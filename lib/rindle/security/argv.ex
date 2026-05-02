defmodule Rindle.Security.Argv do
  @moduledoc """
  Argv sanitization and format validation.
  """

  @shell_chars_regex ~r/[;&|`$<>]/

  @doc """
  Validates a command argument string against shell injection and unsupported formats.
  """
  def validate(command) do
    cond do
      String.match?(command, @shell_chars_regex) ->
        {:error, :invalid_format}

      String.match?(command, ~r/\$\(/) ->
        {:error, :invalid_format}

      not String.contains?(command, "-protocol_whitelist") ->
        {:error, :missing_protocol_whitelist}

      String.match?(command, ~r/\.(m3u8|mpd|mkv)\b/i) ->
        {:error, :unsupported_ingest_format}

      String.match?(command, ~r/-f\s+(hls|dash|matroska)\b/i) ->
        {:error, :unsupported_ingest_format}

      true ->
        {:ok, command}
    end
  end

  @doc """
  Sanitizes a command string by stripping out shell characters.
  """
  def sanitize(command) do
    command
    |> String.replace(@shell_chars_regex, "")
    |> String.replace(~r/\$\(/, "")
  end
end
