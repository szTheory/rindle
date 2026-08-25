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

The following authorities ran in this order on 2026-08-25 and each exited `0`:

1. `mix quality_signals`
   - Credo/public-contract/complexity aggregate passed.
   - Doctor reported 79 passed modules, 0 failed modules, and 100.0% total doc,
     moduledoc, and spec coverage.
   - The included contract invocation reported `93 tests, 0 failures`.
2. `bash scripts/maintainer/refactor_contract.sh`
   - Compile completed for 150 files, no compile-connected cycles were found, and
     the contract suite reported `93 tests, 0 failures`.
3. `mix coveralls.multiple --type local --type json`
   - This was the single authoritative coverage invocation for this receipt.
   - It exited `0` and produced non-empty `cover/excoveralls.json`.
   - The run emitted the repository's existing test-load-filter warning for support
     files; it did not change the command result.
4. `bash scripts/install_smoke.sh image`
   - The packed clean-room image consumer exited `0` after package build/unpack and
     the generated-app MinIO profile proof. Its live output showed the unpacked
     `rindle-0.4.4` package and the included MinIO ExUnit profile.

### Authoritative coverage arithmetic

From `cover/excoveralls.json`, treating non-null entries as relevant lines and
positive entries as covered lines:

- covered lines: `5149`
- relevant lines: `6269`
- exact percentage: `5149 / 6269 * 100 = 82.1343%` (rounded to four decimals)
- inclusive D-07 check: `5149 * 10000 >= 6269 * 8213` is `true`

This clears the `82.13%` threshold without adding a percentage-only test. The
coverage artifact came from the one recorded authoritative command above; no second
coverage suite was run.

### Packed-consumer result

The successful `image` authority used the built and unpacked package, then exercised
the existing generated Phoenix application path. Its profile retains the tracer's
package provenance, post-patch dependency fetch and compile, explicit host plus
Rindle migrations, compiled boot/report boundary, MinIO-backed presigned-PUT
lifecycle, and cleanup assertions. The repository script invokes the generated-app
suite with `--include minio`; this receipt records its command exit rather than
inventing an additional test total from partially displayed nested output.

### Bounded prohibited-surface review

The complete Plan 01 net correction range contains only:

- `test/install_smoke/generated_app_smoke_test.exs`
- `test/install_smoke/support/generated_app/workspace.ex`

Review of that range found no drift in the prohibited surfaces:

| Surface | Finding |
| --- | --- |
| Admin | No Admin path changed. |
| Public functions | No `lib/` path changed; no public API changed. |
| Schema or migration | No schema or migration path changed. |
| Telemetry or error shape | No telemetry/error path changed. |
| Dependencies or lockfiles | No manifest or lockfile changed. |
| CI workflow | No `.github/workflows` path changed; required topology and evaluator are separately proven above. |
| Release proof | No release workflow, package metadata, or release-runbook path changed. |

The correction remains limited to removing Phoenix's pre-patch `--install` argv
entry and locking that ordering through its focused test. It does not characterize
unrelated product or CI drift as behavior-preserving.
