defmodule Rindle.AV.Ffprobe do
  @moduledoc """
  FFprobe metadata extractor shim.

  Extracts format and stream metadata treating output as untrusted UGC.
  """
  alias Rindle.AV.Subprocess

  @doc """
  Runs ffprobe on the given file path to extract JSON metadata.
  """
  def probe(file_path) do
    args = [
      "-v",
      "error",
      "-print_format",
      "json",
      "-show_format",
      "-show_streams",
      file_path
    ]

    case Subprocess.run("ffprobe", args) do
      {output, 0} ->
        parse_and_sanitize(output)

      {output, status} ->
        {:error, {:ffprobe_failed, status, output}}
    end
  end

  @doc """
  Parses a JSON string from ffprobe and sanitizes all string values.
  """
  def parse_and_sanitize(json) do
    case Jason.decode(json) do
      {:ok, data} ->
        {:ok, sanitize(data)}

      {:error, _} ->
        {:error, :invalid_json}
    end
  end

  defp sanitize(string) when is_binary(string) do
    string
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp sanitize(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {k, sanitize(v)} end)
  end

  defp sanitize(list) when is_list(list) do
    Enum.map(list, &sanitize/1)
  end

  defp sanitize(other), do: other
end
