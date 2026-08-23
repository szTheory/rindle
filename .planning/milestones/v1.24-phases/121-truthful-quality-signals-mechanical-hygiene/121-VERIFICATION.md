---
phase: 121-truthful-quality-signals-mechanical-hygiene
verified: 2026-08-22T22:55:24Z
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 121: Truthful Quality Signals & Mechanical Hygiene Verification Report

**Phase Goal:** Maintainers receive truthful, blocking quality feedback for deterministic regressions and can make every later refactor against an explicit behavior-preservation contract.
**Verified:** 2026-08-22T22:55:24Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A deterministic public-contract or documentation-parity regression fails a blocking CI result, while AV-dependent checks visibly declare and prove prerequisites. | ✓ VERIFIED | `quality` has non-advisory Credo, measured Doctor, and focused AV steps; the latter follows both `Install libvips` and `Install FFmpeg`. `contract` has non-advisory `mix test --only contract` and SAFE-01 steps. `quality_signal_policy_test.exs` parses the workflow and asserts the commands, canonical lint condition, ordering, and lack of failure masking; 50 focused policy/contract tests and the 7 focused AV tests passed. |
| 2 | The documentation doctor reports measured public module, function, and spec coverage meeting the ratchet, and fails on measured regression. | ✓ VERIFIED | `.doctor.exs` retains the 100/100/100/95/95 ratchet and explicit internal ownership exclusions. `doctor_thresholds_test.exs` calls `Doctor.CLI.generate_module_report_list/1` and `Doctor.ReportUtils` against compiled `lib/` reports rather than only reading threshold literals. Fresh `MIX_ENV=dev mix doctor --full --raise` passed: 68 modules, 0 failed, 100.0% docs/moduledocs/specs. |
| 3 | Credo blocks actionable warnings, complexity/nesting, and public docs/spec drift while retaining low-value style as advisory. | ✓ VERIFIED | `.credo.exs` defines separate `blocking_warnings`, `public_contract`, and `complexity_inventory` profiles. `credo_quality.sh` runs all three fail-fast and compares normalized `{check,file,trigger,observed_metric,count}` identities with the 33-entry/37-occurrence baseline. Its policy test injects an arbitrary test warning and baseline additions, deletions, changed identities, and count drift; all focused tests passed. CI keeps full-tree strict style visible with `continue-on-error: true`. Fresh aggregate passed. |
| 4 | Mechanically proven residue and recurrence-prone root lint outputs are removed or narrowly ignored without deleting unique evidence. | ✓ VERIFIED | `gsd_cleanup.sh` has a finite nine-name allowlist, checks `git ls-files --error-unmatch` before deletion, uses only non-recursive `rm -f`, and has no broad `rindle-*`/recursive cleanup path. `repository_residue_test.exs` creates an isolated Git repo proving tracked files survive, the eight untracked matches are removed, and `rindle-0.1.0-dev/sentinel.txt` survives. Canonical v1.8 audit remains non-empty with SHA-256 `aa579304462e5ed5ee44c7551856cf7ff7e9905aab5745133d72a2dc5de58b76`. |
| 5 | Every subsequent refactor slice has a runnable regression contract proving unchanged public signatures, schema/migration behavior, telemetry names/metadata, error shapes, and supported CI/release invariants. | ✓ VERIFIED | Executable `refactor_contract.sh` root-resolves then `exec`s one foreground `mix test --include contract --seed 0` invocation over explicit API, schema, migration, telemetry, error, CI-lane, and release-guard suites. Its structural test rejects empty selection, planning coupling, background/masking constructs, and missing domain membership. Fresh runner passed 86 tests. |

**Score:** 5/5 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `scripts/maintainer/refactor_contract.sh` | Fail-fast SAFE-01 entry point | ✓ VERIFIED | Executable, substantive 16-line strict runner; invoked by Mix alias and CI Contract job. |
| `test/install_smoke/refactor_contract_test.exs` | SAFE-01 structural lock | ✓ VERIFIED | 79-line behavioral structural test; fresh pass. |
| `.doctor.exs` | Curated public Doctor policy | ✓ VERIFIED | Explicit exclusions and unchanged ratchet drive live Doctor command. |
| `test/rindle/doctor_thresholds_test.exs` | Measured Doctor ratchet test | ✓ VERIFIED | Uses Doctor report APIs and compiled module reports; fresh pass. |
| `scripts/maintainer/credo_quality.sh` | Fail-fast Credo aggregate | ✓ VERIFIED | Three named Credo passes plus fail-closed baseline normalization/comparison; fresh pass. |
| `scripts/maintainer/credo_complexity_baseline.json` | Reviewed complexity/nesting inventory | ✓ VERIFIED | Validated by normalizer and policy test as 33 identities/37 occurrences with owner/removal metadata. |
| `test/install_smoke/credo_policy_test.exs` | Aggregate bite/restraint proof | ✓ VERIFIED | Exercises warning and identity/count failure cases; fresh pass. |
| `scripts/gsd_cleanup.sh` | Tracked-safe exact cleanup | ✓ VERIFIED | Finite allowlist with tracked-file preservation; behaviorally tested in temporary repository. |
| `test/install_smoke/repository_residue_test.exs` | Residue and cleanup-safety lock | ✓ VERIFIED | Root-ignore, absence, tracked preservation, untracked deletion, package-evidence preservation tests pass. |
| `.github/workflows/ci.yml` | Blocking signal wiring | ✓ VERIFIED | Quality and Contract are existing CI Summary carriers; new deterministic steps are non-advisory. |
| `test/install_smoke/quality_signal_policy_test.exs` | Durable CI/local policy lock | ✓ VERIFIED | Parses workflow YAML and checks commands, conditions, prerequisite order, advisory exceptions, aliases, and topology. |
| `RUNNING.md` / `mix.exs` | Reproducible local quality policy | ✓ VERIFIED | Documents/implements `credo_quality`, `refactor_contract`, `quality_signals`, then one default suite in `mix ci`; fresh `mix ci` passed. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `refactor_contract.sh` | API/schema/migration/telemetry/error/CI/release tests | explicit foreground `mix test` list | ✓ WIRED | All eight suites are named; fresh runner executes 86 tests. |
| Doctor threshold test | `.doctor.exs` and compiled public modules | `Doctor.CLI` / `Doctor.ReportUtils` | ✓ WIRED | Live report, aggregate health, expected public module membership, and ratchet all asserted. |
| Credo aggregate | named Credo profiles and baseline | three commands plus Elixir/Jason normalizer | ✓ WIRED | Fresh aggregate exits 0; fixture tests prove non-zero on drift. |
| Cleanup test | cleanup script and `.gitignore` | temporary Git repository plus root assertions | ✓ WIRED | Tests actual tracked/untracked behavior rather than only shell text. |
| Quality CI steps | Quality carrier | parsed YAML policy test | ✓ WIRED | Required non-advisory commands run on canonical lint cell; AV comes after tool installation. |
| Contract CI steps | Contract carrier | parsed YAML policy test | ✓ WIRED | Deterministic contract tests and SAFE-01 are non-advisory. |
| CI Summary | existing merge carriers | unchanged `needs` and evaluator | ✓ WIRED | Current and pre-phase Summary `needs` lists are identical; name remains `CI Summary`; evaluator remains `bash scripts/ci/eval_ci_summary.sh`. |
| Release gate | `ci.yml` exact-SHA result | `release.yml` `gate-ci-green` | ✓ WIRED | `release.yml` and `scripts/setup_branch_protection.sh` are byte-unchanged from pre-phase commit `18f758e`; release still requires successful exact-SHA `ci.yml`. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Doctor quality gate | compiled module reports | Doctor inspection of `lib/` compiled metadata | 68 measured module reports; 0 failed | ✓ FLOWING |
| Credo aggregate | normalized issue identity multiset | full-tree Credo JSON plus checked-in reviewed inventory | actual analyzer JSON, fail-closed normalization and `cmp` | ✓ FLOWING |
| SAFE-01 runner | selected ExUnit suites | explicit shipped test files | 86 executed tests | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Structural policy, SAFE-01, Doctor, Credo, residue, CI/release lock behavior | focused seven-file `mix test` command | 50 tests, 0 failures | ✓ PASS |
| Actionable Credo and reviewed baseline | `bash scripts/maintainer/credo_quality.sh` | aggregate passed | ✓ PASS |
| Measured Doctor health | `MIX_ENV=dev mix doctor --full --raise` | 68 modules; 0 failed; all coverage 100.0% | ✓ PASS |
| Deterministic public contract | `mix test --only contract --seed 0` | 15 tests, 0 failures | ✓ PASS |
| SAFE-01 preservation contract | `bash scripts/maintainer/refactor_contract.sh` | 86 tests, 0 failures | ✓ PASS |
| AV prerequisite-backed behavior | focused AV/probe test command | 7 tests, 0 failures | ✓ PASS |
| Local merge-carrier composition | `mix ci` | 1,354 tests, 0 failures, 4 skipped | ✓ PASS |
| Release-train hygiene | `./scripts/maintainer/repo_hygiene_check.sh` | 11 PASS, 0 WARN, 0 BLOCK; clean tree and latest main CI succeeded | ✓ PASS |

### Probe Execution

No phase-declared standalone `probe-*.sh` files. The phase's runnable proof is covered by the AV ExUnit behavior command above.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| SIGNAL-01 | 121-02, 121-07 | Blocking deterministic contract/doc feedback with explicit AV prerequisites | ✓ SATISFIED | Non-advisory Quality/Contract steps, prerequisite ordering lock, 15 contract and 7 AV tests passed. |
| SIGNAL-02 | 121-03, 121-07 | Measured public Doctor ratchet | ✓ SATISFIED | Report-driven test plus fresh 68-module, 100% Doctor pass. |
| SIGNAL-03 | 121-04, 121-06, 121-07 | Blocking warnings/docs/specs/complexity; style advisory | ✓ SATISFIED | Separate profiles, fail-closed aggregate, 33/37 inventory and fixture tests, non-advisory CI wiring. |
| SIGNAL-04 | 121-05 | Exact safe residue cleanup and evidence preservation | ✓ SATISFIED | Temporary-repository safety proof, narrow ignores, canonical audit checksum. |
| SAFE-01 | 121-01, 121-04, 121-07 | Runnable preservation contract for later refactors | ✓ SATISFIED | One root-independent foreground runner, structural lock, and fresh 86-test execution. |

### Anti-Patterns Found

No blocker or warning anti-patterns found in the phase-owned runners and regression locks. The only broad deletion expression observed is the `rm -rf` cleanup of `credo_quality.sh`'s uniquely-created `mktemp` directory via an EXIT trap; it is scoped temporary-process cleanup, not repository cleanup. No unreferenced `TBD`, `FIXME`, or `XXX` markers were found in the phase-owned implementation/test files.

### Disconfirmation Pass

- A superficial CI check would miss disabled steps; the YAML policy test explicitly rejects a false canonical-lint condition and verifies `continue-on-error` is absent from blocking steps.
- A superficial Doctor check would only read `.doctor.exs`; the tested gate generates current reports from compiled `lib/` modules and asserts aggregate health.
- A superficial Credo check would allow a count-only baseline or an empty style-free pass; the fixture tests prove any warning anywhere under `test/` fails before later profiles and that baseline identity/count additions, deletion, and mutation fail.
- A superficial cleanup check would trust shell text; the temporary Git repository test proves a tracked match survives while exact untracked files alone are removed.

### Human Verification Required

None. All phase success criteria are deterministic CI/local policy and test behavior, and each has fresh executable evidence.

### Gaps Summary

None. No deferred item applies: later phases refactor the preserved domains but do not defer any Phase 121 quality signal or preservation-contract requirement.

### PR CI disconfirmation follow-up

The first PR run (`32603899720`) exposed a prerequisite the local tool-equipped checkout could not:
Contract's real `ProcessVariant` telemetry test invoked ffmpeg, but the Contract job did not install it.
Commits `25cc8bb`, `6082872`, and `12426bb` made the pinned installer explicit and fail-closed,
locked its command and ordering in the parsed-workflow policy test, and retired the stale action name
from both current guides and parity contracts. Fresh focused evidence passed: 15 Contract tests,
7 workflow-policy tests, and 58 documentation-parity tests. The final clean re-review covers the
expanded 29-file scope with zero findings.

---

_Verified: 2026-08-22T22:55:24Z_
_Verifier: the agent (gsd-verifier)_
