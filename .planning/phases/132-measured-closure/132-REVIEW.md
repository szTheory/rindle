---
phase: 132-measured-closure
reviewed: 2026-08-27T17:03:55Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - scripts/ci/collect_pr_timing_receipt.sh
  - scripts/ci/install_apt_packages.sh
  - scripts/maintainer/automation_first_contract.sh
  - scripts/maintainer/repo_hygiene_check.sh
  - test/install_smoke/automation_first_contract_test.exs
  - test/install_smoke/ci_cache_hygiene_test.exs
  - test/install_smoke/ci_lane_split_test.exs
  - test/install_smoke/ci_timing_automation_test.exs
  - test/install_smoke/generated_app_smoke_test.exs
  - test/install_smoke/support/generated_app/workspace.ex
  - test/install_smoke/support/generated_app_helper.ex
findings:
  critical: 4
  warning: 2
  info: 0
  total: 6
status: issues_found
---

# Phase 132: Code Review Report

**Reviewed:** 2026-08-27T17:03:55Z
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

The Phase 132 controller has several paths that undermine its stated bounded, fail-closed evidence contract. In particular, a terminal controller state can be reset, the caller can authorize more than two sequences, and the sampler can wait forever for a run that never materializes. The canonical-population query also reads only one API page, so a receipt can be accepted without all eligible runs.

Focused test commands passed, but the timing fixture does not cover terminal-state re-entry, an over-ceiling `--max-sequences`, a permanently absent trigger, or a paginated Actions population.

## Critical Issues

### CR-01: A failed controller state is silently reset and permits fresh sequences

**File:** `scripts/ci/collect_pr_timing_receipt.sh:377-379`
**Issue:** A second invocation against a terminal `status: "failed"` state calls `write_initial_state`, resetting `sequence_attempt` to 1 and discarding the recorded failure. This directly bypasses the two-sequence ceiling that Plan 132-18 relies on: rerunning the same command can produce two more label-triggered sampling sequences after the authorized budget was exhausted.
**Fix:** Treat `failed` as terminal. Validate its invocation identity, report the recorded reason, and exit non-zero without mutating it. Add a process regression that exhausts sequence 2, invokes the controller again, and proves the state file, label count, and receipt are unchanged.

### CR-02: The public flag accepts an unbounded sequence budget

**File:** `scripts/ci/collect_pr_timing_receipt.sh:284-285`
**Issue:** The controller accepts every positive `--max-sequences` value, and the loop at line 575 uses that supplied value. `--max-sequences 3` (or much larger) therefore authorizes additional trigger/restart sequences despite the Phase 132 contract requiring a two-sequence ceiling.
**Fix:** Require exactly two for this CI-14 controller, for example: `[[ "$max_sequences" =~ ^[0-9]+$ ]] && [ "$max_sequences" -eq 2 ] || die "--max-sequences must be exactly 2"`. Add tests that reject 1 and 3 before state, labels, or receipts can change.

### CR-03: Missing Actions runs make the controller poll forever

**File:** `scripts/ci/collect_pr_timing_receipt.sh:513-527`
**Issue:** `wait_for_new_run` has no deadline. `creation_timeout` is declared and accepted (lines 49 and 71) but never used, so a label that does not create a visible PR run causes an unattended controller to sleep and poll indefinitely instead of terminalizing within a bounded failure path. API rate-limit retries in `gh_api_json` are likewise outside a controller deadline.
**Fix:** Start a creation deadline when persisting the trigger, retain it in state for resume, and return a terminal failure when it expires; bound API retry time by the same deadline. Add a fixture mode that never returns a new run and assert bounded failure, retained forensic state, label cleanup, and no receipt mutation.

### CR-04: Canonical eligible-run selection ignores API pagination

**File:** `scripts/ci/collect_pr_timing_receipt.sh:240-252`
**Issue:** The canonical authority requests `per_page=100` once and never follows GitHub's next-page link. If more than 100 Actions runs exist for the workflow, older qualifying first-attempt runs for the same PR/SHA are omitted; the selected IDs can equal this truncated list and a receipt can be accepted as a “complete canonical eligible population.” This invalidates the receipt's population-integrity claim.
**Fix:** Retrieve every page (for example, `gh api --paginate` and normalize the resulting page objects) before filtering and sorting. Add a shim fixture with qualifying records beyond page 1 and prove that the controller either includes them or fails rather than issuing a ten-run receipt from a truncated population.

## Warnings

### WR-01: Resumed running state is trusted without identity or schema validation

**File:** `scripts/ci/collect_pr_timing_receipt.sh:377-396`
**Issue:** Existing `running` state bypasses the identity check applied only to `complete` state. A stale or malformed JSON file in the caller-provided state directory can supply a different repository/PR/label, invalid `sequence_attempt`, arbitrary `runs`, or a pending trigger, and the controller proceeds to mutate or calculate from it. The final API check may reject some bad populations, but it is not a fail-closed resume boundary.
**Fix:** Before using any existing nonterminal state, require schema version 2 and exact equality for repo, PR, SHA, label, max sequence count, valid attempt range, arrays, and pending/current-run shape. Add negative resume fixtures for mismatched identity and malformed state and assert no label, state, or receipt mutation.

### WR-02: Automation-first parser can miss valid XML-like checkpoint syntax

**File:** `scripts/maintainer/automation_first_contract.sh:53-68`
**Issue:** The contract recognizes only the exact substring `type="checkpoint:human-action"` (and similarly the exact human-verify spelling). Attribute order and quote style are legal in the task markup, so `<task gate="blocking" type='checkpoint:human-action'>` is skipped entirely. A manual acceptance checkpoint can consequently evade the required automation-first enforcement. The tests exercise only the one hard-coded attribute layout.
**Fix:** Parse task tags with an XML-aware tool, or at minimum match both quote styles and attributes in either order before analyzing each complete task block. Add regressions for reordered attributes and single quotes, including a human-verify checkpoint.

---

_Reviewed: 2026-08-27T17:03:55Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
