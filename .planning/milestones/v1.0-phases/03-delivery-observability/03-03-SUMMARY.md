---
phase: 03-delivery-observability
plan: "03"
subsystem: html
tags: [html, picture-tag, responsive-images, phoenix]
requires: [VIEW-01, VIEW-02, VIEW-03, VIEW-04]
provides:
  - "Responsive picture_tag/3 helper"
  - "Ready-only variant source rendering"
  - "Placeholder and original fallback behavior"
key-files:
  created:
    - lib/rindle/html.ex
    - test/rindle/html_test.exs
requirements-completed: [VIEW-01, VIEW-02, VIEW-03, VIEW-04]
completed: 2026-04-26
---

# Phase 03 Plan 03: Responsive Image Helper Summary

`Rindle.HTML.picture_tag/3` now renders safe `<picture>` markup from explicit variant ordering, filters to ready variants, and falls back cleanly to a placeholder or original asset URL.

## Verification

- `mix test test/rindle/html_test.exs`

## Notes

- The helper delegates URL resolution to `Rindle.Delivery`.
- Non-ready variants are excluded from rendered sources.
