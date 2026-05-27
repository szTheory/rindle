# Phase 77: Planning Artifact Cleanup - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Close v1.15 post-ship **planning truth drift** identified in the milestone audit. Docs-only — no `lib/`, no `ci.yml`, no new ExUnit tests.

**In scope (PLAN-01):**
- Phase 71 `71-VALIDATION.md` — Nyquist closure via fresh verify + metadata reconciliation
- Phase 72 `72-VALIDATION.md` — mark stale `72-01-01` row ✅ green
- `.planning/STATE.md` — extended surgical truth sync (position block + milestone section + operator next steps)
- Bounded `v1.15-MILESTONE-AUDIT.md` ledger sync (77-03) for planning items fixed here
- **Planning Truth Closure Contract** — grep must-haves in 77-VERIFICATION for future milestone-audit phases

**Out of scope:**
- Full `/gsd-validate-phase 71` with auditor subagent
- Binding proof/parity to merge-blocking CI (Phase 75)
- TusPlug moduledoc parity test (Phase 76)
- `docs_parity_test.exs` extension for `.planning/STATE.md`
- v1.15 STATE archive to milestones/ (defer to `/gsd-complete-milestone`)
- Full STATE.md regen or PROJECT.md sync **during** Phase 77 execution
- Flipping STATE frontmatter to v1.16 **during** Phase 77 (defer to post-77 boundary)
- Clearing CI integration gaps in audit (Phases 75–76)
- Final `/gsd-audit-milestone` (after Phase 75)

</domain>

<decisions>
## Implementation Decisions

### Nyquist closure depth (Phase 71 + 72)

- **D-01:** **Targeted re-verify (Option A)** — re-run all four Phase 71 verify commands fresh before marking rows green; do not use blind metadata flip (Option B) or full `/gsd-validate-phase 71` (Option C).
- **D-02:** **Fix stale criterion first** — row `71-02-02` acceptance text changes from `≥ 8` to `≥ 6` (matches shipped `ci.yml` and `71-VERIFICATION.md` evidence of 6 comment blocks).
- **D-03:** Phase 71 verify block (run in order):
  ```bash
  rg '## CI lane severity' RUNNING.md
  mix test test/install_smoke/docs_parity_test.exs
  ! rg -A2 'package-consumer:' .github/workflows/ci.yml | rg 'continue-on-error'
  test "$(rg 'Phase 71 \(CI proof honesty\)' .github/workflows/ci.yml | wc -l | tr -d ' ')" -ge 6
  ```
- **D-04:** After green runs: flip all four Per-Task rows ✅, sign-off checklist complete, frontmatter `status: complete` + `nyquist_compliant: true`, `Approval: approved 2026-05-27`, append **Validation Audit** table (Phase 73 pattern).
- **D-05:** Phase 72 — mark `72-01-01` ✅ green; optional fresh `mix test test/rindle/batch_owner_erasure_task_test.exs` for timestamp note.
- **D-06:** Do not conflate Nyquist metadata closure with CI enforcement depth (Phase 75 charter).

### STATE.md update scope

- **D-07:** **Extended surgical fix (A+)** — not frontmatter v1.16 flip (B) or PROJECT.md sync (C) during Phase 77.
- **D-08:** **Frontmatter in Phase 77:** bump `last_updated` / `last_activity` only; **leave** `milestone: v1.15`, `status: Milestone v1.15 shipped`, `progress` 4/4 @ 100% until post-77 boundary.
- **D-09:** **Current Position target:**
  ```
  Phase: 74 (complete)
  Plan: complete — milestone v1.15 shipped
  Status: Between milestones
  ```
- **D-10:** **Current Milestone section:** `Between milestones`; `Previous shipped: v1.15`; add `Next queued: v1.16 CI Enforcement & Planning Hygiene (Phases 75–77; execute 77→76→75)`.
- **D-11:** **Next Step:** point to Phase 76/75 on ROADMAP (not "demand-gated v1.16+").
- **D-12:** **Operator Next Steps:** remove `/gsd-plan-phase 71`; replace with post-77 queue (Phase 76 TusPlug lock, then Phase 75 proof lanes).
- **D-13:** **Post-Phase-77 boundary (orchestrator, not 77-02):** flip STATE frontmatter to `milestone: v1.16`, reset progress counters (1/3 after 77), set `Active: v1.16` before Phase 76 execution.
- **D-14:** **PROJECT.md sync deferred** to post-77 or `/gsd-progress` — charter-level, not PLAN-01 deliverable.

### Audit ledger timing (77-03)

- **D-15:** **Include 77-03 as bounded ledger sync (Option C)** — partial patch after 77-01/02; not full audit rewrite (A) nor defer-all (B).
- **D-16:** Patch only planning items fixed in Phase 77:
  - Remove Phase 72 + 74 tech_debt blocks; from Phase 71 remove Nyquist item only (keep CI enforcement bullet)
  - Nyquist frontmatter: move 71 to `compliant_phases`; set `overall: complete`
  - Remove STATE drift bullet from integration prose; **do not** touch CI-01/PROOF-06/TRUTH-04 gaps
  - Leave `status: tech_debt`, integration 18/20, flows 2/3 unchanged
  - Bump `audited:` timestamp; note *"Partial ledger sync — Phase 77; full re-audit after Phase 75"*
- **D-17:** Full `/gsd-audit-milestone v1.15` runs **once after Phase 75** before `/gsd-complete-milestone`.

### Recurrence prevention

- **D-18:** **Planning Truth Closure Contract (Option D + B tail)** — encode grep must-haves in `77-VERIFICATION.md`; optional RETROSPECTIVE pattern note (77-03 tail).
- **D-19:** **No** `docs_parity_test` extension for `.planning/` (Option C rejected — wrong contract surface; Phase 75 owns adopter docs proof).
- **D-20:** Standard grep must-haves for final milestone-audit phases:
  ```bash
  # STATE position (when milestone shipped)
  ! grep -q '^Plan: Not started' .planning/STATE.md

  # Nyquist per shipped phase N
  grep -q 'nyquist_compliant: true' .planning/phases/N-*/N-VALIDATION.md
  grep -q 'Approval: approved' .planning/phases/N-*/N-VALIDATION.md
  ! grep '⬜ pending' .planning/phases/N-*/N-VALIDATION.md
  ```
- **D-21:** **Mandatory at phase close going forward:** flip VALIDATION sign-off atomically when VERIFICATION → passed (Phase 73 retroactive pattern becomes norm, not cleanup phase).
- **D-22:** Future automation (`scripts/planning_truth_verify.sh` + CI lane) deferred to post-v1.16 if needed — accrue-style named lane, separate charter.

### Claude's Discretion

- Exact wording of STATE `Next Step` and RETROSPECTIVE pattern paragraph (must preserve decision intent).
- Whether to append Validation Audit one-liner to 72-VALIDATION.md (recommended if 72 re-run performed).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 77 scope and requirements
- `.planning/ROADMAP.md` — Phase 77 goal, success criteria, execute-first ordering
- `.planning/REQUIREMENTS.md` — PLAN-01 requirement definition
- `.planning/milestones/v1.15-MILESTONE-AUDIT.md` — source gaps and 77-03 patch targets

### Patterns to mirror
- `.planning/phases/73-nyquist-validation-closure/73-VALIDATION.md` — retroactive Nyquist closure precedent
- `.planning/phases/71-ci-proof-honesty/71-VERIFICATION.md` — evidence for Phase 71 row reconciliation
- `.planning/phases/72-mix-batch-failure-proof/72-VERIFICATION.md` — evidence for 72-01-01 row
- `.planning/phases/74-support-truth-milestone-audit/74-VERIFICATION.md` — weak STATE gate to avoid repeating

### Project DNA
- `prompts/gsd-rindle-elixir-oss-dna.md` — truth ownership, milestone honesty, pitfall ledger → checks
- `prompts/gsd-rindle-research-index.md` — accrue/sigra/scrypath CI and planning truth patterns

### Artifacts to edit
- `.planning/phases/71-ci-proof-honesty/71-VALIDATION.md`
- `.planning/phases/72-mix-batch-failure-proof/72-VALIDATION.md`
- `.planning/STATE.md`
- `.planning/milestones/v1.15-MILESTONE-AUDIT.md` (77-03 bounded patch)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 71 verify commands already defined in `71-VALIDATION.md` Per-Task map — reuse verbatim after criterion fix
- Phase 73 grep gates for Nyquist compliance — reuse pattern for 77-VERIFICATION must-haves

### Established Patterns
- **Phase 73 retroactive Nyquist:** evidence cross-read + fresh verify + metadata reconciliation + Validation Audit table
- **Phase 14/74 grep-as-contract:** VERIFICATION must-haves as shell greps, not ExUnit
- **Accrue/sigra:** named truth lanes — adopter docs (Phase 75) separate from maintainer planning (Phase 77)

### Integration Points
- Post-77: orchestrator flips STATE to v1.16 active before Phase 76
- Post-75: full milestone re-audit closes remaining integration/flow gaps in audit ledger

</code_context>

<specifics>
## Specific Ideas

Discussion + subagent research (2026-05-27) locked all four gray areas with one coherent plan:

1. Re-verify beats blind flip; fix `≥ 8` → `≥ 6` before running 71-02-02
2. STATE extended surgical fix during 77; v1.16 frontmatter activation **after** 77 completes
3. Bounded audit ledger sync now; full re-audit after Phase 75
4. Grep-backed Planning Truth Closure Contract in VERIFICATION — not docs_parity_test

</specifics>

<deferred>
## Deferred Ideas

- **PROJECT.md v1.16 charter sync** — post-Phase 77 or `/gsd-progress`
- **STATE frontmatter v1.16 activation** — post-Phase 77 boundary (before Phase 76)
- **`scripts/planning_truth_verify.sh` + CI lane** — future v1.16+ hygiene if drift recurs
- **Full v1.15 audit regeneration** — after Phase 75 via `/gsd-audit-milestone`
- **docs_parity_test for .planning/STATE.md** — wrong surface; rejected

</deferred>

---

*Phase: 77-planning-artifact-cleanup*
*Context gathered: 2026-05-27 (discuss-phase, all areas + subagent research)*
