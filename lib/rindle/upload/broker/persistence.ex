defmodule Rindle.Upload.Broker.Persistence do
  @moduledoc false

  alias Rindle.Domain.{MediaAsset, MediaUploadSession}
  alias Rindle.Storage.Local

  @doc false
  def create(repo, session_seed, session_attrs) do
    case repo.transaction(fn ->
           {:ok, asset} =
             %MediaAsset{id: session_seed.asset_id}
             |> MediaAsset.changeset(%{
               state: "staged",
               profile: session_seed.profile_name,
               storage_key: session_seed.storage_key,
               filename: session_seed.filename
             })
             |> repo.insert()

           {:ok, session} =
             %MediaUploadSession{}
             |> MediaUploadSession.changeset(
               Map.merge(
                 %{
                   asset_id: asset.id,
                   state: "initialized",
                   upload_key: session_seed.storage_key,
                   expires_at: session_seed.expires_at
                 },
                 session_attrs
               )
             )
             |> repo.insert()

           session
         end) do
      {:ok, session} -> {:ok, session}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  def persist_multipart(repo, adapter, session_seed, multipart, opts) do
    case create(repo, session_seed, %{
           state: "initialized",
           upload_strategy: "multipart",
           multipart_upload_id: multipart.upload_id,
           multipart_parts: %{}
         }) do
      {:ok, session} ->
        {:ok, session}

      {:error, reason} ->
        compensate_failed_multipart_persist(adapter, session_seed.storage_key, multipart.upload_id, opts)
        {:error, reason}
    end
  end

  @doc false
  def persist_resumable(repo, adapter, session_seed, resumable, opts) do
    case create(repo, session_seed, %{
           state: "signed",
           upload_strategy: "resumable",
           session_uri: resumable.session_uri,
           session_uri_expires_at: resumable.expires_at,
           last_known_offset: 0,
           region_hint: Map.get(resumable, :region_hint)
         }) do
      {:ok, session} ->
        {:ok, session}

      {:error, reason} ->
        compensate_failed_resumable_persist(adapter, session_seed.storage_key, resumable.session_uri, opts)
        {:error, reason}
    end
  end

  @doc false
  def persist_tus(repo, session_seed, opts) do
    case create(repo, session_seed, %{
           state: "signed",
           upload_strategy: "resumable",
           resumable_protocol: "tus",
           last_known_offset: 0
         }) do
      {:ok, session} ->
        {:ok, session}

      {:error, reason} ->
        compensate_failed_tus_persist(session_seed.asset_id, session_seed.storage_key, opts)
        {:error, reason}
    end
  end

  @doc false
  def update(repo, session, attrs) do
    repo.transaction(fn ->
      {:ok, updated_session} =
        session
        |> MediaUploadSession.changeset(attrs)
        |> repo.update()

      updated_session
    end)
  end

  defp compensate_failed_multipart_persist(adapter, storage_key, upload_id, opts) do
    case adapter.abort_multipart_upload(storage_key, upload_id, opts) do
      {:ok, _} -> :ok
      {:error, :not_found} -> :ok
      {:error, reason} ->
        require Logger
        Logger.warning("rindle.upload.broker.multipart_persist_compensation_failed",
          upload_key: storage_key,
          multipart_upload_id: upload_id,
          reason: inspect(reason)
        )
        :ok
    end
  end

  defp compensate_failed_resumable_persist(adapter, storage_key, session_uri, opts) do
    case adapter.cancel_resumable_upload(storage_key, session_uri, opts) do
      {:ok, _} -> :ok
      {:error, :session_uri_unknown} -> :ok
      {:error, :session_uri_expired} -> :ok
      {:error, reason} ->
        require Logger
        Logger.warning("rindle.upload.broker.resumable_persist_compensation_failed",
          upload_key: storage_key,
          reason: inspect(reason)
        )
        :ok
    end
  end

  defp compensate_failed_tus_persist(asset_id, storage_key, opts) do
    part_path = Local.tus_part_path(asset_id, opts)

    case File.rm_rf(part_path) do
      {:ok, _removed} -> :ok
      {:error, reason, _file} ->
        require Logger
        Logger.warning("rindle.upload.broker.tus_persist_compensation_failed",
          upload_key: storage_key,
          reason: inspect(reason)
        )
        :ok
    end
  end
end
