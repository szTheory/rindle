---
phase: 25
plan: 03
title: Video outputs for Rindle.Processor.AV
date: 2026-05-05
commits:
  - 72230dd
  - 7554c05
  - bcbbd44
---

# Phase 25 Plan 03 Summary

Implemented the video-output half of `Rindle.Processor.AV`: preset-led mp4 transcode, explicit poster extraction, and explicit thumbnail-strip generation, all exercised against real FFmpeg fixtures.

## Outcome

- Added `Rindle.Processor.AV.Video` as the dedicated helper for transcode, poster, and strip execution.
- Updated `Rindle.Processor.AV` to normalize and dispatch explicit image-output AV recipes (`:video_poster_scene`, `:video_thumbnail_strip`) alongside `:web_720p`.
- Expanded `test/rindle/processor/av_test.exs` with real-fixture proofs for:
  - H.264 + AAC mp4 output
  - `+faststart` moov-before-mdat behavior
  - scene-change poster extraction
  - first-I-frame fallback when no scene qualifies
  - explicit opt-in thumbnail-strip generation

## Verification

Command run:

```sh
mix test test/rindle/processor/av_test.exs
```

Result: `9 tests, 0 failures`

## Changed Files

- `lib/rindle/processor/av.ex`
- `lib/rindle/processor/av/video.ex`
- `test/rindle/processor/av_test.exs`
- `lib/rindle/av/subprocess.ex`

## Deviations from Plan

### Rule 1 - Bug

`lib/rindle/av/subprocess.ex` needed a blocking fix during Task 1. The existing FFmpeg arg builder prepended `-fs` before the input path, which caused FFmpeg to reject valid jobs as malformed. The fix preserves the subprocess seam but relocates `-fs` to the output side of the argv list for single-output commands.

### TDD Note

Task 1 followed a normal red-green loop (`72230dd` -> `7554c05`). Task 2’s new real-fixture tests passed immediately because the explicit poster/strip helper logic had already landed in the Task 1 feature commit; the proof coverage was recorded separately in `bcbbd44`.
