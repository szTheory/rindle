defmodule Rindle.Ops.LifecycleRepair do
  @moduledoc false

  require Logger

  import Ecto.Query

  alias Rindle.Config
  alias Rindle.Domain.MediaAsset
  alias Rindle.Domain.MediaVariant
  alias Rindle.Workers.PromoteAsset
  alias Rindle.Workers.ProcessVariant

  @type failure_class :: :configuration | :enqueue | :state_conflict
  @type reprobe_report :: %{
          asset_id: binary(),
          attempted: non_neg_integer(),
          refreshed: non_neg_integer(),
          errors: non_neg_integer(),
          failures: [],
          cleared_fields: [atom()],
          content_type: binary(),
          kind: binary(),
          refreshed_fields: [atom()],
          updated_at: NaiveDateTime.t()
        }
  @type requeue_failure_reason ::
          :state_not_repairable | :variant_definition_missing | :enqueue_failed
  @type requeue_failure :: %{
          asset_id: binary(),
          variant_id: binary(),
          variant_name: binary(),
          state: binary(),
          failure_class: failure_class(),
          reason: requeue_failure_reason(),
          message: binary()
        }
  @type requeue_report :: %{
          asset_id: binary(),
          selected: non_neg_integer(),
          enqueued: non_neg_integer(),
          skipped: non_neg_integer(),
          errors: non_neg_integer(),
          failures: [requeue_failure()]
        }

  @repairable_states ["failed", "cancelled"]
  @allowed_requeue_option_keys [:variant_names]

  @spec reprobe_asset(MediaAsset.t() | binary()) :: {:ok, reprobe_report()} | {:error, term()}
  def reprobe_asset(asset_or_id) do
    with_repair_telemetry(:reprobe, fn ->
      repo = Config.repo()

      with %MediaAsset{} = asset <- fetch_asset(repo, asset_or_id),
           {:ok, attrs} <- PromoteAsset.probe_asset(asset),
           {:ok, updated_asset} <-
             PromoteAsset.persist_probe_result(repo, asset, attrs,
               allowed_fields: PromoteAsset.probe_fields(),
               clear_missing?: true
             ) do
        {:ok, build_reprobe_report(updated_asset, attrs)}
      else
        nil -> {:error, :not_found}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  @spec requeue_failed_variants(MediaAsset.t() | binary(), keyword() | map()) ::
          {:ok, requeue_report()} | {:error, term()}
  def requeue_failed_variants(asset_or_id, opts \\ []) do
    with_repair_telemetry(:requeue, fn ->
      repo = Config.repo()

      with {:ok, normalized_opts} <- normalize_requeue_opts(opts),
           %MediaAsset{} = asset <- fetch_asset(repo, asset_or_id),
           {:ok, selected_variants} <- select_variants(repo, asset.id, normalized_opts),
           {:ok, variant_specs} <- resolve_variant_specs(asset) do
        report =
          selected_variants
          |> Enum.reduce(base_requeue_report(asset.id, length(selected_variants)), fn variant,
                                                                                      report ->
            requeue_variant(asset, variant, variant_specs, report)
          end)
          |> finalize_requeue_report()

        {:ok, report}
      else
        nil -> {:error, :not_found}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  defp fetch_asset(repo, %MediaAsset{id: id}), do: repo.get(MediaAsset, id)
  defp fetch_asset(repo, asset_id) when is_binary(asset_id), do: repo.get(MediaAsset, asset_id)

  defp build_reprobe_report(asset, attrs) do
    refreshed_fields =
      PromoteAsset.probe_fields()
      |> Enum.filter(&Map.has_key?(attrs, &1))

    %{
      asset_id: asset.id,
      attempted: 1,
      refreshed: 1,
      errors: 0,
      failures: [],
      refreshed_fields: refreshed_fields,
      cleared_fields: PromoteAsset.probe_fields() -- refreshed_fields,
      content_type: asset.content_type,
      kind: asset.kind,
      updated_at: asset.updated_at
    }
  end

  defp normalize_requeue_opts(opts) when is_list(opts) do
    opts
    |> Enum.into(%{})
    |> normalize_requeue_opts()
  end

  defp normalize_requeue_opts(opts) when is_map(opts) do
    with :ok <- validate_requeue_option_keys(opts),
         {:ok, variant_names} <- normalize_variant_names(Map.get(opts, :variant_names)) do
      {:ok, %{variant_names: variant_names}}
    end
  end

  defp normalize_requeue_opts(_opts), do: {:error, {:invalid_options, :expected_keyword_or_map}}

  defp validate_requeue_option_keys(opts) do
    case Map.keys(opts) -- @allowed_requeue_option_keys do
      [] -> :ok
      unknown -> {:error, {:unknown_options, unknown}}
    end
  end

  defp normalize_variant_names(nil), do: {:ok, nil}
  defp normalize_variant_names([]), do: {:ok, []}

  defp normalize_variant_names(names) when is_list(names) do
    Enum.reduce_while(names, {:ok, []}, fn name, {:ok, acc} ->
      case normalize_variant_name(name) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized) |> Enum.uniq()}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_variant_names(other), do: {:error, {:invalid_variant_names, other}}

  defp normalize_variant_name(name) when is_atom(name), do: {:ok, Atom.to_string(name)}
  defp normalize_variant_name(name) when is_binary(name), do: {:ok, name}
  defp normalize_variant_name(other), do: {:error, {:invalid_variant_name, other}}

  defp select_variants(repo, asset_id, %{variant_names: nil}) do
    variants =
      repo.all(
        from v in MediaVariant,
          where: v.asset_id == ^asset_id and v.state in @repairable_states,
          order_by: [asc: v.name]
      )

    {:ok, variants}
  end

  defp select_variants(_repo, _asset_id, %{variant_names: []}) do
    {:ok, []}
  end

  defp select_variants(repo, asset_id, %{variant_names: requested_names}) do
    variants =
      repo.all(
        from v in MediaVariant,
          where: v.asset_id == ^asset_id,
          order_by: [asc: v.name]
      )

    known_names = MapSet.new(Enum.map(variants, & &1.name))
    unknown_names = Enum.reject(requested_names, &MapSet.member?(known_names, &1))

    case unknown_names do
      [] ->
        selected =
          variants
          |> Enum.filter(&(&1.name in requested_names))

        {:ok, selected}

      _ ->
        {:error, {:unknown_variant_names, unknown_names}}
    end
  end

  defp resolve_variant_specs(%MediaAsset{profile: profile}) do
    profile_module = String.to_existing_atom(profile)

    specs =
      profile_module.variants()
      |> Enum.into(%{}, fn {name, spec} -> {Atom.to_string(name), spec} end)

    {:ok, specs}
  rescue
    ArgumentError -> {:error, :unknown_profile}
  end

  defp base_requeue_report(asset_id, selected_count) do
    %{
      asset_id: asset_id,
      selected: selected_count,
      enqueued: 0,
      skipped: 0,
      errors: 0,
      failures: []
    }
  end

  defp requeue_variant(asset, variant, variant_specs, report) do
    cond do
      variant.state not in @repairable_states ->
        add_requeue_failure(
          report,
          variant,
          :state_conflict,
          :state_not_repairable,
          "Variant #{variant.name} is #{variant.state}; only failed or cancelled variants can be requeued."
        )

      not Map.has_key?(variant_specs, variant.name) ->
        add_requeue_failure(
          report,
          variant,
          :configuration,
          :variant_definition_missing,
          "Variant #{variant.name} is not declared by profile #{asset.profile}; broad regeneration stays on mix rindle.regenerate_variants."
        )

      true ->
        enqueue_selected_variant(
          asset.id,
          variant,
          Map.fetch!(variant_specs, variant.name),
          report
        )
    end
  end

  defp enqueue_selected_variant(asset_id, variant, variant_spec, report) do
    case asset_id
         |> ProcessVariant.build_job(variant.name, variant_spec)
         |> Oban.insert() do
      {:ok, %Oban.Job{conflict?: true}} ->
        %{report | skipped: report.skipped + 1}

      {:ok, _job} ->
        %{report | enqueued: report.enqueued + 1}

      {:error, reason} ->
        add_requeue_failure(
          report,
          variant,
          :enqueue,
          :enqueue_failed,
          "Variant #{variant.name} could not be requeued: #{inspect(reason)}"
        )
    end
  end

  defp add_requeue_failure(report, variant, failure_class, reason, message) do
    Logger.warning("rindle.lifecycle_repair.requeue_variant_failed",
      asset_id: variant.asset_id,
      variant_id: variant.id,
      variant_name: variant.name,
      state: variant.state,
      failure_class: failure_class,
      reason: reason
    )

    failure = %{
      asset_id: variant.asset_id,
      variant_id: variant.id,
      variant_name: variant.name,
      state: variant.state,
      failure_class: failure_class,
      reason: reason,
      message: message
    }

    %{report | errors: report.errors + 1, failures: [failure | report.failures]}
  end

  defp finalize_requeue_report(report) do
    %{report | failures: Enum.reverse(report.failures)}
  end

  defp with_repair_telemetry(operation, fun) do
    started_at = System.monotonic_time()

    try do
      :telemetry.execute(
        [:rindle, :repair, :start],
        %{system_time: System.system_time()},
        %{operation: operation, scope: :asset, result: :started, dry_run: false}
      )

      result = fun.()

      :telemetry.execute(
        [:rindle, :repair, :stop],
        repair_measurements(result, started_at),
        %{operation: operation, scope: :asset, result: repair_result(result), dry_run: false}
      )

      result
    rescue
      error ->
        :telemetry.execute(
          [:rindle, :repair, :exception],
          %{duration_us: elapsed_us(started_at), system_time: System.system_time()},
          %{operation: operation, scope: :asset, result: :exception, dry_run: false}
        )

        reraise error, __STACKTRACE__
    end
  end

  defp repair_measurements(
         {:ok, %{attempted: attempted, refreshed: refreshed, errors: errors}},
         started_at
       ) do
    %{duration_us: elapsed_us(started_at), attempted: attempted, refreshed: refreshed, errors: errors}
  end

  defp repair_measurements(
         {:ok, %{selected: selected, enqueued: enqueued, skipped: skipped, errors: errors}},
         started_at
       ) do
    %{duration_us: elapsed_us(started_at), selected: selected, enqueued: enqueued, skipped: skipped, errors: errors}
  end

  defp repair_measurements({:error, _reason}, started_at) do
    %{duration_us: elapsed_us(started_at), errors: 1}
  end

  defp repair_result({:ok, %{errors: 0, failures: []}}), do: :ok
  defp repair_result({:ok, %{enqueued: enqueued, failures: failures}}) when enqueued > 0 and failures != [], do: :partial
  defp repair_result({:ok, %{errors: 0}}), do: :ok
  defp repair_result({:ok, _report}), do: :error
  defp repair_result({:error, _reason}), do: :error

  defp elapsed_us(started_at) do
    System.convert_time_unit(System.monotonic_time() - started_at, :native, :microsecond)
  end
end
