defmodule Rindle.Ops.RuntimeStatus.Collector do
  @moduledoc false

  import Ecto.Query

  alias Oban.Job
  alias Rindle.Config
  alias Rindle.Domain.{MediaAsset, MediaProviderAsset, MediaUploadSession, MediaVariant}
  alias Rindle.Schema
  alias Rindle.Workers.ProcessVariant

  @queue_starved_age_seconds 5 * 60
  @image_orphan_age_seconds 15 * 60
  @provider_stuck_default_threshold_seconds 7200

  @doc false
  @spec collect(map(), DateTime.t(), NaiveDateTime.t() | nil, String.t()) :: map()
  def collect(filters, now, cutoff, oban_prefix) do
    runtime_checks = runtime_checks_report(filters, cutoff, now)
    variants = variant_report(filters, cutoff, now, oban_prefix)
    upload_sessions = upload_session_report(filters, cutoff, now)
    provider_assets = provider_assets_report(filters, now)

    %{
      runtime_checks: runtime_checks,
      assets: asset_report(filters),
      variants: variants,
      upload_sessions: upload_sessions,
      provider_assets: provider_assets
    }
  end

  defp runtime_checks_report(filters, cutoff, now) do
    rows =
      asset_probe_rows_query(filters, cutoff)
      |> rindle_all()
      |> Enum.map(&probe_drift_sample(&1, now))
      |> Enum.filter(& &1)

    %{counts: finding_counts(rows), findings: summarize_findings(rows, filters.limit)}
  end

  defp asset_report(filters) do
    counts =
      from(a in MediaAsset, select: {a.state, count(a.id)})
      |> maybe_filter_profile(:asset, filters.profile)
      |> group_by([a], a.state)
      |> rindle_all()
      |> count_map()

    %{counts: Map.put(counts, :total, Enum.sum(Map.values(counts)))}
  end

  defp variant_report(filters, cutoff, now, oban_prefix) do
    rows = variant_finding_rows_query(filters, cutoff) |> rindle_all()

    findings =
      rows
      |> classify_variants(oban_index(rows, oban_prefix), now)
      |> summarize_findings(filters.limit)

    counts =
      from(v in MediaVariant,
        join: a in MediaAsset,
        on: a.id == v.asset_id,
        select: {v.state, count(v.id)}
      )
      |> maybe_filter_profile(:variant, filters.profile)
      |> group_by([v, _a], v.state)
      |> rindle_all()
      |> count_map()

    %{counts: Map.put(counts, :total, Enum.sum(Map.values(counts))), findings: findings}
  end

  defp upload_session_report(filters, cutoff, now) do
    findings =
      upload_session_finding_rows_query(filters, cutoff)
      |> rindle_all()
      |> Enum.map(&upload_session_sample(&1, now))
      |> summarize_state_findings(filters.limit)

    counts =
      from(s in MediaUploadSession,
        join: a in MediaAsset,
        on: a.id == s.asset_id,
        select: {s.state, count(s.id)}
      )
      |> maybe_filter_profile(:upload_session, filters.profile)
      |> group_by([s, _a], s.state)
      |> rindle_all()
      |> count_map()

    %{
      counts: Map.put(counts, :total, Enum.sum(Map.values(counts))),
      findings: findings,
      resumable: resumable_session_summary(filters, now)
    }
  end

  defp resumable_session_summary(filters, now) do
    pending =
      from(s in MediaUploadSession,
        join: a in MediaAsset,
        on: a.id == s.asset_id,
        where: s.upload_strategy == "resumable",
        where: s.state in ["signed", "resuming", "uploading"],
        select: count(s.id)
      )
      |> maybe_filter_profile(:upload_session, filters.profile)
      |> rindle_one()

    expired =
      from(s in MediaUploadSession,
        join: a in MediaAsset,
        on: a.id == s.asset_id,
        where: s.upload_strategy == "resumable",
        where: not is_nil(s.session_uri_expires_at),
        where: s.session_uri_expires_at < ^now,
        select: count(s.id)
      )
      |> maybe_filter_profile(:upload_session, filters.profile)
      |> rindle_one()

    stale =
      from(s in MediaUploadSession,
        join: a in MediaAsset,
        on: a.id == s.asset_id,
        where: s.upload_strategy == "resumable",
        where: not is_nil(s.session_uri_expires_at),
        where: s.session_uri_expires_at < ^now,
        where: not is_nil(s.session_uri),
        select: count(s.id)
      )
      |> maybe_filter_profile(:upload_session, filters.profile)
      |> rindle_one()

    %{
      resumable_sessions_pending: pending || 0,
      resumable_sessions_expired: expired || 0,
      resumable_session_uris_stale: stale || 0
    }
  end

  defp provider_assets_report(filters, now) do
    threshold = effective_provider_stuck_threshold(filters)

    rows =
      if filters.provider_stuck do
        provider_assets_finding_rows_query(filters, threshold, now)
        |> rindle_all()
        |> Enum.map(&provider_asset_sample(&1, now))
      else
        []
      end

    counts =
      from(p in MediaProviderAsset, select: {p.state, count(p.id)})
      |> maybe_filter_provider_assets_profile(filters.profile)
      |> group_by([p], p.state)
      |> rindle_all()
      |> count_map()

    %{
      counts: Map.put(counts, :total, Enum.sum(Map.values(counts))),
      threshold_seconds: threshold,
      findings: summarize_findings(rows, filters.limit)
    }
  end

  defp effective_provider_stuck_threshold(%{older_than: value}) when is_integer(value), do: value

  defp effective_provider_stuck_threshold(_filters) do
    :rindle
    |> Application.get_env(Rindle.Streaming.Provider.Mux, [])
    |> Keyword.get(:provider_stuck_threshold_seconds, @provider_stuck_default_threshold_seconds)
  end

  defp provider_assets_finding_rows_query(filters, threshold_seconds, now) do
    cutoff = now |> DateTime.to_naive() |> NaiveDateTime.add(-threshold_seconds, :second)

    from(p in MediaProviderAsset,
      where: p.state in ["uploading", "processing"],
      where: p.updated_at < ^cutoff,
      select: %{
        asset_id: p.asset_id,
        provider_asset_id: p.provider_asset_id,
        profile: p.profile,
        provider_name: p.provider_name,
        state: p.state,
        updated_at: p.updated_at,
        last_event_at: p.last_event_at,
        last_sync_error: p.last_sync_error
      }
    )
    |> maybe_filter_provider_assets_profile(filters.profile)
  end

  defp maybe_filter_provider_assets_profile(query, nil), do: query

  defp maybe_filter_provider_assets_profile(query, profile),
    do: from(p in query, where: p.profile == ^profile)

  defp provider_asset_sample(row, now) do
    age = age_seconds(row.updated_at, now)

    %{
      class: :provider_stuck,
      age_seconds: age,
      sample: %{
        asset_id: row.asset_id,
        provider_asset_id: MediaProviderAsset.redact_id(row.provider_asset_id),
        profile: row.profile,
        provider: row.provider_name,
        state: row.state,
        updated_at: row.updated_at,
        last_event_at: row.last_event_at,
        last_sync_error: row.last_sync_error,
        reason: "row stuck in #{row.state} for #{age}s"
      }
    }
  end

  defp variant_finding_rows_query(filters, cutoff) do
    from(v in MediaVariant,
      join: a in MediaAsset,
      on: a.id == v.asset_id,
      where: v.state in ["failed", "cancelled", "stale", "missing", "queued", "processing"],
      select: %{
        asset_id: v.asset_id,
        asset_kind: a.kind,
        profile: a.profile,
        variant_id: v.id,
        variant_name: v.name,
        state: v.state,
        error_reason: v.error_reason,
        updated_at: v.updated_at
      }
    )
    |> maybe_filter_profile(:variant, filters.profile)
    |> maybe_filter_updated_at(cutoff)
  end

  defp asset_probe_rows_query(filters, cutoff) do
    from(a in MediaAsset,
      where: a.state in ["available", "ready", "degraded", "transcoding"],
      select: %{
        asset_id: a.id,
        state: a.state,
        kind: a.kind,
        content_type: a.content_type,
        width: a.width,
        height: a.height,
        duration_ms: a.duration_ms,
        has_video_track: a.has_video_track,
        has_audio_track: a.has_audio_track,
        updated_at: a.updated_at
      }
    )
    |> maybe_filter_profile(:asset, filters.profile)
    |> maybe_filter_updated_at(cutoff)
  end

  defp upload_session_finding_rows_query(filters, cutoff) do
    from(s in MediaUploadSession,
      join: a in MediaAsset,
      on: a.id == s.asset_id,
      where: s.state in ["expired", "failed"],
      select: %{
        session_id: s.id,
        asset_id: s.asset_id,
        state: s.state,
        failure_reason: s.failure_reason,
        expires_at: s.expires_at,
        updated_at: s.updated_at
      }
    )
    |> maybe_filter_profile(:upload_session, filters.profile)
    |> maybe_filter_upload_cutoff(cutoff)
  end

  defp classify_variants(rows, oban_index, now) do
    Enum.flat_map(rows, fn row ->
      case classify_variant(row, oban_index, now) do
        nil -> []
        finding -> [finding]
      end
    end)
  end

  defp classify_variant(row, oban_index, now) do
    key = {row.asset_id, row.variant_name}
    age = age_seconds(row.updated_at, now)
    active_states = Map.get(oban_index, key, MapSet.new())

    cond do
      row.state == "failed" ->
        variant_sample(:failed_work, row, age, "variant exhausted its retry budget")

      row.state == "cancelled" ->
        variant_sample(:cancelled_work, row, age, "variant was intentionally cancelled")

      row.state == "stale" ->
        variant_sample(:recipe_drift, row, age, "variant recipe digest drifted")

      row.state == "missing" ->
        variant_sample(:storage_drift, row, age, "variant storage object is missing")

      row.state == "queued" and age > @queue_starved_age_seconds and
          MapSet.disjoint?(active_states, MapSet.new(ProcessVariant.active_job_states())) ->
        variant_sample(:queue_starved, row, age, "queued variant lacks corroborating Oban job")

      row.state == "processing" and age > processing_threshold_seconds(row) and
          MapSet.disjoint?(active_states, MapSet.new([:executing, :retryable])) ->
        variant_sample(:orphan_suspect, row, age, "processing variant lacks executing Oban job")

      true ->
        nil
    end
  end

  defp oban_index([], _prefix), do: %{}

  defp oban_index(rows, prefix) do
    asset_ids = rows |> Enum.map(& &1.asset_id) |> Enum.uniq()
    names = rows |> Enum.map(& &1.variant_name) |> Enum.uniq()

    from(j in Job,
      where: j.worker == "Rindle.Workers.ProcessVariant",
      where: j.state in ^Enum.map(ProcessVariant.active_job_states(), &Atom.to_string/1),
      where: fragment("?->>'asset_id' = ANY(?)", j.args, ^asset_ids),
      where: fragment("?->>'variant_name' = ANY(?)", j.args, ^names),
      select:
        {fragment("?->>'asset_id'", j.args), fragment("?->>'variant_name'", j.args), j.state}
    )
    |> oban_all(prefix)
    |> Enum.reduce(%{}, fn {asset_id, variant_name, state}, acc ->
      key = {asset_id, variant_name}
      state = String.to_existing_atom(state)
      Map.update(acc, key, MapSet.new([state]), &MapSet.put(&1, state))
    end)
  end

  defp rindle_all(query), do: report_all(:rindle_all, query, Schema.prefix())
  defp rindle_one(query), do: report_one(query, Schema.prefix())
  defp oban_all(query, prefix), do: report_all(:oban_all, query, prefix)
  defp report_all(operation, query, prefix), do: dispatch_query(operation, query, prefix, :all)
  defp report_one(query, prefix), do: dispatch_query(:one, query, prefix, :one)

  defp dispatch_query(operation, query, prefix, repo_operation) do
    case report_query() do
      fun when is_function(fun, 3) -> fun.(operation, query, prefix)
      _other -> apply(Config.repo(), repo_operation, [query, [prefix: prefix]])
    end
  end

  defp report_query do
    :rindle |> Application.get_env(Rindle.Ops.RuntimeStatus, []) |> Keyword.get(:report_query)
  end

  defp processing_threshold_seconds(%{asset_kind: kind}) when kind in ["video", "audio"],
    do: max(div(ProcessVariant.av_timeout_ms() * 2, 1000), 20 * 60)

  defp processing_threshold_seconds(_row), do: @image_orphan_age_seconds

  defp probe_drift_sample(row, now) do
    case probe_drift_reason(row) do
      nil ->
        nil

      reason ->
        %{
          class: :probe_drift,
          age_seconds: age_seconds(row.updated_at, now),
          sample: %{asset_id: row.asset_id, state: row.state, kind: row.kind, reason: reason}
        }
    end
  end

  defp probe_drift_reason(%{kind: "video"} = row) do
    cond do
      mismatch_kind_and_content_type?(row.kind, row.content_type) ->
        "content type does not match persisted video kind"

      is_nil(row.duration_ms) or is_nil(row.width) or is_nil(row.height) or
          row.has_video_track != true ->
        "video asset is missing probe-owned AV fields"

      true ->
        nil
    end
  end

  defp probe_drift_reason(%{kind: "audio"} = row) do
    cond do
      mismatch_kind_and_content_type?(row.kind, row.content_type) ->
        "content type does not match persisted audio kind"

      is_nil(row.duration_ms) or row.has_audio_track != true ->
        "audio asset is missing probe-owned AV fields"

      true ->
        nil
    end
  end

  defp probe_drift_reason(%{kind: "image"} = row) do
    cond do
      mismatch_kind_and_content_type?(row.kind, row.content_type) ->
        "content type does not match persisted image kind"

      not is_nil(row.duration_ms) or not is_nil(row.has_video_track) or
          not is_nil(row.has_audio_track) ->
        "image asset still carries AV-only probe fields"

      true ->
        nil
    end
  end

  defp probe_drift_reason(_row), do: nil
  defp mismatch_kind_and_content_type?(_kind, nil), do: false
  defp mismatch_kind_and_content_type?("image", <<"audio/", _::binary>>), do: true
  defp mismatch_kind_and_content_type?("image", <<"video/", _::binary>>), do: true
  defp mismatch_kind_and_content_type?("audio", <<"image/", _::binary>>), do: true
  defp mismatch_kind_and_content_type?("video", <<"image/", _::binary>>), do: true
  defp mismatch_kind_and_content_type?(_kind, _content_type), do: false

  defp upload_session_sample(row, now) do
    reference_time = row.expires_at || row.updated_at

    %{
      state: row.state,
      age_seconds: age_seconds(reference_time, now),
      sample: %{
        session_id: row.session_id,
        asset_id: row.asset_id,
        state: row.state,
        failure_reason: row.failure_reason
      }
    }
  end

  defp summarize_findings(samples, limit) do
    samples
    |> Enum.group_by(& &1.class)
    |> Enum.sort_by(fn {class, _samples} -> Atom.to_string(class) end)
    |> Enum.map(fn {class, rows} ->
      sorted = Enum.sort_by(rows, &{-&1.age_seconds, &1.sample.asset_id})

      %{
        class: class,
        count: length(rows),
        oldest_age_seconds: hd(sorted).age_seconds,
        samples: sorted |> Enum.take(limit) |> Enum.map(& &1.sample)
      }
    end)
  end

  defp summarize_state_findings(samples, limit) do
    samples
    |> Enum.group_by(& &1.state)
    |> Enum.sort_by(fn {state, _samples} -> state end)
    |> Enum.map(fn {state, rows} ->
      sorted = Enum.sort_by(rows, &{-&1.age_seconds, &1.sample.asset_id})

      %{
        state: state,
        count: length(rows),
        oldest_age_seconds: hd(sorted).age_seconds,
        samples: sorted |> Enum.take(limit) |> Enum.map(& &1.sample)
      }
    end)
  end

  defp finding_counts(samples),
    do:
      samples
      |> Enum.group_by(& &1.class)
      |> Enum.map(fn {class, rows} -> {class, length(rows)} end)
      |> Enum.sort_by(fn {class, _count} -> Atom.to_string(class) end)
      |> Map.new()

  defp count_map(rows),
    do: rows |> Enum.map(fn {state, count} -> {String.to_atom(state), count} end) |> Map.new()

  defp variant_sample(class, row, age, reason),
    do: %{
      class: class,
      age_seconds: age,
      sample: %{
        asset_id: row.asset_id,
        variant_id: row.variant_id,
        variant_name: row.variant_name,
        state: row.state,
        reason: reason,
        error_reason: row.error_reason
      }
    }

  defp age_seconds(nil, _now), do: 0

  defp age_seconds(%NaiveDateTime{} = value, now),
    do: NaiveDateTime.diff(DateTime.to_naive(now), value, :second)

  defp age_seconds(%DateTime{} = value, now), do: DateTime.diff(now, value, :second)
  defp maybe_filter_profile(query, _scope, nil), do: query

  defp maybe_filter_profile(query, :asset, profile),
    do: from(a in query, where: a.profile == ^profile)

  defp maybe_filter_profile(query, scope, profile) when scope in [:variant, :upload_session],
    do: from([_row, a] in query, where: a.profile == ^profile)

  defp maybe_filter_updated_at(query, nil), do: query

  defp maybe_filter_updated_at(query, cutoff),
    do: from(row in query, where: row.updated_at <= ^cutoff)

  defp maybe_filter_upload_cutoff(query, nil), do: query

  defp maybe_filter_upload_cutoff(query, cutoff),
    do:
      from(s in query,
        where: s.updated_at <= ^cutoff or (not is_nil(s.expires_at) and s.expires_at <= ^cutoff)
      )
end
