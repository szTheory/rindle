defmodule Rindle.Security.StorageKey do
  @moduledoc """
  Generates non-user-controlled storage keys for uploaded assets.
  """

  @spec generate(String.t(), String.t(), String.t()) :: String.t()
  def generate(profile, asset_id, extension) do
    profile = normalize_segment(profile, "profile")
    asset_id = normalize_segment(asset_id, "asset")
    extension = normalize_extension(extension)
    uuid = Ecto.UUID.generate()

    Path.join([profile, asset_id, "#{uuid}#{extension}"])
  end

  defp normalize_segment(value, fallback) when is_binary(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]/u, "-")
    |> String.trim("-")
    |> case do
      "" -> fallback
      cleaned -> cleaned
    end
  end

  defp normalize_segment(_value, fallback), do: fallback

  defp normalize_extension(extension) when is_binary(extension) do
    extension =
      extension
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9.]/u, "")

    cond do
      extension == "" -> ""
      String.starts_with?(extension, ".") -> extension
      true -> ".#{extension}"
    end
  end

  defp normalize_extension(_extension), do: ""
end
