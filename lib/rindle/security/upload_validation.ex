defmodule Rindle.Security.UploadValidation do
  @moduledoc """
  Server-side upload validation primitives.

  Client-provided metadata is treated as advisory. MIME detection is based on
  file bytes, then checked against profile allowlists and extension consistency.
  """

  alias Rindle.Security.Mime

  @type upload_metadata :: %{
          optional(:path) => Path.t(),
          optional(:filename) => String.t(),
          optional(:extension) => String.t()
        }

  @type profile_policy :: %{
          optional(:allow_mime) => [String.t()],
          optional(:allow_extensions) => [String.t()]
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
end
