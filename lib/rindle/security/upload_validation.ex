defmodule Rindle.Security.UploadValidation do
  @moduledoc """
  Server-side upload validation primitives.

  Client-provided metadata is treated as advisory. MIME detection is based on
  file bytes, then checked against profile allowlists and extension consistency.
  """

  alias Rindle.Security.Mime
  alias Rindle.Security.Filename
  alias Rindle.Security.StorageKey

  @type upload_metadata :: %{
          optional(:path) => Path.t(),
          optional(:filename) => String.t(),
          optional(:extension) => String.t(),
          optional(:byte_size) => non_neg_integer(),
          optional(:width) => pos_integer(),
          optional(:height) => pos_integer(),
          optional(:direct_upload) => boolean(),
          optional(:upload_session_state) => String.t()
        }

  @type profile_policy :: %{
          optional(:allow_mime) => [String.t()],
          optional(:allow_extensions) => [String.t()],
          optional(:max_bytes) => pos_integer(),
          optional(:max_pixels) => pos_integer()
        }

  @spec validate_mime_and_extension(upload_metadata(), profile_policy()) ::
          {:ok, %{detected_mime: String.t(), extension: String.t()}} | {:error, {:quarantine, atom()}}
  def validate_mime_and_extension(upload, profile_policy)
      when is_map(upload) and is_map(profile_policy) do
    allow_mime = Map.get(profile_policy, :allow_mime, [])
    allow_extensions = Map.get(profile_policy, :allow_extensions, []) |> Enum.map(&Mime.normalize_extension/1)

    with {:ok, path} <- fetch_path(upload),
         {:ok, detected_mime} <- Mime.detect(path),
         :ok <- ensure_mime_allowed(detected_mime, allow_mime),
         {:ok, extension} <- fetch_extension(upload),
         :ok <- ensure_extension_allowed(extension, allow_extensions),
         :ok <- ensure_extension_matches_mime(extension, detected_mime) do
      {:ok, %{detected_mime: detected_mime, extension: extension}}
    end
  end

  def validate_mime_and_extension(_upload, _profile_policy), do: {:error, {:quarantine, :invalid_upload}}

  @spec validate_limits(upload_metadata(), profile_policy()) :: :ok | {:error, {:quarantine, atom()}}
  def validate_limits(upload, profile_policy) when is_map(upload) and is_map(profile_policy) do
    max_bytes = Map.get(profile_policy, :max_bytes)
    max_pixels = Map.get(profile_policy, :max_pixels)

    with :ok <- ensure_max_bytes(upload, max_bytes),
         :ok <- ensure_max_pixels(upload, max_pixels) do
      :ok
    end
  end

  def validate_limits(_upload, _profile_policy), do: {:error, {:quarantine, :invalid_upload}}

  @spec validate_promotion_gate(upload_metadata(), :ok | {:ok, map()} | {:error, term()}) ::
          :ok | {:error, {:quarantine, atom()}}
  def validate_promotion_gate(upload, validation_result) when is_map(upload) do
    if direct_upload?(upload) do
      state = Map.get(upload, :upload_session_state) || Map.get(upload, "upload_session_state")

      cond do
        not success_result?(validation_result) ->
          {:error, {:quarantine, :validation_required}}

        state in ["verifying", "completed"] ->
          :ok

        true ->
          {:error, {:quarantine, :direct_upload_not_verified}}
      end
    else
      if success_result?(validation_result) do
        :ok
      else
        {:error, {:quarantine, :validation_required}}
      end
    end
  end

  def validate_promotion_gate(_upload, _validation_result), do: {:error, {:quarantine, :invalid_upload}}

  @spec validate_for_promotion(upload_metadata(), profile_policy(), String.t(), String.t()) ::
          {:ok,
           %{
             detected_mime: String.t(),
             extension: String.t(),
             sanitized_filename: String.t(),
             storage_key: String.t()
           }}
          | {:error, {:quarantine, atom()}}
  def validate_for_promotion(upload, profile_policy, profile, asset_id) do
    with {:ok, %{detected_mime: detected_mime, extension: extension}} <-
           validate_mime_and_extension(upload, profile_policy),
         :ok <- validate_limits(upload, profile_policy),
         :ok <- validate_promotion_gate(upload, :ok),
         {:ok, filename} <- fetch_filename(upload) do
      {:ok,
       %{
         detected_mime: detected_mime,
         extension: extension,
         sanitized_filename: Filename.sanitize(filename),
         storage_key: StorageKey.generate(profile, asset_id, extension)
       }}
    end
  end

  defp fetch_path(upload) do
    case Map.get(upload, :path) || Map.get(upload, "path") do
      path when is_binary(path) and path != "" -> {:ok, path}
      _ -> {:error, {:quarantine, :missing_upload_path}}
    end
  end

  defp fetch_extension(upload) do
    extension =
      Map.get(upload, :extension) ||
        Map.get(upload, "extension") ||
        upload
        |> Map.get(:filename, Map.get(upload, "filename", ""))
        |> Path.extname()

    case extension do
      ext when is_binary(ext) and ext != "" -> {:ok, Mime.normalize_extension(ext)}
      _ -> {:error, {:quarantine, :missing_extension}}
    end
  end

  defp fetch_filename(upload) do
    case Map.get(upload, :filename) || Map.get(upload, "filename") do
      filename when is_binary(filename) and filename != "" -> {:ok, filename}
      _ -> {:error, {:quarantine, :missing_filename}}
    end
  end

  defp ensure_mime_allowed(_detected_mime, []), do: :ok

  defp ensure_mime_allowed(detected_mime, allow_mime) do
    if detected_mime in allow_mime do
      :ok
    else
      {:error, {:quarantine, :mime_not_allowed}}
    end
  end

  defp ensure_extension_allowed(_extension, []), do: :ok

  defp ensure_extension_allowed(extension, allow_extensions) do
    if extension in allow_extensions do
      :ok
    else
      {:error, {:quarantine, :extension_not_allowed}}
    end
  end

  defp ensure_extension_matches_mime(extension, detected_mime) do
    if Mime.extension_matches_mime?(extension, detected_mime) do
      :ok
    else
      {:error, {:quarantine, :extension_mime_mismatch}}
    end
  end

  defp ensure_max_bytes(_upload, nil), do: :ok

  defp ensure_max_bytes(upload, max_bytes) when is_integer(max_bytes) do
    byte_size = Map.get(upload, :byte_size) || Map.get(upload, "byte_size")

    if is_integer(byte_size) and byte_size <= max_bytes do
      :ok
    else
      {:error, {:quarantine, :max_bytes_exceeded}}
    end
  end

  defp ensure_max_bytes(_upload, _max_bytes), do: {:error, {:quarantine, :max_bytes_exceeded}}

  defp ensure_max_pixels(_upload, nil), do: :ok

  defp ensure_max_pixels(upload, max_pixels) when is_integer(max_pixels) do
    width = Map.get(upload, :width) || Map.get(upload, "width")
    height = Map.get(upload, :height) || Map.get(upload, "height")

    if is_integer(width) and is_integer(height) and width * height <= max_pixels do
      :ok
    else
      {:error, {:quarantine, :max_pixels_exceeded}}
    end
  end

  defp ensure_max_pixels(_upload, _max_pixels), do: {:error, {:quarantine, :invalid_pixel_dimensions}}

  defp direct_upload?(upload) do
    Map.get(upload, :direct_upload) || Map.get(upload, "direct_upload") || false
  end

  defp success_result?(:ok), do: true
  defp success_result?({:ok, _value}), do: true
  defp success_result?(_), do: false
end
