# Phase 33 Deferred Items

## Plan 04: Pre-existing credo --strict findings

**Discovered during:** Plan 04 quality gate (Task 3)

`mix credo --strict` exits with code 14 on the pre-existing tree (verified
by stashing Plan 04 changes and re-running on baseline `c6aeead`). All findings
are in unrelated files (e.g. `lib/rindle/processor/ffmpeg.ex`,
`lib/rindle/live_view.ex`, `lib/rindle/ops/runtime_status.ex`,
`lib/rindle/av/capability.ex`, `lib/rindle/domain/media_asset.ex`,
`lib/rindle/processor/av/video.ex`, `lib/rindle/workers/process_variant.ex`,
`lib/rindle/ops/lifecycle_repair.ex`, etc.).

Plan 04 introduces ZERO new credo findings on `lib/rindle/error.ex`,
`lib/rindle/capability.ex`, `test/rindle/error_streaming_freeze_test.exs`,
or `test/rindle/capability_test.exs`.

Out of scope per executor scope boundary. Recommended action: open a
separate `chore(credo): clean up --strict findings` plan.

## Plan 04: Pre-existing dialyzer findings

**Discovered during:** Plan 04 quality gate (Task 3)

`mix dialyzer` exits with code 2 on the pre-existing tree (verified by
stashing Plan 04 changes and re-running on baseline `c6aeead`). All
warnings are in `lib/rindle/html.ex`, `lib/rindle/ops/runtime_status.ex`,
`lib/rindle/workers/process_variant.ex`, `lib/rindle/workers/promote_asset.ex`.

Plan 04 introduces ZERO new dialyzer findings on
`lib/rindle/error.ex` or `lib/rindle/capability.ex`.

Out of scope per executor scope boundary.

## Plan 04: Pre-existing test flakes (FFmpeg subprocess :epipe)

**Discovered during:** Plan 04 quality gate (Task 3, full `mix test` run)

The full `mix test` suite reports 3-6 failures non-deterministically. Failures
shift between runs (different test names each invocation). All flakes share the
same root cause: `:epipe` errors from FFmpeg/FFprobe subprocess plumbing in:

- `test/rindle/processor/waveform_test.exs`
- `test/rindle/processor/av_test.exs`
- `test/rindle/av/ffprobe_test.exs`
- `test/rindle/probe/av_probe_test.exs`
- `test/rindle/application_test.exs` (`run_startup_checks`)

Verified pre-existing on baseline `c6aeead` (3 failures on a single full-suite
run with Plan 04 changes stashed; the specific tests vary between runs).

Plan 04's focused suite (`test/rindle/error_streaming_freeze_test.exs +
test/rindle/capability_test.exs + test/rindle/error_test.exs`) runs 25 tests
deterministically green across 3 consecutive invocations.

Out of scope per executor scope boundary (FFmpeg subprocess flakes are
unrelated to error.ex / capability.ex changes).
