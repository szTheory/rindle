# Phase 20: v1.3 Verification & Metadata Closure - Context

**Gathered:** 2026-05-01 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

All v1.3 phases (15-19) have the verification artifacts and SUMMARY/REQUIREMENTS metadata required for `/gsd-audit-milestone v1.3` to report `passed`. Specifically: write the missing `15-VERIFICATION.md` and `16-VERIFICATION.md`, correct Phase 16 SUMMARY `requirements_completed` frontmatter to declare VERIFY-01, VERIFY-02, and RELEASE-02, commit the residual Phase 17 LiveView corrective patch sitting in the working tree, teach Phase 19 helpers (`attachment_for/2,3`, `ready_variants_for/1`, the five bangs) in the canonical onboarding prose (README.md + guides/getting_started.md), and clean up REQUIREMENTS.md (traceability table flips, bold-span line-break fixes, coverage note refresh).

**Out of scope:** the hexdocs.pm reachability probe (VERIFY-02 observability gap, G4) — that is Phase 21's exclusive scope.
</domain>

<decisions>
## Implementation Decisions

### Verification Artifact Retrofitting (G1, G2)

- **D-01:** Author `15-VERIFICATION.md` and `16-VERIFICATION.md` directly. Do NOT invoke `/gsd-verify-work`. Phase 15/16 implementations are already integration-checker-validated per `.planning/v1.3-MILESTONE-AUDIT.md:147-167`; a verifier subagent would re-derive identical evidence. The audit explicitly classifies this as a "metadata gap, not implementation gap" at `v1.3-MILESTONE-AUDIT.md:143`.
- **D-02:** Mirror the canonical frontmatter and section structure from `17-VERIFICATION.md` (frontmatter: `phase / verified / status / score / overrides_applied`; sections: Goal Achievement → Observable Truths → Required Artifacts → Key Link Verification → Data-Flow Trace → Behavioral Spot-Checks → Requirements Coverage → Anti-Patterns → Gaps Summary). Where ROADMAP success criteria are explicit, follow the richer Success-Criteria-driven variant from `18-VERIFICATION.md:1-16`.
- **D-03:** In `16-VERIFICATION.md`, mark VERIFY-02 as `SATISFIED (functional)` with a `forward_reference: phase-21` evidence note. Functional contract is met (`mix hex.publish --yes` uploads docs, `mix docs --warnings-as-errors` gate, `guides/release_publish.md:108,144` repair path); the rendered-HTML reachability probe is by-design routed to Phase 21 per `.planning/REQUIREMENTS.md:89` and `ROADMAP.md` Phase 21 scope. Do not mark this `partial` — it would re-flag G4.
- **D-04:** `15-VERIFICATION.md` cites: `release_docs_parity_test.exs`, `package_metadata_test.exs`, `release_preflight.sh`. `16-VERIFICATION.md` cites: `release.yml:332-348` (idempotency probe + skip-gates), `release.yml:447-467` (index wait + public smoke), `hex_release_exists_test.exs` (7/7 pass), `16-REVERT-REHEARSAL.md`, `release_docs_parity_test.exs:252` (revert parity assertion).

### SUMMARY Frontmatter Splits (G3)

- **D-05:** `16-01-SUMMARY.md` `requirements_completed` becomes `[PUBLISH-03, RELEASE-01, VERIFY-01]`. Rationale: 16-01 shipped the idempotency probe + ExUnit harness (`16-01-SUMMARY.md:18-21`) — the probe is what makes `mix deps.get` resolve cleanly post-publish, satisfying VERIFY-01.
- **D-06:** `16-02-SUMMARY.md` `requirements_completed` becomes `[PUBLISH-03, RELEASE-01, VERIFY-02, RELEASE-02]`. Rationale: 16-02 shipped the workflow wiring (public-smoke + index-wait satisfies VERIFY-02 transitively) + the parity test at `release_docs_parity_test.exs:252` (RELEASE-02) + landed `16-REVERT-REHEARSAL.md`.
- **D-07:** Strike the stale "remain uncommitted" claim at `16-01-SUMMARY.md:31` — all four artifacts are now tracked in git per audit L228.

### REQUIREMENTS.md Cleanup (TD-Req)

- **D-08:** In `.planning/REQUIREMENTS.md`:
  - Flip API-06/07/08 traceability rows (L97-99) and the 7 v1.3 process-pending rows (L85-91 — PUBLISH-01/02/03, VERIFY-01, RELEASE-01, RELEASE-02; VERIFY-02 stays routed to Phase 21) to `Complete`.
  - Flip Active-section checkboxes (L10-12 PUBLISH, L16-17 VERIFY, L21-22 RELEASE, L40-42 API-06/07/08) to `[x]`.
  - Fix bold-span literal newlines at L26, L28, L35, L46, L48, L50 (e.g. `**API-01\n**:` → `**API-01**:`).
  - Update the "Pending closure: 7" coverage note at L108 — after Phase 20, only VERIFY-02 remains routed to Phase 21.
- **D-09:** Note: VERIFY-02 row stays as `Pending` in the table because Phase 21 has not yet shipped — only its closure routing is unchanged.

### Phase 17 LiveView Corrective Patch (TD-17)

- **D-10:** Commit the existing working-tree diff on `lib/rindle/live_view.ex` (+13 lines: alias + refactor of `handle_initiate_upload/3` to use `Broker.sign_url/1` instead of bypassing through `adapter.presigned_put/3`, replacing fabricated `Ecto.UUID.generate()` `asset_id` with broker-owned `signed_session.asset_id`) and `test/rindle/live_view_test.exs` (+98 lines: real broker-backed tests + `consume_uploaded_entries/3` round-trip with Mox).
- **D-11:** Single commit. Attribute to **Phase 20** (not amended into Phase 17). Commit message must reference "closes Phase 17 anti-patterns logged in `17-VERIFICATION.md:85-89` (sign_url bypass at L85, fabricated asset_id at L93)". Rationale: keeping `17-VERIFICATION.md` honest — it currently catalogs these as Warning anti-patterns with "Residual risk for follow-up". Phase 20's stated ROADMAP goal includes "residual Phase 17 LiveView corrections are committed".
- **D-12:** Do NOT modify either source file beyond the working-tree diff. Verify `MIX_ENV=test mix test test/rindle/live_view_test.exs` reports 8/8 pass before committing. If a regression appears, treat as a deviation and stop.

### Onboarding Prose Insertion (TD-19)

- **D-13:** README.md: insert a new `## After First Run: Querying Attachments and Variants` section between the existing first-run section (L86-117) and the "Next Reads" section (L124). Show `Rindle.attachment_for/2,3` and `Rindle.ready_variants_for/1` with copy-pasteable Phoenix-controller-shaped examples. Add a `### Bang Variants` subsection covering `attach!/4`, `detach!/3`, `upload!/3`, `url!/3`, `variant_url!/4` with the "raises Rindle.Error" contract surfaced in one line.
- **D-14:** `guides/getting_started.md`: append section `## 8. Querying Attachments and Variants` after section 7 (L197-212), then `## 9. Bang Variants` before "Next Reads" (~L214). Match the section-number style already in the file.
- **D-15:** Update `test/install_smoke/docs_parity_test.exs` if it asserts symbol presence in onboarding docs (Phase 17/18 pattern); add assertions for the eight new symbols so `docs_parity_test.exs` gates regression.

### Plan Decomposition

- **D-16:** Three plans, dependency order **20-01 → 20-02 → 20-03**:
  - **20-01 (verification + metadata retrofit):** docs-only commit covering D-01 through D-09 (writes 15-VERIFICATION.md, 16-VERIFICATION.md, edits both 16 SUMMARY frontmatters, edits REQUIREMENTS.md). Unblocks the audit re-run.
  - **20-02 (LiveView corrective patch commit):** D-10 through D-12. Single source/test commit attributed to Phase 20.
  - **D-17:** **20-03 (onboarding prose insertion):** D-13 through D-15. README + getting_started + docs_parity_test additions.
- **D-18:** Plans 20-02 and 20-03 are independent of each other and could run in parallel waves; 20-01 must precede the milestone audit re-run but does not technically block 20-02/03. Default to sequential for clarity.

### Claude's Discretion

- Exact line ranges in README.md and guides/getting_started.md for prose insertion may shift slightly to respect surrounding section anchors (e.g., if `## 8.` already exists in getting_started.md, renumber).
- Bang-variant prose tone: brief, copy-pasteable, surface the `Rindle.Error` raise contract from `17-CONTEXT.md` D-01 boundary allowlist.
- Verification artifact requirements_coverage tables: full 3-source matrix (`status / claimed_by_plans / completed_by_plans / verification_status / evidence`) per the `v1.3-MILESTONE-AUDIT.md:24-72` shape.

### Folded Todos

None. `gsd-sdk query todo.match-phase 20` returned 0 matches.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` (Phase 20 description, success criteria, gap closure mapping)
- `.planning/REQUIREMENTS.md` (traceability table, Active checkboxes, coverage note)
- `.planning/v1.3-MILESTONE-AUDIT.md` (G1-G4 gap definitions, tech-debt catalog, 3-source matrix template)
- `.planning/phases/17-api-surface-boundary-audit/17-VERIFICATION.md` (canonical short-form VERIFICATION format; anti-patterns at L85-89)
- `.planning/phases/18-documentation-and-typespec-coverage/18-VERIFICATION.md` (canonical Success-Criteria-driven VERIFICATION format)
- `.planning/phases/19-convenience-api-additions/19-VERIFICATION.md` (canonical short-form VERIFICATION format)
- `.planning/phases/15-ci-integrity-and-publish-preflight/15-01-SUMMARY.md` (PUBLISH-02 claim mapping)
- `.planning/phases/15-ci-integrity-and-publish-preflight/15-02-SUMMARY.md` (PUBLISH-01, PUBLISH-02 claim mapping)
- `.planning/phases/16-live-publish-execution-and-post-publish-verification/16-01-SUMMARY.md` (target frontmatter edit)
- `.planning/phases/16-live-publish-execution-and-post-publish-verification/16-02-SUMMARY.md` (target frontmatter edit)
- `.planning/phases/16-live-publish-execution-and-post-publish-verification/16-REVERT-REHEARSAL.md` (RELEASE-02 evidence)
- `.github/workflows/release.yml` (idempotency probe L332-348; index wait + public smoke L447-467)
- `test/install_smoke/release_docs_parity_test.exs` (PUBLISH-01 + RELEASE-02 parity assertions)
- `test/install_smoke/package_metadata_test.exs` (PUBLISH-02 evidence)
- `test/install_smoke/hex_release_exists_test.exs` (PUBLISH-03 idempotency proof)
- `test/install_smoke/docs_parity_test.exs` (Phase 17/18 onboarding-doc gating pattern; extend in 20-03)
- `scripts/release_preflight.sh` (PUBLISH-02 evidence)
- `lib/rindle/live_view.ex` + `test/rindle/live_view_test.exs` (working-tree corrective patch — commit as-is in 20-02)
- `README.md` L86-124 (first-run + next-reads anchors for prose insertion)
- `guides/getting_started.md` L135-214 (section 7 + Next Reads anchors for prose insertion)
- `guides/release_publish.md` L108,144 (VERIFY-02 docs repair path evidence)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **VERIFICATION.md format precedent:** Phases 17, 18, 19 already passed verification with consistent frontmatter (`phase / verified / status / score`) and section progression (Goal Achievement → Observable Truths → Required Artifacts → Key Link Verification → Data-Flow Trace → Behavioral Spot-Checks → Requirements Coverage → Anti-Patterns → Gaps Summary). Phase 18 demonstrates the variant used when ROADMAP success criteria are explicit (Success Criteria → Detail Per Criterion). Phase 20 should reuse Phase 18's variant since Phase 20's ROADMAP block declares 6 explicit success criteria.
- **3-source requirements matrix:** the `v1.3-MILESTONE-AUDIT.md` matrix at L24-72 (`status / claimed_by_plans / completed_by_plans / verification_status / evidence`) is the canonical retrospective-cross-reference shape; replicate it in 15-VERIFICATION.md and 16-VERIFICATION.md.
- **Working-tree LiveView patch:** `lib/rindle/live_view.ex` (+13 lines) and `test/rindle/live_view_test.exs` (+98 lines) constitute a coherent corrective patch with 8/8 tests passing. No additional source changes required for D-10.
- **`docs_parity_test.exs` gating:** Phase 17/18 use this file to assert symbol presence in onboarding docs. Extend in 20-03 to gate Phase 19 helper visibility.

### Established Patterns

- **Single-commit-per-plan, atomic-commit discipline:** every prior v1.3 plan ships one git commit per plan. 20-01/02/03 follow.
- **Single docs commit for metadata-only plans:** Phase 17/18 demonstrate that requirements/traceability/SUMMARY edits ship as one `docs(<phase>): ...` commit.
- **Phase attribution for residual fixes:** Phase 17's `17-VERIFICATION.md` records the LiveView anti-patterns with "Residual risk for follow-up" — Phase 20 owns the fix without amending Phase 17 history.
- **`Rindle.Error` boundary allowlist:** Phase 17 D-01 + `test/rindle/api_surface_boundary_test.exs` gate the bang-raise contract. 20-03 prose must reflect `raises Rindle.Error` for the five bangs.

### Integration Points

- **`/gsd-audit-milestone v1.3` re-run** must report `passed` after 20-01 ships (and TD-17/19 closed in 20-02/03). The audit cross-references VERIFICATION.md + SUMMARY.md frontmatter + REQUIREMENTS.md table — all three must agree.
- **`docs_parity_test.exs`** gates symbol presence in README + getting_started.md after 20-03.
- **`api_surface_boundary_test.exs`** must continue to pass after 20-02 (LiveView patch should not affect facade boundary).
- **`MIX_ENV=test mix doctor --full --raise`** must continue exit 0 (Phase 18 doctor gate at 100/100/100/95/95 holds — 20-02/03 may add to onboarding docs but must not break this).
</code_context>

<specifics>
## Specific Ideas

- VERIFY-01 → 16-01-SUMMARY.md (idempotency probe path); VERIFY-02 + RELEASE-02 → 16-02-SUMMARY.md (workflow + revert rehearsal). Judgment call confirmed by user.
- VERIFY-02 in 16-VERIFICATION.md: status = `SATISFIED (functional)` + `forward_reference: phase-21` (NOT `partial`).
- LiveView patch attribution: Phase 20 (not amended into Phase 17 history).
- Onboarding prose location: a new top-level section in README.md (between first-run and next-reads) and two new sections in guides/getting_started.md (after section 7, before next-reads), NOT a separate guide.
</specifics>

<deferred>
## Deferred Ideas

- **G4 — hexdocs.pm reachability HTTP probe:** routed to Phase 21 per ROADMAP; explicitly NOT closed in Phase 20 (only forward-referenced in 16-VERIFICATION.md).
- **Future REQUIREMENTS.md schema cleanup:** the bold-span newline issue affects 6 rows; if the underlying generator produces this on every requirement add, a future tooling fix could be a separate seed/backlog item. Not in Phase 20 scope (which only fixes the existing rows).
- **Squash 20-01/02/03 into one phase:** rejected — entangling metadata + code + prose in one commit boundary breaks `/gsd-audit-milestone` isolation.

### Reviewed Todos (not folded)

None — phase had 0 todo matches.
</deferred>
