# Phase 138: Lifecycle Failure and Recovery Matrix — Pattern Map

**Mapped:** 2026-10-21  
**Files analyzed:** 23 likely new/modified files across 16 owner groups  
**Analogs found:** 23/23 (including partial role matches)  
**Source gate:** Analog paths below are git-tracked in the authoritative worktree. Proposed new paths are planning suggestions, not established files.

## File Classification

| New/modified owner | Role | Data flow | Closest tracked analog | Match |
|---|---|---|---|---|
| `scripts/maintainer/built_package_twin.py` | runner/controller | batch, request-response | same file | exact extension |
| `scripts/maintainer/twin_receipt.py` | verifier/model | transform | same file | exact extension |
| `scripts/maintainer/twin_cleanup.py` | cleanup utility | batch | same file | exact extension |
| `test/twin/host/lib/twin/tracer.ex` | host scenario service | event-driven, CRUD | same file | exact extension |
| `test/twin/host/lib/twin/storage.ex` | host storage adapter | file-I/O | same file | exact extension |
| `test/twin/host/lib/twin/web.ex` | HTTP route | request-response, streaming | same file; `lib/rindle/upload/tus_plug.ex` | role + protocol |
| `test/twin/host/lib/twin/application.ex` | application/supervision | event-driven | same file | exact extension |
| `test/twin/host/config/config.exs`, `config/runtime.exs`, `mix.exs` | config | request-response | same host files | exact extension |
| `test/twin/host/lib/twin/mux_fixture.ex` (if separate) | local HTTP fixture | request-response | `test/twin/host/lib/twin/web.ex`; `lib/rindle/streaming/provider/mux/http.ex` | role match |
| `lib/rindle/workers/ingest_provider_webhook.ex` | worker | event-driven, CRUD | same file | exact correction owner |
| `lib/rindle/domain/provider_asset_fsm.ex` (only if effect ordering requires) | model | transform, event-driven | same file | exact correction owner |
| `lib/rindle/domain/media_provider_asset.ex` (existing fields only) | model | CRUD | same file | exact extension |
| `test/rindle/workers/ingest_provider_webhook_test.exs` | test | event-driven | same file | exact extension |
| `test/rindle/workers/purge_storage_test.exs`, `process_variant_test.exs` | tests | event-driven, file-I/O | same files | exact extension |
| `test/install_smoke/twin_{receipt,cleanup,cli,fault,tracer_contract}_test.exs` | tests | batch, request-response | same files | exact extension |
| `guides/built_package_twin.md` | documentation | batch | same file | exact extension |

`lib/rindle/workers/purge_storage.ex`, `process_variant.ex`, `promote_asset.ex`, `lib/rindle/ops/upload_maintenance.ex`, and supported Mix tasks are behavioral seams to exercise first; no change to them is implied by the matrix. A discovered defect can justify a narrow change with its focused regression test. Proposed fixture ownership can remain within `Twin.Router`/`Twin.Tracer` if a separate module adds no clarity. No new schema, public API, dependency family, or generic fault framework is indicated.

## Pattern Assignments

### Runner, retained inputs and one archive: `built_package_twin.py`

**Analog:** `scripts/maintainer/built_package_twin.py`.

**Imports and contract ownership** (lines 1–26): standard library only; import `dispose`, `validate_descriptor` from `twin_cleanup`, and `verify_receipt`, `require`, `Refused`, safe diagnostic primitives from `twin_receipt`. `TOOLCHAIN` fixes the supported diagonal.

**Bounded private execution** (lines 165–186): `Runner.command` writes child output to an exclusive mode-0600 private file, polls timeout/size, kills its process group on failure, and surfaces only fixed `Refused` codes. Extend its stage/reason allowlists for finite cases; do not export raw command output.

**Fresh package and immutable bindings** (lines 225–285): `stage_inputs()` copies the allowlisted host tree, runs `mix hex.build`, extracts and validates the archive, hashes package/host/lock/config/contract/fixture/build, then writes `inputs.json` and an exact resource descriptor. Preserve this single-build boundary for the full matrix; bind each case identity and retained inputs to those values. Update `HOST_FILES`/`validate_host_inputs` (lines 96–105) if a new host file is added. `validate_stage()` checks staged hashes, Compose service/mount/environment identity (lines 288–310). `validate_archive()` independently rehashes the archive (lines 142–146).

**Host boundary guard** (lines 149–152): `validate_host_surface` rejects direct worker execution, Oban drain/retry/testing shortcuts, Sandbox, domain writes and rewritten schedules. Extend for any discovered shortcut; host-owned `twin_fault_counters` are the established narrow persistent fixture exception.

### Typed matrix receipt: `twin_receipt.py`

**Analog:** `scripts/maintainer/twin_receipt.py`.

**Exact schema primitives** (lines 10–16, 23–56): `SCENARIO`, `KIND`, `DOMAIN`, `HASHES`, `STAGES`; `require`, duplicate-key rejecting `decode`, exact `keys`, typed `integer`/`text`/`boolean`/UUID `identity`. Keep one closed common envelope and finite scenario-specific validators. Preserve interpretation of the Phase 137 single-case receipt through explicit version/scenario dispatch.

**Independent binding** (lines 64–73, 90–98): `validate_inputs` enforces exact keys, supported versions and hash syntax; `verify_receipt(inputs, receipt)` requires complete receipt and equality with separately retained inputs. Matrix validation should require exactly the six RECOV case IDs, distinct case/run identities, same archive/host/contract bindings, and complete typed case payloads. A focused case run is diagnostic, not a full pass.

**Predicate style** (lines 76–79, 99–165): `barrier_ok` asserts paused/no-running plus retryable attempt-one with stored error; the verifier checks same job ID through attempt two and exact final inventory/job set. Replace fixed image-only counts with per-case declared counts and one full-matrix inventory; reject unexplained history/residue, duplicate/skipped/unknown cases and swapped identities. `safe_diagnostic` exports fixed fields only (lines 168–174).

### Exact owned disposal: `twin_cleanup.py`

**Analog:** `scripts/maintainer/twin_cleanup.py`.

`validate_descriptor` binds exact project, database, bucket, host, volumes, network, image, hashes and paths (lines 14–35). `containers()` checks Compose labels and refuses a live host (lines 38–52). `dispose()` checks foreign volume/network users before mutation, rechecks liveness, and removes resources without force/prune (lines 59–93). Extend descriptor identities only as required by case isolation; freeze the domain verdict before calling disposal. Test repeated disposal and foreign-resource refusal in `test/install_smoke/twin_cleanup_test.exs` (lines 31–96).

### Host scenario and queue barriers: `Twin.Tracer`

**Analog:** `test/twin/host/lib/twin/tracer.ex`.

**Request entry and safe failures** (lines 11–49): GenServer serializes control calls; `execute/2` has a finite 150-second call budget; `handle_call` returns fixed `incomplete` reason codes on exceptions. Keep scenario-specific operations narrow and validate parameters before using them.

**One stimulus and ordinary lifecycle** (lines 51–112): exclusive run-scoped fixture claim, public `Rindle.initiate_upload`, actual signed S3 PUT, public `Rindle.verify_completion`, `ready_variants_for`, `attach` and `detach`. Each case should own a distinct run-scoped fixture claim and resource set. The image fixture here is only an analog for structure; AV needs real valid media and its own profile.

**Durable job barrier** (lines 113–159, 162–189): read `Oban.Job` until retryable attempt one/errors exist, call `Oban.pause_queue`, wait for `Oban.check_queue` paused with `running == []`, then re-read the job and apply `barrier?/2` (lines 249–252). Use the same pause/quiescence/re-read pattern for the available attempt-zero promotion cut and AV/provider cuts. Polling is bounded by `wait/poll` (lines 265–276); adjust measured deadlines without changing job attempts or schedules.

**Read-only inventory** (lines 191–244): pause every queue and wait for no running work before catalog/domain/Oban/temp counts. Extend inventory to exact source/variant keys, multipart upload IDs and parts, provider fixture effects, processes and allowed history. Unknown/truncated/denied observations must fail. Do not count infrastructure disposal as domain cleanup.

### Fixed storage faults and profiles: `Twin.StorageFault`, `Twin.Profile`

**Analog:** `test/twin/host/lib/twin/storage.ex`.

The wrapper declares `@behaviour Rindle.Storage` and delegates every unaffected callback to `Rindle.Storage.S3` (lines 1–28). `delete/2` selects only the run-owned exact source key (lines 30–43); an atomic SQL `UPDATE ... claims=0 RETURNING` commits one fault before network I/O, then delegates subsequent calls (lines 46–67). Copy that exact-key and committed-claim discipline for one post-download worker-temp corruption and the post-delete janitor block; preserve real S3 operations and all advertised capabilities. `Twin.Profile` is a small `use Rindle.Profile` declaration with storage, variants, MIME and size (lines 70–76); add a video/audio profile and supported derivative there or in a focused host module.

`test/install_smoke/twin_fault_test.exs` lines 59–96 tests concurrent claims, one failure, resumed delegation and capability export. Add equivalent focused fault restoration tests; do not use broad process-global fault switches.

### Actual tus and signed provider ingress: host web/config

**Analogs:** `test/twin/host/lib/twin/web.ex`, `application.ex`, `config/config.exs`; protocol owners `lib/rindle/upload/tus_plug.ex` and `lib/rindle/delivery/webhook_plug.ex`.

`Twin.Router` uses `Plug.Router`, `plug(:match)`, `plug(:dispatch)` and a control-secret guarded POST with bounded `read_body` (web lines 1–22); `Twin.Endpoint` mounts it (lines 25–28). Add actual tus and webhook routes ahead of the catchall, using the shipped Plugs. TusPlug documents same-node S3 tail retention (lines 55–69); the host should stay one node for RECOV-01. A separate client-process interrupt/resume precedent exists in `test/install_smoke/support/generated_app/profile_helpers.ex` lines 759–793 (`node ... interrupt`, then a new `node ... resume`); adapt the protocol sequence without importing its Sandbox/inline-job test setup. Assert fresh HEAD offset, wrong-offset rejection, final checksum and exact keys.

`Twin.Application` supervises one Repo, one Oban, tracer and endpoint (lines 1–18). `config/config.exs` supplies ordinary queues (lines 1–13), endpoint (15–20) and no raw logging (22–25). Add `:rindle_provider` to the ordinary queue list and activate the already locked optional `:mux` SDK in host `mix.exs`; configure the shipped adapter through `:base_url` (`lib/rindle/streaming/provider/mux/http.ex` lines 97–109). The local HTTP fixture should answer the SDK's actual outbound create protocol; keep credentials dummy and record only count/shape. Signed raw-body webhook ingress must use the normal Plug, which enqueues with `IngestProviderWebhook.new(unique: ... ) |> Oban.insert()` (`lib/rindle/delivery/webhook_plug.ex` lines 176–202). Avoid duplicate endpoint/Oban supervision in maintenance task processes.

### Provider update and regression owner

**Analogs:** `lib/rindle/workers/ingest_provider_webhook.ex`, `lib/rindle/domain/provider_asset_fsm.ex`, `lib/rindle/domain/media_provider_asset.ex`.

The worker uses Oban queue `:rindle_provider`, five attempts and event-ID uniqueness across active states (worker lines 66–96); completed jobs are outside the unique set. `perform` currently looks up a row then dispatches (105–128); ready/errored/created paths parse `occurred_at` and write `last_event_at` (175–207, 222–315). `transition_and_broadcast` transitions, updates, then broadcasts and emits telemetry (342–375). The FSM allows ready→errored (FSM lines 8–15) and emits state-change telemetry before persistence (20–46). The model already has `last_event_id` and microsecond `last_event_at` (model lines 43–77).

Reproduce stale created **and** errored after newer ready, pending and post-completion duplicates, equal/missing time and concurrent handlers before fixing. Keep lookup/order decision/update cohesive and serialized at the row, with effects after accepted commit; do not assume a read/check/write guard is race-safe or suppress legitimate newer ready→errored. Preserve `broadcast`'s provider-ID-free payload (worker lines 387–405) and `emit`'s redaction (423–439). `test/rindle/workers/ingest_provider_webhook_test.exs` lines 1–90 establishes DataCase/Oban.Testing, telemetry capture and row/event factories; lines 131–145 covers active-job uniqueness. Extend it for ordering, concurrency, committed effects and redaction. The real host matrix must still use normal Oban scheduling and HTTP ingress.

### Retry, AV and supported repair

**Analogs:** `lib/rindle/workers/purge_storage.ex`, `process_variant.ex`, `lib/rindle/ops/lifecycle_repair.ex`.

Purge loads all variant/source keys, deletes storage before the asset row, replays already-deleted keys and accepts only `:not_found`/`:enoent` as absence (purge lines 25–58). `test/rindle/workers/purge_storage_test.exs` lines 114–158 proves retained rows after failure, retry, and those two error atoms; add an explicit error-atom branch only if missing coverage is found. The host must establish authoritative S3 absence separately before attempt two; unversioned missing DELETE is normally success.

`ProcessVariant` declares `max_attempts: 5`, AV queue `:rindle_media`, `build_job`/queue selection (lines 1–83), and downloads actual source into a temporary run directory before processing (119–130). Corrupt only the delegated download destination in the host wrapper; retain through real discard, then use public `Rindle.requeue_variants/2` (backed by `LifecycleRepair.requeue_failed_variants/2` at lines 72 onward). Inspect actual new job ID, ready state, output download, probe and full decode. Keep the real FFmpeg/ffprobe and MinIO path.

### Supported upload maintenance and interrupted janitor

**Analogs:** `lib/mix/tasks/rindle.abort_incomplete_uploads.ex`, `rindle.cleanup_orphans.ex`, `lib/rindle/ops/upload_maintenance.ex`.

Abort task starts the app and invokes `UploadMaintenance.abort_incomplete_uploads([])` (task lines 44–60). Cleanup task parses `--no-dry-run`, starts the app and passes `[dry_run: false]` plus optional storage adapter (task lines 63–96). The service defaults to dry run (maintenance lines 57–65), targets genuinely expired incomplete sessions (76–95), deletes storage before the session row (272–301), and retries a missing object idempotently (382–395). Multipart cleanup calls the adapter's `abort_multipart_upload` for a real upload ID (355–379, 616–641). Use public short expiry/options, put a real part, wait for expiry, run abort, then block the host-owned wrapper only after real delete and before janitor row deletion. Terminate that task process, inspect absent object + retained row, rerun twice and inventory upload IDs/parts. `test/rindle/ops/upload_maintenance_{abort,cleanup,tus}_test.exs` and `test/support/upload_maintenance_case.ex` are focused behavior analogs.

## Shared Patterns

- **No consumer shortcut:** `built_package_twin.py` lines 149–152 plus `test/install_smoke/twin_fault_test.exs` lines 100–124 guard against private workers, Sandbox, direct domain writes and schedule manipulation. Read-only Repo/Oban observations remain valid.
- **Fault provenance:** `Twin.StorageFault` lines 30–67 claims one exact, run-owned fault durably, then delegates all normal storage calls. Host-only fixture writes belong to `twin_fault_counters`; state outcomes come from real storage/domain/Oban.
- **Queue and temporal proof:** `Twin.Tracer` lines 113–141 and 191–205 pause/check/re-read, with bounded polling at 265–276. Run restart and retry claims at a quiescent durable cut.
- **Safe evidence:** `Runner.command` lines 165–186 retains private bounded captures; `twin_receipt.py` lines 28–56, 90–98 and 168–174 enforce exact types, separate input authority and allowlisted diagnostics. Test canaries in `test/install_smoke/twin_receipt_test.exs` lines 77–105.
- **Final audit before disposal:** `Twin.Tracer` lines 191–244 stops writers and observes live resources; `twin_cleanup.py` lines 59–93 disposes only exact owned infrastructure after the verdict.

## No Analog Found

No existing tracked **host** local Mux HTTP fixture, real AV matrix scenario, or complete six-scenario typed receipt exists. Use the closest listed route/storage/runner/worker analogs and the protocol details in `138-RESEARCH.md`; these are new bounded cases, not evidence already delivered by Phase 137.

## Metadata

**Analog search scope:** `scripts/maintainer`, `test/twin/host`, `test/install_smoke`, `test/rindle`, `lib/rindle`, `lib/mix/tasks`.  
**Pattern extraction date:** 2026-10-21.  
**Planner boundary:** RECOV-01..06 only; Phase 139 owns exact-head readiness and Doctor migration-ledger work. Six vertical slices at most, three tasks each, share one archive per complete invocation.
