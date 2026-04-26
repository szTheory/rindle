defmodule Rindle.Ops.VariantMaintenance do
  @moduledoc """
  Shared variant maintenance operations for Day-2 operations.

  Provides two primary operations:

  - `regenerate_variants/1` — Enqueues `ProcessVariant` jobs for stale or missing
    variants, optionally filtered by profile module or variant name. Only targets
    actionable states; ready/queued/processing variants are skipped.

  - `verify_storage/1` — HEAD-checks the storage object for each variant with a
    `storage_key` and flips absent entries to `missing`. Returns structured counts
    so the caller (or Mix task) can emit a deterministic summary.

  Both operations fail loudly on unexpected errors (query failures, storage
  connection problems) via `{:error, reason}` tuple returns so scripted callers
  can detect non-zero exits.
  """

  require Logger

  import Ecto.Query

  alias Rindle.Domain.{MediaAsset, MediaVariant}
  alias Rindle.Domain.VariantFSM
  alias Rindle.Repo
  alias Rindle.Workers.ProcessVariant

  @regeneration_states ["stale", "missing"]
  @verifiable_states ["ready", "stale", "missing", "failed"]
  @allowed_filter_keys [:profile, :variant_name]

  @type filters :: %{
          optional(:profile) => String.t(),
          optional(:variant_name) => String.t()
        }

  @type regenerate_result :: %{
          enqueued: non_neg_integer(),
          skipped: non_neg_integer(),
          errors: non_neg_integer()
        }
  @type verify_result :: %{
          checked: non_neg_integer(),
          present: non_neg_integer(),
          missing: non_neg_integer(),
          fsm_blocked: non_neg_integer(),
          errors: non_neg_integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Enqueues `ProcessVariant` jobs for all stale or missing variants that match
  the given filters.

  ## Filters

    * `:profile` — restrict to variants whose associated asset has this profile
      string (e.g. `"Elixir.MyApp.AvatarProfile"`).
    * `:variant_name` — restrict to variants with this exact name.

  ## Returns

    * `{:ok, %{enqueued: N, skipped: M, errors: E}}` on success.
      - `enqueued` is the count of newly inserted ProcessVariant jobs.
      - `skipped` includes both eligible variants whose insertion was a
        no-op due to Oban uniqueness (an equivalent job is already in-flight)
        and variants in non-regeneratable states (`queued`, `processing`,
        `ready`).
      - `errors` is the count of `Oban.insert/1` failures (non-uniqueness
        rejection — e.g. DB connection, validation failure). Callers should
        exit non-zero when this is greater than zero.
    * `{:error, reason}` if the underlying query fails.
  """
  @spec regenerate_variants(filters()) :: {:ok, regenerate_result()} | {:error, term()}
  def regenerate_variants(filters) when is_map(filters) do
    with :ok <- validate_filters(filters) do
      do_regenerate_variants(filters)
    end
  end

  defp do_regenerate_variants(filters) do
    query =
      from v in MediaVariant,
        join: a in MediaAsset,
        on: a.id == v.asset_id,
        where: v.state in @regeneration_states,
        select: {v.id, v.name, a.id, v.state}

    query = maybe_filter_profile(query, filters)
    query = maybe_filter_variant_name(query, filters)

    with {:ok, rows} <- safe_all(query) do
      # Compute the "already in a non-regeneratable state" tally BEFORE we
      # touch Oban so a query failure here does not strand half-enqueued work
      # in the queue (WR-04). Restrict to operationally-relevant states only
      # ("queued", "processing", "ready") rather than the open-ended
      # "anything not in @regeneration_states" set, which over-counted purged
      # / failed / planned variants as "skipped".
      skipped_query =
        from v in MediaVariant,
          join: a in MediaAsset,
          on: a.id == v.asset_id,
          where: v.state in ["queued", "processing", "ready"],
          select: count(v.id)

      skipped_query = maybe_filter_profile(skipped_query, filters)
      skipped_query = maybe_filter_variant_name(skipped_query, filters)

      with {:ok, [existing_skip_count]} <- safe_all(skipped_query) do
        {enqueued, skipped, errors} =
          Enum.reduce(rows, {0, 0, 0}, fn {_variant_id, variant_name, asset_id, _state},
                                          {enq, skip, err} ->
            case enqueue_job(asset_id, variant_name) do
              # Oban uniqueness rejected this insert because an equivalent job
              # is already in-flight — count as skipped, not enqueued.
              {:ok, %Oban.Job{conflict?: true}} ->
                {enq, skip + 1, err}

              {:ok, _job} ->
                {enq + 1, skip, err}

              {:error, reason} ->
                Logger.error("rindle.variant_maintenance.enqueue_failed",
                  asset_id: asset_id,
                  variant_name: variant_name,
                  reason: inspect(reason)
                )

                {enq, skip, err + 1}
            end
          end)

        {:ok,
         %{enqueued: enqueued, skipped: skipped + existing_skip_count, errors: errors}}
      end
    end
  end

  @doc """
  Walks all variant records that have a `storage_key` and HEAD-checks the
  storage object via the profile's configured storage adapter.

  Variants where the HEAD returns `{:error, :not_found}` are flipped to
  `missing` state. Other error types are counted as errors without mutating
  the record (network errors, auth failures, etc.).

  Counters are kept distinct so operators can tell infrastructure problems
  apart from FSM invariant enforcement:

    * `:errors` — true infrastructure failures (storage connection, auth,
      adapter resolution, repo failure). Mix-task callers exit non-zero on
      any non-zero `:errors` count.
    * `:fsm_blocked` — the FSM rejected the `→ missing` transition (e.g. a
      `failed` variant whose object disappears). The state is left as-is and
      logged; this is informational and does NOT trigger a non-zero exit.

  ## Filters

    * `:variant_name` — restrict to variants with this exact name.
    * `:profile` — restrict to variants whose asset has this profile string.

  ## Returns

    * `{:ok, %{checked: N, present: P, missing: M, fsm_blocked: B, errors: E}}` on success.
    * `{:error, reason}` if the initial query fails.
  """
  @spec verify_storage(filters()) :: {:ok, verify_result()} | {:error, term()}
  def verify_storage(filters) when is_map(filters) do
    with :ok <- validate_filters(filters) do
      do_verify_storage(filters)
    end
  end

  defp do_verify_storage(filters) do
    query =
      from v in MediaVariant,
        join: a in MediaAsset,
        on: a.id == v.asset_id,
        where: not is_nil(v.storage_key),
        where: v.state in @verifiable_states,
        select: %{
          variant_id: v.id,
          variant_state: v.state,
          storage_key: v.storage_key,
          asset_profile: a.profile
        }

    query = maybe_filter_profile(query, filters)
    query = maybe_filter_variant_name(query, filters)

    with {:ok, rows} <- safe_all(query) do
      acc0 = %{checked: 0, present: 0, missing: 0, fsm_blocked: 0, errors: 0}

      result =
        Enum.reduce(rows, acc0, fn row, acc ->
          acc = Map.update!(acc, :checked, &(&1 + 1))

          case check_object(row) do
            :present -> Map.update!(acc, :present, &(&1 + 1))
            :missing -> Map.update!(acc, :missing, &(&1 + 1))
            :fsm_blocked -> Map.update!(acc, :fsm_blocked, &(&1 + 1))
            :error -> Map.update!(acc, :errors, &(&1 + 1))
          end
        end)

      {:ok, result}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # WR-08: filter typos in a destructive lane should be loud. The Mix tasks
  # already constrain CLI flags via OptionParser, but the Elixir-callable API
  # needs an explicit guard so e.g. `%{prof: ...}` or `%{variant: ...}` does
  # not silently regenerate every variant in the system.
  defp validate_filters(filters) do
    case Map.keys(filters) -- @allowed_filter_keys do
      [] -> :ok
      unknown -> {:error, {:unknown_filters, unknown}}
    end
  end

  defp maybe_filter_profile(query, %{profile: profile}) when is_binary(profile) do
    from [_v, a] in query, where: a.profile == ^profile
  end

  defp maybe_filter_profile(query, _filters), do: query

  defp maybe_filter_variant_name(query, %{variant_name: name}) when is_binary(name) do
    from v in query, where: v.name == ^name
  end

  defp maybe_filter_variant_name(query, _filters), do: query

  defp enqueue_job(asset_id, variant_name) do
    # Uniqueness scoped to (worker, queue, asset_id, variant_name) for any
    # in-flight or queued state. Two back-to-back regenerate_variants runs (or
    # two cron firings) must not duplicate work — T-04-08 mitigation.
    %{"asset_id" => asset_id, "variant_name" => variant_name}
    |> ProcessVariant.new(
      unique: [
        fields: [:args, :worker, :queue],
        keys: [:asset_id, :variant_name],
        states: [:available, :scheduled, :executing, :retryable],
        period: :infinity
      ]
    )
    |> Oban.insert()
  end

  defp check_object(%{variant_id: variant_id, variant_state: state, storage_key: key, asset_profile: profile}) do
    case resolve_storage_adapter(profile) do
      {:ok, storage_adapter} ->
        case storage_adapter.head(key, []) do
          {:ok, _meta} ->
            :present

          {:error, :not_found} ->
            mark_missing(variant_id, state)

          {:error, _other} ->
            :error
        end

      {:error, reason} ->
        # WR-09: do NOT raise — that would abort the whole verify walk on the
        # first malformed profile string. Bump the :error counter and log so
        # operators can investigate without losing the rest of the run.
        Logger.warning("rindle.variant_maintenance.resolve_adapter_failed",
          variant_id: variant_id,
          profile_present: not is_nil(profile),
          reason: inspect(reason)
        )

        :error
    end
  end

  defp resolve_storage_adapter(profile_string) when is_binary(profile_string) do
    try do
      mod = String.to_existing_atom(profile_string)

      cond do
        not Code.ensure_loaded?(mod) ->
          {:error, :module_not_loaded}

        not function_exported?(mod, :storage_adapter, 0) ->
          {:error, :no_storage_adapter_callback}

        true ->
          {:ok, mod.storage_adapter()}
      end
    rescue
      ArgumentError -> {:error, :unknown_profile}
    end
  end

  defp resolve_storage_adapter(_), do: {:error, :invalid_profile_value}

  # Gate the missing-flip on the FSM. The query set includes "stale" and
  # "failed" today and the FSM forbids those source states transitioning to
  # "missing" — flipping them silently would erase the prior FSM decision.
  # When the transition is invalid, classify as :fsm_blocked (informational,
  # non-error) so the verify_storage report distinguishes FSM enforcement
  # from real infrastructure failures. Mix-task exit code is unaffected.
  defp mark_missing(variant_id, current_state) do
    case VariantFSM.transition(current_state, "missing", %{variant_id: variant_id}) do
      :ok ->
        # Use a real changeset so validate_inclusion runs (a typo in the
        # constant "missing" would otherwise pass update_all silently).
        case Repo.get(MediaVariant, variant_id) do
          nil ->
            Logger.warning("rindle.variant_maintenance.variant_disappeared",
              variant_id: variant_id
            )

            :error

          variant ->
            variant
            |> MediaVariant.changeset(%{state: "missing"})
            |> Repo.update()
            |> case do
              {:ok, _updated} ->
                :missing

              {:error, reason} ->
                Logger.warning("rindle.variant_maintenance.mark_missing_failed",
                  variant_id: variant_id,
                  reason: inspect(reason)
                )

                :error
            end
        end

      {:error, {:invalid_transition, from, to}} ->
        Logger.warning("rindle.variant_maintenance.mark_missing_invalid_transition",
          variant_id: variant_id,
          from_state: from,
          to_state: to
        )

        :fsm_blocked
    end
  end

  defp safe_all(query) do
    {:ok, Repo.all(query)}
  rescue
    e -> {:error, e}
  end
end
