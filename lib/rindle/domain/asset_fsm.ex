defmodule Rindle.Domain.AssetFSM do
  @moduledoc """
  Transition rules for media asset lifecycle state changes.
  """

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
  def transition(current_state, target_state, _context \\ %{}) do
    if target_state in Map.get(@allowed_transitions, current_state, []) do
      :ok
    else
      {:error, {:invalid_transition, current_state, target_state}}
    end
  end
end
