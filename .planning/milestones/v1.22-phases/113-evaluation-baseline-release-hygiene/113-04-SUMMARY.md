---
phase: 113-evaluation-baseline-release-hygiene
plan: 04
subsystem: release-hygiene
tags: [release, hex, truth-reconciliation, hygiene-01]
requires: ["113-01", "113-02", "113-03"]
provides: ["hex-0.3.2-live", "live-truth-reconciled", "release-train-published-row"]
affects: [".planning/PROJECT.md", ".planning/MILESTONES.md", ".planning/RETROSPECTIVE.md", ".planning/RELEASE-TRAIN.md"]
tech_stack_added: []
patterns: ["D-11 canonical reconciliation sentence", "D-12 publish-then-edit sequencing"]
key_files_created: [".planning/phases/113-evaluation-baseline-release-hygiene/113-04-SUMMARY.md"]
key_files_modified: [".planning/PROJECT.md", ".planning/MILESTONES.md", ".planning/RETROSPECTIVE.md", ".planning/RELEASE-TRAIN.md"]
decisions:
  - "D-12 honored: truth edits committed only AFTER observing Hex == 0.3.2 (no pre-publish 'now live')."
  - "Included PROJECT.md lines 70 + 109 in the sweep per Pitfall 4 (beyond D-10's literal list)."
  - "Left the v1.21-retro statement (now line 819) untouched per D-10/D-13."
metrics:
  duration: "~3min"
  completed: 2026-06-30
  tasks: 2
  files: 5
status: complete
---

# Phase 113 Plan 04: 0.3.2 Cut + Live-Truth Reconciliation Summary

Hex 0.3.2 confirmed live; the three live-truth planning docs reconcile the aspirational "ships as 0.3.2" prose with reality using the D-11 canonical sentence, committed only after publish was observed (D-12), and a dated published row was appended to the RELEASE-TRAIN ledger.

## What Was Built

- **Task 1 (confirm-only):** Re-confirmed `curl hex.pm/api/packages/rindle | jq .latest_stable_version == 0.3.2`. The human token-rotation checkpoint was satisfied during the 2026-06-30 planning session — no human prompt issued. Recorded the three-blocker reality (token rotation + PR #40 relabel + manual publish-dispatch) and the pending `Actions: write` durable fix for the ledger row.
- **Task 2 (truth edits + ledger):** Edited the three live-truth surfaces (PROJECT.md, MILESTONES.md, RETROSPECTIVE.md) with the D-11 reconciliation (full canonical sentence in the PROJECT.md correction block; short form for inline bullets). Appended the dated published Verification-Log row to RELEASE-TRAIN.md (run 28420598348, merge SHA `d228b67`, Publish + Public Verify GREEN) and updated its Current Baseline to `0.3.2` per the file's own update instruction.

## Edit Catalogue (PROJECT.md, RE-GREPPED — drifted from D-10)

| Surface | What changed |
|---------|--------------|
| line 18-19 | v1.21 "ship as Hex 0.3.2" prose → short-form reconciliation |
| block 43-48 | "Release-state correction" → "Release-state reconciliation (2026-06-30)" with full D-11 sentence + three-fix narrative |
| line 70 | HYGIENE bullet "cut the stuck" → past-tense "now live" (Pitfall 4 recommendation) |
| line 109 | v1.21 collapsed-details "ships Hex 0.3.2" → short-form reconciliation (Pitfall 4 recommendation) |
| line 405 | shipped-list "→ Hex 0.3.2" → short-form reconciliation |
| line 599 | D-v1.21-01 decision row "(0.3.2)" → "(0.3.2 — merged in v1.21, released in v1.22 Phase 113)" |
| line 819 (was 814) | **LEFT untouched** — v1.21-retro statement, accurate as-of-its-context (D-10/D-13) |

## Verification

- `curl -s https://hex.pm/api/packages/rindle | jq -r .latest_stable_version` == `0.3.2` ✓
- D-11 reconciliation grep gates passed: `released in v1.22 Phase 113` + `now live` in PROJECT.md; `0.3.2` in MILESTONES.md + RETROSPECTIVE.md ✓
- `git diff` touches NO `.planning/milestones/v1.21-*` path and NO versioned source (mix.exs / manifest / CHANGELOG) ✓
- Dated published row present in RELEASE-TRAIN.md ✓
- No accidental file deletions; no untracked files ✓

## Deviations from Plan

None — plan executed exactly as written. The human checkpoint (token rotation) was pre-satisfied during planning, so Task 1 ran as a confirm-only auto task as the prompt directed.

## Threat Surface

No new security surface introduced — this plan is doc edits + a release confirmation. T-113-11 (pre-publish "now live") was mitigated by the D-12 sequencing gate, which asserted Hex == 0.3.2 before accepting the edits.

## Requirements Closed

- **HYGIENE-01** — the stuck Hex 0.3.2 release is cut and the aspirational claim reconciled. This is the last plan of Phase 113; HYGIENE-01 closes here.

## Self-Check: PASSED

- SUMMARY.md exists ✓
- Task 2 commit `e54eec6` present in git log ✓
