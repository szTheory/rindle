---
phase: 91-cohort-demo-evolution
plan: 02
subsystem: adoption_demo
tags:
  - adoption_demo
  - media_asset
  - lifecycle_states
  - seeds
dependency_graph:
  requires:
    - 91-01 (implied previous execution)
  provides:
    - AudioProfile
    - DocumentProfile
    - Edge case seed data for UI testing
tech_stack:
  added: []
  patterns: []
key_files:
  modified:
    - examples/adoption_demo/lib/adoption_demo/rindle_profile.ex
    - examples/adoption_demo/priv/repo/seeds.exs
decisions:
  - Added empty `variants: []` block to Audio and Document profiles to pass Rindle profile validations.
  - Used `NaiveDateTime` and `DateTime` appropriately in seeds to match schema type constraints.
  - Used predictable prefix mapping `seed/...` and timestamp generation to allow repeated seed invocations without DB constraint violations.
metrics:
  tasks_completed: 2
  total_files_modified: 2
  completion_date: 2026-06-12
---

# Phase 91 Plan 02: Cohort Demo Evolution Summary

Media profiles for Audio and Document added and lifecycle edge case data seeded for testing.

## Execution Details

- Successfully implemented `AdoptionDemo.AudioProfile` and `AdoptionDemo.DocumentProfile` within the `adoption_demo` subsystem.
- Seeded comprehensive edge cases covering all discrete states for `MediaAsset`, `MediaVariant`, and `MediaUploadSession`.

## Deviations from Plan

**1. [Rule 3 - Blocker] Fixed missing variants validation**
- **Found during:** Task 1
- **Issue:** Attempting to compile `rindle_profile.ex` produced an `ArgumentError` due to missing required `:variants` option in `Rindle.Profile`.
- **Fix:** Provided an empty list `variants: []` for both `AdoptionDemo.AudioProfile` and `AdoptionDemo.DocumentProfile`.
- **Files modified:** `examples/adoption_demo/lib/adoption_demo/rindle_profile.ex`
- **Commit:** 5f9e5a8

**2. [Rule 1 - Bug] Fixed Ecto.ChangeError on missing naive datetime in seeds**
- **Found during:** Task 2
- **Issue:** Ecto `insert!` failed because `inserted_at` mapped to `:naive_datetime` and the seeds provided `:utc_datetime_usec`.
- **Fix:** Truncated and passed `NaiveDateTime` variables alongside `DateTime` for compatibility with `inserted_at`, `updated_at`, and `expires_at`.
- **Files modified:** `examples/adoption_demo/priv/repo/seeds.exs`
- **Commit:** 9488806

## Self-Check: PASSED
- `examples/adoption_demo/lib/adoption_demo/rindle_profile.ex` has Audio and Document profiles.
- `examples/adoption_demo/priv/repo/seeds.exs` seeds edge cases properly.
- Commits 5f9e5a8 and 9488806 applied.
