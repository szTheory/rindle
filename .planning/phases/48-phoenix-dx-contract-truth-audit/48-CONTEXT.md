# Phase 48: Phoenix DX Contract + Truth Audit - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Freeze the exact Phoenix-facing tus support claim for the surface that already
ships today, remove stale active-language that implies the whole LiveView path
is still deferred, and leave a precise contract for what Phase 49 must
productize next.

This phase does not add new tus capability, a new JS package, or a reusable UI
kit. It clarifies support truth, canonical documentation ownership, deferred
language, and archive-handling posture.

</domain>

<decisions>
## Implementation Decisions

### Canonical Phoenix story
- **D-01:** Keep the canonical Phoenix / LiveView tus integration story in
  `guides/resumable_uploads.md`. That guide is the single authoritative
  end-to-end source for router mount, `Plug.Parsers`, CORS, client uploader,
  `allow_tus_upload/4`, and `consume_uploaded_entries/3`.
- **D-02:** `Rindle.LiveView` moduledoc and API docs should stay deliberately
  thin and point to `guides/resumable_uploads.md` instead of becoming a second
  canonical setup guide.
- **D-03:** Do not create a second Phoenix-specific canonical guide in Phase 48.
  One canonical guide is lower-drift and more idiomatic for a Phoenix / ExDoc
  library whose real story crosses router, endpoint, JS, and verification
  boundaries.

### Support claim strength
- **D-04:** Describe the shipped Phoenix path as a supported narrow helper seam,
  not as experimental and not as a broad batteries-included Phoenix uploader
  abstraction.
- **D-05:** The core maintained contract remains the tus edge itself:
  `Rindle.Upload.TusPlug`, `Rindle.initiate_tus_upload/2`, and convergence
  through `verify_completion/2`. The LiveView layer is a real first-party
  helper path over that contract, but it is still convenience wiring rather
  than a full Rindle-owned UI abstraction.
- **D-06:** Support wording must be precise that `allow_tus_upload/4` plus the
  documented `uploader: "RindleTus"` client path are supported now, while the
  adopter still owns router/auth/parser/CORS wiring and current operational
  caveats such as sticky-session or single-node resume posture where relevant.

### Deferred terminology
- **D-07:** Stop using "LiveView tus uploader component" as shorthand for the
  entire deferred scope. That wording is now support-truth drift because the
  helper seam and documented client pattern already ship.
- **D-08:** Replace the old shorthand with an explicit split:
  the shipped contract is `initiate_tus_upload/2` +
  `allow_tus_upload/4` + documented `uploader: "RindleTus"` guidance;
  the deferred work is richer reusable uploader UI/component abstractions beyond
  the supported helper path, plus any future Rindle-owned standalone tus JS
  client package.
- **D-09:** Deferred lists should name UI-kit / component abstractions and
  standalone JS-package ownership separately when both matter, rather than
  collapsing them into one vague "LiveView uploader" bucket.

### Truth-alignment scope
- **D-10:** Phase 48 should truth-align active source-of-truth artifacts first:
  `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md`, relevant active
  guides, and API docs/moduledocs that speak about the Phoenix path.
- **D-11:** Archived v1.8 research and milestone artifacts should remain
  historical records rather than being rewritten wholesale. Preserve the
  historiography.
- **D-12:** Add short archival disclaimers or cross-links on the specific
  archived v1.8 research/context files whose older "deferred" wording can still
  mislead grep-driven readers, pointing them to active v1.9 truth surfaces
  rather than retroactively rewriting the body text.

### Downstream-agent posture
- **D-13:** Planning and execution for this milestone should default to one
  coherent recommendation set and decide by default on local, reversible, or
  ergonomic choices. Escalate only for high-blast-radius changes such as
  semver-significant support-boundary reshapes, security-boundary changes,
  destructive actions, material recurring-cost surprises, or milestone/scope
  changes.

### the agent's Discretion
- Exact support-copy phrasing, as long as it preserves the D-04 through D-09
  boundary precisely and does not imply a broader Phoenix abstraction than
  exists.
- Exact archive-banner format and placement, as long as archived docs remain
  visibly historical and point clearly at active truth surfaces.
- Exact cross-link targets between `Rindle.LiveView` docs and
  `guides/resumable_uploads.md`.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Active phase contract
- `.planning/ROADMAP.md` — Phase 48 goal, success criteria, and the v1.9 phase
  split across truth audit, productization, and proof.
- `.planning/REQUIREMENTS.md` — `PHX-01` and `TRUTH-01`, plus the milestone’s
  support-truth and proof posture.
- `.planning/PROJECT.md` — project constitution, decision-by-default posture,
  and locked v1.9 framing for the Phoenix tus seam.
- `.planning/STATE.md` — current milestone truth, including that the remaining
  wedge is Phoenix DX completion and support honesty.

### Shipped Phoenix / tus surface
- `lib/rindle/live_view.ex` — shipped `allow_tus_upload/4` seam and current
  helper metadata shape.
- `guides/resumable_uploads.md` — current canonical operational guide for the
  shipped tus path, including the `RindleTus` uploader example.
- `lib/rindle.ex` — shipped public tus facade entrypoints including
  `initiate_tus_upload/2`.

### Prior phase context and historical drift source
- `.planning/phases/42-tus-protocol-edge-bare-plug/42-CONTEXT.md` — original
  v1.8 boundary and deferred-language source that still mentioned a future
  LiveView uploader component.
- `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-CONTEXT.md`
  — locked tus auth/DX/docs/doctor/proof posture inherited by the current
  Phoenix truth-audit work.
- `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md`
  — current proof authority posture for the tus path.
- `.planning/research/v1.8/TUS-RESEARCH.md` §12 — historical candidate language
  that deferred a LiveView uploader component to v1.9.
- `.planning/research/v1.8/STRATEGY-SEQUENCING.md` — historical sequencing doc
  that still uses the older deferred shorthand.
- `.planning/milestones/v1.8-ROADMAP.md` — archived milestone snapshot that
  still records the earlier wording as a historical record.

### Product and OSS posture
- `prompts/gsd-rindle-elixir-oss-dna.md` — single-source truth, support honesty,
  calm explicit docs, and decision-by-default OSS posture.
- `prompts/gsd-rindle-gsd-bootstrap-brief.md` — locked expectations around one
  coherent recommendation set, explicit contracts, and canonical adopter truth.
- `prompts/phoenix-media-uploads-lib-deep-research.md` — cross-ecosystem media
  library lessons around explicit contracts, helper-vs-guide posture, and DX
  tradeoffs.
- `prompts/rindle-brand-book.md` — calm, explicit, production-aware voice and
  anti-hype constraints for support wording.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `guides/resumable_uploads.md`: already contains the operational Phoenix tus
  story, including route mount, parser/CORS caveats, `allow_tus_upload/4`, and
  `Uploaders.RindleTus`.
- `lib/rindle/live_view.ex`: already ships the thin helper seam and should be
  treated as a pointer/reference layer rather than the place where all Phoenix
  operational guidance is duplicated.
- `lib/rindle.ex`: already exposes the public tus initiation path that the
  helper sits on top of.

### Established Patterns
- Active truth lives in `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, and
  `STATE.md`; milestone archives are historical evidence, not the live support
  contract.
- Rindle favors explicit capability boundaries and calm, non-magical docs over
  broad convenience claims.
- Canonical adopter stories in this repo already use a guide-first posture with
  README or API docs pointing into deeper operational guides.

### Integration Points
- Phase 48 planning should connect active planning/doc truth surfaces to the
  shipped `Rindle.LiveView.allow_tus_upload/4` seam and `guides/resumable_uploads.md`.
- Archive-disclaimer work should target the specific v1.8 research/context files
  that still surface misleading deferred wording in repo search.
- Phase 49 must inherit the exact boundary between supported helper contract and
  deferred richer UI/package abstractions from this file.

</code_context>

<specifics>
## Specific Ideas

- Treat `guides/resumable_uploads.md` as the Phoenix tus equivalent of an
  operational contract page: one place that answers “what is actually
  supported?” without forcing adopters to infer support boundaries from source
  history.
- Phrase the current seam as “supported helper path” or “supported thin helper
  seam” rather than “experimental” or “full Phoenix uploader support.”
- When archive disclaimers are added, prefer a short banner that says the file
  is a historical v1.8 artifact and points readers to active v1.9 truth
  surfaces for the current support contract.
- Carry the user’s preference left: downstream GSD planning/execution should
  resolve local tradeoffs autonomously and present one cohesive recommendation
  set unless the choice has real blast radius.

</specifics>

<deferred>
## Deferred Ideas

- Rindle-owned reusable uploader UI kit / component abstractions beyond the
  current helper seam.
- Rindle-owned standalone tus JS client package.
- Broader multi-provider Phoenix upload abstractions beyond the current narrow
  tus helper path.

</deferred>

---

*Phase: 48-phoenix-dx-contract-truth-audit*
*Context gathered: 2026-05-25*
