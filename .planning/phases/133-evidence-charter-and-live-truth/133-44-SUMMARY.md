---
phase: 133-evidence-charter-and-live-truth
plan: "44"
subsystem: nightly-incident
requirements: [EVID-03]
status: complete
commits: [5e2987ac]
---

# Plan 133-44: Preserve Nightly Receipts and Incident History

## Completed

- Receipt publication now refuses occupied destinations, writes a same-filesystem temporary file, and publishes without replacement. A racing writer's receipt is preserved.
- Incident inventory includes closed incidents and canonicalizes state out of the historical identity fields.
- Historical verification accepts appended body text, later issue closure, and unrelated incident issues while retaining the recorded body prefix and exact prior comments.
- Harness coverage protects occupied and raced receipt paths and mutable issue history.

## Verification

- `bash scripts/ci/test_verify_nightly_run.sh` — 168 passed, 0 failed.
- `shellcheck scripts/ci/verify_nightly_run.sh scripts/ci/test_verify_nightly_run.sh` — passed.

## Commit

- `5e2987ac fix(133-44): preserve nightly receipt and incident history`
