# Phase 77: Planning Artifact Cleanup — Research

**Researched:** 2026-05-27  
**Phase:** 77 — planning-artifact-cleanup  
**Requirement:** PLAN-01

## RESEARCH COMPLETE

## Summary

Phase 77 closes v1.15 post-ship **planning truth drift** identified in `v1.15-MILESTONE-AUDIT.md`. All work is docs-only under `.planning/` — no `lib/`, no `ci.yml`, no new ExUnit tests. The phase mirrors Phase 73's retroactive Nyquist closure pattern but targets phases 71–72 VALIDATION metadata and `STATE.md` position block instead of archive restoration.

## Current Drift (Evidence)

| Artifact | Gap | Evidence |
|----------|-----|----------|
| `71-VALIDATION.md` | All 4 Per-Task rows ⬜ pending; `nyquist_compliant: false`; sign-off incomplete | Frontmatter + Per-Task map |
| `71-VALIDATION.md` row `71-02-02` | Stale criterion `≥ 8` | `71-VERIFICATION.md` confirms 6 Phase 71 comment blocks; `rg 'Phase 71' ci.yml` → 6 matches |
| `72-VALIDATION.md` | Row `72-01-01` ⬜ pending despite sign-off approved | Per-Task map vs frontmatter `nyquist_compliant: true` |
| `STATE.md` | `Plan: Not started` while milestone shipped | Line 28; audit tech_debt item |
| `STATE.md` | Stale operator next step `/gsd-plan-phase 71` | Line 74 |
| `v1.15-MILESTONE-AUDIT.md` | Nyquist overall `partial`; tech_debt blocks for 71/72/74 | Frontmatter + Tech Debt section |

## Technical Approach

### 1. Phase 71 Nyquist closure (77-01)

**Pattern:** Phase 73 retroactive reconciliation — fix criterion → fresh verify → flip metadata.

**Order of operations (mandatory):**
1. Fix `71-02-02` Automated Command acceptance from `≥ 8` to `≥ 6` before any verify run.
2. Run all four verify commands in order (D-03):
   ```bash
   rg '## CI lane severity' RUNNING.md
   mix test test/install_smoke/docs_parity_test.exs
   ! rg -A2 'package-consumer:' .github/workflows/ci.yml | rg 'continue-on-error'
   test "$(rg 'Phase 71 \(CI proof honesty\)' .github/workflows/ci.yml | wc -l | tr -d ' ')" -ge 6
   ```
3. Flip all four Per-Task rows to ✅ green.
4. Complete Validation Sign-Off checklist; set frontmatter `status: complete`, `nyquist_compliant: true`.
5. Set `**Approval:** approved 2026-05-27`.
6. Append **Validation Audit** table (Phase 73 pattern).

**Do not:** Run full `/gsd-validate-phase 71` with auditor subagent (out of scope per CONTEXT D-01).

### 2. Phase 72 row closure (77-02)

**Pattern:** Evidence cross-read from `72-VERIFICATION.md` + optional fresh test for timestamp.

- Mark `72-01-01` row ✅ green.
- Optional: `mix test test/rindle/batch_owner_erasure_task_test.exs` for Validation Audit note.
- Append Validation Audit one-liner if test re-run performed (D-22 discretion).

Frontmatter already has `nyquist_compliant: true` and approved sign-off — only Per-Task row stale.

### 3. STATE.md surgical fix (77-02)

**Pattern:** Extended surgical fix (D-07) — position block + milestone section + operator steps.

**Frontmatter during Phase 77:** Bump `last_updated` / `last_activity` only. **Do not** flip to v1.16 (D-08, D-13 deferred to post-77 orchestrator).

**Current Position target (D-09):**
```
Phase: 74 (complete)
Plan: complete — milestone v1.15 shipped
Status: Between milestones
```

**Current Milestone (D-10):**
- `Between milestones`
- `Previous shipped: v1.15`
- Add `Next queued: v1.16 CI Enforcement & Planning Hygiene (Phases 75–77; execute 77→76→75)`

**Next Step (D-11):** Point to Phase 76/75 on ROADMAP — not "demand-gated v1.16+".

**Operator Next Steps (D-12):** Remove `/gsd-plan-phase 71`; replace with post-77 queue (Phase 76 TusPlug lock, then Phase 75 proof lanes).

### 4. Audit ledger bounded sync (77-03)

**Pattern:** Partial patch (D-15/D-16) — not full audit rewrite.

**Patch targets in `v1.15-MILESTONE-AUDIT.md`:**
- Remove entire `tech_debt` entries for phases 72 and 74.
- From phase 71 `tech_debt` entry: remove Nyquist item only; keep CI enforcement bullet.
- Frontmatter `nyquist`: move 71 to `compliant_phases: [71, 72, 73, 74]`; remove `partial_phases`; set `overall: complete`.
- Integration prose: remove STATE drift bullet (`Plan: Not started`).
- **Leave unchanged:** `status: tech_debt`, `integration: 18/20`, `flows: 2/3`, CI-01/PROOF-06/TRUTH-04 gap entries.
- Bump `audited:` timestamp; add note: *"Partial ledger sync — Phase 77; full re-audit after Phase 75"*.

### 5. Planning Truth Closure Contract (77-03)

**Pattern:** Phase 14/74 grep-as-contract — encode must-haves in `77-VERIFICATION.md`, not ExUnit.

Standard greps (D-20):
```bash
# STATE position (when milestone shipped)
! grep -q '^Plan: Not started' .planning/STATE.md

# Nyquist per shipped phase N (71, 72 for this milestone)
grep -q 'nyquist_compliant: true' .planning/phases/N-*/N-VALIDATION.md
grep -q 'Approval: approved' .planning/phases/N-*/N-VALIDATION.md
! grep '⬜ pending' .planning/phases/N-*/N-VALIDATION.md
```

**Rejected:** `docs_parity_test` extension for `.planning/STATE.md` (D-19 — wrong contract surface; Phase 75 owns adopter docs proof).

## Validation Architecture

Phase 77 verification is grep + targeted mix test probes (reusing shipped test commands as evidence gates, not new tests).

| Property | Value |
|----------|-------|
| **Framework** | Shell grep + existing ExUnit (evidence only) |
| **Quick run** | Per-plan grep commands from VALIDATION.md Per-Task map |
| **Full suite** | All 77-VERIFICATION.md must-have greps |
| **Estimated runtime** | ~20 seconds |

**Per-plan verify surfaces:**
- 77-01: Four Phase 71 commands + 71-VALIDATION.md compliance greps
- 77-02: 72-VALIDATION.md row + STATE.md position greps
- 77-03: Audit frontmatter nyquist + tech_debt greps + 77-VERIFICATION contract

**Wave 0:** Existing infrastructure — no new test files. All verify commands reference shipped artifacts.

## Files to Modify

| File | Plan | Action |
|------|------|--------|
| `.planning/phases/71-ci-proof-honesty/71-VALIDATION.md` | 77-01 | Fix criterion, flip rows, sign-off, audit table |
| `.planning/phases/72-mix-batch-failure-proof/72-VALIDATION.md` | 77-02 | Flip 72-01-01 row green |
| `.planning/STATE.md` | 77-02 | Position block, milestone, next steps |
| `.planning/milestones/v1.15-MILESTONE-AUDIT.md` | 77-03 | Bounded ledger sync |
| `.planning/phases/77-planning-artifact-cleanup/77-VERIFICATION.md` | 77-03 | Create grep contract |

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Blind metadata flip without verify | Mandatory fresh command runs before row flips (D-01) |
| Conflating Nyquist closure with CI enforcement | Keep Phase 71 CI enforcement tech_debt bullet in audit (D-06) |
| Premature v1.16 STATE flip | Frontmatter v1.16 activation is post-77 orchestrator step (D-13) |
| Over-scoping audit rewrite | Patch-only list in D-16; full re-audit deferred to post-Phase 75 |

## Plan Split Recommendation

Three plans in two waves:

| Wave | Plan | Scope |
|------|------|-------|
| 1 | 77-01 | Phase 71 Nyquist closure |
| 1 | 77-02 | Phase 72 row + STATE.md surgical fix |
| 2 | 77-03 | Audit ledger + 77-VERIFICATION contract |

77-01 and 77-02 are parallel-safe (different files). 77-03 depends on 77-01/02 completing first (audit patch references their fixes).

## Canonical References Consulted

- `.planning/phases/73-nyquist-validation-closure/73-VALIDATION.md` — closure precedent
- `.planning/phases/73-nyquist-validation-closure/73-01-PLAN.md` — Validation Audit table format
- `.planning/phases/71-ci-proof-honesty/71-VERIFICATION.md` — Phase 71 evidence
- `.planning/phases/72-mix-batch-failure-proof/72-VERIFICATION.md` — Phase 72 evidence
- `.planning/phases/74-support-truth-milestone-audit/74-VERIFICATION.md` — weak STATE gate to avoid
- `.planning/milestones/v1.15-MILESTONE-AUDIT.md` — source gaps
