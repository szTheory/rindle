---
phase: 49-liveview-tus-productization
plan: 01
subsystem: docs / liveview / testing
tags: [phoenix, tus, liveview, guide, parity]
provides:
  - "The canonical LiveView server-side tus contract now names required `:path` and `:secret_key_base` options plus optional `:actor`"
  - "The guide remains the only full Phoenix / LiveView setup narrative while `Rindle.LiveView` stays a thin pointer"
  - "Unit coverage freezes `RindleTus` metadata, socket-derived actor resolution, and convergence through `consume_uploaded_entries/3` plus `verify_completion/2`"
requirements-completed: [PHX-02]
completed: 2026-05-25
---

# Phase 49 Plan 01 Summary

**The LiveView tus helper contract is now explicit in the canonical guide, `Rindle.LiveView` stays thin, and unit tests lock the helper metadata plus socket-derived actor behavior.**

## Accomplishments

- Added explicit LiveView helper contract wording to
  `guides/resumable_uploads.md`, including required `:path` and
  `:secret_key_base`, optional `:actor`, and the host-app ownership boundary
  for router, auth, parser, CORS, and resume posture.
- Kept `lib/rindle/live_view.ex` as a guide pointer rather than duplicating
  operational setup, while preserving the supported `allow_tus_upload/4`
  contract and `consume_uploaded_entries/3` completion boundary.
- Expanded `test/rindle/live_view_test.exs` with a real `actor: fn socket ->`
  case that proves socket-derived actor values are signed into the tus URL.

## Verification

- `rg -n "allow_tus_upload/4|:path|:secret_key_base|:actor|consume_uploaded_entries/3|verify_completion/2" guides/resumable_uploads.md`
- `rg -n "guides/resumable_uploads.md" lib/rindle/live_view.ex`
- `! rg -n "plug Plug\.Parsers|config :cors_plug" lib/rindle/live_view.ex`
- `rg -n "thin helper seam|host app still owns|router|CORS" guides/resumable_uploads.md`
- `rg -n "actor: fn|RindleTus|upload_url|verify_completion/2|consume_uploaded_entries/3" test/rindle/live_view_test.exs`
- `mix test test/rindle/live_view_test.exs`

## Decisions Made

- Kept the full Phoenix / LiveView narrative in `guides/resumable_uploads.md`
  so `Rindle.LiveView` docs do not become a second setup source.
- Treated `:actor` as an existing supported seam only; the phase sharpened its
  documentation and tests without widening the API surface.

## Commits

- None in this execution run. The working tree already contained in-flight user
  changes, so this plan was left uncommitted to avoid bundling unrelated work
  into a GSD execution commit.
