defmodule Rindle.Security.Filename do
  @moduledoc """
  Sanitizes client-provided filenames for safe metadata storage.
  """

  @default_filename "upload"

  @spec sanitize(String.t()) :: String.t()
  def sanitize(filename) do
    filename
    |> Path.basename()
    |> String.replace(~r/[\x00-\x1F\x7F]/u, "")
    |> String.replace(~r{[/\\]+}u, "_")
    |> String.replace(~r/[^A-Za-z0-9._-]/u, "_")
    |> String.replace(~r/_+/u, "_")
    |> String.trim("_")
    |> fallback_filename()
  end

  defp fallback_filename(""), do: @default_filename
  defp fallback_filename(value), do: value
end
