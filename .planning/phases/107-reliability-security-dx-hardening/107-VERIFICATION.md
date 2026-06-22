---
phase: 107-reliability-security-dx-hardening
verified: 2026-06-22T16:30:00Z
status: passed
score: 14/14 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 107: Reliability, Security & DX Hardening Verification Report

**Phase Goal:** Settle the pipeline — concurrency/async correctness, supply-chain posture, a
faithful local repro, and the DX docs that describe the *settled* fast-PR check set.
**Verified:** 2026-06-22T16:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #  | Truth (Requirement) | Status | Evidence |
| -- | ------------------- | ------ | -------- |
| 1  | HARD-01: async-safety AST static guard exists, is `async: true`, passes green on current tree | ✓ VERIFIED | `test/async_safety_guard_test.exs` (430 lines, header `use ExUnit.Case, async: true` @ :38; `Path.wildcard` + `Code.string_to_quoted!` + 9× `Macro.prewalk`). `mix test` → 2 tests, 0 failures |
| 2  | HARD-01: 15 RESEARCH-CLEAN modules flipped to `async: true`; suite stays green | ✓ VERIFIED | All 14 listed files report `async: true` / `async: false`=0; `owner_erasure_batch_opts_test.exs` sibling pair preserved (2× `async: true`, 0 false). Full `mix ci` suite: 1160 tests, 1 pre-existing external failure (see Gaps) |
| 3  | HARD-01: future contributor adding an unsafe primitive to an async:true module gets a red gate (behavior-dependent) | ✓ VERIFIED | Behavioral probe: synthetic `Application.put_env` in an `async: true` test made the guard FAIL with `test/.../probe_test.exs:4 ... uses application_put_env` + remediation message; green again after probe removed. Classifier wired to `assert offenders == []` |
| 4  | HARD-02: every third-party `uses:` pinned to 40-hex SHA + `# vX.Y.Z` comment | ✓ VERIFIED | `grep -rEn 'uses: [^@./][^@]*@v[0-9]'` → NOTHING (no mutable tag survives); 52 SHA pins, 0 missing version comment |
| 5  | HARD-02: `.github/dependabot.yml` with github-actions + mix, grouped, weekly, non-release prefix | ✓ VERIFIED | 48 lines; both `package-ecosystem` entries; `interval: weekly`; `prefix: ci` / `prefix: build`; `groups:` present; no `feat`/`fix` prefix |
| 6  | HARD-02: `{:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}` + advisory `mix deps.audit` in quality lane | ✓ VERIFIED | `mix.exs:138` exact dep; `mix_audit` in `mix.lock`; `ci.yml:166` `run: mix deps.audit` with `ci.yml:167` `continue-on-error: true` |
| 7  | HARD-02: jobs beyond `contents: read` default declare least-privilege `permissions:`; ci-observability has `actions: read` | ✓ VERIFIED | Workflow default `contents: read` @ `ci.yml:35`; `ci-observability` job declares `permissions: actions: read` @ :1207+ |
| 8  | HARD-03: single `ci` alias mirrors the merge-blocking check set | ✓ VERIFIED | `mix.exs` `aliases/0` `ci:` = deps.get --check-locked, deps.unlock --check-unused, compile --warnings-as-errors, format --check-formatted, 4 brandbook drift gates, test |
| 9  | HARD-03: `mix ci` runs default-tag suite (skips minio/integration), full-parity MinIO documented | ✓ VERIFIED | Alias contains no `--include minio`/`integration`; CONTRIBUTING documents the full-parity command (3× `minio`). `mix ci` runs default-tag suite (76 excluded) |
| 10 | HARD-03: CONTRIBUTING Phase-107/HARD-03 section filled (lanes, CI Summary, mix ci, prerequisites) | ✓ VERIFIED | Placeholder gone (0 hits); 11× `mix ci`, 4× `CI Summary`, MinIO prerequisites present |
| 11 | HARD-03: README keeps ci.yml/badge.svg workflow-run badge; docs state it reflects CI Summary; no custom per-check badge | ✓ VERIFIED | `README.md:10` `ci.yml/badge.svg?branch=main` kept; :15 documents `CI Summary` gate; only shields.io refs are pre-existing Hex.pm/HexDocs version badges (not a custom CI badge) |
| 12 | HARD-04: CI E2E lane AND `scripts/ci/e2e_local.sh` both run `playwright:v1.57.0-noble` (same image) | ✓ VERIFIED | `scripts/ci/e2e_local.sh` (79 lines, executable, `bash -n` OK, 2× pinned image); `ci.yml` 3× pinned image; lane not in branch-protection required set |
| 13 | HARD-04: `@playwright/test` pinned exact `1.57.0` (caret dropped) | ✓ VERIFIED | `examples/adoption_demo/package.json:10` `"@playwright/test": "1.57.0"` |
| 14 | HARD-04: single `WCAG_AA_NORMAL = 4.5` constant imported by runtime gate + token-pair gates; pass counts byte-identical | ✓ VERIFIED | `brandbook/src/contrast-constants.mjs` exports `WCAG_AA_NORMAL = 4.5`; imported by `admin-gallery-check.mjs:10` (`ratio < WCAG_AA_NORMAL` @ :284) + 2 data modules; 0 bare `min: 4.5` remain. Gates: `58/58` + `47/47` pairs pass; validation test 24 tests/0 failures |

**Score:** 14/14 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Status | Details |
| -------- | ------ | ------- |
| `test/async_safety_guard_test.exs` | ✓ VERIFIED | 430 lines, async:true, AST classifier for all 8 primitives, allowlist escape hatch, `assert offenders == []` |
| `.github/dependabot.yml` | ✓ VERIFIED | 48 lines, both ecosystems, grouped/weekly/non-release prefix |
| `mix.exs` | ✓ VERIFIED | `mix_audit` dep + `ci:` alias |
| `CONTRIBUTING.md` | ✓ VERIFIED | reserved section filled; `mix ci` + `CI Summary` |
| `README.md` | ✓ VERIFIED | badge kept + CI Summary clarification |
| `brandbook/src/contrast-constants.mjs` | ✓ VERIFIED | exports `WCAG_AA_NORMAL = 4.5` |
| `scripts/ci/e2e_local.sh` | ✓ VERIFIED | executable, valid, pinned container |
| `examples/adoption_demo/package.json` | ✓ VERIFIED | exact `1.57.0` |

### Key Link Verification

| From | To | Status | Details |
| ---- | -- | ------ | ------- |
| async guard | `test/**/*_test.exs` | ✓ WIRED | `Path.wildcard` glob + `Code.string_to_quoted!` per file |
| ci.yml quality job | `mix deps.audit` | ✓ WIRED | advisory step `ci.yml:166-167` |
| `ci` alias | PR merge-blocking lane set | ✓ WIRED | alias task list mirrors gate (no minio/integration) |
| CONTRIBUTING | `mix ci` + CI Summary | ✓ WIRED | documents single command + sole required check |
| e2e_local.sh | ci.yml adoption-demo-e2e lane | ✓ WIRED | both reference `playwright:v1.57.0-noble` |
| admin-gallery-check.mjs | contrast-constants.mjs | ✓ WIRED | imports `WCAG_AA_NORMAL`, replaces `ratio < 4.5` literal |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Guard passes on current tree | `mix test test/async_safety_guard_test.exs --seed 0` | 2 tests, 0 failures | ✓ PASS |
| Guard red-flags unsafe primitive | synthetic `Application.put_env` probe (added+removed) | FAIL with `file:line` + `application_put_env` | ✓ PASS |
| Contrast gates byte-identical | `node admin-contrast.mjs`; `node contrast.mjs` | `58/58`, `47/47` pairs pass | ✓ PASS |
| Brandbook validation test | `mix test .../admin_design_system_validation_test.exs --include …` | 24 tests, 0 failures | ✓ PASS |
| No mutable third-party tags | `grep -rEn 'uses: …@v[0-9]'` | empty (exit 1) | ✓ PASS |
| e2e_local.sh parses | `bash -n scripts/ci/e2e_local.sh` | OK, executable | ✓ PASS |

### Prohibitions (must-NOT) — all upheld

| Prohibition | Status | Evidence |
| ----------- | ------ | -------- |
| No `lib/` file created/modified (whole-milestone invariant) | ✓ UPHELD | `git diff --name-only e4e3186^..514ebfc \| grep -c '^lib/'` = 0 |
| No `--partitions` wiring added (DEFERRED, D-01) | ✓ UPHELD | 0 `partitions` hits in ci.yml/mix.exs; only `.planning/` docs note DEFERRED |
| No GENUINELY-UNSAFE module flipped to async:true | ✓ UPHELD | Only the 15 CLEAN flipped; 2 offenders → async:false, 2 → justified `@async_safety_allow [:file_mutation]` |
| `name: CI` + `ci.yml` filename unchanged (release coupling) | ✓ UPHELD | `^name: CI$` present @ ci.yml:1 |
| `CI Summary` stays SOLE required check; deps.audit advisory | ✓ UPHELD | `setup_branch_protection.sh` lists `CI Summary`; deps.audit `continue-on-error: true` |
| No new required check; adoption-demo-e2e not PR-required | ✓ UPHELD | `grep -c adoption-demo-e2e setup_branch_protection.sh` = 0 |
| dependabot prefix non-release | ✓ UPHELD | `ci`/`build`, no `feat`/`fix` |
| No NON-4.5 contrast pair clobbered | ✓ UPHELD | pass counts identical (58/58, 47/47); validation test green |
| No custom per-check badge endpoint | ✓ UPHELD | only kept workflow-run badge + pre-existing Hex.pm/HexDocs badges |

### Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
| ----------- | ----------- | ------ | -------- |
| HARD-01 | 107-01 | ✓ SATISFIED | Truths 1-3 |
| HARD-02 | 107-02 | ✓ SATISFIED | Truths 4-7 |
| HARD-03 | 107-03 | ✓ SATISFIED | Truths 8-11 |
| HARD-04 | 107-04 | ✓ SATISFIED | Truths 12-14 |

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
| ---- | ------- | -------- | ------ |
| (none) | TBD/FIXME/XXX in phase-modified files | — | None found across all non-`.planning/` phase files |

### Human Verification Required

None. All truths verified programmatically, including the behavior-dependent guard red-flag
capability (confirmed via a throwaway probe).

### Gaps Summary

No phase-107 gaps. The phase goal is achieved: the async-safety guard lands and is
self-enforcing, the supply-chain posture is hardened (SHA pins + dependabot + mix_audit +
least-privilege permissions), the `mix ci` DX layer mirrors the settled merge-blocking set,
and the faithful Linux-Chromium repro + single contrast constant are wired with byte-identical
results.

**Known external (NON-phase-107) condition — noted, not a gap:**
`mix ci` currently exits non-zero because of a single pre-existing test failure at
`test/install_smoke/release_docs_parity_test.exs:319` — a docs-content assertion
(`running =~ "Package Consumer Proof Matrix"`) on `RUNNING.md`. Verified phase-independent:
- Phase 107's 12 commits (`e4e3186^..514ebfc`) do NOT touch `RUNNING.md` or
  `release_docs_parity_test.exs` (`git diff --name-only … | grep -iE 'RUNNING|release_docs_parity'` empty).
- Neither file is modified in the working tree.
- This failure is owned by a separate, currently-stashed `.planning` archive-cleanup change
  set and fails identically with phase-107 changes reverted.
It does not invalidate the HARD-03 `mix ci` truth: the alias is correctly composed and runs the
default-tag suite; the lone failure is external. Recommend closing the external docs-parity
failure under its own change set before relying on a clean local `mix ci` exit 0.

---

_Verified: 2026-06-22T16:30:00Z_
_Verifier: Claude (gsd-verifier)_
