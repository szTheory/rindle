defmodule Rindle.AV.MetadataSanitizer do
  @moduledoc """
  Container-metadata sanitization for untrusted FFprobe output.

  Two passes applied to every string value in a metadata map:

    1. Strip control characters in `\x00-\x1F` except `\t`.
    2. Truncate to 1024 bytes (codepoint-aligned; no invalid UTF-8 emitted).

  This is layered ON TOP of `Rindle.AV.Ffprobe`'s HTML-escape (Phase 23).
  Both layers are intentional — Phase 23's escape is render-time defense in
  depth (output safety), Phase 24's truncate-and-strip is ingest-time
  stored-data hygiene (input safety). Do NOT collapse them. (D-21)

  Called from `Rindle.Probe.AVProbe` (Plan 05) AFTER `Rindle.AV.Ffprobe.probe/1`
  and BEFORE the result is written into `media_assets.metadata`. (D-20)

  Implementation note: the standard byte-slice helper arrived in Elixir 1.17,
  while the CI matrix includes Elixir 1.15. The hand-rolled `binary-size` +
  `String.valid?/1` rewind is the portable equivalent.
  """

  @max_bytes 1024
  # Control chars \x00-\x1F minus \t (\x09).
  @control_chars Enum.map(0x00..0x1F, &<<&1>>) -- [<<0x09>>]

  @spec sanitize(map() | list() | binary() | term()) ::
          map() | list() | binary() | term()
  def sanitize(value) when is_binary(value) do
    value
    |> strip_control_chars()
    |> truncate_to_bytes(@max_bytes)
  end

  def sanitize(value) when is_map(value),
    do: Map.new(value, fn {k, v} -> {k, sanitize(v)} end)

  def sanitize(value) when is_list(value), do: Enum.map(value, &sanitize/1)
  def sanitize(value), do: value

  @doc false
  @spec strip_control_chars(String.t()) :: String.t()
  def strip_control_chars(string) when is_binary(string),
    do: Enum.reduce(@control_chars, string, &String.replace(&2, &1, ""))

  @doc """
  Truncates `string` to at most `max_bytes` bytes, never emitting an
  incomplete UTF-8 codepoint. Works on Elixir 1.15+.

  ## Examples

      iex> Rindle.AV.MetadataSanitizer.truncate_to_bytes("héllo", 1024)
      "héllo"

      iex> Rindle.AV.MetadataSanitizer.truncate_to_bytes("héllo", 3)
      "hé"

      iex> Rindle.AV.MetadataSanitizer.truncate_to_bytes("hello", 5)
      "hello"
  """
  @spec truncate_to_bytes(String.t(), non_neg_integer()) :: String.t()
  def truncate_to_bytes(string, max_bytes)
      when is_binary(string) and is_integer(max_bytes) and max_bytes >= 0 do
    if byte_size(string) <= max_bytes do
      string
    else
      <<head::binary-size(max_bytes), _rest::binary>> = string
      drop_trailing_partial_codepoint(head)
    end
  end

  # If `head` ends mid-codepoint, peel back bytes one at a time until the
  # remaining binary is valid UTF-8. UTF-8 codepoints are at most 4 bytes,
  # so this loop runs at most 3 times.
  defp drop_trailing_partial_codepoint(<<>>), do: <<>>

  defp drop_trailing_partial_codepoint(bin) when is_binary(bin) do
    if String.valid?(bin) do
      bin
    else
      size = byte_size(bin)
      <<shorter::binary-size(size - 1), _::binary>> = bin
      drop_trailing_partial_codepoint(shorter)
    end
  end
end
