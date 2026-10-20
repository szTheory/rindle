---
phase: "136"
slug: "measured-quality-and-ci-ratchets"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-20"
---

# Phase 136 — Validation Strategy

## Test Infrastructure

Existing ExUnit, Bash fixtures, parsed YAML policies, and authenticated GitHub receipt validators own acceptance. No new test framework is needed. Execution requires Phase 135 completion and a supported Elixir 1.17/OTP 27 environment; planning does not supply runtime or live acceptance evidence.

| Property | Value |
|---|---|
| Config | `mix.exs`, `test/test_helper.exs`, `coveralls.json` |
| Quick command | `bash scripts/ci/test_nightly_dialyzer.sh` |
| Focused command | `mix test test/install_smoke/quality_signal_policy_test.exs test/install_smoke/dialyzer_ignore_policy_test.exs test/install_smoke/async_isolation_evidence_runner_test.exs --seed 0` |
| Canonical suite | `mix coveralls.multiple --type local --type json` |
| Planning contract | `./scripts/maintainer/automation_first_contract.sh` |
| Runtime | Measure during execution; focused feedback target <=120 seconds, long collectors retain explicit finite budgets. |

## Sampling Rate

Run the relevant focused fixture/behavior tests after each implementation task. Plan 03 commits all source and coverage configuration. Plan 11 then persists one subject_sha/source_tree and runs the canonical coverage invocation **once in its Task 1 action**; both Task 1 and Task 2 automated verifies consume existing artifacts and never launch the suite. Plans 09 and 07 use that persisted pin despite later .planning evidence commits; collection runs from a detached checkout at the pin. The fixed 25-seed local experiment is separate evidence, not a second CI coverage lane.

## Per-Task Verification Map

Phase 135 completion and its supported source/toolchain evidence gate **every** plan before implementation or qualification. The executable entry gate is `bash .planning/phases/136-measured-quality-and-ci-ratchets/136-preflight.sh`; each plan invokes it before any mutating action. It requires the completed Phase 135 Roadmap checkbox, all five requirement checkboxes, and a tracked, unmodified `135-VERIFICATION.md` whose frontmatter status is `passed` or `complete`. These remain pending today, so this file grants no Phase 136 acceptance. Any unavailable prerequisite becomes durable blocked/open evidence, never a fixture-only pass.

| Wave | Plan/task | Requirement | Automated signal | Threat refs |
|---|---|---|---|---|
| 1 | 136-01 T1 | MAINT-04 | `mix test test/install_smoke/credo_policy_test.exs --seed 0` separates stable identity from metric/count ceiling; unproved observed reductions fail | T-136-01 |
| 1 | 136-01 T2 | MAINT-04 | Same focused test covers equality, count/metric growth, empty/singleton, ordering and executed behavior evidence for any reduction; supported `mix credo_quality` | T-136-01 |
| 1 | 136-02 T1 | TYPE-03 | `mix test test/install_smoke/dialyzer_ignore_policy_test.exs --seed 0` rejects broad/new identities | T-136-02 |
| 1 | 136-02 T2 | TYPE-03 | `bash scripts/ci/test_nightly_dialyzer.sh` covers PLT-mode fixtures; final measurement is 136-09 | T-136-02, T-136-03 |
| 1 | 136-04 T1 | TEST-08 | `mix test test/install_smoke/async_isolation_evidence_runner_test.exs --seed 0` validates first-red and complete receipts | T-136-05, T-136-06 |
| 1 | 136-04 T2 | TEST-08 | Same test verifies no-clobber; final measurement is 136-09 | T-136-05, T-136-06 |
| 1 | 136-05 T1 | CI-15 | `mix test test/install_smoke/ci_cache_hygiene_test.exs --seed 0` fails checksum mismatch before install | T-136-07 |
| 1 | 136-05 T2 | CI-15 | `mix test test/install_smoke/quality_signal_policy_test.exs --seed 0` mutates parsed image, download, cache and timeout consumer fields | T-136-07, T-136-09 |
| 1 | 136-05 T3 | CI-16 | `mix test test/install_smoke/quality_signal_policy_test.exs test/install_smoke/ci_lane_split_test.exs --seed 0` preserves exact context, fork and release semantics | T-136-08, T-136-10 |
| 1 | 136-08 T1 | CI-16 | `mix test test/install_smoke/ci_timing_automation_test.exs --seed 0` exercises new current-subject collection | T-136-14 |
| 1 | 136-08 T2 | CI-16 | Same test rejects partial/foreign populations and preserves historical mode | T-136-15 |
| 3 | 136-10 T1 | TYPE-03, TEST-08, DX-05 | `mix test test/install_smoke/phase136_measure_test.exs --seed 0` proves collector and SHA/toolchain validator | T-136-16 |
| 3 | 136-10 T2 | all seven | `mix test test/install_smoke/phase136_qualification_test.exs --seed 0` fixes coverage/subject receipt schema and proves fail-closed verdict before Plan 03 | T-136-17 |
| 4 | 136-03 T1 | COV-06 | `mix test test/install_smoke/coverage_floor_policy_test.exs --seed 0` rejects just-below counts and foreign SHA; no full run yet | T-136-04 |
| 4 | 136-03 T2 | COV-06 | Finish threshold/tests and commit source/config; focused tests only, no canonical suite | T-136-04 |
| 2 | 136-06 T1 | DX-05 | `mix test test/install_smoke/contributor_bootstrap_test.exs --seed 0` proves clean-checkout script contract; final measurement is 136-09 | T-136-11 |
| 2 | 136-06 T2 | DX-05 | Same test executes command-map ownership and focused/full selection | T-136-11 |
| 5 | 136-11 T1 | COV-06 | Task action pins committed SHA/tree, invokes canonical suite once, writes count receipt; `verify_coverage_floor.exs --verify-only` consumes it | T-136-19 |
| 5 | 136-11 T2 | COV-06 | `phase136_measure.sh verify-subject` rejects source drift after evidence commit | T-136-19 |
| 6 | 136-09 T1 | TYPE-03 | `phase136_measure.sh verify-dialyzer --subject-file` validates actual pinned-checkout fresh/restored receipt | T-136-18 |
| 6 | 136-09 T2 | TEST-08, DX-05 | `phase136_measure.sh verify-async/verify-bootstrap --subject-file` validates pinned-checkout receipts | T-136-18 |
| 7 | 136-07 T1 | CI-16 | `collect_pr_timing_receipt.sh verify --subject-sha` authenticates exact ten PR runs to pin | T-136-12 |
| 7 | 136-07 T2 | all seven | `verify_phase136_qualification.sh verify --subject-file` recomputes seven verdicts from pinned artifacts | T-136-12, T-136-13, T-136-17 |

All eleven plans carry T-136-SC for package supply; no new package is planned. There is no CONTEXT.md by explicit user decision. The nine spec-less edge probes are carried as flagged assumptions in the corresponding plans (MAINT-04 three; each other requirement one); six unclassified rows remain flagged rather than inferred green. Prohibition recall found no bespoke value/safety prohibition beyond existing requirement truthfulness; canon security concerns map to T-136-05 through T-136-19. Assumption-delta scan matched the word “second” only inside “480-second”; no primary identity changes, so the plans record `no-change`.

## Multi-Source Coverage Audit

| Source | Item | Plan | Status | Evidence |
|---|---|---|---|---|
| GOAL | Bounded reproducible quality and CI feedback that cannot silently regress | 01–11 | COVERED | Policy fixtures, pinned measurements, exact-ten live timing |
| REQ | MAINT-04 | 01, 07 | COVERED | Monotone Credo ledger and removal proof |
| REQ | TYPE-03 | 02, 09, 10, 07 | COVERED | Narrow ignores; supported fresh/restored analysis |
| REQ | COV-06 | 03, 11, 07 | COVERED | Exact 82.1343 floor and behavioral branch tests |
| REQ | TEST-08 | 04, 09, 10, 07 | COVERED | Finite new receipt, first-red open path |
| REQ | CI-15 | 05, 07 | COVERED | Input integrity, cache and timeout semantics |
| REQ | CI-16 | 05, 08, 10, 07 | COVERED | Preserved topology, current controller, exact-ten receipt |
| REQ | DX-05 | 06, 09, 10, 07 | COVERED | Clean supported bootstrap and command map |
| RESEARCH | Existing authorities; no new package/framework | 01–11 | COVERED | Existing Credo, Dialyzer, ExCoveralls, YAML and timing owners |
| RESEARCH | Phase 135 prerequisite; source/toolchain freshness | 01–11 | COVERED | Executable shared preflight, subject pin and source-bound validators |
| RESEARCH | Removal-only ledgers, exact-count single coverage run | 01, 03, 11 | COVERED | Fixture mutations and final supported receipt |
| RESEARCH | Bounded async first red and immutable history | 04, 09 | COVERED | Runner/validator, final receipt and no-clobber tests |
| RESEARCH | CI input integrity, structural topology, final live timing | 05, 08, 07 | COVERED | Parsed tests and authenticated GitHub receipt |
| RESEARCH | Contributor command map, runtime state and secret boundaries | 06, 09 | COVERED | Clean probe, final supported runtime and threat registers |
| CONTEXT | No artifact by explicit user decision | — | N/A | Roadmap, requirements, research govern scope |

The API-coverage detector fires on the threat-table phrase “GitHub Actions API.” This phase extends an existing timing controller; it introduces no new external API integration. The orchestrator owns the contribution-guidance `COVERAGE.md` false-positive declaration because this planner's edit ownership is limited to PLAN.md, VALIDATION.md, and the Phase 136 ROADMAP list.

## Wave 0 Requirements

Create missing ledger, exact-coverage, async-receipt, CI-integrity and clean-bootstrap validators in their owning implementation tasks. Plan 10 defines the coverage/subject receipt interface and final qualification validator before Plan 03 implements its side. Plan 03 commits threshold/tests/config; Plan 11 pins that commit and runs the sole canonical suite. Plans 09 and 07 create evidence only against that same pin. Every new verify path has an explicit producer and dependency. No fixture alone closes a measured requirement.

## Manual-Only Verifications

None. All phase behaviors require automated verification. Credentials or irreversible-action authorization may use a checkpoint; its answer does not satisfy acceptance. Missing credentials, unsupported runtime or insufficient live samples leaves the corresponding requirement open.

## Validation Sign-Off

- [ ] Every task has automated verification and an observable failure direction.
- [ ] Exact task map and threat references agree with final plans.
- [ ] Every new validator is produced before use.
- [ ] No watch mode, manual acceptance or unsupported-toolchain substitution.
- [ ] Long collectors have finite budgets and preserve first-red evidence.
- [ ] Fresh final acceptance evidence exists before requirement closure.

Approval: pending execution; this draft is not a passed validation result.
