---
phase: 133-evidence-charter-and-live-truth
plan: "27"
type: execute
status: halted
halt_reason: "Dispatch-owned Nightly run 34661043059 attempt 1 completed failure; the one-time publication authorization is exhausted and strict qualification correctly refused to replace the last valid receipt."
requirements_completed: []
commits:
  - hash: 7eaf789bbbdaa955b15e8941b01620e42e5d79c2
    message: "docs(133-27): bind census to clean pre-ledger subject"
key_files:
  modified:
    - .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json
  preserved:
    - .planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json
---

# Phase 133 Plan 27: Halted execution record

Plan 133-27 did not complete. This summary is a factual halted-state record so later execution does not mistake the committed census rebind for an unaccounted production change or retry the consumed one-time publication.

## Completed work

- Task 1 committed the Phase 133 census rebind at `7eaf789bbbdaa955b15e8941b01620e42e5d79c2` for clean subject `0f8189ddeed7e7a52b5c7464f17b70ab44596c33`.
- Task 2 received one exact, non-force publication authorization for `refs/heads/phase-133-evidence-0f8189ddeed7` at that subject. The authorization was consumed when the ref was created and the workflow was dispatched.
- The dispatch-owned Nightly run is `34661043059`, attempt `1`, on head SHA `0f8189ddeed7e7a52b5c7464f17b70ab44596c33`. It completed with conclusion `failure`.

## Halt condition

Task 3 stopped at strict qualification. Compatibility cells Elixir 1.15/OTP 26 and Elixir 1.16/OTP 26 each failed two package-evidence tests with `package command failed: boot`; Elixir 1.18/OTP 27 failed the multi-verification-pair reconciliation assertion because the captured process output contained two lines. Nightly Summary correctly rejected the non-green matrix.

The failed ref and run are immutable evidence. They must not be force-updated, deleted, relabeled, rerun, or represented as passing. This halted record does not close EVID-01, EVID-02, EVID-03, EVID-04, or TRUTH-08.

## Preserved authority

The canonical receipt remains the previously qualified receipt for subject `1470cf8cb0f111d0b233efbf77ee69e92f25fd68`, run `34638437301`. Plan 133-27 did not replace it.

Any later remote publication requires a repaired clean subject, a different subject-derived ref that is absent before publication, and a fresh blocking-human authorization naming the exact SHA and exact ref.
