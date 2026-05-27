# Phase 80: Post-Ship Planning Hygiene — Research

**Researched:** 2026-05-27  
**Phase:** 80-post-ship-planning-hygiene  
**Status:** Ready for planning

## Summary

Phase 80 closes **post-ship narrative drift** in `.planning/` markdown only. All v1.17
requirements are satisfied; the v1.17 milestone audit (`tech_debt.planning-hygiene`) lists
five actionable stale phrases across two threads plus PROJECT.md Active section and STATE.md
Current Position contradictions.

**Pattern:** Mirror Phase 77/78/79 hygiene waves — grep-forbidden phrases + manual read gate,
no `lib/` or `ci.yml` wiring changes.

## Stale Phrase Inventory (grep targets)

| Pattern | File | Line(s) | Fix |
|---------|------|---------|-----|
| `remains Phase 79` | path-to-done | L34 | CI-04 recorded Phase 79; advisory per RUNNING.md |
| `Milestone v1.17 (current)` | path-to-done | L51 | Shipped / completed tense |
| `Status: Active` (v1.17 block) | path-to-done | L53 | Shipped 2026-05-27 |
| `selected — active` | path-to-done | L111 | selected and completed 2026-05-27 |
| `complete v1.17 Branch C` | path-to-done | L182 | v1.17 Branch C **shipped** |
| `Status: active` (header) | both threads | L4–5 | canonical post-ship |
| `Active micro milestone` | assessment | L83 | Shipped v1.17 summary |
| TRUTH-06/PLAN-02/CI-04 under Active | PROJECT.md | L335–338 | Move to Validated |
| Phase 79 Plan: Not started | STATE.md | L28 | Phase 80 planning/execute status |

**Intentionally NOT fixed:** Doctor/AV doctor without CI-04 record (audit D-07 scope guard).

## Shipped Truth (do not contradict)

- `.planning/ROADMAP.md` — Phases 78–79 complete
- `.planning/REQUIREMENTS.md` — TRUTH-06, PLAN-02, CI-04 `[x]` Complete
- `RUNNING.md` — `### Static analysis policy (CI-04)`
- `.github/workflows/ci.yml` — Credo/Dialyzer `continue-on-error: true`
- Assessment L118 — CI-04 Recorded block (already correct from Phase 79)

## Plan Split Recommendation

| Plan | Wave | Scope |
|------|------|-------|
| 80-01 | 1 | Both threads (D-01–D-07) |
| 80-02 | 2 | PROJECT.md + STATE.md + ROADMAP plan checkboxes + full grep gate (D-08–D-14) |

## Validation Architecture

Docs-only phase — no ExUnit. Verification = **grep gate + manual read + lib/ scope guard**.

### Forbidden (must exit 1)

```bash
rg 'remains Phase 79' .planning/threads/
rg 'selected — active' .planning/threads/
rg 'Active micro milestone' .planning/threads/
rg 'Milestone v1.17 \(current\)' .planning/threads/
```

### Required (must exit 0)

```bash
rg 'shipped|Shipped|complete 2026-05-27' .planning/threads/2026-05-27-path-to-done-roadmap.md
rg 'Shipped|shipped' .planning/threads/2026-05-27-post-v116-milestone-assessment.md
rg 'TRUTH-06|PLAN-02|CI-04' .planning/PROJECT.md
rg 'Phase: 80' .planning/STATE.md
```

### Scope guard

```bash
git diff --name-only HEAD -- lib/ .github/workflows/ci.yml RUNNING.md
```

must be empty after phase execution.

### Manual read checklist (7/7)

1. Path-to-done Branch C block reads completed (not in-flight)
2. Path-to-done Milestone 0 prereq says v1.17 shipped (not "after Branch C ships" only if still ambiguous)
3. Assessment L83–85 reflects shipped v1.17 (not active micro milestone)
4. Assessment L118 CI-04 Recorded unchanged
5. PROJECT.md Active has no TRUTH-06/PLAN-02/CI-04 bullets
6. PROJECT.md Validated lists all three with v1.17 phase refs
7. STATE Current Position matches ROADMAP Phase 80 status

## RESEARCH COMPLETE
