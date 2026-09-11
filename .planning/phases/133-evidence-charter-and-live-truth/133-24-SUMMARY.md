---
phase: 133-evidence-charter-and-live-truth
plan: 24
subsystem: release-evidence
tags: [package-authority, command-execution, receipt-consumption, atom-safety, tdd]
status: complete
requires:
  - phase: 133-22
    provides: reviewed live-truth gaps and authenticated package evidence baseline
provides:
  - independently executed compile, boot, and smoke/lifecycle package proof
  - exactly-once CLI package-receipt consumption with bounded errors
  - finite generated migration resolver decoding without atom allocation
affects: [TRUTH-08, package-consumer, live-truth, generated-app-smoke]
tech-stack:
  added: []
  patterns:
    - repository-owned command execution after package and generated-tree authentication
    - explicit package-receipt argument consumer identity
    - finite string-to-existing-atom resolver mapping
key-files:
  created: []
  modified:
    - test/install_smoke/support/generated_app_helper.ex
    - scripts/maintainer/validate_live_truth.exs
    - test/install_smoke/live_truth_parity_test.exs
key-decisions:
  - "Treat persisted package command results as diagnostic data; independently executed repository-owned commands are the only lifecycle authority."
  - "Require receipt arguments to name exactly one consumer through receipt_source: package-receipt-argument and keep the option out of model.package_proof."
  - "Map only the repository-emitted host_migrations resolver string to :host_migrations; reject every other value without atom creation."
patterns-established:
  - "Execution-backed evidence: authenticate roots, versions, trees, dependency source, and argv before executing the expected commands."
  - "Consumed input: standalone evidence options must be bound to one complete claim or rejected before output."
requirements-completed: [TRUTH-08]
coverage:
  - id: D1
    description: "Package and lifecycle truth derives from independently observed compile, boot, and smoke/lifecycle execution in the authenticated generated consumer."
    requirement: TRUTH-08
    verification:
      - kind: integration
        ref: "mix test test/install_smoke/live_truth_parity_test.exs --only package_authority"
        status: pass
      - kind: e2e
        ref: "mix test test/install_smoke/generated_app_smoke_test.exs --only minio"
        status: pass
    human_judgment: false
  - id: D2
    description: "A --package-receipt is parsed with bounded errors and consumed by exactly one complete package claim without entering the derived model directly."
    requirement: TRUTH-08
    verification:
      - kind: integration
        ref: "test/install_smoke/live_truth_parity_test.exs#standalone package receipt requires exactly one explicit consuming claim"
        status: pass
      - kind: integration
        ref: "test/install_smoke/live_truth_parity_test.exs#one complete package claim consumes and normalizes the receipt argument"
        status: pass
    human_judgment: false
  - id: D3
    description: "Generated migration resolver decoding accepts only host_migrations and nil while repeated unknown strings leave the atom count unchanged."
    requirement: TRUTH-08
    verification:
      - kind: unit
        ref: "test/install_smoke/live_truth_parity_test.exs#migration resolver decoding is finite and cannot allocate caller atoms"
        status: pass
    human_judgment: false
plan_head_before: 034d74b3f17509f888ebad66639aa2dd6f2f7220
actuals:
  tokens: 7714
  tasks: 3
  commits: 6
metrics:
  duration: 35m
  completed: 2026-09-11
---

# Phase 133 Plan 24: Execution-Authenticated Package Truth Summary

Repository-owned command re-execution now authenticates package lifecycle proof, CLI receipts require one complete consumer, and generated resolver decoding cannot allocate untrusted atoms.

## Performance

- **Duration:** 35 minutes
- **Started:** 2026-09-11T21:18:17Z
- **Completed:** 2026-09-11T21:52:58Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Removed the command-result authority seam from the exported package evidence producer and made both producer and verifier execute the exact repository-owned compile, boot, and combined smoke/lifecycle argv.
- Made `--package-receipt` fail closed on malformed JSON, zero or multiple consumers, inline disagreement, and incomplete evidence context while preserving inline claims and independent-adopter boundaries.
- Replaced generated-report `String.to_atom/1` with the explicit `host_migrations` resolver vocabulary at all three report construction sites and proved repeated unknown values do not grow the atom table.

## Task Commits

1. **Task 1: Authenticate package proof through independent command execution**
   - RED: `c93d565` — forged schema-correct command results initially validated.
   - GREEN: `174abf0` — repository-owned producer and verifier command execution.
2. **Task 2: Normalize and consume every standalone package receipt**
   - RED: `e304576` — a receipt with no consuming claim initially printed valid live truth.
   - GREEN: `fd29fc7` — bounded parsing and exactly-one explicit consumer enforcement.
3. **Task 3: Bound generated migration resolver decoding**
   - RED: `5906548` — finite resolver decoding and atom-count protection were absent.
   - GREEN: `9f0e32e` — literal resolver mapping applied at every report boundary.

## Verification

- `mix test test/install_smoke/live_truth_parity_test.exs --only package_authority` — 28 tests, 0 failures, 12 excluded.
- `mix test test/install_smoke/generated_app_smoke_test.exs --only minio` — 33 tests, 0 failures, 17 excluded in the post-Task-1 tracer rerun.
- `mix test test/install_smoke/generated_app_smoke_test.exs` — 33 tests, 0 failures, 16 excluded.
- `mix format --check-formatted test/install_smoke/support/generated_app_helper.ex scripts/maintainer/validate_live_truth.exs test/install_smoke/live_truth_parity_test.exs` — exit 0.

## TDD Gate Compliance

All three tasks followed intentional RED then GREEN commits. Each RED target failed on the planned behavioral assertion and returned `RED_EVIDENCE_OK`; every GREEN implementation passed its focused gate. No behavior-neutral refactor commit was needed.

## Decisions Made

- Persisted result documents remain schema-checked diagnostics, but cannot establish lifecycle truth; fresh execution in the authenticated generated root is authoritative.
- Receipt argument consumption is explicit through `receipt_source: package-receipt-argument`, preventing accidental fallback or standalone model injection.
- The complete repository-owned migration resolver vocabulary is currently the single literal `host_migrations` value emitted by `generated_app/migrations.ex`.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The repository-pinned Erlang 27.2 was not installed locally, so verification used the installed compatible Erlang 27.3.4.15 with Elixir 1.17.3-otp-27.
- The OTP-27 environment initially lacked the pinned Phoenix 1.8.9 installer archive; the repository-owned `scripts/ci/ensure_phx_new.sh` bootstrap restored it.
- The command runner terminated background MinIO when the bootstrap shell exited, so MinIO was held in a live process session during the two full generated-consumer gates.

## Known Stubs

None.

## Threat Flags

None. The changed execution, receipt, and atom-table trust boundaries are all declared in the plan threat model and covered by automated regressions.

## Self-Check: PASSED

All three modified files exist, all six task commits are present, every acceptance criterion is covered by passing tests, the plan-level verification exited 0, and no generated or task-owned files remain untracked.

## Next Phase Readiness

TRUTH-08 package authority and receipt-consumption gaps are closed. Phase 133 can continue to the remaining gap-closure plans without granting maintainer evidence independent-adopter or 1.0 authority.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-11*
