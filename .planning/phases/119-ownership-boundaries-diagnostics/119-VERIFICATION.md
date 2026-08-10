---
phase: 119-ownership-boundaries-diagnostics
verified: 2026-08-10T02:14:39Z
status: gaps_found
score: 2/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "mix rindle.doctor reports separate Rindle and Oban prefix diagnostics without raw database failures."
    status: failed
    reason: "Migration-inspection failures interpolate Exception.message/1 into a doctor check summary; that summary is emitted by the CLI and returned to the admin model."
    artifacts:
      - path: "lib/rindle/ops/runtime_checks.ex"
        issue: "migration_statuses/1 embeds raw exception text at lines 667-675."
    missing:
      - "Replace exception-derived summaries with a fixed bounded classification/message and add a sentinel regression test through doctor/admin."
  - truth: "mix rindle.runtime_status returns bounded setup failures rather than raw database exceptions."
    status: failed
    reason: "RuntimeStatus copies snapshot expected_prefix and observed_prefix without validation, and the text/JSON formatter serializes them verbatim."
    artifacts:
      - path: "lib/rindle/ops/runtime_status.ex"
        issue: "bounded_refusal/3 forwards arbitrary prefix values at lines 159-166."
      - path: "lib/mix/tasks/rindle.runtime_status.ex"
        issue: "format_error/1 and error_details/1 interpolate/serialize those values at lines 79-84 and 126-135."
    missing:
      - "Project prefix fields through a strict safe-prefix allowlist or use a constant unknown value before text and JSON rendering; test sentinels in mismatch and binding-drift details."
  - truth: "Admin query/LiveView and adoption-demo surfaces consume bounded diagnostic data and render runtime refusals safely."
    status: failed
    reason: "The admin refusal model deliberately has runtime_status: nil, but the LiveView always dereferences runtime_status fields while rendering runtime findings."
    artifacts:
      - path: "lib/rindle/admin/queries.ex"
        issue: "runtime_doctor/1 sets runtime_status: nil on every refusal at lines 233-241."
      - path: "lib/rindle/admin/live/runtime_doctor_live.ex"
        issue: "runtime_findings/1 dereferences nil at lines 190-194, while the template calls it unconditionally at line 107."
    missing:
      - "Make runtime findings conditional/empty for a refusal model and add an actual LiveView refusal render test."
---

# Phase 119: Ownership Boundaries & Diagnostics Verification Report

**Phase Goal:** Operators can distinguish Rindle's configured schema from independently configured host Oban infrastructure and resolve prefix problems without raw database failures.
**Verified:** 2026-08-10T02:14:39Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Rindle leaves host `oban_jobs`, host `schema_migrations`, and host Oban configuration outside its diagnostic ownership boundary. | ✓ VERIFIED | `OwnershipSnapshot` uses catalog reads only; no diagnostic production path invokes DDL or `Application.put_env`. The no-mutation proof is present in `test/rindle/migration_test.exs`. |
| 2 | Catalog and Oban-binding reads resolve only validated, respective schema authorities. | ✓ VERIFIED | `ownership_snapshot.ex:60-103` canonicalizes the default binding before catalog access; `:137-193` bounds Rindle catalog reads to `Schema.supported_prefixes/0` and the seven-relation allowlist; `:207-216` binds the host `oban_jobs` catalog query. |
| 3 | `mix rindle.doctor` reports separately owned prefixes and actionable diagnostics **without raw database failures**. | ✗ FAILED | The normal mismatch path is wired and covered, but `runtime_checks.ex:667-675` inserts raw `Exception.message/1` into a rendered doctor summary. |
| 4 | `mix rindle.runtime_status` preflights the snapshot before report queries and gives a bounded failure. | ✗ FAILED | Preflight/tripwire behavior is tested, but `runtime_status.ex:159-166` forwards unchecked prefix data that `rindle.runtime_status.ex:79-84,126-135` renders/serializes. |
| 5 | Admin and demo operator surfaces safely render the shared diagnostic family. | ✗ FAILED | Demo unknown-error path is redacted, but an actual bounded admin refusal crashes: the facade returns `runtime_status: nil` and the LiveView unconditionally dereferences it. |

**Score:** 2/5 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/rindle/ops/ownership_snapshot.ex` | Fixed-scope snapshot/classifier | ✓ VERIFIED | Substantive and consumed by doctor/runtime-status. |
| `lib/rindle/ops/runtime_checks.ex` | Enriched stable doctor checks | ⚠️ HOLLOW | Wired and substantive, but raw migration exception text crosses its output boundary. |
| `lib/mix/tasks/rindle.doctor.ex` | Structured-first doctor rendering | ⚠️ HOLLOW | Correctly renders check summaries, which makes the raw summary leak observable. |
| `test/rindle/ops/ownership_snapshot_test.exs` | Classifier/binding matrix | ✓ VERIFIED | Present and selected test run passed. |
| `test/rindle/doctor_test.exs` | Doctor mismatch proof | ✓ VERIFIED | Covers normal mismatch redaction, not migration-inspection exception text. |
| `test/rindle/ops/runtime_checks_test.exs` | Stable check behavior | ✓ VERIFIED | Present/substantive; lacks the raw migration-error rendering case. |
| `test/rindle/migration_test.exs` | Live no-mutation proof | ✓ VERIFIED | Contains before/after diagnostic ownership proof. |
| `lib/rindle/ops/runtime_status.ex` | Snapshot-first report routing | ⚠️ HOLLOW | Preflight is wired; bounded refusal copies unvalidated fields. |
| `lib/mix/tasks/rindle.runtime_status.ex` | Bounded text/JSON formatter | ⚠️ HOLLOW | Unknown fallback is safe, but known mismatch/drift branches render arbitrary prefix values. |
| `test/rindle/ops/runtime_status_test.exs` | Refusal and tripwire proof | ✓ VERIFIED | Passes for safe fixtures; does not probe hostile prefix payloads. |
| `test/rindle/runtime_status_task_test.exs` | CLI error contract | ✓ VERIFIED | Covers unknown-error redaction and safe fixture prefixes, not unsafe known-classification fields. |
| `lib/rindle/admin/queries.ex` | Safe runtime-doctor facade | ⚠️ HOLLOW | Projects a bounded diagnostic but deliberately produces a nil runtime report that its consumer cannot render. |
| `lib/rindle/admin/live/runtime_doctor_live.ex` | Bounded operator presentation | ✗ STUB ON REFUSAL PATH | The refusal branch exists but fails at the unconditional `runtime_findings/1` call. |
| `test/rindle/admin/queries_test.exs` | Facade redaction proof | ✓ VERIFIED | Validates the facade map only; no LiveView refusal rendering test. |
| `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` | Shared demo formatter | ✓ VERIFIED | Calls `Mix.Tasks.Rindle.RuntimeStatus.format_error/1` at its private provider boundary. |
| `examples/adoption_demo/test/adoption_demo_web/live/ops_live_test.exs` | Demo click-path redaction | ✓ VERIFIED | Exercised unknown error sentinels; it does not cover the formatter's known unsafe prefix branches. |
| `examples/adoption_demo/e2e/ops-surfaces.spec.js` | Supplemental browser proof | ⚠️ ORPHANED BY ENVIRONMENT | Exists, but the documented browser run is blocked before Playwright by inherited demo fixtures. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Snapshot | `Migration.V1.owned_relations/0` | fixed catalog allowlist | ✓ WIRED | Direct call at `ownership_snapshot.ex:180`. |
| Runtime checks | Snapshot | single doctor snapshot | ✓ WIRED | Same snapshot supplies both readiness checks at `runtime_checks.ex:156-158`. |
| Doctor renderer | check maps | structured fields | ✓ WIRED | `emit_check/2` uses enriched fields at `rindle.doctor.ex:98-119`; it also renders unsafe raw summaries. |
| Snapshot | default Oban binding | canonical host resolver | ✓ WIRED | `Application.get_env(mix_app, Oban)` is validated before reads. |
| Runtime status | Snapshot | first report preflight | ✓ WIRED | `ready_snapshot/0` precedes every report helper. |
| Runtime status | Oban queries | snapshot-resolved prefix | ✓ WIRED | `variant_report(... snapshot.oban.expected_prefix)` flows to `oban_all/2`. |
| Admin facade | RuntimeStatus | bounded projection | ⚠️ PARTIAL | Facade projects diagnostic data, but the resulting `nil` report crashes the LiveView consumer. |
| Admin LiveView | enriched doctor maps | ownership fields | ✓ WIRED | Owner/prefix/classification/action cells render in the existing table. |
| Demo LiveView | shared formatter | refusal renderer | ✓ WIRED | Unknown-error test confirms this specific path. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Doctor CLI | `report.checks` | `RuntimeChecks.run/2` | Yes, but failure summary can contain raw exception data | ⚠️ LEAKING |
| Runtime-status CLI | refusal details | snapshot → `bounded_refusal/3` → formatter | Yes, but no safe-field projection | ⚠️ LEAKING |
| Admin Runtime/Doctor | `model.runtime_status` / `model.diagnostic` | `Queries.runtime_doctor/1` | Refusal data is real but report is `nil` | ✗ DISCONNECTED ON REFUSAL |
| Adoption demo | `runtime_output` | private provider → shared formatter | Yes | ✓ FLOWING for the tested unknown-error route |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Snapshot classifier plus runtime preflight/tripwire and unknown-error redaction | `mix test test/rindle/ops/ownership_snapshot_test.exs test/rindle/ops/runtime_status_test.exs:48 test/rindle/runtime_status_task_test.exs:120 --seed 0` | 15 tests, 0 failures; Postgrex logged inherited `too_many_connections` during startup | ✓ PASS |
| Compilation | `mix compile --warnings-as-errors` | Exit 0 | ✓ PASS |
| Admin refusal LiveView render | No test exists; static trace reaches nil dereference | Refusal cannot complete render | ✗ FAIL |

### Probe Execution

Step 7c: SKIPPED — no Phase 119 probe script is declared or present.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- |
| BOUNDARY-01 | 119-01, 119-02, 119-04 | Rindle does not take ownership of host Oban/ledger state. | ✓ SATISFIED | Fixed read-only snapshot, bounded host resolver, and no-mutation proof are present. |
| BOUNDARY-02 | 119-01, 119-02, 119-03 | Prefix-sensitive reads use validated, safely bounded identifiers and authorities. | ✗ BLOCKED | Catalog SQL is bounded, but a binding-drift prefix reaches output unchecked through runtime-status. |
| OPS-01 | 119-01, 119-03, 119-04 | Doctor/runtime-status separately report ownership and mismatch without raw database errors. | ✗ BLOCKED | Raw migration exception reaches doctor/admin; known runtime refusal can serialize unsafe prefix data; admin refusal crashes. |

No Phase-119 requirement is orphaned: all three IDs are claimed by plans. Phase 120 covers adoption/release proof only, not these correctness defects, so none is deferred.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `lib/rindle/admin/live/runtime_doctor_live.ex` | 107, 190-194 | Nil dereference on refusal model | 🛑 BLOCKER | Bounded diagnostic cannot render. |
| `lib/mix/tasks/rindle.runtime_status.ex` | 79-84, 126-135 | Unvalidated values rendered/serialized | 🛑 BLOCKER | Raw/error-like values may leak through known refusals. |
| `lib/rindle/ops/runtime_checks.ex` | 667-675 | `Exception.message/1` in rendered check | 🛑 BLOCKER | Database exception text reaches doctor and admin. |

## Gaps Summary

The diagnostic architecture is materially present: it preserves the host boundary, constrains catalog inspection, distinguishes prefixes, and preflights report queries. The phase goal nevertheless requires safe resolution of real prefix/inspection faults. Three failure paths violate that contract: one crashes the admin surface and two expose data that the bounded-diagnostic layer is meant to suppress. These are Phase 119 implementation defects, not consequences of the inherited database fixture failures.

The broader `mix test --seed 0` failure (reported as 405 failures caused by missing public tables and connection exhaustion) is not used as evidence against Phase 119: the selected Phase 119 tests above passed, and the source gaps are independently observable without that environment.

---

_Verified: 2026-08-10T02:14:39Z_
_Verifier: the agent (gsd-verifier)_
