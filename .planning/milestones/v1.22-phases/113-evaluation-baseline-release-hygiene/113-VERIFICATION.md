---
phase: 113-evaluation-baseline-release-hygiene
verified: 2026-06-30T12:05:00Z
status: passed
score: 11/11 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: none
  previous_score: n/a
---

# Phase 113: Evaluation Baseline & Release Hygiene — Verification Report

**Phase Goal:** Open the v1.22 milestone with an evidence-cited scored-weakness summary, unstick the merged-but-unreleased v1.21 adopter fixes by cutting the 0.3.2 release, and reconcile the planning truth those gaps created.

**Verified:** 2026-06-30
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

The phase goal decomposes into three deliverables, all observably true in the codebase:
1. EVAL-01 scored-weakness summary exists and maps to closing phases (verified).
2. Hex 0.3.2 is LIVE (`latest_stable_version == 0.3.2`), carrying the v1.21 `lib/` fixes, cut by release-please (verified end-to-end including remote tag `rindle-v0.3.2` @ `d228b67`).
3. Planning truth reconciled across PROJECT/MILESTONES/RETROSPECTIVE + RELEASE-TRAIN ledger; root cause recorded; SEED-003/004 lifecycle corrected (verified).

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | EVAL-01 summary at locked path, ~1 page, two scored tables, dimension→phase column byte-faithful to REQUIREMENTS | ✓ VERIFIED | `.planning/milestones/v1.22-OSS-QUALITY-EVAL.md` exists (47 lines); 2 `Dimension/Score` tables; all 12 req-IDs (TRUST/META→114, VERSION/README→115, MIGRATE→116, ISO23→v1.23) present and mapped exactly to REQUIREMENTS §Traceability |
| 2 | Hex 0.3.2 published (v1.21 :epipe/$callers fixes reach adopters); tag exists | ✓ VERIFIED | `curl hex.pm/api/packages/rindle → 0.3.2`; remote tag `rindle-v0.3.2` → `d228b67` ("chore(main): release rindle 0.3.2 (#47)") |
| 3 | mix.exs / manifest / CHANGELOG reflect 0.3.2, written by release-please not by hand | ✓ VERIFIED | At tag `d228b67`: `@version "0.3.2"`, manifest `0.3.2`, CHANGELOG `[0.3.2]` entry — authored by release-please bot commit; ZERO phase-113 commits touched these files |
| 4 | release-train-drift.yml drift guard ships, OFF the required CI path | ✓ VERIFIED | `.github/workflows/release-train-drift.yml` exists; NOT referenced in `ci.yml`; daily cron + dispatch, least-privilege |
| 5 | release.yml token-validity step fails loud (auth + Actions-scope) | ✓ VERIFIED | `release.yml:60` step `Validate RELEASE_PLEASE_TOKEN`: `gh api user` (line 74) + `repos/.../actions/permissions` probe (line 83); a STEP inside existing `release-please` job, no new required job |
| 6 | release_guard_meta_test passes; locks guards OFF required path + ci.yml byte-stable | ✓ VERIFIED | `mix test test/install_smoke/release_guard_meta_test.exs` → 6 tests, 0 failures |
| 7 | ci.yml `name: CI` byte-unchanged | ✓ VERIFIED | `head -1 ci.yml` == `name: CI`; ci.yml NOT in phase-113 changed-file set |
| 8 | public_smoke.sh valid; junit abnormal-exit path hardened (env -u CI on install-smoke shell-out) | ✓ VERIFIED | `bash -n scripts/public_smoke.sh` valid; `env -u CI mix test test/install_smoke/generated_app_smoke_test.exs` at line 50 |
| 9 | Root cause recorded; superseded "PR #40 was the 0.3.2 PR" framing ABSENT | ✓ VERIFIED | `guides/release_publish.md` + `RELEASE-TRAIN.md` carry corrected chain ("PR #40 was the 0.3.1 PR"); literal `PR #40 was the 0.3.2` absent from both |
| 10 | PROJECT/MILESTONES/RETROSPECTIVE say "0.3.2 now live"; no v1.21 archive edited | ✓ VERIFIED | "released in v1.22 Phase 113" + "now live" in PROJECT.md; "0.3.2" reconciled in MILESTONES.md + RETROSPECTIVE.md; NO `milestones/v1.21-*` path in phase-113 diff |
| 11 | SEED-003/004 frontmatter `status: consumed` + `consumed_by` | ✓ VERIFIED | Both seeds read `status: consumed` with `consumed:` + `consumed_by:` (v1.20 18/18, v1.21 24/24) |

**Score:** 11/11 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.planning/milestones/v1.22-OSS-QUALITY-EVAL.md` | EVAL-01 summary, 2 tables, phase mapping | ✓ VERIFIED | 47 lines; 2 scored tables; 12 req-IDs mapped byte-faithfully |
| `.github/workflows/release-train-drift.yml` | drift guard, non-required | ✓ VERIFIED | exists; not in ci.yml |
| `.github/ISSUE_TEMPLATE/release-train-drift.md` | rolling-issue template | ✓ VERIFIED | exists |
| `.github/workflows/release.yml` | token-validity step added | ✓ VERIFIED | step at line 60, dual probe |
| `test/install_smoke/release_guard_meta_test.exs` | locks guards OFF required path | ✓ VERIFIED | 6 tests pass |
| `scripts/public_smoke.sh` | junit hardening | ✓ VERIFIED | `env -u CI` on install-smoke shell-out; valid syntax |
| `guides/release_publish.md` | corrected root-cause prose | ✓ VERIFIED | corrected chain; superseded framing absent |
| `.planning/RELEASE-TRAIN.md` | dated root-cause + published rows | ✓ VERIFIED | 2026-06-29 root-cause row + 2026-06-30 published row (run 28420598348, SHA d228b67) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| EVAL doc dimension column | REQUIREMENTS.md §Traceability | byte-faithful phase mapping | ✓ WIRED | governance→114, versioning/README→115, host-respect→116, schema-flip→v1.23 all match |
| Token rotation → release-please → publish | Hex 0.3.2 live | canonical release pipeline (D-12 sequencing) | ✓ WIRED | run 28420598348 GREEN; tag rindle-v0.3.2; truth edits committed after publish observed |
| both guards | ci.yml ci-summary needs: | must NOT appear (locked by meta-test) | ✓ WIRED (correctly absent) | meta-test green; ci.yml unchanged |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Hex live version | `curl hex.pm/api/packages/rindle` | `0.3.2` | ✓ PASS |
| Remote release tag | `git ls-remote --tags origin rindle-v0.3.2` | `d228b67` | ✓ PASS |
| Meta-test | `mix test .../release_guard_meta_test.exs` | 6 tests, 0 failures | ✓ PASS |
| public_smoke syntax | `bash -n scripts/public_smoke.sh` | valid | ✓ PASS |
| Release-coupling (no hand-edit) | `git diff 43b0ef8..HEAD` on mix.exs/manifest/CHANGELOG | not in set | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| EVAL-01 | 113-01 | Scored-weakness summary | ✓ SATISFIED | EVAL doc verified (Truth 1) |
| HYGIENE-01 | 113-02/03/04 | 0.3.2 cut + reconcile + guards | ✓ SATISFIED | Hex live, tag, guards, prose, truth edits (Truths 2–10) |
| HYGIENE-02 | 113-01 | SEED-003/004 → consumed | ✓ SATISFIED | both seeds consumed (Truth 11) |

No orphaned requirements — all three phase-113 requirements claimed by plans and satisfied.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | No TBD/FIXME/XXX in any modified workflow/test/script file | — | clean |

### Release-Coupling Invariants (D-09 / SC7)

All hard release-coupling invariants preserved:
- `ci.yml` `name: CI` (line 1) byte-unchanged; ci.yml not in phase diff.
- mix.exs / `.release-please-manifest.json` / CHANGELOG.md NOT touched by any phase-113 commit — release-please authored the 0.3.2 bump on `d228b67`.
- No `lib/` change in the phase.
- Neither new guard added to the sole required `CI Summary` path (locked by meta-test).

**Note on local working-tree version state (informational, NOT a gap):** Local `mix.exs`/`manifest` read `0.3.1` because the local `main` branch is "ahead 14, behind 1" of `origin/main` — it has not yet pulled the release-please bump commit `d228b67` (the 1 commit it is "behind"). The release-please bump branched from the same merge-base (`43b0ef8`) and is correctly authored by the bot. The published artifact (Hex, tag) reflects 0.3.2; this is the expected release-please topology, not a hand-edit deviation.

### Human Verification Required

None — all criteria machine-observable. The one human checkpoint (RELEASE_PLEASE_TOKEN rotation) was satisfied during the 2026-06-30 session and its downstream publish is confirmed via Hex API + remote tag.

### Gaps Summary

No gaps. All 11 observable truths, 8 artifacts, 3 key links, 5 behavioral spot-checks, and 3 requirements verified against the codebase and live Hex/git state. The phase goal — opening EVAL summary, 0.3.2 release cut, and planning-truth reconciliation — is achieved.

---

_Verified: 2026-06-30T12:05:00Z_
_Verifier: Claude (gsd-verifier)_
