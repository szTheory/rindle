defmodule Rindle.Upload.Broker.Completion do
  @moduledoc false

  alias Rindle.Domain.{MediaAsset, MediaUploadSession, UploadSessionFSM}
  alias Rindle.Workers.PromoteAsset

  @doc false
  @spec transact(module(), MediaUploadSession.t(), MediaAsset.t(), map()) ::
          {:ok, map()} | {:error, atom(), term(), map()}
  def transact(repo, session, asset, metadata) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(
      :verifying_session,
      MediaUploadSession.changeset(session, %{state: "verifying"})
    )
    |> Ecto.Multi.run(:verify_fsm_complete, fn _repo, %{verifying_session: vs} ->
      do_fsm_transition(vs)
    end)
    |> Ecto.Multi.update(
      :session,
      fn %{verifying_session: vs} ->
        MediaUploadSession.changeset(vs, %{
          state: "completed",
          verified_at: DateTime.utc_now()
        })
      end
    )
    |> Ecto.Multi.update(
      :asset,
      MediaAsset.changeset(asset, %{
        state: "validating",
        byte_size: Map.get(metadata, :size),
        content_type: Map.get(metadata, :content_type)
      })
    )
    |> Oban.insert(:promote_job, PromoteAsset.new(%{asset_id: asset.id}))
    |> repo.transaction()
  end

  defp do_fsm_transition(session) do
    case UploadSessionFSM.transition(session.state, "completed", %{session_id: session.id}) do
      :ok -> {:ok, :transitioned}
      error -> error
    end
  end
end
