---
phase: 27
plan: 01
plan_id: 27-01
title: HTML AV helper surface
status: completed
code_commit: 8608bc9
verified:
  - mix test test/rindle/html_test.exs test/rindle/api_surface_boundary_test.exs
files_modified:
  - lib/rindle/html.ex
  - test/rindle/html_test.exs
  - test/rindle/api_surface_boundary_test.exs
  - .planning/phases/27-html-helpers-liveview-integration/27-01-SUMMARY.md
---

# Phase 27 Plan 01 Summary

Implemented thin Phoenix AV helpers on `Rindle.HTML` without widening delivery or media policy.

## What Changed

- Added `Rindle.HTML.video_tag/3` with ordered `<source>` rendering, `preload="metadata"` defaulting, original-asset `src` fallback, and explicit `poster: :variant_name | url` handling.
- Added `Rindle.HTML.audio_tag/3` with the same playback source-resolution rules, `controls: true`, `preload="metadata"`, and reserved `:tracks` acceptance without rendering `<track>` tags.
- Kept `picture_tag/3` image-specific and unchanged in behavior.
- Added regression coverage for AV source ordering, non-ready variant skipping, fallback behavior, poster resolution, reserved option acceptance, and compiled-doc visibility for the new helper APIs.

## Verification

- `mix test test/rindle/html_test.exs test/rindle/api_surface_boundary_test.exs`

## Deviations

None. The plan was completed within the owned files.
