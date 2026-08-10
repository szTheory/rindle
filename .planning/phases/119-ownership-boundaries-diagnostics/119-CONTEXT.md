# Phase 119: Ownership Boundaries & Diagnostics - Context

**Gathered:** 2026-08-09 (assumptions mode, expanded research review)
**Status:** Ready for planning

<domain>
## Phase Boundary

Keep Rindle's selected schema and host-owned Oban infrastructure strictly independent at every
diagnostic boundary. Make the fixed Rindle `public`/`rindle` upgrade mismatch observable and
actionable through read-only doctor and runtime-status flows, without touching `oban_jobs`, the
host Ecto ledger, arbitrary schemas, queues, or lifecycle data.

</domain>

<decisions>
## Implementation Decisions

### Prefix authority and host binding

- **D-119-01:** Retain `Rindle.Schema` as the only authority for Rindle's compile-time `"rindle" | "public"` schema selection. Do not derive Rindle routing from Oban, `search_path`, or a runtime application-env override. — **Reversibility:** costly — changing this pairing after the 0.4.0 migration/runtime contract would require coordinated code, migration, and adopter-doc changes.
- **D-119-02:** Resolve the host's default Oban binding as the canonical source for Oban diagnostic and runtime query prefixing. Retain the existing `:rindle, :oban_prefix` configuration only as a compatibility expectation/override during transition; if it disagrees with the resolved host binding, report a bounded binding-drift fault instead of silently choosing one. Do not infer Oban's prefix from Rindle's prefix. — **Reversibility:** costly — it changes the meaning of an existing adopter configuration key, so compatibility must be preserved and drift must be explicitly diagnosed.
- **D-119-03:** Keep the supported Oban scope deliberately narrow: default host `Oban` instance and the Rindle-configured repo must align. An alternate named instance, alternate repo, `prefix: false`, unavailable binding, or invalid identifier is a clear setup/configuration refusal, never an inference or implicit support expansion.

### Ownership-safe inspection

- **D-119-04:** Factor all prefix-sensitive catalog inspection into one internal, data-only snapshot used by both `mix rindle.doctor` and `Rindle.runtime_status/1`. The snapshot may inspect only the fixed seven Rindle-owned relations in `rindle` and `public`, and `oban_jobs` in the resolved host Oban prefix. It must never discover arbitrary schemas, inspect or mutate `schema_migrations`, configure/move Oban, or offer generic schema/relation APIs.
- **D-119-05:** Use bound query values for all catalog predicates and permit dynamic SQL identifiers only through one internal validated-and-quoted boundary. Reuse the Phase 118 fixed ownership list and quoting patterns; do not treat quoting arbitrary user/config input as authorization. Preserve catalog/permission failures as explicit `:inspection_failed` state rather than collapsing them to a missing marker or incomplete install.
- **D-119-06:** Treat the exact two-schema Rindle transition as the only safe mismatch inference: when the expected Rindle prefix is incomplete and the other supported prefix contains a complete, marker-backed Rindle v1 catalog, classify it as `:rindle_prefix_mismatch`. Partial catalogs, invalid markers, both-complete states, and other ambiguous states remain bounded incomplete/inspection failures rather than guessed upgrade states.

### Doctor diagnostics and operator experience

- **D-119-07:** Keep `mix rindle.doctor` a read-only setup and ownership gate. Preserve the established stable IDs `doctor.rindle_schema.ready` and `doctor.oban_jobs.ready`; enrich their data and rendering with expected prefix, observed state/prefix where known, owner, classification, and one next action. Do not add a third generic prefix check or a parallel doctor subsystem.
- **D-119-08:** On every doctor run, report Rindle and Oban independently, including healthy cases. A Rindle mismatch must name expected and observed supported prefixes and direct operators to the documented host-owned maintenance-window move plus matching deploy; an Oban failure must state that the host owns `Oban.Migration`. Rindle output must plainly say it never creates, moves, drops, or prefixes `oban_jobs` or `schema_migrations`.
- **D-119-09:** Use calm, specific, structured-first output: deterministic check IDs/statuses and JSON fields are the contract; concise line-oriented text is its accessible rendering. State the condition, the ownership boundary, and one verb-led next action. Never expose raw Postgrex error text, SQL, connection strings, credentials, broad schema inventories, or color-only meaning.

### Runtime-status refusal contract

- **D-119-10:** Make runtime status consume the same inspection snapshot before any asset, variant, upload, provider, or Oban report query. Preserve existing public errors `{:setup_incomplete, :rindle_schema}` and `{:setup_incomplete, :oban_jobs}` for their established cases; add detailed tagged errors only for new known states such as Rindle prefix mismatch, Oban binding drift, and catalog unavailability. — **Reversibility:** costly — `Rindle.runtime_status/1` is public, so existing error shapes remain compatible while new data is additive.
- **D-119-11:** Ensure every failure surface—Mix task, API-adjacent rendering, and existing adoption-demo/operator presentation—uses the same bounded diagnostic family rather than `inspect(reason)` or adapter exception leakage. Refusal text must say that no report queries ran and direct the operator first to `mix rindle.doctor`.

### Proof and handoffs

- **D-119-12:** Prove shared doctor/runtime interpretation, expected-public and expected-rindle mismatches, partial/invalid-marker non-mismatches, invalid or drifted Oban binding, catalog permission/query failures, bounded text/JSON/non-zero responses, and that no report query runs after refusal. Retain Phase 118's ownership proof and add read/binding-side assertions that diagnostics never mutate `public.oban_jobs`, `schema_migrations`, or host Oban configuration.
- **D-119-13:** Keep diagnosis separate from remediation. The supported operator funnel is: host migration → `mix rindle.doctor` → `mix rindle.runtime_status` → explicit lifecycle repair. Auto-migration, automatic redeployment, generic schema discovery, queue changes, dashboard redesign, packed-adopter/Cohort proof, full release-documentation reconciliation, and unrelated connectivity tooling stay out of this phase.

### the agent's Discretion

- Choose internal module/function names, exact snapshot struct/map shape, telemetry field names, validation implementation, and concise microcopy while preserving the stable IDs, ownership boundary, and bounded public error contract.
- Reuse existing focused test seams and fixtures where they preserve real database proof; do not introduce a public diagnostic snapshot API merely for implementation convenience.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Current milestone and phase contract
- `.planning/ROADMAP.md` §Phase 119 — locked goal, requirements, success criteria, and Phase 120 handoff.
- `.planning/REQUIREMENTS.md` §Ownership & Operations — BOUNDARY-01, BOUNDARY-02, and OPS-01.
- `.planning/STATE.md` §v1.23 roadmap and Decisions — Phase 117 routing, Phase 118 migration, and ownership boundary decisions already locked.
- `.planning/phases/118-isolated-migration-safe-upgrade/118-CONTEXT.md` — two-prefix authority, exact seven-relation allowlist, safe public-to-rindle move, and retained Phase 119/120 boundary.

### Canonical product and research posture
- `prompts/rindle-brand-book.md` §§Calm developer experience, Brand voice, Documentation tone — visible state, strict defaults, explicit escape hatches, and calm operator microcopy.
- `prompts/gsd-rindle-research-index.md` — research provenance and precedence; newer active project truth supersedes prompt-era findings.
- `prompts/gsd-rindle-elixir-oss-dna.md` — public API discipline, named footguns, host-install truth, and layered proof patterns.
- `guides/operations.md` — supported operator funnel and doctor/runtime-status role separation.
- `guides/troubleshooting.md` — adopter-facing troubleshooting and remediation ordering.

### Code and test integration points
- `lib/rindle/schema.ex` — sole compile-time Rindle prefix authority.
- `lib/rindle/config.ex` — independent Rindle/Oban prefix configuration boundary.
- `lib/rindle/migration/v1.ex` — authoritative Rindle-owned relation list, catalog requirements, and validated quoting/move patterns.
- `lib/rindle/ops/runtime_checks.ex` — doctor check model, catalog checks, telemetry, and current error rendering seams.
- `lib/rindle/ops/runtime_status.ex` — pre-report readiness flow and separate Rindle/Oban query prefixing.
- `lib/mix/tasks/rindle.doctor.ex` and `lib/mix/tasks/rindle.runtime_status.ex` — CLI rendering and exit behavior.
- `lib/rindle/admin/queries.ex` and `lib/rindle/admin/live/runtime_doctor_live.ex` — existing consumers of doctor/runtime diagnostic models.
- `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` — existing operator presentation that must not render raw reasons.
- `test/rindle/ops/runtime_checks_test.exs`, `test/rindle/doctor_test.exs`, `test/rindle/ops/runtime_status_test.exs`, and `test/rindle/runtime_status_task_test.exs` — focused behavior and bounded-error proof seams.
- `test/rindle/migration_test.exs` and `test/support/schema_prefix_case.ex` — ownership regression and selected/decoy-schema integration fixtures.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle.Migration.V1.owned_relations/0` and catalog requirements: fixed seven-relation Rindle ownership authority.
- `Rindle.Ops.RuntimeChecks.run/2`: stable sorted doctor-check model, injected catalog test seams, and existing telemetry.
- `Rindle.Ops.RuntimeStatus`: established preflight-before-report-query boundary plus separate `rindle_all`/`oban_all` query helpers.
- `Rindle.SchemaPrefixCase`: serial selected/decoy schema fixture without `search_path` mutation.
- Existing migration tests: direct proof that `oban_jobs` and `schema_migrations` remain untouched.

### Established Patterns
- Rindle prefix is compile-time and only `rindle` or `public`; host Oban remains independently configured and host-owned.
- Dynamic identifiers are quoted in migration code; catalog checks bind values.
- Doctor is a read-only setup/ownership diagnostic; runtime status is a bounded operational report with text/JSON rendering, limits, and refusal telemetry.
- Host applications own migrations, deployment order, Oban installation, and the Ecto migration ledger.

### Integration Points
- Centralize duplicated doctor/runtime catalog inspection before extending classification or microcopy.
- Align the resolved Oban binding with both doctor readiness and runtime Oban report queries.
- Extend existing check IDs and task renderers rather than create competing diagnostic surfaces.
- Route the adoption demo/operator presentation through the bounded refusal renderer to eliminate raw reason rendering.

</code_context>

<specifics>
## Specific Ideas

- Good mismatch language: “Runtime expects Rindle in `rindle`; the complete Rindle v1 catalog is in `public`. No report queries ran. Prepare the documented maintenance window, run the host-owned upgrade migration, deploy the `rindle` build, then rerun `mix rindle.doctor`.”
- Good Oban ownership language: “Host-owned `oban_jobs` is installed in configured prefix `public`. Rindle does not manage this table or your Ecto migration ledger.”
- Non-UI accessibility still applies: deterministic ordering, status words rather than color alone, simple line-oriented text, JSON alternative, stable identifiers, and concise actionable language. No visual redesign is in scope.
- Ecosystem lessons: follow Ecto's explicit prefix/migration boundaries and Oban's host-owned migration/config model; borrow only the namespace/host-integration lesson from mature framework engines, not their migration ownership model.

</specifics>

<deferred>
## Deferred Ideas

- Generic arbitrary-schema discovery, configuration, migration, or repair — violates Phase 118's narrow ownership contract.
- Automatic migrations, automatic deploy/restart, changing Oban queues/configuration, or lifecycle repairs from doctor/runtime-status — host/operator-owned or separate lifecycle scope.
- Dashboard redesign, a new diagnostics API version, broad connection/credential diagnostics, and full packed-adopter/Cohort/release-documentation proof — Phase 120 or future work.

</deferred>

---

*Phase: 119-Ownership Boundaries & Diagnostics*
*Context gathered: 2026-08-09*
