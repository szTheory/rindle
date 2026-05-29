defmodule AdoptionDemo.Media do
  @moduledoc false

  import Ecto.Query

  alias AdoptionDemo.Accounts.User
  alias AdoptionDemo.Repo
  alias AdoptionDemo.RindleProfile
  alias Rindle.Domain.{MediaAsset, MediaVariant}
  alias Rindle.Error

  def list_assets do
    Repo.all(from a in MediaAsset, order_by: [desc: a.inserted_at], limit: 50)
  end

  def get_asset!(id), do: Repo.get!(MediaAsset, id)

  def attachment_for(%User{} = user, slot) do
    Rindle.attachment_for(user, slot_name(slot))
  end

  def attach!(%User{} = user, asset_id, slot) do
    Rindle.attach!(asset_id, user, slot_name(slot))
  end

  def detach!(%User{} = user, slot) do
    Rindle.detach!(user, slot_name(slot))
  end

  def variants_for(asset_id) do
    Repo.all(from v in MediaVariant, where: v.asset_id == ^asset_id, order_by: v.name)
  end

  def delivery_url(storage_key) do
    Rindle.url(RindleProfile, storage_key)
  end

  def preview_owner_erasure(%User{} = user) do
    case Rindle.preview_owner_erasure(user) do
      {:ok, report} -> report
      {:error, reason} -> raise Error, action: :preview_owner_erasure, reason: reason
    end
  end

  def erase_owner!(%User{} = user) do
    case Rindle.erase_owner(user) do
      {:ok, report} -> report
      {:error, reason} -> raise Error, action: :erase_owner, reason: reason
    end
  end

  defp slot_name(slot) when is_atom(slot), do: Atom.to_string(slot)
  defp slot_name(slot) when is_binary(slot), do: slot
end
