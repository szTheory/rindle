defmodule Rindle.Internal.OwnerErasure do
  @moduledoc false

  import Ecto.Query

  alias Ecto.Multi
  alias Rindle.Config
  alias Rindle.Domain.{MediaAsset, MediaAttachment}
  alias Rindle.Workers.PurgeStorage

  @type owner_info :: {String.t(), Ecto.UUID.t()}

  @spec preview(struct(), keyword()) :: {:ok, map()} | {:error, term()}
  def preview(owner, _opts \\ []) do
    repo = Config.repo()

    owner
    |> owner_info()
    |> planner_query(repo)
    |> build_plan()
    |> build_report(mode: :preview, purge_enqueued: 0, purge_already_queued: 0)
    |> then(&{:ok, &1})
  end

  @spec execute(struct(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(owner, _opts \\ []) do
    repo = Config.repo()
    owner_info = owner_info(owner)

    Multi.new()
    |> Multi.run(:plan, fn tx_repo, _changes ->
      {:ok, owner_info |> planner_query(tx_repo) |> build_plan()}
    end)
    |> Ecto.Multi.delete_all(:detach_attachments, fn %{plan: plan} ->
      attachment_ids = Enum.map(plan.attachments_to_detach.entries, & &1.attachment_id)

      from(attachment in MediaAttachment, where: attachment.id in ^attachment_ids)
    end)
    |> Multi.merge(fn %{plan: plan} ->
      Enum.with_index(plan.assets_to_purge.entries)
      |> Enum.reduce(Multi.new(), fn {%{asset_id: asset_id, profile: profile}, index}, multi ->
        Oban.insert(multi, {:purge_asset, index}, purge_job(asset_id, profile))
      end)
    end)
    |> repo.transaction()
    |> case do
      {:ok, changes} ->
        {purge_enqueued, purge_already_queued} = summarize_purge_results(changes)

        changes.plan
        |> build_report(
          mode: :execute,
          purge_enqueued: purge_enqueued,
          purge_already_queued: purge_already_queued
        )
        |> then(&{:ok, &1})

      {:error, _step, reason, _changes} ->
        {:error, reason}
    end
  end

  defp planner_query({owner_type, owner_id}, repo) do
    repo.all(
      from attachment in MediaAttachment,
        join: asset in MediaAsset,
        on: asset.id == attachment.asset_id,
        left_join: surviving in MediaAttachment,
        on:
          surviving.asset_id == attachment.asset_id and
            not (surviving.owner_type == ^owner_type and surviving.owner_id == ^owner_id),
        where: attachment.owner_type == ^owner_type and attachment.owner_id == ^owner_id,
        group_by: [attachment.id, attachment.asset_id, attachment.slot, asset.profile],
        select: %{
          attachment_id: attachment.id,
          asset_id: attachment.asset_id,
          slot: attachment.slot,
          profile: asset.profile,
          surviving_attachment_count: count(surviving.id, :distinct)
        }
    )
  end

  defp build_plan(rows) do
    attachments =
      Enum.map(rows, fn row ->
        %{
          attachment_id: row.attachment_id,
          asset_id: row.asset_id,
          slot: row.slot
        }
      end)

    assets =
      rows
      |> Enum.reduce(%{}, fn row, acc ->
        Map.put_new(acc, row.asset_id, %{
          asset_id: row.asset_id,
          profile: row.profile,
          surviving_attachment_count: row.surviving_attachment_count
        })
      end)
      |> Map.values()
      |> Enum.sort_by(& &1.asset_id)

    assets_to_purge =
      Enum.map(Enum.filter(assets, &(&1.surviving_attachment_count == 0)), fn asset ->
        %{asset_id: asset.asset_id, profile: asset.profile}
      end)

    retained_shared_assets =
      Enum.map(Enum.filter(assets, &(&1.surviving_attachment_count > 0)), fn asset ->
        %{
          asset_id: asset.asset_id,
          profile: asset.profile,
          surviving_attachment_count: asset.surviving_attachment_count
        }
      end)

    %{
      attachments_to_detach: bucket(attachments),
      assets_to_purge: bucket(assets_to_purge),
      retained_shared_assets: bucket(retained_shared_assets)
    }
  end

  defp build_report(plan, opts) do
    %{
      mode: Keyword.fetch!(opts, :mode),
      attachments_to_detach: plan.attachments_to_detach,
      assets_to_purge: plan.assets_to_purge,
      retained_shared_assets: plan.retained_shared_assets,
      purge_enqueued: Keyword.fetch!(opts, :purge_enqueued),
      purge_already_queued: Keyword.fetch!(opts, :purge_already_queued)
    }
  end

  defp summarize_purge_results(changes) do
    Enum.reduce(changes, {0, 0}, fn
      {{:purge_asset, _index}, %Oban.Job{conflict?: true}}, {enqueued, already_queued} ->
        {enqueued, already_queued + 1}

      {{:purge_asset, _index}, %Oban.Job{}}, {enqueued, already_queued} ->
        {enqueued + 1, already_queued}

      _, acc ->
        acc
    end)
  end

  defp purge_job(asset_id, profile) do
    PurgeStorage.new(
      %{"asset_id" => asset_id, "profile" => profile},
      unique: [
        fields: [:args, :worker, :queue],
        keys: [:asset_id, :profile],
        states: [:available, :scheduled, :executing, :retryable],
        period: :infinity
      ]
    )
  end

  defp bucket(entries), do: %{count: length(entries), entries: entries}

  defp owner_info(%{__struct__: module, id: id}), do: {to_string(module), id}
end
