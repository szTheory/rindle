# Phase 54: Execute + Orphan-Safe Purge Wiring - Context

**Gathered:** 2026-05-26 (assumptions mode + advisor research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement the public owner/account erasure execute lane promised by Phase 53.
This phase must detach all attachments for the target owner, preserve shared
assets that still have surviving attachments, enqueue async purge only for
newly orphaned assets, and return a stable idempotent report on reruns.

This phase does not add admin UI, bulk orchestration, force-delete semantics
for still-shared assets, or a broader lifecycle API reshape.
</domain>

<decisions>
## Implementation Decisions

### Public execute lane
- **D-01:** Ship `Rindle.erase_owner/2` as the public execute entrypoint and
  keep `Rindle.preview_owner_erasure/2` as its explicit dry-run companion.
- **D-02:** `Rindle.erase_owner/2` should execute synchronously from the
  caller's perspective: compute the erasure plan, detach owner attachments
  transactionally, enqueue purge work, and return `{:ok, owner_erasure_report()}`.
- **D-03:** Reuse the current owner input contract used by `attach/4` and
  `detach/3`: an owner struct with `id`, resolved internally through
  `get_owner_info/1`.
- **D-04:** The execute lane erases only Rindle-managed media associations for
  the owner. It does not delete the adopter's account row.

### Planning and transaction boundary
- **D-05:** Build a shared internal owner-erasure planning helper used by both
  preview and execute so both surfaces compute the same semantic partition.
- **D-06:** Execute should recompute the plan inside its own transaction path;
  do not trust a prior preview result as execution input.
- **D-07:** Use `Ecto.Multi` for the execute flow so the dynamic detach set and
  purge enqueue set remain named, auditable, and transactionally coupled.
- **D-08:** Keep storage deletion out of the DB transaction. The transaction is
  for attachment-row mutation and purge-job enqueue only.

### Shared-asset and purge safety
- **D-09:** Partition affected assets into `assets_to_purge` and
  `retained_shared_assets` before enqueueing any purge jobs.
- **D-10:** An asset is purge-eligible only if detaching the target owner's
  attachment rows leaves it with zero surviving attachments.
- **D-11:** `PurgeStorage` must re-check for surviving attachments immediately
  before destructive deletion, even if the asset was previously classified as
  orphaned.
- **D-12:** The worker-side re-check is mandatory because the current worker
  deletes by `asset_id` and the schema permits multiple attachments per asset;
  a stale purge job must not delete media still owned elsewhere.
- **D-13:** Current `attach/4` and `detach/3` purge enqueueing must remain safe
  under the strengthened purge-worker semantics; Phase 54 should improve the
  worker boundary, not invent a second destructive lane.

### Idempotency and uniqueness
- **D-14:** Re-running `Rindle.erase_owner/2` after the owner's attachments are
  already gone must return `{:ok, zeroed_report}` rather than error.
- **D-15:** Purge jobs should be unique by asset identity for active job
  states, but worker idempotency is the primary guarantee and uniqueness is
  only a dedupe aid.
- **D-16:** Treat Oban enqueue conflicts as "already queued" success, not as an
  operation failure.
- **D-17:** Do not use a completed-forever uniqueness policy that could block a
  legitimate later purge after an earlier no-op/shared-asset skip.

### Public report shape
- **D-18:** Keep the frozen public vocabulary:
  `attachments_to_detach`, `assets_to_purge`, `retained_shared_assets`, and
  `purge_enqueued`.
- **D-19:** Distinguish preview vs execute with semantic result fields such as
  `mode`, not with a separate payload family.
- **D-20:** Report entries should be plain semantic maps, not raw `Ecto.Multi`,
  `Oban.Job`, schema structs, or internal step names.
- **D-21:** `attachments_to_detach.entries` should include enough audit detail
  to explain the detach set without leaking unrelated owner data; the minimum
  useful shape is `attachment_id`, `asset_id`, and `slot`.
- **D-22:** `assets_to_purge.entries` should identify assets semantically
  enough for proof and operator understanding; `asset_id` and `profile` are the
  core useful fields.
- **D-23:** `retained_shared_assets.entries` should explain retention
  explicitly; include `surviving_attachment_count` so shared-asset behavior is
  proof-friendly without exposing full surviving attachment rows.
- **D-24:** If enqueue conflicts need to be reported, prefer a semantic field
  like `purge_already_queued` rather than leaking raw Oban conflict details.

### Support-truth and planning posture
- **D-25:** Public docs and proof for this phase and Phase 55 must describe
  execute semantics honestly as "detach now, purge enqueued later" rather than
  "bytes deleted immediately."
- **D-26:** `detach/3` remains slot-scoped and `cleanup_orphans` remains
  maintenance-only; neither should be reframed as the supported owner-erasure
  API.
- **D-27:** Any move toward force-delete behavior, bulk/admin orchestration, or
  a broader public API reshaping is high-blast-radius scope and remains
  deferred beyond this phase.

### the agent's Discretion
- Exact internal module/helper layout behind the shared plan-builder and
  execute flow.
- Whether `mode` and "already queued" details are encoded as atoms or strings,
  as long as the public semantic contract stays stable and proof-friendly.
- Exact `Ecto.Multi` step naming and query helper decomposition.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Active phase contract
- `.planning/ROADMAP.md` — Phase 54 goal, requirements mapping, and success
  criteria.
- `.planning/REQUIREMENTS.md` — `LIFE-02`, `LIFE-03`, `LIFE-04`, support-truth
  boundary, and milestone non-goals.
- `.planning/PROJECT.md` — v1.10 milestone framing, support-truth posture, and
  decision-making contract.
- `.planning/STATE.md` — current milestone status and owner-erasure wedge
  framing.
- `.planning/phases/53-owner-erasure-contract-truth-gate/53-CONTEXT.md` —
  frozen public contract inherited by Phase 54.

### Current milestone research and pitfalls
- `.planning/research/SUMMARY.md` — v1.10 wedge summary and major risks.
- `.planning/research/ARCHITECTURE.md` — recommended owner-erasure integration
  shape.
- `.planning/research/PITFALLS.md` — destructive-work footguns this phase must
  close.
- `.planning/threads/2026-05-25-next-milestone-ordering.md` — repo-truth
  rationale for the owner-erasure milestone and the shared-asset hazard.

### Relevant shipped code and tests
- `lib/rindle.ex` — current public facade, typed report contract, and existing
  attach/detach patterns.
- `lib/rindle/workers/purge_storage.ex` — current async purge seam that must
  become survivor-aware.
- `lib/rindle/domain/media_attachment.ex` — ownership join semantics and slot
  uniqueness boundary.
- `lib/rindle/domain/media_asset.ex` — asset shared-state model and attachment
  relationship.
- `priv/repo/migrations/20260425090000_create_media_attachments.exs` — DB
  cascade behavior and attachment foreign-key direction.
- `test/rindle/attach_detach_test.exs` — current idempotent detach and purge
  expectations.
- `test/rindle/workers/purge_storage_test.exs` — current purge-worker behavior
  that needs shared-asset hardening.
- `test/rindle/ops/variant_maintenance_test.exs` — existing Oban conflict
  handling pattern worth reusing for enqueue dedupe semantics.
- `guides/user_flows.md` — support-truth wording the execute lane must keep
  honest.

### Prompt and philosophy inputs
- `prompts/gsd-rindle-gsd-bootstrap-brief.md` — explicit state, strict
  defaults, idempotent processing, and operator-friendly lifecycle posture.
- `prompts/gsd-rindle-elixir-oss-dna.md` — explicit contracts, named footguns,
  and transaction/async side-effect guidance.
- `prompts/phoenix-media-uploads-lib-deep-research.md` — lifecycle architecture
  and destructive-work lessons from adjacent ecosystems.
- `prompts/rindle-brand-book.md` — calm, explicit, non-magical voice and DX
  constraints.

### External prior-art references
- `https://guides.rubyonrails.org/active_storage_overview.html` — attachment vs
  purge split, direct-upload orphan cleanup, and background purge semantics.
- `https://api.rubyonrails.org/classes/ActiveStorage/Attachment.html` —
  shared-blob attachment boundary and purge behavior.
- `https://shrinerb.com/docs/attacher` — attachment-centric lifecycle verbs.
- `https://shrinerb.com/docs/plugins/backgrounding` — idempotent background
  promotion/deletion and concurrency-safety lessons.
- `https://hexdocs.pm/ecto/Ecto.Multi.html` — idiomatic dynamic transaction
  orchestration.
- `https://hexdocs.pm/oban/Oban.html` — transaction-safe job enqueueing.
- `https://hexdocs.pm/oban/unique_jobs.html` — Oban uniqueness semantics and
  limits.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle` already provides the correct public-facade boundary: explicit
  tagged-tuple results and app-facing lifecycle entrypoints.
- `get_owner_info/1` in `lib/rindle.ex` already normalizes owner structs into
  `owner_type` + `owner_id`, which is the natural owner-erasure selection seam.
- `media_attachments` already encode ownership claims via `owner_type`,
  `owner_id`, and `slot`.
- `PurgeStorage` and existing Oban integration already provide the async
  destructive seam; Phase 54 should harden and reuse it, not replace it.
- Existing Oban conflict handling in variant-maintenance flows provides a local
  pattern for treating uniqueness conflicts as semantic skips rather than hard
  errors.

### Established Patterns
- Public lifecycle capabilities belong on `Rindle`; lower-level orchestration
  details stay internal.
- Heavy or destructive side effects happen asynchronously after DB truth is
  committed, not inline in the transaction.
- Idempotent no-op behavior on reruns is already established by `detach/3`.
- The repo prefers semantic report maps and support-truth wording over exposing
  raw internal machinery.

### Integration Points
- Phase 54 should introduce a shared internal owner-erasure planner that both
  preview and execute can consume.
- `erase_owner/2` should couple attachment deletion and purge-job enqueueing in
  one DB transaction via `Ecto.Multi`.
- `PurgeStorage` must gain a survivor-aware attachment re-check before storage
  deletion and asset-row deletion.
- Existing attach/detach flows should continue to enqueue purge through the
  same worker boundary, benefiting from the hardened shared-asset guard.
</code_context>

<specifics>
## Specific Ideas

- Treat owner erasure as "detach all references for this owner, then enqueue
  purge only for assets whose reference count reaches zero."
- Use the same plan-builder semantics for preview and execute, but recompute
  under execute so the live transaction sees current DB truth.
- Keep the report contract calm and semantic: explain what will detach, what
  will purge later, and what was retained because other attachments still live.
- Prefer a small additive report enhancement like `mode` and optionally
  `purge_already_queued` over inventing a second execute-only payload shape.
- Tighten `PurgeStorage` because the current unconditional `asset_id` purge is
  the real shared-asset hazard exposed by this milestone.
</specifics>

<deferred>
## Deferred Ideas

- Force-delete policy for still-shared assets.
- Bulk/admin/compliance orchestration around the core owner-erasure facade.
- Any UI surface for operator review or account-deletion workflows.
- Broader public lifecycle API reshaping beyond `preview_owner_erasure/2` and
  `erase_owner/2`.
- App-level durable purge markers beyond Oban uniqueness unless later proof or
  compliance needs justify the extra state complexity.

### Reviewed Todos (not folded)
None — `todo.match-phase 54` returned no relevant todos.
</deferred>

---

*Phase: 54-execute-orphan-safe-purge-wiring*
*Context gathered: 2026-05-26*
