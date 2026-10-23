---
phase: 136
phase_name: "Measured Quality and CI Ratchets"
project: "Rindle"
generated: "2026-10-21T19:40:30.174319+00:00"
counts:
  decisions: 1
  lessons: 1
  patterns: 1
  surprises: 1
missing_artifacts: ["UAT.md (automation-first acceptance)"]
---

# Phase 136 Learnings: Measured Quality and CI Ratchets

## Decisions

### Keep deferred performance acceptance explicit

The user deferred exact-ten numeric CI speed acceptance unfinished to SEED-261021-918.
Required CI and structural guarantees remain enforced; speed earns zero credit.

**Rationale:** Preserve truthful acceptance while allowing the expressly authorized merge.
**Source:** 136-07-PLAN.md scope_amendment; 136-SPEED-DEFERRAL.json; 136-VERIFICATION.md.

## Lessons

### Receipt validity and aggregate acceptance are separate

The qualification verify command authenticates a blocked manifest successfully.
A zero verifier exit establishes integrity, not a complete verdict inside the receipt.

**Context:** The immutable original timing contract stays blocked after an explicit
scope amendment; final verification separately assesses the amended active criteria.
**Source:** 136-07-SUMMARY.md; 136-QUALIFICATION-CLOSEOUT.json; 136-VERIFICATION.md.

## Patterns

### Resume external work by reconciling its existing authority

Read the job manifest, preserve the frozen subject, authenticate retained artifacts,
then commit the summary before updating lifecycle state. Never resubmit a completed
or running collector merely because its summary is absent.

**When to use:** Long-running measurement jobs across agent sessions.
**Source:** 136-07-SUMMARY.md; .planning/async-jobs/136-07-final-measurements.json.

## Surprises

### A healthy collector can coexist with stale primary state

The primary checkout still described blocked prerequisites while the designated
execution worktree already held all implementations and a completed external job.

**Impact:** Follow the recorded execution checkout and reconcile durable evidence
before dispatch. Environment-only runtime overrides also avoid changing user pins.
**Source:** 136-EXECUTION-RECOVERY.md; 136-07-SUMMARY.md;
136-CLOSEOUT-REGRESSION-RERUN.txt; 136-CLOSEOUT-REGRESSION-SUPPORTED.json.
