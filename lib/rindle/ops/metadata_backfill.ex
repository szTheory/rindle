defmodule Rindle.Ops.MetadataBackfill do
  @moduledoc """
  Shared service for backfilling metadata on existing media assets.

  Iterates assets in backfillable states, downloads each source file, reruns
  the configured analyzer, and persists the updated metadata back to the asset
  record.

  Only analyst output is persisted — raw media bytes and other secrets are never
  logged (T-04-07 mitigation).

  ## Design

  Storage side effects (downloads) are intentionally kept outside DB transactions
  per the Rindle security invariant. Per-asset failures are accumulated and
  surfaced in the report rather than aborting the entire run. Operators can detect
  problems via the returned report and the non-zero exit from the Mix task.

  ## Backfillable States

  Assets in `ready`, `available`, and `degraded` states are eligible. Assets in
  terminal or in-progress states (`staged`, `validating`, `analyzing`,
  `promoting`, `processing`, `quarantined`, `deleted`) are skipped because they
  are either not yet promoted or are in active use by the pipeline.
  """

  require Logger

  import Ecto.Query

  alias Rindle.Domain.MediaAsset
  alias Rindle.Repo

  @backfillable_states ["ready", "available", "degraded"]

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type backfill_report :: %{
          assets_found: non_neg_integer(),
          assets_updated: non_neg_integer(),
          failures: non_neg_integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Reruns the analyzer for all eligible assets and persists updated metadata.

  Downloads each asset's source from storage, analyzes it, and writes the
  resulting metadata map back to `media_assets.metadata`. Only assets in
  `ready`, `available`, or `degraded` states are processed.

  ## Options

    * `:storage` (module) — storage adapter used to download source files.
      Must implement the `Rindle.Storage` behaviour. Required.
    * `:analyzer` (module) — analyzer module to use. Must implement the
      `Rindle.Analyzer` behaviour. Required.
    * `:profile` (string) — when provided, restricts backfill to assets whose
      `profile` field matches this string exactly.

  ## Returns

    * `{:ok, backfill_report()}` on success — per-asset failures are counted
      in the `:failures` field rather than short-circuiting the run, so
      operators get a full picture.
    * `{:error, reason}` reserved for catastrophic conditions (e.g. eligible-
      asset query failure). Callers MUST handle this clause defensively even
      if the current implementation does not yet exercise it.

  ## Examples

      iex> Rindle.Ops.MetadataBackfill.backfill_metadata(
      ...>   storage: MyApp.Storage,
      ...>   analyzer: Rindle.Analyzer.Image
      ...> )
      {:ok, %{assets_found: 42, assets_updated: 40, failures: 2}}
  """
  @spec backfill_metadata(keyword()) :: {:ok, backfill_report()} | {:error, term()}
  def backfill_metadata(opts) when is_list(opts) do
    storage_mod = Keyword.fetch!(opts, :storage)
    analyzer_mod = Keyword.fetch!(opts, :analyzer)
    profile_filter = Keyword.get(opts, :profile)

    assets = fetch_eligible_assets(profile_filter)

    base_report = %{
      assets_found: length(assets),
      assets_updated: 0,
      failures: 0
    }

    report =
      Enum.reduce(assets, base_report, fn asset, acc ->
        backfill_asset(asset, storage_mod, analyzer_mod, acc)
      end)

    {:ok, report}
  end

  # ---------------------------------------------------------------------------
  # Private — query helpers
  # ---------------------------------------------------------------------------

  @spec fetch_eligible_assets(String.t() | nil) :: [MediaAsset.t()]
  defp fetch_eligible_assets(nil) do
    query = from(a in MediaAsset, where: a.state in @backfillable_states, select: a)

    try do
      Repo.all(query)
    rescue
      e ->
        Logger.error("rindle.metadata_backfill.query_failed", reason: inspect(e))
        []
    end
  end

  defp fetch_eligible_assets(profile) when is_binary(profile) do
    query =
      from(a in MediaAsset,
        where: a.state in @backfillable_states,
        where: a.profile == ^profile,
        select: a
      )

    try do
      Repo.all(query)
    rescue
      e ->
        Logger.error("rindle.metadata_backfill.query_failed",
          profile: profile,
          reason: inspect(e)
        )

        []
    end
  end

  # ---------------------------------------------------------------------------
  # Private — per-asset processing
  # ---------------------------------------------------------------------------

  defp backfill_asset(asset, storage_mod, analyzer_mod, acc) do
    tmp_path = Path.join(System.tmp_dir!(), "rindle_backfill_#{Ecto.UUID.generate()}")

    # WR-01: keep cleanup_temp/1 in `after` so a raise inside the analyzer or
    # any other helper still removes the temp file, AND wrap in try/rescue so
    # the per-asset failure is counted and the rest of the run continues
    # (matching the moduledoc contract that promises per-asset failures are
    # accumulated rather than aborting the run).
    result =
      try do
        with {:ok, _path} <- download_source(storage_mod, asset.storage_key, tmp_path),
             {:ok, metadata} <- analyze_source(analyzer_mod, tmp_path),
             {:ok, _updated} <- persist_metadata(asset, metadata) do
          :updated
        else
          {:error, reason} ->
            Logger.warning("rindle.metadata_backfill.asset_failed",
              asset_id: asset.id,
              storage_key: asset.storage_key,
              reason: inspect(reason)
            )

            :failed
        end
      rescue
        e ->
          Logger.warning("rindle.metadata_backfill.asset_raised",
            asset_id: asset.id,
            storage_key: asset.storage_key,
            kind: e.__struct__,
            message: Exception.message(e)
          )

          :failed
      after
        cleanup_temp(tmp_path)
      end

    case result do
      :updated -> Map.update!(acc, :assets_updated, &(&1 + 1))
      :failed -> Map.update!(acc, :failures, &(&1 + 1))
    end
  end

  defp download_source(storage_mod, key, tmp_path) do
    storage_mod.download(key, tmp_path, [])
  end

  defp analyze_source(analyzer_mod, path) do
    analyzer_mod.analyze(path)
  end

  defp persist_metadata(asset, metadata) do
    asset
    |> MediaAsset.changeset(%{metadata: metadata})
    |> Repo.update()
  end

  defp cleanup_temp(path) do
    File.rm(path)
    :ok
  end
end
