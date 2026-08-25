# Phase 132 Preservation Receipt

**Recorded:** 2026-08-25  
**Purpose:** Bind the measured-closure preservation census to the immutable Plan 01
correction and to fresh local authority outputs. This is local preservation evidence;
it does not establish the external ten-run CI-14 timing acceptance.

## Immutable Implementation Identity

- Final implementation commit: `1161029d5403088d19f4a5017daf3048ecf159aa`
  (`fix(132-01): defer generated app dependency installation`)
- Its Git parent: `1e1bd1cd030219c5059647c947cc8d1fb145a338`
  (`test(132-01): add failing generator dependency-order contract`)
- Exact name-only diff from that parent to the final implementation commit:
  `test/install_smoke/support/generated_app/workspace.ex`
- Plan 01 net correction range: `c09a628d9d3ebb92738ad76177d553d2bc1a3ce1..1161029d5403088d19f4a5017daf3048ecf159aa`
  - `test/install_smoke/generated_app_smoke_test.exs`
  - `test/install_smoke/support/generated_app/workspace.ex`

The Plan 01 TDD sequence placed the contract test and implementation in separate
commits. Consequently, the literal parent-to-final-commit diff has one source path;
the two-path net range above is the complete Plan 01 correction. No other product,
workflow, branch-protection, release, or dependency-manifest path is in that range.

## Task 1: Required-Gate and Observability Contracts

### Fresh focused commands

```sh
mix test test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs
bash scripts/ci/test_ci_summary_gate.sh
```

Both commands exited `0` on 2026-08-25. The combined ExUnit invocation reported
`31 tests, 0 failures`. The summary-gate shell contract reported `passed: 6  failed: 0`.
No count has been inferred beyond these command outputs.

### Direct contract census

- Required workflow file remains `.github/workflows/ci.yml`; its workflow name remains
  `CI`, and the aggregate job display name remains `CI Summary`.
- `CI Summary` is still the sole branch-protection required context:
  `REQUIRED_CHECKS=("CI Summary")` in `scripts/setup_branch_protection.sh`.
- Exact `ci-summary.needs` membership is `quality`, `optional-dependencies`,
  `integration`, `contract`, `proof`, `package-consumer`, `adoption-demo-unit`,
  `adoption-demo-e2e-smoke`, `adopter`, `brandbook-tokens`, and `ci-script-tests`.
- `scripts/ci/eval_ci_summary.sh` preserves `success|skipped` as the passing fork;
  every other result fails the aggregate.
- The image `package-consumer` has no `needs:` prerequisite and therefore starts
  independently; it remains included in `ci-summary.needs`.
- `adoption-demo-e2e-smoke` remains included in `ci-summary.needs` as the required
  PR-side browser proxy.
- The bounded Plan 01 correction did not touch `.github/workflows/ci.yml`, the
  evaluator, branch-protection script, or release proof. It therefore introduced no
  PR title/body/label/branch shell interpolation and did not alter the existing trusted
  concurrency input.

## Task 2: Full Preservation Authorities

Task 2 evidence is appended only after each ordered authority completes successfully.
