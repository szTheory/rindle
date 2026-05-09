defmodule Rindle do
  alias Rindle.Domain.MediaAsset
  alias Rindle.Domain.MediaAttachment
  alias Rindle.Domain.MediaUploadSession
  alias Rindle.Domain.MediaVariant
  alias Rindle.Error
  alias Rindle.Internal.VariantFailureLogger
  alias Rindle.Ops.LifecycleRepair
  alias Rindle.Ops.RuntimeStatus
  alias Rindle.Security.UploadValidation
  alias Rindle.Upload.Broker
  alias Rindle.Workers.ProcessVariant
  alias Rindle.Workers.PromoteAsset
  alias Rindle.Workers.PurgeStorage

  @moduledoc """
  Phoenix/Ecto-native media lifecycle library.

  Rindle manages the full post-upload lifecycle: upload sessions, staged object
  verification, asset modeling, attachment associations, variant/derivative
  generation, background processing, secure delivery, observability, and
  day-2 operations.
  """

  import Ecto.Query

  @typedoc "Tagged storage result shape: {:ok, result} | {:error, reason}"
  @type storage_result :: {:ok, term()} | {:error, term()}

  @doc """
  Returns the current version of Rindle.

  ## Examples

      iex> is_binary(Rindle.version())
      true

  """
  @spec version :: String.t()
  def version do
    Application.spec(:rindle, :vsn) |> to_string()
  end

  @doc """
  Initiates a direct upload session through the broker.

  Delegates to `Broker.initiate_session/2`. Returns
  `{:ok, %MediaUploadSession{}}` on success.

  ## Examples

      # Requires `config :rindle, :repo, MyApp.Repo` and a configured profile module.
      iex> {:ok, session} = Rindle.initiate_upload(MyApp.MediaProfile, filename: "photo.png")
      iex> session.state
      "initialized"

  """
  @spec initiate_upload(module(), keyword()) :: {:ok, MediaUploadSession.t()} | {:error, term()}
  def initiate_upload(profile, opts \\ []) do
    Broker.initiate_session(profile, opts)
  end

  @doc """
  Initiates a multipart direct upload session through the broker.
  """
  @spec initiate_multipart_upload(module(), keyword()) :: Broker.initiate_multipart_result()
  def initiate_multipart_upload(profile, opts \\ []) do
    Broker.initiate_multipart_session(profile, opts)
  end

  @doc """
  Signs a single multipart upload part through the broker.
  """
  @spec sign_multipart_part(binary(), pos_integer(), keyword()) :: Broker.sign_part_result()
  def sign_multipart_part(session_id, part_number, opts \\ []) do
    Broker.sign_multipart_part(session_id, part_number, opts)
  end

  @doc """
  Completes a multipart upload through the broker and reuses upload verification.
  """
  @spec complete_multipart_upload(binary(), [map()], keyword()) :: Broker.verify_result()
  def complete_multipart_upload(session_id, parts, opts \\ []) do
    Broker.complete_multipart_upload(session_id, parts, opts)
  end

  @doc """
  Initiates a resumable upload session through the broker.
  """
  @spec initiate_resumable_session(module(), keyword()) :: Broker.initiate_resumable_result()
  def initiate_resumable_session(profile, opts \\ []) do
    Broker.initiate_resumable_session(profile, opts)
  end

  @doc """
  Polls the broker-owned resumable upload session without changing completion trust.
  """
  @spec resumable_session_status(binary(), keyword()) :: Broker.resumable_status_result()
  def resumable_session_status(session_id, opts \\ []) do
    Broker.resumable_session_status(session_id, opts)
  end

  @doc """
  Cancels a broker-owned resumable upload session.
  """
  @spec cancel_resumable_session(binary(), keyword()) :: Broker.cancel_resumable_result()
  def cancel_resumable_session(session_id, opts \\ []) do
    Broker.cancel_resumable_session(session_id, opts)
  end

  @doc """
  Verifies a direct upload completion through the broker.

  Delegates to `Broker.verify_completion/2`. Promotes the
  session to `completed` and the asset to `validating`.

  ## Examples

      # Requires a configured Rindle repo + the upload object to exist in storage.
      iex> {:ok, %{session: session, asset: asset}} = Rindle.verify_completion(session_id)
      iex> session.state
      "completed"
      iex> asset.state
      "validating"

  """
  @spec verify_completion(binary(), keyword()) :: Broker.verify_result()
  def verify_completion(session_id, opts \\ []) do
    Broker.verify_completion(session_id, opts)
  end

  @doc deprecated: "Use verify_completion/2"
  @doc """
  Verifies a direct upload completion through the broker.

  Legacy compatibility shim for `0.1.x`. Delegates to
  `verify_completion/2` while the older name remains supported.

  ## Examples

      # Requires a configured Rindle repo + the upload object to exist in storage.
      iex> {:ok, %{session: session, asset: asset}} = Rindle.verify_upload(session_id)
      iex> session.state
      "completed"
      iex> asset.state
      "validating"

  """
  @spec verify_upload(binary(), keyword()) :: Broker.verify_result()
  def verify_upload(session_id, opts \\ []) do
    verify_completion(session_id, opts)
  end

  @doc """
  Resolves the storage adapter module for a given profile.

  ## Examples

      # Requires a profile module that defines `storage_adapter/0`.
      iex> Rindle.storage_adapter_for(MyApp.MediaProfile)
      Rindle.Storage.Local

  """
  @spec storage_adapter_for(module()) :: module()
  def storage_adapter_for(profile) do
    profile.storage_adapter()
  end

  @doc """
  Stores an object through the profile-specific storage adapter.

  ## Examples

      # Requires a configured storage adapter and a readable source file.
      iex> {:ok, _meta} = Rindle.store(MyApp.MediaProfile, "uploads/abc.png", "/tmp/abc.png")
      iex> :ok
      :ok

  """
  @spec store(module(), String.t(), Path.t(), keyword()) :: storage_result()
  def store(profile, key, source_path, opts \\ []) do
    invoke_storage(profile, :store, [key, source_path, opts])
  end

  @doc """
  Attaches a MediaAsset to an owner at a specific slot.

  If an attachment already exists in that slot, it is replaced and the old
  asset is purged asynchronously via `PurgeStorage`.

  ## Examples

      # Requires a configured Rindle repo + an existing MediaAsset and owner record.
      iex> {:ok, attachment} = Rindle.attach(asset_id, %MyApp.User{id: user_id}, "avatar")
      iex> attachment.slot
      "avatar"

  """
  @spec attach(MediaAsset.t() | binary(), struct(), String.t(), keyword()) ::
          {:ok, MediaAttachment.t()} | {:error, term()}
  def attach(asset_or_id, owner, slot, _opts \\ []) do
    repo = Rindle.Config.repo()
    asset_id = get_asset_id(asset_or_id)
    {owner_type, owner_id} = get_owner_info(owner)

    Ecto.Multi.new()
    |> Ecto.Multi.run(:existing, fn repo, _ ->
      existing =
        repo.one(
          from a in MediaAttachment,
            where: a.owner_type == ^owner_type and a.owner_id == ^owner_id and a.slot == ^slot
        )

      {:ok, existing}
    end)
    |> Ecto.Multi.run(:detach_old, fn repo, %{existing: existing} ->
      if existing do
        repo.delete(existing)
      else
        {:ok, nil}
      end
    end)
    |> Ecto.Multi.insert(:attachment, fn _ ->
      %MediaAttachment{}
      |> MediaAttachment.changeset(%{
        asset_id: asset_id,
        owner_type: owner_type,
        owner_id: owner_id,
        slot: slot
      })
    end)
    |> Ecto.Multi.run(:old_asset, fn tx_repo, %{existing: existing} ->
      if existing do
        {:ok, tx_repo.get!(MediaAsset, existing.asset_id)}
      else
        {:ok, nil}
      end
    end)
    |> Ecto.Multi.merge(fn %{old_asset: old_asset} ->
      if old_asset do
        Ecto.Multi.new()
        |> Oban.insert(
          :purge_old,
          PurgeStorage.new(%{
            "asset_id" => old_asset.id,
            "profile" => old_asset.profile
          })
        )
      else
        Ecto.Multi.new()
      end
    end)
    |> repo.transaction()
    |> case do
      {:ok, %{attachment: attachment}} -> {:ok, attachment}
      {:error, _name, reason, _changes} -> {:error, reason}
    end
  end

  @doc """
  Detaches any MediaAsset from an owner at a specific slot and triggers a purge.

  Idempotent: returns `:ok` even when no attachment exists at the slot.

  ## Examples

      # Requires a configured Rindle repo + an existing attachment at owner+slot.
      iex> :ok = Rindle.detach(%MyApp.User{id: user_id}, "avatar")
      iex> :ok
      :ok

  """
  @spec detach(struct(), String.t(), keyword()) :: :ok | {:error, term()}
  def detach(owner, slot, _opts \\ []) do
    repo = Rindle.Config.repo()
    {owner_type, owner_id} = get_owner_info(owner)

    Ecto.Multi.new()
    |> Ecto.Multi.run(:existing, fn repo, _ ->
      existing =
        repo.one(
          from a in MediaAttachment,
            where: a.owner_type == ^owner_type and a.owner_id == ^owner_id and a.slot == ^slot
        )

      if existing, do: {:ok, existing}, else: {:error, :not_found}
    end)
    |> Ecto.Multi.run(:old_asset, fn tx_repo, %{existing: existing} ->
      {:ok, tx_repo.get!(MediaAsset, existing.asset_id)}
    end)
    |> Ecto.Multi.delete(:attachment, fn %{existing: existing} -> existing end)
    |> Oban.insert(
      :purge,
      fn %{old_asset: old_asset} ->
        PurgeStorage.new(%{
          "asset_id" => old_asset.id,
          "profile" => old_asset.profile
        })
      end
    )
    |> repo.transaction()
    |> case do
      {:ok, _} -> :ok
      # Idempotent
      {:error, :existing, :not_found, _} -> :ok
      {:error, _name, reason, _changes} -> {:error, reason}
    end
  end

  # Bang variants — Phase 19 (API-11).

  @doc "Same as `attach/4` but raises `Rindle.Error` on failure or re-raises the original exception for storage adapter exceptions. Database constraint failures (e.g., foreign-key violations) surface as `Rindle.Error` with the underlying changeset as the reason."
  @spec attach!(MediaAsset.t() | binary(), struct(), String.t()) :: MediaAttachment.t()
  @spec attach!(MediaAsset.t() | binary(), struct(), String.t(), keyword()) :: MediaAttachment.t()
  def attach!(asset_or_id, owner, slot, opts \\ []) do
    case attach(asset_or_id, owner, slot, opts) do
      {:ok, attachment} ->
        attachment

      {:error, {:storage_adapter_exception, exception}} when is_exception(exception) ->
        raise exception

      {:error, reason} ->
        raise Error, action: :attach, reason: reason
    end
  end

  @doc "Same as `detach/3` but raises `Rindle.Error` on failure."
  @spec detach!(struct(), String.t()) :: :ok
  @spec detach!(struct(), String.t(), keyword()) :: :ok
  def detach!(owner, slot, opts \\ []) do
    case detach(owner, slot, opts) do
      :ok ->
        :ok

      {:error, %Ecto.Changeset{} = cs} ->
        raise Ecto.InvalidChangesetError, action: :delete, changeset: cs

      {:error, {:storage_adapter_exception, exception}} when is_exception(exception) ->
        raise exception

      {:error, reason} ->
        raise Error, action: :detach, reason: reason
    end
  end

  # Convenience read helpers — Phase 19 (API-09 / API-10).

  @doc """
  Fetches the most recent `MediaAttachment` for an `(owner, slot)` pair.

  Returns the attachment row with `:asset` preloaded by default, or `nil`
  when no attachment exists at the slot. Pass `preload: <list>` to override
  the default preload (the override **replaces** `[:asset]` rather than
  merging — pass `preload: [asset: :variants]` to extend, `preload: []` to
  disable preloading entirely).

  When multiple attachment rows exist for the same `(owner, slot)` (possible
  because the join schema enforces uniqueness only at the application level
  via `attach/4`'s last-write-wins replacement), the most-recent row by
  `:inserted_at` is returned.

  This helper does **not** issue a write or a side-effect query; it is safe
  to call in render paths.

  ## Examples

      # Requires a configured Rindle repo + an existing owner record.
      iex> attachment = Rindle.attachment_for(%MyApp.User{id: user_id}, "avatar")
      iex> attachment && attachment.slot
      "avatar"

  """
  @spec attachment_for(struct(), String.t()) :: MediaAttachment.t() | nil
  @spec attachment_for(struct(), String.t(), keyword()) :: MediaAttachment.t() | nil
  def attachment_for(owner, slot, opts \\ []) do
    repo = Rindle.Config.repo()
    {owner_type, owner_id} = get_owner_info(owner)
    preloads = Keyword.get(opts, :preload, [:asset])

    query =
      from a in MediaAttachment,
        where: a.owner_type == ^owner_type and a.owner_id == ^owner_id and a.slot == ^slot,
        order_by: [desc: a.inserted_at],
        limit: 1

    case repo.one(query) do
      nil -> nil
      attachment -> repo.preload(attachment, preloads)
    end
  end

  @doc """
  Lists `MediaVariant` rows in the `"ready"` state for a given asset.

  Accepts either a `%MediaAsset{}` struct or a binary asset id. Returns a
  list of variants ordered by `:name` ascending; returns `[]` when no
  variants are ready. The unique constraint on `(asset_id, name)` makes the
  ordering deterministic.

  Only variants in the `"ready"` state are returned — variants in
  `"planned"`, `"queued"`, `"processing"`, `"stale"`, `"missing"`,
  `"failed"`, or `"purged"` are excluded. Adopters wanting fallback
  behavior should call `variant_url/4`, which already orchestrates the
  stale-policy fallback.

  ## Examples

      # Requires a configured Rindle repo + at least one ready variant row.
      iex> variants = Rindle.ready_variants_for(asset)
      iex> Enum.all?(variants, &(&1.state == "ready"))
      true

  """
  @spec ready_variants_for(MediaAsset.t() | binary()) :: [MediaVariant.t()]
  def ready_variants_for(asset_or_id) do
    repo = Rindle.Config.repo()
    asset_id = get_asset_id(asset_or_id)

    repo.all(
      from v in MediaVariant,
        where: v.asset_id == ^asset_id and v.state == "ready",
        order_by: [asc: v.name]
    )
  end

  @doc """
  Cancels active variant processing for an asset.

  Returns `:ok` when the asset has queued or executing variant work that can be
  cancelled. Returns `{:error, :not_processing}` when the asset has no queued
  or executing variant work.

  The public surface remains asset-scoped; callers do not need to know variant
  ids, job ids, or Oban internals to stop in-flight processing.

  ## Examples

      iex> Rindle.cancel_processing(asset_id)
      :ok

      iex> Rindle.cancel_processing("missing-or-idle-asset")
      {:error, :not_processing}

  """
  @spec cancel_processing(MediaAsset.t() | binary()) :: :ok | {:error, :not_processing}
  def cancel_processing(asset_or_id) do
    asset_or_id
    |> get_asset_id()
    |> ProcessVariant.cancel_processing()
  end

  @doc """
  Reruns probe detection for an asset and persists only probe-derived fields.

  Accepts either a `%MediaAsset{}` struct or a binary asset id. Reprobe is
  asset-scoped and refreshes only `content_type`, `kind`, `width`, `height`,
  `duration_ms`, `has_video_track`, and `has_audio_track`; fields that no
  longer apply are cleared explicitly, while unrelated lifecycle state and
  ownership data stay untouched.

  Returns `{:ok, report}` on a completed probe refresh and `{:error, reason}`
  when the run could not be completed.

  ## Examples

      iex> {:ok, report} = Rindle.reprobe(asset_id)
      iex> report.kind
      "image"

  """
  @spec reprobe(MediaAsset.t() | binary()) ::
          {:ok, LifecycleRepair.reprobe_report()} | {:error, term()}
  def reprobe(asset_or_id) do
    LifecycleRepair.reprobe_asset(asset_or_id)
  end

  @doc """
  Requeues failed or cancelled variants for a single asset.

  Accepts either a `%MediaAsset{}` struct or a binary asset id. By default,
  only this asset's variants currently in `failed` or `cancelled` state are
  targeted. Pass `variant_names: [...]` to narrow the repair to explicit
  variant names; unknown names fail loudly, and already-ready siblings stay
  untouched.

  Returns `{:ok, report}` after the enqueue attempt finishes, including
  deterministic counters for selected, enqueued, skipped, and errored
  variants. Equivalent in-flight jobs are counted as skipped through Oban
  uniqueness rather than double-enqueued.

  ## Examples

      iex> {:ok, report} = Rindle.requeue_variants(asset_id)
      iex> report.enqueued
      1

      iex> {:ok, report} = Rindle.requeue_variants(asset_id, variant_names: ["thumb"])
      iex> report.selected
      1

  """
  @spec requeue_variants(MediaAsset.t() | binary(), keyword() | map()) ::
          {:ok, LifecycleRepair.requeue_report()} | {:error, term()}
  def requeue_variants(asset_or_id, opts \\ []) do
    LifecycleRepair.requeue_failed_variants(asset_or_id, opts)
  end

  @doc """
  Returns a bounded runtime diagnostics report for operators.

  The report is read-only and groups lifecycle drift, stuck work, and upload
  residue into a stable map shape with counts, oldest age, and bounded
  examples. Supported filters are intentionally narrow: `:profile`,
  `:older_than`, `:limit`, and `:format`.

  ## Examples

      iex> {:ok, report} = Rindle.runtime_status(limit: 3)
      iex> is_map(report.variants)
      true

  """
  @spec runtime_status(keyword() | map()) :: {:ok, map()} | {:error, term()}
  def runtime_status(opts \\ []) do
    RuntimeStatus.runtime_status(opts)
  end

  defp get_asset_id(%MediaAsset{id: id}), do: id
  defp get_asset_id(id) when is_binary(id), do: id

  defp get_owner_info(%{__struct__: module, id: id}) do
    {to_string(module), id}
  end

  @doc """
  Downloads an object through the profile-specific storage adapter.

  ## Examples

      # Requires a configured storage adapter and an existing object.
      iex> {:ok, _meta} = Rindle.download(MyApp.MediaProfile, "uploads/abc.png", "/tmp/abc.png")
      iex> :ok
      :ok

  """
  @spec download(module(), String.t(), Path.t(), keyword()) :: storage_result()
  def download(profile, key, destination_path, opts \\ []) do
    invoke_storage(profile, :download, [key, destination_path, opts])
  end

  @doc """
  Deletes an object through the profile-specific storage adapter.

  ## Examples

      # Requires a configured storage adapter.
      iex> {:ok, _} = Rindle.delete(MyApp.MediaProfile, "uploads/abc.png")
      iex> :ok
      :ok

  """
  @spec delete(module(), String.t(), keyword()) :: storage_result()
  def delete(profile, key, opts \\ []) do
    invoke_storage(profile, :delete, [key, opts])
  end

  @doc """
  Generates a delivery URL through the profile-specific storage adapter.

  Delegates to `Rindle.Delivery.url/3` so policy (public vs. signed) is honored.

  ## Examples

      # Requires a configured storage adapter and a key that exists in storage.
      iex> {:ok, url} = Rindle.url(MyApp.MediaProfile, "uploads/abc.png")
      iex> is_binary(url)
      true

  """
  @spec url(module(), String.t(), keyword()) :: storage_result()
  def url(profile, key, opts \\ []) do
    Rindle.Delivery.url(profile, key, opts)
  end

  @doc "Same as `url/3` but raises `Rindle.Error` on failure or re-raises the original exception for storage adapter exceptions."
  @spec url!(module(), String.t()) :: String.t()
  @spec url!(module(), String.t(), keyword()) :: String.t()
  def url!(profile, key, opts \\ []) do
    case url(profile, key, opts) do
      {:ok, url_string} ->
        url_string

      {:error, %Ecto.Changeset{} = cs} ->
        raise Ecto.InvalidChangesetError, action: :insert, changeset: cs

      {:error, {:storage_adapter_exception, exception}} when is_exception(exception) ->
        raise exception

      {:error, reason} ->
        raise Error, action: :url, reason: reason
    end
  end

  @doc """
  Generates a delivery URL for a variant, falling back when needed.

  Delegates to `Rindle.Delivery.variant_url/4`. Stale or non-ready variants
  fall back to the original asset URL per the configured stale-serving policy.

  ## Examples

      # Requires a configured storage adapter and ready/stale variant rows.
      iex> {:ok, url} = Rindle.variant_url(MyApp.MediaProfile, asset, variant)
      iex> is_binary(url)
      true

  """
  @spec variant_url(module(), map(), map(), keyword()) :: storage_result()
  def variant_url(profile, asset, variant, opts \\ []) do
    Rindle.Delivery.variant_url(profile, asset, variant, opts)
  end

  @doc "Same as `variant_url/4` but raises `Rindle.Error` on failure or re-raises the original exception for storage adapter exceptions."
  @spec variant_url!(module(), map(), map()) :: String.t()
  @spec variant_url!(module(), map(), map(), keyword()) :: String.t()
  def variant_url!(profile, asset, variant, opts \\ []) do
    case variant_url(profile, asset, variant, opts) do
      {:ok, url_string} ->
        url_string

      {:error, %Ecto.Changeset{} = cs} ->
        raise Ecto.InvalidChangesetError, action: :insert, changeset: cs

      {:error, {:storage_adapter_exception, exception}} when is_exception(exception) ->
        raise exception

      {:error, reason} ->
        raise Error, action: :variant_url, reason: reason
    end
  end

  @doc """
  Uploads a file directly through the server (proxied upload).

  Accepts a profile module and an upload (map or `%Plug.Upload{}`).
  The file is validated against the profile's `upload_policy/0`, stored
  via the profile's storage adapter, and a `MediaAsset` row is inserted
  in the `analyzing` state.

  ## Examples

      # Requires a configured Rindle repo + a configured storage adapter + a Plug.Upload.
      iex> {:ok, asset} = Rindle.upload(MyApp.MediaProfile, %Plug.Upload{path: "/tmp/x.png", filename: "x.png"})
      iex> asset.state
      "analyzing"

  """
  @spec upload(module(), map() | Plug.Upload.t(), keyword()) ::
          {:ok, MediaAsset.t()} | {:error, term()}
  def upload(profile_module, upload, opts \\ []) do
    repo = Rindle.Config.repo()
    upload = normalize_upload(upload)
    profile_name = to_string(profile_module)
    asset_id = Ecto.UUID.generate()

    # Get policy from profile
    policy = profile_module.upload_policy()

    with {:ok, validation} <-
           UploadValidation.validate_for_promotion(
             upload,
             policy,
             profile_name,
             asset_id
           ),
         {:ok, _storage_meta} <- store(profile_module, validation.storage_key, upload.path, opts) do
      Ecto.Multi.new()
      |> Ecto.Multi.insert(
        :asset,
        %MediaAsset{id: asset_id}
        |> MediaAsset.changeset(%{
          state: "analyzing",
          profile: profile_name,
          storage_key: validation.storage_key,
          filename: validation.sanitized_filename,
          content_type: validation.detected_mime,
          byte_size: upload.byte_size
        })
      )
      |> Oban.insert(:promote_job, PromoteAsset.new(%{asset_id: asset_id}))
      |> repo.transaction()
      |> case do
        {:ok, %{asset: asset}} -> {:ok, asset}
        {:error, _name, reason, _changes} -> {:error, reason}
      end
    else
      {:error, {:quarantine, reason}} ->
        # Handle quarantine (Pitfall 2)
        # For now, we return the error
        {:error, {:quarantine, reason}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Same as `upload/3` but raises `Rindle.Error` on failure, `Ecto.InvalidChangesetError` for changeset failures, or re-raises the original exception for storage adapter exceptions."
  @spec upload!(module(), map() | Plug.Upload.t()) :: MediaAsset.t()
  @spec upload!(module(), map() | Plug.Upload.t(), keyword()) :: MediaAsset.t()
  def upload!(profile_module, upload, opts \\ []) do
    case upload(profile_module, upload, opts) do
      {:ok, asset} ->
        asset

      {:error, %Ecto.Changeset{} = cs} ->
        raise Ecto.InvalidChangesetError, action: :insert, changeset: cs

      {:error, {:storage_adapter_exception, exception}} when is_exception(exception) ->
        raise exception

      {:error, reason} ->
        raise Error, action: :upload, reason: reason
    end
  end

  @doc """
  Checks for object existence through the profile-specific storage adapter.

  ## Examples

      # Requires a configured storage adapter.
      iex> {:ok, _meta} = Rindle.head(MyApp.MediaProfile, "uploads/abc.png")
      iex> :ok
      :ok

  """
  @spec head(module(), String.t(), keyword()) :: storage_result()
  def head(profile, key, opts \\ []) do
    invoke_storage(profile, :head, [key, opts])
  end

  @doc """
  Generates a presigned PUT payload through the profile-specific storage adapter.

  ## Examples

      # Requires an S3-compatible storage adapter with :presigned_put capability.
      iex> {:ok, %{url: url}} = Rindle.presigned_put(MyApp.MediaProfile, "uploads/abc.png", 3600)
      iex> is_binary(url)
      true

  """
  @spec presigned_put(module(), String.t(), pos_integer(), keyword()) :: storage_result()
  def presigned_put(profile, key, expires_in, opts \\ []) do
    invoke_storage(profile, :presigned_put, [key, expires_in, opts])
  end

  @doc """
  Executes variant storage and logs failures with required context metadata.

  Wraps `store/4` with structured failure logging that captures the
  `asset_id` and `variant_name` for observability dashboards.

  ## Examples

      # Requires a configured storage adapter.
      iex> {:ok, _meta} = Rindle.store_variant(MyApp.MediaProfile, "variants/abc-thumb.png", "/tmp/abc-thumb.png", asset_id: asset_id, variant_name: "thumb")
      iex> :ok
      :ok

  """
  @spec store_variant(module(), String.t(), Path.t(), keyword()) :: storage_result()
  def store_variant(profile, key, source_path, opts \\ []) do
    asset_id = Keyword.get(opts, :asset_id)
    variant_name = Keyword.get(opts, :variant_name)
    adapter_opts = Keyword.drop(opts, [:asset_id, :variant_name])

    case store(profile, key, source_path, adapter_opts) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} = error ->
        VariantFailureLogger.log(asset_id, variant_name, reason)
        error
    end
  end

  @deprecated "Use Rindle.Internal.VariantFailureLogger.log/3 instead — facade shim kept for 0.1.x compatibility only"
  @doc false
  @spec log_variant_processing_failure(term(), term(), term()) :: :ok
  def log_variant_processing_failure(asset_id, variant_name, reason) do
    VariantFailureLogger.log(asset_id, variant_name, reason)
  end

  defp invoke_storage(profile, function_name, args) do
    adapter = storage_adapter_for(profile)

    try do
      normalize_storage_result(apply(adapter, function_name, args))
    rescue
      exception ->
        {:error, {:storage_adapter_exception, exception}}
    end
  end

  defp normalize_storage_result({:ok, _result} = result), do: result
  defp normalize_storage_result({:error, _reason} = result), do: result
  defp normalize_storage_result(other), do: {:error, {:invalid_storage_response, other}}

  defp normalize_upload(%{__struct__: Plug.Upload} = upload) do
    %{
      path: upload.path,
      filename: upload.filename,
      content_type: upload.content_type,
      byte_size: File.stat!(upload.path).size
    }
  end

  defp normalize_upload(upload) when is_map(upload) do
    # Ensure byte_size is present if path is given
    if Map.has_key?(upload, :path) and not Map.has_key?(upload, :byte_size) do
      Map.put(upload, :byte_size, File.stat!(upload.path).size)
    else
      upload
    end
  end
end
