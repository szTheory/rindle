---
schema_version: 1
open_count: 5
waived_count: 2
fixed_count: 26
total_count: 33
last_updated: 2026-09-13T16:29:31.472Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
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
| 12 | 126 | deviation | .planning/phases/126-curated-type-ratchet/126-04-SUMMARY.md |  | Verification predicate used a punctuation typo; exact emitted E38 text was used for supported receipt validation. | fixed |  | 2026-08-23T13:45:36.941Z | 2026-08-23T18:15:48.503Z |
| 13 | 126 | deviation | lib/rindle/upload/broker.ex | 193 | Corrected concatenate_tus_sessions/3 return spec to match its existing session-map result. | fixed |  | 2026-08-23T15:10:46.355Z | 2026-08-23T18:15:48.584Z |
| 14 | 132 | deviation | .planning/REQUIREMENTS.md |  | CI-14 was restored to open because Plan 132-08 owns its live ten-run acceptance. | fixed |  | 2026-08-26T14:47:14.864Z | 2026-08-26T14:47:47.401Z |
| 15 | 133 | deviation | test/install_smoke/ci_cache_hygiene_test.exs |  | Updated the obsolete cache-miss save assertion to the planned fresh-save-exact-restore topology | fixed |  | 2026-09-10T00:29:46.836Z | 2026-09-10T00:29:56.052Z |
| 16 | 133 | stub | examples/adoption_demo/docs/adoption-proof-matrix.md | 43 | GCS resumable browser path remains an explicitly optional demo placeholder; live generated-app proof is separate. | open |  | 2026-09-10T02:11:37.821Z |  |
| 17 | 133 | deviation | test/install_smoke/evidence_census_test.exs |  | Classified per-test unique census fixture writes for the async-safety guard. | fixed |  | 2026-09-10T02:12:36.558Z | 2026-09-10T02:13:07.278Z |
| 18 | 133 | deviation | scripts/maintainer/evidence_census.exs |  | Corrected the census performance detector to the actual archived Phase 132 receipt. | fixed |  | 2026-09-10T02:13:07.391Z | 2026-09-10T02:13:16.387Z |
| 19 | 133 | deviation | scripts/ci/verify_nightly_run.sh |  | Rejected empty generated census and live-truth JSON before canonical hashing | fixed |  | 2026-09-10T22:04:34.028Z | 2026-09-10T22:05:06.934Z |
| 20 | 133 | deviation | scripts/ci/verify_nightly_run.sh |  | Restored detached Git identity for exact-subject validator execution | fixed |  | 2026-09-10T22:04:34.174Z | 2026-09-10T22:05:07.060Z |
| 21 | 133 | deviation | scripts/maintainer/evidence_census.exs |  | Canonicalize the inspected root through the physical resolver so platform symlink aliases do not reject contained detector inputs | fixed |  | 2026-09-11T17:20:05.449Z | 2026-09-11T17:20:27.089Z |
| 22 | 133 | deviation | scripts/maintainer/validate_phase_133_reconciliation.exs |  | Bootstrapped the literal standalone Elixir verification path from repository-bounded compiled dependencies | fixed |  | 2026-09-12T02:07:24.771Z | 2026-09-12T02:07:50.462Z |
| 23 | 133 | deviation | .planning/ROADMAP.md |  | Corrected halted Plan 133-27 Roadmap tracking after the generic summary-count handler rechecked it | fixed |  | 2026-09-12T02:07:24.858Z | 2026-09-12T02:07:50.550Z |
| 24 | 133 | deviation | .planning/phases/133-evidence-charter-and-live-truth/133-30-PLAN.md |  | Used the shipped detached ledger-plus-receipt validator interface because the plan's literal --census flag is obsolete. | fixed |  | 2026-09-12T02:52:04.986Z | 2026-09-12T02:52:12.603Z |
| 25 | 133 | deviation | test/install_smoke/nightly_policy_test.exs |  | Applied the supported Elixir formatter's deterministic indentation and rebound the census to the post-fix subject. | fixed |  | 2026-09-12T02:52:05.087Z | 2026-09-12T02:52:12.726Z |
| 26 | 133 | deviation | .planning/ROADMAP.md |  | Restored Plan 133-27 to unchecked halted status and corrected post-Plan-30 semantic totals after the generic progress handler rechecked it. | fixed |  | 2026-09-12T02:53:16.183Z | 2026-09-12T02:53:16.295Z |
| 27 | 133 | deviation | .planning/ROADMAP.md |  | Restored Plan 133-27 to unchecked halted status and corrected post-Plan-31 semantic totals after the generic progress handler rechecked it. | fixed |  | 2026-09-12T03:24:16.251Z | 2026-09-12T03:24:16.357Z |
| 28 | 133 | unrun-verify | scripts/ci/verify_nightly_run.sh |  | Plan 133-32 terminal run/log/receipt and promotion gates were not run because the sole collector invocation halted on GitHub API rate limiting before candidate creation. | open |  | 2026-09-12T03:36:52.032Z |  |
| 29 | 133 | deviation | .planning/ROADMAP.md |  | Restored Plans 133-27 and 133-32 to unchecked halted status and corrected post-halt semantic totals after the generic progress handler rechecked both. | fixed |  | 2026-09-12T03:37:31.584Z | 2026-09-12T03:37:45.885Z |
| 30 | 133 | deviation | .planning/ROADMAP.md |  | Generic progress updater counted halted summaries as completed; restored exact post-Plan-34 branch arithmetic and unchecked halt rows | fixed |  | 2026-09-12T20:25:06.283Z | 2026-09-12T20:25:26.849Z |
| 31 | 133 | unrun-verify | scripts/ci/test_verify_nightly_run.sh |  | Plan 133-37 qualification commands after the detached exact-SHA census failure were not run because the one authorized attempt was terminal | open |  | 2026-09-13T02:16:05.419Z |  |
| 32 | 133 | deviation | .planning/phases/133-evidence-charter-and-live-truth/133-37-SUMMARY.md |  | Plan 133-37 halted on immutable run 34732110533 after detached exact-SHA census qualification could not start :rindle | open |  | 2026-09-13T02:16:05.510Z |  |
| 33 | 133 | unrun-verify | .planning/phases/133-evidence-charter-and-live-truth/133-42-PLAN.md |  | Plan 133-42 Task 2 qualification and promotion gates were not run after immutable Nightly run 34768317696 failed. | open |  | 2026-09-13T16:29:31.472Z |  |

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
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-23T13:45:36.941Z",
    "resolved_at": "2026-08-23T18:15:48.503Z"
  },
  {
    "id": 13,
    "kind": "deviation",
    "phase": "126",
    "file": "lib/rindle/upload/broker.ex",
    "line": 193,
    "description": "Corrected concatenate_tus_sessions/3 return spec to match its existing session-map result.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-23T15:10:46.355Z",
    "resolved_at": "2026-08-23T18:15:48.584Z"
  },
  {
    "id": 14,
    "kind": "deviation",
    "phase": "132",
    "file": ".planning/REQUIREMENTS.md",
    "line": null,
    "description": "CI-14 was restored to open because Plan 132-08 owns its live ten-run acceptance.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-26T14:47:14.864Z",
    "resolved_at": "2026-08-26T14:47:47.401Z"
  },
  {
    "id": 15,
    "kind": "deviation",
    "phase": "133",
    "file": "test/install_smoke/ci_cache_hygiene_test.exs",
    "line": null,
    "description": "Updated the obsolete cache-miss save assertion to the planned fresh-save-exact-restore topology",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-10T00:29:46.836Z",
    "resolved_at": "2026-09-10T00:29:56.052Z"
  },
  {
    "id": 16,
    "kind": "stub",
    "phase": "133",
    "file": "examples/adoption_demo/docs/adoption-proof-matrix.md",
    "line": 43,
    "description": "GCS resumable browser path remains an explicitly optional demo placeholder; live generated-app proof is separate.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-10T02:11:37.821Z",
    "resolved_at": null
  },
  {
    "id": 17,
    "kind": "deviation",
    "phase": "133",
    "file": "test/install_smoke/evidence_census_test.exs",
    "line": null,
    "description": "Classified per-test unique census fixture writes for the async-safety guard.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-10T02:12:36.558Z",
    "resolved_at": "2026-09-10T02:13:07.278Z"
  },
  {
    "id": 18,
    "kind": "deviation",
    "phase": "133",
    "file": "scripts/maintainer/evidence_census.exs",
    "line": null,
    "description": "Corrected the census performance detector to the actual archived Phase 132 receipt.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-10T02:13:07.391Z",
    "resolved_at": "2026-09-10T02:13:16.387Z"
  },
  {
    "id": 19,
    "kind": "deviation",
    "phase": "133",
    "file": "scripts/ci/verify_nightly_run.sh",
    "line": null,
    "description": "Rejected empty generated census and live-truth JSON before canonical hashing",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-10T22:04:34.028Z",
    "resolved_at": "2026-09-10T22:05:06.934Z"
  },
  {
    "id": 20,
    "kind": "deviation",
    "phase": "133",
    "file": "scripts/ci/verify_nightly_run.sh",
    "line": null,
    "description": "Restored detached Git identity for exact-subject validator execution",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-10T22:04:34.174Z",
    "resolved_at": "2026-09-10T22:05:07.060Z"
  },
  {
    "id": 21,
    "kind": "deviation",
    "phase": "133",
    "file": "scripts/maintainer/evidence_census.exs",
    "line": null,
    "description": "Canonicalize the inspected root through the physical resolver so platform symlink aliases do not reject contained detector inputs",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-11T17:20:05.449Z",
    "resolved_at": "2026-09-11T17:20:27.089Z",
    "milestone": "v1.26"
  },
  {
    "id": 22,
    "kind": "deviation",
    "phase": "133",
    "file": "scripts/maintainer/validate_phase_133_reconciliation.exs",
    "line": null,
    "description": "Bootstrapped the literal standalone Elixir verification path from repository-bounded compiled dependencies",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-12T02:07:24.771Z",
    "resolved_at": "2026-09-12T02:07:50.462Z",
    "milestone": "v1.26"
  },
  {
    "id": 23,
    "kind": "deviation",
    "phase": "133",
    "file": ".planning/ROADMAP.md",
    "line": null,
    "description": "Corrected halted Plan 133-27 Roadmap tracking after the generic summary-count handler rechecked it",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-12T02:07:24.858Z",
    "resolved_at": "2026-09-12T02:07:50.550Z",
    "milestone": "v1.26"
  },
  {
    "id": 24,
    "kind": "deviation",
    "phase": "133",
    "file": ".planning/phases/133-evidence-charter-and-live-truth/133-30-PLAN.md",
    "line": null,
    "description": "Used the shipped detached ledger-plus-receipt validator interface because the plan's literal --census flag is obsolete.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-12T02:52:04.986Z",
    "resolved_at": "2026-09-12T02:52:12.603Z",
    "milestone": "v1.26"
  },
  {
    "id": 25,
    "kind": "deviation",
    "phase": "133",
    "file": "test/install_smoke/nightly_policy_test.exs",
    "line": null,
    "description": "Applied the supported Elixir formatter's deterministic indentation and rebound the census to the post-fix subject.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-12T02:52:05.087Z",
    "resolved_at": "2026-09-12T02:52:12.726Z",
    "milestone": "v1.26"
  },
  {
    "id": 26,
    "kind": "deviation",
    "phase": "133",
    "file": ".planning/ROADMAP.md",
    "line": null,
    "description": "Restored Plan 133-27 to unchecked halted status and corrected post-Plan-30 semantic totals after the generic progress handler rechecked it.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-12T02:53:16.183Z",
    "resolved_at": "2026-09-12T02:53:16.295Z",
    "milestone": "v1.26"
  },
  {
    "id": 27,
    "kind": "deviation",
    "phase": "133",
    "file": ".planning/ROADMAP.md",
    "line": null,
    "description": "Restored Plan 133-27 to unchecked halted status and corrected post-Plan-31 semantic totals after the generic progress handler rechecked it.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-12T03:24:16.251Z",
    "resolved_at": "2026-09-12T03:24:16.357Z",
    "milestone": "v1.26"
  },
  {
    "id": 28,
    "kind": "unrun-verify",
    "phase": "133",
    "file": "scripts/ci/verify_nightly_run.sh",
    "line": null,
    "description": "Plan 133-32 terminal run/log/receipt and promotion gates were not run because the sole collector invocation halted on GitHub API rate limiting before candidate creation.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T03:36:52.032Z",
    "resolved_at": null,
    "milestone": "v1.26"
  },
  {
    "id": 29,
    "kind": "deviation",
    "phase": "133",
    "file": ".planning/ROADMAP.md",
    "line": null,
    "description": "Restored Plans 133-27 and 133-32 to unchecked halted status and corrected post-halt semantic totals after the generic progress handler rechecked both.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-12T03:37:31.584Z",
    "resolved_at": "2026-09-12T03:37:45.885Z",
    "milestone": "v1.26"
  },
  {
    "id": 30,
    "kind": "deviation",
    "phase": "133",
    "file": ".planning/ROADMAP.md",
    "line": null,
    "description": "Generic progress updater counted halted summaries as completed; restored exact post-Plan-34 branch arithmetic and unchecked halt rows",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-12T20:25:06.283Z",
    "resolved_at": "2026-09-12T20:25:26.849Z",
    "milestone": "v1.26"
  },
  {
    "id": 31,
    "kind": "unrun-verify",
    "phase": "133",
    "file": "scripts/ci/test_verify_nightly_run.sh",
    "line": null,
    "description": "Plan 133-37 qualification commands after the detached exact-SHA census failure were not run because the one authorized attempt was terminal",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-13T02:16:05.419Z",
    "resolved_at": null,
    "milestone": "v1.26"
  },
  {
    "id": 32,
    "kind": "deviation",
    "phase": "133",
    "file": ".planning/phases/133-evidence-charter-and-live-truth/133-37-SUMMARY.md",
    "line": null,
    "description": "Plan 133-37 halted on immutable run 34732110533 after detached exact-SHA census qualification could not start :rindle",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-13T02:16:05.510Z",
    "resolved_at": null,
    "milestone": "v1.26"
  },
  {
    "id": 33,
    "kind": "unrun-verify",
    "phase": "133",
    "file": ".planning/phases/133-evidence-charter-and-live-truth/133-42-PLAN.md",
    "line": null,
    "description": "Plan 133-42 Task 2 qualification and promotion gates were not run after immutable Nightly run 34768317696 failed.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-13T16:29:31.472Z",
    "resolved_at": null,
    "milestone": "v1.26"
  }
]
````
