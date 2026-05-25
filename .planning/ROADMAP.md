# Roadmap: Rindle

## Milestones

- 🚧 **v1.9 Phoenix Tus DX Completion** — Phases 48-52 (started 2026-05-25)
- ✅ **v1.8 Resumable Browser Ingest** — Phases 42–47 (shipped 2026-05-25, see archive)
- ✅ **v1.7 GCS Resumable Adapter** — Phases 37–41 (shipped 2026-05-08, see archive)
- ✅ **v1.6 Provider Boundary + Mux** — Phases 33–36 (shipped 2026-05-07, see archive)
- ✅ **v1.5 Adopter Hardening & Lifecycle Repair** — Phases 29–32 (shipped 2026-05-06, see archive)
- ✅ **v1.4 Video & Audio Wedge** — Phases 23–28 (shipped 2026-05-05, see archive)
- ✅ **v1.3 Live Publish & API Ergonomics** — Phases 15–22 (shipped 2026-05-02, see archive)
- ✅ **v1.2 First Hex Publish** — Phases 10–14 (shipped 2026-04-29, see archive)
- ✅ **v1.1 Adopter Hardening** — Phases 6–9 (shipped 2026-04-28, see archive)
- ✅ **v1.0 MVP** — Phases 1–5 (shipped 2026-04-xx, see archive)

## Current Status

Milestone `v1.9 Phoenix Tus DX Completion` is now active. The wedge is narrow
on purpose: Rindle already ships the bare tus edge, `Rindle.initiate_tus_upload/2`,
the thin `Rindle.LiveView.allow_tus_upload/4` seam, and the headless tus proof.
This milestone finishes the Phoenix adopter story by aligning truth,
productizing the supported helper path, and proving it end to end.

## Milestone Goal

Turn the shipped tus edge into an honest first-class Phoenix adopter story:
reconcile planning/docs truth, lock the supported LiveView/server/client
contract, and add proof that the documented Phoenix-facing path works as
shipped.

## Phase Plan

**5 phases** | **7 requirements mapped** | All covered

| # | Phase | Goal | Requirements | Success Criteria |
|---|-------|------|--------------|------------------|
| 48 | Phoenix DX Contract + Truth Audit | Freeze the exact Phoenix tus support claim and remove stale "fully deferred" language from active planning surfaces. | `PHX-01`, `TRUTH-01` | 4 |
| 49 | LiveView Tus Productization | 2/2 | Complete   | 2026-05-25 |
| 50 | Phoenix Proof + Parity Closure | 2/2 | Complete | 2026-05-25 |
| 51 | Verification Artifact Closure | 2/2 | Complete    | 2026-05-25 |
| 52 | Traceability And Validation Reconciliation | Bring traceability and Nyquist metadata back in sync with the shipped v1.9 evidence before re-audit. | None | 3 |

## Phase Details

### Phase 48: Phoenix DX Contract + Truth Audit
Goal: freeze the exact Phoenix tus support claim and remove stale planning
language that treats the current seam as wholly deferred.

Success criteria:
1. Active planning docs distinguish the shipped bare tus edge, the shipped thin
   LiveView helper seam, and the still-deferred richer future abstractions.
2. One canonical Phoenix-facing story is named explicitly instead of forcing
   adopters to infer support boundaries from code history.
3. Deferred lists name only the still-deferred richer reusable uploader
   component abstractions, standalone tus JS package work, and broader future
   Phoenix upload abstractions.
4. The milestone leaves a clear contract for what Phase 49 must productize.

**Plans:** 2 plans (planned 2026-05-25 by `/gsd-plan-phase 48`). Wave 1:
`48-01`; Wave 2: `48-02`.

Plans:
- [x] 48-01-PLAN.md — align active planning truth surfaces and keep the Phoenix story canonical in `guides/resumable_uploads.md` with thin `Rindle.LiveView` docs
- [x] 48-02-PLAN.md — add targeted v1.8 archive disclaimers and parity tests for active truth, guide-pointer ownership, and archive-banner presence

### Phase 49: LiveView Tus Productization
Goal: turn the existing helper seam into a copy-pasteable Phoenix-facing
integration contract with an honest uploader and UI-state model.

Success criteria:
1. `allow_tus_upload/4` setup is documented as the supported server-side entry
   point with required and optional options called out precisely.
2. The supported `uploader: "RindleTus"` client flow is explicit about signed
   URL reuse, resume discovery, and offset-safe tus behavior.
3. The recommended UI state model distinguishes byte-upload progress from
   server verification and readiness instead of conflating `100%` with done.
4. The path still converges through the existing `consume_uploaded_entries/3`
   and `verify_completion/2` boundary with no silent alternate lifecycle.

**Plans:** 2/2 plans complete
`49-01`; Wave 2: `49-02`.

Plans:
- [x] 49-01-PLAN.md — freeze the `allow_tus_upload/4` server-side contract in the canonical guide, keep `Rindle.LiveView` docs thin, and lock helper metadata plus optional actor behavior with unit tests
- [x] 49-02-PLAN.md — freeze the canonical `RindleTus` client snippet and honest `uploading`/`verifying`/`ready`/`error` vocabulary with explicit parity assertions

### Phase 50: Phoenix Proof + Parity Closure
Goal: prove the documented Phoenix path end to end and freeze it against future
drift.

Success criteria:
1. Package-consumer or generated-app proof exercises the documented Phoenix /
   LiveView tus path, not only a headless tus client against the mounted plug.
2. Docs parity checks fail when the guide, helper metadata, or proof harness
   drift out of sync.
3. Proof artifacts show the same honest state boundaries claimed in the guide.
4. Closing evidence makes the Phoenix tus support claim auditable without
   reading source history.

**Plans:** 2/2 plans complete
`50-01`; Wave 2: `50-02`.

Plans:
- [x] 50-01-PLAN.md — elevate the existing generated-app `:tus` lane into the canonical Phoenix / LiveView proof with machine-readable report fields and preserved drop-and-resume evidence
- [x] 50-02-PLAN.md — add fast parity and local helper tests that freeze guide/helper/proof-field alignment, then rerun the full built-artifact tus lane

### Phase 51: Verification Artifact Closure
Goal: rebuild the missing verification chain for already-shipped Phases 48-50 so
the v1.9 audit can trace each scoped requirement through the normal closure
artifacts.

Success criteria:
1. `48-VERIFICATION.md` exists and ties `PHX-01` and `TRUTH-01` to the shipped
   Phase 48 evidence.
2. `49-VERIFICATION.md` exists and ties `PHX-02`, `PHX-03`, and `PHX-04` to the
   shipped Phase 49 evidence.
3. `50-VERIFICATION.md` exists and ties `PROOF-01` and `PROOF-02` to the
   shipped Phase 50 proof and parity evidence.
4. Verification artifacts are explicit enough that a rerun milestone audit no
   longer marks the v1.9 requirement set as orphaned.

### Phase 52: Traceability And Validation Reconciliation
Goal: reconcile planning metadata that still disagrees with the shipped v1.9
evidence so the milestone can close cleanly after verification artifacts land.

Success criteria:
1. `.planning/REQUIREMENTS.md` traceability matches the gap-closure phase
   ownership and resets shipped-but-orphaned requirements back to pending until
   closure is reverified.
2. `49-VALIDATION.md` reflects the actual completed phase state instead of the
   stale draft/partial metadata noted by the audit.
3. Roadmap and planning metadata tell one consistent closeout story before the
   next milestone re-audit.

## Phase Completion

- [x] **Phase 48: Phoenix DX Contract + Truth Audit** - Truth-align active planning/docs and freeze the exact support claim. (completed 2026-05-25)
- [x] **Phase 49: LiveView Tus Productization** - Productize the supported helper path with copy-pasteable client/server guidance and honest UI semantics. (completed 2026-05-25)
- [x] **Phase 50: Phoenix Proof + Parity Closure** - Add package-consumer proof and parity gates for the documented Phoenix path. (completed 2026-05-25)
- [x] **Phase 51: Verification Artifact Closure** - Generate the missing phase verification artifacts for shipped v1.9 work. (completed 2026-05-25)
- [ ] **Phase 52: Traceability And Validation Reconciliation** - Reconcile requirements and Nyquist metadata before re-audit.

## Deferred to v1.10+ / Later

- tus Checksum / Concatenation
- `Upload-Defer-Length`
- IETF RUFH / tus 2.0
- GCS-as-tus-backend / R2-native tus proxying
- Rindle-owned standalone tus JS client package
- Richer reusable uploader component abstractions beyond the supported helper path
- First-class account erasure / `purge_owner`-style lifecycle API
- Second streaming provider (Cloudflare/Bunny)
- `cancel_direct_upload/1` (Mux)

## Archive

- [.planning/milestones/v1.8-ROADMAP.md](milestones/v1.8-ROADMAP.md)
- [.planning/milestones/v1.8-REQUIREMENTS.md](milestones/v1.8-REQUIREMENTS.md)
- [.planning/milestones/v1.8-MILESTONE-AUDIT.md](milestones/v1.8-MILESTONE-AUDIT.md)
- [.planning/milestones/v1.7-ROADMAP.md](milestones/v1.7-ROADMAP.md)
- [.planning/milestones/v1.7-REQUIREMENTS.md](milestones/v1.7-REQUIREMENTS.md)
- [.planning/milestones/v1.7-MILESTONE-AUDIT.md](milestones/v1.7-MILESTONE-AUDIT.md)
