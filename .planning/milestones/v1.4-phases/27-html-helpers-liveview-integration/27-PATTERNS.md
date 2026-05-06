# Phase 27: HTML Helpers + LiveView Integration - Pattern Map

**Mapped:** 2026-05-05
**Files analyzed:** 9
**Analogs found:** 6 / 6

## File Classification

| New/Modified File | Role | Closest Analog | Match quality |
|---|---|---|---|
| `lib/rindle/html.ex` | thin Phoenix helper | self (`picture_tag/3`) | exact |
| `lib/rindle/live_view.ex` | thin Phoenix integration helper | self (`allow_upload/4`, `consume_uploaded_entries/3`) | exact |
| `lib/rindle/workers/process_variant.ex` | stateful worker + public event seam | self + existing AV progress tests | exact |
| `lib/rindle.ex` | public façade | self | exact |
| `lib/rindle/error.ex` | public contract copy surface | self | exact |
| `test/rindle/html_test.exs` / `test/rindle/live_view_test.exs` / `test/rindle/workers/process_variant_test.exs` | regression and contract tests | self | exact |

## Pattern Assignments

### `lib/rindle/html.ex`

**Analog:** existing `picture_tag/3`

Mirror these patterns:

- explicit root-function shape: `@spec helper(module(), map(), keyword()) :: Phoenix.HTML.safe()`
- caller-order preservation for `:variants`
- skip-on-non-ready instead of rendering broken URLs
- literal pass-through of unconsumed HTML attrs

Planning implication: `video_tag/3` and `audio_tag/3` should be added beside `picture_tag/3`, not behind a generic polymorphic media renderer.

### `lib/rindle/live_view.ex`

**Analog:** existing upload helpers

Mirror these patterns:

- public wrapper stays thin and documented
- helper delegates to lower-level runtime seams rather than owning process state
- docs include realistic LiveView usage snippets and are tested in `test/rindle/live_view_test.exs`

Planning implication: `subscribe/2` and `unsubscribe/1` should be small and explicit, with any scope-to-topic mapping kept private.

### `lib/rindle/workers/process_variant.ex`

**Analog:** current AV progress broadcasting

Mirror these patterns:

- worker remains the source of lifecycle truth
- topic fan-out happens in one place
- state transitions flow through existing FSM/aggregate recompute paths

Planning implication: public `{:rindle_event, ...}` messages should be produced here, not in a LiveView-side adapter layer.

### `lib/rindle.ex`

**Analog:** additive public façades such as `verify_completion/2`

Mirror these patterns:

- narrow return contracts
- top-level docs on public functions
- internal orchestration hidden behind the façade

Planning implication: `cancel_processing/1` belongs on `Rindle`, but any Oban query/cancellation service should remain internal.

### `lib/rindle/error.ex`

**Analog:** existing direct message branches

Mirror these patterns:

- exact branch-per-reason rendering
- no second public error-rendering module
- tests should assert byte-for-byte output

Planning implication: freeze the AV vocabulary by extending `Rindle.Error.message/1`, not by creating a parallel formatter.

## Recommended Ownership By Plan

### Plan 01

- Primary files: `lib/rindle/html.ex`, `test/rindle/html_test.exs`, `test/rindle/api_surface_boundary_test.exs`
- Reason: isolate template helper semantics and root-element markup from worker/runtime changes

### Plan 02

- Primary files: `lib/rindle/live_view.ex`, `lib/rindle/workers/process_variant.ex`, `test/rindle/live_view_test.exs`, `test/rindle/workers/process_variant_test.exs`
- Reason: keep the public event tuple and helper subscription story together

### Plan 03

- Primary files: `lib/rindle.ex`, internal cancellation helper/service, `lib/rindle/workers/process_variant.ex`, cancellation-focused tests
- Reason: cancellation crosses façade, Oban, and worker lifecycle, but should reuse the Plan 02 event contract

### Plan 04

- Primary files: `lib/rindle/error.ex`, `lib/rindle/delivery.ex`, `lib/rindle/delivery/local_plug.ex`, contract tests
- Reason: error vocabulary closure needs to normalize producers and freeze exact message text after behavior lands

## Anti-Patterns To Avoid

- Do not introduce a generic media-rendering abstraction that collapses `picture_tag/3`, `video_tag/3`, and `audio_tag/3` into one large helper.
- Do not make `Rindle.LiveView` a registry, GenServer, or event transformer layer. Subscription must stay thin.
- Do not ask LiveView subscribers to parse private tuples like `{:rindle_variant_progress, payload}` once the public contract exists.
- Do not expose variant-scoped public cancellation just because worker internals identify jobs by variant.
- Do not spread AV message copy across multiple modules; `Rindle.Error.message/1` is the public source of truth.
