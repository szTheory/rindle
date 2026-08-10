---
schema_version: 1
open_count: 5
waived_count: 0
fixed_count: 0
total_count: 5
last_updated: 2026-08-10T20:33:03.670Z
---

# Broken Windows Ledger

> Cross-phase defect register. `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 117 | deviation | .planning/STATE.md |  | Reconciled stale Phase 117 plan counter from four on-disk summaries. | open |  | 2026-08-09T02:52:51.780Z |  |
| 2 | 119 | unrun-verify | test/rindle/ops/runtime_status_test.exs |  | Plan-level runtime/doctor verification is blocked by protected Phase 118 database fixtures missing public Rindle tables | open |  | 2026-08-10T02:00:44.512Z |  |
| 3 | 119 | unrun-verify | examples/adoption_demo/e2e/ops-surfaces.spec.js |  | Supplemental ops browser proof is blocked before Playwright by protected Phase 118 demo fixtures missing rindle.media_attachments | open |  | 2026-08-10T02:06:46.584Z |  |
| 4 | 120 | unrun-verify | scripts/ci/cohort_demo_smoke.sh |  | Authoritative Docker cold-start proof blocked before boot because Docker predefined address pools are exhausted. | open |  | 2026-08-10T03:58:36.554Z |  |
| 5 | 120 | unrun-verify | test/install_smoke/generated_app_smoke_test.exs |  | Authoritative image-profile package gate was interrupted after phx.new --install stalled while generating the public compatibility consumer. | open |  | 2026-08-10T20:33:03.670Z |  |

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
  },
  {
    "id": 3,
    "kind": "unrun-verify",
    "phase": "119",
    "file": "examples/adoption_demo/e2e/ops-surfaces.spec.js",
    "line": null,
    "description": "Supplemental ops browser proof is blocked before Playwright by protected Phase 118 demo fixtures missing rindle.media_attachments",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-10T02:06:46.584Z",
    "resolved_at": null
  },
  {
    "id": 4,
    "kind": "unrun-verify",
    "phase": "120",
    "file": "scripts/ci/cohort_demo_smoke.sh",
    "line": null,
    "description": "Authoritative Docker cold-start proof blocked before boot because Docker predefined address pools are exhausted.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-10T03:58:36.554Z",
    "resolved_at": null
  },
  {
    "id": 5,
    "kind": "unrun-verify",
    "phase": "120",
    "file": "test/install_smoke/generated_app_smoke_test.exs",
    "line": null,
    "description": "Authoritative image-profile package gate was interrupted after phx.new --install stalled while generating the public compatibility consumer.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-10T20:33:03.670Z",
    "resolved_at": null
  }
]
````
