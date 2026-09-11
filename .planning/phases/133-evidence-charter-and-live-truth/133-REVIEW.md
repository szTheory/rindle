---
phase: 133-evidence-charter-and-live-truth
reviewed: 2026-09-11T20:06:06Z
depth: standard
files_reviewed: 31
files_reviewed_list:
  - .github/actions/setup-elixir/action.yml
  - .github/workflows/ci.yml
  - .github/workflows/nightly.yml
  - .github/workflows/release.yml
  - RUNNING.md
  - config/ci_required_checks.json
  - examples/adoption_demo/docs/adoption-proof-matrix.md
  - scripts/ci/eval_nightly_incident.sh
  - scripts/ci/eval_nightly_summary.sh
  - scripts/ci/fixtures/fake_nightly_dialyzer_mix.sh
  - scripts/ci/manage_nightly_incident.sh
  - scripts/ci/run_nightly_dialyzer.sh
  - scripts/ci/test_nightly_dialyzer.sh
  - scripts/ci/test_nightly_incident.sh
  - scripts/ci/test_nightly_summary_gate.sh
  - scripts/ci/test_verify_nightly_run.sh
  - scripts/ci/verify_nightly_run.sh
  - scripts/maintainer/check_adoption_proof_matrix.sh
  - scripts/maintainer/evidence_census.exs
  - scripts/maintainer/validate_evidence_census.exs
  - scripts/maintainer/validate_live_truth.exs
  - scripts/maintainer/validate_phase_133_reconciliation.exs
  - scripts/setup_branch_protection.sh
  - test/install_smoke/ci_cache_hygiene_test.exs
  - test/install_smoke/ci_lane_split_test.exs
  - test/install_smoke/evidence_census_test.exs
  - test/install_smoke/live_truth_parity_test.exs
  - test/install_smoke/nightly_policy_test.exs
  - test/install_smoke/phase_133_completed_validation_test.exs
  - test/install_smoke/phase_133_reconciliation_test.exs
  - test/install_smoke/support/generated_app_helper.ex
findings:
  critical: 4
  warning: 3
  info: 0
  total: 7
status: issues_found
---

# Phase 133: Code Review Report

**Reviewed:** 2026-09-11T20:06:06Z
**Depth:** standard
**Files Reviewed:** 31
**Status:** issues_found

## Summary

The Phase 133 implementation contains four ship-blocking correctness defects in its Nightly incident recovery, package-evidence authority, package-receipt CLI, and phase-completion validator. The most consequential failures are that a normal red-on-SHA-A/green-on-SHA-B Nightly sequence cannot close its incident, and package proof can be manufactured from caller-authored success maps without executing the recorded commands. Three additional maintainability defects leave an unbounded atom conversion, stale public live-truth instructions, and an obsolete parallel incident policy implementation.

The four shell regression suites passed 228 assertions, and the focused Phase 133/live-truth ExUnit selection passed 27 tests with one integration-tagged test excluded. Those suites do not cover the failing transitions identified below; in two cases, their fixtures directly encode the blind spot.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: [BLOCKER] Incident replay discards the prior failing SHA, so a fixed commit cannot close the incident

**File:** `/Users/jon/projects/rindle/scripts/ci/manage_nightly_incident.sh:125-140`

**Related:** `/Users/jon/projects/rindle/scripts/ci/manage_nightly_incident.sh:238-290`; `/Users/jon/projects/rindle/scripts/ci/test_nightly_incident.sh:22-46`

**Issue:** `prepare_event_index` restricts every replayed scheduled run to `head_sha == REMOTE_MAIN_SHA`. After a red scheduled run at commit A opens an incident, the fix advances `main` to commit B. The later green run at B therefore replays only B: `derive_intent` starts with `logical_open=false`, treats the green event as a no-op, and then fails because the real issue inventory still contains one open incident. The required recovery transition can work only while `main` has not changed, which is the opposite of the normal fix workflow. The test fixture masks this by assigning the same all-`a` SHA to runs 101, 102, and 103 and to every event.

**Fix:** Authenticate each historical event against that run's own `head_sha`, default branch, workflow, event, run ID, and attempt. Require only the current high-watermark run to equal the freshly resolved remote-main SHA. Replay all authenticated scheduled default-branch events through the high watermark, then add a regression with red run A and green run B that closes exactly one incident.

### CR-02: [BLOCKER] Caller-authored result maps can forge successful package execution evidence

**File:** `/Users/jon/projects/rindle/test/install_smoke/support/generated_app_helper.ex:338-378`

**Related:** `/Users/jon/projects/rindle/scripts/maintainer/validate_live_truth.exs:484-493`; `/Users/jon/projects/rindle/scripts/maintainer/validate_live_truth.exs:597-641`; `/Users/jon/projects/rindle/test/install_smoke/live_truth_parity_test.exs:751-795`

**Issue:** The exported receipt producer accepts arbitrary `%{exit_code: 0, output: ...}` maps, hashes those strings, writes them to a caller-controlled generated-app directory, and labels them compile/boot/lifecycle evidence. The verifier checks only that the self-authored receipt matches the self-authored results file, that the argv is expected, and that the supplied result fields look valid. It never runs the commands or verifies immutable provenance for their execution. The supposedly positive unit fixture demonstrates the bypass: it creates minimal fake package/generated trees and passes literal `"compile ok"`, `"boot ok"`, and `"2 tests, 0 failures"` maps; the resulting receipt is accepted as package proof even though none of those commands ran.

**Fix:** Move command execution and receipt construction behind one canonical producer that accepts no caller-provided result maps. Bind the resulting command records to trusted run/artifact provenance (or re-execute the exact commands in the materialized unpacked tree during validation). Add a negative test that constructs a fully schema-correct, digest-consistent directory/results/receipt triple without running commands and require validation to reject it.

### CR-03: [BLOCKER] `--package-receipt` accepts and reports arbitrary JSON as live truth when no package claim consumes it

**File:** `/Users/jon/projects/rindle/scripts/maintainer/validate_live_truth.exs:40-56`

**Related:** `/Users/jon/projects/rindle/scripts/maintainer/validate_live_truth.exs:384-389`; `/Users/jon/projects/rindle/scripts/maintainer/validate_live_truth.exs:1064-1099`

**Issue:** The CLI reads `--package-receipt`, stores its decoded JSON directly in `model.package_proof`, validates only the separately supplied claims, and then prints `live truth valid`. With no `--claims` argument, any valid JSON object—including the unrelated required-check policy JSON—passes and is emitted as `package_proof` in JSON mode. This contradicts the advertised public input and the phase's explicit requirement that CLI receipt input traverse the same normalization and filesystem checks as inline receipts.

**Fix:** Either remove `--package-receipt` as a standalone authority input, or require the filesystem context needed by `verify_package_evidence!/2` and normalize it immediately. If it remains a default consumed by claims, track consumption and fail when a supplied receipt was never validated. Add CLI tests for schema-invalid but valid JSON, a fully self-consistent forged receipt, and a receipt supplied without any consuming package claim.

### CR-04: [BLOCKER] A body or code-block line can impersonate completed SUMMARY frontmatter

**File:** `/Users/jon/projects/rindle/scripts/maintainer/validate_phase_133_reconciliation.exs:516-535`

**Related:** `/Users/jon/projects/rindle/test/install_smoke/phase_133_completed_validation_test.exs:74-85`

**Issue:** `completed_summary_set/1` searches the entire Markdown file for any line matching `status: complete`; it does not parse or constrain the match to YAML frontmatter. A summary with frontmatter `status: halted` followed by body text or a fenced example containing `status: complete` is therefore counted as complete and can satisfy `--expect-execution-complete`, roadmap counts, and checkbox parity. The negative test covers only halted frontmatter with no matching body line, so this false completion path remains green.

**Fix:** Parse only the first delimited YAML frontmatter block, reject malformed/duplicate frontmatter, and require its single `status` value to equal `complete` (along with the expected phase/plan identity if present). Add a regression whose frontmatter is halted while its body contains `status: complete`.

## Warnings

### WR-01: [WARNING] Untrusted resolver text is interned as a permanent VM atom

**File:** `/Users/jon/projects/rindle/test/install_smoke/support/generated_app_helper.ex:756-757`

**Related:** `/Users/jon/projects/rindle/test/install_smoke/support/generated_app_helper.ex:616`

**Issue:** `to_existing_atom_safe/1` is misnamed: it calls `String.to_atom/1` on a value decoded from a generated migration report. Every novel value permanently grows the BEAM atom table. Repeated malformed or influenced reports can exhaust the atom table and terminate the VM.

**Fix:** Keep the resolver as a string, map an explicit allowlist of resolver names to existing atoms, or use `String.to_existing_atom/1` with bounded error handling. Never intern arbitrary decoded text.

### WR-02: [WARNING] RUNNING.md retains stale live-authority and branch-protection instructions

**File:** `/Users/jon/projects/rindle/RUNNING.md:82-87`

**Related:** `/Users/jon/projects/rindle/RUNNING.md:46-48`; `/Users/jon/projects/rindle/RUNNING.md:174-176`; `/Users/jon/projects/rindle/scripts/setup_branch_protection.sh:17-45`

**Issue:** The maintained public live-truth document still names “Plan 07's exact-SHA ... run” as the live acceptance authority even though the phase's later repairs replaced that receipt. It also documents the old hard-coded `REQUIRED_CHECKS=("CI Summary")` implementation after the script moved authority to `config/ci_required_checks.json`, and describes Nightly as broadly “advisory” immediately before classifying its component jobs as Nightly-gating. These contradictions make the operator guide an unreliable view of the authority model this phase is meant to establish.

**Fix:** Replace the Plan 07 reference with the current durable receipt/validator authority, document `config/ci_required_checks.json` as the required-context source consumed by the setup script, and distinguish “not a required PR check” from “gating the Nightly aggregate.” Add exact assertions for these active statements to the live-truth parity test.

### WR-03: [WARNING] The obsolete standalone incident evaluator leaves a second divergent policy implementation

**File:** `/Users/jon/projects/rindle/scripts/ci/eval_nightly_incident.sh:1-79`

**Related:** `/Users/jon/projects/rindle/scripts/ci/manage_nightly_incident.sh:238-293`

**Issue:** No production workflow or current test calls `eval_nightly_incident.sh`; the Nightly lifecycle now implements policy and replay inside `manage_nightly_incident.sh`. The unused evaluator still uses the retired `nightly-run:` marker shape while production uses `nightly-mutation:<action>:` markers, and it implements a separate one-event state machine. Keeping both makes future incident changes prone to updating or testing the wrong policy.

**Fix:** Delete the unused evaluator, or refactor the manager so one pure evaluator is the actual production dependency and its tests exercise that exact implementation and marker schema.

---

_Reviewed: 2026-09-11T20:06:06Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
