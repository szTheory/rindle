defmodule AdoptionDemo.Media do
  @moduledoc false

  import Ecto.Query

  alias AdoptionDemo.Accounts.Member
  alias AdoptionDemo.Cohort.{Lesson, Post}
  alias AdoptionDemo.Repo
  alias Rindle.Domain.{MediaAsset, MediaVariant}
  alias Rindle.Error

  def list_assets do
    Repo.all(from a in MediaAsset, order_by: [desc: a.inserted_at], limit: 50)
  end

  def get_asset!(id), do: Repo.get!(MediaAsset, id)

  def attachment_for(%Member{} = member, slot), do: Rindle.attachment_for(member, slot_name(slot))
  def attachment_for(%Lesson{} = lesson, slot), do: Rindle.attachment_for(lesson, slot_name(slot))
  def attachment_for(%Post{} = post, slot), do: Rindle.attachment_for(post, slot_name(slot))

  def attach!(owner, asset_id, slot) do
    Rindle.attach!(asset_id, owner, slot_name(slot))
  end

  def detach!(owner, slot) do
    Rindle.detach!(owner, slot_name(slot))
  end

  def variants_for(asset_id) do
    Repo.all(from v in MediaVariant, where: v.asset_id == ^asset_id, order_by: v.name)
  end

  def delivery_url(profile, storage_key) do
    Rindle.url(profile, storage_key)
  end

  def streaming_url(profile, asset) do
    case Rindle.Delivery.streaming_url(profile, asset) do
      {:ok, %{url: url}} -> {:ok, url}
      {:ok, url} when is_binary(url) -> {:ok, url}
      other -> other
    end
  end

  def preview_owner_erasure(%Member{} = member) do
    case Rindle.preview_owner_erasure(member) do
      {:ok, report} -> report
      {:error, reason} -> raise Error, action: :preview_owner_erasure, reason: reason
    end
  end

  def erase_owner!(%Member{} = member) do
    case Rindle.erase_owner(member) do
      {:ok, report} -> report
      {:error, reason} -> raise Error, action: :erase_owner, reason: reason
    end
  end

  def preview_batch_erasure(members) do
    case Rindle.preview_batch_owner_erasure(members) do
      {:ok, report} -> report
      {:error, reason} -> raise Error, action: :preview_batch_owner_erasure, reason: reason
    end
  end

  def erase_batch!(members) do
    case Rindle.erase_batch_owner_erasure(members) do
      {:ok, report} -> report
      {:error, reason} -> raise Error, action: :erase_batch_owner_erasure, reason: reason
    end
  end

  def await_streaming_url(profile, asset_id, attempts \\ 60) do
    asset = get_asset!(asset_id)

    case streaming_url(profile, asset) do
      {:ok, url} when is_binary(url) ->
        {:ok, url}

      _ when attempts > 0 ->
        try do
          Oban.drain_queue(queue: :rindle_promote, with_safety: false)
          Oban.drain_queue(queue: :rindle_process, with_safety: false)
          Oban.drain_queue(queue: :rindle_media, with_safety: false)
        rescue
          _ -> :ok
        end

        Process.sleep(200)
        await_streaming_url(profile, asset_id, attempts - 1)

      _ ->
        {:error, :timeout}
    end
  end

  def asset_for_attachment(%{asset_id: asset_id}) when is_binary(asset_id) do
    Repo.get(MediaAsset, asset_id)
  end

  def asset_for_attachment(_), do: nil

  defp slot_name(slot) when is_atom(slot), do: Atom.to_string(slot)
  defp slot_name(slot) when is_binary(slot), do: slot
end
