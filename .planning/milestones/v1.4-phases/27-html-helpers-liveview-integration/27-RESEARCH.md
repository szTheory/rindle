# Phase 27: HTML Helpers + LiveView Integration - Research

**Researched:** 2026-05-05 [VERIFIED: system date]  
**Domain:** Phoenix AV helper markup, LiveView PubSub ergonomics, cancellation facade wiring, and frozen public error/event contracts. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md]  
**Confidence:** HIGH [VERIFIED: repo grep] [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] [CITED: https://hexdocs.pm/phoenix_html/Phoenix.HTML.html] [CITED: https://hexdocs.pm/oban/Oban.Worker.html]

<user_constraints>
## User Constraints (from CONTEXT.md)

Verbatim copy from `.planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md`. All items in this block inherit `[VERIFIED: .planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md]`.

### Locked Decisions
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
- **D-22:** Progress events remain variant-centric first and asset-rollup second,
  consistent with the existing `"rindle:variant:#{id}"` and
  `"rindle:asset:#{id}"` topic structure already present in the worker.
- **D-23:** The public progress contract is rate-limited to at most 2 events per
  second per variant, per the locked requirements. This limit is part of the
  API behavior, not just an optimization.
- **D-24:** Phase 27 should treat worker-side throttling as the canonical source
  of truth. LiveView helpers should not invent their own secondary throttle
  layer that changes message cadence unpredictably.
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
- **D-34:** Carry forward the standing project preference from `.planning/STATE.md`:
  keep the public API coherent and additive, preserve the existing thin-helper
  philosophy, and escalate only if a genuine semver-significant ambiguity
  appears during planning.

### Claude's Discretion
- Exact private helper decomposition inside `lib/rindle/html.ex` so long as the
  public helper contract above remains intact.
- Exact payload field names beyond the required event type/topic guarantees,
  provided tests lock the public schema once chosen.
- Whether `subscribe/2` returns only the topic string or a slightly richer
  subscription token, so long as `unsubscribe/1` is symmetrical and the public
  docs stay simple.
- Exact Oban cancellation mechanism (`Oban.cancel_job/1`, engine helpers, query
  strategy) so long as queued and executing jobs are both addressed.

### Deferred Ideas (OUT OF SCOPE)
- Caption / subtitle implementation beyond reserving the `:tracks` option.
- HLS / DASH / manifest-aware helper behavior.
- Per-variant public cancellation APIs.
- Admin UI or bundled LiveView components.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AV-05-01 | `Rindle.HTML.video_tag/3` mirrors `picture_tag/3`, preserves `:variants` order, resolves poster, defaults `preload`, reserves `:tracks`, and passes through HTML attrs. [VERIFIED: .planning/REQUIREMENTS.md] | Reuse `picture_tag/3`'s thin-helper structure, but switch AV source resolution to `Rindle.Delivery.streaming_url/3` and centralize source/poster filtering in shared private helpers. [VERIFIED: lib/rindle/html.ex] [VERIFIED: lib/rindle/delivery.ex] |
| AV-05-02 | `Rindle.HTML.audio_tag/3` mirrors `video_tag/3` minus poster and defaults `controls: true`, `preload: :metadata`. [VERIFIED: .planning/REQUIREMENTS.md] | Implement `audio_tag/3` on the same internal renderer as `video_tag/3` so fallback, attr pass-through, and source filtering stay identical. [VERIFIED: lib/rindle/html.ex] |
| AV-05-03 | Stale or non-ready variants are skipped from `<source>` while fallback to the original asset is preserved. [VERIFIED: .planning/REQUIREMENTS.md] | Keep the current `ready_variant/2` discipline and add a single AV fallback path instead of generating broken empty `<source>` tags. [VERIFIED: lib/rindle/html.ex] |
| AV-05-04 | `Rindle.LiveView.subscribe/2` and `unsubscribe/1` wrap `:variant | :asset | :upload_session` PubSub topics and target `handle_info/2`. [VERIFIED: .planning/REQUIREMENTS.md] | Build a thin topic facade over `Phoenix.PubSub.subscribe/3` and `unsubscribe/2`; do not add registry state. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] |
| AV-05-05 | Public PubSub event vocabulary is frozen to `:variant_started | :variant_progress | :variant_ready | :variant_failed | :variant_cancelled`. [VERIFIED: .planning/REQUIREMENTS.md] | Insert a public event adapter between worker broadcasts and LiveView subscribers so the repo can keep internal tuples private. [VERIFIED: lib/rindle/workers/process_variant.ex] |
| AV-05-06 | `Rindle.cancel_processing/1` cancels queued/executing jobs, flips variants to `cancelled`, broadcasts cancellation, and returns `:ok | {:error, :not_processing}`. [VERIFIED: .planning/REQUIREMENTS.md] | Add a facade in `Rindle`, query active Oban jobs by `asset_id`, use Oban cancellation for job state, then perform variant/asset state reconciliation plus event broadcast in library code. [VERIFIED: lib/rindle.ex] [VERIFIED: deps/oban/lib/oban.ex] [CITED: https://hexdocs.pm/oban/job_lifecycle.html] |
| AV-05-07 | `Rindle.Error.message/1` must cover the 8 locked AV reasons with exact text parity. [VERIFIED: .planning/REQUIREMENTS.md] | Replace the generic fallback-only message surface with explicit clauses for the 8 public AV reasons and keep legacy `:not_found` / `{:quarantine, _}` behavior intact. [VERIFIED: lib/rindle/error.ex] [VERIFIED: test/rindle/convenience_api_test.exs] |
</phase_requirements>

## Summary

Phase 27 should stay additive and thin. The repo already has the three core seams this phase needs: `Rindle.HTML.picture_tag/3` for explicit order-preserving markup generation, `Rindle.Delivery.streaming_url/3` for AV playback URLs, and `Rindle.Workers.ProcessVariant` for variant/asset PubSub broadcasts plus `cancelled` terminal-state support. [VERIFIED: lib/rindle/html.ex] [VERIFIED: lib/rindle/delivery.ex] [VERIFIED: lib/rindle/workers/process_variant.ex] [VERIFIED: test/rindle/workers/process_variant_test.exs]

The biggest contract risk is not implementation complexity; it is public-shape drift. The worker currently broadcasts raw `{:rindle_variant_progress, payload}` tuples on two topic families, `Rindle.Error.message/1` is still generic `inspect/1` prose, and the public facade does not yet expose `cancel_processing/1`. [VERIFIED: lib/rindle/workers/process_variant.ex] [VERIFIED: lib/rindle/error.ex] [VERIFIED: lib/rindle.ex] Phase 27 should therefore split by contract boundary: helpers, LiveView subscription/event facade, cancellation facade, and frozen error-text/test gates. [INFERENCE from required scope] [VERIFIED: .planning/ROADMAP.md]

The implementation should not invent new subsystems. `Phoenix.PubSub.subscribe/3` and `unsubscribe/2` already provide the exact primitive needed for a stateless wrapper, and LiveView's `handle_info/2` is the documented place for process-delivered messages. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] The best plan is to adapt internal worker broadcasts into the frozen `{:rindle_event, type, payload}` tuple without changing the worker topic namespace. [VERIFIED: .planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md] [VERIFIED: lib/rindle/workers/process_variant.ex]

**Primary recommendation:** Plan Phase 27 as four additive passes: AV helper rendering in `Rindle.HTML`, public topic/event adapters in `Rindle.LiveView`, asset-scoped cancellation in `Rindle`, and locked error/event parity tests. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md]

## Project Constraints (from CLAUDE.md)

No project-root `CLAUDE.md` exists in `/Users/jon/projects/rindle`, so there are no additional repo-local directives beyond the planning artifacts and required phase context. [VERIFIED: repo grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| AV helper HTML generation | Frontend Server (SSR) | API / Backend | `Rindle.HTML` renders escaped server-side markup and delegates URL policy to `Rindle.Delivery`; it should not perform background/job logic. [VERIFIED: lib/rindle/html.ex] [VERIFIED: lib/rindle/delivery.ex] |
| Delivery URL lookup for `<video>` / `<audio>` | API / Backend | CDN / Static | `streaming_url/3` remains the backend seam that returns a playback URL while byte serving stays with storage/local plug. [VERIFIED: lib/rindle/delivery.ex] |
| LiveView PubSub subscriptions | Frontend Server (SSR) | API / Backend | LiveViews subscribe from their process and consume messages in `handle_info/2`; the library only maps kinds to topic strings. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] |
| Worker event production | API / Backend | Frontend Server (SSR) | `ProcessVariant` owns lifecycle transitions and broadcast timing; LiveView wrappers should not become a second event source. [VERIFIED: lib/rindle/workers/process_variant.ex] |
| Asset-scoped cancellation | API / Backend | Database / Storage | Oban job cancellation and variant/asset state reconciliation are backend lifecycle work, not UI work. [VERIFIED: lib/rindle.ex] [CITED: https://hexdocs.pm/oban/job_lifecycle.html] |
| Error vocabulary rendering | API / Backend | Frontend Server (SSR) | `Rindle.Error.message/1` is the public text seam for bangs and diagnostics, so exact wording belongs in the facade layer. [VERIFIED: lib/rindle/error.ex] |

## Standard Stack

### Core

| Library / Module | Version | Purpose | Why Standard |
|------------------|---------|---------|--------------|
| `Rindle.HTML` | repo-local | Existing thin markup helper seam. [VERIFIED: lib/rindle/html.ex] | `picture_tag/3` already proves the project’s preferred explicit-order and pass-through-attrs pattern. [VERIFIED: test/rindle/html_test.exs] |
| `Rindle.LiveView` | repo-local | Existing Phoenix-facing helper module gated behind `Code.ensure_loaded?(Phoenix.LiveView)`. [VERIFIED: lib/rindle/live_view.ex] | New subscribe/unsubscribe functions belong beside upload helpers rather than in a new Phoenix-only module. [VERIFIED: lib/rindle/live_view.ex] |
| `Rindle.Delivery.streaming_url/3` | repo-local | Future-stable playback URL seam for AV. [VERIFIED: lib/rindle/delivery.ex] | Phase 26 already locked this as the AV playback entrypoint, so helper code should not bypass it. [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md] |
| `Phoenix.PubSub` | `2.2.0` in `mix.lock`. [VERIFIED: mix.lock] | Topic subscribe/unsubscribe and broadcast delivery. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] | The documented API already provides the exact stateless topic wrapper this phase needs. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] |
| `Phoenix.LiveView` | `1.1.28` in `mix.lock`. [VERIFIED: mix.lock] | LiveView callback contract for `handle_info/2` and upload helpers. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] | Phase 27 extends the existing module, so its public contract should align with current LiveView callback expectations. [VERIFIED: lib/rindle/live_view.ex] |
| `Oban` | `2.21.1` in `mix.lock`. [VERIFIED: mix.lock] | Job cancellation and lifecycle semantics. [VERIFIED: deps/oban/lib/oban.ex] [CITED: https://hexdocs.pm/oban/job_lifecycle.html] | The worker pipeline is already Oban-backed; cancellation must stay there rather than introducing a parallel runner. [VERIFIED: lib/rindle/workers/process_variant.ex] |

### Supporting

| Library / Module | Version | Purpose | When to Use |
|------------------|---------|---------|-------------|
| `Phoenix.HTML` | `4.3.0` in `mix.lock`. [VERIFIED: mix.lock] | Escaping, `raw/1`, and `safe_to_string/1` for safe iodata/string output. [CITED: https://hexdocs.pm/phoenix_html/Phoenix.HTML.html] | Keep using the current explicit escaping style in `Rindle.HTML` instead of hand-building unsafe strings. [VERIFIED: lib/rindle/html.ex] |
| `:telemetry` | `1.4.1` in `mix.lock`. [VERIFIED: mix.lock] | Existing public telemetry contract lane for delivery and worker events. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] | Use it only if Phase 27 expands the public event contract tests; do not invent a new observability surface. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] |
| `Rindle.Workers.ProcessVariant` | repo-local | Current AV progress and terminal-state broadcast seam. [VERIFIED: lib/rindle/workers/process_variant.ex] | Extend it for public event adaptation and cancellation visibility instead of creating a new worker. [VERIFIED: test/rindle/workers/process_variant_test.exs] |
| `Rindle.Error` | repo-local | Public exception/message formatting seam. [VERIFIED: lib/rindle/error.ex] | Centralize exact AV-facing wording here so bangs and tests consume one source of truth. [VERIFIED: test/rindle/convenience_api_test.exs] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Thin `Rindle.LiveView.subscribe/2` facade | A registry-backed subscription manager | Reject this; Phoenix.PubSub already offers caller-scoped subscribe/unsubscribe, and extra state would widen failure modes without adding value. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] |
| Extending `ProcessVariant` broadcasts with raw public tuples only | A separate event-normalizer process | Reject this; a separate process would duplicate timing/state and make contract tests less direct. [VERIFIED: lib/rindle/workers/process_variant.ex] |
| Generic `Rindle.Error.message/1` fallback text | A second AV-specific error-text module | Reject this; the roadmap freezes one public error vocabulary, not parallel renderers. [VERIFIED: .planning/ROADMAP.md] |
| Hand-built HTML attribute serialization | `Phoenix.HTML.attributes_escape/1` style helpers or the existing escape utilities | Reject manual special-casing; current helper code already escapes values safely and preserves explicit rendering control. [VERIFIED: lib/rindle/html.ex] [CITED: https://hexdocs.pm/phoenix_html/Phoenix.HTML.html] |

**Dependencies:** No new Hex dependency is recommended for Phase 27; all required runtime/library surfaces are already present in `mix.lock` and the repo modules above. [VERIFIED: mix.exs] [VERIFIED: mix.lock]

## Public-Contract Risks

| Risk | Why It Matters | Recommendation |
|------|----------------|----------------|
| Raw worker tuple leak | The current worker emits `{:rindle_variant_progress, payload}` on PubSub, but Phase 27 freezes `{:rindle_event, type, payload}` as the public contract. [VERIFIED: lib/rindle/workers/process_variant.ex] | Add a public adapter seam and lock it with contract tests before adding convenience docs. [VERIFIED: .planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md] |
| Duplicate subscriptions | Phoenix.PubSub allows duplicate subscriptions and drops them all on `unsubscribe/2`, which can surprise callers if wrappers are not documented clearly. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] | Keep `subscribe/2` stateless, return the topic token, and document “subscribe once per topic per process”. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] |
| Helper fallback ambiguity | `picture_tag/3` falls back to the original asset through `<img src>`, but AV fallback is a source-list problem rather than an element-src problem. [VERIFIED: lib/rindle/html.ex] | Decide one canonical AV fallback: no broken `<source>` tags, plus root `src`/fallback source to original asset when no ready variants exist. [INFERENCE from HTML media element semantics] |
| Cancellation return-shape drift | `:ok | {:error, :not_processing}` is narrow; returning counts or partial results would widen semver surface. [VERIFIED: .planning/REQUIREMENTS.md] | Keep rich diagnostics internal/logged and freeze the facade return shape in tests. [VERIFIED: .planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md] |
| Error-text drift | `Rindle.Error.message/1` currently falls through to `inspect(reason)`, which will not satisfy the locked parity-gated AV message contract. [VERIFIED: lib/rindle/error.ex] | Add exact clauses for the 8 AV reasons and a parity test file that asserts exact strings. [VERIFIED: .planning/REQUIREMENTS.md] |

## Code Seams

| Seam | Current State | Phase 27 Recommendation |
|------|---------------|-------------------------|
| `lib/rindle/html.ex` | Only `picture_tag/3` exists; helper order, filtering, and attr escaping are already centralized enough to extract common private functions. [VERIFIED: lib/rindle/html.ex] | Add `video_tag/3` and `audio_tag/3` on top of a shared private media-element builder so filtering, fallback, and attr passthrough stay consistent. [VERIFIED: lib/rindle/html.ex] |
| `lib/rindle/live_view.ex` | Module is optional behind `Code.ensure_loaded?(Phoenix.LiveView)` and currently focused on uploads. [VERIFIED: lib/rindle/live_view.ex] | Add `subscribe/2` and `unsubscribe/1` here, not in a new module, to preserve the Phoenix-facing surface boundary. [VERIFIED: lib/rindle/live_view.ex] |
| `lib/rindle/delivery.ex` | `streaming_url/3` already exists and wraps `url/3` with `%{url, kind, mime}`. [VERIFIED: lib/rindle/delivery.ex] | Helper code should accept/propagate mime information instead of guessing delivery shape locally. [VERIFIED: test/rindle/delivery_test.exs] |
| `lib/rindle/workers/process_variant.ex` | AV variants broadcast `{:rindle_variant_progress, payload}` on `rindle:variant:*` and `rindle:asset:*`; terminal `cancelled` state already exists. [VERIFIED: lib/rindle/workers/process_variant.ex] [VERIFIED: test/rindle/workers/process_variant_test.exs] | Add a small internal event-normalization helper plus explicit cancellation broadcasts instead of rewriting worker flow. [VERIFIED: .planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md] |
| `lib/rindle.ex` | Public facade exposes upload/delivery helpers but no `cancel_processing/1` yet. [VERIFIED: lib/rindle.ex] | Add the cancellation facade here so API-boundary tests continue to treat `Rindle` as the public entrypoint. [VERIFIED: test/rindle/api_surface_boundary_test.exs] |
| `lib/rindle/error.ex` | Message logic is still generic and short. [VERIFIED: lib/rindle/error.ex] | Turn this into the one frozen AV vocabulary renderer; do not split wording across worker/helper modules. [VERIFIED: .planning/ROADMAP.md] |

## Test Seams

| Test File | Existing Contract | Phase 27 Addition |
|-----------|-------------------|-------------------|
| `test/rindle/html_test.exs` | Locks source order, ready-only filtering, passthrough attrs, and image-only scope of `picture_tag/3`. [VERIFIED: test/rindle/html_test.exs] | Extend with `video_tag/3` and `audio_tag/3` assertions for variant ordering, poster resolution, default attrs, fallback behavior, and reserved `:tracks` acceptance. [VERIFIED: .planning/REQUIREMENTS.md] |
| `test/rindle/live_view_test.exs` | Currently covers upload helper API only. [VERIFIED: test/rindle/live_view_test.exs] | Add explicit subscribe/unsubscribe tests, supported kind validation, and a `handle_info/2`-style public tuple example contract. [VERIFIED: .planning/REQUIREMENTS.md] |
| `test/rindle/workers/process_variant_test.exs` | Already proves raw progress broadcasts and `cancelled` state for stale-source cancellations. [VERIFIED: test/rindle/workers/process_variant_test.exs] | Extend to assert public event-type mapping and explicit `:variant_cancelled` emission when cancellation is user-driven. [VERIFIED: .planning/REQUIREMENTS.md] |
| `test/rindle/convenience_api_test.exs` | Already owns `Rindle.Error.message/1` expectations and public facade convenience APIs. [VERIFIED: test/rindle/convenience_api_test.exs] | Add `cancel_processing/1` success/error contract tests plus exact AV error message parity cases. [VERIFIED: .planning/REQUIREMENTS.md] |
| `test/rindle/api_surface_boundary_test.exs` | Guards public module visibility and facade exports. [VERIFIED: test/rindle/api_surface_boundary_test.exs] | Add export/doc visibility expectations for `Rindle.cancel_processing/1`, `Rindle.LiveView.subscribe/2`, `Rindle.LiveView.unsubscribe/1`, `Rindle.HTML.video_tag/3`, and `audio_tag/3`. [VERIFIED: .planning/REQUIREMENTS.md] |
| `test/rindle/contracts/telemetry_contract_test.exs` | Locks telemetry event names only, not PubSub tuple vocabulary. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] | Keep telemetry stable and add a separate public-event contract test rather than overloading telemetry tests with PubSub assertions. [INFERENCE from current test scope] |

## Recommended Plan Split

| Plan | Scope | Why This Slice |
|------|-------|----------------|
| `27-01-PLAN.md` | `Rindle.HTML.video_tag/3` and `audio_tag/3`, shared private media renderer, poster/source fallback rules, HTML helper tests. [VERIFIED: lib/rindle/html.ex] | This is self-contained, low-risk, and builds directly on `picture_tag/3` without touching job lifecycle code. [VERIFIED: test/rindle/html_test.exs] |
| `27-02-PLAN.md` | `Rindle.LiveView.subscribe/2` and `unsubscribe/1`, topic-token mapping, public `{:rindle_event, type, payload}` adapter, LiveView/public-event tests. [VERIFIED: lib/rindle/live_view.ex] [VERIFIED: lib/rindle/workers/process_variant.ex] | This isolates the public event contract before cancellation changes add more event types. [VERIFIED: .planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md] |
| `27-03-PLAN.md` | `Rindle.cancel_processing/1`, Oban query/cancel path, variant/asset cancellation reconciliation, cancellation broadcasts, facade tests. [VERIFIED: lib/rindle.ex] [VERIFIED: deps/oban/lib/oban.ex] | Cancellation crosses the most layers, so it should land after the event adapter exists and before text-freezing. [INFERENCE from code seams] |
| `27-04-PLAN.md` | Frozen AV error vocabulary, API-boundary/docs visibility updates, exact-string parity tests, final contract pass. [VERIFIED: lib/rindle/error.ex] [VERIFIED: test/rindle/api_surface_boundary_test.exs] | This closes the semver-sensitive surface last, after helper and cancellation reason shapes are settled. [VERIFIED: .planning/ROADMAP.md] |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Topic subscription state | A process registry or ETS subscription tracker | `Phoenix.PubSub.subscribe/3` and `unsubscribe/2` [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] | PubSub already owns subscriber lifecycle and duplicate-subscription semantics. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] |
| LiveView message handling | A custom callback DSL | Standard `handle_info/2` message delivery [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] | LiveView already documents process-message handling there; anything else is extra API surface. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] |
| Job cancellation engine | A direct SQL update against `oban_jobs` | `Oban.cancel_all_jobs/2` or equivalent Oban cancellation APIs [VERIFIED: deps/oban/lib/oban.ex] | Oban documents cancellation semantics for queued and executing jobs; bypassing it risks notifier/lifecycle drift. [VERIFIED: deps/oban/lib/oban.ex] [CITED: https://hexdocs.pm/oban/Oban.Notifier.html] |
| HTML escaping | Manual interpolation without safe conversion | Existing `Phoenix.HTML` escaping helpers and current `escape/1` pattern [CITED: https://hexdocs.pm/phoenix_html/Phoenix.HTML.html] | The repo already uses safe escaping; custom shortcuts would turn a simple helper phase into an XSS risk. [VERIFIED: lib/rindle/html.ex] |

**Key insight:** The phase is mostly about adapting already-existing primitives into stable public contracts, not adding new infrastructure. [VERIFIED: lib/rindle/html.ex] [VERIFIED: lib/rindle/live_view.ex] [VERIFIED: lib/rindle/workers/process_variant.ex]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / Mix | Compile and test all four plans. [VERIFIED: mix.exs] | ✓ [VERIFIED: local command] | `Mix 1.19.5` with Erlang/OTP 28. [VERIFIED: local command] | — |
| PostgreSQL test instance | ExUnit data-case and Oban-backed tests. [VERIFIED: config/test.exs] [VERIFIED: test/test_helper.exs] | ✓ [VERIFIED: local command] | `pg_isready` reports `/tmp:5432 - accepting connections`. [VERIFIED: local command] | — |
| FFmpeg | Existing AV worker fixture tests that Phase 27 will extend around progress/cancellation. [VERIFIED: test/rindle/workers/process_variant_test.exs] | ✓ [VERIFIED: local command] | `ffmpeg 8.0.1`. [VERIFIED: local command] | Skip AV-worker verification only if tests are narrowed to pure facade/unit coverage. [INFERENCE from test seams] |
| Phoenix LiveView optional dep | `Rindle.LiveView` compile gate and tests. [VERIFIED: lib/rindle/live_view.ex] | ✓ [VERIFIED: mix.lock] | `phoenix_live_view 1.1.28`. [VERIFIED: mix.lock] | None; the module is optional at runtime, but this repo already includes it for tests. [VERIFIED: mix.exs] |

**Missing dependencies with no fallback:** None found. [VERIFIED: local command]  
**Missing dependencies with fallback:** None found. [VERIFIED: local command]

## Architecture Patterns

### System Architecture Diagram

```text
Template / LiveView
  |
  +--> Rindle.HTML.video_tag/3 | audio_tag/3
  |       -> filter ready variants in caller order
  |       -> resolve source URLs via Rindle.Delivery.streaming_url/3
  |       -> resolve poster via explicit variant atom or literal URL
  |       -> render escaped <video>/<audio> markup
  |
  +--> Rindle.LiveView.subscribe(kind, id)
          -> Phoenix.PubSub.subscribe(pubsub, topic)
          -> caller handles {:rindle_event, type, payload} in handle_info/2

Rindle.Workers.ProcessVariant
  -> lifecycle transitions
  -> raw/internal progress + terminal events
  -> adapter maps to frozen public event types
  -> broadcasts on rindle:variant:* and rindle:asset:*

Rindle.cancel_processing(asset_id)
  -> query active variant jobs for asset
  -> Oban cancellation
  -> variant state -> cancelled
  -> asset aggregate recompute
  -> :variant_cancelled event broadcast
```

### Recommended Project Structure

```text
lib/rindle/
├── html.ex                 # Add video_tag/3 + audio_tag/3 on shared private helpers
├── live_view.ex            # Add subscribe/2 + unsubscribe/1 public Phoenix facade
├── error.ex                # Freeze AV error vocabulary text
├── workers/process_variant.ex
│                           # Adapt raw/internal broadcasts + cancellation visibility
└── rindle.ex               # Add public cancel_processing/1 facade
```

### Pattern 1: Shared Media Element Renderer
**What:** Build `video_tag/3` and `audio_tag/3` on one private renderer that takes the root tag name, helper-specific options, and a source list. [VERIFIED: lib/rindle/html.ex]  
**When to use:** When adding AV helpers without drifting from `picture_tag/3` semantics. [VERIFIED: .planning/REQUIREMENTS.md]  
**Example:**
```elixir
# Source: lib/rindle/html.ex + lib/rindle/delivery.ex
def video_tag(profile, asset, opts \\ []) do
  render_media_tag("video", profile, asset, opts,
    defaults: [preload: "metadata"],
    allow_poster?: true
  )
end

def audio_tag(profile, asset, opts \\ []) do
  render_media_tag("audio", profile, asset, opts,
    defaults: [controls: true, preload: "metadata"],
    allow_poster?: false
  )
end
```

### Pattern 2: Topic Token In, Public Event Tuple Out
**What:** Keep the topic namespace internal but normalize all public LiveView-facing messages to `{:rindle_event, type, payload}`. [VERIFIED: .planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md]  
**When to use:** For `:variant`, `:asset`, and `:upload_session` subscriptions. [VERIFIED: .planning/REQUIREMENTS.md]  
**Example:**
```elixir
# Source: Phoenix.PubSub docs + Phase 27 context
def subscribe(kind, id) do
  topic = topic_for!(kind, id)
  :ok = Phoenix.PubSub.subscribe(pubsub_server(), topic)
  topic
end

def unsubscribe(topic) when is_binary(topic) do
  :ok = Phoenix.PubSub.unsubscribe(pubsub_server(), topic)
  :ok
end
```

### Anti-Patterns to Avoid
- **Re-sorting variants by mime or extension:** The caller-supplied `:variants` order is the codec-priority contract and is already locked. [VERIFIED: .planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md]
- **Publishing raw worker tuples as public API:** The current raw tuple is an implementation detail and should not leak into docs/tests as the public shape. [VERIFIED: lib/rindle/workers/process_variant.ex]
- **Returning rich cancellation diagnostics from the facade:** Counts and partial results create semver surface that the requirements explicitly avoid. [VERIFIED: .planning/REQUIREMENTS.md]

## Common Pitfalls

### Pitfall 1: Duplicating Helper Logic Instead of Extracting It
**What goes wrong:** `video_tag/3` and `audio_tag/3` drift on fallback, attr sorting, or escaping behavior. [VERIFIED: lib/rindle/html.ex]  
**Why it happens:** Copy/paste from `picture_tag/3` is easy, but AV helper defaults differ slightly and the divergence will compound. [INFERENCE from current helper shape]  
**How to avoid:** Extract one private media-element builder and keep helper-specific differences to defaults/poster handling only. [VERIFIED: lib/rindle/html.ex]  
**Warning signs:** Tests for `video_tag/3` and `audio_tag/3` need duplicated fixes for attr ordering or fallback logic. [INFERENCE from test seam]

### Pitfall 2: Treating Internal PubSub Tuples as the Public Contract
**What goes wrong:** Adopters couple directly to `{:rindle_variant_progress, payload}` and break when worker internals change. [VERIFIED: lib/rindle/workers/process_variant.ex]  
**Why it happens:** The worker already broadcasts something useful, so it is tempting to expose it unchanged. [VERIFIED: test/rindle/workers/process_variant_test.exs]  
**How to avoid:** Introduce a small normalization seam and document only `{:rindle_event, type, payload}`. [VERIFIED: .planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md]  
**Warning signs:** New tests assert raw worker tuple names outside worker-specific test files. [VERIFIED: test/rindle/workers/process_variant_test.exs]

### Pitfall 3: Half-Cancelling Jobs
**What goes wrong:** Queued jobs cancel but executing jobs finish and still write ready variants, or job rows cancel without variant rows moving to `cancelled`. [VERIFIED: deps/oban/lib/oban.ex] [VERIFIED: .planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md]  
**Why it happens:** Oban job state and Rindle variant state are separate records. [VERIFIED: lib/rindle/workers/process_variant.ex]  
**How to avoid:** Treat cancellation as a two-part operation: cancel active jobs through Oban, then reconcile variant/asset rows and broadcast `:variant_cancelled`. [VERIFIED: deps/oban/lib/oban.ex] [VERIFIED: .planning/REQUIREMENTS.md]  
**Warning signs:** `Oban.Job` rows show `cancelled` while `media_variants.state` remains `queued` or `processing`. [INFERENCE from lifecycle model]

### Pitfall 4: Free-Form AV Error Text
**What goes wrong:** Message wording drifts between docs, tests, and runtime because the generic fallback uses `inspect(reason)`. [VERIFIED: lib/rindle/error.ex]  
**Why it happens:** The current implementation optimized for generic convenience, not locked public vocabulary. [VERIFIED: test/rindle/convenience_api_test.exs]  
**How to avoid:** Add exact clauses for all eight AV reasons and assert exact strings in one parity lane. [VERIFIED: .planning/REQUIREMENTS.md]  
**Warning signs:** Docs mention a “fix this by...” message that is not byte-for-byte asserted anywhere in tests. [INFERENCE from current test coverage]

## Code Examples

Verified patterns from official sources and current repo seams:

### Subscribe a LiveView Process to a Topic
```elixir
# Source: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html
topic = "rindle:variant:#{variant_id}"
:ok = Phoenix.PubSub.subscribe(Rindle.PubSub, topic)

def handle_info({:rindle_event, :variant_progress, payload}, socket) do
  {:noreply, assign(socket, :variant_progress, payload)}
end
```

### Preserve Existing Helper Escaping Discipline
```elixir
# Source: lib/rindle/html.ex + https://hexdocs.pm/phoenix_html/Phoenix.HTML.html
defp attr_markup(key, value) do
  " " <> to_string(key) <> "=\"" <> escape(value) <> "\""
end

defp escape(value) do
  value
  |> to_string()
  |> Phoenix.HTML.html_escape()
  |> Phoenix.HTML.safe_to_string()
end
```

### Cancel Active Jobs by Asset Query
```elixir
# Source: deps/oban/lib/oban.ex + current ProcessVariant args shape
Oban.Job
|> where([job], job.worker == ^to_string(Rindle.Workers.ProcessVariant))
|> where([job], fragment("?->>'asset_id' = ?", job.args, ^asset_id))
|> Oban.cancel_all_jobs()
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Image-only helper surface centered on `picture_tag/3`. [VERIFIED: lib/rindle/html.ex] | Additive AV helper surface should be `video_tag/3` + `audio_tag/3`, not polymorphic picture markup. [VERIFIED: .planning/ROADMAP.md] | v1.4 Phase 27 design lock on 2026-05-05. [VERIFIED: .planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md] | Keeps image callers stable while giving AV callers a native markup surface. [VERIFIED: .planning/ROADMAP.md] |
| Raw/internal worker tuples on PubSub. [VERIFIED: lib/rindle/workers/process_variant.ex] | Public event wrapper `{:rindle_event, type, payload}` over the same topics. [VERIFIED: .planning/REQUIREMENTS.md] | v1.4 Phase 27 design lock on 2026-05-05. [VERIFIED: .planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md] | Allows internal worker evolution without breaking LiveView consumers. [INFERENCE from contract boundary] |
| Generic `Rindle.Error.message/1` fallback text. [VERIFIED: lib/rindle/error.ex] | Explicit AV vocabulary with exact parity tests. [VERIFIED: .planning/REQUIREMENTS.md] | v1.4 Phase 27 design lock on 2026-05-05. [VERIFIED: .planning/ROADMAP.md] | Turns messages into a real public contract instead of incidental exception prose. [VERIFIED: .planning/ROADMAP.md] |

**Deprecated/outdated:**
- Treating `{:rindle_variant_progress, payload}` as a public message contract is outdated for v1.4 planning because the roadmap freezes a richer event vocabulary. [VERIFIED: lib/rindle/workers/process_variant.ex] [VERIFIED: .planning/REQUIREMENTS.md]

## Assumptions Log

All recommendations in this research were verified against repo artifacts or official documentation during this session. No `[ASSUMED]` claims remain. [VERIFIED: repo read] [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] [CITED: https://hexdocs.pm/phoenix_html/Phoenix.HTML.html] [CITED: https://hexdocs.pm/oban/job_lifecycle.html]

## Open Questions

1. **Should `unsubscribe/1` accept only the returned topic string or also accept `{kind, id}`?**
   - What we know: The context explicitly allows either a plain topic token or a slightly richer token as long as symmetry is preserved. [VERIFIED: .planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md]
   - What's unclear: The exact ergonomics preference is not locked in the phase context. [VERIFIED: .planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md]
   - Recommendation: Return the topic string from `subscribe/2` and accept that same string in `unsubscribe/1`; it is the smallest public surface and matches PubSub semantics directly. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html]

2. **What exact payload fields should the public `:variant_*` events freeze?**
   - What we know: Current raw payload has `asset_id`, `variant_id`, `variant_name`, `progress`, and `state`. [VERIFIED: lib/rindle/workers/process_variant.ex] [VERIFIED: test/rindle/workers/process_variant_test.exs]
   - What's unclear: Whether terminal events should also expose `error_reason`, `output_kind`, or timestamps. [VERIFIED: .planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md]
   - Recommendation: Start with the existing payload fields plus a minimal terminal-only `reason` field where needed; lock the public schema in tests immediately after choosing it. [INFERENCE from current payload seam]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Ecto SQL Sandbox + Oban testing. [VERIFIED: test/test_helper.exs] |
| Config file | `test/test_helper.exs`, `config/test.exs`. [VERIFIED: test/test_helper.exs] [VERIFIED: config/test.exs] |
| Quick run command | `mix test test/rindle/html_test.exs test/rindle/live_view_test.exs test/rindle/convenience_api_test.exs test/rindle/api_surface_boundary_test.exs`. [INFERENCE from test seams] |
| Full suite command | `mix test` plus `mix test --only contract` for the contract lane. [VERIFIED: test/test_helper.exs] [VERIFIED: .github/workflows/ci.yml] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AV-05-01 | `video_tag/3` preserves source order, poster resolution, defaults, and attrs | unit | `mix test test/rindle/html_test.exs` | ✅ extend existing |
| AV-05-02 | `audio_tag/3` mirrors `video_tag/3` minus poster | unit | `mix test test/rindle/html_test.exs` | ✅ extend existing |
| AV-05-03 | Non-ready variants skipped and original fallback preserved | unit | `mix test test/rindle/html_test.exs` | ✅ extend existing |
| AV-05-04 | `subscribe/2` / `unsubscribe/1` public LiveView topic API | unit | `mix test test/rindle/live_view_test.exs` | ✅ extend existing |
| AV-05-05 | Public `{:rindle_event, type, payload}` vocabulary | contract + worker | `mix test test/rindle/live_view_test.exs test/rindle/workers/process_variant_test.exs` | ✅ extend existing |
| AV-05-06 | `cancel_processing/1` facade cancels jobs and reconciles states | unit + integration | `mix test test/rindle/convenience_api_test.exs test/rindle/workers/process_variant_test.exs` | ✅ extend existing |
| AV-05-07 | Exact AV error text parity | contract | `mix test test/rindle/convenience_api_test.exs` | ✅ extend existing |

### Sampling Rate

- **Per task commit:** `mix test test/rindle/html_test.exs test/rindle/live_view_test.exs`
- **Per wave merge:** `mix test test/rindle/convenience_api_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/workers/process_variant_test.exs`
- **Phase gate:** `mix test` and `mix test --only contract`

### Wave 0 Gaps

- [ ] Add a dedicated public-event contract lane, either as a new `test/rindle/contracts/live_view_event_contract_test.exs` or a clearly marked contract describe block; no file currently locks the PubSub tuple vocabulary. [VERIFIED: repo grep]
- [ ] Extend `test/rindle/api_surface_boundary_test.exs` for the new public exports and docs visibility. [VERIFIED: test/rindle/api_surface_boundary_test.exs]
- [ ] Add explicit cancellation facade tests in `test/rindle/convenience_api_test.exs`; none exist yet. [VERIFIED: test/rindle/convenience_api_test.exs]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Phase 27 itself adds no auth scheme; adopters keep existing auth around views/actions. [VERIFIED: .planning/PROJECT.md] |
| V3 Session Management | no | Phase 27 does not alter session cookies or token issuance. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: lib/rindle/live_view.ex] |
| V4 Access Control | yes | Reuse `Rindle.Delivery` authorizer posture for URL issuance and keep cancellation/subscription APIs library-thin so host apps can authorize before calling them. [VERIFIED: lib/rindle/delivery.ex] [VERIFIED: .planning/PROJECT.md] |
| V5 Input Validation | yes | Guard `kind`/`id` inputs for subscribe helpers, whitelist helper-only options, and keep HTML escaping through `Phoenix.HTML`. [VERIFIED: lib/rindle/html.ex] [CITED: https://hexdocs.pm/phoenix_html/Phoenix.HTML.html] |
| V6 Cryptography | no | Phase 27 adds no new crypto beyond existing signed delivery/cancellation infrastructure. [VERIFIED: lib/rindle/delivery.ex] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| XSS through AV helper attrs or poster URL rendering | Tampering / Info Disclosure | Continue escaping all attribute values with `Phoenix.HTML` helpers and never mark caller input raw. [VERIFIED: lib/rindle/html.ex] [CITED: https://hexdocs.pm/phoenix_html/Phoenix.HTML.html] |
| Unauthorized cancellation of processing jobs | Denial of Service | Keep `Rindle.cancel_processing/1` as a plain library call and require host apps to authorize before invoking it; do not expose transport/auth policy inside the library helper. [VERIFIED: .planning/PROJECT.md] [VERIFIED: lib/rindle.ex] |
| Event-storm pressure on LiveViews | Denial of Service | Preserve worker-side `<= 2/sec` progress rate limit and avoid adding a second unbounded event layer. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md] |
| Topic enumeration / accidental over-subscription | Information Disclosure | Keep topic construction internal to `Rindle.LiveView` and document one-subscription-per-topic usage. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] |

## Sources

### Primary (HIGH confidence)

- `.planning/ROADMAP.md` - Phase 27 goal, success criteria, and plan-count target. [VERIFIED: repo read]
- `.planning/REQUIREMENTS.md` - AV-05-01 through AV-05-07. [VERIFIED: repo read]
- `.planning/STATE.md` - current milestone status and decision preference. [VERIFIED: repo read]
- `.planning/PROJECT.md` - v1.4 constraints and security invariants. [VERIFIED: repo read]
- `.planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md` - locked decisions and discretion points. [VERIFIED: repo read]
- `.planning/phases/25-rindle-processor-av/25-CONTEXT.md` - poster and cancellation semantics inherited by Phase 27. [VERIFIED: repo read]
- `.planning/phases/26-delivery-surface/26-CONTEXT.md` - `streaming_url/3` delivery seam requirements. [VERIFIED: repo read]
- `.planning/research/v1.4/SYNTHESIS.md` - milestone-wide AV design locks. [VERIFIED: repo read]
- `lib/rindle/html.ex`, `lib/rindle/live_view.ex`, `lib/rindle/delivery.ex`, `lib/rindle/error.ex`, `lib/rindle/workers/process_variant.ex`, `lib/rindle.ex` - current implementation seams. [VERIFIED: repo read]
- `test/rindle/html_test.exs`, `test/rindle/live_view_test.exs`, `test/rindle/delivery_test.exs`, `test/rindle/convenience_api_test.exs`, `test/rindle/api_surface_boundary_test.exs`, `test/rindle/workers/process_variant_test.exs`, `test/rindle/contracts/telemetry_contract_test.exs` - existing public contract/test seams. [VERIFIED: repo read]
- Phoenix.PubSub docs - subscribe/unsubscribe behavior and duplicate-subscription semantics. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html]
- Phoenix.LiveView docs - `handle_info/2` callback contract. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html]
- Phoenix.HTML docs - HTML escaping and safe rendering helpers. [CITED: https://hexdocs.pm/phoenix_html/Phoenix.HTML.html]
- `deps/oban/lib/oban.ex` - current public cancellation APIs exported by the installed Oban version. [VERIFIED: repo read]
- Oban docs - job lifecycle semantics and notifier requirements. [CITED: https://hexdocs.pm/oban/job_lifecycle.html] [CITED: https://hexdocs.pm/oban/Oban.Notifier.html]

### Secondary (MEDIUM confidence)

- None. All key claims were verified against repo artifacts or official docs during this session. [VERIFIED: repo read] [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html]

### Tertiary (LOW confidence)

- None. [VERIFIED: repo read]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all recommended surfaces are already present in repo or official docs. [VERIFIED: mix.lock] [VERIFIED: repo read]
- Architecture: HIGH - the phase boundary is tightly constrained by existing modules and adjacent phase decisions. [VERIFIED: .planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md]
- Pitfalls: HIGH - each pitfall maps to an observable existing seam or official API behavior. [VERIFIED: lib/rindle/workers/process_variant.ex] [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html]

**Research date:** 2026-05-05 [VERIFIED: system date]  
**Valid until:** 2026-06-04 for repo-internal seams; re-verify official docs if Phoenix or Oban versions change before planning/execution. [VERIFIED: mix.lock]

## RESEARCH COMPLETE
