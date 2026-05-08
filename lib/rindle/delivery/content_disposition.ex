defmodule Rindle.Delivery.ContentDisposition do
  @moduledoc """
  Normalizes caller-supplied download disposition intent.

  The normalized representation is shared across redirect-style adapter opts and
  future local header emission so delivery policy stays consistent.
  """

  alias Rindle.Security.Filename

  @type disposition_type :: :inline | :attachment

  @type t :: %{
          type: disposition_type(),
          filename: String.t(),
          filename_star: String.t()
        }

  @doc """
  Returns a normalized disposition map, or `nil` when the caller did not request one.
  """
  @spec normalize(String.t(), keyword()) :: t() | nil
  def normalize(key, opts) do
    disposition = Keyword.get(opts, :disposition)
    filename = Keyword.get(opts, :filename)

    if is_nil(disposition) and is_nil(filename) do
      nil
    else
      type = normalize_type(disposition)
      sanitized_filename = normalize_filename(key, filename, type)

      %{
        type: type,
        filename: sanitized_filename,
        filename_star: "UTF-8''" <> encode_rfc5987(sanitized_filename)
      }
    end
  end

  defp normalize_type(:attachment), do: :attachment
  defp normalize_type("attachment"), do: :attachment
  defp normalize_type(_), do: :inline

  defp normalize_filename(key, nil, :attachment), do: Filename.sanitize(Path.basename(key))
  defp normalize_filename(_key, nil, :inline), do: Filename.sanitize("download")
  defp normalize_filename(_key, filename, _type), do: Filename.sanitize(filename)

  defp encode_rfc5987(value) do
    value
    |> :unicode.characters_to_binary(:utf8)
    |> :binary.bin_to_list()
    |> Enum.map_join(&encode_byte/1)
  end

  defp encode_byte(byte)
       when byte in ?0..?9 or byte in ?A..?Z or byte in ?a..?z or
              byte in [?!, ?#, ?$, ?&, ?+, ?-, ?., ?^, ?_, ?`, ?|, ?~] do
    <<byte>>
  end

  defp encode_byte(byte) do
    "%" <> String.upcase(Base.encode16(<<byte>>))
  end
end
