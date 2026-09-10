---
phase: 133-evidence-charter-and-live-truth
reviewed: 2026-09-10T04:05:12Z
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
  critical: 2
  warning: 1
  info: 0
  total: 3
status: issues_found
---

# Phase 133: Code Review Report

**Reviewed:** 2026-09-10T04:05:12Z
**Depth:** standard
**Files Reviewed:** 24
**Status:** issues_found

## Summary

The strict Nightly evaluator, incident mutation boundary, job-scoped log collection, and PLT cache key are generally fail-closed, and all four shell contract suites passed. However, two evidence-authority paths can accept forged data: package claims can opt themselves out of provenance validation, and the Nightly receipt verifier does not compare most persisted receipt fields with the live run. The supported-toolchain parser also uses substring matching rather than a version boundary.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Caller-controlled `validated` flag bypasses package provenance validation

**Classification:** BLOCKER

**File:** `scripts/maintainer/validate_live_truth.exs:263-291`

**Issue:** `validate_package_claim!/2` trusts any receipt carrying `validated: true` and skips `normalize_package_receipt!/1`. That flag is an ordinary caller-controlled map field, not an opaque type or signed capability. An Elixir caller can therefore submit only `%{validated: true, install_mode: "package", install_source: path, unpacked_path: path, deps_rindle_present: false}` and receive `:ok`, even when `path` does not exist and the receipt has no `proof_origin`, provenance record, generated-app root, exit codes, lifecycle result, or package metadata. This directly bypasses the checks at lines 349-426 and lets fabricated package evidence authorize package/adoption claims.

**Fix:** Never trust a `validated` field from a claim. Always pass claim-supplied receipts through `normalize_package_receipt!/1`. If the normalized proof stored in `model.package_proof` needs an internal fast path, represent it with a private struct or validate claims against `model.package_proof` by identity rather than accepting a public boolean discriminator. Add a regression test that submits the minimal forged map above and requires rejection.

### CR-02: Receipt revalidation accepts forged jobs, timestamps, verdict provenance, incidents, and local authorities

**Classification:** BLOCKER

**File:** `scripts/ci/verify_nightly_run.sh:149-184`

**Issue:** `verify_receipt_shape` checks only broad types/statuses for most receipt fields, while `verify-receipt` compares live GitHub data only for `run_id` and the derived Dialyzer object. It never compares the receipt's `created_at` or `jobs` (names and IDs included) to `live_run`, never validates `strict_verdict.summary_job`, and never re-establishes or cryptographically binds the incident snapshots and local-authority payloads. A reproduced test using the repository's fake `gh` changed the timestamp to 2020, replaced all ten jobs with `{name:"forged",id:0}`, changed the summary job to `forged`, replaced both incident snapshots with empty arrays, and added forged authority fields; `verify-receipt` still printed `Nightly receipt valid`. This makes the advertised independent receipt revalidation unable to detect material evidence tampering.

**Fix:** Derive a canonical expected receipt projection from `live_run` and job-scoped logs, then compare every remotely reproducible field byte-for-byte (`created_at`, sorted jobs including IDs/names/status/conclusion, run identity, and strict-verdict source). For local authorities and before/after incident snapshots that cannot be reconstructed later, bind their canonical JSON into a digest created during collection and anchored in a separately authoritative artifact, or explicitly re-run/re-query those authorities during verification. At minimum, require exact object key sets and exact job names/IDs, and add a mutation matrix covering every persisted field.

## Warnings

### WR-01: Supported toolchain checks accept unrelated versions containing `1.17` and `27`

**Classification:** WARNING

**File:** `scripts/ci/verify_nightly_run.sh:112-121,158-160`

**Issue:** Collection uses unanchored Bash regexes (`=~ 1\.17` and `=~ 27`), and receipt validation uses `contains("1.17")` / `contains("27")`. Versions such as Elixir `11.17.0` or `1.170.0` and OTP `127.0` satisfy these checks, and a cache key containing those same strings also satisfies the identity assertions. The collector could therefore label a non-supported toolchain as the required 1.17/27 cell if setup output ever drifts unexpectedly; the current `unsupported_toolchain` test only covers missing version output, not near-match versions.

**Fix:** Parse and validate explicit version grammar and major/minor boundaries, for example `^1\.17(?:\.[0-9]+)*(?:-otp-[0-9]+)?$` for the resolved Elixir value and `^27(?:\.[0-9]+)*$` for OTP (adjusted to the exact setup-beam output format). Apply the same boundary rules in `verify_receipt_shape`, and add near-match rejection cases (`11.17`, `1.170`, `127`).

---

_Reviewed: 2026-09-10T04:05:12Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
