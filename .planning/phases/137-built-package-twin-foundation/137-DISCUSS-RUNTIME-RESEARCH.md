# Phase 137 runtime, durable jobs, restart, and fault-boundary research

Researched 2026-10-21. Recommendation for discussion/planning, not acceptance evidence. No services, credentials, live provider actions, package installation, or runtime tests were executed. Scope: TWIN-03/04/05 and runtime contributions to TWIN-06; RECOV-01–06 inform interfaces but remain Phase 138 work.

## Cohesive recommendation

Use one minimal external Phoenix adopter host, with its own ordinary supervised Repo and **default `Oban` instance in normal mode**, real PostgreSQL, MinIO, and media tools. An external controller owns the host OS process, startup deadline, termination, restart, retained run identifiers, observations, and cleanup. Existing Docker/Compose is the provisional authoritative runtime: the isolated host BEAM may run inside its own container, with the package/host staged independently and no checkout mount. Configure once at boot; do not inherit ExUnit sandbox ownership or Cohort's test configuration. Build one end-to-end tracer: upload/attach/detach through supported APIs, fail one actual storage delete, observe persisted Oban failure, terminate the BEAM **between attempts**, restart against the same database/object/temp namespace, and observe the same job complete without a second detach. This proves the Phase 137 interfaces; it does not claim the Phase 138 matrix or in-flight orphan rescue.

Prefer the shipped retry cadence for this single failure. Do not patch workers, manufacture retry rows, update `scheduled_at`, or install a scheduler/fault framework merely to save approximately 18 seconds. Use a unique per-run database, supported Rindle `rindle` schema, host/Oban `public` schema, object prefix, and temp root. Keep the host and all twin adapters outside the package. **Use one tiny fixed host-owned PostgreSQL fault table through the existing Repo**: atomic allocation survives BEAM/container restart and concurrent callbacks without adding file-locking or a control protocol. Its cost is one fixture migration and cleanup obligation; its scope is run/operation/key/remaining-failures, not an evidence database, generic registry, framework, or journal.

This applies the existing DNA: explicit behaviours, atomic durable state, side effects outside transactions, bounded observability, no optional-dependency leakage (`prompts/gsd-rindle-elixir-oss-dna.md:72–129`; `prompts/phoenix-media-uploads-lib-deep-research.md:194,625–629`). Earlier milestone research proposed Cohort plus manual drains (`.planning/research/STACK.md:67–75`, `ARCHITECTURE.md:180–189`). The recommendation changes those *mechanisms* because shipped code reveals inline/manual and ownership baggage; it preserves their public-boundary, no-product-API, synthetic-evidence constraints. Dedicated external-host choice is coordinated with package research.

## Shipped truth and integration map

| Inspected source | Consequence |
|---|---|
| `guides/getting_started.md:78–115` | Adopter owns Repo and the default `Oban`; arbitrary named-instance routing is explicitly outside the contract. Use default name `Oban` in the isolated host, not `Twin.Oban`. |
| `guides/getting_started.md:117–159` | Separate host migrations invoke `Oban.Migration` and pinned `Rindle.Migration.up(version: 1)`. Preserve host/public versus Rindle schema ownership. |
| `lib/rindle/schema.ex:4,13–17,39` | Rindle prefix is compiled and limited to `rindle` or `public`. Arbitrary `twin_<run>` schema prefixes are unsupported. This is research evidence, not permission for runtime private-module introspection. |
| `examples/adoption_demo/lib/adoption_demo/application.ex:12–22` | Repo before Oban in a conventional `:one_for_one` application supervision tree is the reusable ownership pattern. |
| `examples/adoption_demo/config/test.exs:16–31` | `PHX_SERVER` removes Sandbox but leaves `testing: :inline`. Browser-server execution therefore is not proof of production Oban retries. |
| `examples/adoption_demo/lib/adoption_demo/application.ex:8–10` | Test boot also configures Mux cassettes; avoid inheriting unrelated test boot assumptions. |
| `test/install_smoke/support/generated_app/patcher.ex:119–131` | Generated consumers currently set `testing: :manual`; reuse package/migration ideas, not retry-runtime settings. |
| `test/install_smoke/support/generated_app/workspace.ex:7–10,54–78,109–116` | Existing temporary workspace and package build ideas are useful. Its `MIX_ENV=test` and inherited environment are not the new host's runtime authority. |
| `lib/rindle/storage.ex:3–7,120–150` | Storage is the clean configurable fault seam, with exact callback return shapes and explicit external-I/O transaction discipline. |
| `lib/rindle/profile.ex:25–31,35–63` | Public profile DSL selects the storage adapter at compile time. A host adapter can delegate to `Rindle.Storage.S3`. |
| `lib/rindle/processor.ex:1–20` and `lib/rindle/workers/process_variant.ex:244–247,358–362` | A public processor behaviour exists, but the shipped worker dispatches directly to specific processors. No demonstrated configurable processor module seam exists. Do not promise fail-N processor substitution or add one for the twin. |
| `lib/rindle/streaming/provider.ex:19–26,75–94` | Provider callbacks normalize results and protect provider identifiers. Provider seams are relevant to 138, not a reason for real credentials in 137. |
| `lib/rindle/workers/purge_storage.ex:3,25–55` | Purge has three attempts, deletes objects before durable asset removal, and tolerates `:not_found`/`:enoent`. A one-failure storage-delete tracer exercises a useful real invariant. |
| `lib/rindle.ex:669–726` | `Rindle.requeue_variants/2` and `Rindle.runtime_status/1` are supported repair/diagnostics surfaces. Do not call their private owners. |
| `lib/rindle/domain/media_asset.ex:1–25`, `lib/rindle/domain/media_variant.ex:1–25`; `guides/core_concepts.md:14–15,196–208`; `guides/troubleshooting.md:354–377` | These schemas are documented adopter query surfaces. Permit fixed read-only queries through the host Repo for asset existence and documented lifecycle fields; this is not private coupling. Continue to forbid private workers/owners, target-state mutations, source introspection, and repository test helpers. |

Exact dependency split matters: root `mix.lock:15–16,49–60` has Ecto 3.14.2, Ecto SQL 3.14.0, Oban **2.21.1**, Phoenix 1.8.12, Plug 1.20.3, Postgrex 0.22.4, Req 0.7.5. The demo has Oban **2.23.1** (`examples/adoption_demo/mix.lock:30`) and Req 0.7.3. Pin the initial twin's resolved Oban to the researched 2.21.1 fixture configuration and record the complete resolved lock/toolchain; do not silently borrow demo lock contents. This is not a request to change either product lockfile.

## Execution modes: what each can actually establish

| Approach | Benefits | Costs / proof limits | Use |
|---|---|---|---|
| `Oban.Testing.perform_job` | Fast worker result tests | In-memory build; executor `ack: false`; cannot establish durable attempt/error/terminal acknowledgement | Existing unit tests only |
| Inline | Convenient synchronous happy path | Testing config removes queues/plugins; not production producer, staging, concurrency or restart | Never twin retry authority |
| Manual + `drain_queue` | Real DB fetch/ack and failure recording; deterministic synchronous tests | Runs in caller process; suppresses queues/plugins; `with_scheduled: true` makes future jobs available early | Useful supporting tests, clearly labelled |
| Normal mode, real supervised queues | Exercises producer fetch, durable attempts, staging, errors, shutdown and fresh boot | Eventual observation and finite waiting required | **Twin authority** |

Pinned official source: [Testing perform_job](https://github.com/oban-bg/oban/blob/v2.21.1/lib/oban/testing.ex#L242-L249), [Config testing overrides](https://github.com/oban-bg/oban/blob/v2.21.1/lib/oban/config.ex#L87-L95), [drain_queue documented semantics](https://github.com/oban-bg/oban/blob/v2.21.1/lib/oban.ex#L824-L870). These distinctions correct the overly broad earlier phrase “manual Oban with production execution semantics”: manual drains share execution machinery but do not prove background producer operation.

The pinned [Basic engine fetch](https://github.com/oban-bg/oban/blob/v2.21.1/lib/oban/engines/basic.ex#L95-L130) locks selected available rows, atomically sets executing/attempted metadata, and increments `attempt`. [Executor acknowledgement](https://github.com/oban-bg/oban/blob/v2.21.1/lib/oban/queue/executor.ex#L220-L262) computes worker backoff on failure; [error/complete writes](https://github.com/oban-bg/oban/blob/v2.21.1/lib/oban/engines/basic.ex#L215-L259) persist retryable state, scheduled time, errors, or completed state. Accordingly, collect one job ID before/after restart, attempts, attempted/completed/scheduled timestamps, normalized errors, and durable domain/object observations. A telemetry event, adapter call count, drain summary, or final `attempt == 2` alone is incomplete proof.

### Ordinary host configuration shape

Illustrative adopter configuration, not proposed product API:

```elixir
config :rindle, :repo, Twin.Repo

config :twin, Twin.Repo,
  database: System.fetch_env!("RINDLE_TWIN_DB"),
  pool_size: 5

config :twin, Oban,
  repo: Twin.Repo,
  testing: :disabled,
  queues: [rindle_promote: 1, rindle_process: 1,
           rindle_purge: 1, rindle_maintenance: 1]

# Add rindle_media and documented streaming queues only when the host profiles need them.
children = [Twin.Repo, {Oban, Application.fetch_env!(:twin, Oban)}]
Supervisor.start_link(children, strategy: :one_for_one)
```

Prefer `MIX_ENV=prod` or a dedicated host environment with the same non-testing runtime semantics. “Production-faithful” comes from real ownership/execution, not the environment atom. No Sandbox pool, test helper, caller process dictionary, `Rindle.Config.put_repo_override`, or dynamic `Application.put_env` toggling belongs in runtime execution.

## Restart: pick the claim before the kill

| Restart target | Demonstrates | Does not demonstrate |
|---|---|---|
| Worker/GenServer child in one VM | OTP child recovery | Host death, loss of VM memory or new DB connections |
| Whole external BEAM after durable retry acknowledgement, before next attempt | **Selected tracer:** persisted job/domain work survives host restart without reissuing stimulus | In-flight orphan rescue, machine/disk failure, multi-node failover |
| Hard kill while job is `executing` | Orphan handling only if separately configured and observed | Immediate automatic rescue merely because Oban was restarted |

The controller must retain its own process, record host OS PID plus a fresh boot identity, wait for actual old process exit, start a new BEAM, and verify Repo/Oban readiness. Under Docker/Compose, track container/runtime identity and confirm old BEAM exit rather than treating a successful restart command as sufficient evidence; retain named run resources and stage the same verified package without mounting the checkout. Use direct executable spawning if running outside a container, not a shell whose PID hides the BEAM. Closing an Elixir Port alone is insufficient: [Elixir 1.17.3 Port documentation](https://github.com/elixir-lang/elixir/blob/v1.17.3/lib/elixir/lib/port.ex#L143-L155) explicitly says the OS program need not terminate. [OTP supervisor](https://www.erlang.org/doc/apps/stdlib/supervisor.html#module-supervision-principles) defines child restart and reverse-order shutdown; that is distinct from OS runtime supervision. The cited OTP page is current, used only for stable supervision principles, not a claim about new OTP APIs on supported OTP 27.

Use durable-stage barriers rather than sleep-and-hope. Observe committed `retryable` with its error, call public `Oban.pause_queue(queue: :rindle_purge, local_only: true)`, and poll `Oban.check_queue(queue: :rindle_purge)` until it reports paused with no running jobs. Re-read the same job and require retryable/attempt one before termination. That conjunction is the quiescent barrier; an adapter notification emitted before returning is too early. If attempt two wins the race, fail this run as incomplete rather than rewriting state. The delay gives a practical observation window; correctness depends on the checks. Start the new host with its normal active queue configuration and wait for the existing job's scheduled time. If startup passes that time, the still-durable job may execute immediately; no second detach/upload/insert is permitted. Label the intentional queue pause and between-attempts restart in the receipt. The controller initiates the stimulus once and retains its returned IDs. A controller crash in the ambiguous gap between stimulus and ID retention is **not** covered by host-restart acceptance; fail incomplete instead of silently reissuing the action or building a new exactly-once controller protocol.

Pinned [Lifeline source](https://github.com/oban-bg/oban/blob/v2.21.1/lib/oban/plugins/lifeline.ex#L1-L38) says rescue is time-based, defaults to 60-minute age checked every minute, may duplicate jobs still genuinely executing, and discards exhausted jobs. Therefore **do not add a fast Lifeline just to make the between-attempt tracer pass**. A future in-execution crash test needs its own explicit age/interval/runtime bounds and idempotency oracle. Never describe restart-between-attempts as in-flight crash rescue.

## Ownership, isolation, and persistent fault state

Use an ordinary connection pool with committed PostgreSQL state. SQL Sandbox shares an owned transaction through explicit process allowances/shared mode; workers cannot automatically see test-owned uncommitted data, and terminating the owner takes the connection away. A new BEAM cannot inherit that transaction or its PIDs. [Ecto SQL 3.14.0 Sandbox](https://hexdocs.pm/ecto_sql/3.14.0/Ecto.Adapters.SQL.Sandbox.html#module-collaborating-processes) is the direct source. This is why a larger ownership timeout or shared sandbox is not a restart fix.

Unique run database + normal supported schemas is the flat isolation default. A dynamically prefixed Repo is not enough because schema prefixes can outrank connection search path, and migrations/Oban/Rindle must agree. [Ecto 3.14.2 query-prefix guide](https://github.com/elixir-ecto/ecto/blob/v3.14.2/guides/howtos/Multi%20tenancy%20with%20query%20prefixes.md#prefix-precedence) explains that precedence. Run database names must be derived from validated safe IDs; retain DB, object prefix and temp root across host restart; destroy them only after independent observation.

For deterministic faults, compile host wrappers against **documented** behaviours and delegate all untouched callbacks with their documented shapes/capabilities. Example storage `delete/2`:

```elixir
def delete(key, opts) do
  case Twin.Faults.consume(:delete, key) do
    :fail -> {:error, :twin_transient_delete}
    :delegate -> Rindle.Storage.S3.delete(key, opts)
  end
end
```

`Twin.Faults` is host-owned fixture code, not a package module, and never enters an export snapshot or public production config. Key faults by run + operation + exact owned key, with safe bounded reasons. A process-local Agent/ETS counter would reset on reboot and could fail forever. Mox expectations/caller propagation likewise are not a durable cross-BEAM oracle.

| Counter storage | Tradeoff | Recommendation |
|---|---|---|
| Agent/ETS/process dictionary | Small but lost with BEAM, sensitive to caller lineage | Reject for restart faults |
| Same-run retained file, consumed atomically on one filesystem | Requires careful concurrent consumption, filesystem/container retention and corruption semantics despite already having PostgreSQL | Reject for this harness: little value versus existing Repo ownership |
| Tiny fixed host-owned table with atomic `UPDATE ... WHERE remaining > 0 RETURNING` | Concurrency-safe durable fail-N through the existing Repo; one fixture migration and cleanup obligation | **Selected:** no new dependency, database framework, locking protocol or generic fault registry |
| New queue simulator, event store, control protocol | Broad machinery; more state to trust and clean | Reject |

Use one atomic committed conditional update, not a read-then-write counter. Record configured versus consumed state and test two simultaneous consumers; the run/operation/key tuple identifies the fixed fault target. This host fixture table may be mutated by the host fault wrapper; it does not authorize mutations of Rindle lifecycle or Oban rows to manufacture outcomes. Consuming a fault and acknowledging a job are not one transaction: a crash in that gap cannot count as observed retry. The tracer's post-ack restart avoids that ambiguity; missing persisted failure makes it fail. Do not make an exactly-once claim about fault delivery.

## Retry cadence and practical tracer acceptance

[Worker 2.21.1](https://github.com/oban-bg/oban/blob/v2.21.1/lib/oban/worker.ex#L525-L535) plus [Backoff implementation](https://github.com/oban-bg/oban/blob/v2.21.1/lib/oban/backoff.ex#L30-L36) gives the first default delay as `15 + 2^1 = 17` seconds, then positive jitter (normally 17–18 seconds for this attempt). Producer/stager/database latency adds observation delay. Record the actual persisted due time and poll with a monotonic deadline (initial recommendation: 60–90 seconds for retry convergence, measured and bounded separately from setup). Do not assert a fixed sleep or exact jitter value.

Shortening **host** staging/poll intervals can reduce polling latency if measured necessary, but does not shorten the worker's backoff. Public `Oban.retry_job/1` forces immediate retry and can exercise an operator path; it must not be labelled autonomous schedule recovery. A custom twin worker with one-second `backoff/1` tests that custom worker, not the shipped Rindle worker. None is necessary for one fail-once tracer.

Tracer success requires observations in this order:

1. Public upload/ready and `Rindle.attach(asset_or_id, owner, slot)` create actual asset/object/attachment (`lib/rindle.ex:377–379`). Then `Rindle.detach(owner, slot)` removes its final attachment and transactionally enqueues purge (`lib/rindle.ex:438–484`); capture the asset ID and discover its resulting job through supported Oban/DB observations without calling private worker modules. Fixed host-Repo read-only queries against documented `Rindle.Domain.MediaAsset`/`MediaVariant` may confirm existence and state. Detach returns `:ok`, not the job ID. Do not add a twin-specific purge/enqueue API.
2. The owned storage wrapper fails the intended delete once. Persisted job is retryable, attempt one, error present; durable asset/key remains; no false success/terminal deletion.
3. External BEAM exits between attempts. New boot uses the identical database/package/config and retained fault state. No second public stimulus is issued.
4. That job reaches completed at attempt two through the queue; object and asset are absent as expected; the fault consumption remains one. Public diagnostics/MinIO facts agree.
5. Capture terminal observations before teardown, then independently enumerate every owned DB/job/object/multipart/temp resource. Retained successful job rows are expected *evidence before cleanup*, not a license for unapproved residue after cleanup. A failed cleanup cannot turn a failed scenario green.

## MinIO, effects, and transfer from other ecosystems

Count logical effects separately from request attempts. A transient delete may issue multiple DELETE requests while removing only one object. HEAD/list authoritative absence after retry matters more than a mock's `called_twice` assertion. List multipart uploads separately; object listing does not expose uncompleted multipart state. Verify versioning is disabled for the ephemeral bucket or enumerate/delete versions and markers explicitly; a current-object absence is not proof of zero versioned residue. AWS [S3 consistency documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html#ConsistencyModel) supports read-after-write/delete observations for S3; MinIO is an independent local implementation, so record its version and probe its actual observed result rather than calling it a cloud guarantee.

The existing S3 tus implementation retains sub-5-MiB tail bytes on local disk (`lib/rindle/storage/s3.ex:5–25`). Retain the same temp filesystem on **process** restart; deleting it would turn restart into disk-loss semantics. RECOV-01's client recreation and RECOV-05's durable-stage host restart should remain distinct claims in 138.

Two external lessons change the design rather than merely adding references:

- [Sidekiq's own best practices](https://github.com/sidekiq/sidekiq/wiki/Best-Practices#2-make-your-job-idempotent-and-transactional) explain the side-effect/acknowledgement gap and repeated execution even after work finishes. Transfer: prove convergent effects and stable IDs, not exactly-once execution; preserve durable handles until storage confirms completion.
- [Rails Active Storage blob purge source](https://github.com/rails/rails/blob/v8.0.0/activestorage/app/models/active_storage/blob.rb#L319-L339) warns against network deletion inside transactions/callbacks. Transfer its transaction-boundary lesson, **not** its record-first purge ordering: Rindle's shipped worker intentionally preserves DB handles until all deletions succeed, a stronger recovery oracle for this tracer.

For 138 webhook tests preserve the raw signed body through the ordinary host Plug pipeline. [Plug.Parsers `body_reader`](https://hexdocs.pm/plug/Plug.Parsers.html#module-options) is the standard capture seam; bypassing the actual endpoint with a normalized event map would skip signature/parser/order behavior. Keep provider events local and synthetic until separately authorized real-provider work exists.

## Adversarial pass: tests that make this architecture earn its claims

| Footgun / attack | Ordinary executable probe |
|---|---|
| Inline/manual accidentally inherited | Boot assertion reads public Oban config and queue health; deliberately inject testing mode and require explicit refusal before stimulus. |
| Named Oban or alternate Repo | Run documented doctor; deliberately misconfigure and require ownership refusal, not a later timeout. |
| Pre-ack “failure seen” triggers kill | Require committed retryable row plus error; kill before ack in a negative probe and reject retry evidence. |
| Test transaction masks commits | Use independent connection/BEAM to observe the committed job and asset before restart. |
| Supervisor-only restart masquerades as host restart | Assert old OS process termination and changed boot identity, retained DB identity, and one stimulus count. |
| Counter resets, concurrent fail-once allocation, wrong key | Restart and parallel-consume wrapper fixture probes; unrelated keys delegate; configured one failure cannot become two. |
| Failure returns wrong shape / swallows unknown error | Callback contract tests cover success, expected failure, unexpected failure and capability delegation. |
| Autonomous retry silently accelerated | Prohibit receipt mode mixing; compare scheduled/attempt timestamps; no `retry_job`, drain or direct scheduling writes in tracer. |
| Effect applied before lost acknowledgement | Supporting partial-delete replay probe expects idempotent absence and remaining durable handle; do not infer exactly-once work. |
| Fast Lifeline duplicates valid long job | Not enabled for 137. Any later in-flight test separately demonstrates rescue age and duplicate-safe effects. |
| Cleanup creates green by dropping all evidence | Serialize terminal facts first, independently verify cleanup, retain redacted failure result; deliberately fail cleanup and require overall red. |
| Wrapper/receipt logs signed URL/provider ID/credentials | Canary sensitive strings through error and telemetry paths; emit allowlisted normalized reasons/counts, not raw exception/args dumps. |
| Resume loses S3 tus tail | Retain run tmp root on process restart; explicit missing-tail negative case remains failure, never offset reset/re-upload success. |

Do not generate source-literal tests mirroring the implementation for every row. Use observable runtime/callback probes where they add confidence; compile/static guards can support the narrow no-private-coupling/no-new-product-API contract.

## Scope and remaining uncertainty

Phase 137 should supply the normal host, isolated services/ownership, documented adapter specimen, external process lifecycle, and the single combined retry/restart tracer. Phase 138 owns all six recovery cases and their complete effect/residue assertions. Phase 139 owns exact-head overall readiness. No Phase 138 checkbox closes because this foundation has interfaces.

Keep the inherited target of at most six plans with at most three tasks each; if the same gate blocks twice, rescope instead of adding another qualification/authorization/journal subsystem (`134-CONTEXT.md`, D-134-01, inherited instruction). Standard GSD workflow plus ordinary executable probes suffices. No new dependency has a concrete need in this recommendation.

Known questions for implementation probes, not maintainer preference questions: startup/restart cost on supported Elixir 1.17/OTP 27; exact queue set demanded by selected profiles; independent DB/object inventory commands available in existing local services; authoritative container runtime/package staging with no checkout mount; and whether the real AV-invalid-input scenario reaches the intended processor failure rather than earlier upload validation. Fault storage is settled as the tiny fixed host-owned PostgreSQL table. If the AV-input probe fails, narrow the scenario through existing HTTP/media-input seams; do not add a processor injection API.

Confidence: high in pinned Oban execution/acknowledgement and repo ownership findings; high in unsupported named Oban/arbitrary schema/custom processor-substitution limitations; medium in runtime budgets and exact tracer ergonomics until automated execution. Official sources above were inspected online or as pinned raw source; local dependency source was used to cross-check exact lines. Research does not assert successful host boot, retry, restart, cleanup, or requirement closure.
