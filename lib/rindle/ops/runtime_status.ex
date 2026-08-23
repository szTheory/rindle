defmodule Rindle.Ops.RuntimeStatus do
  @moduledoc false

  alias Rindle.Config
  alias Rindle.Ops.OwnershipSnapshot
  alias Rindle.Ops.RuntimeStatus.Collector
  alias Rindle.Schema

  @allowed_filter_keys [:profile, :older_than, :limit, :format, :provider_stuck]
  @default_limit 5

  @type filters :: %{
          profile: String.t() | nil,
          older_than: non_neg_integer() | nil,
          limit: pos_integer(),
          format: :text | :json,
          provider_stuck: boolean()
        }

  @type report :: %{
          generated_at: DateTime.t(),
          filters: filters(),
          runtime_checks: map(),
          assets: map(),
          variants: map(),
          upload_sessions: map(),
          provider_assets: map(),
          recommendations: [map()]
        }

  @spec runtime_status(keyword() | map()) :: {:ok, report()} | {:error, term()}
  def runtime_status(opts \\ []) do
    with {:ok, filters} <- normalize_filters(opts),
         {:ok, snapshot} <- ready_snapshot() do
      now = DateTime.utc_now()
      cutoff = older_than_cutoff(now, filters.older_than)

      collected = Collector.collect(filters, now, cutoff, snapshot.oban.expected_prefix)

      {:ok,
       %{
         generated_at: now,
         filters: filters,
         runtime_checks: collected.runtime_checks,
         assets: collected.assets,
         variants: collected.variants,
         upload_sessions: collected.upload_sessions,
         provider_assets: collected.provider_assets,
         recommendations:
           build_recommendations(
             collected.runtime_checks,
             collected.variants,
             collected.upload_sessions,
             collected.provider_assets
           )
       }}
    else
      {:error, reason} = error ->
        emit_runtime_refusal(reason)
        error
    end
  end

  defp ready_snapshot do
    snapshot = ownership_snapshot()

    case snapshot do
      %{rindle: %{classification: rindle}, oban: %{classification: oban}} = valid_snapshot ->
        classify_snapshot(rindle, oban, valid_snapshot)

      _other ->
        {:error, {:inspection_failed, %{component: :rindle, owner: :rindle}}}
    end
  end

  defp ownership_snapshot do
    config = Application.get_env(:rindle, __MODULE__, [])

    case Keyword.get(config, :ownership_snapshot, :inspect) do
      :inspect ->
        case Keyword.get(config, :setup_readiness, :inspect) do
          :inspect -> OwnershipSnapshot.inspect()
          readiness -> legacy_readiness_snapshot(readiness)
        end

      fun when is_function(fun, 0) ->
        fun.()

      snapshot ->
        snapshot
    end
  end

  defp legacy_readiness_snapshot(readiness) when is_function(readiness, 0),
    do: legacy_readiness_snapshot(readiness.())

  defp legacy_readiness_snapshot(readiness) when is_map(readiness) do
    rindle_ready? = Map.get(readiness, :rindle_schema, %{}) |> Map.get(:ready?, false)
    oban_ready? = Map.get(readiness, :oban_jobs, %{}) |> Map.get(:ready?, false)

    %{
      rindle:
        snapshot_component(
          :rindle,
          if(rindle_ready?, do: :ready, else: :incomplete),
          Schema.prefix(),
          Schema.prefix()
        ),
      oban:
        snapshot_component(
          :host,
          if(oban_ready?, do: :ready, else: :incomplete),
          Config.oban_prefix(),
          if(oban_ready?, do: Config.oban_prefix(), else: nil)
        )
    }
  end

  defp legacy_readiness_snapshot(_other), do: %{}

  defp snapshot_component(owner, classification, expected_prefix, observed_prefix) do
    %{
      owner: owner,
      classification: classification,
      expected_prefix: expected_prefix,
      observed_prefix: observed_prefix
    }
  end

  defp classify_snapshot(:incomplete, _oban, _snapshot),
    do: {:error, {:setup_incomplete, :rindle_schema}}

  defp classify_snapshot(_rindle, :incomplete, _snapshot),
    do: {:error, {:setup_incomplete, :oban_jobs}}

  defp classify_snapshot(:ready, :ready, snapshot), do: {:ok, snapshot}
  defp classify_snapshot(:legacy_ready, :ready, snapshot), do: {:ok, snapshot}

  defp classify_snapshot(:rindle_prefix_mismatch, _oban, snapshot),
    do: {:error, bounded_refusal(:rindle_prefix_mismatch, :rindle, snapshot.rindle)}

  defp classify_snapshot(_rindle, :oban_binding_drift, snapshot),
    do: {:error, bounded_refusal(:oban_binding_drift, :oban, snapshot.oban)}

  defp classify_snapshot(:inspection_failed, _oban, _snapshot),
    do: {:error, {:inspection_failed, %{component: :rindle, owner: :rindle}}}

  defp classify_snapshot(_rindle, :inspection_failed, _snapshot),
    do: {:error, {:inspection_failed, %{component: :oban, owner: :host}}}

  defp classify_snapshot(_rindle, _oban, _snapshot),
    do: {:error, {:inspection_failed, %{component: :rindle, owner: :rindle}}}

  defp bounded_refusal(classification, component, snapshot) do
    {classification,
     %{
       component: component,
       expected_prefix: safe_prefix(component, Map.get(snapshot, :expected_prefix)),
       observed_prefix: safe_prefix(component, Map.get(snapshot, :observed_prefix)),
       owner: refusal_owner(component)
     }}
  end

  defp safe_prefix(:rindle, prefix) when prefix in ["rindle", "public"], do: prefix

  defp safe_prefix(:oban, prefix) when is_binary(prefix) do
    if Regex.match?(~r/\A[a-zA-Z_][a-zA-Z0-9_$]*\z/, prefix), do: prefix, else: "unknown"
  end

  defp safe_prefix(_component, _prefix), do: "unknown"

  defp refusal_owner(:rindle), do: :rindle
  defp refusal_owner(:oban), do: :host

  defp build_recommendations(runtime_checks, variants, upload_sessions, provider_assets) do
    classes =
      Enum.map(runtime_checks.findings, & &1.class) ++
        Enum.map(variants.findings, & &1.class) ++
        Enum.map(provider_assets.findings, & &1.class)

    upload_states = Enum.map(upload_sessions.findings, & &1.state)

    classes
    |> Enum.uniq()
    |> Enum.map(&recommendation_for_class/1)
    |> Enum.reject(&is_nil/1)
    |> Kernel.++(upload_recommendations(upload_states))
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
      summary:
        "Requeue affected failed or stuck asset-scoped variant work after confirming the root cause."
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

  defp recommendation_for_class(:provider_stuck) do
    %{
      class: :provider_stuck,
      action: :resync,
      surface: "Rindle.Workers.MuxSyncProviderAsset",
      summary:
        "Re-sync provider state for rows stuck in :uploading or :processing past threshold."
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

  defp older_than_cutoff(_now, nil), do: nil

  defp older_than_cutoff(now, older_than) do
    now
    |> DateTime.to_naive()
    |> NaiveDateTime.add(-older_than, :second)
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
         {:ok, format} <- normalize_format(Map.get(normalized, :format)),
         {:ok, provider_stuck} <- normalize_provider_stuck(Map.get(normalized, :provider_stuck)) do
      {:ok,
       %{
         profile: profile,
         older_than: older_than,
         limit: limit,
         format: format,
         provider_stuck: provider_stuck
       }}
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

        {"provider_stuck", value}, acc ->
          Map.put(acc, :provider_stuck, value)

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

  defp normalize_provider_stuck(nil), do: {:ok, false}
  defp normalize_provider_stuck(true), do: {:ok, true}
  defp normalize_provider_stuck(false), do: {:ok, false}
  defp normalize_provider_stuck(value), do: {:error, {:invalid_provider_stuck, value}}

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
