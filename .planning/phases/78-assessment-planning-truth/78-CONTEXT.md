# Phase 78: Assessment & Planning Truth - Context

**Gathered:** 2026-05-27 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Close residual planning-truth drift in post-v1.16 assessment and path-to-done threads so adopters and maintainers read one honest CI story. Verify JTBD-MAP anchor at the v1.16 shipped boundary and align PROJECT.md, STATE.md, and ROADMAP.md with the v1.17 charter.

**In scope:** `.planning/` markdown only (threads, JTBD-MAP, PROJECT/STATE/ROADMAP consistency checks). TRUTH-06 and PLAN-02.

**Out of scope:** `ci.yml` wiring changes, Credo/Dialyzer severity decision (Phase 79 / CI-04), any `lib/` public API.

</domain>

<decisions>
## Implementation Decisions

### Stale phrase corrections (TRUTH-06)

- **D-01:** Patch three locations in `.planning/threads/2026-05-27-post-v116-milestone-assessment.md` identified by path-to-done doc drift note:
  - **L30 (Done estimate / Proof & CI row):** Replace "default `mix test` still advisory via Coveralls" with language that `quality` → Run tests with coverage (`mix coveralls`) is **merge-blocking**, citing `ci.yml` and `RUNNING.md`.
  - **L63 (Rough edges):** Replace undifferentiated "Green PR CI does not guarantee full unit/Credo/Dialyzer pass" with a split statement: default unit suite **is** merge-blocking via Coveralls; **Credo, Doctor, and Dialyzer remain advisory** (`continue-on-error: true` in `ci.yml`).
  - **L81–82 (Optional micro milestone):** Remove "optional CI unit-suite blocking" — shipped in commit `0036760`. v1.17 Branch C is planning-truth closure plus deferred static-analysis policy (owned by Phase 79), not optional unit blocking.

- **D-02:** After assessment edits, update `.planning/threads/2026-05-27-path-to-done-roadmap.md`:
  - Rewrite or remove the "Doc drift note" (§ Repo verification) to state drift is **resolved** once L30/L63/L81–82 are fixed.
  - Move "Credo/Dialyzer merge-blocking decision" language to Phase 79 only; Phase 78 corrects **factual** CI severity wording only.
  - Keep cross-links between assessment, path-to-done, JTBD-MAP, `ci.yml`, and `RUNNING.md` consistent.

### JTBD-MAP anchor verification (PLAN-02)

- **D-03:** Anchor milestone **v1.16 (shipped 2026-05-27)** remains correct. Refresh the git sha on the anchor line from stale `3dbf7ab` to current HEAD after verifying the delta is planning/docs/ci-hygiene only (no new JTBD inventory rows).

- **D-04:** Run JTBD update protocol (read anchor → `git log <anchor-sha>..HEAD` → confirm no new shipped jobs → refresh anchor sha → append "What changed since last generation" entry for v1.17 planning-only delta). Do **not** full JTBD regen unless shipped jobs changed.

### Wedge table honesty

- **D-05:** Change assessment ranked-wedge #1 (Planning hygiene) from premature **"Done 2026-05-27"** to **"In progress — v1.17 Phase 78"** until TRUTH-06 grep audit passes. Mark **Done** only after verification.

### Verification (TRUTH-06 closure)

- **D-06:** Close TRUTH-06 with a grep audit plus manual read of both thread files against `RUNNING.md` `## CI lane severity`:
  - **Forbidden phrases** (zero matches after edit): "unit tests advisory", "mix test still advisory", "optional … unit-suite blocking" (and close variants).
  - **Required:** Every CI severity claim in threads cites `.github/workflows/ci.yml` and/or `RUNNING.md` as source of truth.

### Scope guardrails

- **D-07:** No edits to `.github/workflows/ci.yml`, no Credo/Dialyzer policy decision in `RUNNING.md` (Phase 79 / CI-04), no `lib/` changes.

### Claude's Discretion

- Exact replacement wording for L30/L63/L81–82 (must match ci.yml/RUNNING.md facts).
- Wording of path-to-done "drift resolved" note and JTBD "What changed" entry.
- Whether to add a one-line maintainer checklist in phase plan vs inline verification tasks.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### CI source of truth

- `.github/workflows/ci.yml` — Job wiring, `continue-on-error` on Credo/Doctor/Dialyzer vs blocking `mix coveralls`
- `RUNNING.md` — `## CI lane severity` matrix (merge-blocking vs advisory)

### Planning threads (edit targets)

- `.planning/threads/2026-05-27-post-v116-milestone-assessment.md` — Primary TRUTH-06 stale-phrase fixes (L30, L63, L81–82)
- `.planning/threads/2026-05-27-path-to-done-roadmap.md` — Cross-ref alignment, doc drift note resolution, Branch C scope split

### Milestone charter and requirements

- `.planning/PROJECT.md` — v1.17 charter, demand-gated LIFE-06/STREAM-10 posture
- `.planning/STATE.md` — Current milestone position and accumulated context
- `.planning/ROADMAP.md` — Phase 78 goal and success criteria
- `.planning/REQUIREMENTS.md` — TRUTH-06, PLAN-02 acceptance wording

### JTBD anchor

- `.planning/JTBD-MAP.md` — Anchor line verification and update protocol (§ Update protocol)

### v1.16 shipped boundary

- `.planning/milestones/v1.16-ROADMAP.md` — Shipped milestone scope reference
- `.planning/milestones/v1.16-REQUIREMENTS.md` — Requirement traceability for anchor verification

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- No `lib/` changes in this phase. Verification reuses existing CI/docs truth: `ci.yml`, `RUNNING.md`, `docs_parity_test.exs` patterns from v1.16 (reference only).

### Established Patterns

- **Repo-truth evidence ladder:** `ci.yml` > `RUNNING.md` > planning threads (methodology lens).
- **v1.16 phase 77 pattern:** Planning artifact cleanup without public API — same hygiene-only posture for Phase 78.
- **Coveralls merge-blocking:** `mix coveralls` step has no `continue-on-error` (commit `0036760`); Credo/Doctor/Dialyzer steps do.

### Integration Points

- Thread edits must stay consistent with PROJECT.md/STATE.md/ROADMAP.md v1.17 charter already started on `main`.
- JTBD anchor refresh must not contradict `guides/user_flows.md` (no user-visible job changes expected).
- Phase 79 (CI-04) depends on Phase 78 factual truth being settled first.

</code_context>

<specifics>
## Specific Ideas

- Path-to-done already documents the three stale locations — use it as the edit checklist, then mark drift resolved.
- JTBD git delta since `3dbf7ab` is planning/docs/ci-hygiene commits only (`0036760` coveralls, v1.17 milestone start) — anchor refresh, not inventory regen.

</specifics>

<deferred>
## Deferred Ideas

- Credo/Dialyzer merge-blocking vs advisory **decision** and `ci.yml`/`RUNNING.md` policy alignment — Phase 79 (CI-04).
- LIFE-06 force-delete, STREAM-10 second provider — demand-gated v1.18+ per path-to-done.
- Release `gate-ci-green` bypass tightening — out of scope per REQUIREMENTS.md.

None — analysis stayed within phase scope.

</deferred>

---

*Phase: 78-assessment-planning-truth*
*Context gathered: 2026-05-27*
