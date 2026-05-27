# Phase 80: Post-Ship Planning Hygiene - Context

**Gathered:** 2026-05-27 (from v1.17-MILESTONE-AUDIT tech_debt)
**Status:** Ready for planning

<domain>
## Phase Boundary

Close post-ship narrative drift in planning artifacts identified by `/gsd-audit-milestone` on v1.17. All v1.17 requirements (TRUTH-06, PLAN-02, CI-04) are satisfied — this phase fixes cosmetic/stale tense in threads and charter frontmatter so maintainers can archive v1.17 with one honest story.

**In scope:** `.planning/` markdown only (threads, PROJECT.md, STATE.md). No `lib/`, no `ci.yml` wiring changes.

**Out of scope:** New requirements, Credo/Dialyzer policy changes (CI-04 closed in Phase 79), Doctor/AV doctor CI-04 record (D-07 intentional scope guard — informational only).

</domain>

<decisions>
## Implementation Decisions

### Path-to-done thread (`.planning/threads/2026-05-27-path-to-done-roadmap.md`)

- **D-01:** L33–34 — Replace "Credo/Dialyzer merge-blocking **decision** remains Phase 79" with shipped language: CI-04 recorded in Phase 79 (2026-05-27); Credo/Dialyzer advisory per RUNNING.md.
- **D-02:** L51–57 — Change "Milestone v1.17 (current)" / "Status: Active" to **shipped** tense; reference Phases 78–79 complete.
- **D-03:** L111 — Change "Branch C: … (selected — active)" to **shipped** (selected and completed 2026-05-27).
- **D-04:** L182–183 — Update verdict maintainer action from "complete v1.17 Branch C" to "v1.17 Branch C **shipped**; demand-gated pause active unless LIFE-06/STREAM-10 signal."
- **D-05:** L4 header `Status: active` — Consider `Status: canonical (v1.17 shipped 2026-05-27)` or equivalent; document that thread remains canonical ordering reference post-ship.

### Assessment thread (`.planning/threads/2026-05-27-post-v116-milestone-assessment.md`)

- **D-06:** L83–84 — Replace "Active micro milestone (Branch C)" with **shipped** v1.17 summary; preserve CI-04 Recorded block at L118 (already correct).
- **D-07:** L4 header `Status: active` — Align with path-to-done: canonical post-v116 assessment, v1.17 shipped boundary.

### PROJECT.md charter

- **D-08:** L333–338 Active section — Move TRUTH-06, PLAN-02, CI-04 bullets to Validated (with v1.17 phase refs). Active section should reflect v1.18+ demand-gated pause only.

### STATE.md frontmatter drift

- **D-09:** Current Position block — Update `Phase: 80`, `Plan: Not started` (until 80-01 planned), remove stale Phase 79 "Plan: Not started" contradiction with frontmatter `status: completed`.
- **D-10:** After Phase 80 verification, set Current Position to reflect v1.17 fully archived-ready state (Phase 80 complete, demand-gated pause).

### Verification

- **D-11:** Grep audit (zero matches after edits):
  - `remains Phase 79`
  - `selected — active`
  - `Active micro milestone`
  - `Milestone v1.17 (current)` (unless explicitly historical quote)
- **D-12:** Manual read: path-to-done ↔ assessment ↔ STATE ↔ ROADMAP ↔ REQUIREMENTS tell one post-ship story.

### Scope guardrails

- **D-13:** No RUNNING.md CI policy edits unless fixing a direct contradiction (CI-04 already recorded).
- **D-14:** Doctor/AV doctor advisory without separate CI-04 record — **do not fix** (audit marks intentional D-07 scope).

</decisions>

<canonical_refs>
## Canonical References

### Audit source

- `.planning/milestones/v1.17-MILESTONE-AUDIT.md` — `tech_debt.planning-hygiene` items (8 locations, 5 actionable in this phase)

### Edit targets

- `.planning/threads/2026-05-27-path-to-done-roadmap.md`
- `.planning/threads/2026-05-27-post-v116-milestone-assessment.md`
- `.planning/PROJECT.md` — Active vs Validated sections
- `.planning/STATE.md` — Current Position block

### Shipped truth (do not contradict)

- `.planning/ROADMAP.md` — Phases 78–79 complete
- `.planning/REQUIREMENTS.md` — TRUTH-06, PLAN-02, CI-04 all [x] Complete
- `RUNNING.md` — `### Static analysis policy (CI-04)`
- `.github/workflows/ci.yml` — Credo/Dialyzer advisory

</canonical_refs>

<specifics>
## Specific Ideas

- Mirror Phase 77/78 hygiene-only pattern: grep + manual read verification gate, no public API.
- Two-plan split: 80-01 threads, 80-02 PROJECT/STATE + cross-artifact verification.

</specifics>

<deferred>
## Deferred Ideas

- Doctor/AV doctor explicit CI-04 subsection — out of scope (informational tech debt, D-07 guard).
- `/gsd-complete-milestone v1.17` — run after Phase 80 verification passes.

</deferred>

---

*Phase: 80-post-ship-planning-hygiene*
*Context gathered: 2026-05-27*
