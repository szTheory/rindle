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

## Final Automation Candidate Re-census

**Preserved automation candidate SHA:**
`5001e2a05f378c4fb3b0db9abefc316f8652d3c2`

This is the immutable code-bearing subject for Plan 05. Commits between this SHA and
the measured PR head may change only `.planning/**`; the unattended controller
enforces that boundary before publication or sampling.

The final re-census includes the Phase 132 automation controller and its forward
policy, plus automation defects found by the census and the first fail-closed live
attempt:

- discovered live runs are resumed from persisted state without triggering a
  duplicate sample;
- Phoenix generation passes `--no-install`, preserving the post-patch `deps.get`
  authority while suppressing the Phoenix 1.8.9 interactive install prompt.
- jq arguments avoid the reserved `label` identifier used by the CI runner's jq
  version;
- after a fast-forward publication, the controller waits for the synchronize-triggered
  PR run set to become terminal and stable before applying a sampling label.
- workflow-run discovery uses one branch-filtered 100-run API page instead of
  paginating all history, and shared API reads back off across rate-limit resets
  without consuming a sample or sequence.

The isolation-upgrade smoke command now uses the raising command boundary, so a
substantive generated-app failure reports its captured stage and output instead of
being masked by a later missing-receipt error.

### Final successful authorities

All commands below ran after the final source edit on 2026-08-25 and exited `0`:

1. `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_132_generator_contract --seed 0`
   - `1 test, 0 failures` (`32 excluded`).
2. `mix test test/install_smoke/ci_timing_automation_test.exs test/install_smoke/automation_first_contract_test.exs test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs --seed 0`
   - `40 tests, 0 failures`.
3. `bash scripts/ci/test_ci_summary_gate.sh`
   - `passed: 6  failed: 0`.
4. `mix quality_signals`
   - Credo/public-contract/complexity passed; Doctor reported 79 passed modules and
     100% doc/moduledoc/spec coverage; the contract suite reported `93 tests, 0 failures`.
5. `bash scripts/maintainer/refactor_contract.sh`
   - 150 files compiled, no compile-connected cycles, `93 tests, 0 failures`.
6. `./scripts/maintainer/automation_first_contract.sh`
   - The Phase 132 automation-first contract passed with no manual-only acceptance.
7. `./scripts/maintainer/repo_hygiene_check.sh --ci`
   - `9 PASS, 0 WARN, 0 BLOCK`.
8. `mix coveralls.multiple --type local --type json`
   - `3 doctests, 1393 tests, 0 failures, 4 skipped (86 excluded)` and a non-empty
     `cover/excoveralls.json`.
9. `bash scripts/install_smoke.sh image`
   - The packed image consumer completed the default, public-compatibility, and
     isolation-upgrade generated applications with `22 tests, 0 failures` in 200.0s.

### Final coverage arithmetic

The final `cover/excoveralls.json` contains `5149` positive covered entries among
`6269` non-null relevant entries:

- exact percentage: `5149 / 6269 * 100 = 82.13431169245494%`;
- rounded receipt value: `82.1343%`;
- inclusive threshold proof: `5149 * 10000 >= 6269 * 8213` is `true`.

No percentage-only test, required-check relaxation, workflow topology change,
dependency change, public API change, schema/migration change, telemetry/error-shape
change, or human verification/UAT exception was introduced.

## Gap-Closure Final Preservation Census

**Preserved gap-closure subject:**
`0696c49896f34f8747a38fbe6ac08fa2c3355b05`
(`docs(132-06): finalize apt remediation evidence`). This is the full `HEAD` after
Plan 132-06; the final code-bearing remediation remains the bounded apt helper and
its process-isolated contract, committed before this evidence-only subject.

### Subject and bounded-diff census

The Plan 132-05 measured head is
`24c17783bbc080a085e398164450b7c3f475781e`. Its exact name-only range through the
preserved subject is:

```text
.planning/REQUIREMENTS.md
.planning/ROADMAP.md
.planning/STATE.md
.planning/phases/132-measured-closure/132-05-SUMMARY.md
.planning/phases/132-measured-closure/132-06-PLAN.md
.planning/phases/132-measured-closure/132-06-SUMMARY.md
.planning/phases/132-measured-closure/132-07-PLAN.md
.planning/phases/132-measured-closure/132-08-PLAN.md
.planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md
.planning/phases/132-measured-closure/132-VALIDATION.md
.planning/phases/132-measured-closure/132-VERIFICATION.md
scripts/ci/install_apt_packages.sh
test/install_smoke/ci_cache_hygiene_test.exs
```

The only non-planning paths are the approved remediation surfaces:
`scripts/ci/install_apt_packages.sh` and
`test/install_smoke/ci_cache_hygiene_test.exs`. The planning paths are the bounded
timing/evidence, requirements, and execution artifacts for this phase. The range
contains no workflow/topology, Admin, public API, schema/migration,
telemetry/error-shape, dependency/lockfile, or release-proof path.

### Ordered final authorities

All following commands ran once, in this order, after the final source edit and
before any Plan 132-08 live sample; each exited `0`:

1. `mix test test/install_smoke/ci_cache_hygiene_test.exs test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs --seed 0`
   - `49 tests, 0 failures`.
2. `bash scripts/ci/test_ci_summary_gate.sh`
   - `passed: 6  failed: 0`.
3. `mix quality_signals`
   - Credo/public-contract/complexity passed; Doctor reported `79` passed modules,
     `0` failed modules, and `100.0%` total doc, moduledoc, and spec coverage;
     its contract suite reported `93 tests, 0 failures`.
4. `bash scripts/maintainer/refactor_contract.sh`
   - compiled `150` files, found no compile-connected cycles, and reported
     `93 tests, 0 failures`.
5. `./scripts/maintainer/automation_first_contract.sh`
   - passed for the Phase 132 planning directory with no manual-only acceptance.
6. `./scripts/maintainer/repo_hygiene_check.sh --ci`
   - `9 PASS, 0 WARN, 0 BLOCK`.
7. `mix coveralls.multiple --type local --type json && test -s cover/excoveralls.json`
   - the single authoritative coverage invocation exited `0` and left a non-empty
     JSON artifact.
8. `bash scripts/install_smoke.sh image`
   - the complete packed image consumer exited `0`, proving package build/unpack
     provenance, generated-app dependency/compile order, host and Rindle migrations,
     boot, lifecycle, and cleanup.

### Authoritative COV-05 arithmetic

The fresh non-empty `cover/excoveralls.json` has `5149` positive covered entries
among `6269` non-null relevant entries. Therefore:

- exact percentage: `5149 / 6269 * 100 = 82.13431169245494%`;
- receipt value: `82.1343%`;
- inclusive D-07 comparison: `5149 * 10000 >= 6269 * 8213` is `true`.

This is one coverage run, not a percentage-only test. It clears the inclusive
`82.13%` floor, including the SAFE-02 adjacency case where equality at the floor
would pass.

### CI and prohibited-surface backstop

Focused lane-split/observability and summary-gate authorities retain workflow name
`CI`, sole required check `CI Summary`, and the exact `ci-summary.needs` set:
`quality`, `optional-dependencies`, `integration`, `contract`, `proof`,
`package-consumer`, `adoption-demo-unit`, `adoption-demo-e2e-smoke`, `adopter`,
`brandbook-tokens`, and `ci-script-tests`. The evaluator still treats
`success|skipped` as passing. The `package-consumer` job remains independently
starting and the image consumer remains part of the required aggregate.

The helper correction changes no `.github/workflows/ci.yml` topology or job proof.
The bounded diff census above confirms no Admin, product/public API,
schema/migration, telemetry/error, dependency/lockfile, or release-proof drift is
being described as behavior-preserving. The equality backstop for the later timing
receipt remains inclusive: a `480`-second median or `600`-second nearest-rank p95
will pass when Plan 132-08 samples this preserved subject.

## Recovery topology final preservation census

**Correction SHA:** `11bfee5d819318a090d2c2bf065ebc3a26d0ef7d`
(`feat(132-09): remove six critical-path scheduling edges`)

**Preserved subject SHA:** `5add06528a45cc927079563138e71dd8459fe5d2`
(`docs(132-09): complete topology recovery plan`)

The correction is an ancestor of the preserved subject. The exact name/status range
from the parent of the topology correction through the preserved subject is:

```text
M .github/workflows/ci.yml
A test/fixtures/ci_timing/phase_132_topology_projection.json
M test/install_smoke/ci_lane_split_test.exs
M .planning/ROADMAP.md
M .planning/STATE.md
A .planning/phases/132-measured-closure/132-09-SUMMARY.md
```

The only new or modified non-planning paths are exactly the D-08/D-09 authorities:
`.github/workflows/ci.yml`,
`test/install_smoke/ci_lane_split_test.exs`, and
`test/fixtures/ci_timing/phase_132_topology_projection.json`. The exact workflow
patch deletes only these three declarations:

```diff
-    needs: [quality, optional-dependencies]
```

They are removed only from `integration`, `contract`, and `adoption-demo-e2e-smoke`.
No other executable workflow line changes. The bounded census contains no Admin,
product/public API, schema/migration, telemetry/error, dependency/lockfile,
release-proof, timing-controller, or rerun-policy surface.

### Ordered local authorities (2026-08-26)

All commands below ran after the final topology edit and before the no-publish
preflight. Each completed successfully:

1. `mix test test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs test/install_smoke/ci_timing_automation_test.exs --seed 0`
   - `47 tests, 0 failures`.
2. `bash scripts/ci/test_ci_summary_gate.sh`
   - `passed: 6  failed: 0`.
3. `mix quality_signals`
   - Credo/public-contract/complexity passed; Doctor reported `79` passed modules
     and `100%` doc/moduledoc/spec coverage; contract suite: `96 tests, 0 failures`.
4. `bash scripts/maintainer/refactor_contract.sh`
   - compiled `150` files, found no cycles, and reported `96 tests, 0 failures`.
5. `./scripts/maintainer/automation_first_contract.sh`
   - passed for the Phase 132 planning directory.
6. `./scripts/maintainer/repo_hygiene_check.sh --ci`
   - `9 PASS, 0 WARN, 0 BLOCK`.
7. `mix coveralls.multiple --type local --type json`
   - exactly one authoritative invocation exited `0` and produced non-empty
     `cover/excoveralls.json`.
8. `bash scripts/install_smoke.sh image`
   - packed image consumer: `22 tests, 0 failures` in `162.3s`.

### Canonical recovery coverage census

The JSON line below was generated directly from `cover/excoveralls.json` by
fail-closed parsing of `source_files[].coverage[]`: source files must be non-empty,
each coverage vector must be an array, and every non-null entry must be a
non-negative integer. Non-null entries are relevant; positive entries are covered.
The parser rejected a zero denominator and enforced the inclusive D-07 comparison
`covered * 10000 >= relevant * 8213`.

RECOVERY_COVERAGE_CENSUS_V1_BEGIN
{"covered":5149,"passes":true,"ratio":0.8213431169245494,"relevant":6269,"threshold_basis_points":8213}
RECOVERY_COVERAGE_CENSUS_V1_END

### No-publish sampler preflight

The existing controller ran only in `preflight --no-publish` mode with immutable
inputs: repository `szTheory/rindle`, PR `96`, workflow `ci.yml`, summary job
`CI Summary`, label `ci-timing-sample`, `10` samples, at most `2` sequences,
inclusive `480`/`600` thresholds, correction SHA
`11bfee5d819318a090d2c2bf065ebc3a26d0ef7d`, and preserved subject SHA
`5add06528a45cc927079563138e71dd8459fe5d2`.

It failed closed (exit `1`) with:

```text
[ci-timing] ERROR: PR head f3476633fdc459779a937c5dc3c7234379bd8ce3 does not equal local HEAD 5add06528a45cc927079563138e71dd8459fe5d2 and publication is disabled
```

This is a required publication-path blocker for Plan 132-11, not authorization to
push, label, trigger, rerun, or sample. Before/after GitHub workflow-run listings
were byte-identical; the owned label was absent before and after; and
`.gsd/ci-timing/phase-132-recovery-preflight` was absent before and after. No live
controller lock or owned label remains.

## Historical post-repair preservation census (Plan 132-15, 2026-08-27)

**Prior preserved subject:** `7f025dfdf55d612861610a10773d86761a374277`
**Controller correction boundary:** `1671cdde1c42231a8a958c8f2771a24edb8b444e`
**Formatter correction boundary:** `214e56c5fc16b02a44280eee1567b8087358ffd5`
**Repair and preserved subject:** `73e2c334f17894c14918838ee69e3507b5e42f09`

The anchors above were derived from Git, not plan prose. The controller boundary is
the completed Plan 132-12 boundary immediately before `541b992`; it contains both
`9e70f4b` and `5a61ab9`, plus the Plan 132-12 summary and tracking commits. The
formatter boundary is Plan 132-13's tracking commit `214e56c`, with `541b992` and
the immutable Plan 132-13 summary in its ancestry. Git confirms all three stage
ranges are strict ancestor ranges. The repair and preserved subject are identical
at the completed Plan 132-14 HEAD.

HISTORICAL_PRESERVATION_TRANSITION_V2_BEGIN
{"schema_version":2,"repo":"szTheory/rindle","pr":96,"prior_preserved_sha":"7f025dfdf55d612861610a10773d86761a374277","controller_correction_sha":"1671cdde1c42231a8a958c8f2771a24edb8b444e","formatter_correction_sha":"214e56c5fc16b02a44280eee1567b8087358ffd5","repair_sha":"73e2c334f17894c14918838ee69e3507b5e42f09","preserved_subject_sha":"73e2c334f17894c14918838ee69e3507b5e42f09","stages":[{"id":"plan-132-12","from_sha":"7f025dfdf55d612861610a10773d86761a374277","to_sha":"1671cdde1c42231a8a958c8f2771a24edb8b444e","planning":[{"status":"M","path":".planning/REQUIREMENTS.md"},{"status":"M","path":".planning/ROADMAP.md"},{"status":"M","path":".planning/STATE.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-11-SUMMARY.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-12-PLAN.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-12-SUMMARY.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-13-PLAN.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-14-PLAN.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-15-PLAN.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-REVIEW.md"},{"status":"M","path":".planning/phases/132-measured-closure/132-VALIDATION.md"},{"status":"M","path":".planning/phases/132-measured-closure/132-VERIFICATION.md"},{"status":"M","path":".planning/phases/132-measured-closure/COVERAGE.md"}],"non_planning":[{"status":"M","path":"scripts/ci/collect_pr_timing_receipt.sh","blob_oid":"dc6ea5fbd4c33b3addba8430cf2758dedae7452f"},{"status":"M","path":"test/install_smoke/ci_timing_automation_test.exs","blob_oid":"5ca85afef8c0079bb6db22a7e4ff87b5435f2cd5"}]},{"id":"plan-132-13","from_sha":"1671cdde1c42231a8a958c8f2771a24edb8b444e","to_sha":"214e56c5fc16b02a44280eee1567b8087358ffd5","planning":[{"status":"M","path":".planning/ROADMAP.md"},{"status":"M","path":".planning/STATE.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-13-SUMMARY.md"},{"status":"M","path":".planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md"}],"non_planning":[{"status":"M","path":"test/install_smoke/ci_lane_split_test.exs","blob_oid":"a641d9a84f545e7d37fcb4b8a8bdf143d02b7754"}]},{"id":"plan-132-14-repair","from_sha":"214e56c5fc16b02a44280eee1567b8087358ffd5","to_sha":"73e2c334f17894c14918838ee69e3507b5e42f09","planning":[{"status":"M","path":".planning/ROADMAP.md"},{"status":"M","path":".planning/phases/132-measured-closure/132-14-PLAN.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-14-SUMMARY.md"},{"status":"M","path":".planning/phases/132-measured-closure/132-15-PLAN.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-16-PLAN.md"}],"non_planning":[{"status":"M","path":"scripts/ci/collect_pr_timing_receipt.sh","blob_oid":"ae86eb515fe1fa96f5f1a0e978fdd624a94fd1c1"},{"status":"M","path":"test/install_smoke/ci_timing_automation_test.exs","blob_oid":"ce7908135e4e0cdb676690a28e7a9b433feffd9c"}]}]}
HISTORICAL_PRESERVATION_TRANSITION_V2_END

The manifest is a full, rename-disabled, Git name/status census. Every entry is
explicitly partitioned into planning and non-planning paths; every mutable target
in a non-planning partition records its target-tree blob OID. No other executable
path is attributed to a stage.

### Preservation authorities and structural coverage result

After recording the manifest, all required authorities passed in this order:

1. `mix format --check-formatted`.
2. Focused timing-controller, lane-split, and observability tests: `52 tests, 0 failures`.
3. `bash scripts/ci/test_ci_summary_gate.sh`: `passed: 6  failed: 0`.
4. `mix quality_signals` and `bash scripts/maintainer/refactor_contract.sh`.
5. `./scripts/maintainer/automation_first_contract.sh` and
   `./scripts/maintainer/repo_hygiene_check.sh --ci`.
6. One authoritative `mix coveralls.multiple --type local --type json` invocation.
7. `bash scripts/install_smoke.sh image`, the packed image consumer.
8. `git diff --check`.

The fresh nonempty ExCoveralls artifact was structurally parsed after that sole
coverage invocation: every `source_files[].coverage` value was an array and every
entry was either `null` or a non-negative integer. Its positive relevant-line
denominator was `6269`, covered lines were `5149`, and inclusive integer arithmetic
confirmed `5149 * 10000 >= 6269 * 8213`. This preserves the 82.13% floor without
adding a percentage-only test.

Git's post-subject census reports no non-planning path after
`73e2c334f17894c14918838ee69e3507b5e42f09`: the receipt itself is planning
evidence only. Therefore there is no workflow/required-membership, public API,
schema/migration, telemetry/error, dependency/lockfile, Admin, or release-proof
drift in the repaired subject.

### Mutation-free strict-ancestor preflight

The controller reparsed and independently reproduced this same manifest using
repository `szTheory/rindle`, PR `96`, `ci.yml`, `CI Summary`, label
`ci-timing-sample`, exactly ten samples, two sequences, and inclusive `480`/`600`
limits. It received correction SHA
`1671cdde1c42231a8a958c8f2771a24edb8b444e` and preserved SHA
`73e2c334f17894c14918838ee69e3507b5e42f09`, then exited zero in
`preflight --no-publish` mode. The remote PR head
`7f025dfdf55d612861610a10773d86761a374277` was an accepted strict ancestor of the
local repaired subject.

Before and after snapshots were byte-identical for PR head and labels, the exact-head
`ci.yml` workflow-run API response, receipt hash, and current-marker counts. The
requested controller state directory and lock were absent both before and after. No
publication, label trigger, rerun, state creation, or sample was performed. CI-14
remains open for the separately authorized terminal API-backed exact-ten receipt.

## Post-controller-fix preservation census (Plan 132-17, 2026-08-27)

This active census supersedes only the historical manifest markers above. It preserves
the completed Plan 132-15 prose and JSON as historical evidence while recording the
actual post-controller-fix source chronology from Git.

**Prior preserved subject:** `7f025dfdf55d612861610a10773d86761a374277`
**Controller correction boundary:** `1671cdde1c42231a8a958c8f2771a24edb8b444e`
**Formatter correction boundary:** `214e56c5fc16b02a44280eee1567b8087358ffd5`
**Repair and preserved source subject:** `15336d4cc8053aa90788c62377096081c5b07f21`

PRESERVATION_TRANSITION_V2_BEGIN
{"schema_version":2,"repo":"szTheory/rindle","pr":96,"prior_preserved_sha":"7f025dfdf55d612861610a10773d86761a374277","controller_correction_sha":"1671cdde1c42231a8a958c8f2771a24edb8b444e","formatter_correction_sha":"214e56c5fc16b02a44280eee1567b8087358ffd5","repair_sha":"15336d4cc8053aa90788c62377096081c5b07f21","preserved_subject_sha":"15336d4cc8053aa90788c62377096081c5b07f21","stages":[{"id":"plan-132-12","from_sha":"7f025dfdf55d612861610a10773d86761a374277","to_sha":"1671cdde1c42231a8a958c8f2771a24edb8b444e","planning":[{"status":"M","path":".planning/REQUIREMENTS.md"},{"status":"M","path":".planning/ROADMAP.md"},{"status":"M","path":".planning/STATE.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-11-SUMMARY.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-12-PLAN.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-12-SUMMARY.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-13-PLAN.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-14-PLAN.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-15-PLAN.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-REVIEW.md"},{"status":"M","path":".planning/phases/132-measured-closure/132-VALIDATION.md"},{"status":"M","path":".planning/phases/132-measured-closure/132-VERIFICATION.md"},{"status":"M","path":".planning/phases/132-measured-closure/COVERAGE.md"}],"non_planning":[{"status":"M","path":"scripts/ci/collect_pr_timing_receipt.sh","blob_oid":"dc6ea5fbd4c33b3addba8430cf2758dedae7452f"},{"status":"M","path":"test/install_smoke/ci_timing_automation_test.exs","blob_oid":"5ca85afef8c0079bb6db22a7e4ff87b5435f2cd5"}]},{"id":"plan-132-13","from_sha":"1671cdde1c42231a8a958c8f2771a24edb8b444e","to_sha":"214e56c5fc16b02a44280eee1567b8087358ffd5","planning":[{"status":"M","path":".planning/ROADMAP.md"},{"status":"M","path":".planning/STATE.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-13-SUMMARY.md"},{"status":"M","path":".planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md"}],"non_planning":[{"status":"M","path":"test/install_smoke/ci_lane_split_test.exs","blob_oid":"a641d9a84f545e7d37fcb4b8a8bdf143d02b7754"}]},{"id":"plan-132-14-repair","from_sha":"214e56c5fc16b02a44280eee1567b8087358ffd5","to_sha":"15336d4cc8053aa90788c62377096081c5b07f21","planning":[{"status":"M","path":".planning/REQUIREMENTS.md"},{"status":"M","path":".planning/ROADMAP.md"},{"status":"M","path":".planning/phases/132-measured-closure/132-14-PLAN.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-14-SUMMARY.md"},{"status":"M","path":".planning/phases/132-measured-closure/132-15-PLAN.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-15-SUMMARY.md"},{"status":"A","path":".planning/phases/132-measured-closure/132-16-PLAN.md"},{"status":"M","path":".planning/phases/132-measured-closure/132-PRESERVATION-RECEIPT.md"}],"non_planning":[{"status":"M","path":"scripts/ci/collect_pr_timing_receipt.sh","blob_oid":"3bb0de6f75660870614cbc3ad3f5f6e1293b262e"},{"status":"M","path":"test/install_smoke/ci_timing_automation_test.exs","blob_oid":"cda7a618255f0030f450c2aa03e043ad01a24f12"}]}]}
PRESERVATION_TRANSITION_V2_END

The active schema-v2 manifest is a rename-disabled, full Git name/status census:
for every stage, its declared planning/non-planning union equals the Git delta and
every non-planning target blob equals its `to_sha` tree. Stage three is deliberately
the cumulative `214e56c..15336d4` delta required by the shipped validator.

### Plan 132-16 preserved-tail repair attribution

The cumulative stage must not rewrite the source history as Plan 132-15 work. Git
independently reproduces the strict `73e2c33..15336d4` tail as
`plan-132-16-preserved-tail-repair`:

| Order | Commit | Attribution |
| --- | --- | --- |
| 1 | `99c9fd6914c4e0af8b103fbe8c1356d84ade6dbc` | Plan 132-15 planning receipt |
| 2 | `c27413d34afe4d315468eeadf340db9b4e93ec43` | Plan 132-15 planning summary |
| 3 | `f488a7e7d30afcf0fc7e2c4e167171c29edf5041` | Plan 132-15 planning tracking |
| 4 | `74d09e863be08cd57898fab8933ef5069b55a147` | Plan 132-15 planning closeout |
| 5 | `15336d4cc8053aa90788c62377096081c5b07f21` | Plan 132-16 source controller repair |

Its exact rename-disabled name/status census is `M .planning/REQUIREMENTS.md`,
`M .planning/ROADMAP.md`, `A .planning/phases/132-measured-closure/132-15-SUMMARY.md`,
`M .planning/phases/132-measured-closure/132-PRESERVATION-RECEIPT.md`,
`M scripts/ci/collect_pr_timing_receipt.sh`, and
`M test/install_smoke/ci_timing_automation_test.exs`. The final non-planning target
blobs are `scripts/ci/collect_pr_timing_receipt.sh` =
`3bb0de6f75660870614cbc3ad3f5f6e1293b262e` and
`test/install_smoke/ci_timing_automation_test.exs` =
`cda7a618255f0030f450c2aa03e043ad01a24f12` in tree `15336d4`.

### Fresh preservation authorities and no-publish preflight

The following Plan 132-17 authorities are recorded after their fresh execution:

1. `mix format --check-formatted` passed.
2. `mix test test/install_smoke/ci_timing_automation_test.exs --seed 0` passed
   with exactly `18 tests, 0 failures`; the lane-split and observability suite
   passed with `34 tests, 0 failures`.
3. `bash scripts/ci/test_ci_summary_gate.sh`, `mix quality_signals`,
   `bash scripts/maintainer/refactor_contract.sh`,
   `./scripts/maintainer/automation_first_contract.sh`, and
   `./scripts/maintainer/repo_hygiene_check.sh --ci` all passed.
4. One authoritative `mix coveralls.multiple --type local --type json` invocation
   passed and emitted a nonempty artifact. Structural parsing accepted only
   nonempty source files, array coverage vectors, and non-null non-negative integer
   entries; it found `5149` covered of `6269` relevant lines. The denominator is
   positive and `5149 * 10000 >= 6269 * 8213`, so the inclusive 82.13% floor passes.
5. `bash scripts/install_smoke.sh image` passed against the packed image consumer.
   `git diff --check` passed, and the prohibited-surface census remains planning-only
   after `15336d4`: no Admin, public API, schema/migration, telemetry/error,
   dependency/lockfile, workflow, or release-proof path appears.

The controller then reparsed the active manifest and the repository independently
reproduced each stage. `preflight --no-publish` passed for `szTheory/rindle#96`
with `ci.yml`, `CI Summary`, ten samples, at most two sequences, inclusive `480`/
`600` limits, correction `1671cdd`, and preserved subject `15336d4`. The open draft
PR remains at `7f025dfdf55d612861610a10773d86761a374277` with no labels. Before/after
snapshots were equal for PR metadata, the `ci.yml` pull-request workflow API
population, receipt hash, and current-marker count (`0`); the requested state
directory and lock were absent both before and after. No publication, label, rerun,
sample, durable controller ownership, or timing receipt mutation occurred.

COV-05 and SAFE-02 are freshly preserved by these exact authorities. CI-14 remains
open and is reserved for Plan 132-18's terminal API-backed exact-ten receipt.
