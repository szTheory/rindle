# Phase 138: Lifecycle Failure and Recovery Matrix - Context

**Gathered:** 2026-10-21 (research-first assumptions mode)
**Status:** Ready for planning
**Decision authority:** The user requested comprehensive subagent research and one coherent
recommendation set, then explicitly selected: “Adopt the recommendations and bounded fixes.”

<domain>
## Phase Boundary

Deliver executable RECOV-01 through RECOV-06 evidence against the Phase 137 built-package
adopter twin: interrupted tus client recovery, storage retry/absence, real audio/video
failure and repair, duplicate/out-of-order provider events, abrupt host replacement between
durable stages, and interrupted domain cleanup. Extend the existing maintainer CLI and
strict receipts. Confirmed correctness defects exposed by these cases may receive narrow
fixes preserving public APIs and schema; this is explicitly approved scope.

This context grants no execution or acceptance credit. Phase 139 owns aggregate exact-head
readiness, including Doctor's migration-ledger defect. Synthetic evidence never closes the
independent-adopter gate or authorizes 1.0.
</domain>

<decisions>
## Implementation Decisions

### Consumer boundary and finite matrix

- **D-138-01:** Extend the dedicated external Phoenix/Repo/default-Oban host from Phase
  137. Build one fresh Hex archive per matrix invocation and bind every case to the exact
  same archive bytes, source, host/lock/fixture/contract inputs and actual runtime versions.
  Compile Rindle uncached as required by the foundation. Isolate case state with distinct
  run identities and fresh disposable resources; one case must not satisfy another's oracle.
- **D-138-02:** Use public facade/configuration/behaviour, supported Mix tasks, actual HTTP
  endpoints and normal committed Oban scheduling. No SQL Sandbox, direct worker execution,
  manual job draining, lifecycle-row mutation, rewritten job schedules/attempts, private
  production hooks or checkout-backed consumer code. Read-only domain/Oban observations
  and narrowly host-owned persistent fixture state remain legitimate. Faults are fixed,
  exact-key/run-scoped behaviours, not a general fault platform.
- **D-138-03:** Keep six required scenario families with finite explicit sub-observations,
  not a combinatorial chaos/compatibility matrix. Every family must pass; partial runs are
  useful reproduction evidence but cannot pass full-matrix verification. Preserve the
  supported Elixir 1.17.3 / OTP 27.3.4.15 diagonal, root lock and toolchain declarations.

### Tus, storage retry and abrupt restart

- **D-138-04:** For RECOV-01, finish a nonfinal PATCH, record its acknowledged byte count,
  terminate/recreate the client process, and resume the same session using a fresh HEAD's
  authoritative offset. Keep the same S3 tus host/node and retained tail. Assert a wrong
  offset is rejected without advancement, one upload stimulus/session/asset, final source
  checksum, ready state and exact storage inventory. Describe this as interruption between
  committed PATCHes; do not claim a severed mid-PATCH socket or cross-node tail recovery.
- **D-138-05:** Interpret “one object” as exactly one original upload object, plus the
  explicitly configured derivative object(s) necessary for the shipped ready lifecycle.
  Name all permitted keys and reject extras. This clarifies the existing source/variant
  contract; it does not remove variants or change readiness semantics to hit a bucket count.
- **D-138-06:** For RECOV-02, reuse the committed exact-source delete-once fault. Observe
  retained durable asset state and the same purge job retryable at attempt one with a stored
  error. Pause and prove quiescence before independently removing the owned source key and
  establishing authoritative absence. Ordinary scheduling must complete that job at attempt
  two without another detach/stimulus. Verify final rows and objects independently. Missing
  unversioned S3 DELETE normally succeeds; never invent a provider 404 or mistake permission
  denial for absence. Keep explicit error-atom branch proof in focused behavioural tests.
- **D-138-07:** For RECOV-05, pause the promotion queue before upload completion. Require
  committed completed session/asset state, one persisted promotion job available at attempt
  zero, paused queue and no running work at the selected cut. SIGKILL only the host, observe
  old-runtime death, then boot a new runtime against the same package and durable resources.
  The same job ID must complete normally and converge without repeating upload/completion
  stimulus. Record old/new runtime identities. This is an abrupt between-stages crash proof;
  executing-job rescue, controller recovery and disk loss remain outside the claim.

### Real AV failure, diagnostics and supported repair

- **D-138-08:** AV means audio/video. Use one tiny valid video fixture with audio and one
  supported video derivative, real FFmpeg/ffprobe, actual MinIO I/O and ordinary media queue
  execution. After valid promotion, apply a fixed exact-source download fault through the
  host's configurable storage wrapper: delegate real download, then replace only that worker
  temp input with malformed bytes. Prove the real processor rejects it; do not stub a
  processor result, remove binaries or claim storage corruption as an observed root cause.
- **D-138-09:** Retain the fault through the shipped five-attempt budget, observing the
  failed variant, discarded job, actual attempts/errors and public `Rindle.runtime_status/1`
  failure classification. Restore normal downloads and use `Rindle.requeue_variants/2` for
  the selected variant. Require a genuinely enqueued repair and a consistent ready terminal
  state, then download, probe and fully decode the output. Record actual binary versions.
  Use bounded state polling with execution/scheduler margin, not an estimated retry sum as
  a guarantee. No backoff patch, attempt shortcut or automatic retry masquerading as repair.

### Provider convergence and bounded correctness fixes

- **D-138-10:** Exercise the shipped Mux adapter and its existing optional SDK through
  supported `base_url` configuration aimed at a minimal isolated local HTTP fixture. Use
  dummy credentials, actual signed raw-body webhook ingress and the ordinary provider queue.
  Activate the already locked optional SDK only in the host if needed. Prefer this over a
  replacement provider implementation, a new mocking dependency or a paid/cloud account.
  Claim local adapter/protocol evidence, never real-cloud parity or adoption.
- **D-138-11:** Include duplicates both while the first event job is pending and after it
  completes; include a newer ready event followed by older created AND older errored events.
  Assert converged provider identity/state, nonregressing event watermark, bounded declared
  jobs, exactly one intended outbound create and no duplicate observable lifecycle effects.
  A post-completion handler job is legitimate if effect-free; completed-job uniqueness is
  not an exactly-once guarantee. Capture allowlisted telemetry/PubSub effects and scan secrets.
  Do not narrow the fixture to the one out-of-order edge the current FSM already rejects.
- **D-138-12:** A confirmed stale-event regression or duplicate-effect defect belongs in
  this approved correctness slice: first reproduce behaviour, then fix its cohesive owner
  with regression proof. Preserve public APIs, schema, supported fresh-event transitions,
  error/telemetry vocabulary and provider identifier secrecy. Research timestamp precision,
  equal/missing times and concurrent handlers; a read/check/write timestamp guard alone must
  not be assumed race-safe. Do not introduce an event-sourcing framework, new event ledger,
  timestamp-total-order promise or blanket terminal-state immunity. If the fix cannot meet
  those boundaries, keep RECOV-04 open and present the exact remaining contract decision.

### Interrupted domain cleanup and evidence

- **D-138-13:** For RECOV-06, create genuinely expired disposable upload work through
  public session expiry/options and `mix rindle.abort_incomplete_uploads`, without backdating
  lifecycle rows. Exercise `mix rindle.cleanup_orphans --no-dry-run` as the supported janitor.
  Observe a real owned storage deletion, block the host-owned wrapper before returning to
  the janitor's row deletion, and terminate that maintenance process. Prove the object is
  absent but its expired row remains; rerun the janitor on the same resources and run it
  again to prove convergence/idempotence. Keep a real multipart/part cleanup observation in
  this family through the supported abort lane; empty multipart lists alone cannot prove
  multipart abort was exercised. Avoid duplicate endpoint/queue supervision in task runtimes.
- **D-138-14:** The upload janitor does not erase provider assets or every AV/temp resource.
  Account for each resource class with its actual public/host-owned cleanup owner. Audit DB,
  exact jobs/history, source/variant objects, provider fixture effects, multipart uploads AND
  parts, temp files and owned processes while services/volumes still exist. Allow only exact
  declared history/fixture/infrastructure identities, never broad positive counts. Unknown,
  denied, missing, truncated or raced inventory fails. Stop writers before the final audit.
  Freeze the domain verdict before infrastructure disposal; disposal cannot repair a failure.
- **D-138-15:** Extend `twin_receipt.py` with a finite discriminated scenario set and one
  common closed envelope. Keep predicates and the required matrix set in source, with typed
  scenario-specific payloads. Independently verify retained runner inputs/archive identities
  and complete scenario receipts. Reject omitted/duplicate/unknown/skipped scenarios, swapped
  case identities, contradictions, forged counts and unexplained residue. No generic receipt
  DSL, signing service, witness registry or claim to authenticate fabricated trusted inputs.
- **D-138-16:** Preserve bounded private captures and original failed/interrupted evidence.
  Export only typed allowlisted observations and fixed safe reason codes; no signed URLs,
  webhook bodies/signatures, raw credentials/errors or environment dumps. Canary-test receipts,
  stdout/stderr, logs, telemetry and any PubSub export. Infrastructure cleanup must retain the
  foundation's descriptor/label/mount/liveness checks, foreign-resource refusal and repeated
  safe disposal. Never use force removal/prune to turn unknown ownership into success.

### DX, dependencies, acceptance and workflow

- **D-138-17:** Keep one documented check/run/verify/cleanup entrypoint with useful focused
  reproduction, clear partial/failure states, optional machine output and safe evidence paths.
  Prefer Python standard library and existing Elixir dependencies with small cohesive owners.
  No frontend, new public API, general orchestration/fault DSL or new dependency tree. Follow
  the current `brandbook/` for applicable voice/accessibility; the prompt brand seed is history.
- **D-138-18:** Close requirements only from executable package-consumer probes and separate
  semantic verification, with negative controls for false-green paths. Add fast regressions in
  existing lanes; measure full real matrix cost before considering recurring heavy CI. Preserve
  required contexts/release coupling and deferred numeric speed acceptance. Plan a few vertical
  slices, at most six plans/three tasks each; repeated blockage requires rescoping, not recovery
  plan cascades. Next stage is ordinary `$gsd-plan-phase 138`; auto-advance remains disabled.

### Codex's Discretion

Exact helper/module layout, finite case identifiers, receipt versioning/migration treatment,
fixture dimensions, polling deadlines with measured margin and plan ordering are implementation
choices. Keep existing Phase 137 receipts interpretable and distinguish them from complete
matrix acceptance. Prefer the named fixed fault; an equivalent documented boundary needs the
same real failure and restoration proof. Do not make the maintainer arbitrate reversible details.

### Folded Todos

None. Doctor's versioned-host migration-ledger todo was reviewed and explicitly retained for
Phase 139. The CI publish-race and landing-record/collector todos are unrelated to RECOV scope.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/PROJECT.md` — active v1.26 scope, public-contract and adoption boundaries.
- `.planning/REQUIREMENTS.md` — RECOV-01 through RECOV-06; Phase 139 owns READY requirements.
- `.planning/ROADMAP.md` — Phase 138 boundary and sequencing.
- `.planning/METHODOLOGY.md` — evidence ladder, research-first, automation and diminishing returns.
- `.planning/DEVELOPMENT-TRAIN.md` — ordinary GSD loop and direct next-stage handoffs.
- `.planning/phases/137-built-package-twin-foundation/137-CONTEXT.md` — inherited foundation decisions.
- `.planning/phases/137-built-package-twin-foundation/137-VERIFICATION.md` — accepted foundation and limits.
- `.planning/phases/138-lifecycle-failure-and-recovery-matrix/138-DISCUSS-RECOMMENDATIONS.md` — researched tradeoffs, sources and adversarial findings.
- `guides/built_package_twin.md`, `guides/operations.md`, `guides/streaming_providers.md`, `RUNNING.md` — supported runtime and maintainer surfaces.
- `lib/rindle/upload/tus_plug.ex` — documented tus contract and same-node S3 tail constraint.
- `lib/rindle/streaming/provider.ex` — public provider behaviour and secrecy invariant.
- `.planning/todos/pending/2026-10-21-doctor-versioned-host-migration-ledger.md` — deferred readiness defect; no Doctor pass claimed here.
- `prompts/gsd-rindle-elixir-oss-dna.md`, `prompts/phoenix-media-uploads-lib-deep-research.md`, `prompts/gsd-rindle-research-index.md` — relevant prior art, subordinate to shipped code.
- `brandbook/README.md`, `brandbook/index.html`, `brandbook/tokens/tokens.json` — current brand authority; applicable CLI voice/accessibility only.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `scripts/maintainer/built_package_twin.py`, `twin_receipt.py`, `twin_cleanup.py` — fresh
  artifact isolation, retained inputs, receipt verification and owned infrastructure disposal.
- `test/twin/host/lib/twin/{storage,tracer,web,application}.ex`, host config/lock/migration —
  ordinary consumer runtime and exact-key committed delete-once precedent. The current host
  only exercises images; tus route, AV profile and provider fixture/queue must be added honestly.
- `test/install_smoke/support/generated_app/profile_helpers.ex` — client-process tus resume
  precedent; copy narrow protocol setup, not its Sandbox/inline job semantics.
- `lib/rindle/upload/broker/completion.ex` — durable session/asset/promotion enqueue boundary.
- `lib/rindle/workers/purge_storage.ex`, `process_variant.ex`, `ingest_provider_webhook.ex` —
  deletion retry, real AV execution and provider ordering/idempotency risk owners.
- `lib/rindle/ops/lifecycle_repair.ex`, `ops/runtime_status/collector.ex` — shipped facade
  repair/status semantics; repair uniqueness means an active retry is not a new repair job.
- `lib/mix/tasks/rindle.{abort_incomplete_uploads,cleanup_orphans}.ex` — public two-stage
  upload maintenance; `lib/rindle/ops/upload_maintenance.ex` deletes storage before the row.

### Established Patterns and Integration Points

Use committed host-owned fixture counters, explicit capability-preserving storage delegation,
actual HTTP ingress, paused/quiescent public queue barriers and read-only durable observations.
The current fixed receipt expects one image scenario and three jobs; extend its contract rather
than inheriting those counts for the matrix. Provider `last_event_at` exists, but the webhook
worker currently does not order by it; ready-to-errored is allowed. Existing optional Mux 3.2.2
is locked, and its HTTP adapter accepts `base_url`. No new provider abstraction is required.
</code_context>

<specifics>
## Specific Ideas

Adopter/maintainer job: run one reproducible packaged-host matrix, locate a safe concrete failure,
repair through supported tools, and verify converged durable state and bounded cleanup evidence.
Inputs come from source-owned cases and retained manifests; outputs are safe observations and
verdicts, not backend dumps. Treat UI concerns as CLI clarity, text-based statuses and useful
reproduction/cleanup commands. No graphical design work is needed.

The user approved bounded correctness fixes after being shown the stale-provider-event risk and
the alternatives. A green subset cannot substitute for the adverse stale-error/post-completion
duplicate cases. One original plus declared derivatives clarifies object cardinality without
changing lifecycle semantics. All six cases remain pending until execution proves them.
</specifics>

<deferred>
## Deferred Ideas

- Doctor migration-ledger correction and aggregate exact-head readiness — Phase 139.
- Mid-PATCH transport severing, cross-node tus tails, executing-job rescue, disk/controller loss,
  broad chaos testing, additional providers/cloud certification and compatibility expansion.
- New event ledger/schema, public API or telemetry-vocabulary changes require a separate scoped
  decision if the approved no-schema/no-API correctness repair proves insufficient.
- UI/admin console, new dependencies, generic fault/schema/orchestration frameworks and automatic
  heavy PR lanes; independent pilot/1.0 and deferred numeric CI target receive zero credit.

### Reviewed Todos (not folded)

Doctor versioned host ledger: user explicitly retained for Phase 139. Hygiene publish-race and
landing-record/collector gaps: unrelated CI/release ownership, remain in backlog.
</deferred>
