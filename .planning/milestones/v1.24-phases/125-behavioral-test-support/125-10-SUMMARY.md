---
phase: 125-behavioral-test-support
plan: "10"
subsystem: testing
tags: [elixir, ci, async-isolation, generated-app, proof]
requires:
  - phase: 125-09
    provides: Explicit Proof coverage for the four docs-parity domains
provides:
  - Immutable fail-fast async-isolation evidence receipt
  - Exact-head CI and open issue #42 narrowing disposition
affects: [issue-42, ci-summary, phase-125]
tech-stack:
  added: []
  patterns: [fail-fast finite evidence, exact-head CI authority, behavior-backed generated outcomes]
key-files:
  created: [.planning/phases/125-behavioral-test-support/125-ASYNC-ISOLATION-EVIDENCE.md, .planning/phases/125-behavioral-test-support/125-10-SUMMARY.md]
  modified: [RUNNING.md, test/install_smoke/phoenix_tus_truth_parity_test.exs]
key-decisions:
  - "Keep issue #42 open because the sole authorized matrix stopped at 1/25, despite green focused and supported CI evidence."
  - "Use one stable tus outcome contract in both compiled parity and real generated-consumer assertions."
requirements-completed: [TEST-01, TEST-02, TEST-03, TEST-04, SAFE-01]
duration: 45min
completed: 2026-08-23
status: complete
---

# Phase 125 Plan 10: Final Behavioral Evidence Summary

**Fail-fast async-isolation evidence, behavior-backed generated tus parity, and exact-head CI authority preserve the open narrowing disposition for issue #42.**

## Accomplishments

- Recorded the single authorized matrix attempt: it stopped at seed 0 after 1/25 processes because the Credo inventory observed a new helper complexity identity; no seed or matrix was retried.
- Reduced that helper below the policy threshold, passed focused Credo and 100 causal isolation iterations, and retained the receipt as `local_failure` rather than masking it.
- Passed strict compile, generated/docs/isolation focused suites, packed image smoke, SAFE-01, `mix ci`, hygiene, and supported CI before the final metadata head.
- Kept #42 open with a sanitized comment containing only the allowed failure fields and final-head/PR authority.
- Resolved the final TEST-02 review warning by linking the stable tus outcome contract to both compiled parity and a real generated MinIO tus outcome; re-review is clean.

## Task Commits

1. **Task 1: Run the fixed 25-seed matrix once and commit its pass-or-failure receipt** — `c72e1d4` (docs)
2. **Task 2: Obtain exact-head supported authority and close or narrow issue #42** — `88cd6e7`, `50b0f60`, `0819388`, `f757278`, `96a2aeb` (test/docs)

## Verification

- `MIX_ENV=test mix compile --force --warnings-as-errors` — pass.
- Focused generated/docs/isolation suite — 55 tests, 0 failures.
- Causal isolation proof — 100 iterations, pass.
- `bash scripts/install_smoke.sh image`, `bash scripts/maintainer/refactor_contract.sh`, `mix ci`, and `bash scripts/maintainer/repo_hygiene_check.sh --ci` — pass.
- `bash scripts/maintainer/check_docs_links.sh` and focused docs/refactor contracts — 16 tests, 0 failures.
- Review-fix focused suite — 18 tests, 0 failures; packed tus proof — 18 tests, 0 failures; SAFE-01 — 92 tests, 0 failures.
- Prior exact-head CI run `32624000242` for `0819388da9bb26bbddd2b6c1ca53d8a488492acd` — success, including Elixir 1.17/OTP 27 Quality and CI Summary.

## Decisions Made

- The incomplete one-shot local receipt is conclusive narrowing evidence, not a reason to retry or close issue #42.
- Adopter-facing RUNNING guidance stays planning-neutral; the Phase-specific report path stays in maintainer planning evidence.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 1 - Quality] Removed trailing whitespace from the Phase pattern map** — `50b0f60`.
2. **[Rule 1 - Bug] Removed planning artifacts from adopter-facing RUNNING guidance after the Proof link-hygiene gate failed** — `0819388`.
3. **[Rule 1 - Test quality] Connected tus parity assertions to a real generated-consumer outcome through a stable contract** — `f757278`.

## Issues Encountered

The first PR CI head failed Proof because RUNNING exposed Phase/.planning paths. The focused documentation repair passed and the superseding CI run was green. The local matrix remains 1/25 and therefore #42 is intentionally open.

## Self-Check: PASSED

The evidence receipt, review report, and all task commits exist. No production, schema, dependency, Admin, or release-topology surface changed.
