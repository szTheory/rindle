# Phase 31: Runtime Diagnostics & Drift Visibility - Context

**Gathered:** 2026-05-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Make runtime misconfiguration, capability drift, stale migration state, and
stuck lifecycle work visible through supported diagnostics before adopters
guess. This phase adds diagnostics, reporting, and telemetry contracts. It
does not add new repair verbs, a dashboard product, or a host-app control
plane.

</domain>

<decisions>
## Implementation Decisions

### Doctor posture

- **D-01:** Keep `mix rindle.doctor` as a deterministic prerequisite and drift
  checker, not a broad runtime-inspection or auto-remediation command.
- **D-02:** `mix rindle.doctor` should expand beyond the current FFmpeg and
  profile-capability checks to cover:
  - runtime capability drift
  - profile-to-capability fit
  - required Oban queue presence and default-`Oban` ownership sanity
  - delivery/local-playback misconfiguration
  - stale migration state
- **D-03:** `mix rindle.doctor` must stay read-only. No queue creation, no
  cleanup, no repair, no migration mutation, and no “auto-fix” mode.
- **D-04:** `mix rindle.doctor` must not become the stuck-work report surface.
  Keep DIAG-01 and DIAG-02 separate so `doctor` remains fast, low-surprise,
  and CI-friendly.
- **D-05:** Use stable, documented check IDs plus actionable fix guidance for
  each failing check. The check contract should feel closer to Django-style
  system checks than ad-hoc stderr strings.

### Runtime status surface

- **D-06:** DIAG-02 should ship as a public structured report API on `Rindle`
  plus a Mix-task wrapper, not as CLI-only output and not as dashboard-first
  UX.
- **D-07:** The canonical shape is:
  - public function on `Rindle`, such as `runtime_status/1` or
    `status_report/1`, returning `{:ok, report}`
  - `mix rindle.runtime_status` as the operator entrypoint
  - text and JSON output modes on the Mix task
- **D-08:** Keep any implementation/query modules under internal
  `Rindle.Ops.*`; the public contract is the `Rindle` facade plus the Mix
  wrapper, consistent with Phase 30’s “asset-scoped public surface, broad
  operator flows command-shaped” boundary.
- **D-09:** The report should be a status/reporting contract, not a new control
  plane. It may point to the right repair verb, but it must not itself mutate
  lifecycle state.
- **D-10:** The report should expose bounded, operator-shaped filters only,
  such as `profile`, `older_than`, `limit`, and `format`. Do not introduce a
  generic public query DSL in v1.5.

### Stuck work and drift semantics

- **D-11:** Preserve the current lifecycle vocabulary split:
  - `failed` and `cancelled` are repairable work items
  - `stale` and `missing` are drift classes with different operator verbs
  Phase 31 extends that vocabulary; it does not replace it.
- **D-12:** Use a hybrid classification model:
  - persisted Rindle lifecycle state is the user-facing truth
  - Oban/runtime evidence corroborates whether work is healthy, starved, or
    orphan-suspect
  - migration state is derived from Ecto migration versions, not full schema
    diffing
- **D-13:** Define `stuck lifecycle work` as non-terminal work that exceeded a
  conservative age threshold and lacks healthy corroboration from Oban/runtime.
  Age alone is not enough.
- **D-14:** Lock these diagnostic classes for v1.5:
  - `failed_work`
  - `cancelled_work`
  - `queue_starved`
  - `orphan_suspect`
  - `recipe_drift`
  - `storage_drift`
  - `probe_drift`
  - `runtime_misconfiguration`
  - `migration_pending`
  - `migration_unresolved`
- **D-15:** Suggested default thresholds:
  - `queue_starved`: variant remains `queued` for more than 5 minutes with no
    active corroborating Oban job
  - `orphan_suspect`: `processing`/executing work older than 20 minutes for AV,
    15 minutes for image, or more than 2x the configured timeout when a per-job
    timeout is available
  These are status-report defaults, not hard alert contracts.
- **D-16:** Do not classify `retryable` or first-failure work as “stuck”.
  Exhausted `failed` work is immediately actionable; healthy retry behavior is
  not.
- **D-17:** `stale migration state` in v1.5 means one of:
  - local Rindle migration file exists but is not applied
  - DB reports an applied Rindle migration version that is missing from local
    code
  Do not add checksum/content validation or full schema-diff posture in v1.5.
- **D-18:** Status/report output should favor counts, oldest age, and a bounded
  sample of IDs/examples. Do not emit unbounded per-row output by default and
  do not encourage one-alert-per-row semantics.

### Telemetry posture

- **D-19:** Treat Phase 31 telemetry as a small public contract reset, not a
  broad observability expansion.
- **D-20:** Keep the existing public telemetry allowlist intact; add a narrow
  additive Phase 31 layer rather than redesigning the entire event catalog.
- **D-21:** Use a split telemetry model:
  - `[:rindle, :repair, :start|:stop|:exception]`
  - `[:rindle, :runtime, :refusal]`
  - `[:rindle, :runtime, :check, :stop]`
  - optional `[:rindle, :runtime, :check, :exception]` only if check failures
    need alertable distinction
- **D-22:** Keep new telemetry metadata strictly low-cardinality:
  - repair: `operation`, `scope`, `result`, `dry_run`
  - runtime refusal: `surface`, `reason`, `mode`
  - runtime check: `check`, `status`, `component`
- **D-23:** Do not include `asset_id`, `variant_id`, `storage_key`, raw error
  text, actor identifiers, or similar high-cardinality data in the public
  Phase 31 telemetry contract.
- **D-24:** Do not model cancellation as an error in the new telemetry
  families. For operator semantics, intentional cancellation is a terminal
  lifecycle outcome, not an exception-class failure.
- **D-25:** Do not bless ad-hoc one-off event families such as the current temp
  sweep event as separate public contracts. Fold sweep into the repair
  telemetry contract or keep it internal.

### Surface and UX posture

- **D-26:** Do not make a Phoenix dashboard or LiveDashboard integration the
  primary Phase 31 deliverable. A future UI may layer on top of the report and
  telemetry contracts, but the primary surface remains `Rindle` + `mix`.
- **D-27:** `mix rindle.doctor` and `mix rindle.runtime_status` should have
  human-friendly text output first, with deterministic summary ordering and
  optional JSON output for machine use.
- **D-28:** Diagnostics should always point operators to the existing explicit
  repair verbs (`reprobe`, `requeue`, `regenerate`, `cleanup`, `sweep`) rather
  than inventing new overlapping operator language.

### Decision-Making Preference

- **D-29:** Strengthen the standing project preference: downstream agents should
  decide by default and present one coherent recommendation set unless the
  decision has genuinely high blast radius. Escalate only for:
  - public semver-significant API reshapes
  - destructive or irreversible operations
  - security/compliance boundary changes
  - similarly high-impact architectural commitments

### the agent's Discretion

- Exact public naming between `runtime_status/1` and `status_report/1`, so long
  as one structured report API exists on `Rindle` and one matching Mix wrapper
  exists.
- Exact report struct/map layout, provided the report keeps clear sections for
  lifecycle findings and runtime checks and remains stable enough for docs,
  tests, and automation.
- Exact check ID naming convention, provided it is stable, documented, and
  actionable.
- Exact measurement keys for new telemetry events, provided they remain
  backend-agnostic and low-cardinality.

</decisions>

<specifics>
## Specific Ideas

- Recommended surface split:
  - `mix rindle.doctor` = prerequisite/drift checker
  - `Rindle.runtime_status/1` + `mix rindle.runtime_status` = runtime state
    inspection/reporting
  - repair verbs remain exactly the Phase 30 set
- Recommended status sections:
  - `runtime_checks`
  - `assets`
  - `variants`
  - `upload_sessions`
  - `recommendations`
- Recommended first actions by class:
  - `failed_work` / `cancelled_work` -> `requeue`
  - `recipe_drift` / `storage_drift` -> `regenerate`
  - `probe_drift` -> `reprobe`
  - upload residue -> `cleanup`
  - AV temp residue -> `sweep`
- Keep docs language explicit and boring:
  - “doctor validates setup and drift”
  - “runtime status reports what is stuck or degraded”
  - “repair verbs perform change”
- The stronger autonomy preference from the user should be reflected in
  downstream planning and execution for this phase and later phases unless a
  high-blast-radius exception applies.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and milestone requirements
- `.planning/ROADMAP.md` — Phase 31 goal, requirements, and success criteria
- `.planning/REQUIREMENTS.md` — `DIAG-01`, `DIAG-02`, and `DIAG-03`
- `.planning/PROJECT.md` — adopter-first runtime ownership, milestone posture,
  and current project-level constraints
- `.planning/STATE.md` — current project status and decision-making preference

### Prior phase decisions that constrain Phase 31
- `.planning/phases/28-onboarding-docs-ci-proof/28-CONTEXT.md` — `mix rindle.doctor`
  is already a first-class onboarding and CI gate; docs parity and telemetry
  contract posture are already locked
- `.planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md` — repair
  verb boundaries, public-vs-internal surface split, and reporting posture

### Current public/runtime seams
- `lib/mix/tasks/rindle.doctor.ex` — current doctor behavior and CLI contract
- `lib/rindle.ex` — current public lifecycle and repair surface
- `lib/rindle/workers/process_variant.ex` — queueing, timeout, cancellation,
  and worker-state realities
- `lib/rindle/domain/variant_fsm.ex` — current lifecycle state vocabulary
- `lib/rindle/config.ex` — profile discovery and repo config seam
- `priv/repo/migrations/` — Rindle-owned migration versions for drift checks

### Existing operator and telemetry docs
- `guides/background_processing.md` — Oban ownership, queue contract, and
  current telemetry documentation posture
- `guides/operations.md` — explicit operator verbs and command-shaped surfaces
- `guides/troubleshooting.md` — lifecycle-state recovery vocabulary and current
  operator guidance
- `test/rindle/contracts/telemetry_contract_test.exs` — current public
  telemetry allowlist and documentation lock

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Mix.Tasks.Rindle.Doctor`: existing user-facing doctor entrypoint to expand,
  not replace
- `Rindle.Workers.ProcessVariant`: already contains queue choice, timeout, and
  cancellation behavior needed for stuck-work heuristics
- `Rindle.Config.profile_modules/0`: usable seam for profile-aware checks
- `Rindle` facade: already the public home for lifecycle and repair APIs
- `test/rindle/contracts/telemetry_contract_test.exs`: existing contract lock
  that should be extended deliberately

### Established Patterns
- Public targeted operations live on `Rindle`; internal mechanics live under
  `Rindle.Ops.*`
- Broad operator workflows are Mix-task-first and human-readable
- Telemetry is treated as a frozen public contract with docs tied to tests
- Oban ownership remains adopter-owned; Rindle must not over-assume host-app
  supervision topology

### Integration Points
- `mix rindle.doctor` should integrate with Ecto migration/version inspection,
  profile loading, queue checks, and delivery/runtime config checks
- `runtime_status` should combine persisted lifecycle rows with bounded Oban
  corroboration
- Repair telemetry should reuse existing Phase 30 repair/report seams rather
  than inventing a parallel instrumentation model

</code_context>

<deferred>
## Deferred Ideas

- LiveDashboard or first-party UI over the status report
- Adopter-extensible custom doctor checks
- Full checksum/content validation for migration drift
- Generic public query DSL for status inspection
- Metrics-backend-specific integration packages

</deferred>

---

*Phase: 31-runtime-diagnostics-drift-visibility*
*Context gathered: 2026-05-06*
