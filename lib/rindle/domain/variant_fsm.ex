defmodule Rindle.Domain.VariantFSM do
  @moduledoc false

  @allowed_transitions %{
    "planned" => ["queued", "cancelled"],
    "queued" => ["processing", "cancelled"],
    "processing" => ["ready", "failed", "cancelled"],
    "ready" => ["stale", "missing", "purged"],
    "stale" => ["queued", "purged"],
    "missing" => ["queued", "purged"],
    "failed" => ["queued", "purged"],
    "cancelled" => [],
    "purged" => []
  }

  @type state :: String.t()
  @type transition_error :: {:error, {:invalid_transition, state(), state()}}

  @spec transition(state(), state(), map()) :: :ok | transition_error()
  def transition(current_state, target_state, context \\ %{}) do
    if target_state in Map.get(@allowed_transitions, current_state, []) do
      :ok
      |> tap(fn _ ->
        :telemetry.execute(
          [:rindle, :variant, :state_change],
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
      {:error, {:invalid_transition, current_state, target_state}}
    end
  end
end
