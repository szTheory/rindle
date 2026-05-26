# Next Milestone Ordering After v1.9

Date: 2026-05-25
Status: open

## Why this thread exists

Preserve the post-v1.9 milestone ordering from shipped repo truth so the next
milestone does not start from older candidate-ranking artifacts that predate
the shipped browser→Mux direct-upload surface.

## Shipped-truth correction

Do not treat browser→Mux direct creator upload as pending work.

Shipped evidence already exists in:

- `lib/rindle/streaming.ex` — `Rindle.Streaming.create_direct_upload/2`
- `lib/rindle/live_view.ex` — `Rindle.LiveView.allow_direct_upload/4`
- `lib/rindle/streaming/provider/mux.ex` — Mux adapter support
- `guides/streaming_providers.md` — adopter-facing direct-upload docs
- `test/rindle/streaming/create_direct_upload_test.exs`
- `test/rindle/live_view_direct_upload_test.exs`
- `test/rindle/streaming/provider/mux/mux_test.exs`

Any planning artifact that still ranks "browser→Mux direct upload" as the next
candidate is stale and should lose to shipped code/tests/docs.

## Known drift to ignore until refreshed

`JTBD-MAP.md` is still strategically useful, but its current anchor is
`Against: milestone v1.7`, so the ranked-gap and milestone-priority sections
predate two now-shipped truths:

- browser→Mux direct creator upload is real in v1.8
- Phoenix / LiveView tus DX completion plus generated-app proof closed in v1.9

Until that artifact is regenerated, use `PROJECT.md`, `STATE.md`, this thread,
and shipped code/tests/guides as the ordering source of truth.

## Ranked wedges

1. `purge_owner`-style owner/account erasure
2. tus protocol follow-ons as one narrow bundle: checksum, concatenation,
   `Upload-Defer-Length`
3. `cancel_direct_upload/1`
4. richer Phoenix uploader abstractions beyond the current helper seam
5. second streaming provider only on explicit adopter demand

## Recommendation

If starting `v1.10` now, prefer first-class owner/account erasure.

Why:

- It is the most universal remaining SaaS lifecycle job.
- It stays inside Rindle's core mission instead of pushing into broader upload
  UI or provider breadth.
- It builds on already-shipped primitives (`attach` / `detach` /
  `cleanup_orphans`) rather than introducing another protocol or provider
  surface.

## Owner-erasure design constraint to carry into v1.10 planning

The remaining ambiguity is not "whether owner erasure matters" but what exactly
it erases when assets can be attached more than once.

Repo truth today:

- `Rindle.attach/4` and `Rindle.detach/3` are slot-scoped only.
- `mix rindle.cleanup_orphans` removes expired upload residue, not attached
  owner media.
- `PurgeStorage` purges by `asset_id`, so an owner-level API cannot blindly
  delete an asset that still has another live attachment.

Implication for the next milestone:

- `purge_owner` / `erase_owner` should be planned as a first-class facade API
  with explicit shared-asset semantics, dry-run/reporting shape, and docs/proof
  for account deletion.
- Do not treat this as "just loop detach over slots" unless the milestone
  deliberately locks a single-owner-only contract for attached assets.

## Non-default candidates

- tus follow-ons are real but narrower than owner erasure and should be driven
  by concrete adopter need rather than protocol completeness for its own sake.
- tus follow-ons remain a coherent bundle (`checksum`, `concatenation`,
  `Upload-Defer-Length`) but they now sit firmly in protocol-completeness
  territory around an already-usable shipped tus product.
- `cancel_direct_upload/1` is the main remaining Mux direct-upload hole, but it
  is provider-specific control-surface work, not a broad core lifecycle wedge.
- richer Phoenix uploader abstractions are convenience work, not required proof
  that the current library mission is real.
- a second streaming provider is a contract-test/demand milestone, not a
  default breadth expansion.
