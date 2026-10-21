---
phase: "136"
slug: "measured-quality-and-ci-ratchets"
status: validated
nyquist_compliant: true
wave_0_complete: true
created: "2026-10-20"
---

# Phase 136 — Validation Strategy

## Test Infrastructure

Existing ExUnit, Bash fixtures, parsed YAML policies, and authenticated GitHub receipt validators own acceptance. No new test framework is needed. Execution requires Phase 135 completion and a supported Elixir 1.17/OTP 27 environment; the accepted runtime was observed during execution. Unit/producer coverage compliance is separate from final measurement acceptance.

| Property | Value |
|---|---|
| Config | `mix.exs`, `test/test_helper.exs`, `coveralls.json` |
| Quick command | `bash scripts/ci/test_nightly_dialyzer.sh` |
| Focused command | `mix test test/install_smoke/quality_signal_policy_test.exs test/install_smoke/dialyzer_ignore_policy_test.exs test/install_smoke/async_isolation_evidence_runner_test.exs --seed 0` |
| Canonical suite | `mix coveralls.multiple --type local --type json` |
| Planning contract | `./scripts/maintainer/automation_first_contract.sh` |
| Runtime | Measure during execution; focused feedback target <=120 seconds, long collectors retain explicit finite budgets. |

## Sampling Rate

Run relevant focused behavior and actual whole-tree guards after source changes. Each immutable candidate owns one canonical default local+JSON measurement. Original909318d9 was first-red, replacement002b8582 had green coverage but exposed a clean-bootstrap timeout/reporting gap, and FINAL4dc73fa9 has green canonical1695tests/3doctests and exact5206/6329coverage. Prior receipts remain immutable and cannot qualify a later source. Verify-only never launches a suite. Plan14 supersedes the initial PR hygiene failure; Plan07 now selects136-SUBJECT-HYGIENE.json and explicitly named HYGIENE coverage/Dialyzer/bootstrap/async receipts. The25seed experiment is separately declared finite local evidence, not another CI lane.

## Per-Task Verification Map

Phase 135 completion and its supported source/toolchain evidence gate **every** plan before implementation or qualification. The executable entry gate is `bash .planning/phases/136-measured-quality-and-ci-ratchets/136-preflight.sh`; each plan invokes it before any mutating action. It requires the completed Phase 135 Roadmap checkbox, all five requirement checkboxes, and a tracked, unmodified `135-VERIFICATION.md` whose frontmatter status is `passed` or `complete`. The tracked Phase135 closure has repeatedly passed this gate. This coverage audit grants no acceptance for an unrun or blocked measurement. Any unavailable prerequisite becomes durable blocked/open evidence, never a fixture-only pass.

| Wave | Plan/task | Requirement | Automated signal | Threat refs | Execution evidence state |
|---|---|---|---|---|---|
| 1 | 136-01 T1 | MAINT-04 | `mix test test/install_smoke/credo_policy_test.exs --seed 0` separates stable identity from metric/count ceiling; unproved observed reductions fail | T-136-01 | Owner fixtures green in FINAL canonical; see plan summary. |
| 1 | 136-01 T2 | MAINT-04 | Same focused test covers equality, count/metric growth, empty/singleton, ordering and executed behavior evidence for any reduction; supported `mix credo_quality` | T-136-01 | Owner fixtures green in FINAL canonical; see plan summary. |
| 1 | 136-02 T1 | TYPE-03 | `mix test test/install_smoke/dialyzer_ignore_policy_test.exs --seed 0` rejects broad/new identities | T-136-02 | Owner fixtures green in FINAL canonical; see plan summary. |
| 1 | 136-02 T2 | TYPE-03 | `bash scripts/ci/test_nightly_dialyzer.sh` covers PLT-mode fixtures; final measurement is 136-09 | T-136-02, T-136-03 | Owner fixtures green in FINAL canonical; see plan summary. |
| 1 | 136-04 T1 | TEST-08 | `mix test test/install_smoke/async_isolation_evidence_runner_test.exs --seed 0` validates first-red and complete receipts | T-136-05, T-136-06 | Owner fixtures green in FINAL canonical; see plan summary. |
| 1 | 136-04 T2 | TEST-08 | Same test verifies no-clobber; final measurement is 136-09 | T-136-05, T-136-06 | Owner fixtures green in FINAL canonical; see plan summary. |
| 1 | 136-05 T1 | CI-15 | `mix test test/install_smoke/ci_cache_hygiene_test.exs --seed 0` fails checksum mismatch before install | T-136-07 | Owner fixtures green in FINAL canonical; see plan summary. |
| 1 | 136-05 T2 | CI-15 | `mix test test/install_smoke/quality_signal_policy_test.exs --seed 0` mutates parsed image, download, cache and timeout consumer fields | T-136-07, T-136-09 | Owner fixtures green in FINAL canonical; see plan summary. |
| 1 | 136-05 T3 | CI-16 | `mix test test/install_smoke/quality_signal_policy_test.exs test/install_smoke/ci_lane_split_test.exs --seed 0` preserves exact context, fork and release semantics | T-136-08, T-136-10 | Owner fixtures green in FINAL canonical; see plan summary. |
| 1 | 136-08 T1 | CI-16 | `mix test test/install_smoke/ci_timing_automation_test.exs --seed 0` exercises new current-subject collection | T-136-14 | Owner fixtures green in FINAL canonical; see plan summary. |
| 1 | 136-08 T2 | CI-16 | Same test rejects partial/foreign populations and preserves historical mode | T-136-15 | Owner fixtures green in FINAL canonical; see plan summary. |
| 3 | 136-10 T1 | TYPE-03, TEST-08, DX-05 | `mix test test/install_smoke/phase136_measure_test.exs --seed 0` proves collector and SHA/toolchain validator | T-136-16 | Owner fixtures green in FINAL canonical; see plan summary. |
| 3 | 136-10 T2 | all seven | `mix test test/install_smoke/phase136_qualification_test.exs --seed 0` fixes coverage/subject receipt schema and proves fail-closed verdict before Plan 03 | T-136-17 | Owner fixtures green in FINAL canonical; see plan summary. |
| 4 | 136-03 T1 | COV-06 | `mix test test/install_smoke/coverage_floor_policy_test.exs --seed 0` rejects just-below counts and foreign SHA; no full run yet | T-136-04 | Owner fixtures green in FINAL canonical; see plan summary. |
| 4 | 136-03 T2 | COV-06 | Finish threshold/tests and commit source/config; focused tests only, no canonical suite | T-136-04 | Owner fixtures green in FINAL canonical; see plan summary. |
| 2 | 136-06 T1 | DX-05 | `mix test test/install_smoke/contributor_bootstrap_test.exs --seed 0` proves clean-checkout script contract; final measurement is 136-09 | T-136-11 | Owner fixtures green in FINAL canonical; see plan summary. |
| 2 | 136-06 T2 | DX-05 | Same test executes command-map ownership and focused/full selection | T-136-11 | Owner fixtures green in FINAL canonical; see plan summary. |
| 5 | 136-11 T1 | COV-06 | Task action pins committed SHA/tree, invokes canonical suite once, writes count receipt; `verify_coverage_floor.exs --verify-only` consumes it | T-136-19 | Historical first-red retained; superseded by Plan13. |
| 5 | 136-11 T2 | COV-06 | `phase136_measure.sh verify-subject` rejects source drift after evidence commit | T-136-19 | Historical first-red retained; superseded by Plan13. |
| 8 | 136-09 T1 | TYPE-03 | `phase136_measure.sh verify-dialyzer --subject-file` validates actual pinned-checkout fresh/restored receipt | T-136-18 | Original subject complete: fresh/restored analysis, clean bootstrap and all25seeds verified; replacement measurements pending. |
| 8 | 136-09 T2 | TEST-08, DX-05 | `phase136_measure.sh verify-async/verify-bootstrap --subject-file` validates pinned-checkout receipts | T-136-18 | Original subject complete: fresh/restored analysis, clean bootstrap and all25seeds verified; replacement measurements pending. |
| 9 | 136-07 T1 | CI-16 | `collect_pr_timing_receipt.sh verify --subject-sha` authenticates exact ten PR runs to pin | T-136-12 | Pending live exact-head timing/qualification; fixtures green. |
| 9 | 136-07 T2 | all seven | `verify_phase136_qualification.sh verify --subject-file` recomputes seven verdicts from pinned artifacts | T-136-12, T-136-13, T-136-17 | Pending live exact-head timing/qualification; fixtures green. |
| 6 | 136-12 T1 | COV-06, CI-15 | Actual async-safety and residue owners plus waveform postconditions | T-136-04, T-136-09 | Green36test repair, retained first-red. |
| 6 | 136-12 T2 | COV-06 | Distinct source pin and exact receipt, no overwritten historical attempt | T-136-19 | Archived green002b8582; later bootstrap first-red retained. |
| 7 | 136-13 T1 | DX-05, COV-06 | Real timeout record,600second full bound, foreign-host fixture and receipt-consumer regressions | T-136-04, T-136-11, T-136-18 | Green60/60; both JUnit REDs preserved. |
| 7 | 136-13 T2 | COV-06, TYPE-03, DX-05 | FINAL source pin, one canonical run and exact verify-only | T-136-19 | Green1695tests/3doctests,5206/6329; final projection passes. |

| 9 | 136-14 T1 | CI-15, CI-16 | Command-output owner/consumer tests, exact relocation hashes and full ledger/archive harness | T-136-13, T-136-16 | GREEN65/65 owner/meta tests and58/58 shell cases; genuine JUnit RED preserved. |
| 9 | 136-14 T2 | all seven | New source pin, one canonical measurement and all source-bound collectors, authenticated current-head timing | T-136-12, T-136-17, T-136-19 | Pipeline active on HYGIENE4fdd3fba; no replacement acceptance credit yet. |

The eleven original plans carry T-136-SC for package supply; gap Plans12/13 add no package and preserve that boundary. There is no CONTEXT.md by explicit user decision. The nine spec-less edge probes are carried as flagged assumptions in the corresponding plans (MAINT-04 three; each other requirement one); six unclassified rows remain flagged rather than inferred green. Prohibition recall found no bespoke value/safety prohibition beyond existing requirement truthfulness; canon security concerns map to T-136-05 through T-136-19. Assumption-delta scan matched the word “second” only inside “480-second”; no primary identity changes, so the plans record `no-change`.

## Multi-Source Coverage Audit

COVERED here means automated test/producer coverage exists and runs green; it does not mean every measured requirement is accepted. Final bootstrap,25seed async, live exact-ten timing and recomputed qualification still govern their own outcomes. No missing source-test automation was found; external/execution prerequisites remain pending.

| Source | Item | Plan | Status | Evidence |
|---|---|---|---|---|
| GOAL | Bounded reproducible quality and CI feedback that cannot silently regress | 01–13 | COVERED | Policy fixtures, pinned measurements, exact-ten live timing |
| REQ | MAINT-04 | 01, 07 | COVERED | Monotone Credo ledger and removal proof |
| REQ | TYPE-03 | 02, 09, 10, 07 | COVERED | Narrow ignores; supported fresh/restored analysis |
| REQ | COV-06 | 03, 11, 07 | COVERED | Exact 82.1343 floor and behavioral branch tests |
| REQ | TEST-08 | 04, 09, 10, 07 | COVERED | Finite new receipt, first-red open path |
| REQ | CI-15 | 05, 07 | COVERED | Input integrity, cache and timeout semantics |
| REQ | CI-16 | 05, 08, 10, 07 | COVERED | Preserved topology, current controller, exact-ten receipt |
| REQ | DX-05 | 06, 09, 10, 07 | COVERED | Clean supported bootstrap and command map |
| RESEARCH | Existing authorities; no new package/framework | 01–13 | COVERED | Existing Credo, Dialyzer, ExCoveralls, YAML and timing owners |
| RESEARCH | Phase 135 prerequisite; source/toolchain freshness | 01–13 | COVERED | Executable shared preflight, subject pin and source-bound validators |
| RESEARCH | Removal-only ledgers, exact-count single coverage run | 01, 03, 11 | COVERED | Fixture mutations and final supported receipt |
| RESEARCH | Bounded async first red and immutable history | 04, 09 | COVERED | Runner/validator, final receipt and no-clobber tests |
| RESEARCH | CI input integrity, structural topology, final live timing | 05, 08, 07 | COVERED | Parsed tests and authenticated GitHub receipt |
| RESEARCH | Contributor command map, runtime state and secret boundaries | 06, 09 | COVERED | Clean probe, final supported runtime and threat registers |
| CONTEXT | No artifact by explicit user decision | — | N/A | Roadmap, requirements, research govern scope |

The API-coverage detector fires on the threat-table phrase “GitHub Actions API.” This phase extends an existing timing controller; it introduces no new external API integration. The orchestrator owns the contribution-guidance `COVERAGE.md` false-positive declaration because this planner's edit ownership is limited to PLAN.md, VALIDATION.md, and the Phase 136 ROADMAP list.

## Wave 0 Requirements

All declared validators and producer entrypoints now exist, were tested before qualification use, and ran in the current supported canonical suite. Plan13 owns the final committed source and count receipt; Plans09/07 create evidence only against FINAL. Setup/focused bootstrap commands are bounded300seconds, full mix ci600, total1200; a shorter caller deadline clamps every command. The actual earlier timeout remains immutable, and controlled timeout/foreign-host tests close the discovered source-test gaps. No new source test is needed by this audit.

## Manual-Only Verifications

None. All phase behaviors require automated verification. Credentials or irreversible-action authorization may use a checkpoint; its answer does not satisfy acceptance. Missing credentials, unsupported runtime or insufficient live samples leaves the corresponding requirement open.

## Validation Sign-Off

- [x] Every task has automated verification and an observable failure direction.
- [x] Exact task map and threat references agree with final plans.
- [x] Every new validator is produced before use.
- [x] No watch mode, manual acceptance or unsupported-toolchain substitution.
- [x] Long collectors have finite budgets and preserve first-red evidence.
- [ ] Fresh final acceptance evidence exists before requirement closure.

Coverage audit: all fourteen plans and all seven requirements map to executable owners; the HYGIENE repair passed65 owner/meta tests and58 shell cases. Requirement acceptance remains pending final actual receipts and authenticated PR timing; the last sign-off box stays open until that evidence exists. No manual-only acceptance or unsupported-host substitution is authorized.

## Validation Audit 2026-10-20

| Metric | Count |
|---|---|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

## User scope decision and Plan15 coverage (2026-10-21)

The numeric CI-16 target is deferred unfinished to SEED-261021-918 under 136-SPEED-DEFERRAL.json and no longer gates merge. This decision earns no acceptance credit. Plan15 adds executable overlap and each failing-child propagation tests against the actual parsed YAML run body; focused39/0 and full owner/meta/topology104/0 pass. All four real harnesses pass in both modes. The existing job timeout and strict sole CI Summary gate remain enforced. The prior exact-source qualification receipts remain historical; no stale authority is promoted by this audit.
