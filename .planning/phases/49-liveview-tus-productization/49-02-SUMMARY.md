---
phase: 49-liveview-tus-productization
plan: 02
subsystem: docs / testing
tags: [phoenix, tus, liveview, client, parity]
requires:
  - phase: 49-liveview-tus-productization
    plan: 01
    provides: "locked server-side helper contract and canonical guide ownership"
provides:
  - "The canonical `RindleTus` client snippet now explicitly freezes signed URL reuse and resume-discovery semantics"
  - "The guide now names `uploading`, `verifying`, `ready`, and `error` as the honest UI vocabulary"
  - "Install-smoke parity tests fail if the browser snippet or readiness wording drifts"
requirements-completed: [PHX-03, PHX-04]
completed: 2026-05-25
---

# Phase 49 Plan 02 Summary

**The canonical browser-facing tus path now freezes `uploadUrl`, resume discovery, and honest `uploading`/`verifying`/`ready`/`error` wording, with parity tests guarding future drift.**

## Accomplishments

- Tightened `guides/resumable_uploads.md` so the supported `uploader: "RindleTus"`
  path explicitly starts from `uploadUrl: entry.meta.upload_url` and preserves
  server-owned offset truth through `findPreviousUploads()` and
  `resumeFromPreviousUpload(...)`.
- Made the UI-state guidance explicit that `100%` means bytes transferred while
  readiness stays behind `consume_uploaded_entries/3` and
  `verify_completion/2`, and marked `@uppy/tus` as a compatible non-canonical
  option.
- Expanded `test/install_smoke/phoenix_tus_truth_parity_test.exs` so doc drift
  around the client snippet or the `uploading` / `verifying` / `ready` /
  `error` vocabulary now fails fast.

## Verification

- `rg -n "uploader: \"RindleTus\"|uploadUrl: entry.meta.upload_url|findPreviousUploads\(\)|resumeFromPreviousUpload" guides/resumable_uploads.md`
- `rg -n "uploading|verifying|ready|error|100%" guides/resumable_uploads.md`
- `rg -n "@uppy/tus" guides/resumable_uploads.md`
- `rg -n "consume_uploaded_entries/3|verify_completion/2" guides/resumable_uploads.md`
- `rg -n "uploader: \"RindleTus\"|uploadUrl: entry.meta.upload_url|findPreviousUploads\(\)|resumeFromPreviousUpload|uploading|verifying|ready|100%" test/install_smoke/phoenix_tus_truth_parity_test.exs`
- `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs`

## Decisions Made

- Kept `tus-js-client` as the canonical example and treated `@uppy/tus` as a
  compatibility note, not a second blessed browser path.
- Locked the UI language to server truth rather than adding any alternate
  client-only readiness lifecycle.

## Commits

- None in this execution run. The working tree already contained in-flight user
  changes, so this plan was left uncommitted to avoid bundling unrelated work
  into a GSD execution commit.
