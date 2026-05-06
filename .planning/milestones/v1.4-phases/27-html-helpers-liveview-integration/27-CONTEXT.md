# Phase 27: HTML Helpers + LiveView Integration - Context

**Gathered:** 2026-05-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Phoenix adopters get first-class AV template and LiveView ergonomics on top of
the v1.4 delivery and processor work: `Rindle.HTML.video_tag/3`,
`Rindle.HTML.audio_tag/3`, `Rindle.LiveView.subscribe/2`,
`Rindle.LiveView.unsubscribe/1`, and `Rindle.cancel_processing/1`, plus a
frozen public event and error-message contract.

In scope:
- `<video>` / `<audio>` helpers that mirror the existing `picture_tag/3` shape
- Explicit poster resolution from a declared variant
- Progressive playback URLs resolved through `Rindle.Delivery.streaming_url/3`
- Thin LiveView subscription helpers over PubSub topics
- Public `{:rindle_event, type, payload}` message contract for variant progress
- Asset-scoped cancellation of queued/executing transcode jobs
- Locked, self-explanatory text for the 8 v1.4 error reasons

Out of scope:
- Caption / subtitle implementation beyond reserving the `:tracks` option
- HLS / DASH / manifest-aware helper behavior
- Per-variant public cancellation APIs
- Admin UI or bundled LiveView components
</domain>

<decisions>
## Implementation Decisions

### HTML Helper Shape
- **D-01:** `Rindle.HTML.video_tag/3` and `audio_tag/3` must stay intentionally
  thin and mirror the existing `picture_tag/3` calling shape:
  `(profile, asset, opts)`.
- **D-02:** The caller-provided `:variants` order is preserved as rendered
  `<source>` order. This is the codec-priority contract; the helper must not
  re-sort by MIME, extension, or readiness.
- **D-03:** Stale, failed, queued, processing, and otherwise non-ready variants
  are skipped from the rendered `<source>` list. This matches the current
  `picture_tag/3` behavior and Phase 27 success criteria.
- **D-04:** The helpers fall back to the original asset source when a listed
  variant is not ready. They should not emit broken `<source>` tags or force
  callers to branch on variant state.
- **D-05:** `video_tag/3` resolves playback URLs through
  `Rindle.Delivery.streaming_url/3`, not `url/3`, so templates already use the
  future-stable AV delivery surface reserved in Phase 26.
- **D-06:** `audio_tag/3` uses the same streaming-oriented delivery path and
  source-resolution rules as `video_tag/3`.

### Media Element Defaults
- **D-07:** `video_tag/3` defaults `preload` to `"metadata"`. This is the
  project default unless the caller explicitly overrides it.
- **D-08:** `audio_tag/3` defaults `controls: true` and `preload: "metadata"`.
  Audio without controls should require an explicit caller choice.
- **D-09:** Any HTML attributes not consumed by helper-specific options are
  passed through verbatim to the root `<video>` or `<audio>` element, matching
  the current `picture_tag/3` philosophy.
- **D-10:** The `:tracks` option is part of the public helper signature now but
  remains reserved for v1.5 captions/subtitles. Phase 27 should accept the key
  without expanding the feature surface into caption delivery.

### Poster and Source Resolution
- **D-11:** Poster behavior is explicit. `video_tag/3` consumes `poster: :poster`
  style variant references; it must not auto-discover a poster variant.
- **D-12:** Poster resolution is via a declared variant atom first-class in the
  profile DSL, consistent with Phase 25's explicit poster decision.
- **D-13:** A literal poster URL string remains acceptable as an escape hatch,
  but the canonical docs and tests should teach variant-atom poster resolution.
- **D-14:** `audio_tag/3` has no poster behavior at all; keep the surface narrow.
- **D-15:** Phase 27 should preserve the existing helper convention that variant
  URL resolution tolerates missing/non-ready derivatives and degrades cleanly to
  the original asset rather than crashing template rendering.

### LiveView Event Contract
- **D-16:** `Rindle.LiveView.subscribe/2` is a thin Phoenix-facing helper over
  PubSub topics, not a process registry or stateful subscription manager.
- **D-17:** Supported subscription kinds are exactly `:variant`, `:asset`, and
  `:upload_session`, as locked in the roadmap.
- **D-18:** The public LiveView-facing event contract is
  `{:rindle_event, type, payload}`. Raw internal worker messages such as
  `{:rindle_variant_progress, payload}` are implementation detail and should not
  be the public API.
- **D-19:** Public event types are exactly
  `:variant_started`, `:variant_progress`, `:variant_ready`, `:variant_failed`,
  and `:variant_cancelled`.
- **D-20:** `unsubscribe/1` must mirror `subscribe/2` symmetrically so adopters
  do not need to know topic string shapes.
- **D-21:** Phase 27 should adapt the current worker broadcast seam in
  `Rindle.Workers.ProcessVariant` into this public contract rather than asking
  adopters to subscribe to private topic/message details directly.

### Progress and Rate Limiting
- **D-22:** Progress events remain variant-centric first and asset-rollup second,
  consistent with the existing `"rindle:variant:#{id}"` and
  `"rindle:asset:#{id}"` topic structure already present in the worker.
- **D-23:** The public progress contract is rate-limited to at most 2 events per
  second per variant, per the locked requirements. This limit is part of the
  API behavior, not just an optimization.
- **D-24:** Phase 27 should treat worker-side throttling as the canonical source
  of truth. LiveView helpers should not invent their own secondary throttle
  layer that changes message cadence unpredictably.

### Cancellation API
- **D-25:** The public cancellation surface is asset-scoped only:
  `Rindle.cancel_processing(asset_id)`.
- **D-26:** Cancellation must target both queued and executing Oban jobs for the
  asset's variants. A half-cancelled result that only affects queued jobs does
  not satisfy the phase contract.
- **D-27:** Affected variants transition to `cancelled`, asset aggregate state is
  recomputed, and `:variant_cancelled` events are broadcast. Cancellation is a
  visible lifecycle outcome, never a silent no-op.
- **D-28:** The return contract remains narrow and explicit:
  `:ok | {:error, :not_processing}`.
- **D-29:** Phase 27 does not expose a public `cancel_processing/2` or
  variant-id-based cancellation surface. That would widen the public API beyond
  the phase boundary.

### Error Vocabulary
- **D-30:** The eight v1.4 AV-facing error reasons listed in the roadmap are a
  frozen public vocabulary and must receive stable human-readable text through
  `Rindle.Error.message/1`.
- **D-31:** The message style should be fix-oriented and concrete, not terse
  exception prose. Each message should tell the adopter what failed and what to
  change next in `mix phx.gen` style.
- **D-32:** Exact message text is locked by parity tests. Planner/implementation
  should treat wording drift as a public-contract regression.
- **D-33:** Phase 27 extends the current generic `Rindle.Error.message/1`
  implementation into a richer AV-aware message surface rather than introducing
  a parallel error-rendering module.

### Decision-Making Preference
- **D-34:** Carry forward the standing project preference from `.planning/STATE.md`:
  keep the public API coherent and additive, preserve the existing thin-helper
  philosophy, and escalate only if a genuine semver-significant ambiguity
  appears during planning.

### the agent's Discretion
- Exact private helper decomposition inside `lib/rindle/html.ex` so long as the
  public helper contract above remains intact.
- Exact payload field names beyond the required event type/topic guarantees,
  provided tests lock the public schema once chosen.
- Whether `subscribe/2` returns only the topic string or a slightly richer
  subscription token, so long as `unsubscribe/1` is symmetrical and the public
  docs stay simple.
- Exact Oban cancellation mechanism (`Oban.cancel_job/1`, engine helpers, query
  strategy) so long as queued and executing jobs are both addressed.
</decisions>

<specifics>
## Specific Ideas

- Canonical video helper example to preserve in docs/tests:
  ```elixir
  Rindle.HTML.video_tag(profile, asset,
    variants: [:web_720p, :web_480p],
    poster: :poster,
    controls: true,
    preload: :metadata
  )
  ```
- Keep the helper layer explicit: `poster: :poster` is better than auto-guessing
  from variant names or output kinds.
- Keep the LiveView story centered on `handle_info/2` with
  `{:rindle_event, type, payload}`. Adopters should not need to know about the
  worker's current raw PubSub tuple shape.
- `picture_tag/3` should remain image-specific. Phase 27 adds AV helpers; it
  does not mutate the image helper into a polymorphic media renderer.
</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source of truth
- `.planning/ROADMAP.md` — Phase 27 goal, requirements, and success criteria
- `.planning/REQUIREMENTS.md` — AV-05-01 through AV-05-07
- `.planning/PROJECT.md` — v1.4 milestone goal, delivery posture, and AV security constraints
- `.planning/STATE.md` — current milestone state and decision-making preference

### Prior phase decisions this phase must honor
- `.planning/phases/25-rindle-processor-av/25-CONTEXT.md` — explicit poster variant posture, progress reporting, aggregate cancellation semantics
- `.planning/phases/26-delivery-surface/26-CONTEXT.md` — `streaming_url/3` must be the AV playback seam; helper layer remains thin and additive
- `.planning/phases/24-domain-model-dsl-extension/24-CONTEXT.md` — `cancelled` variant state and typed AV domain model already locked

### Research references
- `.planning/research/v1.4/SYNTHESIS.md` — Phase 27 scope and locked LiveView/helper direction
- `.planning/research/v1.4/DELIVERY-DX.md` — helper API shape, event vocabulary, cancellation posture, error vocabulary
- `.planning/research/v1.4/LIFECYCLE.md` — variant lifecycle and degraded/cancelled semantics
- `.planning/research/v1.4/FOOTGUNS.md` — failure modes to avoid in AV UX and diagnostics

### Existing code seams
- `lib/rindle/html.ex` — current `picture_tag/3` thin-helper philosophy and attribute pass-through behavior
- `lib/rindle/live_view.ex` — current Phoenix-facing module where subscription helpers should land
- `lib/rindle/delivery.ex` — `streaming_url/3`, `variant_url/4`, and delivery authorization policy
- `lib/rindle/workers/process_variant.ex` — current PubSub broadcast seam and AV progress behavior
- `lib/rindle/error.ex` — current message rendering surface to extend for frozen AV error text
- `test/rindle/html_test.exs` — helper contract precedent
- `test/rindle/live_view_test.exs` — LiveView public-API contract precedent
- `test/rindle/delivery_test.exs` — delivery and streaming-url contract precedent
- `test/rindle/contracts/telemetry_contract_test.exs` — public contract locking precedent
- `test/rindle/api_surface_boundary_test.exs` — public module/function visibility expectations
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle.HTML.picture_tag/3` already provides the core helper pattern: preserve
  caller order, skip non-ready variants, and pass through HTML attrs.
- `Rindle.Delivery.streaming_url/3` already exists as the AV-friendly playback
  seam introduced in Phase 26.
- `Rindle.Workers.ProcessVariant` already broadcasts variant/asset progress on
  PubSub topics, giving Phase 27 a concrete integration point instead of a greenfield design.
- `Rindle.LiveView` is already the Phoenix-facing module for upload ergonomics,
  so progress subscription naturally belongs there.

### Established Patterns
- Public APIs are additive rather than replacing existing return shapes.
- Phoenix-facing helpers stay thin and explicit rather than embedding policy or
  heavy abstraction.
- Delivery concerns stay in `Rindle.Delivery`; HTML helpers should consume them,
  not reinvent authorization or URL policy.
- Worker/internal message shapes may exist, but the public contract is defined
  at the facade/helper layer and locked by tests.

### Integration Points
- `lib/rindle/html.ex` will gain `video_tag/3` and `audio_tag/3` alongside the
  existing `picture_tag/3`.
- `lib/rindle/live_view.ex` will gain subscription helpers that wrap PubSub
  topics and surface public event tuples for `handle_info/2`.
- `lib/rindle.ex` will likely expose the public `cancel_processing/1` facade.
- `lib/rindle/workers/process_variant.ex` and related processing code will need
  to feed the public event contract and support cancellation end-to-end.
- `lib/rindle/error.ex` will become a public-contract hotspot because Phase 27
  freezes exact AV error messages.
</code_context>

<deferred>
## Deferred Ideas

- Caption/subtitle variant delivery and actual `<track>` rendering
- Manifest-aware helper behavior for HLS / DASH providers
- Per-variant public cancellation controls
- Bundled LiveView UI components for upload/progress widgets

These are intentionally out of scope for Phase 27.
</deferred>

---

*Phase: 27-html-helpers-liveview-integration*
*Context gathered: 2026-05-05*
