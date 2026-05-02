# Phase 14: Validation Closure for Publish Milestone - Research

**Researched:** 2026-04-28
**Domain:** Planning artifact hygiene — Nyquist validation file updates for Phases 10 and 11
**Confidence:** HIGH

---

## Summary

Phase 14 is a planning-artifact-only phase. No production code, no new tests, no
workflow changes. The entire work is updating two YAML-fronted markdown files —
`10-VALIDATION.md` and `11-VALIDATION.md` — so they accurately reflect what was
actually implemented and verified in Phases 10 and 11.

The v1.2 milestone audit (`v1.2-MILESTONE-AUDIT.md`, audited 2026-04-29) landed at
`tech_debt` rather than `passed` for two structural reasons: (1) both VALIDATION
files still carry `wave_0_complete: false` and `status: draft/ready` (not
`complete`), and (2) their Per-Task Verification Maps and Wave 0 checklists still
show `❌ W0` / `⬜ pending` for tasks and artifacts that now exist and pass in CI.
The verification reports (`10-VERIFICATION.md` and `11-VERIFICATION.md`) already
contain the truth — this phase propagates that truth back into the validation
strategy files.

The plans are purely document-editing tasks. Each plan maps to one phase's
VALIDATION file. A planner should model each plan as a single focused editing task
with no Wave 0 gaps, no test infrastructure changes, and no code commits.

**Primary recommendation:** Treat each plan as a document-editing task — read the
corresponding VERIFICATION.md plus the SUMMARY files to identify exactly which
fields changed, then rewrite only the stale fields in the VALIDATION file. Do not
rewrite sections that are already accurate.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Update Phase 10 VALIDATION.md | Planning artifacts | — | Pure markdown/frontmatter edit in `.planning/` tree |
| Update Phase 11 VALIDATION.md | Planning artifacts | — | Pure markdown/frontmatter edit in `.planning/` tree |
| Re-run milestone audit (exit condition) | Audit tooling | — | Runs against the updated artifacts to confirm closure |

---

## Standard Stack

This phase uses no third-party libraries. The only tools involved are:

| Tool | Version | Purpose |
|------|---------|---------|
| File editor (Write/Edit tool) | — | Rewrite VALIDATION.md files |
| ExUnit (`mix test`) | Project-locked | Run Phase 10 test probes to confirm they still pass before closing |
| Bash (`bash scripts/assert_version_match.sh`) | Project-locked | Run Phase 11 quick probe to confirm before closing |

No `npm install` or package additions needed. [VERIFIED: codebase inspection]

---

## Architecture Patterns

### Nyquist Validation File Structure

The project uses a YAML-fronted markdown format for validation files. The fields that
need updating are well-understood from the existing files.

**Frontmatter fields that must change:**

Phase 10 VALIDATION.md (`10-publish-readiness/10-VALIDATION.md`):
- `status: ready` → `status: complete` [VERIFIED: 10-VERIFICATION.md shows verified status]
- `wave_0_complete: false` → `wave_0_complete: true` [VERIFIED: all Wave 0 artifacts exist]

Phase 11 VALIDATION.md (`11-protected-publish-automation/11-VALIDATION.md`):
- `status: draft` → `status: complete` [VERIFIED: 11-VERIFICATION.md shows passed status]
- `wave_0_complete: false` → `wave_0_complete: true` [VERIFIED: scripts/assert_version_match.sh exists]

**Per-Task Verification Map fields that must change:**

Phase 10:
- Task 10-01-01: `File Exists: ❌ W0` → `✅` and `Status: ⬜ pending` → `✅ green`
  (file: `test/install_smoke/release_docs_parity_test.exs` exists) [VERIFIED: ls output]
- Task 10-02-01: `File Exists: ❌ W0` → `✅` and `Status: ⬜ pending` → `✅ green`
  (file: `test/install_smoke/package_metadata_test.exs` exists) [VERIFIED: ls output]
- Task 10-02-02: `File Exists: ❌ W0` → `✅` and `Status: ⬜ pending` → `✅ green`
  (both `mix docs --warnings-as-errors` and preflight wiring now present) [VERIFIED: 10-VERIFICATION.md]

Phase 11:
- Task 11-01-01: `Status: ⬜ pending` → `✅ green`
  (GHA environment config wired in release.yml) [VERIFIED: 11-VERIFICATION.md]
- Task 11-02-01: `File Exists: ❌ W0` → `✅` and `Status: ⬜ pending` → `✅ green`
  (file: `scripts/assert_version_match.sh` exists) [VERIFIED: ls output]

**Wave 0 checklists that must change:**

Phase 10 — all four Wave 0 items flip from `[ ]` to `[x]`:
- `[x] test/install_smoke/release_docs_parity_test.exs` — exists, 4 tests, 0 failures [VERIFIED: 10-VERIFICATION.md behavioral spot-checks]
- `[x] test/install_smoke/package_metadata_test.exs` — exists, 4 tests, 0 failures [VERIFIED: 10-VERIFICATION.md behavioral spot-checks]
- `[x] Release workflow/build command for mix docs --warnings-as-errors` — wired via release_preflight.sh [VERIFIED: 10-02-SUMMARY.md]
- `[x] Warning cleanup for Rindle.LiveView.allow_upload/4` — fixed in lib/rindle/live_view.ex [VERIFIED: 10-02-SUMMARY.md]

Phase 11 — the one Wave 0 item flips from `[ ]` to `[x]`:
- `[x] scripts/assert_version_match.sh` — exists and executable [VERIFIED: ls output, 11-02-SUMMARY.md]

**Validation Sign-Off sections:**

Phase 10 — all six checkboxes flip to checked, Approval advances to "approved":
- `[x] All tasks have <automated> verify or Wave 0 dependencies`
- `[x] Sampling continuity: no 3 consecutive tasks without automated verify`
- `[x] Wave 0 covers all MISSING references`
- `[x] No watch-mode flags`
- `[x] Feedback latency < 30s for task-level probes` (already checked)
- `[x] nyquist_compliant: true set in frontmatter` (already checked)
- `**Approval:** approved` (was "pending")

Phase 11 — all checkboxes already checked, only Approval needs advancing:
- `**Approval:** approved` (was "pending")

**Manual-Only Verifications in Phase 11:**

The Phase 11 VALIDATION file lists two manual checks that were subsequently automated
by Phase 11 Plan 03 (automated CI dry-run) and the shipped release workflow. The
Manual-Only Verifications section should be updated to reflect that these are now
automated, or note that they were satisfied by CI automation. [VERIFIED: 11-VERIFICATION.md
shows "Human Verification Required: None" and 11-03-SUMMARY.md confirms automation]

### Test Infrastructure Sections

Phase 10's test infrastructure block references a "plan-owned targeted ExUnit file
once it exists" hedge. Since those files now exist and are proven, the quick-run
command should be updated to reflect the actual commands used:
- `mix test test/install_smoke/release_docs_parity_test.exs` (already accurate — keep)
- `mix test test/install_smoke/package_metadata_test.exs` (add as alternative quick-run)

Phase 11's test infrastructure block is accurate as-is. `bash scripts/assert_version_match.sh`
is the quick-run and it exists. No changes needed to this section.

---

## What Evidence to Cite in Each Updated File

### Phase 10 Evidence Sources (all VERIFIED)

| Claim | Evidence File | Key Lines |
|-------|--------------|-----------|
| release_docs_parity_test.exs exists and passes | `10-VERIFICATION.md` — Behavioral Spot-Checks | `4 tests, 0 failures` |
| package_metadata_test.exs exists and passes | `10-VERIFICATION.md` — Behavioral Spot-Checks | `4 tests, 0 failures` |
| mix docs --warnings-as-errors passes | `10-VERIFICATION.md` — Behavioral Spot-Checks | `Docs generated successfully` |
| release_preflight.sh wired to release.yml | `10-VERIFICATION.md` — Required Artifacts | `.github/workflows/release.yml` row |
| lib/rindle/live_view.ex warning cleaned | `10-02-SUMMARY.md` | key-files modified |
| RELEASE-04 satisfied | `10-01-SUMMARY.md` | `requirements-completed: [RELEASE-04]` |
| RELEASE-05 satisfied | `10-02-SUMMARY.md` | `requirements-completed: [RELEASE-05]` |

### Phase 11 Evidence Sources (all VERIFIED)

| Claim | Evidence File | Key Lines |
|-------|--------------|-----------|
| assert_version_match.sh exists and passes | `11-VERIFICATION.md` — Behavioral Spot-Checks | `Version matches: 0.1.0-dev` |
| release.yml performs real Hex publish | `11-VERIFICATION.md` — Observable Truths #1 | `mix hex.publish --yes` |
| CI dry-run publish automated | `11-03-SUMMARY.md` + `11-VERIFICATION.md` Truth #4 | package-consumer job |
| RELEASE-06 satisfied | `11-VERIFICATION.md` — Requirements Coverage | satisfied row |
| RELEASE-07 satisfied | `11-VERIFICATION.md` — Requirements Coverage | satisfied row |

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Checking whether test files exist | Custom existence check script | `ls` in research (already done) |
| Rewriting validation boilerplate from scratch | Templated replacement | Edit only the stale fields in-place |

---

## Common Pitfalls

### Pitfall 1: Rewriting accurate sections unnecessarily

**What goes wrong:** The planner or executor rewrites entire sections that are already
correct, introducing inconsistencies or losing accurate wording.
**Why it happens:** It is tempting to "tidy up" a file when editing it.
**How to avoid:** Read the full current VALIDATION.md first. Edit only the specific
fields enumerated in the Architecture Patterns section above. Leave all other content
unchanged.
**Warning signs:** If you find yourself changing sampling rates, test infrastructure
framework, or threat refs, you have gone too far.

### Pitfall 2: Leaving the frontmatter `status` field stale

**What goes wrong:** The Per-Task map is updated but the frontmatter `status` and
`wave_0_complete` remain `draft`/`false`, so the milestone audit still reports partial.
**Why it happens:** Editors fix the body and forget the YAML frontmatter.
**How to avoid:** Update frontmatter fields first, then body fields.
**Warning signs:** If `wave_0_complete: false` is still present after editing, the
plan is not done.

### Pitfall 3: Inventing new evidence or re-running tests as part of this phase

**What goes wrong:** The executor re-runs preflight or mix test and records new
output instead of citing existing verification evidence.
**Why it happens:** It feels more thorough to re-verify.
**How to avoid:** The evidence is already in `10-VERIFICATION.md` and
`11-VERIFICATION.md`. Cite those files. Do not block Phase 14 on fresh CI runs.
**Warning signs:** If a task action reads `run mix hex.build --unpack`, that is out
of scope for this phase.

### Pitfall 4: Not closing the Manual-Only Verification for Phase 11

**What goes wrong:** The Phase 11 VALIDATION still lists two manual-only checks
as `[pending]`, but 11-VERIFICATION.md says "Human Verification Required: None."
**Why it happens:** The Manual-Only table is a separate section that is easy to miss.
**How to avoid:** Update the Manual-Only Verifications table in Phase 11 to note that
both checks were superseded by automated CI (Plan 03 and the Phase 11 verification
report).
**Warning signs:** HUMAN-UAT.md for Phase 11 still shows `status: partial` and
`pending: 2` — this is the HUMAN-UAT file, not the VALIDATION file, and it is
separate from what Phase 14 edits.

---

## Runtime State Inventory

Not applicable. This phase contains no renames, refactors, or data migrations. All
changes are confined to markdown/YAML files under `.planning/`.

---

## Environment Availability

Step 2.6: SKIPPED — this phase is planning-artifact-only with no external
dependencies beyond the file editor.

---

## Validation Architecture

`workflow.nyquist_validation` is absent from `.planning/config.json`, so validation
is enabled. However, Phase 14 itself produces no new tests. The per-plan validation
is structural: confirm the edited VALIDATION files are internally consistent (no
remaining `❌ W0`, no `⬜ pending`, `wave_0_complete: true`, `Approval: approved`)
before committing.

### Phase 14 Validation Approach

Phase 14 is meta-validation — it validates the validators. There are no automated
test commands to run for Phase 14's own deliverables. The exit gate is a logical
consistency check:

1. After each plan: read the edited VALIDATION.md and confirm all checkboxes,
   frontmatter fields, and status symbols match the evidence.
2. After both plans: re-read `v1.2-MILESTONE-AUDIT.md`'s Nyquist section and
   confirm the `partial_phases: [10, 11]` finding would now resolve if the audit
   were re-run.

### Wave 0 Gaps

None — Phase 14 creates no test files. The edited VALIDATION files are the
deliverable.

---

## Open Questions (RESOLVED)

1. **Should the Phase 11 HUMAN-UAT file (`11-HUMAN-UAT.md`) also be updated?**
   - What we know: It still shows `status: partial` and `pending: 2`. The CONTEXT.md
     and audit only call out VALIDATION.md files.
   - What's unclear: Whether the milestone audit reads HUMAN-UAT or only VALIDATION
     files when computing Nyquist compliance.
   - Recommendation: The audit's Nyquist section references VALIDATION files only.
     Update HUMAN-UAT only if the audit re-run still shows partial after VALIDATION
     files are fixed. Keep it as a follow-up rather than a blocker for Phase 14.
   - RESOLVED: `11-HUMAN-UAT.md` is excluded from Phase 14 scope. The milestone audit references only VALIDATION files for Nyquist compliance. HUMAN-UAT update is deferred as a follow-up if the post-fix audit re-run still shows partial.

2. **Should the milestone audit file be re-run as a Phase 14 deliverable?**
   - What we know: CONTEXT.md says "Re-run the milestone audit after Phase 13 and
     Phase 14 to confirm the tech_debt verdict is cleared."
   - What's unclear: Whether re-running the audit is inside the scope of Plan 14-01
     or 14-02, or is a verification gate after both.
   - Recommendation: Make re-running the audit the exit condition verified at
     `gsd-verify-work` time, not a mid-plan step. Neither plan should own the audit
     re-run; it belongs to the phase-level verification pass.
   - RESOLVED: The milestone audit re-run is the phase-level verification gate at `gsd-verify-work` time, not a mid-plan deliverable. Neither Plan 14-01 nor 14-02 owns the audit re-run.

---

## Sources

### Primary (HIGH confidence)

- `.planning/milestones/v1.2-phases/10-publish-readiness/10-VALIDATION.md` — current stale state inspected directly
- `.planning/milestones/v1.2-phases/10-publish-readiness/10-VERIFICATION.md` — full verification evidence for Phase 10
- `.planning/milestones/v1.2-phases/10-publish-readiness/10-01-SUMMARY.md` — RELEASE-04 completion evidence
- `.planning/milestones/v1.2-phases/10-publish-readiness/10-02-SUMMARY.md` — RELEASE-05 completion evidence
- `.planning/milestones/v1.2-phases/11-protected-publish-automation/11-VALIDATION.md` — current stale state inspected directly
- `.planning/milestones/v1.2-phases/11-protected-publish-automation/11-VERIFICATION.md` — full verification evidence for Phase 11
- `.planning/milestones/v1.2-phases/11-protected-publish-automation/11-01-SUMMARY.md` — RELEASE-06 completion evidence
- `.planning/milestones/v1.2-phases/11-protected-publish-automation/11-02-SUMMARY.md` — RELEASE-07 completion evidence
- `.planning/milestones/v1.2-phases/11-protected-publish-automation/11-03-SUMMARY.md` — CI automation completion evidence
- `.planning/v1.2-MILESTONE-AUDIT.md` — authoritative list of Nyquist debt items driving this phase
- `ls /Users/jon/projects/rindle/test/install_smoke/` — confirmed test file existence
- `ls /Users/jon/projects/rindle/scripts/` — confirmed script existence

### Secondary (MEDIUM confidence)

None required — all claims are directly verified against project files.

### Tertiary (LOW confidence)

None.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The milestone audit's Nyquist partial verdict is driven solely by the VALIDATION.md frontmatter fields and sign-off checkboxes, not by re-running tests at audit time | Architecture Patterns | If the audit re-runs tests, Phase 14 would need to also confirm all tests still pass before editing; low risk — audit file confirms it used existing VERIFICATION.md evidence |

---

## Metadata

**Confidence breakdown:**
- What fields to change: HIGH — read directly from the stale VALIDATION files and matched against VERIFICATION evidence
- What evidence to cite: HIGH — VERIFICATION.md files are authoritative, already accepted by the verifier
- Whether HUMAN-UAT needs updating: MEDIUM — audit Nyquist section only mentions VALIDATION files, but HUMAN-UAT for Phase 11 still shows `partial`

**Research date:** 2026-04-28
**Valid until:** Indefinite — project files do not change without commits; this research is a snapshot against the current repo state
