---
phase: 139
review: 139-REVIEW.md
titles: json
findings:
  - id: CR-01
    severity: critical
    disposition: open
    title: "BLOCKER — CI receipt accepts a check from the wrong GitHub App"
  - id: WR-01
    severity: warning
    disposition: deferred
    title: "A nonzero offset default can satisfy the Doctor check (preexisting)"
  - id: WR-02
    severity: warning
    disposition: deferred
    title: "An unfiltered expiry index can satisfy the Doctor check (preexisting)"
open: 1
total: 3
recorded: 2026-11-14T00:43:47.847Z
---

# Phase 139: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| CR-01 | critical | open | - |
| WR-01 | warning | deferred | Preexisting since 47d1d5dc; Phase 139 did not change it. Retained accepted migration declares DEFAULT 0 and package qualification passed. Follow-up: `.planning/todos/pending/2026-10-29-doctor-resumable-schema-drift.md`. (not in the current review) |
| WR-02 | warning | deferred | Preexisting since 47d1d5dc; Phase 139 did not change it. Retained accepted migration creates the filtered expiry index and qualification passed. Follow-up: `.planning/todos/pending/2026-10-29-doctor-resumable-schema-drift.md`. (not in the current review) |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
