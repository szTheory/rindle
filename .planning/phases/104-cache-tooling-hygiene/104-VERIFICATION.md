---
phase: 104-cache-tooling-hygiene
verified: 2026-06-21T00:00:00Z
status: passed
score: 24/24 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 104: Cache & Tooling Hygiene Verification Report

**Phase Goal:** Cache & Tooling Hygiene — composite setup action, correct cache keys, PLT restore/save split, lockfile drift gates, lint de-dup (single-workflow shape; low-risk). Part of milestone v1.20 "CI/CD Performance" whose hard constraint is ZERO `lib/` change.
**Verified:** 2026-06-21
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

This is a CI/CD config phase (GitHub Actions YAML + composite actions). There is no application build/test to run for goal verification; every truth is directly observable via file content, grep wiring counts, `actionlint`, and `git diff`. No behavior-dependent (runtime state-transition / cancellation) truths exist, so no truth routes to PRESENT_BEHAVIOR_UNVERIFIED.

### Observable Truths

ROADMAP Success Criteria (the contract) + the 24 PLAN-frontmatter truths across the 4 plans, deduplicated by concern.

| #  | Truth | Status | Evidence |
| -- | ----- | ------ | -------- |
| 1  | (SC1/CACHE-01) `setup-elixir` composite is the single source of truth for env setup + cache keys, adopted across duplicating jobs | ✓ VERIFIED | `.github/actions/setup-elixir/action.yml` `runs.using: composite`; `uses: ./.github/actions/setup-elixir` count == 10 in ci.yml (matches expected) |
| 2  | (CACHE-01) `setup-minio` composite encapsulates the docker-run/mc/bucket trio with health wait | ✓ VERIFIED | `.github/actions/setup-minio/action.yml` has `minio/minio`, `mc mb --ignore-existing local/rindle-test`, `/minio/health/ready` 30-iter loop; no `RINDLE_MINIO_*` env baked in |
| 3  | (CACHE-01) `setup-minio` adopted: 5 ci.yml jobs + 2 release.yml jobs | ✓ VERIFIED | ci.yml count == 5; release.yml count == 2 (both match expected) |
| 4  | (CACHE-01) composite exposes deps/_build cache-hit outputs; OBS-01 summary reads them | ✓ VERIFIED | `outputs.deps-cache-hit`/`build-cache-hit` in action.yml; ci.yml summary rows read `steps.setup.outputs.deps-cache-hit`/`build-cache-hit`; zero dangling `steps.deps-cache`/`steps.build-cache` refs |
| 5  | (SC2/CACHE-02) deps/_build keys carry OS+arch+resolved-OTP+resolved-Elixir+MIX_ENV+mix.lock-hash+v1 buster | ✓ VERIFIED | action.yml L81/L90 key template = `<ns>-v1-${runner.os}-${runner.arch}-otp${steps.beam.outputs.otp-version}-elixir${steps.beam.outputs.elixir-version}-${inputs.mix-env}-${hashFiles('mix.lock')}` |
| 6  | (CACHE-02/D-09) repo-root `hashFiles('mix.lock')`, NOT `**/mix.lock`; restore-keys truncate at mix-env (never cross toolchains) | ✓ VERIFIED | grep `**/mix.lock` == 0; restore-keys stop at `${{ inputs.mix-env }}-` |
| 7  | (D-06) `cache-prefix: no-optional` yields `deps-no-optional-`/`build-no-optional-` namespace | ✓ VERIFIED | `Compute cache namespaces` step maps non-`default` → `deps-<prefix>`; optional-dependencies job calls with `cache-prefix: no-optional` (ci.yml L263) |
| 8  | (SC3/CACHE-03) PLT restore/save split persists built PLT before advisory analysis | ✓ VERIFIED | `actions/cache/restore@v4` id `plt_cache` (L187) → build-if-miss (L199) → `actions/cache/save@v4` (L208) BEFORE `mix dialyzer --format github` (programmatic save-idx < dialyzer-idx == true) |
| 9  | (CACHE-03/D-08) PLT save guarded `cache-hit != 'true'`, NOT `if: always()` | ✓ VERIFIED | save step L207 `if: steps.plt_cache.outputs.cache-hit != 'true'`; no `if: always()` between save and analysis |
| 10 | (CACHE-03/D-07) PLT key hashes `mix.exs`+`.dialyzer_ignore.exs`, NOT mix.lock; prefix `plt-v1-`+OS+arch+OTP+Elixir | ✓ VERIFIED | L191/L211 `plt-v1-...-${{ hashFiles('mix.exs', '.dialyzer_ignore.exs') }}`; no mix.lock in PLT key |
| 11 | (SC4/CACHE-04) `mix deps.get --check-locked` runs on BOTH matrix cells (unguarded) | ✓ VERIFIED | ci.yml L89 `run: mix deps.get --check-locked`, no matrix `if:` guard |
| 12 | (CACHE-04/D-11) `mix deps.unlock --check-unused` guarded `if: matrix.otp == '27'` | ✓ VERIFIED | L95-97 step `if: matrix.otp == '27'` then `run: mix deps.unlock --check-unused`; exactly one occurrence |
| 13 | (SC5/CACHE-05) version-invariant lint runs once on primary pair via `lint: true` + `if: matrix.lint` | ✓ VERIFIED | `lint: true` on 1.17/27 include (L36); format/credo/doctor each `if: ${{ matrix.lint }}` (L107/118/123); credo+doctor keep `continue-on-error: true`; `lint-cell: format running` marker present |
| 14 | (CACHE-05/D-13) repo-root `.tool-versions` pins primary pair; no `version-file:` wiring | ✓ VERIFIED | `.tool-versions` = `elixir 1.17.3-otp-27`/`erlang 27.2`/`nodejs 20.18.1`; `version-file` count across workflows+actions == 0 |
| 15 | (CACHE-05/D-14) `FedericoCarboni/setup-ffmpeg` retired in release.yml for `install_ffmpeg.sh` | ✓ VERIFIED | release.yml `FedericoCarboni/setup-ffmpeg` count == 0; `scripts/ci/install_ffmpeg.sh` referenced (count 2) and script exists on disk |
| 16 | (D-02) adoption-demo-e2e preserves CORS via `cors-allow-origin: "*"`; other callers omit it | ✓ VERIFIED | ci.yml L826 `cors-allow-origin: "*"` (single occurrence); composite injects `-e MINIO_API_CORS_ALLOW_ORIGIN` only when non-empty |
| 17 | (D-03) gcs-live secret-gated composite call keeps `enabled == 'true'` if-guard | ✓ VERIFIED | setup-elixir call at ci.yml L1125 carries the `enabled` guard in its preceding context |
| 18 | (D-01) composite does NOT compile; job-specific compile/flags stay at job level | ✓ VERIFIED | no `mix compile` in either composite; `compile --no-optional-deps --warnings-as-errors` remains at job level (count 1) |
| 19 | (D-04/D-15) all required-check job NAMEs byte-identical | ✓ VERIFIED | Quality, Integration, Contract, Proof, Package Consumer Proof Matrix + Release Preflight, Adopter, Adoption Demo Unit, Adoption Demo E2E, ADMIN-06 Optional Dependencies — each present exactly once |
| 20 | (D-15) `name: CI` (ci.yml L1) and `name: Release` (release.yml) byte-identical; filenames unchanged | ✓ VERIFIED | `head -1 ci.yml` == `name: CI`; `name: Release` present in release.yml |
| 21 | (D-16 prohibition) NO reusable workflows / `CI Summary` aggregate / concurrency / lane split (Phase 105-107 boundaries) | ✓ VERIFIED | `workflow_call:` == 0 (both files); `CI Summary` == 0; `concurrency:` == 0 |
| 22 | (D-16 prohibition) NO third-party SHA-pin, NO `mix ci` alias | ✓ VERIFIED | composites reference in-repo `uses: ./…` only; `mix ci` in actions == 0; ffmpeg moved FROM third-party TO in-repo `run:` |
| 23 | Both ci.yml and release.yml parse as valid YAML | ✓ VERIFIED | `yaml.safe_load` on both == OK |
| 24 | (milestone hard constraint) ZERO `lib/` change across the phase | ✓ VERIFIED | `git diff --stat 131fae7^..HEAD -- lib/` is empty |

**Score:** 24/24 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `.github/actions/setup-elixir/action.yml` | composite: setup-beam + deps/_build cache, resolved-version keys, cache-hit outputs | ✓ VERIFIED | 100 lines, `runs.using: composite`, 5 documented inputs, 2 outputs, full CACHE-02 key, namespace via cache-prefix, no compile |
| `.github/actions/setup-minio/action.yml` | composite: docker-run/mc/bucket trio + health wait + CORS input | ✓ VERIFIED | 44 lines, trio byte-equivalent to source job, health loop, `cors-allow-origin` input, no baked env |
| `.tool-versions` | asdf pins for primary pair, local-dev only | ✓ VERIFIED | elixir/erlang/nodejs pins; no version-file wiring |
| `.github/workflows/ci.yml` | composite adoption + PLT split + lockfile gates + lint de-dup | ✓ VERIFIED | 10 setup-elixir + 5 setup-minio adoptions; PLT split; both lockfile gates; lint de-dup; names intact |
| `.github/workflows/release.yml` | 2 setup-minio adoptions + ffmpeg swap | ✓ VERIFIED | 2 setup-minio; 0 FedericoCarboni/setup-ffmpeg; install_ffmpeg.sh wired |

### Key Link Verification

| From | To | Via | Status |
| ---- | -- | --- | ------ |
| ci.yml quality job | setup-elixir composite | `uses: ./.github/actions/setup-elixir` (matrix-driven) | ✓ WIRED |
| ci.yml OBS-01 summary | composite cache-hit outputs | reads `steps.setup.outputs.deps-cache-hit`/`build-cache-hit` | ✓ WIRED |
| setup-elixir | `erlef/setup-beam@v1` | id `beam` → resolved otp/elixir feed cache key | ✓ WIRED |
| setup-elixir | `actions/cache@v4` | deps + _build restore/save with D-05 key + cache-hit outputs | ✓ WIRED |
| PLT `actions/cache/save@v4` | dialyzer analysis | save precedes analysis in file order (D-08 crux) | ✓ WIRED |
| optional-dependencies | setup-elixir (cache-prefix) | `cache-prefix: no-optional` | ✓ WIRED |
| release.yml publish/public_verify | setup-minio | `uses: ./.github/actions/setup-minio` | ✓ WIRED |
| release.yml | `scripts/ci/install_ffmpeg.sh` | `run: bash scripts/ci/install_ffmpeg.sh` (replaces setup-ffmpeg) | ✓ WIRED |

### Requirements Coverage

All 5 phase requirement IDs from PLAN frontmatter accounted for against REQUIREMENTS.md; no orphaned IDs (REQUIREMENTS.md maps exactly CACHE-01..05 to Phase 104).

| Requirement | Source Plan(s) | Status | Evidence |
| ----------- | -------------- | ------ | -------- |
| CACHE-01 | 01, 02, 03, 04 | ✓ SATISFIED | setup-elixir (×10) + setup-minio (×5 ci + ×2 release) are single source of truth |
| CACHE-02 | 01, 03 | ✓ SATISFIED | full resolved-version key schema in composite; separate deps/_build/PLT/no-optional namespaces |
| CACHE-03 | 02 | ✓ SATISFIED | PLT restore/save split, save-before-analysis, keyed on mix.exs+.dialyzer_ignore.exs |
| CACHE-04 | 02 | ✓ SATISFIED | --check-locked both cells; --check-unused OTP27-guarded |
| CACHE-05 | 01, 02, 04 | ✓ SATISFIED | lint de-dup on 1.17/27; .tool-versions landed; ffmpeg action retired in release.yml |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| ci.yml actionlint baseline unchanged | `actionlint .github/workflows/ci.yml` | 6 findings (4× SC2209 + 2× `property "elixir" is not defined`) — matches documented pre-existing baseline | ✓ PASS |
| release.yml actionlint clean | `actionlint .github/workflows/release.yml` | 0 findings | ✓ PASS |
| ci.yml YAML valid | `yaml.safe_load` | OK | ✓ PASS |
| release.yml YAML valid | `yaml.safe_load` | OK | ✓ PASS |
| install_ffmpeg.sh exists | `test -f scripts/ci/install_ffmpeg.sh` | EXISTS | ✓ PASS |

### Probe Execution

No project probes (`scripts/*/tests/probe-*.sh`) declared or implied by this phase. SKIPPED.

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
| ---- | ------- | -------- | ------ |
| (none) | TBD/FIXME/XXX/HACK/PLACEHOLDER scan over all 4 modified config files | — | clean — zero debt markers |

The two inline `erlef/setup-beam@v1` instances remaining in ci.yml are `mux-soak` (MinIO-trio-only job; setup-beam intentionally left inline, only its MinIO trio migrated) and `gcs-soak` (plan-sanctioned DECLINED adoption — no existing cache, fully secret-gated). The 4 release.yml setup-beam instances are non-MinIO-cache jobs out of scope. All intentional and documented in the SUMMARYs. Not anti-patterns.

104-REVIEW.md reports 0 critical / 4 warning / 2 info — advisory, already triaged; its warnings are not goal failures.

### Human Verification Required

None. Every truth is directly observable via file content, grep, actionlint, and git diff. The SUMMARYs note non-blocking observational confirmations deferred to the next CI run (lint-cell marker appears only on 1.17/27; OBS-01 table renders byte-equivalent; first-run cold cache miss as the no-optional namespace re-keys onto the v1 schema) — these are expected runtime observations of an already-correct config, not verification gaps that block the goal.

### Gaps Summary

No gaps. All 24 must-have truths verified, all 5 artifacts substantive and wired, all 8 key links connected, all 5 requirements satisfied, all D-16 prohibitions held, actionlint baselines unchanged (ci.yml 6 / release.yml 0), and the milestone hard constraint (zero `lib/` change) confirmed empty. The phase goal — composite setup action, correct cache keys, PLT restore/save split, lockfile drift gates, and lint de-dup while preserving the single-workflow shape — is achieved.

---

_Verified: 2026-06-21_
_Verifier: Claude (gsd-verifier)_
