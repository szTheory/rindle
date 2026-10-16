---
created: 2026-10-16T12:40:00.000Z
title: De-flake the Package Consumer Full (mux) generated-app AV variant timeout
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

Seen twice in five main runs, both on lock-only commits that the generated app never reads, and both passed on a
single failed-job rerun:

- run 38838770800 on be7ac7e2 (#129, demo lock), attempt 1 red, attempt 2 green
- run 38898465466 on d6074a4c (#130, demo bandit), attempt 1 red, attempt 2 rerun

The lane runs only on main push (see reference memory "CI lanes only on main"), so the flake reddens main
without a PR signal and costs a rerun per occurrence.

## Options

1. Find why the ffmpeg fallback attempt hangs on the runner (no subprocess timeout reached before the 60 s
   ExUnit timeout?) and give `run_isolated` a bounded per-attempt timeout below the test budget.
2. Raise the generated test's `@tag timeout:` only if the AV work is legitimately slow on shared runners, with the
   subprocess timeout still bounding each attempt.

Fix in the merge-blocking path first if it can be reproduced in a PR lane.
