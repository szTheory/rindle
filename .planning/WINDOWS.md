---
schema_version: 1
open_count: 1
waived_count: 0
fixed_count: 0
total_count: 1
last_updated: 2026-08-09T02:52:51.780Z
---

# Broken Windows Ledger

> Cross-phase defect register. `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 117 | deviation | .planning/STATE.md |  | Reconciled stale Phase 117 plan counter from four on-disk summaries. | open |  | 2026-08-09T02:52:51.780Z |  |

````json
[
  {
    "id": 1,
    "kind": "deviation",
    "phase": "117",
    "file": ".planning/STATE.md",
    "line": null,
    "description": "Reconciled stale Phase 117 plan counter from four on-disk summaries.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-09T02:52:51.780Z",
    "resolved_at": null
  }
]
````
