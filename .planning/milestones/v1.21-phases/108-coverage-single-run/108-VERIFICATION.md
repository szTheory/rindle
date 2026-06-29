---
phase: 108-coverage-single-run
verified: 2026-06-28T00:00:00Z
status: passed
score: 7/7 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 108: coverage-single-run Verification Report

**Phase Goal:** one ExUnit suite execution per lane; `quality` emits both the gate and the JSON artifact, integration/adoption drop their redundant coverage run (COV-01..04)
**Verified:** 2026-06-28
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Each default-suite lane runs the ExUnit suite exactly once per matrix cell (COV-01) | ✓ VERIFIED | quality: single `mix coveralls.multiple --type local --type json --slowest 20` (ci.yml:197); integration: gate is plain `mix test` only (ci.yml:377-378), redundant `Generate coverage JSON artifact` step deleted; adoption: redundant standalone `mix coveralls.json` step deleted. `grep -c 'Generate coverage JSON artifact'` = 0, `grep -c 'mix coveralls.json'` = 0. |
| 2 | Quality lane emits BOTH the console gate AND cover/excoveralls.json from a single coveralls.multiple run (COV-01) | ✓ VERIFIED | ci.yml:197 single run with `--type local` + `--type json`. Vendored `Mix.Tasks.Coveralls.Multiple.run` (deps/excoveralls/lib/mix/tasks.ex:339) parses multiple `--type` keep-values and dispatches once to `Coveralls.do_run(args, type: types)` — one suite execution, dual formatter output. |
| 3 | Gate still runs the `local` analyzer; pass/fail never derived from coveralls.json (COV-02) | ✓ VERIFIED | `--type local` present (ci.yml:197). Source proof: `--type local` → `ExCoveralls.Local.execute` → `ensure_minimum_coverage` (local.ex:24, the gate). JSON formatter (json.ex) contains NO `ensure_minimum_coverage`/`exit`/`raise` — non-gating. ci.yml:184-193 invariant comment explicitly forbids JSON-derived pass/fail. No JSON exit code is read anywhere. |
| 4 | Redundant standalone coverage run removed from all three lanes (COV-03) | ✓ VERIFIED | `Generate coverage JSON artifact` count = 0; `mix coveralls.json` count = 0. Stale comments repointed: integration (ci.yml:387-391) and adoption (ci.yml:645-649) comments now describe the absence of a standalone coverage run and the surviving upload's `warn` behavior. |
| 5 | cover/excoveralls.json still produced/uploaded on quality; all three Upload steps preserved with if-no-files-found: warn (COV-03) | ✓ VERIFIED | `if-no-files-found: warn` count = 3 (ci.yml:213, 400, 661). All three upload steps keep `if: always()`, the pinned `actions/upload-artifact@ea165f8d...`, and both `_build/test/junit/rindle-junit.xml` + `cover/excoveralls.json` paths. Quality's JSON now comes from the single coveralls.multiple run. |
| 6 | Contributor reproduces CI coverage step with one documented RUNNING.md command; `mix coveralls` alone still reproduces the gate (COV-04) | ✓ VERIFIED | RUNNING.md:87 documents `mix coveralls.multiple --type local --type json --slowest 20` in a new "Reproducing the coverage step locally (COV-04)" section; RUNNING.md:94 documents `mix coveralls` reproduces the gate alone; table-row note (RUNNING.md:62) updated to reflect the single run. Table header intact (1 occurrence). |
| 7 | mix.exs cli/0 preferred_envs names coveralls.multiple: :test; mix ci's final test task unchanged (D-08) | ✓ VERIFIED | mix.exs:54 `"coveralls.multiple": :test` (exactly 1). `test:` alias byte-matches expected string (mix.exs:323); `ci:` alias ends in `"test"` (mix.exs:318) byte-unchanged. mix.exs diff is a single additive line. `mix format --check-formatted mix.exs` passes. |

**Score:** 7/7 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.github/workflows/ci.yml` | 3 lanes edited (single-run dual-output, redundant steps deleted) | ✓ VERIFIED | Valid YAML; quality gate switched; 0 redundant coverage steps; comments repointed; 3 upload steps preserved. |
| `mix.exs` | cli/0 preferred_envs gains coveralls.multiple: :test | ✓ VERIFIED | One additive line; format-clean; aliases byte-unchanged. |
| `RUNNING.md` | coverage command documented near lane table | ✓ VERIFIED | New COV-04 section + updated table-row note; gate-alone parity noted; table not restructured. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| quality lane gating step | `local` analyzer (merge-blocking gate → CI Summary) | `mix coveralls.multiple --type local` | ✓ WIRED | `--type local` → Local.execute → ensure_minimum_coverage (source-confirmed). |
| quality lane single run | existing Upload step | `--type json` → cover/excoveralls.json | ✓ WIRED | Single run emits JSON; upload step path includes cover/excoveralls.json (ci.yml:212). |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| COV-01 | 108-01 | One suite execution per lane; quality dual-output; integration/adoption drop redundant run | ✓ SATISFIED | Truths 1, 2 |
| COV-02 | 108-01 | Gate keeps `local` analyzer; never derived from coveralls.json | ✓ SATISFIED | Truth 3 (source-proven) |
| COV-03 | 108-01 | Redundant standalone coverage step removed from all 3 lanes; JSON still on quality; warn preserved | ✓ SATISFIED | Truths 4, 5 |
| COV-04 | 108-01 | One documented local command; gate-alone via `mix coveralls`; mix ci test unchanged | ✓ SATISFIED | Truths 6, 7 |

No orphaned requirements — REQUIREMENTS.md maps exactly COV-01..04 to Phase 108, all claimed in plan frontmatter.

### Prohibitions Held

| Prohibition | Status | Evidence |
|-------------|--------|----------|
| ZERO `lib/` change | ✓ HELD | `git diff d0d46b9..HEAD --name-only -- lib/` = 0 lines |
| Only sanctioned files changed | ✓ HELD | Diff = ci.yml, mix.exs, RUNNING.md (+ SUMMARY doc) |
| ci.yml / `name: CI` not renamed | ✓ HELD | `name: CI` present (5 occurrences) |
| `CI Summary` aggregate untouched | ✓ HELD | `CI Summary` present (8 occurrences); not in diff |
| nightly.yml untouched | ✓ HELD | nightly.yml not in diff (0 lines) |
| `mix ci` final `test` task byte-unchanged | ✓ HELD | mix.exs:318 `"test"`; aliases not in diff |
| Integration gate stays plain `mix test` | ✓ HELD | ci.yml:377-378 plain `mix test ... --include integration` / `--include minio`; not folded into coveralls.multiple |
| Gate never derived from coveralls.json exit code | ✓ HELD | No JSON exit read; `--type local` gates (source-proven) |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | None (no TBD/FIXME/XXX/TODO in changed non-doc files) | — | — |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| ci.yml is valid YAML | `python3 -c "yaml.safe_load(...)"` | YAML_OK | ✓ PASS |
| mix.exs format-clean | `mix format --check-formatted mix.exs` | FORMATTED | ✓ PASS |
| coveralls.multiple task exists | `grep Multiple deps/excoveralls/lib/mix/tasks.ex` | defmodule Multiple (line 329) | ✓ PASS |

Note: `mix coveralls.multiple` itself was not executed (requires the full test DB/suite, > 10s, mutates state) — its correctness is established by source inspection of the vendored task (single `do_run`, gate from `local`, json non-gating), which is sufficient for a CI-config-only phase.

### Gaps Summary

No gaps. The phase goal is observably achieved in the codebase: the quality lane runs the suite once and emits both the merge-blocking `local` gate and `cover/excoveralls.json` from a single `mix coveralls.multiple --type local --type json --slowest 20` execution; the integration and adoption lanes each retain a single suite execution with their redundant standalone coverage runs deleted; all three upload steps are preserved with `if-no-files-found: warn`; mix.exs gains the additive preferred_env; RUNNING.md documents local↔CI parity. Every prohibition holds — most importantly ZERO `lib/` change (the load-bearing v1.21 milestone invariant). All four COV requirements are accounted for and satisfied.

---

_Verified: 2026-06-28_
_Verifier: Claude (gsd-verifier)_
