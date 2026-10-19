---
phase: 135-repository-and-code-craft-consolidation
plan: 01
subsystem: testing
tags: [residue-scan, allowlist, craft, ci-gate]
requires: []
provides:
  - "scripts/maintainer/scan_live_residue.exs: twelve-class live residue scanner (--check, --list, --regen-baseline, --root, --allowlist-dir, --require-no-pending)"
  - "seven removal-only allowlist shards under scripts/maintainer/live_residue_allowlist/"
  - "test/install_smoke/live_residue_scan_test.exs: merge-blocking live scan plus planted-violation fixtures"
affects: [135-02, 135-03, 135-04, 135-05, 135-06, 135-07, 135-08, 135-09, 135-10, 135-11, 135-12, 135-13]
tech-stack:
  added: []
  patterns: ["exact-count removal-only allowlist keyed by path/class/normalized text", "area-sharded baseline so parallel tranche plans never share a shard"]
key-files:
  created:
    - scripts/maintainer/scan_live_residue.exs
    - scripts/maintainer/live_residue_allowlist/lib.json
    - scripts/maintainer/live_residue_allowlist/automation_generators.json
    - scripts/maintainer/live_residue_allowlist/automation_workflows.json
    - scripts/maintainer/live_residue_allowlist/install_smoke.json
    - scripts/maintainer/live_residue_allowlist/unit_tests_a.json
    - scripts/maintainer/live_residue_allowlist/unit_tests_b.json
    - scripts/maintainer/live_residue_allowlist/examples_docs.json
    - test/install_smoke/live_residue_scan_test.exs
  modified: []
key-decisions:
  - "Comment detection is per file family; block comments and test-file @moduledoc/@doc heredocs are followed for narration"
  - "Contract class covers any non-comment lib text (Rindle.Error messages, public docs) and named check-run/step strings"
status: complete
duration: ~1h
completed: 2026-10-18
commits: 3
plan_head_before: c7ff1511dd4bbc59f4fd8a0158ccc8020acc74da
plan_head_after: 31aee45ecc715465586eb324ef2d463afa553362
actuals:
  tokens: 101800
  tasks: 3
  commits: 3
---

# Phase 135 Plan 01: Live residue scanner with removal-only allowlist Summary

Twelve-class CRAFT-04/CRAFT-06 residue scanner, seven area-sharded exact-count allowlist shards seeded from the live tree, and a merge-blocking ExUnit wrapper with one planted violation per class.

## Tasks

| Task | Commit | Result |
| ---- | ------ | ------ |
| 1 Tracer: scanner core, decision-id and mojibake, shards, live check | 2fed3a75 | live check exit 0, fixtures for stale count, mojibake, misfiled shards |
| 2 Remaining CRAFT-04 classes, reason classification, --require-no-pending | 42c309f4 | seven more classes, reason_class validation, contract/receipt/policy/fixture seeded |
| 3 CRAFT-06 classes and idempotent regen | 31aee45e | duplicated-prose, narration, artifact-comment, byte-idempotent regeneration |

## Verification

- `mix test test/install_smoke/live_residue_scan_test.exs test/planning_path_hygiene_test.exs test/async_safety_guard_test.exs`: 33 tests, 0 failures
- `./scripts/maintainer/automation_first_contract.sh`: passed
- grep for the phase-135 planning path under scripts, test, lib and .github: no matches
- `mix format --check-formatted` on the scanner and test: clean
- `--check`: `live residue scan: ok (611 files, 1348 hits, 1313 allowlist entries)`
- `--regen-baseline` twice: `diff -r` empty; the test also proves regeneration reproduces the committed shards byte for byte

## Census (fresh, seeded; supersedes research counts)

611 scanned files, 1348 hit lines, 1313 allowlist entries.

Per class (hit lines): decision-id 435, requirement-id 320, phase-ref 172, spec-ref 172, planning-path 88, milestone-ref 78, plan-ref 47, narration 29, mojibake 4, path-name 2, duplicated-prose 1, artifact-comment 0.

Per area shard (entries / hit lines / pending-removal entries): lib 117/119/98, automation_generators 149/150/142, automation_workflows 239/261/209, install_smoke 360/369/349, unit_tests_a 140/140/140, unit_tests_b 153/154/153, examples_docs 155/155/148.

Per reason_class (entries): pending-removal 1239, policy 28, contract 24, immutable-receipt 15, fixture 7.

lib/rindle/error.ex entries (all non-comment message text, all contract): milestone-ref x5 (the Mux/Cloudflare "post-v1.4" wait, "falls through to v1.4 progressive playback", "In Rindle v1.4, only :progressive", "bare-atom v1.6 surface", "pre-v1.13 rows"), phase-ref x1 (the provider-stuck check text). No `#` comment in error.ex hit.

## Calibration notes

- Mojibake: matched on decoded text. 1592 non-ASCII lines across 234 scoped files (python measurement, vendor excluded); exactly 4 lines in 2 files flagged and all 4 are true hits: `onboarding_and_capabilities_test.exs` lines 201-202 (intentional regression literal, seeded fixture) and `operations_test.exs` lines 216 and 221 (double-encoded em dash, pending-removal). So 1588 correctly encoded non-ASCII lines were not flagged. No file in scope is non-UTF-8 text.
- duplicated-prose: alphabetic-only tokens (length 3 or more) with code-shaped tokens breaking a run, at least 4 distinct words and not stopword-only. Live result is exactly one true hit, `mix.exs:305`. Zero false positives; no rule relaxed.
- narration: closed phrase list, case-insensitive, comment text only. Comment detection is per family: `#` for Elixir, shell, YAML and unknown; `//`, `/* */` and `*` only for js/mjs/cjs/ts/css; only `<!--` for markdown; none for JSON. Added after finding that the plan's named true sites were missed by single-line markers: continuation lines of multi-line `<%!-- --%>`, `<!-- -->` and `/* */` blocks, and `@moduledoc`/`@doc` heredocs in `_test.exs` files (non-public prose). This brought in `actions_live.ex:574` and the two examples "formerly human-verified" headers. 29 narration lines in total; `lib/rindle/error.ex` "previously advertised capability" is message text, not a comment, so it is never reached. Some lines are present-tense facts about upstream ("Upstream MinIO no longer publishes container images" in 3 files); they stay pending-removal for the tranche plans to reword.
- artifact-comment: closed list (generated by plus AI or agent tool names, ai-generated, "as an ai language model", the GSD write sentinel, bare TODO/FIXME/XXX/HACK words, case-sensitive). Zero live hits; mktemp `XXXXXX` templates do not match because of word boundaries.
- milestone-ref and the other regexes use the RESEARCH patterns unchanged.

## Classification

- contract (24): Rindle.Error message text, public `@moduledoc`/`@doc`/`@typedoc` text and the NimbleOptions `doc:` string in `lib/`, the `ADMIN-06 Optional Dependencies` and `Run SAFE-01 preservation contract` names in ci.yml, the same name in `dep_landing_evidence.sh`, `test_dep_landing_evidence.sh` and `quality_signal_policy_test.exs`.
- immutable-receipt (15): lines naming the census ledger path or the 132 closure summary in `verify_nightly_run.sh`, `test_verify_nightly_run.sh`, `evidence_census.exs`, `validate_evidence_census.exs` and `evidence_census_test.exs`.
- policy (28): `.planning` reads in `gsd_cleanup.sh`, `repo_hygiene_check.sh`, `automation_first_contract.sh`, `update_release_train_baseline.sh`, the non-comment ci.yml and `release.yml` lines, and AGENTS.md (planning paths plus the LIFE-06/STREAM-10 reopening signal line).
- fixture (7): the `ci_timing_automation_test.exs` temp-fixture writes and the onboarding mojibake regression literal.
- Requirement-id test names stay pending-removal (D-135-07). `test_nightly_dialyzer.sh` fingerprint path stays pending-removal.

## Deviations from Plan

None in behavior. Notes: the comment-detection extensions above (block comments, test-file doc heredocs) are calibration of the narration rule, applied so the plan's own named true sites are detected. The scanner exposes the self-exclusion list through `self_exclusions/0` and the test asserts the three paths by parsing the source constants.

## Known Stubs

None.

## Threat Flags

None. Scanned content is only matched with Regex and never compiled or executed; the file list comes from `git ls-files` argv.

## Issues Encountered

The worktree had no `_build`; one `mix compile` into the shared scratch build path was needed before `--no-compile` script runs.

## Self-Check: PASSED

All nine created files exist; commits 2fed3a75, 42c309f4 and 31aee45e are ancestors of HEAD.
