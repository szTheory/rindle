defmodule Rindle.Upload.Broker do
  @moduledoc """
  Manages direct-to-storage upload sessions.
  """

  alias Rindle.Config
  alias Rindle.Domain.{AssetFSM, MediaAsset, MediaUploadSession, UploadSessionFSM}
  alias Rindle.Storage.Capabilities
  alias Rindle.Upload.Broker.{Completion, Persistence, SessionSeed, SessionValidation}
  alias Rindle.Upload.ResumableTelemetry
  alias Phoenix.PubSub

  @default_multipart_part_size 8 * 1024 * 1024

  @typedoc "Tagged result wrapping just an upload session."
  @type session_only_result :: {:ok, MediaUploadSession.t()} | {:error, term()}

  @typedoc "Tagged result of `initiate_multipart_session/2` — session plus multipart upload metadata."
  @type initiate_multipart_result ::
          {:ok,
           %{
             session: MediaUploadSession.t(),
             multipart: %{
               upload_id: String.t(),
               upload_key: String.t(),
               part_size: pos_integer(),
               part_headers: map()
             }
           }}
          | {:error, term()}

  @typedoc "Presigned upload payload returned by sign_url and sign_multipart_part."
  @type presigned_payload :: %{
          required(:url) => String.t(),
          required(:method) => atom() | String.t(),
          required(:headers) => map() | list(),
          optional(:part_number) => pos_integer(),
          optional(:upload_id) => String.t()
        }

  @typedoc "Tagged result of `sign_url/2` — session plus presigned PUT payload."
  @type sign_url_result ::
          {:ok, %{session: MediaUploadSession.t(), presigned: presigned_payload()}}
          | {:error, term()}

  @typedoc "Tagged result of `sign_multipart_part/3` — session plus presigned part payload."
  @type sign_part_result :: sign_url_result()

  @typedoc "Tagged result of `verify_completion/2` and `complete_multipart_upload/3` — session plus promoted asset."
  @type verify_result ::
          {:ok, %{session: MediaUploadSession.t(), asset: MediaAsset.t()}}
          | {:error, term()}

  @typedoc "Tagged result of `initiate_resumable_session/2` — session plus resumable session metadata."
  @type initiate_resumable_result ::
          {:ok,
           %{
             session: MediaUploadSession.t(),
             resumable: %{
               session_uri: String.t(),
               upload_id: String.t(),
               expires_at: DateTime.t()
             }
           }}
          | {:error, term()}

  @typedoc "Tagged result of `initiate_tus_upload/2` — session stamped for the tus protocol lane."
  @type initiate_tus_result ::
          {:ok, %{session: MediaUploadSession.t()}} | {:error, term()}

  @typedoc "Tagged result of `resumable_session_status/2` — session plus remote committed bytes."
  @type resumable_status_result ::
          {:ok,
           %{
             session: MediaUploadSession.t(),
             committed_bytes: non_neg_integer(),
             state: :in_progress | :complete | :expired
           }}
          | {:error, term()}

  @typedoc "Tagged result of `cancel_resumable_session/2` — session after broker-side cancellation bookkeeping."
  @type cancel_resumable_result :: {:ok, %{session: MediaUploadSession.t()}} | {:error, term()}

  @doc """
  Initiates a new direct upload session.

  Creates a staged `MediaAsset` and an `initialized` `MediaUploadSession` in
  a single DB transaction, then emits `[:rindle, :upload, :start]`
  telemetry AFTER commit.

  ## Examples

      # Requires `config :rindle, :repo, MyApp.Repo` and a profile module.
      iex> {:ok, session} = Rindle.Upload.Broker.initiate_session(MyApp.MediaProfile, filename: "photo.png")
      iex> session.state
      "initialized"

  """
  @spec initiate_session(module(), keyword()) :: session_only_result()
  def initiate_session(profile_module, opts \\ []) do
    repo = Config.repo()
    session_seed = SessionSeed.build(profile_module, opts)

    case Persistence.create(repo, session_seed, %{state: "initialized"}) do
      {:ok, session} ->
        emit_upload_start(session_seed.profile_name, profile_module.storage_adapter(), session.id)
        broadcast_upload_session(session, :upload_session_initialized)

        {:ok, session}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Initiates a new multipart upload session through the broker-owned lifecycle.
  """
  @spec initiate_multipart_session(module(), keyword()) :: initiate_multipart_result()
  def initiate_multipart_session(profile_module, opts \\ []) do
    repo = Config.repo()
    session_seed = SessionSeed.build(profile_module, opts)
    part_size = Keyword.get(opts, :part_size, @default_multipart_part_size)
    adapter = profile_module.storage_adapter()

    with :ok <- Capabilities.require_upload(adapter, :multipart_upload),
         {:ok, multipart} <-
           adapter.initiate_multipart_upload(session_seed.storage_key, part_size, opts),
         {:ok, session} <-
           Persistence.persist_multipart(repo, adapter, session_seed, multipart, opts) do
      emit_upload_start(session_seed.profile_name, adapter, session.id)

      ResumableTelemetry.emit_start(
        session_seed.profile_name,
        adapter,
        session,
        %{state: session.state, source: :broker, protocol: :gcs_native},
        %{}
      )

      broadcast_upload_session(session, :upload_session_initialized)

      {:ok,
       %{
         session: session,
         multipart: %{
           upload_id: multipart.upload_id,
           upload_key: session_seed.storage_key,
           part_size: Map.get(multipart, :part_size, part_size),
           part_headers: Map.get(multipart, :part_headers, %{})
         }
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Initiates a new resumable upload session through the broker-owned lifecycle.
  """
  @spec initiate_resumable_session(module(), keyword()) :: initiate_resumable_result()
  def initiate_resumable_session(profile_module, opts \\ []) do
    repo = Config.repo()
    session_seed = SessionSeed.build(profile_module, opts)
    expected_size = Keyword.get(opts, :expected_size)
    adapter = profile_module.storage_adapter()

    with :ok <- Capabilities.require_upload(adapter, :resumable_upload),
         {:ok, resumable} <-
           adapter.initiate_resumable_upload(session_seed.storage_key, expected_size, opts),
         {:ok, session} <-
           Persistence.persist_resumable(repo, adapter, session_seed, resumable, opts) do
      emit_upload_start(session_seed.profile_name, adapter, session.id)
      broadcast_upload_session(session, :upload_session_signed)

      {:ok,
       %{
         session: session,
         resumable: %{
           session_uri: resumable.session_uri,
           upload_id: resumable.upload_id,
           expires_at: resumable.expires_at
         }
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Concatenates multiple complete partial tus sessions into a single final session.
  """
  @spec concatenate_tus_sessions(module(), [map()], keyword()) :: initiate_tus_result()
  def concatenate_tus_sessions(profile_module, payloads, opts \\ []) do
    repo = Config.repo()

    repo.transaction(fn ->
      sessions_with_length =
        Enum.map(payloads, fn payload ->
          session =
            repo.get(MediaUploadSession, payload["session_id"]) || repo.rollback(:not_found)

          {session, payload["length"]}
        end)

      Enum.each(sessions_with_length, fn {session, length} ->
        unless match?(%{"is_partial" => true}, session.multipart_parts) do
          repo.rollback(:not_partial)
        end

        if session.last_known_offset != length or length == nil do
          repo.rollback(:incomplete_partial)
        end
      end)

      total_length = Enum.reduce(sessions_with_length, 0, fn {_, len}, acc -> len + acc end)
      source_keys = Enum.map(sessions_with_length, fn {s, _} -> s.upload_key end)

      {:ok, %{session: final_session}} =
        initiate_tus_upload(profile_module, length: total_length)

      {:ok, final_session} =
        final_session
        |> MediaUploadSession.changeset(%{upload_length: total_length})
        |> repo.update()

      adapter = profile_module.storage_adapter()

      # Call Storage.concatenate
      case adapter.concatenate(final_session.upload_key, source_keys, opts) do
        {:ok, _result} ->
          # Immediately mark final session as complete
          case verify_completion(final_session.id, opts) do
            {:ok, %{session: completed_session}} -> completed_session
            {:error, reason} -> repo.rollback(reason)
          end

        {:error, reason} ->
          repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, final_session} -> {:ok, %{session: final_session}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Initiates a tus-protocol upload session through the broker-owned lifecycle.

  Sibling to `initiate_resumable_session/2` but for the tus (Topology B,
  server-mediated) protocol over a Local-backed sink. Unlike the GCS-native
  resumable path, this does NOT call any adapter-side `initiate_*` (Local has no
  multipart machinery); it only gates on the `:tus_upload` capability and
  persists a session row stamped `resumable_protocol: "tus"`, reusing the
  `"resumable"` strategy lane.

  The session is persisted in `"signed"` so the completion edge
  `signed -> verifying` stays legal (Pitfall 7). The signed tus URL itself is
  minted and stored into `session_uri` by the `TusPlug` edge, which
  owns `secret_key_base`; this broker entrypoint returns the unsigned session.
  """
  @spec initiate_tus_upload(module(), keyword()) :: initiate_tus_result()
  def initiate_tus_upload(profile_module, opts \\ []) do
    repo = Config.repo()
    session_seed = SessionSeed.build(profile_module, opts)
    adapter = profile_module.storage_adapter()

    with :ok <- Capabilities.require_upload(adapter, :tus_upload),
         {:ok, session} <-
           Persistence.persist_tus(repo, session_seed, opts) do
      emit_upload_start(session_seed.profile_name, adapter, session.id)

      ResumableTelemetry.emit_start(
        session_seed.profile_name,
        adapter,
        session,
        %{state: session.state, source: :broker, protocol: :tus},
        %{}
      )

      broadcast_upload_session(session, :upload_session_signed)

      {:ok, %{session: session}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generates a presigned URL for an initialized session.

  Transitions the session to `signed` and returns
  `{:ok, %{session: %MediaUploadSession{}, presigned: %{url: String.t()}}}`.

  ## Examples

      # Requires `config :rindle, :repo, MyApp.Repo` and a configured S3-compatible storage adapter.
      iex> {:ok, %{session: session, presigned: %{url: url}}} =
      ...>   Rindle.Upload.Broker.sign_url(session_id)
      iex> session.state
      "signed"
      iex> is_binary(url)
      true

  """
  @spec sign_url(binary(), keyword()) :: sign_url_result()
  def sign_url(session_id, opts \\ []) do
    repo = Config.repo()

    with %MediaUploadSession{} = session <- repo.get(MediaUploadSession, session_id),
         :ok <- UploadSessionFSM.transition(session.state, "signed", %{session_id: session.id}),
         asset <- repo.preload(session, :asset).asset,
         {:ok, profile_module} <- SessionValidation.profile_module(asset.profile),
         adapter <- profile_module.storage_adapter(),
         expires_in <- Keyword.get(opts, :expires_in, 3600),
         {:ok, presigned} <- adapter.presigned_put(session.upload_key, expires_in, opts),
         {:ok, updated_session} <- Persistence.update(repo, session, %{state: "signed"}) do
      broadcast_upload_session(updated_session, :upload_session_signed)
      {:ok, %{session: updated_session, presigned: presigned}}
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Signs a multipart upload part without falling back to the presigned PUT path.
  """
  @spec sign_multipart_part(binary(), pos_integer(), keyword()) :: sign_part_result()
  def sign_multipart_part(session_id, part_number, opts \\ []) do
    repo = Config.repo()

    with %MediaUploadSession{} = session <- repo.get(MediaUploadSession, session_id),
         :ok <- SessionValidation.multipart(session),
         asset <- repo.preload(session, :asset).asset,
         {:ok, profile_module} <- SessionValidation.profile_module(asset.profile),
         adapter <- profile_module.storage_adapter(),
         :ok <- Capabilities.require_upload(adapter, :multipart_upload),
         expires_in <- Keyword.get(opts, :expires_in, 3600),
         {:ok, presigned} <-
           adapter.presigned_upload_part(
             session.upload_key,
             session.multipart_upload_id,
             part_number,
             expires_in,
             opts
           ),
         {:ok, updated_session} <- ensure_session_marked_signed(repo, session) do
      broadcast_upload_session(updated_session, :upload_session_signed)
      {:ok, %{session: updated_session, presigned: presigned}}
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Completes a multipart upload, then converges into the trusted verification lane.
  """
  @spec complete_multipart_upload(binary(), [map()], keyword()) :: verify_result()
  def complete_multipart_upload(session_id, parts, opts \\ []) do
    repo = Config.repo()

    with %MediaUploadSession{} = session <- repo.get(MediaUploadSession, session_id),
         :ok <- SessionValidation.multipart(session),
         {:ok, normalized_parts} <- SessionValidation.normalize_parts(parts),
         asset <- repo.preload(session, :asset).asset,
         {:ok, profile_module} <- SessionValidation.profile_module(asset.profile),
         adapter <- profile_module.storage_adapter(),
         :ok <- Capabilities.require_upload(adapter, :multipart_upload),
         {:ok, persisted_session} <-
           Persistence.update(repo, session, %{
             multipart_parts: %{"parts" => SessionValidation.encode_parts(normalized_parts)}
           }),
         {:ok, _result} <-
           adapter.complete_multipart_upload(
             persisted_session.upload_key,
             persisted_session.multipart_upload_id,
             normalized_parts,
             opts
           ) do
      verify_completion(persisted_session.id, opts)
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Reads resumable session status without broadening the durable FSM semantics.
  """
  @spec resumable_session_status(binary(), keyword()) :: resumable_status_result()
  def resumable_session_status(session_id, opts \\ []) do
    repo = Config.repo()

    with %MediaUploadSession{} = session <- repo.get(MediaUploadSession, session_id),
         :ok <- SessionValidation.resumable(session),
         asset <- repo.preload(session, :asset).asset,
         {:ok, profile_module} <- SessionValidation.profile_module(asset.profile),
         adapter <- profile_module.storage_adapter(),
         :ok <- Capabilities.require_upload(adapter, :resumable_upload_session),
         {:ok, status} <-
           adapter.resumable_upload_status(session.upload_key, session.session_uri, opts),
         {:ok, updated_session} <-
           Persistence.update(
             repo,
             session,
             SessionValidation.resumable_status_attrs(session, status)
           ),
         :ok <-
           ResumableTelemetry.emit_status(
             asset.profile,
             adapter,
             updated_session,
             %{state: status.state, source: Keyword.get(opts, :source, :poll), outcome: :ok},
             %{
               committed_bytes: status.committed_bytes,
               offset_delta: status.committed_bytes - (session.last_known_offset || 0)
             }
           ) do
      broadcast_upload_session(updated_session, :upload_session_uploading, %{
        offset: status.committed_bytes
      })

      {:ok,
       %{session: updated_session, committed_bytes: status.committed_bytes, state: status.state}}
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Cancels a resumable session through the adapter's session-scoped lifecycle.
  """
  @spec cancel_resumable_session(binary(), keyword()) :: cancel_resumable_result()
  def cancel_resumable_session(session_id, opts \\ []) do
    repo = Config.repo()
    started_at = System.monotonic_time(:microsecond)

    with %MediaUploadSession{} = session <- repo.get(MediaUploadSession, session_id),
         :ok <- SessionValidation.resumable(session),
         asset <- repo.preload(session, :asset).asset,
         {:ok, profile_module} <- SessionValidation.profile_module(asset.profile),
         adapter <- profile_module.storage_adapter(),
         :ok <- Capabilities.require_upload(adapter, :resumable_upload_session),
         {:ok, _result} <-
           adapter.cancel_resumable_upload(session.upload_key, session.session_uri, opts),
         :ok <- UploadSessionFSM.transition(session.state, "aborted", %{session_id: session.id}),
         {:ok, updated_session} <- Persistence.update(repo, session, %{state: "aborted"}),
         :ok <-
           ResumableTelemetry.emit_cancel(
             asset.profile,
             adapter,
             updated_session,
             %{outcome: :ok, source: Keyword.get(opts, :source, :user)},
             %{duration_us: System.monotonic_time(:microsecond) - started_at}
           ) do
      broadcast_upload_session(updated_session, :upload_session_cancelled)
      {:ok, %{session: updated_session}}
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Verifies that a direct upload was completed in storage.

  Transitions the session to `completed` and the asset to `validating`,
  then enqueues `PromoteAsset`. Emits
  `[:rindle, :upload, :stop]` telemetry AFTER the `Ecto.Multi` commits.

  ## Examples

      # Requires `config :rindle, :repo, MyApp.Repo`, the upload object to exist in storage, and the default `Oban` instance running.
      iex> {:ok, %{session: session, asset: asset}} =
      ...>   Rindle.Upload.Broker.verify_completion(session_id)
      iex> session.state
      "completed"
      iex> asset.state
      "validating"

  """
  @spec verify_completion(binary(), keyword()) :: verify_result()
  def verify_completion(session_id, opts \\ []) do
    repo = Config.repo()

    with %MediaUploadSession{} = session <- repo.get(MediaUploadSession, session_id),
         asset <- repo.preload(session, :asset).asset,
         {:ok, profile_module} <- SessionValidation.profile_module(asset.profile),
         adapter <- profile_module.storage_adapter(),
         # Check storage for object existence (Pitfall 5)
         {:ok, metadata} <- adapter.head(session.upload_key, opts),
         :ok <-
           UploadSessionFSM.transition(session.state, "verifying", %{session_id: session.id}),
         :ok <- AssetFSM.transition(asset.state, "validating", %{asset_id: asset.id}) do
      execute_verify_completion(repo, session, asset, profile_module, metadata)
    else
      nil -> {:error, :not_found}
      {:error, :not_found} -> {:error, :storage_object_missing}
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_verify_completion(repo, session, asset, profile_module, metadata) do
    case Completion.transact(repo, session, asset, metadata) do
      {:ok, %{session: updated_session, asset: updated_asset}} ->
        :telemetry.execute(
          [:rindle, :upload, :stop],
          %{system_time: System.system_time()},
          %{
            profile: asset.profile,
            adapter: profile_module.storage_adapter(),
            session_id: updated_session.id,
            asset_id: updated_asset.id
          }
        )

        if updated_session.upload_strategy == "resumable" do
          ResumableTelemetry.emit_stop(
            asset.profile,
            profile_module.storage_adapter(),
            updated_session,
            %{
              outcome: :ok,
              source: :verify_completion,
              protocol: resumable_protocol(updated_session)
            },
            %{committed_bytes: updated_asset.byte_size || updated_session.last_known_offset || 0}
          )
        end

        broadcast_upload_session(updated_session, :upload_session_completed)

        {:ok, %{session: updated_session, asset: updated_asset}}

      {:error, _name, reason, _changes} ->
        {:error, reason}
    end
  end

  defp ensure_session_marked_signed(_repo, %MediaUploadSession{state: "signed"} = session),
    do: {:ok, session}

  defp ensure_session_marked_signed(repo, %MediaUploadSession{} = session) do
    with :ok <- UploadSessionFSM.transition(session.state, "signed", %{session_id: session.id}),
         {:ok, updated_session} <- Persistence.update(repo, session, %{state: "signed"}) do
      {:ok, updated_session}
    end
  end

  defp emit_upload_start(profile_name, adapter, session_id) do
    :telemetry.execute(
      [:rindle, :upload, :start],
      %{system_time: System.system_time()},
      %{
        profile: profile_name,
        adapter: adapter,
        session_id: session_id
      }
    )
  end

  defp broadcast_upload_session(%MediaUploadSession{} = session, event_type, extra \\ %{}) do
    ensure_pubsub_started()

    payload =
      %{
        session_id: session.id,
        asset_id: session.asset_id,
        state: session.state,
        upload_strategy: session.upload_strategy,
        resumable_protocol: session.resumable_protocol
      }
      |> Map.merge(Map.take(extra, [:offset]))

    topics =
      ["rindle:admin:lifecycle", "rindle:upload_session:#{session.id}"]
      |> maybe_append_asset_topic(session.asset_id)

    Enum.each(topics, fn topic ->
      :ok = PubSub.broadcast(pubsub_server(), topic, {:rindle_event, event_type, payload})
    end)

    :ok
  end

  defp maybe_append_asset_topic(topics, asset_id) when is_binary(asset_id),
    do: topics ++ ["rindle:asset:#{asset_id}"]

  defp maybe_append_asset_topic(topics, _asset_id), do: topics

  defp ensure_pubsub_started do
    case Process.whereis(pubsub_server()) do
      nil -> :ok
      _pid -> :ok
    end
  end

  defp pubsub_server do
    Application.get_env(:rindle, :pubsub_server, Rindle.PubSub)
  end

  defp resumable_protocol(%MediaUploadSession{resumable_protocol: "tus"}), do: :tus
  defp resumable_protocol(_session), do: :gcs_native
end
