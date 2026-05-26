# Phase 53: owner-erasure-contract-truth-gate - Context

**Gathered:** 2026-05-26 (assumptions mode + advisor research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Freeze the supported owner/account erasure contract before implementation
lands. Phase 53 defines the public API boundary, the dry-run/reporting result
shape, the retained-shared-asset rule, the async execution posture, and the
support-truth/non-goal wording that Phase 54 and Phase 55 must inherit.

This phase does not implement the execute path, admin UI, bulk orchestration,
or force-delete policy for still-shared assets.
</domain>

<decisions>
## Implementation Decisions

### Public API shape
- **D-01:** The supported public surface should live on `Rindle`, not on Mix
  tasks, workers, or lower-level internal helpers.
- **D-02:** Use two explicit public facade functions rather than one
  mode-switched destructive API:
  `Rindle.preview_owner_erasure/2` and `Rindle.erase_owner/2`.
- **D-03:** `preview_owner_erasure/2` is a read-only planning/reporting call.
  `erase_owner/2` performs the detach work and enqueues orphan-only purge work.
- **D-04:** The public contract is about erasing Rindle-managed media
  associations for an owner. Do not imply that Rindle deletes the adopter's
  owner/account row itself.

### Reporting contract
- **D-05:** Dry-run and execute must return the same stable `{:ok, report}`
  contract, differing by `mode`/result values rather than by key vocabulary or
  payload family.
- **D-06:** The report must explicitly partition results into:
  `attachments_to_detach`, `assets_to_purge`, and `retained_shared_assets`.
- **D-07:** The report should include both totals and lists so docs, proof, and
  operator/debug flows stay auditable without extra queries.
- **D-08:** Use semantic result fields such as `purge_enqueued` and
  `retained_shared_assets`; do not claim storage is already deleted on execute.
- **D-09:** Keep the public report semantic and stable. Do not expose raw
  `Ecto.Multi` state, Oban job internals, or unrelated attachment/owner data.

### Shared-asset semantics
- **D-10:** Retain any asset that still has a surviving live attachment after
  the target owner's rows are removed.
- **D-11:** Purge only assets that become newly orphaned because of this owner
  erasure operation.
- **D-12:** Do not make destructive policy configurable in `v1.10`. Force-delete
  behavior for still-shared assets is explicitly deferred.
- **D-13:** Idempotent reruns must return a stable success/no-op report rather
  than raising or attempting duplicate purge work.

### Execution boundary
- **D-14:** The execute path should preserve Rindle's existing durability
  posture: DB detach work happens transactionally first, then async purge work
  handles orphaned assets afterward.
- **D-15:** Do not perform storage deletion inline in the request path or inside
  the DB transaction.
- **D-16:** Phase 54 should reuse the existing purge lane, but make it
  survivor-aware and safe for owner-erasure-triggered purge enqueueing.
- **D-17:** Worker/job idempotency and uniqueness should be used so reruns and
  retries do not double-purge the same asset.

### Support-truth boundary
- **D-18:** `detach/3` remains a slot-scoped attachment API, not the supported
  account-deletion surface.
- **D-19:** `mix rindle.cleanup_orphans` remains upload-session/staged-object
  maintenance, not the owner/account erasure API.
- **D-20:** Active planning and future docs should describe one supported
  owner-erasure facade, explicit retained-shared-asset semantics, and explicit
  non-goals: admin UI, bulk orchestration, and force-delete policy.

### Downstream planning posture
- **D-21:** Planning should treat the recommended boundary as already narrowed:
  explicit public facade, shared report contract, retained-shared-asset rule,
  transaction + async purge posture, and contract-first truth alignment.
- **D-22:** Downstream agents should continue the project default posture:
  produce one coherent recommendation set, decide by default on local
  reversible choices, and escalate only for high-blast-radius decisions.

### the agent's Discretion
- Exact report map-vs-struct implementation detail, as long as the public
  semantic field contract stays stable and proof-friendly.
- Exact helper/internal service layout behind the `Rindle` facade.
- Exact wording of status atoms or counts, as long as `attachments_to_detach`,
  `assets_to_purge`, and `retained_shared_assets` remain the user-facing
  conceptual buckets.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Active phase contract
- `.planning/ROADMAP.md` — Phase 53 goal, success criteria, and current v1.10
  phase split.
- `.planning/REQUIREMENTS.md` — `LIFE-01` and `TRUTH-02`, plus the support
  truth gate and non-goals for owner erasure.
- `.planning/PROJECT.md` — project-level decision-making contract, support
  truth posture, and `v1.10` milestone framing.
- `.planning/STATE.md` — current milestone status and owner-erasure wedge
  framing.

### Current milestone research
- `.planning/research/SUMMARY.md` — recommended owner-erasure wedge summary.
- `.planning/research/ARCHITECTURE.md` — recommended integration shape and
  reuse of attachment/asset/purge seams.
- `.planning/research/PITFALLS.md` — locked destructive-work footguns and
  prevention strategy.
- `.planning/research/FEATURES.md` — table stakes and anti-features for the
  owner-erasure capability.
- `.planning/threads/2026-05-25-next-milestone-ordering.md` — repo-truth
  justification for why owner erasure is the next wedge and what ambiguity
  remains.

### Relevant shipped code/docs
- `lib/rindle.ex` — current public lifecycle facade, plus current `attach/4`
  and `detach/3` behavior.
- `lib/rindle/domain/media_attachment.ex` — attachment row identity and
  uniqueness contract.
- `lib/rindle/domain/media_asset.ex` — asset shared-state model and
  attachment relationship.
- `lib/rindle/workers/purge_storage.ex` — existing async purge seam that Phase
  54 must reuse safely.
- `lib/rindle/ops/upload_maintenance.ex` — existing report-style operational
  surface and dry-run/live maintenance posture.
- `guides/user_flows.md` — current adopter-facing workaround wording that Phase
  55 must replace honestly after implementation exists.

### Prompt and posture inputs
- `prompts/gsd-rindle-gsd-bootstrap-brief.md` — locked decision-by-default and
  high-blast-radius escalation posture.
- `prompts/gsd-rindle-elixir-oss-dna.md` — explicit-contract, async-side-effect,
  and CI/truth posture.
- `prompts/phoenix-media-uploads-lib-deep-research.md` — prior-art lessons on
  lifecycle architecture, variants, async heavy work, and support truth.
- `prompts/rindle-brand-book.md` — calm, explicit, anti-hype documentation and
  product voice constraints.

### External prior-art references
- `https://guides.rubyonrails.org/active_storage_overview.html` — attachment vs
  purge boundary, direct-upload and lifecycle lessons.
- `https://api.rubyonrails.org/classes/ActiveStorage/Attachment.html` —
  explicit attachment deletion/purge semantics.
- `https://shrinerb.com/docs/attacher` — attachment-centric public API lessons.
- `https://shrinerb.com/docs/plugins/backgrounding` — async destructive-work
  and background processing lessons.
- `https://hexdocs.pm/ecto/Ecto.Multi.html` — idiomatic Elixir transactional
  boundary.
- `https://hexdocs.pm/oban/Oban.html` and
  `https://hexdocs.pm/oban/unique_jobs.html` — async job orchestration and
  idempotency guidance.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle` facade functions already provide the right public-boundary pattern:
  app-facing entrypoint, tagged-tuple return contract, and report-shaped
  results for richer operations.
- `media_attachments` already encode owner identity via `owner_type`,
  `owner_id`, and `slot`, which is the natural owner-erasure selection seam.
- `media_assets` already represent shared storage-backed state and can be
  referenced by multiple attachments.
- `PurgeStorage` and the existing Oban integration provide the async destructive
  seam Phase 54 should reuse rather than replace.
- `UploadMaintenance.cleanup_orphans/1` already demonstrates a dry-run/live
  report posture that is useful as a DX reference for owner-erasure reporting.

### Established Patterns
- Public lifecycle capabilities belong on `Rindle`, while Mix tasks/workers act
  as operator wrappers or internal execution machinery.
- Rindle prefers explicit contracts, async destructive work, idempotent jobs,
  and calm support truth over magical convenience.
- Existing planning posture already expects one recommendation set, with
  alternatives recorded as rationale rather than surfaced as equal menus.
- The repo values auditable report maps with explicit counters and stable keys.

### Integration Points
- Phase 54 should add owner-wide attachment discovery and orphan partitioning
  on top of the current attachment/asset model, not invent a parallel deletion
  subsystem.
- The purge worker must become safe for shared assets before owner-erasure
  execute semantics can ship.
- Phase 55 should update docs/proof only once the facade contract is both
  implemented and executable, so support truth remains honest.
</code_context>

<specifics>
## Specific Ideas

- Prefer the explicit pair `preview_owner_erasure/2` and `erase_owner/2` over a
  single boolean- or mode-switched destructive API on the public facade.
- Treat the report shape as part of the product contract, not as an incidental
  implementation detail.
- Phrase execution honestly as detach + purge enqueue, not “all bytes deleted
  now.”
- Use “retained shared assets” instead of vague skip/failure language so the
  caller understands why some assets intentionally survive.
- Preserve the mental split used successfully in adjacent ecosystems:
  attachment removal is one concern, background purge is another, and shared
  asset safety is explicit.
</specifics>

<deferred>
## Deferred Ideas

- Configurable force-delete policy for still-shared assets.
- Bulk/admin/compliance orchestration around the core owner-erasure facade.
- Any UI surface for account deletion or operator review.
- Broader compliance workflow promises beyond the narrow lifecycle contract.

### Reviewed Todos (not folded)
None — `todo.match-phase 53` returned no relevant todos.
</deferred>

---

*Phase: 53-owner-erasure-contract-truth-gate*
*Context gathered: 2026-05-26*
