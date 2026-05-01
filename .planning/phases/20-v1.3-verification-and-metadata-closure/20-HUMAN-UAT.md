---
status: partial
phase: 20-v1.3-verification-and-metadata-closure
source: [20-VERIFICATION.md]
started: 2026-05-01T00:00:00Z
updated: 2026-05-01T00:00:00Z
---

## Current Test

[awaiting human decision on the two items below]

## Tests

### 1. Phase 20 status: pass-with-followup vs reopen-20-02

**expected:** Decide whether to (a) accept Phase 20 as PASSED with a tracked follow-up phase to fix CR-01/CR-02 and the WR-01..WR-05 issues from `20-REVIEW.md`, or (b) reopen Plan 20-02 to fix the LiveView defects in this phase.

**why_human:** Per Plan 20-02 D-12, the working-tree diff was committed AS-IS — the defects (CR-01: 2-tuple return crashes Phoenix.LiveView's external callback contract; CR-02: silent bypass of `Rindle.verify_completion/2` when `session_id` is missing from meta) were encoded in the input patch, not introduced by the executor. The phase's documented job ended at committing the patch, not authoring a flawless one. This is a scope-vs-quality judgment that requires human ownership.

**result:** [pending]

### 2. WR-04 onboarding example defect

**expected:** Decide whether to patch the `avatar.asset` nil-deref in README.md:138 and guides/getting_started.md:231 in a new commit, or route to the same follow-up phase. The defect: examples dereference `avatar.asset` without a nil-guard despite the immediately-preceding comment annotating the return as `nil`-able. An adopter copy-pasting will hit `BadMapError` for any user without an attachment.

**why_human:** WR-04 is a documentation correctness issue, not a metadata-closure issue. Phase 20's specified deliverables (teach the eight symbols + parity test gate) shipped; the example correctness is a quality concern that did not block any of the phase's success criteria.

**result:** [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
