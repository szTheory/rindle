defmodule Rindle.Domain.VariantFSM do
  @moduledoc """
  Transition rules for media variant lifecycle state changes.
  """

  @allowed_transitions %{
    "planned" => ["queued"],
    "queued" => ["processing"],
    "processing" => ["ready", "failed"],
    "ready" => ["stale", "missing", "purged"],
    "stale" => ["queued", "purged"],
    "missing" => ["queued", "purged"],
    "failed" => ["queued", "purged"],
    "purged" => []
  }

  @type state :: String.t()
  @type transition_error :: {:error, {:invalid_transition, state(), state()}}

  @spec transition(state(), state(), map()) :: :ok | transition_error()
  def transition(current_state, target_state, _context \\ %{}) do
    if target_state in Map.get(@allowed_transitions, current_state, []) do
      :ok
    else
      {:error, {:invalid_transition, current_state, target_state}}
    end
  end
end
