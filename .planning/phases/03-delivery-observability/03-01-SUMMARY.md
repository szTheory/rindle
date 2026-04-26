---
phase: 03-delivery-observability
plan: "01"
subsystem: delivery
tags: [delivery, signed-urls, public-opt-in, profile-policy]
requires: [DELV-01, DELV-02, DELV-03, DELV-04, DELV-05, DELV-06]
provides:
  - "Profile-level delivery policy validation and defaults"
  - "Private-by-default URL resolution with public opt-in support"
  - "Variant fallback decisions for non-ready media"
key-files:
  created:
    - lib/rindle/delivery.ex
  modified:
    - lib/rindle/profile.ex
    - lib/rindle/profile/validator.ex
    - test/rindle/profile/profile_test.exs
requirements-completed: [DELV-01, DELV-02, DELV-03, DELV-04, DELV-05, DELV-06]
completed: 2026-04-26
---

# Phase 03 Plan 01: Delivery Policy Contract Summary

`Rindle.Profile` now carries explicit delivery policy settings, and `Rindle.Delivery` resolves private signed URLs, public unsigned URLs, and stale/non-ready fallbacks through a dedicated policy layer.

## Verification

- `mix test test/rindle/profile/profile_test.exs`

## Notes

- Delivery policy defaults to private delivery with the configured signed URL TTL.
- Unknown delivery options fail at compile time through the profile validator.
