# Phase 47: audit-traceability-metadata-backfill - Context

**Gathered:** 2026-05-25
**Status:** Ready for execution

<domain>
## Phase Boundary

Close the final v1.8 audit drift by backfilling canonical
`requirements-completed` frontmatter into already-shipped summary artifacts and
then rerunning the v1.8 milestone audit from current truth.

This phase does **not** reopen runtime implementation, tests, or product scope
for tus or Mux direct upload. The shipped behavior is already verified. The only
remaining gap is three-source traceability consistency across
`REQUIREMENTS.md`, summary frontmatter, and the milestone audit.
</domain>

<decisions>
## Implementation Decisions

### Summary ownership
- **D-01:** Use single-owner summary metadata. A requirement should be declared
  in exactly one summary frontmatter entry, not duplicated across every touched
  plan in the phase.
- **D-02:** `TUS-07` belongs on `43-02-SUMMARY.md` only because that is the
  plan that actually shipped the S3 `:tus_upload` capability advertisement the
  requirement describes.

### Phase 45 mapping
- **D-03:** Use strict per-plan ownership for Phase 45:
  - `45-01-SUMMARY.md` -> `MUX-20`
  - `45-02-SUMMARY.md` -> `MUX-21`, `MUX-22`
  - `45-03-SUMMARY.md` -> `MUX-23`
- **D-04:** Do not collapse `MUX-20..23` into one synthetic summary or copy the
  full set onto every Phase 45 summary. The traceability should mirror the plan
  boundaries already verified in `45-VERIFICATION.md`.

### Closure posture
- **D-05:** Phase 47 includes the re-audit in the same phase. It is not merely
  a metadata edit pass; it ends only once the refreshed v1.8 milestone audit no
  longer marks `TUS-07` or `MUX-20..23` partial due to summary drift.
- **D-06:** Phase 46 is the authoritative closure for `TUS-14`. Phase 47 should
  consume that result and update audit/state artifacts accordingly, not reopen
  the generated-app proof path.
</decisions>

<canonical_refs>
## Canonical References

- `.planning/ROADMAP.md` — Phase 47 goal and success criteria
- `.planning/REQUIREMENTS.md` — current requirement checkboxes and traceability
- `.planning/STATE.md` — current operational truth, currently stale on the
  milestone blocker story
- `.planning/v1.8-MILESTONE-AUDIT.md` — stale partial/unsatisfied matrix to be
  refreshed
- `.planning/phases/43-s3-multipart-backing-minio-proof/43-VERIFICATION.md`
- `.planning/phases/45-browser-mux-direct-creator-upload-sibling-droppable/45-VERIFICATION.md`
- `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md`
</canonical_refs>

<specifics>
## Specific Ideas

- Prefer the smallest safe edit surface: frontmatter and planning artifacts
  only.
- Keep the re-audit explicit and machine-greppable so future closure phases do
  not need to infer why these requirements moved from partial to satisfied.
- Normalize Phase 45 summaries to the canonical frontmatter shape already used
  elsewhere in the repo.
</specifics>

<deferred>
## Deferred Ideas

- Any new code or test execution for tus or Mux direct upload
- Reopening Phase 42 Nyquist compliance drift in this phase
- Milestone archival mechanics beyond the refreshed audit/state/traceability
</deferred>

---

*Phase: 47-audit-traceability-metadata-backfill*
*Context gathered: 2026-05-25*
