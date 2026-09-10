---
phase: 133-evidence-charter-and-live-truth
reviewed: 2026-09-10T19:01:57Z
depth: standard
files_reviewed: 24
files_reviewed_list:
  - .github/actions/setup-elixir/action.yml
  - .github/workflows/ci.yml
  - .github/workflows/nightly.yml
  - RUNNING.md
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
  - test/install_smoke/ci_cache_hygiene_test.exs
  - test/install_smoke/ci_lane_split_test.exs
  - test/install_smoke/evidence_census_test.exs
  - test/install_smoke/live_truth_parity_test.exs
  - test/install_smoke/nightly_policy_test.exs
findings:
  critical: 6
  warning: 1
  info: 0
  total: 7
status: issues_found
---

# Phase 133: Code Review Report

**Reviewed:** 2026-09-10T19:01:57Z
**Depth:** standard
**Files Reviewed:** 24
**Status:** issues_found

## Summary

Phase 133 adds substantial negative-test coverage, but six correctness/data-loss/evidence-integrity defects remain. In particular, the Dialyzer helper can recursively delete an arbitrary caller-selected directory, the Nightly collector aborts when normal older dispatches are present, and several claimed authorities are still derived from mutable or self-asserted inputs rather than independently bound evidence.

The four shell regression suites completed successfully and ShellCheck reported no warning-or-higher findings. The five focused ExUnit files could not be executed because the repository's configured `mix` toolchain is not installed in the current asdf environment; this does not affect the directly provable findings below.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: [BLOCKER] `PLT_DIR` permits recursive deletion outside the PLT directory

**File:** `scripts/ci/run_nightly_dialyzer.sh:11-16,34-36`

**Issue:** `PLT_DIR` is caller-controlled, but the safety check rejects only the empty string, `/`, and `.`. Values such as `..`, `../..`, `/tmp`, or the repository's absolute root pass and are handed directly to `rm -rf`. A mistyped or inherited environment variable can therefore delete the parent checkout or another broad directory before Dialyzer runs. This is a data-loss risk, not merely a test-hook concern, because the production script advertises `PLT_DIR` as an override and calls `reset_plt` in both fresh and stale-cache paths.

**Fix:** Resolve the repository root and the candidate with physical paths, require the candidate to be the exact approved repository-relative PLT path (or a descendant of a dedicated temporary root), reject `..`/symlink escapes and all absolute paths outside that root, then delete only after the containment check. Prefer removing the production override entirely and injecting a temporary repository root in tests.

### CR-02: [BLOCKER] Dispatch polling fails as soon as any older unrelated run exists

**File:** `scripts/ci/verify_nightly_run.sh:364-385`

**Issue:** Immediately after dispatch, `gh run list` may not yet include the new run because GitHub's listing is eventually consistent. The code nevertheless dies whenever the list is non-empty and the exact new run has not appeared. A repository with any prior `workflow_dispatch` run therefore takes the `foreign workflow/ref/SHA identity` branch on the first poll instead of waiting for the just-dispatched run. The fake timeout case returns an empty list, so the regression suite does not exercise the normal “old runs visible, new run not visible yet” state.

**Fix:** Ignore nonmatching historical runs during the bounded polling window. Continue polling while the exact post-boundary match count is zero; accept exactly one qualifying match; fail explicitly on more than one post-boundary qualifying match; and time out only at the deadline. Add a fake state that returns unrelated old runs for at least one poll before exposing the new exact run.

### CR-03: [BLOCKER] Package and adoption authority is forgeable from arbitrary directories and self-reported booleans

**File:** `scripts/maintainer/validate_live_truth.exs:263-289,344-421,437-459`

**Issue:** The validator treats an untrusted map as authoritative when it contains the literal `proof_origin`, points at any two existing directories, places files named `hex_metadata.config` and `mix.exs` in one of them, and self-reports zero exit codes plus `lifecycle_proved: true`. It never authenticates the receipt, binds it to a subject/package digest, verifies the unpacked package version/content, or proves that the generated application actually depended on that package. The repository's own `package_receipt_fixture!` demonstrates this shape using freshly created arbitrary directories and fake file contents. The same forgeable receipt can then be labeled `independent-adopter` with any nonempty name and `authorizes_1_0: true`, which the adoption branch accepts.

**Fix:** Make the evidence producer write a canonical receipt containing immutable subject SHA, package tarball/content digest, generated-app dependency lock/source, command argv, and captured results; verify those fields against the filesystem and Git/package authorities rather than trusting booleans. Independent-adopter authority needs a distinct authenticated evidence type and allowlisted identity/provenance, not a caller-provided name on the package receipt.

### CR-04: [BLOCKER] Receipt revalidation binds to a mutable current-worktree ledger

**File:** `scripts/ci/verify_nightly_run.sh:275-316`

**Issue:** Although validator source files are loaded from a detached worktree at `expected_sha`, both census commands consume `133-EVIDENCE-CENSUS.json` from `project_root`, i.e. the caller's current mutable working tree. The Nightly receipt stores only `{status:"pass"}` for these authorities and no ledger blob/digest/commit identity. Editing or replacing the post-subject ledger therefore changes what a historical receipt means, and a jointly forged ledger/receipt can be revalidated without any mismatch to the immutable Nightly subject. Exact-subject script execution does not make an external mutable input immutable.

**Fix:** Bind the exact ledger bytes into the receipt with a SHA-256 plus immutable Git blob/commit identity, materialize that ledger from the recorded Git object during revalidation, and compare the newly generated detailed census receipt exactly. Reject dirty or untracked ledger sources; do not read authority data from the caller's working tree.

### CR-05: [BLOCKER] Any inapplicable dimension disables the repository-owned detector registry check globally

**File:** `scripts/maintainer/validate_evidence_census.exs:158-190`

**Issue:** The hard-coded detector registry is compared only when every taxonomy dimension is applicable. Marking one dimension inapplicable makes the condition false and disables registry verification for all remaining dimensions. A forged ledger can then replace commands and inputs for supposedly applicable detectors (for example, replace `mix test` with a no-op), adjust its internally owned candidate/baseline records, recollect, and still validate. The minimal test fixture relies on precisely this global bypass, so existing tests normalize rather than detect it.

**Fix:** Validate every applicable dimension's detector IDs, command, and inputs against the corresponding entries in `@detector_registry`, and separately require an explicit repository-owned allowlist for dimensions that may be inapplicable. Never gate the entire registry comparison on `Enum.all?(taxonomy, & &1["applicable"])`. Add a test with one inapplicable dimension and a mutated detector in another dimension.

### CR-06: [BLOCKER] Release coupling “authority” is satisfied by inert text

**File:** `scripts/maintainer/validate_live_truth.exs:514-531`

**Issue:** `exact_sha_release_coupling?/1` declares the release gate valid when four substrings occur anywhere in `release.yml`; they can remain in comments or an unreachable script after the actual gate is removed. `sole_required_check?/1` similarly uses an unanchored regex over shell source and can match commented/dead text without proving what the script applies. Consequently the derived model can report exact-SHA release coupling and sole-check enforcement while neither behavior exists.

**Fix:** Parse the release workflow and assert the executable job/step structure and expressions, and exercise the release-gate evaluator with qualifying and mismatched SHA fixtures. For branch protection, move required-check calculation into a pure structured producer/evaluator and validate its actual output/argv; at minimum anchor parsing to the live assignment and reject duplicate/comment-only matches.

## Warnings

### WR-01: [WARNING] “Repository-relative” observation locations permit parent traversal

**File:** `scripts/maintainer/evidence_census.exs:94-106,259-266`; `scripts/maintainer/validate_evidence_census.exs:203-208`

**Issue:** Observation locations reject absolute paths but accept relative traversal such as `../../outside` because `Path.type/1 == :relative` does not imply containment. The generated receipt can therefore describe evidence outside the repository while claiming repository-relative provenance. Input paths already use an expansion-and-containment check, so the two path boundaries are inconsistent.

**Fix:** Apply the same normalized containment rule used for detector inputs to observation locations (including rejection of `..` escapes and, where filesystem resolution matters, symlink escapes), and add collector/validator mutation tests for parent traversal.

---

_Reviewed: 2026-09-10T19:01:57Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
