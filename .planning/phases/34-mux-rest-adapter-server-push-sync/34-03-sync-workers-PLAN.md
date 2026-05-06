---
phase: 34-mux-rest-adapter-server-push-sync
plan: 03
type: execute
wave: 2
depends_on: [34-01]
autonomous: true
requirements: [MUX-07]
files_modified:
  - lib/rindle/workers/mux_sync_coordinator.ex
  - lib/rindle/workers/mux_sync_provider_asset.ex
  - test/rindle/workers/mux_sync_coordinator_test.exs
  - test/rindle/workers/mux_sync_provider_asset_test.exs

must_haves:
  truths:
    - "`Rindle.Workers.MuxSyncCoordinator` is a cron-driven Oban worker (queue: :rindle_provider, max_attempts: 1) that scans `media_provider_assets` for rows in (`processing`, `uploading`) older than `provider_polling_floor_seconds` (default 30s) and fans out per-row sibling jobs."
    - "`Rindle.Workers.MuxSyncProviderAsset` is a per-row defensive sync worker (queue: :rindle_provider, max_attempts: 3, unique on `provider_asset_id` for 60s) that calls `Rindle.Streaming.Provider.Mux.get_asset/1`, advances the FSM to match Mux-side state (persisting the PLURAL `playback_ids` array per Phase 33 schema), and transitions to `:errored` with reason `:provider_asset_stuck` when the row is older than `provider_stuck_threshold_seconds` (default 7200s)."
    - "Coordinator emits no per-row telemetry — it logs structured fan-out completion (`Logger.info`) and lets the per-row worker emit `[:rindle, :provider, :sync, :resolved | :stuck]` events with redacted `asset_id`."
    - "Both workers are wrapped in `if Code.ensure_loaded?(Mux.Video.Assets) do` (Pitfall 4 #2)."
    - "Per-row unique constraint (`unique: [period: 60, keys: [:provider_asset_id]]`) deduplicates within the 60s window — the second cron tick will not re-fan-out a still-running per-row job."
    - "When the per-row worker calls `get_asset/1` and Mux returns `status: \"ready\"`, the row's FSM transitions `processing → ready` and persists the live `playback_ids` (PLURAL ARRAY); when Mux returns `status: \"errored\"`, the row transitions `processing → errored` with `last_sync_error` populated."
  artifacts:
    - path: "lib/rindle/workers/mux_sync_coordinator.ex"
      provides: "Cron-driven coordinator (max_attempts: 1) — fan-out enqueuer for per-row sync"
      contains: "use Oban.Worker, queue: :rindle_provider, max_attempts: 1"
    - path: "lib/rindle/workers/mux_sync_provider_asset.ex"
      provides: "Per-row defensive sync (max_attempts: 3) — calls get_asset/1, transitions FSM, emits :resolved | :stuck"
      contains: "use Oban.Worker, queue: :rindle_provider, max_attempts: 3"
    - path: "test/rindle/workers/mux_sync_coordinator_test.exs"
      provides: "Coordinator scan + fan-out tests with TestRepoProbe pattern"
      min_lines: 80
    - path: "test/rindle/workers/mux_sync_provider_asset_test.exs"
      provides: "Per-row sync tests for :resolved and :stuck telemetry paths"
      min_lines: 100
  key_links:
    - from: "lib/rindle/workers/mux_sync_coordinator.ex"
      to: "lib/rindle/workers/mux_sync_provider_asset.ex"
      via: "`Oban.insert/2` per-row with `unique: [period: 60, keys: [:provider_asset_id]]`"
      pattern: "Rindle.Workers.MuxSyncProviderAsset.new"
    - from: "lib/rindle/workers/mux_sync_provider_asset.ex"
      to: "Rindle.Streaming.Provider.Mux.get_asset/1"
      via: "Per-row sync delegate"
      pattern: "Rindle.Streaming.Provider.Mux.get_asset"
    - from: "lib/rindle/workers/mux_sync_provider_asset.ex"
      to: "Rindle.Domain.MediaProviderAsset.redact_id/1"
      via: "Telemetry metadata redaction"
      pattern: "MediaProviderAsset.redact_id"
---

<objective>
Implement the defensive sync workers — a cron-driven coordinator and a
per-row sibling. The coordinator scans `media_provider_assets` for stuck
rows and fans out per-row jobs; the per-row worker reconciles each row
against the live Mux asset state and surfaces `:provider_asset_stuck`
beyond the configured threshold. This pair extends Rindle's existing
adopter-owned Oban convention (mirroring `cleanup_orphans.ex` /
`abort_incomplete_uploads.ex`) and adds the per-row fan-out shape v1.6
needs.

Purpose: webhooks (Phase 35) will be the primary readiness signal, but
sync provides the safety-net so that a missed/dropped webhook does not
leave a `media_provider_assets` row stuck forever. The coordinator is the
adopter-cron-wired entry point; the per-row worker is the actual sync logic.

Output: 2 new worker files, 2 new test files. The per-row worker emits
telemetry under `[:rindle, :provider, :sync, :resolved | :stuck]` with
redacted `asset_id`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/34-mux-rest-adapter-server-push-sync/34-CONTEXT.md
@.planning/phases/34-mux-rest-adapter-server-push-sync/34-RESEARCH.md
@.planning/phases/34-mux-rest-adapter-server-push-sync/34-PATTERNS.md
@.planning/phases/34-mux-rest-adapter-server-push-sync/34-VALIDATION.md
@.planning/phases/34-mux-rest-adapter-server-push-sync/34-01-SUMMARY.md

@lib/rindle/workers/cleanup_orphans.ex
@lib/rindle/workers/abort_incomplete_uploads.ex
@lib/rindle/streaming/provider.ex
@lib/rindle/domain/media_provider_asset.ex
@lib/rindle/domain/provider_asset_fsm.ex
@lib/rindle/config.ex
@test/rindle/workers/maintenance_workers_test.exs

<interfaces>
<!-- Adapter callbacks Plan 03 invokes (from Plan 01) -->
```elixir
# lib/rindle/streaming/provider/mux.ex (Plan 01)
@spec get_asset(provider_asset_id :: String.t()) ::
        {:ok, %{state: String.t(), playback_ids: [String.t()], raw: map()}}
        | {:error, term()}

# Public redactor (Plan 01)
@spec Rindle.Domain.MediaProviderAsset.redact_id(nil | String.t()) :: nil | String.t()
```

<!-- ProviderAssetFSM.transition/3 — third arg is a MAP (lib/rindle/domain/provider_asset_fsm.ex:28) -->
```elixir
@spec transition(state :: String.t(), state :: String.t(), context :: map()) :: :ok | {:error, term()}
def transition(current_state, target_state, context \\ %{}) do
  # context is read via Map.get(context, :profile, :unknown), NOT Keyword.get/2
end
```

<!-- Coordinator pattern from cleanup_orphans.ex / abort_incomplete_uploads.ex (cron-driven, Logger structured, max_attempts: 1) -->
```elixir
# Excerpt — adopter cron snippet pattern (cleanup_orphans.ex:9-22, abort_incomplete_uploads.ex:17-30)
@moduledoc """
...
## Cron Configuration Example
    config :my_app, Oban,
      queues: [rindle_<queue>: 1],
      plugins: [
        {Oban.Plugins.Cron,
         crontab: [
           {"0 * * * *", Rindle.Workers.<Worker>}
         ]}
      ]
...
"""

@spec perform(Oban.Job.t()) :: :ok | {:error, term()}
@impl Oban.Worker
def perform(%Oban.Job{}) do
  ...
end
```

<!-- TestRepoProbe pattern from maintenance_workers_test.exs:16-39 -->
```elixir
defmodule TestRepoProbe do
  @moduledoc false
  def all(queryable) do
    notify(:all)
    AdopterRepo.all(queryable)
  end
  # ... etc ...
end
```

<!-- MediaProviderAsset relevant fields for sync (REAL Phase 33 schema). -->
<!-- Note `playback_ids` is PLURAL ARRAY. There is NO `variant_name` column. -->
<!-- Unique constraint is on (asset_id, profile, provider_name). -->
```elixir
schema "media_provider_assets" do
  field :provider_asset_id, :string
  field :state, :string                       # FSM: pending|uploading|processing|ready|errored
  field :playback_ids, {:array, :string}, default: []   # PLURAL ARRAY
  field :playback_policy, :string
  field :ingest_mode, :string
  field :last_sync_error, :string             # truncated 4096
  field :raw_provider_metadata, :map, default: %{}
  belongs_to :asset, Rindle.Domain.MediaAsset, foreign_key: :asset_id
  timestamps()                                # updated_at used by stuck-threshold check
end

# @writable does NOT include :variant_name (no such column).
# changeset validate_required([:asset_id, :profile, :provider_name, :state]).
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: MuxSyncCoordinator (cron-driven fan-out enqueuer)</name>
  <files>lib/rindle/workers/mux_sync_coordinator.ex, test/rindle/workers/mux_sync_coordinator_test.exs</files>
  <read_first>
    - lib/rindle/workers/cleanup_orphans.ex (full file — `@moduledoc` cron snippet at lines 9-22, `perform/1` shape at lines 65-67, structured Logger at lines 101-130)
    - lib/rindle/workers/abort_incomplete_uploads.ex (full file — same template; `max_attempts: 1`)
    - test/rindle/workers/maintenance_workers_test.exs (full file — TestRepoProbe pattern lines 16-39, setup with adopter Repo + Sandbox checkout lines 41-69)
    - lib/rindle/domain/media_provider_asset.ex (REAL schema fields used in coordinator query: `state`, `updated_at`, `provider_asset_id`. NO `variant_name` column.)
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-PATTERNS.md section "lib/rindle/workers/mux_sync_coordinator.ex" + "test/rindle/workers/mux_sync_coordinator_test.exs"
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-CONTEXT.md decisions D-21, D-22, D-23, D-25
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-RESEARCH.md Pitfall 6 (queue flood) + Open Question 4 (LIMIT cap discretion)
  </read_first>
  <action>
**1a. Create `lib/rindle/workers/mux_sync_coordinator.ex`:**

```elixir
# Compiled only when {:mux, "~> 3.2"} is loaded.
if Code.ensure_loaded?(Mux.Video.Assets) do
  defmodule Rindle.Workers.MuxSyncCoordinator do
    @moduledoc """
    Oban cron worker that fans out per-row sync jobs for `media_provider_assets`
    rows in (`processing`, `uploading`) older than `provider_polling_floor_seconds`.

    Delegates per-row work to `Rindle.Workers.MuxSyncProviderAsset`. No sync
    logic lives here. Adopters can schedule this worker from their Oban cron
    config without requiring Rindle to supervise Oban.

    ## Cron Configuration Example

    In your Oban configuration:

        config :my_app, Oban,
          queues: [rindle_provider: 4],
          plugins: [
            {Oban.Plugins.Cron,
             crontab: [
               {"* * * * *", Rindle.Workers.MuxSyncCoordinator}
             ]}
          ]

    Cron resolution is 1 minute (Oban.Plugins.Cron docs); the coordinator's
    internal query enforces the `provider_polling_floor_seconds: 30` floor.

    ## Job Arguments

    This worker accepts no arguments. All behavior is driven by the
    `:provider_polling_floor_seconds` config under
    `config :rindle, Rindle.Streaming.Provider.Mux`.

    ## Return Contract

      * `:ok` — fan-out completed; per-row jobs enqueued.
      * Coordinator runs with `max_attempts: 1` because a missed cron tick is
        always cheaper to skip and re-run on the next tick than to retry
        mid-fanout.

    ## Backpressure (Pitfall 6 mitigation)

    Per-row unique constraint (`unique: [period: 60, keys: [:provider_asset_id]]`)
    deduplicates within the 60s window — the second cron tick will not
    re-fan-out a still-running per-row job. Phase 34 ships unbounded scan;
    if real-world adopter feedback shows queue floods (>1k stuck rows), add
    `LIMIT` cap in v1.7.
    """

    use Oban.Worker, queue: :rindle_provider, max_attempts: 1

    require Logger
    import Ecto.Query, only: [from: 2]

    alias Rindle.Domain.MediaProviderAsset

    @default_polling_floor_seconds 30

    @spec perform(Oban.Job.t()) :: :ok
    @impl Oban.Worker
    def perform(%Oban.Job{}) do
      repo = Rindle.Config.repo()
      floor = config(:provider_polling_floor_seconds, @default_polling_floor_seconds)
      cutoff = DateTime.add(DateTime.utc_now(), -floor, :second)

      provider_asset_ids =
        repo.all(
          from r in MediaProviderAsset,
            where: r.state in ["processing", "uploading"]
              and r.updated_at < ^cutoff
              and not is_nil(r.provider_asset_id),
            select: r.provider_asset_id
        )

      enqueued =
        provider_asset_ids
        |> Enum.map(fn provider_asset_id ->
          %{"provider_asset_id" => provider_asset_id}
          |> Rindle.Workers.MuxSyncProviderAsset.new(
            unique: [fields: [:args, :worker], period: 60, keys: [:provider_asset_id]]
          )
          |> Oban.insert()
        end)
        |> Enum.count(&match?({:ok, _}, &1))

      Logger.info("rindle.workers.mux_sync_coordinator.completed",
        rows_scanned: length(provider_asset_ids),
        jobs_enqueued: enqueued,
        floor_seconds: floor
      )

      :ok
    end

    defp config(key, default) do
      Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])
      |> Keyword.get(key, default)
    end
  end
end
```

**1b. Create `test/rindle/workers/mux_sync_coordinator_test.exs`:**

W1 fix: row attrs map below does NOT include `variant_name` — there is no
such column on `media_provider_assets` (B2 from Plan 02 applies here too).
The required schema fields are `[:asset_id, :profile, :provider_name, :state]`.

```elixir
defmodule Rindle.Workers.MuxSyncCoordinatorTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo

  alias Rindle.Domain.MediaProviderAsset
  alias Rindle.Workers.{MuxSyncCoordinator, MuxSyncProviderAsset}

  defp insert_row(state, age_seconds, provider_asset_id) do
    updated = DateTime.add(DateTime.utc_now(), -age_seconds, :second)

    # W1 fix: NO :variant_name in changeset attrs (no such column).
    {:ok, row} =
      %MediaProviderAsset{}
      |> MediaProviderAsset.changeset(%{
        asset_id: Ecto.UUID.generate(),
        profile: "TestProfile",
        provider_name: "mux",
        playback_policy: "signed",
        provider_asset_id: provider_asset_id,
        state: state
      })
      |> Repo.insert()

    # Force the updated_at to simulate age (changeset always bumps it).
    Ecto.Adapters.SQL.query!(
      Repo,
      "UPDATE media_provider_assets SET updated_at = $1 WHERE id = $2",
      [updated, Ecto.UUID.dump!(row.id)]
    )

    row
  end

  test "fans out per-row jobs for processing/uploading rows older than the floor" do
    Application.put_env(:rindle, Rindle.Streaming.Provider.Mux, provider_polling_floor_seconds: 30)

    _stale_processing = insert_row("processing", 60, "AbCd1234EfGh5678IjKl9012MnOp3456QrSt")
    _stale_uploading = insert_row("uploading", 45, "Up1234EfGh5678IjKl9012MnOp3456QrStAbCd")
    _fresh = insert_row("processing", 5, "Fresh1234EfGh5678IjKl9012MnOp3456QrSt")
    _ready = insert_row("ready", 3600, "Ready1234EfGh5678IjKl9012MnOp3456QrSt")

    assert :ok = perform_job(MuxSyncCoordinator, %{})

    # Two stale rows fanned out; fresh and ready did not.
    assert_enqueued worker: MuxSyncProviderAsset, args: %{"provider_asset_id" => "AbCd1234EfGh5678IjKl9012MnOp3456QrSt"}
    assert_enqueued worker: MuxSyncProviderAsset, args: %{"provider_asset_id" => "Up1234EfGh5678IjKl9012MnOp3456QrStAbCd"}
    refute_enqueued worker: MuxSyncProviderAsset, args: %{"provider_asset_id" => "Fresh1234EfGh5678IjKl9012MnOp3456QrSt"}
    refute_enqueued worker: MuxSyncProviderAsset, args: %{"provider_asset_id" => "Ready1234EfGh5678IjKl9012MnOp3456QrSt"}
  end

  test "second tick does not re-enqueue still-running per-row jobs (unique period: 60)" do
    Application.put_env(:rindle, Rindle.Streaming.Provider.Mux, provider_polling_floor_seconds: 30)
    _row = insert_row("processing", 60, "DupCheck1234EfGh5678IjKl9012MnOp3456")

    assert :ok = perform_job(MuxSyncCoordinator, %{})
    queued_after_first = all_enqueued(worker: MuxSyncProviderAsset) |> length()
    assert queued_after_first == 1

    # Second tick: per-row unique constraint with period: 60 deduplicates.
    assert :ok = perform_job(MuxSyncCoordinator, %{})
    queued_after_second = all_enqueued(worker: MuxSyncProviderAsset) |> length()
    assert queued_after_second == 1, "Second cron tick must not re-enqueue (Pitfall 6 mitigation via per-row unique)"
  end

  test "respects custom provider_polling_floor_seconds" do
    Application.put_env(:rindle, Rindle.Streaming.Provider.Mux, provider_polling_floor_seconds: 120)

    _just_old = insert_row("processing", 60, "JustOld1234EfGh5678IjKl9012MnOp3456QrSt")
    _very_old = insert_row("processing", 200, "VeryOld1234EfGh5678IjKl9012MnOp3456QrSt")

    assert :ok = perform_job(MuxSyncCoordinator, %{})

    refute_enqueued worker: MuxSyncProviderAsset, args: %{"provider_asset_id" => "JustOld1234EfGh5678IjKl9012MnOp3456QrSt"}
    assert_enqueued worker: MuxSyncProviderAsset, args: %{"provider_asset_id" => "VeryOld1234EfGh5678IjKl9012MnOp3456QrSt"}
  end
end
```

Run `mix test test/rindle/workers/mux_sync_coordinator_test.exs --max-failures 1` after writing both files.
  </action>
  <verify>
    <automated>mix compile --warnings-as-errors 2>&1 | tail -10 && grep -c "use Oban.Worker, queue: :rindle_provider, max_attempts: 1" lib/rindle/workers/mux_sync_coordinator.ex && grep -c "if Code.ensure_loaded?(Mux.Video.Assets) do" lib/rindle/workers/mux_sync_coordinator.ex && grep -c 'state in \["processing", "uploading"\]' lib/rindle/workers/mux_sync_coordinator.ex && grep -c "period: 60, keys: \[:provider_asset_id\]" lib/rindle/workers/mux_sync_coordinator.ex && grep -c 'crontab:' lib/rindle/workers/mux_sync_coordinator.ex && mix test test/rindle/workers/mux_sync_coordinator_test.exs --max-failures 1 2>&1 | tail -20</automated>
  </verify>
  <acceptance_criteria>
    - `lib/rindle/workers/mux_sync_coordinator.ex` opens with `if Code.ensure_loaded?(Mux.Video.Assets) do` (Pitfall 4 #2)
    - File contains `use Oban.Worker, queue: :rindle_provider, max_attempts: 1` (D-22, max_attempts: 1 because retrying fan-out is wasteful)
    - File contains `where: r.state in ["processing", "uploading"]` Ecto query
    - File contains `unique: [fields: [:args, :worker], period: 60, keys: [:provider_asset_id]]` (D-23, D-25)
    - File contains `Rindle.Workers.MuxSyncProviderAsset.new(...) |> Oban.insert()` fan-out call
    - `@moduledoc` contains the cron-config snippet (`{"* * * * *", Rindle.Workers.MuxSyncCoordinator}`)
    - File contains `Logger.info("rindle.workers.mux_sync_coordinator.completed", ...)` structured log
    - `test/rindle/workers/mux_sync_coordinator_test.exs` `insert_row/3` helper does NOT pass `variant_name:` to the changeset (W1 — no such column)
    - Test contains `assert_enqueued worker: MuxSyncProviderAsset` for stale rows and `refute_enqueued` for fresh rows
    - Test "second tick does not re-enqueue still-running per-row jobs" passes (Pitfall 6 unique-dedupe verification)
    - `mix test test/rindle/workers/mux_sync_coordinator_test.exs --max-failures 1` exits 0
  </acceptance_criteria>
  <done>Coordinator fans out per-row jobs for stale rows; per-row unique deduplicates across cron ticks; cron snippet documented in moduledoc; test setup uses real schema field names (no fictional `variant_name` column).</done>
</task>

<task type="auto">
  <name>Task 2: MuxSyncProviderAsset (per-row defensive sync)</name>
  <files>lib/rindle/workers/mux_sync_provider_asset.ex, test/rindle/workers/mux_sync_provider_asset_test.exs</files>
  <read_first>
    - lib/rindle/workers/abort_incomplete_uploads.ex (per-row simple `perform/1` shape — lines 71-99)
    - lib/rindle/workers/process_variant.ex (FSM transition + telemetry pattern at lines 461-485)
    - lib/rindle/streaming/provider.ex (`get_asset/1` callback contract — lines 67-75)
    - lib/rindle/domain/provider_asset_fsm.ex (FSM `transition/3` — third arg is a MAP)
    - lib/rindle/streaming/provider/mux.ex (Plan 01 — `get_asset/1` impl + `http_client/0` accessor)
    - lib/rindle/domain/media_provider_asset.ex (`redact_id/1` from Plan 01; field `playback_ids` is PLURAL ARRAY; unique constraint is `(asset_id, profile, provider_name)`)
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-PATTERNS.md section "lib/rindle/workers/mux_sync_provider_asset.ex" + "test/rindle/workers/mux_sync_provider_asset_test.exs"
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-CONTEXT.md decisions D-24, D-25, D-26, D-27
  </read_first>
  <action>
**2a. Create `lib/rindle/workers/mux_sync_provider_asset.ex`:**

```elixir
# Compiled only when {:mux, "~> 3.2"} is loaded.
if Code.ensure_loaded?(Mux.Video.Assets) do
  defmodule Rindle.Workers.MuxSyncProviderAsset do
    @moduledoc false
    # Per-row defensive sync for `media_provider_assets` rows that may have
    # missed a webhook. Called by `Rindle.Workers.MuxSyncCoordinator`.
    # (Plan 04 promotes this to a documented @moduledoc.)

    use Oban.Worker, queue: :rindle_provider, max_attempts: 3

    alias Rindle.Domain.{MediaProviderAsset, ProviderAssetFSM}

    @default_stuck_threshold_seconds 7200

    @spec perform(Oban.Job.t()) :: :ok | {:error, term()}
    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"provider_asset_id" => provider_asset_id}})
        when is_binary(provider_asset_id) do
      repo = Rindle.Config.repo()

      case repo.get_by(MediaProviderAsset, provider_asset_id: provider_asset_id) do
        nil ->
          # Row was deleted between coordinator scan and per-row execution.
          :ok

        row ->
          if stuck?(row) do
            mark_stuck(repo, row)
          else
            sync_with_provider(repo, row)
          end
      end
    end

    # ============================================================
    # Stuck-threshold check + transition to :errored
    # ============================================================

    defp stuck?(row) do
      threshold = config(:provider_stuck_threshold_seconds, @default_stuck_threshold_seconds)
      age = DateTime.diff(DateTime.utc_now(), row.updated_at, :second)
      row.state in ["processing", "uploading"] and age > threshold
    end

    defp mark_stuck(repo, row) do
      reason = "stuck in :#{row.state} past threshold"
      profile_atom = String.to_existing_atom(row.profile)

      # B4 fix: third arg is a MAP, not a keyword list (provider_asset_fsm.ex:28).
      with :ok <- ProviderAssetFSM.transition(row.state, "errored",
                    %{profile: profile_atom, provider: :mux, asset_id: row.asset_id}),
           {:ok, _} <-
             row
             |> MediaProviderAsset.changeset(%{state: "errored", last_sync_error: reason})
             |> repo.update() do
        emit_sync_event(:stuck, row, profile_atom)
        :ok
      end
    end

    # ============================================================
    # Per-row sync against live Mux state
    # ============================================================

    defp sync_with_provider(repo, row) do
      adapter = Rindle.Streaming.Provider.Mux

      case adapter.get_asset(row.provider_asset_id) do
        {:ok, %{state: live_state, playback_ids: pids, raw: _raw}} ->
          apply_state_transition(repo, row, live_state, pids)

        {:error, :not_found} ->
          # Mux deleted the asset; transition to :errored.
          profile_atom = String.to_existing_atom(row.profile)

          # B4 fix: third arg is a MAP.
          with :ok <- ProviderAssetFSM.transition(row.state, "errored",
                        %{profile: profile_atom, provider: :mux, asset_id: row.asset_id}),
               {:ok, _} <-
                 row
                 |> MediaProviderAsset.changeset(%{state: "errored", last_sync_error: "mux asset not found"})
                 |> repo.update() do
            emit_sync_event(:resolved, %{row | state: "errored"}, profile_atom)
            :ok
          end

        {:error, reason} ->
          {:error, reason}
      end
    end

    # B1 fix: persist `playback_ids` (PLURAL ARRAY) — schema field is
    # `field :playback_ids, {:array, :string}`. Write the list verbatim.
    defp apply_state_transition(repo, row, live_state, playback_ids) do
      profile_atom = String.to_existing_atom(row.profile)

      cond do
        live_state == row.state ->
          # No transition needed; just emit :resolved with current state.
          emit_sync_event(:resolved, row, profile_atom)
          :ok

        true ->
          # Always persist the live PLURAL playback_ids list (default to []
          # if Mux returned no ids — schema default is [] so this is safe).
          attrs = %{
            state: live_state,
            playback_ids: playback_ids || []
          }

          # B4 fix: third arg is a MAP.
          with :ok <- ProviderAssetFSM.transition(row.state, live_state,
                        %{profile: profile_atom, provider: :mux, asset_id: row.asset_id}),
               {:ok, updated} <-
                 row |> MediaProviderAsset.changeset(attrs) |> repo.update() do
            emit_sync_event(:resolved, updated, profile_atom)
            :ok
          end
      end
    end

    # ============================================================
    # Telemetry — security invariant 14 redaction at every emit.
    # ============================================================

    defp emit_sync_event(stage, row, profile) do
      age_ms = DateTime.diff(DateTime.utc_now(), row.updated_at, :millisecond)

      :telemetry.execute(
        [:rindle, :provider, :sync, stage],
        %{system_time: System.system_time()},
        %{
          profile: profile,
          provider: :mux,
          asset_id: MediaProviderAsset.redact_id(row.provider_asset_id),
          provider_state: row.state,
          age_ms: age_ms
        }
      )
    end

    defp config(key, default) do
      Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])
      |> Keyword.get(key, default)
    end
  end
end
```

**2b. Create `test/rindle/workers/mux_sync_provider_asset_test.exs`:**

```elixir
defmodule Rindle.Workers.MuxSyncProviderAssetTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Rindle.Domain.MediaProviderAsset
  alias Rindle.Workers.MuxSyncProviderAsset
  alias Rindle.Streaming.Provider.Mux.ClientMock

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      streaming: Rindle.Streaming.Provider.Mux,
      variants: [hero: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000
  end

  setup do
    prev = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])

    Application.put_env(:rindle, Rindle.Streaming.Provider.Mux,
      Keyword.merge(prev, [
        http_client: ClientMock,
        token_id: "test_id",
        token_secret: "test_secret",
        provider_stuck_threshold_seconds: 7200
      ])
    )

    on_exit(fn -> Application.put_env(:rindle, Rindle.Streaming.Provider.Mux, prev) end)
    :ok
  end

  # W1/B2 fix: NO :variant_name in changeset attrs (no such column).
  defp insert_row(state, age_seconds, opts \\ []) do
    provider_asset_id = Keyword.get(opts, :provider_asset_id, "AbCd1234EfGh5678IjKl9012MnOp3456QrSt")
    updated = DateTime.add(DateTime.utc_now(), -age_seconds, :second)

    {:ok, row} =
      %MediaProviderAsset{}
      |> MediaProviderAsset.changeset(%{
        asset_id: Ecto.UUID.generate(),
        profile: to_string(TestProfile),
        provider_name: "mux",
        playback_policy: "signed",
        provider_asset_id: provider_asset_id,
        state: state
      })
      |> Repo.insert()

    Ecto.Adapters.SQL.query!(
      Repo,
      "UPDATE media_provider_assets SET updated_at = $1 WHERE id = $2",
      [updated, Ecto.UUID.dump!(row.id)]
    )

    Repo.get!(MediaProviderAsset, row.id)
  end

  defp attach_telemetry(events) do
    test_pid = self()
    handler_id = "sync-test-#{System.unique_integer([:positive])}"
    :telemetry.attach_many(handler_id, events,
      fn evt, m, meta, _ -> send(test_pid, {:tele, evt, m, meta}) end,
      nil)
    on_exit(fn -> :telemetry.detach(handler_id) end)
    :ok
  end

  # ===========================================================
  # :resolved telemetry path — Mux returned new state
  # ===========================================================

  test "transitions row from :processing to :ready on Mux ready response, persists PLURAL playback_ids, emits :resolved" do
    row = insert_row("processing", 60)
    expect(ClientMock, :get_asset, fn _id ->
      {:ok, %{
        "id" => row.provider_asset_id,
        "status" => "ready",
        "playback_ids" => [%{"id" => "playback-id-test", "policy" => "signed"}]
      }}
    end)

    attach_telemetry([[:rindle, :provider, :sync, :resolved]])

    assert :ok = perform_job(MuxSyncProviderAsset, %{"provider_asset_id" => row.provider_asset_id})

    updated = Repo.get!(MediaProviderAsset, row.id)
    assert updated.state == "ready"
    # B1 fix: schema field is `playback_ids` (PLURAL ARRAY).
    assert is_list(updated.playback_ids)
    assert "playback-id-test" in updated.playback_ids

    assert_receive {:tele, [:rindle, :provider, :sync, :resolved], _, %{provider_state: "ready", asset_id: redacted}}, 500
    assert redacted =~ ~r/^\.\.\.[A-Za-z0-9]{4}$/, "asset_id must be redacted (security invariant 14)"
  end

  # ===========================================================
  # :stuck telemetry path — row exceeded threshold
  # ===========================================================

  test "transitions to :errored with reason :provider_asset_stuck past stuck threshold" do
    Application.put_env(:rindle, Rindle.Streaming.Provider.Mux, provider_stuck_threshold_seconds: 60)
    row = insert_row("processing", 120)  # 60s old, threshold 60s

    # Stuck path does NOT call get_asset/1.
    Mox.stub(ClientMock, :get_asset, fn _ -> raise "should not be called" end)

    attach_telemetry([[:rindle, :provider, :sync, :stuck]])

    assert :ok = perform_job(MuxSyncProviderAsset, %{"provider_asset_id" => row.provider_asset_id})

    updated = Repo.get!(MediaProviderAsset, row.id)
    assert updated.state == "errored"
    assert updated.last_sync_error =~ "stuck in :processing"

    assert_receive {:tele, [:rindle, :provider, :sync, :stuck], _, %{asset_id: redacted}}, 500
    assert redacted =~ ~r/^\.\.\.[A-Za-z0-9]{4}$/
  end

  # ===========================================================
  # Mux 404 (asset deleted) path
  # ===========================================================

  test "transitions to :errored when Mux returns :not_found" do
    row = insert_row("processing", 60)
    expect(ClientMock, :get_asset, fn _ ->
      {:error, "not found", %Tesla.Env{status: 404, body: ""}}
    end)

    attach_telemetry([[:rindle, :provider, :sync, :resolved]])

    assert :ok = perform_job(MuxSyncProviderAsset, %{"provider_asset_id" => row.provider_asset_id})

    updated = Repo.get!(MediaProviderAsset, row.id)
    assert updated.state == "errored"
    assert updated.last_sync_error == "mux asset not found"
  end

  # ===========================================================
  # Idempotency — same state means no transition, but :resolved still fires
  # ===========================================================

  test "no-op transition when live state matches local row state" do
    row = insert_row("processing", 60)
    expect(ClientMock, :get_asset, fn _ ->
      {:ok, %{"id" => row.provider_asset_id, "status" => "preparing", "playback_ids" => []}}
    end)

    # Note: Plan 01 `get_asset/1` reshapes "preparing" -> "processing".
    attach_telemetry([[:rindle, :provider, :sync, :resolved]])

    assert :ok = perform_job(MuxSyncProviderAsset, %{"provider_asset_id" => row.provider_asset_id})

    updated = Repo.get!(MediaProviderAsset, row.id)
    assert updated.state == "processing", "state should remain processing — no transition needed"

    assert_receive {:tele, [:rindle, :provider, :sync, :resolved], _, _}, 500
  end

  # ===========================================================
  # Missing row — coordinator scanned a row that was deleted before per-row ran
  # ===========================================================

  test "returns :ok when row no longer exists (race with deletion)" do
    assert :ok = perform_job(MuxSyncProviderAsset, %{"provider_asset_id" => "DoesNotExist1234"})
  end
end
```

Run `mix test test/rindle/workers/mux_sync_provider_asset_test.exs --max-failures 1` after writing both files.
  </action>
  <verify>
    <automated>mix compile --warnings-as-errors 2>&1 | tail -10 && grep -c "use Oban.Worker, queue: :rindle_provider, max_attempts: 3" lib/rindle/workers/mux_sync_provider_asset.ex && grep -c "if Code.ensure_loaded?(Mux.Video.Assets) do" lib/rindle/workers/mux_sync_provider_asset.ex && grep -c "Rindle.Streaming.Provider.Mux.get_asset" lib/rindle/workers/mux_sync_provider_asset.ex && grep -v '^[[:space:]]*#' lib/rindle/workers/mux_sync_provider_asset.ex | grep -c "MediaProviderAsset.redact_id" && grep -c ":telemetry.execute(\[:rindle, :provider, :sync" lib/rindle/workers/mux_sync_provider_asset.ex && grep -c "playback_ids:" lib/rindle/workers/mux_sync_provider_asset.ex && mix test test/rindle/workers/mux_sync_provider_asset_test.exs --max-failures 1 2>&1 | tail -20</automated>
  </verify>
  <acceptance_criteria>
    - `lib/rindle/workers/mux_sync_provider_asset.ex` opens with `if Code.ensure_loaded?(Mux.Video.Assets) do` (Pitfall 4 #2)
    - File contains `use Oban.Worker, queue: :rindle_provider, max_attempts: 3` (D-25)
    - File contains `Rindle.Streaming.Provider.Mux.get_asset(row.provider_asset_id)` call
    - File contains `:telemetry.execute([:rindle, :provider, :sync, :resolved], ...)` AND `:telemetry.execute([:rindle, :provider, :sync, :stuck], ...)` (D-26)
    - Every telemetry emit metadata includes `asset_id: MediaProviderAsset.redact_id(row.provider_asset_id)` (security invariant 14)
    - `apply_state_transition/4` writes `playback_ids: playback_ids || []` (PLURAL ARRAY — B1 fix; matches Phase 33 schema field `field :playback_ids, {:array, :string}`)
    - File contains NO references to a singular `playback_id:` column (B1 — `grep -v '^[[:space:]]*#' lib/rindle/workers/mux_sync_provider_asset.ex | grep -c "playback_id:"` returns 0)
    - Every `ProviderAssetFSM.transition/3` call passes a MAP as the third argument (B4 — `%{profile: ..., provider: :mux, asset_id: ...}`), NEVER a keyword list
    - `stuck?/1` predicate checks `row.state in ["processing", "uploading"]` AND `age > threshold`
    - `mark_stuck/2` writes `last_sync_error` containing the substring `"stuck in :"` (matches the test assertion)
    - File uses `String.to_existing_atom(row.profile)` (NOT `String.to_atom`)
    - Test file's `insert_row/3` helper does NOT pass `variant_name:` to the changeset (W1/B2)
    - Test file contains test "transitions row from :processing to :ready on Mux ready response, persists PLURAL playback_ids, emits :resolved" — asserts `is_list(updated.playback_ids)` and `"playback-id-test" in updated.playback_ids` (B1)
    - Test file contains test "transitions to :errored with reason :provider_asset_stuck past stuck threshold"
    - Test file contains test "returns :ok when row no longer exists (race with deletion)"
    - Test file asserts `redacted =~ ~r/^\.\.\.[A-Za-z0-9]{4}$/` for both :resolved and :stuck telemetry events
    - `mix test test/rindle/workers/mux_sync_provider_asset_test.exs --max-failures 1` exits 0
  </acceptance_criteria>
  <done>Per-row sync worker fully implemented: handles :ready/:errored Mux states, transitions FSM with MAP context (B4), persists PLURAL `playback_ids` (B1), surfaces stuck rows past threshold, emits redacted-metadata telemetry on every event; test setup uses real schema field names (no fictional `variant_name`).</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Adopter cron tick → Coordinator | Adopter wires `Oban.Plugins.Cron` per Phase 36's guide; coordinator accepts no args. |
| Coordinator → per-row worker | Internal Oban enqueue with unique constraint; `provider_asset_id` is the only arg. |
| Per-row worker → Mux REST API | Server-to-server via Plan 01 adapter; HTTP Basic Auth; `provider_asset_id` is server-known (never client-supplied). |
| Per-row worker → telemetry consumers | Adopter telemetry handlers receive metadata; redaction enforced at emit (security invariant 14). |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-34-03-01 | Denial of Service | Coordinator queue flood at 1k+ stuck rows | accept | Per-row unique constraint (`period: 60, keys: [:provider_asset_id]`) deduplicates within 60s window — second cron tick will not re-fan-out (Pitfall 6). Phase 34 ships unbounded; v1.7 adds LIMIT cap if real-world feedback warrants. |
| T-34-03-02 | Information Disclosure | Telemetry `metadata.asset_id` leaking raw `provider_asset_id` | mitigate | `MediaProviderAsset.redact_id/1` flows on every emit; regex test asserts `~r/^\.\.\.[A-Za-z0-9]{4}$/` for both `:resolved` and `:stuck` events. |
| T-34-03-03 | Spoofing | `args["provider_asset_id"]` from Oban arg accepted without verification | mitigate | Per-row worker resolves the row via `repo.get_by(MediaProviderAsset, provider_asset_id: ...)`; if the row does not exist the worker returns `:ok` (race-with-deletion) — no spurious state change. The arg only references rows that the coordinator scanned, so adversarial input would require Oban table write access (out-of-scope). |
| T-34-03-04 | Tampering | Coordinator triggering FSM transition on a fresh row | mitigate | Coordinator's `where: r.updated_at < ^cutoff` only matches rows older than `provider_polling_floor_seconds`; per-row worker re-checks `stuck?/1` against the current row state. |
| T-34-03-05 | Availability | Per-row worker compiled in adopter without `:mux` dep → crash | mitigate | Worker module wrapped in `if Code.ensure_loaded?(Mux.Video.Assets) do` (Pitfall 4 #2). |
| T-34-03-06 | Information Disclosure | `last_sync_error` truncation missing → leaks long Mux response bodies | mitigate | Reason strings written by `mark_stuck/2` and `:not_found` handler are bounded (`"stuck in :processing past threshold"`, `"mux asset not found"` — both < 50 bytes). Phase 34 worker does not concatenate Mux response bodies into the field. |
| T-34-03-07 | Repudiation | FSM transition without telemetry trace | mitigate | Every FSM transition path (`:resolved`, `:stuck`, `:not_found`) emits `[:rindle, :provider, :sync, _]` with `provider_state` and `age_ms` — full audit trail in adopter telemetry pipeline. Every `ProviderAssetFSM.transition/3` call passes a MAP context (B4 — matches `provider_asset_fsm.ex:28` spec). |
</threat_model>

<verification>
- `mix compile --warnings-as-errors` exits 0
- `mix test test/rindle/workers/mux_sync_coordinator_test.exs test/rindle/workers/mux_sync_provider_asset_test.exs --max-failures 1` exits 0
- `mix test test/rindle/workers/maintenance_workers_test.exs --max-failures 1` exits 0 (regression — coordinator pattern adoption did not break existing maintenance workers)
- `grep -c "max_attempts: 1" lib/rindle/workers/mux_sync_coordinator.ex` returns ≥ 1 (D-22)
- `grep -c "max_attempts: 3" lib/rindle/workers/mux_sync_provider_asset.ex` returns ≥ 1 (D-25)
- `grep -c "period: 60" lib/rindle/workers/mux_sync_coordinator.ex` returns ≥ 1 (D-23 — per-row unique window)
- `grep -v '^[[:space:]]*#' lib/rindle/workers/mux_sync_provider_asset.ex | grep -c "MediaProviderAsset.redact_id"` returns ≥ 1 (security invariant 14)
- `grep -c ":telemetry.execute" lib/rindle/workers/mux_sync_provider_asset.ex` returns ≥ 1 (MUX-08 telemetry contract)
- `grep -c "playback_ids:" lib/rindle/workers/mux_sync_provider_asset.ex` returns ≥ 1 (B1 — PLURAL field write)
- `grep -v '^[[:space:]]*#' lib/rindle/workers/mux_sync_provider_asset.ex | grep -c "playback_id:"` returns 0 (B1 — singular field is gone)
- `grep -E "ProviderAssetFSM\.transition\(.*,\s*\[" lib/rindle/workers/mux_sync_provider_asset.ex | wc -l` returns 0 (B4 — no keyword-list third arg)
- `grep -A 5 "MediaProviderAsset.changeset" test/rindle/workers/mux_sync_coordinator_test.exs test/rindle/workers/mux_sync_provider_asset_test.exs | grep -c "variant_name:"` returns 0 (W1/B2 — no fictional column in test setup)
</verification>

<success_criteria>
1. **MUX-07 coordinator:** `MuxSyncCoordinator.perform/1` selects rows in (`processing`, `uploading`) older than `provider_polling_floor_seconds` (default 30) and fans out per-row jobs unique by `provider_asset_id` for 60s.
2. **MUX-07 per-row:** `MuxSyncProviderAsset.perform/1` calls `Rindle.Streaming.Provider.Mux.get_asset/1`, transitions FSM (with MAP context per B4) to match Mux state, persists PLURAL `playback_ids` (per B1), transitions to `:errored` with reason `:provider_asset_stuck` past `provider_stuck_threshold_seconds` (default 7200).
3. **Telemetry contract (MUX-08 partial):** Per-row worker emits `[:rindle, :provider, :sync, :resolved]` and `[:rindle, :provider, :sync, :stuck]` with metadata `%{profile, provider, asset_id, provider_state, age_ms}` where `asset_id` is redacted.
4. **Security invariant 14:** Telemetry test asserts `redacted =~ ~r/^\.\.\.[A-Za-z0-9]{4}$/` for both event types.
5. **Optional-dep guard:** Both worker modules wrapped in `if Code.ensure_loaded?(Mux.Video.Assets) do`.
6. **Pitfall 6 mitigation:** Test confirms second cron tick does not re-fan-out a still-running per-row job (per-row unique with `period: 60` deduplicates).
7. **Adopter cron snippet:** `MuxSyncCoordinator` `@moduledoc` documents the cron-config snippet (`{"* * * * *", Rindle.Workers.MuxSyncCoordinator}`) so Phase 36's guide can copy verbatim.
8. **Schema fidelity:** Tests use real Phase 33 schema field names — `playback_ids` (PLURAL ARRAY); test setup does NOT include the fictional `variant_name:` column (W1/B2).
9. **FSM contract:** Every `ProviderAssetFSM.transition/3` call passes a MAP as the third argument (B4 — matches `provider_asset_fsm.ex:28` spec).
</success_criteria>

<output>
After completion, create `.planning/phases/34-mux-rest-adapter-server-push-sync/34-03-SUMMARY.md` documenting:
- Coordinator + per-row worker files created (line counts)
- Test pass/fail breakdown for :resolved and :stuck paths
- Stuck-threshold + polling-floor defaults (7200s and 30s)
- Telemetry events emitted with redacted metadata confirmation
- PLURAL playback_ids write confirmation (B1)
- FSM transition MAP-context confirmation (B4)
- Any deviations from CONTEXT.md / RESEARCH.md (none expected)
</output>
</content>
</invoke>