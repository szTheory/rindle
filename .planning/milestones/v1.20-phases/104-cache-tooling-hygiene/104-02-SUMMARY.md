---
phase: 104-cache-tooling-hygiene
plan: 02
subsystem: ci-cd
tags: [ci, github-actions, composite-action, cache, dialyzer, plt, lockfile, lint, dx]

requires:
  - phase: 104-01
    provides: "setup-elixir composite (uses: ./.github/actions/setup-elixir) with deps-cache-hit / build-cache-hit outputs"
provides:
  - "quality job migrated onto the setup-elixir composite (matrix-driven canary, D-03)"
  - "PLT restore/save split that persists the built PLT before advisory dialyzer analysis (CACHE-03)"
  - "CACHE-04 lockfile-drift gates (--check-locked both cells, --check-unused OTP27-only)"
  - "CACHE-05 lint de-dup: format/credo/doctor run once on the 1.17/27 lint cell"
affects:
  - "Phase 104 Wave 3-4 adoption plans (optional-dependencies, integration, package-consumer, release.yml callers)"
  - "Phase 105 (CI Summary aggregate), 106 (lane/trigger split), 107 (SHA-pin / mix ci)"

tech-stack:
  added: []
  patterns:
    - "actions/cache/restore@v4 + build-if-miss + actions/cache/save@v4 placed BEFORE an advisory analysis step (save-before-analysis, D-08)"
    - "PLT cache key hashing mix.exs + .dialyzer_ignore.exs (not mix.lock) so dep bumps don't invalidate the multi-minute PLT (D-07)"
    - "matrix include flag (lint: true) + if: matrix.lint to run version-invariant work on a single home pair (D-12)"
    - "OTP-cell-guarded lockfile check (if: matrix.otp == '27') to dodge a conditional-dep false positive (D-11)"

key-files:
  created: []
  modified:
    - .github/workflows/ci.yml

key-decisions:
  - "PLT key resolved-version segments fall back to coarse matrix.otp/matrix.elixir — the setup-elixir composite does not surface its internal setup-beam resolved OTP/Elixir at job scope (only deps/build cache-hit outputs); documented fallback per plan Task 3."
  - "Composite called with install-deps: false so the quality job owns its own deps.get carrying the CACHE-04 gate flags (D-10)."
  - "lint home pair = newest (1.17/27) so the formatter enforces an up-to-date contributor's local output (D-12)."

patterns-established:
  - "save-before-analysis: cache/save@v4 guarded cache-hit != 'true' (NOT if: always()) precedes continue-on-error analysis so built artifacts persist regardless of advisory outcome"
  - "grep-able run marker ('lint-cell: format running') to assert a matrix-gated step actually fired vs silently skipped behind a green check"

requirements-completed: [CACHE-01, CACHE-03, CACHE-04, CACHE-05]

duration: 4min
completed: 2026-06-21
status: complete
---

# Phase 104 Plan 02: Quality Job Migration + CACHE-03/04/05 Summary

**The matrix-driven `quality` job now `uses: ./.github/actions/setup-elixir` (the D-03 canary), splits the Dialyzer PLT into restore→build→save-before-analysis so the built PLT survives advisory analysis (CACHE-03), gates lockfile drift (--check-locked both cells / --check-unused OTP27-only, CACHE-04), and de-dups version-invariant lint onto the 1.17/27 cell (CACHE-05) — with name: CI, the Quality required-check NAMEs, and the filename byte-identical.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-06-21T16:44Z (approx)
- **Completed:** 2026-06-21T16:48:38Z
- **Tasks:** 3
- **Files modified:** 1 (`.github/workflows/ci.yml`)

## Accomplishments

- **Task 1 (CACHE-01, D-03 canary):** Replaced the inline `setup-beam` + deps-cache + build-cache triplet in `quality` with one `uses: ./.github/actions/setup-elixir` step (`id: setup`, `mix-env: test`, `install-deps: false`). Repointed the OBS-01 cache summary's deps/build rows to `steps.setup.outputs.deps-cache-hit` / `build-cache-hit` and the plt row to the renamed `steps.plt_cache` id, keeping the `|| 'false'` fallback and the exact table markdown so the rendered summary stays byte-equivalent.
- **Task 2 (CACHE-04, D-10/D-11):** Added `mix deps.get --check-locked` (unguarded — both cells) and a separate `mix deps.unlock --check-unused` guarded `if: matrix.otp == '27'`, placed after the composite (deps available) and before compile.
- **Task 3 (CACHE-03 + CACHE-05):** Split the single PLT `actions/cache@v4` into `actions/cache/restore@v4` (`id: plt_cache`) → build-if-miss → `actions/cache/save@v4` placed **before** the advisory `mix dialyzer` analysis, guarded `cache-hit != 'true'` (not `if: always()`). PLT key now `plt-v1-<os>-<arch>-otp<otp>-elixir<elixir>-${{ hashFiles('mix.exs', '.dialyzer_ignore.exs') }}`. Added `lint: true` to the 1.17/27 matrix include and guarded format/credo/doctor with `if: ${{ matrix.lint }}`, preserving credo/doctor `continue-on-error`, and added a grep-able `lint-cell: format running` marker.

## Task Commits

Each task was committed atomically:

1. **Task 1: Migrate quality onto setup-elixir + repoint OBS-01 summary** - `7de1d48` (feat)
2. **Task 2: CACHE-04 lockfile-drift gates** - `7c680af` (feat)
3. **Task 3: PLT restore/save split (CACHE-03) + lint de-dup (CACHE-05)** - `ff99b3e` (feat)

**Plan metadata:** (final docs commit — SUMMARY.md / STATE.md / ROADMAP.md / REQUIREMENTS.md)

## Files Created/Modified

- `.github/workflows/ci.yml` — quality job: composite migration, OBS-01 summary repoint, lockfile gates, PLT restore/save split, lint de-dup. No other job touched.

## Decisions Made

- **PLT key resolved-version source = coarse matrix values (fallback path).** Task 3 instructed reusing the composite's resolved OTP/Elixir outputs if exposed. The `setup-elixir` composite (104-01) exposes only `deps-cache-hit` / `build-cache-hit`; its `steps.beam` resolved-version outputs are internal to the composite and not reachable at the caller's job scope. Per the documented fallback, the PLT prefix uses `matrix.otp` / `matrix.elixir`. The deps/_build keys are unaffected (the composite computes those internally from its own `steps.beam` outputs).
- **PLT save precedes analysis — confirmed.** Programmatic check: index of `actions/cache/save@v4` < index of `mix dialyzer --format github`, and no `if: always()` between them. This is the CACHE-03 crux: the built PLT is persisted before the continue-on-error `mix dialyzer` runs.
- **Lint log-evidence plan.** The format step on the lint cell emits `echo "lint-cell: format running"` before `mix format --check-formatted`, gated `if: ${{ matrix.lint }}` with `lint: true` only on the 1.17/27 include. Expected result on the next CI run: the marker line appears in the **Quality (1.17, 27)** job log and is **absent** from the **Quality (1.15, 26)** job log (where format/credo/doctor are skipped). credo and doctor retain `continue-on-error: true` (de-dup only, no gate tightening).

## Deviations from Plan

None — plan executed exactly as written. The PLT resolved-version fallback to `matrix.otp`/`matrix.elixir` is the plan's own documented Task-3 contingency, not an unplanned deviation.

## Issues Encountered

- **Atomic commit split of interleaved hunks.** All three tasks edit a single file (`ci.yml`) and their diff hunks interleave (e.g. lockfile gates and lint guards sit in adjacent regions). Resolved by building per-task patches with `git apply --cached` against a freshly-regenerated index diff after each commit, splitting the one mixed hunk into a Task-2-only sub-hunk (pure additions between `install_ffmpeg.sh` and `Compile`). Each commit's working-tree/index state was verified to apply cleanly and parse as valid YAML.
- **Plan verify regex window for the --check-unused guard.** The D-11 guard (`if: matrix.otp == '27'`) is directly on the step adjacent to its `run:` line, but an over-long explanatory comment initially pushed the `matrix.otp` token past the plan's 400-char backward-search window. Shortened the comment so the literal verify passes; the guard itself was always structurally correct.

## Validation Results

- **YAML:** `ci.yml` parses (`yaml.safe_load`) after every task and on the committed file.
- **actionlint (v1.7.12):** 6 findings before and after — identical to the documented pre-existing baseline (SC2209 on `MIX_ENV=test mix …` lines; `property "elixir" is not defined` at junit-coverage artifact-name lines in non-matrix jobs). **No new findings introduced.** The one quality-job SC2209 (`MIX_ENV=test mix doctor`) is pre-existing and now additionally gated by `if: matrix.lint`.
- **Task 1:** `uses: ./.github/actions/setup-elixir` present; `name: CI` (line 1) and `name: Quality` intact; no dangling `steps.deps-cache` / `steps.build-cache` references remain inside the quality job (the two remaining references at lines ~348/657 belong to the out-of-scope `integration` and `package-consumer` jobs).
- **Task 2:** `deps.get --check-locked` present and unguarded; exactly one `deps.unlock --check-unused`, guarded `if: matrix.otp == '27'` (within the plan's 400-char window).
- **Task 3:** `actions/cache/restore@v4` (id `plt_cache`) + `actions/cache/save@v4` present; the bare single-block PLT `actions/cache@v4` is gone; key hashes `mix.exs` + `.dialyzer_ignore.exs` (no mix.lock); save precedes dialyzer analysis with no `if: always()`; `lint: true` + `matrix.lint` present; credo/doctor keep `continue-on-error`.

## Prohibitions Held (D-16)

- `grep -c 'workflow_call:' ci.yml` == **0** (no reusable workflow).
- No new top-level `CI Summary` / aggregate job (Phase 105 boundary) — `grep -c 'CI Summary'` == 0.
- No `concurrency:` block added (Phase 106 boundary) — count 0.
- No third-party action SHA-pin and no `mix ci` alias introduced (Phase 107 boundary); the composite is referenced via in-repo `uses: ./…`.
- Quality required-check NAMEs (`Quality (1.15, 26)` / `Quality (1.17, 27)`), `name: CI`, and the `ci.yml` filename byte-identical (D-04, D-15).

## Known Stubs

None. All edits are concrete workflow steps wired to real composite outputs and mix tasks.

## Next Phase Readiness

- The matrix-driven canary proves the `setup-elixir` composite, its cache outputs, and the OBS-01 summary on the hardest caller — Wave 3-4 adoption plans (optional-dependencies, integration, package-consumer, release.yml) can now fan out onto the same composite with confidence.
- **Open empirical confirmations for the next CI run** (observational, non-blocking): (1) the `lint-cell: format running` marker appears only in the 1.17/27 job log; (2) the OBS-01 cache table renders byte-equivalent to the pre-migration table; (3) the deps/_build resolved-version cache keys hit as before. The PLT-key coarse-version fallback (matrix vs resolved patch level) is functionally correct but slightly coarser than the deps/_build keys — a future tightening could surface resolved OTP/Elixir as composite outputs if desired.

## Self-Check: PASSED

- `.github/workflows/ci.yml` exists and parses as valid YAML on the committed HEAD.
- `.planning/phases/104-cache-tooling-hygiene/104-02-SUMMARY.md` exists.
- All three task commits present in git history: `7de1d48`, `7c680af`, `ff99b3e`.
- actionlint findings unchanged from baseline (6, no new findings).

---
*Phase: 104-cache-tooling-hygiene*
*Completed: 2026-06-21*
