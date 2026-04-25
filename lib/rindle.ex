defmodule Rindle do
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
  """
  @spec version :: String.t()
  def version do
    Application.spec(:rindle, :vsn) |> to_string()
  end

  @doc """
  Initiates a direct upload session through the broker.
  """
  @spec initiate_upload(module(), keyword()) :: {:ok, map()} | {:error, term()}
  def initiate_upload(profile, opts \\ []) do
    Rindle.Upload.Broker.initiate_session(profile, opts)
  end

  @doc """
  Verifies a direct upload completion through the broker.
  """
  @spec verify_upload(binary(), keyword()) :: {:ok, map()} | {:error, term()}
  def verify_upload(session_id, opts \\ []) do
    Rindle.Upload.Broker.verify_completion(session_id, opts)
  end

  @doc """
  Resolves the storage adapter module for a given profile.
  """
  @spec storage_adapter_for(module()) :: module()
  def storage_adapter_for(profile) do
    profile.storage_adapter()
  end

  @doc """
  Stores an object through the profile-specific storage adapter.
  """
  @spec store(module(), String.t(), Path.t(), keyword()) :: storage_result()
  def store(profile, key, source_path, opts \\ []) do
    invoke_storage(profile, :store, [key, source_path, opts])
  end

  @doc """
  Attaches a MediaAsset to an owner at a specific slot.
  If an attachment already exists in that slot, it is replaced and the old asset is purged.
  """
  @spec attach(struct() | binary(), struct(), String.t(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def attach(asset_or_id, owner, slot, _opts \\ []) do
    asset_id = get_asset_id(asset_or_id)
    {owner_type, owner_id} = get_owner_info(owner)

    Ecto.Multi.new()
    |> Ecto.Multi.run(:existing, fn repo, _ ->
      existing = repo.one(from a in Rindle.Domain.MediaAttachment, 
        where: a.owner_type == ^owner_type and a.owner_id == ^owner_id and a.slot == ^slot)
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
      %Rindle.Domain.MediaAttachment{}
      |> Rindle.Domain.MediaAttachment.changeset(%{
        asset_id: asset_id,
        owner_type: owner_type,
        owner_id: owner_id,
        slot: slot
      })
    end)
    |> Ecto.Multi.run(:purge_old, fn _repo, %{existing: existing} ->
      if existing do
        old_asset = Rindle.Repo.get!(Rindle.Domain.MediaAsset, existing.asset_id)
        job = Rindle.Workers.PurgeStorage.new(%{
          "asset_id" => old_asset.id,
          "profile" => old_asset.profile
        })
        Oban.insert(job)
      else
        {:ok, nil}
      end
    end)
    |> Rindle.Repo.transaction()
    |> case do
      {:ok, %{attachment: attachment}} -> {:ok, attachment}
      {:error, _name, reason, _changes} -> {:error, reason}
    end
  end

  @doc """
  Detaches any MediaAsset from an owner at a specific slot and triggers a purge.
  """
  @spec detach(struct(), String.t(), keyword()) :: :ok | {:error, term()}
  def detach(owner, slot, _opts \\ []) do
    {owner_type, owner_id} = get_owner_info(owner)

    Ecto.Multi.new()
    |> Ecto.Multi.run(:existing, fn repo, _ ->
      existing = repo.one(from a in Rindle.Domain.MediaAttachment, 
        where: a.owner_type == ^owner_type and a.owner_id == ^owner_id and a.slot == ^slot)
      if existing, do: {:ok, existing}, else: {:error, :not_found}
    end)
    |> Ecto.Multi.delete(:attachment, fn %{existing: existing} -> existing end)
    |> Ecto.Multi.run(:purge, fn _repo, %{existing: existing} ->
      old_asset = Rindle.Repo.get!(Rindle.Domain.MediaAsset, existing.asset_id)
      job = Rindle.Workers.PurgeStorage.new(%{
        "asset_id" => old_asset.id,
        "profile" => old_asset.profile
      })
      Oban.insert(job)
    end)
    |> Rindle.Repo.transaction()
    |> case do
      {:ok, _} -> :ok
      {:error, :existing, :not_found, _} -> :ok # Idempotent
      {:error, _name, reason, _changes} -> {:error, reason}
    end
  end

  defp get_asset_id(%Rindle.Domain.MediaAsset{id: id}), do: id
  defp get_asset_id(id) when is_binary(id), do: id

  defp get_owner_info(%{__struct__: module, id: id}) do
    {to_string(module), id}
  end

  @doc """
  Downloads an object through the profile-specific storage adapter.
  """
  @spec download(module(), String.t(), Path.t(), keyword()) :: storage_result()
  def download(profile, key, destination_path, opts \\ []) do
    invoke_storage(profile, :download, [key, destination_path, opts])
  end

  @doc """
  Deletes an object through the profile-specific storage adapter.
  """
  @spec delete(module(), String.t(), keyword()) :: storage_result()
  def delete(profile, key, opts \\ []) do
    invoke_storage(profile, :delete, [key, opts])
  end

  @doc """
  Generates a delivery URL through the profile-specific storage adapter.
  """
  @spec url(module(), String.t(), keyword()) :: storage_result()
  def url(profile, key, opts \\ []) do
    invoke_storage(profile, :url, [key, opts])
  end

  @doc """
  Uploads a file directly through the server (proxied upload).

  Accepts a profile module and an upload (map or %Plug.Upload{}).
  The file is validated, stored, and a MediaAsset is created.
  """
  @spec upload(module(), map() | struct(), keyword()) :: {:ok, struct()} | {:error, term()}
  def upload(profile_module, upload, opts \\ []) do
    upload = normalize_upload(upload)
    profile_name = to_string(profile_module)
    asset_id = Ecto.UUID.generate()

    # Get policy from profile
    policy = profile_module.upload_policy()

    with {:ok, validation} <-
           Rindle.Security.UploadValidation.validate_for_promotion(
             upload,
             policy,
             profile_name,
             asset_id
           ),
         {:ok, _storage_meta} <- store(profile_module, validation.storage_key, upload.path, opts) do
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:asset, %Rindle.Domain.MediaAsset{id: asset_id}
      |> Rindle.Domain.MediaAsset.changeset(%{
        state: "analyzing",
        profile: profile_name,
        storage_key: validation.storage_key,
        filename: validation.sanitized_filename,
        content_type: validation.detected_mime,
        byte_size: upload.byte_size
      }))
      |> Oban.insert(:promote_job, Rindle.Workers.PromoteAsset.new(%{asset_id: asset_id}))
      |> Rindle.Repo.transaction()
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
  """
  @spec head(module(), String.t(), keyword()) :: storage_result()
  def head(profile, key, opts \\ []) do
    invoke_storage(profile, :head, [key, opts])
  end

  @doc """
  Generates a presigned PUT payload through the profile-specific storage adapter.
  """
  @spec presigned_put(module(), String.t(), pos_integer(), keyword()) :: storage_result()
  def presigned_put(profile, key, expires_in, opts \\ []) do
    invoke_storage(profile, :presigned_put, [key, expires_in, opts])
  end

  @doc """
  Executes variant storage and logs failures with required context metadata.
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
