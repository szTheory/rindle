defmodule Rindle.Domain.StalePolicy do
  @moduledoc """
  Stale variant serving and regeneration targeting helpers.
  """

  import Ecto.Query, only: [where: 3]

  @type stale_mode :: :serve_stale | :fallback_original

  @spec resolve_stale_variant(stale_mode(), String.t(), String.t()) ::
          {:serve_variant, :stale} | {:serve_original, String.t()}
  def resolve_stale_variant(stale_mode, variant_state, original_url) do
    case {stale_mode, variant_state} do
      {:serve_stale, "stale"} ->
        {:serve_variant, :stale}

      {:serve_stale, _other_state} ->
        {:serve_original, original_url}

      {:fallback_original, _any_state} ->
        {:serve_original, original_url}
    end
  end

  @spec stale_regeneration_scope(Ecto.Queryable.t()) :: Ecto.Query.t()
  def stale_regeneration_scope(query) do
    query
    |> where([v], v.state == "stale")
  end
end
