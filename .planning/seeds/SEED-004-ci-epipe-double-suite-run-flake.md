---
id: SEED-004
status: open
planted: 2026-06-26
planted_during: post-v1.20 maintenance — cleaning up red `main` after the phase-dir archive (PR #45)
trigger_when: "Next CI/DX reliability milestone, OR sooner if the `:epipe` flake recurs often enough to cost real rerun time / erode trust in the gate. Surface whenever scope touches CI/CD, test-suite runtime, ExUnit determinism, coverage tooling, or developer experience. Natural companion to [[SEED-003]] (which became v1.20)."
scope: Small-Medium
---

# SEED-004: CI `:epipe` flake from double suite run (coveralls + coveralls.json)

## Why This Matters

Every CI job that runs the default suite runs the **entire ExUnit suite twice**:

1. **`Run tests with coverage`** → `mix coveralls --slowest 20` — the **gating** run.
2. **`Generate coverage JSON artifact`** → `mix coveralls.json` — re-runs the WHOLE suite again
   just to emit `cover/excoveralls.json` for artifact upload.

This doubles wall-clock for the test phase AND doubles exposure to non-deterministic
subprocess failures. Tests that spawn external processes (ffmpeg, etc.) intermittently crash
with `** (EXIT from #PID<...>) :epipe` (broken pipe — the port's reader closed before the write
finished). When it hits the **second** run, the job fails even though the gating run was clean.

**Observed twice on 2026-06-26** while cleaning up red `main` (PR #45 era):

| Run | Job | Test | First run (`mix coveralls`) | Second run (`mix coveralls.json`) |
|---|---|---|---|---|
| PR #45 CI (28263327335) | `Integration` | `test/rindle/processor/ffmpeg_test.exs:32` | ✅ 0 failures | ❌ `:epipe` |
| post-merge main (28263956271) | `Quality (1.17, 27)` | `test/rindle/ops/lifecycle_repair_test.exs:122` | ✅ 0 failures | ❌ `:epipe` |

Both **cleared on `gh run rerun --failed`** → non-deterministic, not a real regression. But each
recurrence costs a full rerun cycle (~10–15 min) and momentarily reds `main` / blocks the gate,
which also blocks release-please. It's a low-grade but real trust/velocity tax.

## When to Surface

Next CI/DX reliability milestone (companion to the v1.20 audit), or sooner if the flake recurs
often. Self-contained, high-DX-leverage, not blocked by feature work. Phases resume at 108.

## Scope Estimate

**Small-Medium.** Likely one focused PR, not a milestone. Pick a fix path (below), implement,
verify against a few green runs.

## Fix Ideas (pick after measuring)

- **(a) Stop re-running the suite for coverage JSON (preferred).** Generate the JSON from the
  gating run instead of a second full execution — e.g. run only `mix coveralls.json` and derive
  the gate from its result/exit code, or configure excoveralls for a single-run dual-output
  (console gate + JSON artifact). Halves test wall-clock AND halves `:epipe` exposure in one move.
- **(b) Harden the process-spawning tests against `:epipe`.** Ensure the port/subprocess drains
  and is awaited; trap/retry on broken pipe at the `Subprocess.run` seam; don't write to a pipe
  whose reader may have exited. This is the correctness-true fix for the underlying race.
- **(c) Tag + serialize the subprocess tests.** `@moduletag`-isolate ffmpeg/external-process
  tests and run them `async: false` / in their own non-partitioned lane to cut contention. Weakest
  option — masks rather than fixes.

Recommendation: **(a) + (b)** together — (a) removes the redundant second run (biggest win), (b)
fixes the actual broken-pipe race so it can't bite the single remaining run either.

## Breadcrumbs

- `.github/workflows/ci.yml` — steps **`Run tests with coverage`** (`mix coveralls`, gating) and
  **`Generate coverage JSON artifact`** (`mix coveralls.json`, `if: always()`); the comment there
  already notes the gating step "STAYS `mix coveralls` (NOT replaced by coveralls.json)".
- `test/rindle/processor/ffmpeg_test.exs:32` and `test/rindle/ops/lifecycle_repair_test.exs:122`
  — the two tests caught `:epipe`-ing (both spawn/await external work).
- `mix.exs` — `excoveralls` dep + `coveralls` task config.

## Related

- [[SEED-003]] — CI/CD performance + reliability audit (became v1.20). This is the reliability
  tail SEED-003 flagged ("make sure things aren't flaky… deterministic as possible gates") but
  that v1.20 did not specifically close; the double-suite-run is a concrete instance.
- [[reference_ci_lanes_only_on_main]] — some lanes run only on `main` push, so flakes like this
  reach `main` undetected by PR CI (relevant to where/whether the fix is gated).
