defmodule Rindle do
  alias Rindle.Domain.MediaAsset
  alias Rindle.Domain.MediaAttachment
  alias Rindle.Security.UploadValidation
  alias Rindle.Upload.Broker
  alias Rindle.Workers.PromoteAsset
  alias Rindle.Workers.PurgeStorage

  @moduledoc """
  Phoenix/Ecto-native media lifecycle library.

  Rindle manages the full post-upload lifecycle: upload sessions, staged object
  verification, asset modeling, attachment associations, variant/derivative
  generation, background processing, secure delivery, observability, and
  day-2 operations.
  """

  require Logger
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
  @spec initiate_upload(module(), keyword()) :: {:ok, map()} | {:error, term()}
  def initiate_upload(profile, opts \\ []) do
    Broker.initiate_session(profile, opts)
  end

  @doc """
  Initiates a multipart direct upload session through the broker.
  """
  @spec initiate_multipart_upload(module(), keyword()) :: {:ok, map()} | {:error, term()}
  def initiate_multipart_upload(profile, opts \\ []) do
    Broker.initiate_multipart_session(profile, opts)
  end

  @doc """
  Signs a single multipart upload part through the broker.
  """
  @spec sign_multipart_part(binary(), pos_integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def sign_multipart_part(session_id, part_number, opts \\ []) do
    Broker.sign_multipart_part(session_id, part_number, opts)
  end

  @doc """
  Completes a multipart upload through the broker and reuses upload verification.
  """
  @spec complete_multipart_upload(binary(), [map()], keyword()) :: {:ok, map()} | {:error, term()}
  def complete_multipart_upload(session_id, parts, opts \\ []) do
    Broker.complete_multipart_upload(session_id, parts, opts)
  end

  @doc """
  Verifies a direct upload completion through the broker.

  Delegates to `Broker.verify_completion/2`. Promotes the
  session to `completed` and the asset to `validating`.

  ## Examples

      # Requires a configured Rindle repo + the upload object to exist in storage.
      iex> {:ok, %{session: session, asset: asset}} = Rindle.verify_upload(session_id)
      iex> session.state
      "completed"
      iex> asset.state
      "validating"

  """
  @spec verify_upload(binary(), keyword()) :: {:ok, map()} | {:error, term()}
  def verify_upload(session_id, opts \\ []) do
    Broker.verify_completion(session_id, opts)
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
  @spec attach(struct() | binary(), struct(), String.t(), keyword()) ::
          {:ok, struct()} | {:error, term()}
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

  @doc """
  Generates a delivery URL for a variant, falling back when needed.

  Delegates to `Rindle.Delivery.variant_url/4`. Stale or non-ready variants
  fall back to the original asset URL per `Rindle.Domain.StalePolicy`.

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
  @spec upload(module(), map() | struct(), keyword()) :: {:ok, struct()} | {:error, term()}
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
        log_variant_processing_failure(asset_id, variant_name, reason)
        error
    end
  end

  @doc """
  Logs a structured storage processing failure for downstream observability.

  Emits an `:error`-level log with the literal message
  `"rindle.storage.variant_processing_failed"` and the contextual
  metadata keys `:asset_id`, `:variant_name`, and `:reason`. Operator
  dashboards alert on this exact message.

  ## Examples

      iex> Rindle.log_variant_processing_failure("asset-uuid", "thumb", :timeout)
      :ok

  """
  @spec log_variant_processing_failure(term(), term(), term()) :: :ok
  def log_variant_processing_failure(asset_id, variant_name, reason) do
    Logger.error("rindle.storage.variant_processing_failed",
      asset_id: asset_id,
      variant_name: variant_name,
      reason: reason
    )
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
