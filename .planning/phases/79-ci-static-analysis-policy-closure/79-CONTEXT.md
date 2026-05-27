# Phase 79: CI Static-Analysis Policy Closure - Context

**Gathered:** 2026-05-27 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the deferred Credo/Dialyzer severity decision (CI-04) with documented maintainer rationale. Align `RUNNING.md`, `ci.yml` comments, and post-v116 assessment thread so adopters and maintainers read one honest static-analysis policy — no `lib/` changes and no workflow wiring changes unless the recorded decision requires it.

**In scope:** `RUNNING.md` policy record, `ci.yml` comment alignment, assessment/path-to-done thread closure, REQUIREMENTS CI-04 traceability.

**Out of scope:** `lib/` public API, Doctor/AV doctor policy re-decision (CI-04 names Credo/Dialyzer only), GitHub branch-protection settings (outside repo), making Credo/Dialyzer merge-blocking without this explicit decision (already satisfied by recording advisory).

</domain>

<decisions>
## Implementation Decisions

### Static-analysis severity (CI-04 core decision)

- **D-01:** **Keep Credo (strict) and Dialyzer advisory** — retain step-level `continue-on-error: true` in `.github/workflows/ci.yml`. Do not remove `continue-on-error` or change job graph wiring in Phase 79.

- **D-02:** Record explicit decision in `RUNNING.md` under a new `### Static analysis policy (CI-04)` subsection within `## CI lane severity`, stating:
  - **Decision:** Credo and Dialyzer remain advisory.
  - **Rationale (all three CI-04 factors):**
    - **Signal value:** Static analysis catches style and typespec drift; results remain visible in CI logs for maintainers.
    - **Fork latency:** Dialyzer PLT build is slow; merge-blocking would raise contributor and fork PR cost disproportionate to adopter impact.
    - **Green-main honesty:** Adopter-critical lanes are already merge-blocking (`mix coveralls`, `proof`, `package-consumer`, `adopter`, `integration`, contract AV hygiene); static analysis is maintainer hygiene, not adopter contract.

### Documentation and comment alignment

- **D-03:** Update `.github/workflows/ci.yml` quality-job comment block (currently Phase 71 historical note at L94–96) to reference the CI-04 recorded policy in `RUNNING.md` instead of implying the decision is still open. **Comments only — no step wiring changes.**

- **D-04:** Ensure `RUNNING.md` matrix rows for Credo and Dialyzer remain **advisory** and cross-reference the new static-analysis policy subsection. No matrix row may contradict live `ci.yml` wiring.

### Assessment thread closure

- **D-05:** Update `.planning/threads/2026-05-27-post-v116-milestone-assessment.md` Open concerns — CI proof honesty (residual) section (L118): replace **"Decision deferred: Credo / Dialyzer merge-blocking"** with the recorded advisory decision and pointer to `RUNNING.md` `### Static analysis policy (CI-04)`.

- **D-06:** Verify path-to-done thread `.planning/threads/2026-05-27-path-to-done-roadmap.md` Branch C "Done enough" and Phase 79 lines reflect decision **recorded** (not pending). Edit only if still implying an open decision after D-05.

### Scope guardrails

- **D-07:** Doctor and AV doctor steps remain advisory without a separate CI-04 decision record — CI-04 requirement names Credo and Dialyzer only.

- **D-08:** No `lib/` changes. No GitHub branch-protection or required-check configuration changes (outside repo).

### Verification (CI-04 closure)

- **D-09:** Close CI-04 with grep/read verification:
  - **Forbidden after edit:** "Decision deferred" for Credo/Dialyzer in assessment thread Open concerns.
  - **Required:** `RUNNING.md` contains explicit Credo + Dialyzer severity and rationale; `ci.yml` comments match; assessment thread reflects recorded decision.
  - **Reference check:** Every severity claim cites `.github/workflows/ci.yml` and/or `RUNNING.md` as source of truth (Phase 78 pattern).

### Claude's Discretion

- Exact wording of `RUNNING.md` static-analysis policy subsection and `ci.yml` comment block.
- Whether path-to-done needs a one-line edit beyond assessment thread (only if "Done enough" still reads as pending).
- Plan structure: single plan vs split (RUNNING.md + ci.yml vs thread updates).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### CI source of truth

- `.github/workflows/ci.yml` — Credo L97–99, Dialyzer L131–133 (`continue-on-error: true`); quality-job comment block L94–96
- `RUNNING.md` — `## CI lane severity` matrix; target location for `### Static analysis policy (CI-04)`

### Planning threads (edit targets)

- `.planning/threads/2026-05-27-post-v116-milestone-assessment.md` — Open concerns L107–118; remove "Decision deferred"
- `.planning/threads/2026-05-27-path-to-done-roadmap.md` — Branch C done-enough criteria; Phase 79 scope line L116

### Milestone charter and requirements

- `.planning/ROADMAP.md` — Phase 79 goal and success criteria
- `.planning/REQUIREMENTS.md` — CI-04 acceptance wording and out-of-scope guards
- `.planning/PROJECT.md` — v1.17 charter (CI-04 explicit decision)
- `.planning/STATE.md` — Current milestone position

### Prior phase context (dependency)

- `.planning/phases/78-assessment-planning-truth/78-CONTEXT.md` — Factual CI truth settled; CI-04 explicitly deferred here

### Historical policy context

- `.planning/milestones/v1.16-REQUIREMENTS.md` — Out of scope: "Making dialyzer/credo merge-blocking"
- `.planning/milestones/v1.16-ROADMAP.md` — Phase 71 advisory policy preserved through v1.16

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- No `lib/` changes. Phase reuses existing CI/docs surfaces: `ci.yml`, `RUNNING.md`, planning threads.

### Established Patterns

- **Repo-truth evidence ladder:** `ci.yml` > `RUNNING.md` > planning threads (Phase 78 / methodology).
- **Phase 71 pattern:** Document lane severity in `RUNNING.md`; use workflow comments to explain advisory vs blocking posture.
- **Phase 78 pattern:** Grep audit for forbidden phrases + manual read against `RUNNING.md` `## CI lane severity`.
- **Current wiring:** Credo and Dialyzer use step-level `continue-on-error: true`; `mix coveralls` has no `continue-on-error` (merge-blocking since `0036760`).

### Integration Points

- CI-04 closes v1.17 Branch C — last requirement after TRUTH-06 and PLAN-02 (Phase 78).
- Assessment thread "Open concerns" is the primary user-facing signal that policy was deferred; must flip to recorded.
- REQUIREMENTS.md CI-04 checkbox and traceability table update on verification pass.

</code_context>

<specifics>
## Specific Ideas

- Maintainer confirmed all five assumptions without correction — advisory policy is the locked decision.
- Rationale must explicitly address fork latency, signal value, and green-main honesty per CI-04 requirement text.

</specifics>

<deferred>
## Deferred Ideas

- Making Credo/Dialyzer merge-blocking — explicitly rejected for v1.17; revisit only via future milestone charter if maintainer priorities change.
- Doctor/AV doctor merge-blocking policy — out of CI-04 scope; remains advisory without separate decision record.
- Release `gate-ci-green` bypass tightening — out of scope per REQUIREMENTS.md.
- GitHub branch-protection required-check configuration — outside repo; document in RUNNING.md post-merge checklist only.

None — analysis stayed within phase scope.

</deferred>

---

*Phase: 79-ci-static-analysis-policy-closure*
*Context gathered: 2026-05-27*
