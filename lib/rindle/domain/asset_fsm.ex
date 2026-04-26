defmodule Rindle.Domain.AssetFSM do
  @moduledoc """
  Transition rules for media asset lifecycle state changes.
  """

  require Logger

  @allowed_transitions %{
    "staged" => ["validating"],
    "validating" => ["analyzing"],
    "analyzing" => ["promoting"],
    "promoting" => ["available"],
    "available" => ["processing", "quarantined"],
    "processing" => ["ready", "quarantined"],
    "ready" => ["degraded", "deleted"],
    "degraded" => ["quarantined", "deleted"],
    "quarantined" => ["deleted"],
    "deleted" => []
  }

  @type state :: String.t()
  @type transition_error :: {:error, {:invalid_transition, state(), state()}}

  @doc """
  Returns `:ok` when the transition is explicitly allowlisted.

  Examples:
    * `{"staged", "ready"} -> {:error, {:invalid_transition, "staged", "ready"}}`
    * `{"staged", "degraded"} -> {:error, {:invalid_transition, "staged", "degraded"}}`
    * `{"analyzing", "deleted"} -> {:error, {:invalid_transition, "analyzing", "deleted"}}`
  """
  @spec transition(state(), state(), map()) :: :ok | transition_error()
  def transition(current_state, target_state, context \\ %{}) do
    if target_state in Map.get(@allowed_transitions, current_state, []) do
      :ok
      |> tap(fn _ ->
        :telemetry.execute(
          [:rindle, :asset, :state_change],
          %{system_time: System.system_time()},
          %{
            profile: Map.get(context, :profile, :unknown),
            adapter: Map.get(context, :adapter, :unknown),
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

  @spec log_quarantine(String.t() | nil, String.t() | nil, term()) :: :ok
  def log_quarantine(asset_id, detected_mime, reason) do
    Logger.warning("rindle.asset.quarantined",
      asset_id: asset_id,
      detected_mime: detected_mime,
      reason: reason
    )

    :ok
  end

  defp log_transition_failure(current_state, target_state, context) do
    Logger.warning("rindle.asset.transition_failed",
      asset_id: Map.get(context, :asset_id),
      from_state: current_state,
      to_state: target_state,
      reason: %{
        type: :invalid_transition,
        detail: Map.get(context, :reason, :invalid_transition)
      }
    )
  end
end
