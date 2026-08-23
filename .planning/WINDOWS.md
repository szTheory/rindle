---
schema_version: 1
open_count: 2
waived_count: 2
fixed_count: 9
total_count: 13
last_updated: 2026-08-23T15:10:46.355Z
---

# Broken Windows Ledger

> Cross-phase defect register. `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 117 | deviation | .planning/STATE.md |  | Reconciled stale Phase 117 plan counter from four on-disk summaries. | fixed |  | 2026-08-09T02:52:51.780Z | 2026-08-20T20:59:00.533Z |
| 2 | 119 | unrun-verify | test/rindle/ops/runtime_status_test.exs |  | Plan-level runtime/doctor verification is blocked by protected Phase 118 database fixtures missing public Rindle tables | fixed |  | 2026-08-10T02:00:44.512Z | 2026-08-20T20:59:00.603Z |
| 3 | 119 | unrun-verify | examples/adoption_demo/e2e/ops-surfaces.spec.js |  | Supplemental ops browser proof is blocked before Playwright by protected Phase 118 demo fixtures missing rindle.media_attachments | waived | Superseded by focused Phase 119 ownership verification and green exact-source Adoption E2E; this supplemental browser probe is not a release gate. | 2026-08-10T02:06:46.584Z | 2026-08-20T20:59:01.170Z |
| 4 | 120 | unrun-verify | scripts/ci/cohort_demo_smoke.sh |  | Authoritative Docker cold-start proof blocked before boot because Docker predefined address pools are exhausted. | fixed |  | 2026-08-10T03:58:36.554Z | 2026-08-20T20:59:00.676Z |
| 5 | 120 | unrun-verify | test/install_smoke/generated_app_smoke_test.exs |  | Authoritative image-profile package gate was interrupted after phx.new --install stalled while generating the public compatibility consumer. | fixed |  | 2026-08-10T20:33:03.670Z | 2026-08-20T20:59:00.747Z |
| 6 | 120 | deviation | test/install_smoke/docs_parity_test.exs |  | Formatted new docs-parity assertions after check-formatted failed. | fixed |  | 2026-08-10T20:44:27.512Z | 2026-08-20T20:59:00.817Z |
| 7 | 120 | deviation | test/install_smoke/docs_parity_test.exs |  | Scoped repeated diagnostic-order assertions to individual troubleshooting routes. | fixed |  | 2026-08-20T20:59:00.137Z | 2026-08-20T20:59:00.887Z |
| 8 | 120 | unrun-verify | guides/release_publish.md |  | Release docs link checker has 45 pre-existing planning-artifact findings in unrelated docs. | waived | Pre-existing planning-artifact link findings are outside the 0.4.0 release surface; release docs parity, exact-source CI, and public verification passed. | 2026-08-20T20:59:00.238Z | 2026-08-20T20:59:01.237Z |
| 9 | 120 | unrun-verify | examples/adoption_demo/test/rindle_migration_contract_test.exs | 11 | Cohort precommit blocked by inherited dirty schema fixture: public.media_assets already exists. | fixed |  | 2026-08-20T20:59:00.311Z | 2026-08-20T20:59:00.958Z |
| 10 | 120 | unrun-verify | test/install_smoke/docs_parity_test.exs |  | mix ci blocked by unrelated pre-existing formatting drift. | fixed |  | 2026-08-20T20:59:00.386Z | 2026-08-20T20:59:01.027Z |
| 11 | 120 | unrun-verify | scripts/install_smoke.sh |  | Broad packed/Cohort verification runner detached before final exit receipts; exact-SHA CI remains required. | fixed |  | 2026-08-20T20:59:00.462Z | 2026-08-20T20:59:01.101Z |
| 12 | 126 | deviation | .planning/phases/126-curated-type-ratchet/126-04-SUMMARY.md |  | Verification predicate used a punctuation typo; exact emitted E38 text was used for supported receipt validation. | open |  | 2026-08-23T13:45:36.941Z |  |
| 13 | 126 | deviation | lib/rindle/upload/broker.ex | 193 | Corrected concatenate_tus_sessions/3 return spec to match its existing session-map result. | open |  | 2026-08-23T15:10:46.355Z |  |

````json
[
  {
    "id": 1,
    "kind": "deviation",
    "phase": "117",
    "file": ".planning/STATE.md",
    "line": null,
    "description": "Reconciled stale Phase 117 plan counter from four on-disk summaries.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-09T02:52:51.780Z",
    "resolved_at": "2026-08-20T20:59:00.533Z"
  },
  {
    "id": 2,
    "kind": "unrun-verify",
    "phase": "119",
    "file": "test/rindle/ops/runtime_status_test.exs",
    "line": null,
    "description": "Plan-level runtime/doctor verification is blocked by protected Phase 118 database fixtures missing public Rindle tables",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-10T02:00:44.512Z",
    "resolved_at": "2026-08-20T20:59:00.603Z"
  },
  {
    "id": 3,
    "kind": "unrun-verify",
    "phase": "119",
    "file": "examples/adoption_demo/e2e/ops-surfaces.spec.js",
    "line": null,
    "description": "Supplemental ops browser proof is blocked before Playwright by protected Phase 118 demo fixtures missing rindle.media_attachments",
    "status": "waived",
    "reason": "Superseded by focused Phase 119 ownership verification and green exact-source Adoption E2E; this supplemental browser probe is not a release gate.",
    "recorded_at": "2026-08-10T02:06:46.584Z",
    "resolved_at": "2026-08-20T20:59:01.170Z"
  },
  {
    "id": 4,
    "kind": "unrun-verify",
    "phase": "120",
    "file": "scripts/ci/cohort_demo_smoke.sh",
    "line": null,
    "description": "Authoritative Docker cold-start proof blocked before boot because Docker predefined address pools are exhausted.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-10T03:58:36.554Z",
    "resolved_at": "2026-08-20T20:59:00.676Z"
  },
  {
    "id": 5,
    "kind": "unrun-verify",
    "phase": "120",
    "file": "test/install_smoke/generated_app_smoke_test.exs",
    "line": null,
    "description": "Authoritative image-profile package gate was interrupted after phx.new --install stalled while generating the public compatibility consumer.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-10T20:33:03.670Z",
    "resolved_at": "2026-08-20T20:59:00.747Z"
  },
  {
    "id": 6,
    "kind": "deviation",
    "phase": "120",
    "file": "test/install_smoke/docs_parity_test.exs",
    "line": null,
    "description": "Formatted new docs-parity assertions after check-formatted failed.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-10T20:44:27.512Z",
    "resolved_at": "2026-08-20T20:59:00.817Z"
  },
  {
    "id": 7,
    "kind": "deviation",
    "phase": "120",
    "file": "test/install_smoke/docs_parity_test.exs",
    "line": null,
    "description": "Scoped repeated diagnostic-order assertions to individual troubleshooting routes.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-20T20:59:00.137Z",
    "resolved_at": "2026-08-20T20:59:00.887Z"
  },
  {
    "id": 8,
    "kind": "unrun-verify",
    "phase": "120",
    "file": "guides/release_publish.md",
    "line": null,
    "description": "Release docs link checker has 45 pre-existing planning-artifact findings in unrelated docs.",
    "status": "waived",
    "reason": "Pre-existing planning-artifact link findings are outside the 0.4.0 release surface; release docs parity, exact-source CI, and public verification passed.",
    "recorded_at": "2026-08-20T20:59:00.238Z",
    "resolved_at": "2026-08-20T20:59:01.237Z"
  },
  {
    "id": 9,
    "kind": "unrun-verify",
    "phase": "120",
    "file": "examples/adoption_demo/test/rindle_migration_contract_test.exs",
    "line": 11,
    "description": "Cohort precommit blocked by inherited dirty schema fixture: public.media_assets already exists.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-20T20:59:00.311Z",
    "resolved_at": "2026-08-20T20:59:00.958Z"
  },
  {
    "id": 10,
    "kind": "unrun-verify",
    "phase": "120",
    "file": "test/install_smoke/docs_parity_test.exs",
    "line": null,
    "description": "mix ci blocked by unrelated pre-existing formatting drift.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-20T20:59:00.386Z",
    "resolved_at": "2026-08-20T20:59:01.027Z"
  },
  {
    "id": 11,
    "kind": "unrun-verify",
    "phase": "120",
    "file": "scripts/install_smoke.sh",
    "line": null,
    "description": "Broad packed/Cohort verification runner detached before final exit receipts; exact-SHA CI remains required.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-20T20:59:00.462Z",
    "resolved_at": "2026-08-20T20:59:01.101Z"
  },
  {
    "id": 12,
    "kind": "deviation",
    "phase": "126",
    "file": ".planning/phases/126-curated-type-ratchet/126-04-SUMMARY.md",
    "line": null,
    "description": "Verification predicate used a punctuation typo; exact emitted E38 text was used for supported receipt validation.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-23T13:45:36.941Z",
    "resolved_at": null
  },
  {
    "id": 13,
    "kind": "deviation",
    "phase": "126",
    "file": "lib/rindle/upload/broker.ex",
    "line": 193,
    "description": "Corrected concatenate_tus_sessions/3 return spec to match its existing session-map result.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-23T15:10:46.355Z",
    "resolved_at": null
  }
]
````
