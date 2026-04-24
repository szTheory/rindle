defmodule Rindle.Security.Mime do
  @moduledoc """
  Helpers for server-side MIME detection and extension consistency checks.
  """

  @magic_probe_bytes 8_192
  @unknown_mime "application/octet-stream"

  @spec detect(Path.t()) :: {:ok, String.t()} | {:error, :unknown_mime}
  def detect(path) do
    if is_binary(path) do
      case File.open(path, [:read, :binary]) do
        {:ok, io} ->
          result =
            case IO.binread(io, @magic_probe_bytes) do
              data when is_binary(data) and byte_size(data) > 0 ->
                data
                |> ExMarcel.MimeType.for({:string, data})
                |> normalize_detected_mime()

              _ ->
                {:error, :unknown_mime}
            end

          File.close(io)
          result

        {:error, _reason} ->
          {:error, :unknown_mime}
      end
    else
      {:error, :unknown_mime}
    end
  end

  @spec extension_matches_mime?(String.t(), String.t()) :: boolean()
  def extension_matches_mime?(extension, detected_mime)
      when is_binary(extension) and is_binary(detected_mime) do
    extension_mime =
      extension
      |> normalize_extension()
      |> then(&ExMarcel.MimeType.for(nil, extension: &1))

    mime_matches_detected?(extension_mime, detected_mime)
  end

  @spec normalize_extension(String.t()) :: String.t()
  def normalize_extension(extension) when is_binary(extension) do
    extension =
      extension
      |> String.downcase()
      |> String.trim()

    if String.starts_with?(extension, ".") do
      extension
    else
      "." <> extension
    end
  end

  defp normalize_detected_mime(mime) when is_binary(mime) do
    if mime == @unknown_mime do
      {:error, :unknown_mime}
    else
      {:ok, mime}
    end
  end

  defp normalize_detected_mime(_), do: {:error, :unknown_mime}

  defp mime_matches_detected?(extension_mime, detected_mime) when is_binary(extension_mime) do
    extension_mime == detected_mime
  end

  defp mime_matches_detected?(_extension_mime, _detected_mime), do: true
end
