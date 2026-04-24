defmodule Rindle.Domain.UploadSessionFSM do
  @moduledoc """
  Transition rules for media upload session lifecycle state changes.
  """

  @allowed_transitions %{
    "initialized" => ["signed", "aborted", "expired", "failed"],
    "signed" => ["uploading", "uploaded", "aborted", "expired", "failed"],
    "uploading" => ["uploaded", "aborted", "expired", "failed"],
    "uploaded" => ["verifying"],
    "verifying" => ["completed", "failed"],
    "completed" => [],
    "aborted" => [],
    "expired" => [],
    "failed" => []
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
