defmodule Rindle.Admin.Queries do
  @moduledoc false

  import Ecto.Query

  alias Rindle.Config

  alias Rindle.Domain.{
    MediaAsset,
    MediaAttachment,
    MediaProcessingRun,
    MediaProviderAsset,
    MediaUploadSession,
    MediaVariant
  }

  alias Rindle.Ops.{RuntimeChecks, RuntimeStatus}

  @asset_filter_keys [:state, :profile, :kind, :limit, :cursor]
  @upload_session_filter_keys [:state, :profile, :strategy, :limit, :cursor]
  @variants_jobs_filter_keys [:state, :profile, :class, :older_than, :limit, :provider_stuck]
  @default_limit 25
  @redacted_session_uri "Redacted by Rindle Admin"
  @redacted_provider_id "Provider identifier redacted"

  @spec home_status(keyword() | map()) :: {:ok, map()} | {:error, term()}
  def home_status(opts) do
    opts = Enum.into(opts, %{})
    runtime_opts = Map.get(opts, :runtime_opts, [])
    doctor_opts = Map.get(opts, :doctor_opts, [])
    profiles = Map.get(opts, :profiles, [])

    with {:ok, runtime_status} <- RuntimeStatus.runtime_status(runtime_opts) do
      doctor = RuntimeChecks.run(profile_args(profiles), doctor_opts)

      {:ok,
       %{
         generated_at: DateTime.utc_now(),
         runtime_status: runtime_status,
         doctor: doctor,
         counts: %{
           assets: runtime_status.assets.counts,
           variants: runtime_status.variants.counts,
           upload_sessions: runtime_status.upload_sessions.counts,
           provider_assets: runtime_status.provider_assets.counts
         },
         recommendations: runtime_status.recommendations
       }}
    end
  end

  @spec assets(keyword() | map()) :: {:ok, map()} | {:error, term()}
  def assets(opts) do
    with {:ok, filters} <- normalize_filters(opts, @asset_filter_keys) do
      rows =
        from(a in MediaAsset,
          order_by: [desc: a.inserted_at, desc: a.id],
          limit: ^filters.limit
        )
        |> maybe_filter(:state, filters.state)
        |> maybe_filter(:profile, filters.profile)
        |> maybe_filter(:kind, filters.kind)
        |> maybe_cursor(filters.cursor)
        |> Config.repo().all()
        |> Enum.map(&asset_row/1)

      {:ok,
       %{
         generated_at: DateTime.utc_now(),
         filters: public_filters(filters),
         limit: filters.limit,
         rows: rows
       }}
    end
  end

  @spec asset_detail(Ecto.UUID.t()) :: {:ok, map()} | {:error, term()}
  def asset_detail(asset_id) when is_binary(asset_id) do
    case Config.repo().get(MediaAsset, asset_id) do
      nil ->
        {:error, :not_found}

      asset ->
        {:ok,
         %{
           generated_at: DateTime.utc_now(),
           asset: asset_row(asset),
           attachments: attachment_rows(asset.id),
           variants: variant_rows(asset.id),
           upload_sessions: upload_session_rows(asset.id),
           processing_runs: processing_run_rows(asset.id),
           provider_assets: provider_asset_rows(asset.id)
         }}
    end
  end

  @spec upload_sessions(keyword() | map()) :: {:ok, map()} | {:error, term()}
  def upload_sessions(opts) do
    with {:ok, filters} <- normalize_filters(opts, @upload_session_filter_keys) do
      rows =
        from(s in MediaUploadSession,
          join: a in MediaAsset,
          on: a.id == s.asset_id,
          order_by: [desc: s.inserted_at, desc: s.id],
          limit: ^filters.limit,
          select: {s, a.profile}
        )
        |> maybe_filter_upload_state(filters.state)
        |> maybe_filter_joined_profile(filters.profile)
        |> maybe_filter_upload_strategy(filters.strategy)
        |> maybe_cursor_upload(filters.cursor)
        |> Config.repo().all()
        |> Enum.map(fn {session, profile} -> upload_session_row(session, profile) end)

      {:ok,
       %{
         generated_at: DateTime.utc_now(),
         filters: public_filters(filters),
         limit: filters.limit,
         rows: rows
       }}
    end
  end

  @spec upload_session_detail(Ecto.UUID.t()) :: {:ok, map()} | {:error, term()}
  def upload_session_detail(session_id) when is_binary(session_id) do
    query =
      from(s in MediaUploadSession,
        join: a in MediaAsset,
        on: a.id == s.asset_id,
        where: s.id == ^session_id,
        select: {s, a.profile}
      )

    case Config.repo().one(query) do
      nil ->
        {:error, :not_found}

      {session, profile} ->
        {:ok,
         %{
           generated_at: DateTime.utc_now(),
           upload_session: upload_session_row(session, profile),
           asset: asset_detail_row(session.asset_id)
         }}
    end
  end

  @spec variants_jobs(keyword() | map()) :: {:ok, map()} | {:error, term()}
  def variants_jobs(opts) do
    with {:ok, filters} <- normalize_filters(opts, @variants_jobs_filter_keys),
         {:ok, runtime_status} <- RuntimeStatus.runtime_status(runtime_status_opts(filters)) do
      findings =
        runtime_status.variants.findings
        |> maybe_filter_finding_class(filters.class)
        |> maybe_filter_finding_state(filters.state)

      {:ok,
       %{
         generated_at: DateTime.utc_now(),
         filters: public_filters(filters),
         runtime_status: runtime_status,
         counts: runtime_status.variants.counts,
         findings: findings,
         recommendations: runtime_status.recommendations
       }}
    end
  end

  @spec runtime_doctor(keyword() | map()) :: {:ok, map()} | {:error, term()}
  def runtime_doctor(opts) do
    opts = Enum.into(opts, %{})
    runtime_opts = Map.get(opts, :runtime_opts, [])
    doctor_opts = Map.get(opts, :doctor_opts, [])
    profiles = Map.get(opts, :profiles, [])

    with {:ok, runtime_status} <- RuntimeStatus.runtime_status(runtime_opts) do
      {:ok,
       %{
         generated_at: DateTime.utc_now(),
         doctor: RuntimeChecks.run(profile_args(profiles), doctor_opts),
         runtime_status: runtime_status
       }}
    end
  end

  @spec actions_directory() :: {:ok, map()}
  def actions_directory do
    {:ok,
     %{
       generated_at: DateTime.utc_now(),
       actions: [
         action(:owner_erasure, "Owner erasure", "Preview and erase one owner's attachments."),
         action(:batch_erasure, "Batch erasure", "Preview and erase multiple owners."),
         action(
           :variant_regeneration,
           "Variant regeneration",
           "Regenerate stale or missing derivatives."
         ),
         action(
           :quarantine_review,
           "Quarantine review",
           "Review quarantined assets and route to supported deletion or erasure paths."
         ),
         action(:lifecycle_repair, "Lifecycle repair", "Repair lifecycle drift after diagnosis.")
       ]
     }}
  end

  defp action(id, label, summary) do
    %{
      id: id,
      label: label,
      summary: summary,
      enabled?: false,
      phase: 90,
      read_only?: true
    }
  end

  defp normalize_filters(opts, allowed_keys) when is_list(opts) do
    opts
    |> Enum.into(%{})
    |> normalize_filters(allowed_keys)
  end

  defp normalize_filters(opts, allowed_keys) when is_map(opts) do
    normalized = normalize_filter_keys(opts, allowed_keys)

    with :ok <- validate_filter_keys(normalized, allowed_keys),
         {:ok, limit} <- normalize_limit(Map.get(normalized, :limit)) do
      {:ok,
       allowed_keys
       |> Map.new(fn key -> {key, Map.get(normalized, key)} end)
       |> Map.put(:limit, limit)}
    end
  end

  defp normalize_filters(_opts, _allowed_keys), do: {:error, {:invalid_filters, :expected_map}}

  defp normalize_filter_keys(opts, allowed_keys) do
    string_to_atom =
      allowed_keys
      |> Map.new(fn key -> {Atom.to_string(key), key} end)

    Map.new(opts, fn
      {key, value} when is_atom(key) -> {key, value}
      {key, value} when is_binary(key) -> {Map.get(string_to_atom, key, key), value}
    end)
  end

  defp validate_filter_keys(opts, allowed_keys) do
    case Map.keys(opts) -- allowed_keys do
      [] -> :ok
      unknown -> {:error, {:unknown_filters, unknown}}
    end
  end

  defp normalize_limit(nil), do: {:ok, @default_limit}
  defp normalize_limit(limit) when is_integer(limit) and limit > 0, do: {:ok, limit}
  defp normalize_limit(limit), do: {:error, {:invalid_limit, limit}}

  defp public_filters(filters) do
    filters
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp maybe_filter(query, _field, nil), do: query

  defp maybe_filter(query, field, value) when field in [:state, :profile, :kind] do
    from row in query, where: field(row, ^field) == ^value
  end

  defp maybe_cursor(query, nil), do: query
  defp maybe_cursor(query, cursor), do: from(a in query, where: a.id < ^cursor)

  defp maybe_filter_upload_state(query, nil), do: query

  defp maybe_filter_upload_state(query, state) do
    from [s, _a] in query, where: s.state == ^state
  end

  defp maybe_filter_joined_profile(query, nil), do: query

  defp maybe_filter_joined_profile(query, profile) do
    from [_s, a] in query, where: a.profile == ^profile
  end

  defp maybe_filter_upload_strategy(query, nil), do: query

  defp maybe_filter_upload_strategy(query, strategy) do
    from [s, _a] in query, where: s.upload_strategy == ^strategy
  end

  defp maybe_cursor_upload(query, nil), do: query
  defp maybe_cursor_upload(query, cursor), do: from([s, _a] in query, where: s.id < ^cursor)

  defp maybe_filter_finding_class(findings, nil), do: findings

  defp maybe_filter_finding_class(findings, class) do
    Enum.filter(findings, &(&1.class == class))
  end

  defp maybe_filter_finding_state(findings, nil), do: findings

  defp maybe_filter_finding_state(findings, state) do
    Enum.filter(findings, fn finding ->
      Enum.any?(finding.samples, &(&1.state == state))
    end)
  end

  defp runtime_status_opts(filters) do
    [
      profile: filters.profile,
      older_than: filters.older_than,
      limit: filters.limit,
      provider_stuck: filters.provider_stuck || false,
      format: :json
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp asset_row(%MediaAsset{} = asset) do
    %{
      id: asset.id,
      state: asset.state,
      profile: asset.profile,
      kind: asset.kind,
      content_type: asset.content_type,
      byte_size: asset.byte_size,
      filename: asset.filename,
      storage_key: asset.storage_key,
      error_reason: asset.error_reason,
      inserted_at: asset.inserted_at,
      updated_at: asset.updated_at
    }
  end

  defp asset_detail_row(asset_id) do
    case Config.repo().get(MediaAsset, asset_id) do
      nil -> nil
      asset -> asset_row(asset)
    end
  end

  defp attachment_rows(asset_id) do
    from(a in MediaAttachment,
      where: a.asset_id == ^asset_id,
      order_by: [asc: a.slot, asc: a.id]
    )
    |> Config.repo().all()
    |> Enum.map(fn attachment ->
      %{
        id: attachment.id,
        owner_type: attachment.owner_type,
        owner_id: attachment.owner_id,
        slot: attachment.slot,
        inserted_at: attachment.inserted_at,
        updated_at: attachment.updated_at
      }
    end)
  end

  defp variant_rows(asset_id) do
    from(v in MediaVariant,
      where: v.asset_id == ^asset_id,
      order_by: [asc: v.name, asc: v.id]
    )
    |> Config.repo().all()
    |> Enum.map(fn variant ->
      %{
        id: variant.id,
        name: variant.name,
        state: variant.state,
        storage_key: variant.storage_key,
        output_kind: variant.output_kind,
        error_reason: variant.error_reason,
        generated_at: variant.generated_at,
        inserted_at: variant.inserted_at,
        updated_at: variant.updated_at
      }
    end)
  end

  defp upload_session_rows(asset_id) do
    from(s in MediaUploadSession,
      join: a in MediaAsset,
      on: a.id == s.asset_id,
      where: s.asset_id == ^asset_id,
      order_by: [desc: s.inserted_at, desc: s.id],
      select: {s, a.profile}
    )
    |> Config.repo().all()
    |> Enum.map(fn {session, profile} -> upload_session_row(session, profile) end)
  end

  defp upload_session_row(%MediaUploadSession{} = session, profile) do
    %{
      id: session.id,
      asset_id: session.asset_id,
      profile: profile,
      state: session.state,
      upload_key: session.upload_key,
      upload_strategy: session.upload_strategy,
      upload_length: session.upload_length,
      resumable_protocol: session.resumable_protocol,
      session_uri: redacted_session_uri(session.session_uri),
      session_uri_expires_at: session.session_uri_expires_at,
      last_known_offset: session.last_known_offset,
      region_hint: session.region_hint,
      expires_at: session.expires_at,
      verified_at: session.verified_at,
      failure_reason: session.failure_reason,
      inserted_at: session.inserted_at,
      updated_at: session.updated_at
    }
  end

  defp redacted_session_uri(nil), do: nil

  defp redacted_session_uri(session_uri) do
    case MediaUploadSession.redact_session_uri(session_uri) do
      nil -> nil
      _redacted -> @redacted_session_uri
    end
  end

  defp processing_run_rows(asset_id) do
    from(r in MediaProcessingRun,
      where: r.asset_id == ^asset_id,
      order_by: [desc: r.inserted_at, desc: r.id]
    )
    |> Config.repo().all()
    |> Enum.map(fn run ->
      %{
        id: run.id,
        variant_name: run.variant_name,
        worker: run.worker,
        state: run.state,
        attempt: run.attempt,
        started_at: run.started_at,
        finished_at: run.finished_at,
        error_reason: run.error_reason,
        inserted_at: run.inserted_at,
        updated_at: run.updated_at
      }
    end)
  end

  defp provider_asset_rows(asset_id) do
    from(p in MediaProviderAsset,
      where: p.asset_id == ^asset_id,
      order_by: [asc: p.provider_name, asc: p.id]
    )
    |> Config.repo().all()
    |> Enum.map(fn provider_asset ->
      %{
        id: provider_asset.id,
        profile: provider_asset.profile,
        provider_name: provider_asset.provider_name,
        provider_asset_id: redacted_provider_id(provider_asset.provider_asset_id),
        playback_ids: provider_asset.playback_ids,
        playback_policy: provider_asset.playback_policy,
        ingest_mode: provider_asset.ingest_mode,
        state: provider_asset.state,
        last_event_at: provider_asset.last_event_at,
        last_sync_error: provider_asset.last_sync_error,
        inserted_at: provider_asset.inserted_at,
        updated_at: provider_asset.updated_at
      }
    end)
  end

  defp redacted_provider_id(nil), do: nil

  defp redacted_provider_id(provider_asset_id) do
    case MediaProviderAsset.redact_id(provider_asset_id) do
      nil -> nil
      _redacted -> @redacted_provider_id
    end
  end

  defp profile_args(profiles) do
    profiles
    |> List.wrap()
    |> Enum.map(&profile_arg/1)
  end

  defp profile_arg(profile) when is_atom(profile), do: Atom.to_string(profile)
  defp profile_arg(profile) when is_binary(profile), do: profile
end
