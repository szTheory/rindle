---
phase: 133-evidence-charter-and-live-truth
reviewed: 2026-09-13T17:05:29Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - RUNNING.md
  - scripts/ci/eval_nightly_incident.sh
  - scripts/ci/manage_nightly_incident.sh
  - scripts/ci/test_nightly_incident.sh
  - scripts/ci/test_verify_nightly_run.sh
  - scripts/ci/verify_nightly_run.sh
  - scripts/maintainer/validate_live_truth.exs
  - scripts/maintainer/validate_phase_133_reconciliation.exs
  - test/install_smoke/live_truth_parity_test.exs
  - test/install_smoke/nightly_policy_test.exs
  - test/install_smoke/phase_133_completed_validation_test.exs
  - test/install_smoke/phase_133_reconciliation_test.exs
  - test/install_smoke/support/generated_app_helper.ex
  - test/rindle/doctor_thresholds_test.exs
findings:
  critical: 6
  warning: 2
  info: 0
  total: 8
status: issues_found
---

# Phase 133: Code Review Report

**Reviewed:** 2026-09-13T17:05:29Z
**Depth:** standard
**Files Reviewed:** 14
**Status:** issues_found

## Summary

The reviewed Phase 133 implementation has six ship-blocking correctness and evidence-integrity defects. Package evidence can be manufactured from an unrelated, trivial package tree; receipt collection can erase an existing evidence file before preflight; historical receipt verification breaks after legitimate incident lifecycle changes; the production reconciliation command ignores every Plans 38–42 validation mapping; successful Plan 42 qualification trusts a self-authenticating local JSON file; and scheduled incident replay eventually deadlocks when any historical artifact expires. Two further defects leave immutable Plan 42 failure identity effectively unvalidated and make scheduled reruns unreplayable.

The intentionally halted Plan 42 run was treated as immutable exhausted history. This review does not request or imply a retry.

Focused verification passed: shell syntax checks, all 17 incident-policy cases, all 163 Nightly verifier cases, and 87 selected ExUnit tests with one excluded. The current production reconciler also returned success while reporting only 27 validation records, confirming that the 26-record Plans 38–42 closure addendum is outside its validation path.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: [BLOCKER] Caller-controlled trees and environment can manufacture package proof

**File:** /Users/jon/projects/rindle/scripts/maintainer/validate_live_truth.exs:402-490

**Related:** /Users/jon/projects/rindle/scripts/maintainer/validate_live_truth.exs:576-578; /Users/jon/projects/rindle/scripts/maintainer/validate_live_truth.exs:691-716; /Users/jon/projects/rindle/test/install_smoke/live_truth_parity_test.exs:557-579; /Users/jon/projects/rindle/test/install_smoke/live_truth_parity_test.exs:1231-1292

**Issue:** Every claimed provenance input other than repository HEAD comes from caller-controlled evidence_context: the unpacked package root, generated app root, results file, and execution environment. The receipt digests are checked only against those same caller-selected files, the dependency check is a raw substring search, and System.cmd/3 resolves mix using the supplied environment, including PATH. A caller can therefore create an unrelated package declaring the current version, a trivial consumer whose only test passes, compute matching digests, and have it accepted as package proof for the repository HEAD. The positive test demonstrates the bypass: its package contains no Rindle implementation and its lifecycle test is only assert(true), yet proof.lifecycle_proved is asserted. Supplying a fake mix through PATH makes the bypass even less constrained.

**Fix:** Materialize the exact committed subject in a verifier-owned detached worktree, build and unpack the package there, generate the consumer from a trusted template, and execute an absolute trusted Mix executable under an allowlisted environment. Do not accept package/generated roots or PATH from the claim. Bind the package artifact digest to the detached subject, parse the generated Mix project structurally, and add a negative test using the existing trivial package fixture that must be rejected.

### CR-02: [BLOCKER] Dispatch deletes or overwrites an existing receipt before qualification

**File:** /Users/jon/projects/rindle/scripts/ci/verify_nightly_run.sh:559-617

**Issue:** dispatch-and-record unconditionally removes the requested receipt path before even running preflight. Any preflight, API, run, log, local-authority, or filesystem failure therefore destroys a previously valid receipt. On success, mv also silently replaces an existing receipt. The command accepts an arbitrary receipt path and does not enforce the Plan 42 convention that the target is a new private candidate, so an invocation pointed at the canonical receipt can erase or replace the only prior authority even though qualification fails.

**Fix:** Refuse dispatch when the destination already exists, write only to a verifier-owned temporary file, and publish with no-clobber semantics only after every qualification check succeeds. Add tests proving an existing receipt remains byte-identical on preflight failure, terminal run failure, and successful collection to an already occupied path.

### CR-03: [BLOCKER] Normal incident open/close transitions invalidate an immutable Nightly receipt

**File:** /Users/jon/projects/rindle/scripts/ci/verify_nightly_run.sh:84-95

**Related:** /Users/jon/projects/rindle/scripts/ci/verify_nightly_run.sh:482-523; /Users/jon/projects/rindle/scripts/ci/verify_nightly_run.sh:533-548

**Issue:** verify-receipt fetches only currently open nightly-failure issues, then requires that list to have exactly the same cardinality as the receipt snapshot. A later scheduled red run opening a new incident invalidates a receipt that recorded zero open incidents. A later green run closing the incident removes a receipt-recorded issue from the open-only query and also invalidates the receipt. These are the intended lifecycle transitions, not evidence tampering, so a valid immutable exact-subject receipt naturally becomes unverifiable as Nightly continues to operate. The tests cover appended comments but not later issue creation or closure.

**Fix:** Query all issue states, authenticate each issue recorded in the receipt by stable number/URL and append-only historical content, and allow unrelated later issues and state transitions. Do not require current inventory cardinality to equal the historical snapshot. Add regressions for receipt-with-zero followed by a later open, and receipt-with-open followed by a later close.

### CR-04: [BLOCKER] The production reconciler ignores the complete Plans 38–42 validation map

**File:** /Users/jon/projects/rindle/scripts/maintainer/validate_phase_133_reconciliation.exs:345-424

**Related:** /Users/jon/projects/rindle/test/install_smoke/phase_133_completed_validation_test.exs:146-184

**Issue:** Execution modes select the Plans 33–37 heading, truncate the parsed body immediately before the Plans 38–42 heading, and build expected records only from plans 33..37. Consequently none of the 26 closure records is parsed or compared by the production reconciliation command. The closure mutation tests exercise a separate test-only assert_closure_map! implementation rather than run_validator, so they cannot catch divergence in production. On the current tree the command reports success with “27 validation records,” which are the pre-closure records only.

**Fix:** Extend the production parser and expected-record generator to include Plans 38–42, including requirements, validation-level, acceptance-credit, and flagged-unresolved fields. Route closure mutation tests through the actual validator and assert the full expected record count.

### CR-05: [BLOCKER] Plan 42 success accepts a self-authenticating, schema-free receipt

**File:** /Users/jon/projects/rindle/scripts/maintainer/validate_phase_133_reconciliation.exs:1116-1152

**Issue:** In the qualified-success lifecycle, the reconciler treats a receipt as authoritative after checking only that its bytes hash to the digest written in the same mutable Plan 42 summary and that its JSON subject_sha equals another value from that summary. It validates no receipt schema, run ID, attempt, workflow, ref, conclusion, job set, strict verdict, incident snapshot, or detached local authority. A locally fabricated JSON object containing only subject_sha can therefore satisfy validate_qualified_receipt once the summary digest is updated, allowing the reconciliation authority to report terminal completion without canonical Nightly evidence.

**Fix:** Invoke the canonical receipt validator, or share its strict schema and reconstruction routines, before accepting qualified_success_42. Bind the expected SHA/ref/run/attempt to independently derived authorization metadata rather than values supplied by the same summary. Add a completion fixture with a digest-consistent minimal JSON receipt and require rejection.

### CR-06: [BLOCKER] Unbounded replay permanently deadlocks after any historical verdict artifact expires

**File:** /Users/jon/projects/rindle/scripts/ci/manage_nightly_incident.sh:47-55

**Related:** /Users/jon/projects/rindle/scripts/ci/manage_nightly_incident.sh:101-149; /Users/jon/projects/rindle/scripts/ci/manage_nightly_incident.sh:332-339

**Issue:** The manager paginates the entire scheduled-run history through the current run, discards expired artifacts, and then requires exactly one non-expired artifact for every historical completed default-branch run. Once any older verdict artifact expires or is deleted while its workflow-run record remains available, every later run fails “canonical verdict artifact coverage incomplete through high-watermark.” There is no authenticated replay origin, checkpoint, or compaction record from which replay can resume, so incident lifecycle mutation is permanently disabled by a normal platform retention event.

**Fix:** Establish an authenticated bounded replay epoch or durable checkpoint whose state and last event identity are independently verified, and require full artifact coverage only from that boundary forward. Configure retention consistently with the chosen horizon and add an expired-pre-epoch success case plus an expired-in-epoch fail-closed case.

## Warnings

### WR-01: [WARNING] Halted Plan 42 identity is reduced to a substring check

**File:** /Users/jon/projects/rindle/scripts/maintainer/validate_phase_133_reconciliation.exs:747-873

**Related:** /Users/jon/projects/rindle/scripts/maintainer/validate_phase_133_reconciliation.exs:1093-1114

**Issue:** The failed-42 lifecycle accepts any halted summary whose halt_reason contains the word “immutable.” Unlike the Plan 27 checks, it does not retain or verify run 34768317696, attempt 1, the exact subject/ref, workflow, terminal conclusion, empty requirements_completed, or the unchanged prior receipt. Plan 41 authorization likewise checks only decision: authorize, not the literal authorized SHA/ref pair. A placeholder or altered failure history therefore passes reconciliation and can widen or erase the authorization boundary used by a later cycle. This is a validation defect in the immutable record; it is not a request to retry Plan 42.

**Fix:** Validate the exact Plan 41 authorized SHA/ref and the full Plan 42 immutable tuple and no-credit metadata, using structured frontmatter fields with exact equality. Add one mutation test per identity field and ensure the current failed state continues to pass without any retry.

### WR-02: [WARNING] Scheduled reruns cannot be represented by the replay index

**File:** /Users/jon/projects/rindle/scripts/ci/manage_nightly_incident.sh:101-154

**Issue:** Canonical artifacts are keyed by run ID and attempt, but relevant-runs contains only the single current run_attempt returned for each workflow run. If a scheduled run is rerun and both attempt artifacts remain, the older artifact has no matching relevant-runs row and the reverse containment check fails forever. The explicit run-attempt schema suggests attempts are intended to be replayable, yet the test matrix contains only attempt 1. This concerns ordinary scheduled-run lifecycle behavior and does not authorize a rerun of the exhausted Plan 42 diagnostic attempt.

**Fix:** Either explicitly prohibit and reject scheduled reruns before producing an artifact, or fetch and authenticate every attempt as a distinct replay event. Add a fixture with one run ID, attempts 1 and 2, and both canonical artifacts to lock the chosen policy.

---

_Reviewed: 2026-09-13T17:05:29Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
