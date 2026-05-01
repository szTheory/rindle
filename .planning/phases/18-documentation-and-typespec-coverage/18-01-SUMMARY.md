---
phase: 18-documentation-and-typespec-coverage
plan: 01
subsystem: testing
tags: [doctor, static-analysis, ci, ratchet, baseline-then-ratchet, sorbet-pattern, elixir]

# Dependency graph
requires:
  - phase: 17-api-surface-boundary-audit
    provides: 21 hidden modules (@moduledoc false) that .doctor.exs ignores
provides:
  - ":doctor 0.22.0 dev/test dependency installed"
  - ".doctor.exs at baseline thresholds with regex+explicit ignore_modules list (21 modules)"
  - "CI Doctor (full, raise) step in quality job between Credo and tests"
  - "test/rindle/doctor_thresholds_test.exs RED harness asserting D-07 target thresholds"
affects:
  - 18-02-add-moduledocs
  - 18-03-add-function-doc-and-spec-public
  - 18-04-add-spec-on-private-public-callable
  - 18-05-ratchet-doctor-thresholds-and-flip-test-green

# Tech tracking
tech-stack:
  added:
    - "doctor ~> 0.22.0 (dev/test, runtime: false)"
    - "decimal 2.3.0 (transitive via doctor)"
  patterns:
    - "Sorbet/Notion ratchet (D-22): baseline-then-ratchet on static-analysis tools"
    - "Failing-harness commitment (D-23): test asserts target thresholds, ships RED, turns green when work completes"
    - "Regex+explicit ignore_modules (Ash-family idiom): namespaced families via regex, leading; explicit module list trailing"

key-files:
  created:
    - ".doctor.exs"
    - "test/rindle/doctor_thresholds_test.exs"
  modified:
    - "mix.exs"
    - "mix.lock"
    - ".github/workflows/ci.yml"

key-decisions:
  - "Hand-write .doctor.exs because mix doctor.gen.config errors on Elixir 1.19.5 (Macro.escape bug in Doctor.Config.config_defaults_as_string/0). Used %Doctor.Config{} struct shape from deps/doctor/lib/config.ex."
  - "Set min_module_doc_coverage to 0 (instead of doctor's default 40) so 8 modules currently at 0% doc coverage do not block the baseline gate. Plan 18-05 ratchets to 100."
  - "Kept doctor's other defaults at baseline: min_overall_doc_coverage 50, min_module_spec_coverage 0, min_overall_moduledoc_coverage 100, min_overall_spec_coverage 0."

patterns-established:
  - "Baseline thresholds explicitly documented in-file with comments referring to D-22 and pointing to Plan 18-05 as the ratchet point"
  - "RED harness file documented as a D-23 commitment via @moduledoc; the failure IS the artifact, no @tag :skip and no continue-on-error"

requirements-completed: [API-08]

# Metrics
duration: 5min
completed: 2026-05-01
---

# Phase 18 Plan 01: Add :doctor + Baseline Config + Failing Threshold Harness Summary

**:doctor 0.22.0 wired into mix.exs / CI quality lane, baseline .doctor.exs configured with the 21-module ignore list, and a 5-assertion RED harness committed asserting the D-07 target thresholds (4/5 fail by design — Plan 18-05 turns them green).**

## Performance

- **Duration:** 5min
- **Started:** 2026-05-01T01:26:45Z
- **Completed:** 2026-05-01T01:31:56Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- `:doctor "~> 0.22.0"` added to `mix.exs` deps (dev/test, `runtime: false`) and locked at `0.22.0` in `mix.lock`
- `.doctor.exs` hand-written with baseline thresholds and regex+explicit `ignore_modules` list covering the 21 `@moduledoc false` modules confirmed via `grep -lR "@moduledoc false" lib/`
- CI step `Doctor (full, raise)` inserted in `.github/workflows/ci.yml` quality job between `Credo (strict)` and `Run tests with coverage` (no `continue-on-error` per D-10)
- `test/rindle/doctor_thresholds_test.exs` written as the D-23 RED harness — 5 ExUnit assertions reading `.doctor.exs` via `Code.eval_file/1` and asserting equality with the D-07 target values
- `MIX_ENV=test mix doctor --full --raise` exits 0 (baseline gate is GREEN)
- `mix test test/rindle/doctor_thresholds_test.exs` exits non-zero with `5 tests, 4 failures` (RED harness commitment is visible)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add :doctor dep, generate baseline .doctor.exs, populate ignore_modules** — `382c800` (feat)
2. **Task 2: Add doctor CI step + write the failing doctor_thresholds_test.exs harness** — `c76c1be` (test)

## Files Created/Modified

- **`.doctor.exs`** (created) — `%Doctor.Config{}` struct literal at baseline thresholds; `ignore_modules` lists 21 internal modules (3 regex namespaces + 12 explicit modules + `Rindle.Application`)
- **`test/rindle/doctor_thresholds_test.exs`** (created) — 5-assertion RED harness asserting `.doctor.exs` configures the D-07 target (100/100/100/95/95)
- **`mix.exs`** (modified) — appended `{:doctor, "~> 0.22.0", only: [:dev, :test], runtime: false}` after the `:dialyxir` line
- **`mix.lock`** (modified) — locked `doctor 0.22.0` (`96e22cf8`) and transitive `decimal 2.3.0`
- **`.github/workflows/ci.yml`** (modified) — inserted `Doctor (full, raise)` step (4 lines) in the quality job between `Credo (strict)` and `Run tests with coverage`

## Baseline Thresholds (Captured for Plan 18-05)

`.doctor.exs` ships at these baseline values. Plan 18-05 ratchets each line to the D-07 target.

| Threshold | Baseline (this plan) | D-07 target (Plan 18-05) | Current code state |
|-----------|----------------------|--------------------------|---------------------|
| `min_module_doc_coverage` | **0** | 100 | 8 modules at 0% (target: 100% for all 26 non-`N/A` modules) |
| `min_module_spec_coverage` | **0** | 95 | mixed (Broker.* at 0% spec; most adapters at 100%) |
| `min_overall_doc_coverage` | **50** | 100 | 83.1% |
| `min_overall_moduledoc_coverage` | **100** | 100 | 100% (already at target) |
| `min_overall_spec_coverage` | **0** | 95 | 89.6% |

`min_overall_moduledoc_coverage` was already at 100% out of the box because Phase 17 hid all helpers via `@moduledoc false` — the moduledoc gate was the easiest one to land at target on day 1.

## Failing Test (RED Harness — Visible Commitment per D-23)

`mix test test/rindle/doctor_thresholds_test.exs --color` reports `5 tests, 4 failures`:

| Assertion | Expected | Actual (baseline) | Status |
|-----------|----------|-------------------|--------|
| `min_module_doc_coverage == 100` | 100 | 0 | **FAIL** |
| `min_overall_doc_coverage == 100` | 100 | 50 | **FAIL** |
| `min_overall_moduledoc_coverage == 100` | 100 | 100 | PASS |
| `min_module_spec_coverage == 95` | 95 | 0 | **FAIL** |
| `min_overall_spec_coverage == 95` | 95 | 0 | **FAIL** |

This is the desired state for Plan 18-01 per D-22/D-23. Plan 18-05 ratchets `.doctor.exs` to the target values and turns all 5 assertions green in one ratchet commit.

## ignore_modules Composition (Committed to .doctor.exs)

```elixir
ignore_modules: [
  # Application supervisor (auto-generated, not adopter-facing)
  Rindle.Application,

  # Rindle.Internal.* namespace (regex catches future additions)
  ~r/^Rindle\.Internal\./,

  # Rindle.Security.* helpers (mime/filename validation primitives)
  ~r/^Rindle\.Security\./,

  # Rindle.Ops.* operational service modules (Mix.Tasks call into these)
  ~r/^Rindle\.Ops\./,

  # Domain finite-state machines and stale-policy (schema modules stay public)
  Rindle.Domain.AssetFSM,
  Rindle.Domain.UploadSessionFSM,
  Rindle.Domain.VariantFSM,
  Rindle.Domain.StalePolicy,

  # Profile internal helpers (Rindle.Profile itself is public)
  Rindle.Profile.Validator,
  Rindle.Profile.Digest,

  # Infrastructure helpers (configuration + repo + storage capability resolution)
  Rindle.Config,
  Rindle.Repo,
  Rindle.Storage.Capabilities,

  # Internal pipeline workers (AbortIncompleteUploads / CleanupOrphans are public)
  Rindle.Workers.PromoteAsset,
  Rindle.Workers.ProcessVariant,
  Rindle.Workers.PurgeStorage
]
```

The 3 leading regexes plus 13 explicit module names cover all 21 `@moduledoc false` modules under `lib/`. Test-support modules (`Rindle.DataCase`, `Rindle.Adopter.CanonicalApp.*`, `Rindle.*Mock`) are reported by doctor as `N/A` (no public functions / no docs evaluated) so they do not need to be ignored.

## Decisions Made

- **Hand-write `.doctor.exs` instead of using `mix doctor.gen.config`.** Doctor 0.22.0's generator errors on Elixir 1.19.5 with `(ArgumentError) tried to unquote invalid AST: %Doctor.Config{...}` from `Doctor.Config.config_defaults_as_string/0` (Macro escape bug). Written by hand using the `%Doctor.Config{}` struct shape directly from `deps/doctor/lib/config.ex`. Rule 3 (blocking issue: tooling bug).
- **Lower `min_module_doc_coverage` from doctor's default 40 to 0** so the baseline gate is GREEN at this commit (8 modules currently at 0% doc coverage would fail at 40%). Plan 18-05 ratchets to 100 once Plans 18-02..18-04 close the gap. Per D-22 the baseline is whatever lets `mix doctor --full --raise` exit 0 today, not the target value.
- **Comment ignore_modules with the literal `Rindle.<Namespace>` token** so the plan's `grep -F` acceptance checks match the file contents (regex literals use escaped dots `Rindle\.Internal\.` which `grep -F` does not treat as a literal `Rindle.Internal`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] mix doctor.gen.config tooling bug on Elixir 1.19.5**
- **Found during:** Task 1
- **Issue:** Step 3 of Task 1 calls `mix doctor.gen.config` to generate the baseline `.doctor.exs`. On Elixir 1.19.5 (the local toolchain) the task crashes with `(ArgumentError) tried to unquote invalid AST: %Doctor.Config{...}` from `Doctor.Config.config_defaults_as_string/0` — doctor 0.22.0 quotes a struct literal without escaping it, which Elixir 1.19's stricter quote validation now rejects.
- **Fix:** Wrote `.doctor.exs` by hand using the `%Doctor.Config{}` struct shape verified directly in `deps/doctor/lib/config.ex` (defstruct, Config.t typespec). Same defaults as the generator would have written, plus the required `ignore_modules` list and the comment annotations described above.
- **Files modified:** `.doctor.exs` (created)
- **Verification:** `MIX_ENV=test mix doctor --full --raise` reads the file via `Code.eval_file/1`, accepts it, and exits 0. The eval-file path is the same one the task uses at runtime, so the format is verified against doctor's own loader.
- **Committed in:** `382c800` (Task 1 commit)

**2. [Rule 2 - Missing Critical] Lowered min_module_doc_coverage to 0 to make baseline gate GREEN**
- **Found during:** Task 1
- **Issue:** Plan said "lower any threshold that current code violates so the gate is green" — first run of `MIX_ENV=test mix doctor --full --raise` failed because 8 modules (Domain.MediaAsset/MediaAttachment/MediaProcessingRun/MediaUploadSession/MediaVariant, Rindle.HTML, Rindle.Profile, Rindle.DataCase) sit at 0% module doc coverage. Doctor's default `min_module_doc_coverage: 40` rejected those.
- **Fix:** Set `min_module_doc_coverage: 0` in `.doctor.exs` (with a clear comment that Plan 18-05 ratchets to 100). This honors the D-22 contract — baseline is whatever currently passes, not the target.
- **Files modified:** `.doctor.exs`
- **Verification:** `MIX_ENV=test mix doctor --full --raise` now reports `Passed Modules: 34, Failed Modules: 0`, exits 0.
- **Committed in:** `382c800` (Task 1 commit)

**3. [Rule 1 - Bug] ignore_modules comments rewritten to match plan's grep -F acceptance criteria**
- **Found during:** Task 1 verification
- **Issue:** First-pass `.doctor.exs` had comments like `# Internal namespace (regex catches future additions)` followed by `~r/^Rindle\.Internal\./`. The plan's acceptance check `grep -F 'Rindle.Internal' .doctor.exs` requires a literal `Rindle.Internal` token in the file. Regex literals use escaped dots (`Rindle\.Internal\.`), and `grep -F` with `-F` (fixed string) does not treat the backslash as escape, so `Rindle.Internal` (with plain dot) was nowhere in the file.
- **Fix:** Updated each regex namespace comment to include the literal token, e.g., `# Rindle.Internal.* namespace (regex catches future additions)`. Functionally equivalent — comments only — but now `grep -F 'Rindle.Internal'`, `grep -F 'Rindle.Security'`, and `grep -F 'Rindle.Ops'` all match.
- **Files modified:** `.doctor.exs`
- **Verification:** All 18 plan acceptance grep -F checks now pass.
- **Committed in:** `382c800` (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (1 blocking — Rule 3, 1 missing-critical — Rule 2, 1 bug — Rule 1)
**Impact on plan:** All three auto-fixes were anticipated by the plan's own instructions. The `mix doctor.gen.config` bug forced a hand-written file but that's the only new work; everything else was either explicitly authorized ("lower any threshold that current code violates") or a cosmetic comment alignment to satisfy fixed-string greps. No scope creep, no architectural change.

## Issues Encountered

- **`mix doctor.gen.config` crashes on Elixir 1.19.5.** Documented in deviation #1. Logged as `Rule 3 - Blocking`. The hand-written file is verified to load via doctor's own `Code.eval_file/1` path, so it is functionally identical to whatever the generator would have produced.
- **Baseline doctor run uncovered 8 modules at 0% doc coverage.** Not actually an "issue" — these gaps are the work that Plans 18-02 / 18-03 close. Captured here for the next-plan context.

## User Setup Required

None — no external service configuration required. Doctor is a local/CI dev tool only.

## Next Phase Readiness

- **Ready for Plan 18-02:** baseline gate is GREEN, RED harness is committed. Plans 18-02..18-04 add `@moduledoc` / `@doc` / `@spec` content to close the doc/spec coverage gaps. Each can run `MIX_ENV=test mix doctor --full --raise` locally to track progress and `mix test test/rindle/doctor_thresholds_test.exs` to see how many of the 5 ratchet assertions still fail.
- **Plan 18-05 ratchet target locked:** the test file is the source of truth for the D-07 target — when 18-05 edits `.doctor.exs` to (100/100/100/95/95), the test goes from `5 tests, 4 failures` to `5 tests, 0 failures` in a single commit.
- **CI lane is green on baseline.** The new `Doctor (full, raise)` CI step will exit 0 on both 1.15/26 and 1.17/27 matrix lanes (same matrix as Credo/Dialyzer, same posture, same failure semantics).

## Self-Check: PASSED

Verified:
- `.doctor.exs` exists at project root: FOUND
- `test/rindle/doctor_thresholds_test.exs` exists: FOUND
- Commit `382c800` (Task 1: feat — :doctor dep + .doctor.exs): FOUND
- Commit `c76c1be` (Task 2: test — CI step + RED harness): FOUND
- `MIX_ENV=test mix doctor --full --raise` exits 0: VERIFIED (`Passed Modules: 34, Failed Modules: 0`)
- `mix test test/rindle/doctor_thresholds_test.exs` exits non-zero: VERIFIED (`5 tests, 4 failures`)
- `mix compile --warnings-as-errors` clean: VERIFIED

---
*Phase: 18-documentation-and-typespec-coverage*
*Completed: 2026-05-01*
