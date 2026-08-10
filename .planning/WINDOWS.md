---
schema_version: 1
open_count: 2
waived_count: 0
fixed_count: 0
total_count: 2
last_updated: 2026-08-10T02:00:44.512Z
---

# Broken Windows Ledger

> Cross-phase defect register. `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 117 | deviation | .planning/STATE.md |  | Reconciled stale Phase 117 plan counter from four on-disk summaries. | open |  | 2026-08-09T02:52:51.780Z |  |
| 2 | 119 | unrun-verify | test/rindle/ops/runtime_status_test.exs |  | Plan-level runtime/doctor verification is blocked by protected Phase 118 database fixtures missing public Rindle tables | open |  | 2026-08-10T02:00:44.512Z |  |

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
  },
  {
    "id": 2,
    "kind": "unrun-verify",
    "phase": "119",
    "file": "test/rindle/ops/runtime_status_test.exs",
    "line": null,
    "description": "Plan-level runtime/doctor verification is blocked by protected Phase 118 database fixtures missing public Rindle tables",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-10T02:00:44.512Z",
    "resolved_at": null
  }
]
````
