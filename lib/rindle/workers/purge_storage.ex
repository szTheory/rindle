defmodule Rindle.Workers.PurgeStorage do
  @moduledoc """
  Oban worker responsible for deleting media assets and their variants from storage.
  This is an idempotent operation; missing objects are handled gracefully.
  """
  use Oban.Worker, queue: :rindle_purge, max_attempts: 3

  alias Rindle.Domain.{MediaAsset, MediaVariant}
  alias Rindle.Repo
  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"asset_id" => asset_id, "profile" => profile_name}}) do
    profile_module = String.to_existing_atom(profile_name)

    # 1. Collect all storage keys to delete
    # We load variants before potentially deleting the asset from DB
    variant_keys =
      Repo.all(from v in MediaVariant, where: v.asset_id == ^asset_id, select: v.storage_key)

    asset = Repo.get(MediaAsset, asset_id)
    source_key = if asset, do: asset.storage_key, else: nil

    # 2. Execute deletions
    Enum.each(variant_keys, fn key ->
      if key, do: Rindle.delete(profile_module, key)
    end)

    if source_key do
      Rindle.delete(profile_module, source_key)
    end

    # 3. Cleanup DB records if they still exist
    # This ensures that the purge is complete.
    if asset do
      Repo.delete!(asset)
    end

    :ok
  end
end
