defmodule Rindle.Ops.RuntimeStatus do
  @moduledoc false

  import Ecto.Query

  alias Oban.Job
  alias Rindle.Config
  alias Rindle.Domain.{MediaAsset, MediaUploadSession, MediaVariant}
  alias Rindle.Workers.ProcessVariant

  @allowed_filter_keys [:profile, :older_than, :limit, :format]
  @default_limit 5
  @queue_starved_age_seconds 5 * 60
  @image_orphan_age_seconds 15 * 60

  @type filters :: %{
          profile: String.t() | nil,
          older_than: non_neg_integer() | nil,
          limit: pos_integer(),
          format: :text | :json
        }

  @type report :: %{
          generated_at: DateTime.t(),
          filters: filters(),
          runtime_checks: map(),
          assets: map(),
          variants: map(),
          upload_sessions: map(),
          recommendations: [map()]
        }

  @spec runtime_status(keyword() | map()) :: {:ok, report()} | {:error, term()}
  def runtime_status(opts \\ []) do
    with {:ok, filters} <- normalize_filters(opts) do
      now = DateTime.utc_now()
      cutoff = older_than_cutoff(now, filters.older_than)

      {:ok,
       %{
         generated_at: now,
         filters: filters,
         runtime_checks: runtime_checks_report(filters, cutoff, now),
         assets: asset_report(filters),
         variants: variant_report(filters, cutoff, now),
         upload_sessions: upload_session_report(filters, cutoff, now),
         recommendations: recommendations(filters, cutoff, now)
       }}
    else
      {:error, reason} = error ->
        emit_runtime_refusal(reason)
        error
    end
  end

  defp runtime_checks_report(filters, cutoff, now) do
    rows =
      asset_probe_rows_query(filters, cutoff)
      |> Config.repo().all()
      |> Enum.map(&probe_drift_sample(&1, now))
      |> Enum.filter(& &1)

    %{
      counts: finding_counts(rows),
      findings: summarize_findings(rows, filters.limit)
    }
  end

  defp asset_report(filters) do
    counts =
      from(a in MediaAsset,
        select: {a.state, count(a.id)}
      )
      |> maybe_filter_profile(:asset, filters.profile)
      |> group_by([a], a.state)
      |> Config.repo().all()
      |> count_map()

    %{counts: Map.put(counts, :total, Enum.sum(Map.values(counts)))}
  end

  defp variant_report(filters, cutoff, now) do
    rows =
      variant_finding_rows_query(filters, cutoff)
      |> Config.repo().all()

    findings =
      rows
      |> classify_variants(oban_index(rows), now)
      |> summarize_findings(filters.limit)

    counts =
      from(v in MediaVariant,
        join: a in MediaAsset,
        on: a.id == v.asset_id,
        select: {v.state, count(v.id)}
      )
      |> maybe_filter_profile(:variant, filters.profile)
      |> group_by([v, _a], v.state)
      |> Config.repo().all()
      |> count_map()

    %{
      counts: Map.put(counts, :total, Enum.sum(Map.values(counts))),
      findings: findings
    }
  end

  defp upload_session_report(filters, cutoff, now) do
    findings =
      upload_session_finding_rows_query(filters, cutoff)
      |> Config.repo().all()
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
      |> Config.repo().all()
      |> count_map()

    %{
      counts: Map.put(counts, :total, Enum.sum(Map.values(counts))),
      findings: findings
    }
  end

  defp recommendations(filters, cutoff, now) do
    report_classes =
      runtime_checks_report(filters, cutoff, now).findings
      |> Enum.map(& &1.class)

    variant_classes =
      variant_report(filters, cutoff, now).findings
      |> Enum.map(& &1.class)

    upload_states =
      upload_session_report(filters, cutoff, now).findings
      |> Enum.map(& &1.state)

    (report_classes ++ variant_classes)
    |> Enum.uniq()
    |> Enum.map(&recommendation_for_class/1)
    |> Enum.reject(&is_nil/1)
    |> Kernel.++(upload_recommendations(upload_states))
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
    age_seconds = age_seconds(row.updated_at, now)
    active_states = Map.get(oban_index, key, MapSet.new())

    cond do
      row.state == "failed" ->
        variant_sample(:failed_work, row, age_seconds, "variant exhausted its retry budget")

      row.state == "cancelled" ->
        variant_sample(:cancelled_work, row, age_seconds, "variant was intentionally cancelled")

      row.state == "stale" ->
        variant_sample(:recipe_drift, row, age_seconds, "variant recipe digest drifted")

      row.state == "missing" ->
        variant_sample(:storage_drift, row, age_seconds, "variant storage object is missing")

      row.state == "queued" and age_seconds > @queue_starved_age_seconds and
          MapSet.disjoint?(active_states, MapSet.new(ProcessVariant.active_job_states())) ->
        variant_sample(:queue_starved, row, age_seconds, "queued variant lacks corroborating Oban job")

      row.state == "processing" and age_seconds > processing_threshold_seconds(row) and
          MapSet.disjoint?(active_states, MapSet.new([:executing, :retryable])) ->
        variant_sample(:orphan_suspect, row, age_seconds, "processing variant lacks executing Oban job")

      true ->
        nil
    end
  end

  defp oban_index([]), do: %{}

  defp oban_index(rows) do
    asset_ids = Enum.map(rows, & &1.asset_id) |> Enum.uniq()
    names = Enum.map(rows, & &1.variant_name) |> Enum.uniq()

    from(j in Job,
      where: j.worker == "Rindle.Workers.ProcessVariant",
      where: j.state in ^Enum.map(ProcessVariant.active_job_states(), &Atom.to_string/1),
      where: fragment("?->>'asset_id' = ANY(?)", j.args, ^asset_ids),
      where: fragment("?->>'variant_name' = ANY(?)", j.args, ^names),
      select: {fragment("?->>'asset_id'", j.args), fragment("?->>'variant_name'", j.args), j.state}
    )
    |> Config.repo().all()
    |> Enum.reduce(%{}, fn {asset_id, variant_name, state}, acc ->
      key = {asset_id, variant_name}
      state_atom = String.to_existing_atom(state)
      Map.update(acc, key, MapSet.new([state_atom]), &MapSet.put(&1, state_atom))
    end)
  end

  defp processing_threshold_seconds(%{asset_kind: kind}) when kind in ["video", "audio"] do
    max(div(ProcessVariant.av_timeout_ms() * 2, 1000), 20 * 60)
  end

  defp processing_threshold_seconds(_row), do: @image_orphan_age_seconds

  defp probe_drift_sample(row, now) do
    case probe_drift_reason(row) do
      nil ->
        nil

      reason ->
        %{
          class: :probe_drift,
          age_seconds: age_seconds(row.updated_at, now),
          sample: %{
            asset_id: row.asset_id,
            state: row.state,
            kind: row.kind,
            reason: reason
          }
        }
    end
  end

  defp probe_drift_reason(%{kind: "video"} = row) do
    cond do
      mismatch_kind_and_content_type?(row.kind, row.content_type) ->
        "content type does not match persisted video kind"

      is_nil(row.duration_ms) or is_nil(row.width) or is_nil(row.height) or row.has_video_track != true ->
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

      not is_nil(row.duration_ms) or not is_nil(row.has_video_track) or not is_nil(row.has_audio_track) ->
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
    |> Enum.sort_by(fn {class, _} -> Atom.to_string(class) end)
    |> Enum.map(fn {class, rows} ->
      sorted = Enum.sort_by(rows, &{-&1.age_seconds, inspect(&1.sample)})

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
    |> Enum.sort_by(fn {state, _} -> state end)
    |> Enum.map(fn {state, rows} ->
      sorted = Enum.sort_by(rows, &{-&1.age_seconds, inspect(&1.sample)})

      %{
        state: state,
        count: length(rows),
        oldest_age_seconds: hd(sorted).age_seconds,
        samples: sorted |> Enum.take(limit) |> Enum.map(& &1.sample)
      }
    end)
  end

  defp recommendation_for_class(:probe_drift) do
    %{
      class: :probe_drift,
      action: :reprobe,
      surface: "Rindle.reprobe/1",
      summary: "Refresh probe-owned fields for affected assets."
    }
  end

  defp recommendation_for_class(class)
       when class in [:failed_work, :cancelled_work, :queue_starved, :orphan_suspect] do
    %{
      class: class,
      action: :requeue,
      surface: "Rindle.requeue_variants/2",
      summary: "Requeue affected failed or stuck asset-scoped variant work after confirming the root cause."
    }
  end

  defp recommendation_for_class(class) when class in [:recipe_drift, :storage_drift] do
    %{
      class: class,
      action: :regenerate,
      surface: "mix rindle.regenerate_variants",
      summary: "Run the broad regeneration lane for stale or missing derivatives."
    }
  end

  defp recommendation_for_class(_class), do: nil

  defp upload_recommendations(states) do
    if "expired" in states do
      [
        %{
          class: :expired_upload_sessions,
          action: :cleanup,
          surface: "mix rindle.abort_incomplete_uploads && mix rindle.cleanup_orphans",
          summary: "Expire timed-out sessions first, then clean up their staged upload residue."
        }
      ]
    else
      []
    end
  end

  defp finding_counts(samples) do
    samples
    |> Enum.group_by(& &1.class)
    |> Enum.map(fn {class, rows} -> {class, length(rows)} end)
    |> Enum.sort_by(fn {class, _count} -> Atom.to_string(class) end)
    |> Map.new()
  end

  defp count_map(rows) do
    rows
    |> Enum.map(fn {state, count} -> {String.to_atom(state), count} end)
    |> Map.new()
  end

  defp variant_sample(class, row, age_seconds, reason) do
    %{
      class: class,
      age_seconds: age_seconds,
      sample: %{
        asset_id: row.asset_id,
        variant_id: row.variant_id,
        variant_name: row.variant_name,
        state: row.state,
        reason: reason,
        error_reason: row.error_reason
      }
    }
  end

  defp age_seconds(nil, _now), do: 0

  defp age_seconds(%NaiveDateTime{} = timestamp, now) do
    NaiveDateTime.diff(DateTime.to_naive(now), timestamp, :second)
  end

  defp age_seconds(%DateTime{} = timestamp, now) do
    DateTime.diff(now, timestamp, :second)
  end

  defp older_than_cutoff(_now, nil), do: nil

  defp older_than_cutoff(now, older_than) do
    now
    |> DateTime.to_naive()
    |> NaiveDateTime.add(-older_than, :second)
  end

  defp maybe_filter_profile(query, _scope, nil), do: query

  defp maybe_filter_profile(query, :asset, profile) do
    from a in query, where: a.profile == ^profile
  end

  defp maybe_filter_profile(query, scope, profile) when scope in [:variant, :upload_session] do
    from [_record, a] in query, where: a.profile == ^profile
  end

  defp maybe_filter_updated_at(query, nil), do: query
  defp maybe_filter_updated_at(query, cutoff) do
    from r in query, where: r.updated_at <= ^cutoff
  end

  defp maybe_filter_upload_cutoff(query, nil), do: query

  defp maybe_filter_upload_cutoff(query, cutoff) do
    from s in query, where: s.updated_at <= ^cutoff or (not is_nil(s.expires_at) and s.expires_at <= ^cutoff)
  end

  defp normalize_filters(opts) when is_list(opts) do
    opts
    |> Enum.into(%{})
    |> normalize_filters()
  end

  defp normalize_filters(opts) when is_map(opts) do
    with {:ok, normalized} <- normalize_filter_keys(opts),
         :ok <- validate_filter_keys(normalized),
         {:ok, profile} <- normalize_profile(Map.get(normalized, :profile)),
         {:ok, older_than} <- normalize_older_than(Map.get(normalized, :older_than)),
         {:ok, limit} <- normalize_limit(Map.get(normalized, :limit)),
         {:ok, format} <- normalize_format(Map.get(normalized, :format)) do
      {:ok, %{profile: profile, older_than: older_than, limit: limit, format: format}}
    end
  end

  defp normalize_filters(_opts), do: {:error, {:invalid_filters, :expected_keyword_or_map}}

  defp normalize_filter_keys(opts) do
    normalized =
      Enum.reduce(opts, %{}, fn
        {key, value}, acc when key in @allowed_filter_keys ->
          Map.put(acc, key, value)

        {"profile", value}, acc ->
          Map.put(acc, :profile, value)

        {"older_than", value}, acc ->
          Map.put(acc, :older_than, value)

        {"limit", value}, acc ->
          Map.put(acc, :limit, value)

        {"format", value}, acc ->
          Map.put(acc, :format, value)

        {key, value}, acc ->
          Map.put(acc, key, value)
      end)

    {:ok, normalized}
  end

  defp validate_filter_keys(opts) do
    case Map.keys(opts) -- @allowed_filter_keys do
      [] -> :ok
      unknown -> {:error, {:unknown_filters, unknown}}
    end
  end

  defp normalize_profile(nil), do: {:ok, nil}
  defp normalize_profile(profile) when is_binary(profile), do: {:ok, profile}
  defp normalize_profile(profile), do: {:error, {:invalid_profile, profile}}

  defp normalize_older_than(nil), do: {:ok, nil}
  defp normalize_older_than(value) when is_integer(value) and value >= 0, do: {:ok, value}
  defp normalize_older_than(value), do: {:error, {:invalid_older_than, value}}

  defp normalize_limit(nil), do: {:ok, @default_limit}
  defp normalize_limit(value) when is_integer(value) and value > 0, do: {:ok, value}
  defp normalize_limit(value), do: {:error, {:invalid_limit, value}}

  defp normalize_format(nil), do: {:ok, :text}
  defp normalize_format(:text), do: {:ok, :text}
  defp normalize_format(:json), do: {:ok, :json}
  defp normalize_format("text"), do: {:ok, :text}
  defp normalize_format("json"), do: {:ok, :json}
  defp normalize_format(value), do: {:error, {:invalid_format, value}}

  defp emit_runtime_refusal(reason) do
    :telemetry.execute(
      [:rindle, :runtime, :refusal],
      %{system_time: System.system_time()},
      %{surface: :runtime_status, reason: refusal_reason(reason), mode: :api}
    )
  end

  defp refusal_reason({reason, _details}) when is_atom(reason), do: reason
  defp refusal_reason(reason) when is_atom(reason), do: reason
  defp refusal_reason(_reason), do: :invalid_request
end
