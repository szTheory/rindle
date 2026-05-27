# Phase 73: Nyquist Validation Closure - Research

**Researched:** 2026-05-27
**Domain:** Planning artifact hygiene — restore v1.14 phase trees and reconcile VALIDATION.md for phases 68–70
**Confidence:** HIGH

---

## Summary

Phase 73 closes VAL-01 by bringing archived v1.14 erasure phases (68–70) to Nyquist-compliant
planning truth. No new public API surface and no new tests by default — implementation and
ExUnit coverage already exist; VALIDATION.md files still show `nyquist_compliant: false`,
`⬜ pending` rows, and `❌ W0` markers from plan-time state.

Commit `dbdfc5d` deleted `.planning/phases/67–70` during v1.15 archive hygiene. Phase 67
remains compliant elsewhere; phases 68–70 need restoration under
`.planning/milestones/v1.14-phases/` (mirrors `v1.3-phases/`, `v1.7-phases/` pattern).

**Primary recommendation:** Three sequential execute plans (68 → 69 → 70), each: restore
archive dir from `dbdfc5d^` → cross-read VERIFICATION + SUMMARY → edit VALIDATION only →
run quick verify from Test Infrastructure table → flip sign-off. Fourth plan updates
VAL-01 and `v1.14-MILESTONE-AUDIT.md` Nyquist table.

**Precedent:** Phase 14 (v1.3) — metadata-only closure; grep-verifiable acceptance criteria.

---

## Git Restore Sources

| Phase | Archive path | Parent commit (pre-delete) | Key artifacts |
|-------|--------------|----------------------------|---------------|
| 68 | `.planning/milestones/v1.14-phases/68-batch-erasure-implementation/` | `dbdfc5d^` (tree at `ff62303`) | `68-VALIDATION.md`, `68-VERIFICATION.md`, SUMMARYs |
| 69 | `.planning/milestones/v1.14-phases/69-operator-mix-task/` | `dbdfc5d^` | `69-VALIDATION.md`, `69-VERIFICATION.md` |
| 70 | `.planning/milestones/v1.14-phases/70-proof-adopter-guidance/` | `dbdfc5d^` | `70-VALIDATION.md`, `70-VERIFICATION.md` |

**Restore command pattern (per phase):**

```bash
git checkout dbdfc5d^ -- .planning/phases/{NN}-{slug}
mkdir -p .planning/milestones/v1.14-phases
mv .planning/phases/{NN}-{slug} .planning/milestones/v1.14-phases/
```

Do not leave restored dirs under active `.planning/phases/` (v1.15 work only).

---

## Stale VALIDATION State (at deletion)

### Phase 68

- Frontmatter: `status: draft`, `nyquist_compliant: false`, `wave_0_complete: true`
- Per-task: rows 68-01-02, 68-02-02 show `❌ W0` / `⬜ pending` for `owner_erasure_batch_test.exs`
- Wave 0: `owner_erasure_batch_test.exs` unchecked — **file exists and tests pass**
- Quick verify: `mix test test/rindle/owner_erasure_batch_test.exs test/rindle/owner_erasure_batch_boundary_test.exs test/rindle/owner_erasure_batch_error_test.exs`

### Phase 69

- Per-task: all four rows `❌ W0` / `⬜ pending` for `batch_owner_erasure_task_test.exs`
- Wave 0: task test + mix task unchecked — **both exist**
- Quick verify: `mix test test/rindle/batch_owner_erasure_task_test.exs test/rindle/api_surface_boundary_test.exs`
- **Phase 72 note:** `batch_owner_erasure_task_test.exs` now includes `batch_owner_failed` partial-failure test — map refresh only if row missing (not new test work)

### Phase 70

- Per-task: 70-01-02, 70-01-03 show `❌ W0` for proof test; Wave 0 lists fixtures/proof as unchecked
- **Files exist:** `test/support/owner_erasure_batch_fixtures.ex`, `test/support/counting_failing_txn_repo.ex`, `test/rindle/owner_erasure_batch_proof_test.exs`
- Quick verify: `mix test test/rindle/owner_erasure_batch_proof_test.exs`

---

## Target End State (per phase VALIDATION.md)

Mirror `72-VALIDATION.md` and Phase 14 closure:

| Field | Target |
|-------|--------|
| `status` | `complete` |
| `nyquist_compliant` | `true` |
| `wave_0_complete` | `true` (already true for 68–70) |
| Per-Task `File Exists` | `✅` (no `❌ W0`) |
| Per-Task `Status` | `✅ green` (no `⬜ pending`) |
| Wave 0 checklist | all `[x]` |
| Sign-Off | all `[x]` |
| `**Approval:**` | `approved 2026-05-27` (or bare `approved`) |

Optional: append **Validation Audit** section per `validate-phase.md` workflow.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Rationale |
|------------|-------------|-----------|
| Restore phase archive dirs | Git + filesystem | No code changes |
| Reconcile VALIDATION.md | Planning artifacts | Markdown/frontmatter edits |
| Repo-truth gate | ExUnit (`mix test`) | Confirm evidence before sign-off |
| VAL-01 / audit table | Planning artifacts | REQUIREMENTS + MILESTONE-AUDIT |

---

## Validation Architecture

`workflow.nyquist_validation` is enabled. Phase 73 produces no new production tests.

### Phase 73 Validation Approach

Meta-validation — same as Phase 14:

1. **Per sub-phase plan (68/69/70):** Run that phase's quick verify command from restored
   `*-VALIDATION.md` Test Infrastructure table; must exit 0 before flipping sign-off.
2. **Per VALIDATION edit:** Grep gates — zero `❌ W0`, zero `⬜ pending` in map (excluding
   legend), `nyquist_compliant: true`, `**Approval:** approved`.
3. **Phase exit (plan 04):** All three archive VALIDATION files compliant; VAL-01 `[x]` in
   REQUIREMENTS.md; v1.14 audit Nyquist table shows 4/4 compliant for phases 67–70.

### Wave 0 Gaps

None for Phase 73 itself — deliverables are restored archives and edited VALIDATION files.

Gap-fill (new tests) only if cross-reference finds a requirement with no test file — default
reject per CONTEXT D-05.

---

## Open Questions (RESOLVED)

1. **Restore full phase tree or minimum files?**
   - RESOLVED: Restore full tree from `dbdfc5d^` for audit trail (CONTEXT D-01, discretion favors full).

2. **Use `/gsd-validate-phase` vs manual edit?**
   - RESOLVED: Outcome-equivalent; plans use manual grep-verifiable edits following Phase 14 pattern (faster, no nested agent).

3. **Phase 69 partial-failure row after Phase 72?**
   - RESOLVED: If `batch_owner_failed` test exists, ensure map row is `✅ green` — refresh only (D-10).

---

## RESEARCH COMPLETE
