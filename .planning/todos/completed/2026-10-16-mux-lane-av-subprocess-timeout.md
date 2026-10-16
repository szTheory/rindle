completed: 2026-10-16
---
created: 2026-10-16T12:40:00.000Z
title: De-flake the AV poster-frame subprocess stall (mux lane + adoption demo E2E)
area: ci-flake
trigger: "Package Consumer Full Matrix + Release Preflight (mux) fails with ExUnit.TimeoutError at test/rindle_install_smoke_test.exs:68 (generated app), stack in Rindle.AV.Subprocess.run_isolated/5"
files:
  - test/install_smoke/generated_app_smoke_test.exs
  - lib/rindle/av/subprocess.ex
  - lib/rindle/processor/av/video.ex
---

## Problem

The main-only mux lane intermittently times out (60 s ExUnit default) in the generated Phoenix app's
"canonical AV lifecycle PLUS Mux-signed HLS streaming URL" test. The test drives
`Oban.Testing.perform_job/2` over each variant (`rindle_install_smoke_test.exs:133-135`) and stalls inside
`Rindle.AV.Subprocess.run_isolated/5` <- `Rindle.Processor.AV.Video.run_fallback_attempts/2`
(`video.ex:78`) <- `image_output/3`, i.e. the ffmpeg poster-frame subprocess.

Seen three times in six main runs, both on lock-only commits that the generated app never reads, and both passed on a
single failed-job rerun:

- run 38838770800 on be7ac7e2 (#129, demo lock), attempt 1 red, attempt 2 green
- run 38898465466 on d6074a4c (#130, demo bandit), attempt 1 red, attempt 2 green
- run 38906151474 on 2f06d5dd (#133, test/ci only), **Adoption Demo E2E** `e2e/mux-streaming.spec.js:6` red: the
  `Rindle.Workers.ProcessVariant` worker sat at `subprocess.ex:81` (the `run_isolated` receive) holding a checked-out
  Postgrex connection until DBConnection timed it out. Same stack, a second lane.

Two observations for the fix: the watchdog only fires at the MuonTrap `:timeout` + 250 ms (default 600 s), far above
any test budget, so a hung ffmpeg poster-frame call is never retried in time; and the AV call runs while the worker
holds a DB connection, so a slow call also starves the pool.

The lane runs only on main push (see reference memory "CI lanes only on main"), so the flake reddens main
without a PR signal and costs a rerun per occurrence.

## Options

1. Find why the ffmpeg fallback attempt hangs on the runner (no subprocess timeout reached before the 60 s
   ExUnit timeout?) and give `run_isolated` a bounded per-attempt timeout below the test budget.
2. Raise the generated test's `@tag timeout:` only if the AV work is legitimately slow on shared runners, with the
   subprocess timeout still bounding each attempt.

Fix in the merge-blocking path first if it can be reproduced in a PR lane.

## Solution

Resolved 2026-10-16. Root cause: MuonTrap 1.7 forks the child without redirecting stdin, so ffmpeg
inherits the pipe the BEAM writes stdout flow-control ACKs to. ffmpeg polls stdin for keyboard
commands ("Press [q] to stop") and swallows ACK bytes; once MuonTrap's output window is spent it
stops draining the child, which then blocks on its own stderr until the MuonTrap timeout. ffmpeg
polls only about every 100 ms, so it wins the race against MuonTrap's own ACK read mainly under CPU
contention, which explains why it shows up only on shared runners and only intermittently. The 600 s
watchdog and the held DB connection were symptoms, not causes.

`Rindle.AV.Subprocess.build_args/3` now prepends `-nostdin` to every ffmpeg call (poster, strip,
transcode, audio, waveform all go through it).

## Verification

- `test/rindle/av/subprocess_stdin_test.exs` (default suite, deterministic): a stdin-reading MuonTrap
  child stalls at the window (timeout, partial output); the same 3 MB output drains in full when stdin
  is left alone; real ffmpeg through `Subprocess.run` no longer prints "Press [q]", while bare
  `MuonTrap.cmd` still does.
- Negative control: removing `-nostdin` fails 3 tests (two `build_args` unit tests plus the ffmpeg
  test).
- Full `mix test` on 2026-10-16: green on the committed tree (LiveTruthParityTest needs a clean
  tree; DoctorThresholdsTest needs a fresh build dir, not one shared across worktrees).
- Live signal: the main-only mux lane and Adoption Demo E2E stop failing at
  `Rindle.AV.Subprocess.run_isolated/5`.
