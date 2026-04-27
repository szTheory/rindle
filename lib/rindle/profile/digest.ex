defmodule Rindle.Profile.Digest do
  @moduledoc """
  Deterministic digest generation for profile variant recipes.
  """

  @spec for_variant(module(), atom()) :: String.t()
  def for_variant(profile_module, variant_name) when is_atom(variant_name) do
    spec = fetch_variant_spec!(profile_module, variant_name)

    spec
    |> normalize()
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  def for_variant(_profile_module, variant_name) do
    raise ArgumentError, "variant name must be an atom, got: #{inspect(variant_name)}"
  end

  defp fetch_variant_spec!(profile_module, variant_name) do
    if function_exported?(profile_module, :variants, 0) do
      do_fetch_variant_spec!(profile_module, variant_name)
    else
      raise ArgumentError,
            "profile #{inspect(profile_module)} does not implement variants/0"
    end
  end

  defp do_fetch_variant_spec!(profile_module, variant_name) do
    case Enum.find(profile_module.variants(), fn {name, _spec} -> name == variant_name end) do
      {_name, spec} ->
        spec

      nil ->
        raise ArgumentError,
              "unknown variant #{inspect(variant_name)} for profile #{inspect(profile_module)}"
    end
  end

  defp normalize(value) when is_map(value) do
    value
    |> Enum.map(fn {key, nested_value} ->
      {normalize_key(key), normalize(nested_value)}
    end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(fn {key, nested_value} -> [key, nested_value] end)
  end

  defp normalize(value) when is_list(value) do
    if Keyword.keyword?(value) do
      value
      |> Enum.map(fn {key, nested_value} ->
        {normalize_key(key), normalize(nested_value)}
      end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {key, nested_value} -> [key, nested_value] end)
    else
      Enum.map(value, &normalize/1)
    end
  end

  defp normalize(value), do: value

  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key) when is_binary(key), do: key
  defp normalize_key(key), do: inspect(key)
end
