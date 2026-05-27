# Phase 73: Nyquist Validation Closure - Context

**Gathered:** 2026-05-27 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 73 closes the v1.15 **validation hygiene** gap (VAL-01): bring phases **68–70**
(v1.14 bulk owner-erasure) to Nyquist-compliant state without new public feature surface.

**In scope:**
- Restore v1.14 phase planning artifacts (at minimum VALIDATION.md, VERIFICATION.md,
  SUMMARY, PLAN) from git into `.planning/milestones/v1.14-phases/{68,69,70}-*/`.
- Reconcile each phase's `*-VALIDATION.md` against its `*-VERIFICATION.md`, SUMMARY
  artifacts, and green `mix test` verify commands.
- Set `nyquist_compliant: true`, complete sign-off, and append Validation Audit trail
  where `/gsd-validate-phase` workflow requires it.
- Update `v1.14-MILESTONE-AUDIT.md` Nyquist table and tick VAL-01 in REQUIREMENTS.md
  when all three phases are green.

**Out of scope (explicit):**
- Phase 67 (already `nyquist_compliant: true` before v1.15 archive).
- New production code or new test files unless gap analysis finds a true MISSING
  requirement (default: metadata reconciliation only).
- PROOF-06 / mix `batch_owner_failed` partial-failure E2E (Phase 72 — may only
  update phase 69 map if Phase 72 landed the test before this phase runs).
- TRUTH-04 ops.md / TusPlug moduledoc drift (Phase 74).
- Force-delete, admin UI, or batch API semantics changes.

</domain>

<decisions>
## Implementation Decisions

Research sources: assumptions-mode analysis, v1.14 milestone audit, git history
(`dbdfc5d` archive deletion), v1.3 Phase 14 validation-closure precedent,
`70-VERIFICATION.md` / green batch test suite.

### Artifact location and workflow

- **D-01:** Restore each phase tree under **`.planning/milestones/v1.14-phases/`**
  (`68-batch-erasure-implementation`, `69-operator-mix-task`,
  `70-proof-adopter-guidance`) — mirrors `v1.7-phases/` archive pattern; do not
  resurrect under active `.planning/phases/` (reserved for current milestone work).
- **D-02:** Source of truth for restore: git commits immediately before `dbdfc5d`
  (e.g. `ff62303` for 68, `a63a226` for 69, `903f0fa` for 70).
- **D-03:** Run **`/gsd-validate-phase N`** per phase with `phase_dir` pointing at
  the restored archive path, **or** equivalent manual reconciliation following the
  validate-phase workflow — planner may choose three sequential plans (68 → 69 → 70).

### Work type (metadata reconciliation default)

- **D-04:** **Primary work is VALIDATION.md reconciliation**, not new test authoring.
  Propagate verified truth from VERIFICATION.md + SUMMARY into per-task maps
  (`✅ green`, `File Exists: ✅`), complete sign-off checkboxes, set frontmatter
  `nyquist_compliant: true` and `status: complete` where appropriate.
- **D-05:** **Do not** spawn `gsd-nyquist-auditor` for new tests unless gap analysis
  classifies a requirement as MISSING after cross-referencing existing test files.
  Implementation is shipped; v1.14 audit "discovery only" meant metadata lag.
- **D-06:** Before closing each phase, run that phase's **quick verify command** from
  its VALIDATION.md Test Infrastructure table and confirm green (repo-truth gate).

### Plan structure

- **D-07:** **Three plans**, one per phase (68, 69, 70) — matches ROADMAP success
  criteria numbering and Phase 14 (v1.3) one-VALIDATION-file-per-plan pattern.
- **D-08:** Each plan: restore archive dir → read VERIFICATION + SUMMARY → edit
  VALIDATION only → run quick verify → append Validation Audit section if needed.

### Scope boundaries

- **D-09:** **Exclude Phase 67** from execution (already Nyquist-compliant).
- **D-10:** **Exclude** PROOF-06 / operator partial-failure E2E from Phase 73 scope;
  if Phase 72 completed first, phase 69 VALIDATION map may be updated to reflect
  the new test — that is a map refresh only, not new Phase 73 test work.
- **D-11:** **Reject** bundling TRUTH-04, force-delete, or batch API changes into
  this phase.

### Exit criteria and downstream updates

- **D-12:** Mark **VAL-01** `[x]` in `.planning/REQUIREMENTS.md` when all three
  phases have `nyquist_compliant: true` with approved sign-off.
- **D-13:** Update **`.planning/milestones/v1.14-MILESTONE-AUDIT.md`** Nyquist
  Compliance table (currently 1/4 compliant, phases 68–70 false).
- **D-14:** Optional note in `.planning/RETROSPECTIVE.md` v1.14 "inefficient" bullet
  when closure completes — **Claude's discretion**.

### Claude's Discretion

- Whether to use `/gsd-validate-phase` tooling vs hand-editing VALIDATION.md following
  the same checklist (outcome must match validate-phase success criteria).
- Exact Validation Audit table wording and date stamps.
- Whether to restore full phase dirs (PLAN, RESEARCH, etc.) vs minimum set
  (VALIDATION, VERIFICATION, SUMMARY) needed for audit trail.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` — Phase 73 goal and four success criteria
- `.planning/REQUIREMENTS.md` — VAL-01
- `.planning/PROJECT.md` — v1.15 maintenance charter
- `.planning/milestones/v1.14-ROADMAP.md` — Phases 68–70 goals and deferred Nyquist note
- `.planning/milestones/v1.14-MILESTONE-AUDIT.md` — Nyquist Compliance table (lines 128–137)

### Precedent (validation closure pattern)
- `.planning/milestones/v1.3-phases/14-validation-closure-for-publish-milestone/14-RESEARCH.md` — Phase 14 metadata-only closure model
- `.planning/phases/72-mix-batch-failure-proof/72-VALIDATION.md` — Recent Nyquist-compliant example (PROOF-06 phase)

### Git restore sources (pre-v1.15 deletion)
- `ff62303` — Phase 68 artifacts (`68-VALIDATION.md`, `68-VERIFICATION.md`)
- `a63a226` / `1023c64` — Phase 69 artifacts
- `903f0fa` — Phase 70 artifacts (`70-VALIDATION.md`, `70-VERIFICATION.md`)
- `dbdfc5d` — Commit that removed `.planning/phases/67–70` (archive boundary)

### Implementation truth (tests to cross-reference, not modify by default)
- `test/rindle/owner_erasure_batch_test.exs`
- `test/rindle/owner_erasure_batch_proof_test.exs`
- `test/rindle/owner_erasure_batch_boundary_test.exs`
- `test/rindle/owner_erasure_batch_error_test.exs`
- `test/rindle/owner_erasure_batch_contract_test.exs`
- `test/rindle/batch_owner_erasure_task_test.exs`
- `test/support/owner_erasure_batch_fixtures.ex`
- `test/support/counting_failing_txn_repo.ex`
- `test/install_smoke/docs_parity_test.exs`

### Workflow
- `$HOME/.cursor/get-shit-done/workflows/validate-phase.md` — Nyquist audit procedure
- `$HOME/.cursor/get-shit-done/templates/VALIDATION.md` — Frontmatter and section contract

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Full batch erasure test matrix already exists across `owner_erasure_batch_*` and
  `batch_owner_erasure_task_test.exs` — VALIDATION maps were never updated post-ship.
- `CountingFailingTxnRepo` and `OwnerErasureBatchFixtures` satisfy Phase 70 Wave 0
  items that VALIDATION still listed as pending at plan time.

### Established Patterns
- **Archive under `milestones/v{N}-phases/`** for shipped milestone phase artifacts
  (v1.7–v1.6 precedent); active `.planning/phases/` is v1.15-only.
- **Phase 14 model:** planning-artifact edits only; run existing verify commands
  before flipping `nyquist_compliant`.
- **Repo-Truth Evidence Ladder:** VERIFICATION.md + green tests override stale
  `⬜ pending` rows in VALIDATION.md.

### Integration Points
- Phase 73 output feeds Phase 74 milestone audit (AUDIT-01) with closed VAL-01.
- No `lib/` or `test/` changes expected unless gap analysis finds MISSING coverage.

</code_context>

<specifics>
## Specific Ideas

- User confirmed all assumptions without correction — proceed with archive restore +
  metadata reconciliation default; escalate to gap-fill only on true MISSING findings.
- v1.14 milestone closed with "discovery only" Nyquist — this phase retroactively
  brings planning truth in line with shipped code (same intent as v1.3 Phase 14).

</specifics>

<deferred>
## Deferred Ideas

None — analysis stayed within phase scope.

</deferred>

---

*Phase: 73-nyquist-validation-closure*
*Context gathered: 2026-05-27*
