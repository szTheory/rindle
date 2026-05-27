defmodule Rindle.Domain.ProviderAssetFSM do
  @moduledoc false

  require Logger

  # D-13 — locked transitions for media_provider_assets.state.
  # `errored → processing` is the re-ingest re-entry edge; Phase 34
  # MuxIngestVariant retry path depends on this edge.
  @allowed_transitions %{
    "pending" => ["uploading", "errored", "deleted"],
    "uploading" => ["processing", "errored", "deleted"],
    "processing" => ["ready", "errored"],
    "ready" => ["errored", "deleted"],
    "errored" => ["deleted", "processing"],
    "deleted" => []
  }

  @type state :: String.t()
  @type transition_error :: {:error, {:invalid_transition, state(), state()}}

  @doc """
  Returns `:ok` when the transition is explicitly allowlisted (D-13). Emits
  `[:rindle, :provider_asset, :state_change]` telemetry on success; logs a
  `Logger.warning` and returns an `{:error, {:invalid_transition, from, to}}`
  tuple on rejection. Caller owns the changeset apply / persistence step;
  this function is a pure validator (no DB writes).
  """
  @spec transition(state(), state(), map()) :: :ok | transition_error()
  def transition(current_state, target_state, context \\ %{}) do
    if target_state in Map.get(@allowed_transitions, current_state, []) do
      :ok
      |> tap(fn _ ->
        :telemetry.execute(
          [:rindle, :provider_asset, :state_change],
          %{system_time: System.system_time()},
          %{
            profile: Map.get(context, :profile, :unknown),
            provider: Map.get(context, :provider, :unknown),
            asset_id: Map.get(context, :asset_id),
            from: current_state,
            to: target_state
          }
        )
      end)
    else
      log_transition_failure(current_state, target_state, context)
      {:error, {:invalid_transition, current_state, target_state}}
    end
  end

  @doc "Returns the static `@allowed_transitions` map for introspection / docs."
  @spec allowed_transitions() :: %{String.t() => [String.t()]}
  def allowed_transitions, do: @allowed_transitions

  defp log_transition_failure(current_state, target_state, context) do
    Logger.warning("rindle.provider_asset.transition_failed",
      asset_id: Map.get(context, :asset_id),
      provider: Map.get(context, :provider),
      from_state: current_state,
      to_state: target_state,
      reason: %{type: :invalid_transition}
    )
  end
end
