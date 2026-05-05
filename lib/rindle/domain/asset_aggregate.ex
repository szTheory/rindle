defmodule Rindle.Domain.AssetAggregate do
  @moduledoc false

  import Ecto.Query

  alias Rindle.Domain.{MediaAsset, MediaVariant}

  @terminal_failure_states ["failed", "cancelled"]
  @ready_state "ready"

  @spec recompute(module(), MediaAsset.t() | Ecto.UUID.t()) :: :ok | {:error, term()}
  def recompute(repo, %MediaAsset{id: asset_id}), do: recompute(repo, asset_id)

  def recompute(repo, asset_id) when is_binary(asset_id) do
    asset = repo.get!(MediaAsset, asset_id)

    variants =
      repo.all(
        from v in MediaVariant,
          where: v.asset_id == ^asset_id,
          select: %{id: v.id, state: v.state}
      )

    case target_state(variants) do
      nil ->
        :ok

      target when target == asset.state ->
        :ok

      target_state ->
        asset
        |> MediaAsset.changeset(%{state: target_state})
        |> repo.update()
        |> case do
          {:ok, _asset} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp target_state([]), do: nil

  defp target_state(variants) do
    states = Enum.map(variants, & &1.state)

    cond do
      Enum.all?(states, &(&1 == @ready_state)) ->
        @ready_state

      Enum.any?(states, &(&1 in @terminal_failure_states)) ->
        "degraded"

      true ->
        "transcoding"
    end
  end
end
