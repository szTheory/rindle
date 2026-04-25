defmodule Rindle.Domain.UploadSessionFSM do
  @moduledoc """
  Transition rules for media upload session lifecycle state changes.
  """

  require Logger

  @allowed_transitions %{
    "initialized" => ["signed", "aborted", "expired", "failed"],
    "signed" => ["uploading", "uploaded", "verifying", "aborted", "expired", "failed"],
    "uploading" => ["uploaded", "verifying", "aborted", "expired", "failed"],
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
  def transition(current_state, target_state, context \\ %{}) do
    if target_state in Map.get(@allowed_transitions, current_state, []) do
      :ok
    else
      log_transition_failure(current_state, target_state, context)
      {:error, {:invalid_transition, current_state, target_state}}
    end
  end

  @spec log_session_expiry(String.t() | nil, non_neg_integer()) :: :ok
  def log_session_expiry(session_id, elapsed_seconds) do
    Logger.info("rindle.upload_session.expired",
      session_id: session_id,
      reason: %{event: :expired, elapsed_seconds: elapsed_seconds}
    )

    :ok
  end

  defp log_transition_failure(current_state, target_state, context) do
    Logger.warning("rindle.upload_session.transition_failed",
      session_id: Map.get(context, :session_id),
      from_state: current_state,
      to_state: target_state,
      reason: %{
        type: :invalid_transition,
        detail: Map.get(context, :reason, :invalid_transition)
      }
    )
  end
end
