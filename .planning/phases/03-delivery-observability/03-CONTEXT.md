# Phase 3: Delivery & Observability - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Secure delivery via signed URLs (private by default), locked telemetry public contract, and a responsive image helper for Phoenix templates.

</domain>

<decisions>
## Implementation Decisions

### Delivery policy boundary
- **D-01:** `Rindle.url/2` is the policy boundary. Profiles default to signed delivery; `public: true` is an explicit opt-in for unsigned URLs.
- **D-02:** `Rindle.Authorizer.authorize/3` stays in the delivery path before URL issuance; authorization failure blocks both public and signed delivery.
- **D-03:** Storage adapters remain primitives/capability providers. They do not decide private/public policy; the delivery layer does.

### Variant fallback rules
- **D-04:** Non-ready variants (`planned`, `queued`, `processing`, `missing`, `failed`) fall back to the original asset URL rather than raising.
- **D-05:** `stale` variants may serve stale only when stale policy says so; otherwise they also fall back to the original.
- **D-06:** `picture_tag/3` must never render a broken variant URL in HTML. It only emits ready variants in `srcset`/`<source>` and uses the original asset or placeholder for fallback.

### Telemetry contract
- **D-07:** Lock the roadmap’s public event family exactly as the contract surface for this phase: upload start, asset state change, variant state change, signed delivery, and cleanup run.
- **D-08:** Measurements stay numeric only; state names and identity live in metadata. `profile` and `adapter` are required metadata fields for every public event.
- **D-09:** Any extra instrumentation stays internal and does not expand the public contract without a later version decision.

### Responsive image helper
- **D-10:** `Rindle.HTML.picture_tag/3` is a thin HEEx-style helper, not an image processor.
- **D-11:** Callers pass explicit variant/source ordering; the helper does not invent breakpoints or resize rules.
- **D-12:** The placeholder option is presentational only and must not trigger processing or delivery side effects.

### the agent's Discretion
- Exact internal module split for delivery, telemetry, and HTML helpers.
- Exact placeholder styling and markup details.
- Whether to cache resolved delivery URLs or variant lookups in phase 3.

</decisions>

<specifics>
## Specific Ideas

- Keep delivery policy out of adapters.
- Prefer safe fallbacks over broken images.
- Keep the telemetry contract small and stable.
- Make the helper easy to use from Phoenix templates without hiding behavior.

</specifics>

<canonical_refs>
## Canonical References

### Phase scope and locked requirements
- `.planning/ROADMAP.md` — Phase 3 goal, success criteria, and required deliverables.
- `.planning/REQUIREMENTS.md` — DELV/TEL/VIEW requirements and public contract constraints.
- `.planning/PROJECT.md` — private-by-default posture, public opt-in, and telemetry contract stance.
- `.planning/STATE.md` — current milestone state and prior architectural constraints.

### Prior decisions and research
- `.planning/phases/01-foundation/01-CONTEXT.md` — authorizer boundary, stale policy primitives, storage capability conventions.
- `.planning/research/SUMMARY.md` — phase 3 rationale and delivery/observability scope.
- `.planning/research/ARCHITECTURE.md` — proposed module boundaries for delivery, telemetry, and HTML helpers.
- `.planning/research/PITFALLS.md` — signed URL, telemetry, and image-helper footguns to avoid.
- `.planning/research/FEATURES.md` — phase 3 value framing and ergonomic goals.

### Existing code surface
- `lib/rindle.ex` — current URL/storage facade.
- `lib/rindle/authorizer.ex` — delivery authorization hook.
- `lib/rindle/storage/s3.ex` and `lib/rindle/storage/local.ex` — adapter delivery primitives.
- `lib/rindle/domain/stale_policy.ex` — reusable stale-serving policy helpers.
- `lib/rindle/domain/media_variant.ex` — queryable variant state for fallback decisions.
- `lib/rindle/profile.ex` — profile DSL pattern for phase-scoped delivery options.
- `lib/rindle/live_view.ex` — existing Phoenix integration style.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle.Authorizer`: ready-made policy hook for delivery authorization.
- `Rindle.Domain.StalePolicy`: existing stale/fallback helper semantics that can feed delivery behavior.
- `Rindle.Storage.S3` and `Rindle.Storage.Local`: URL-generation primitives to build on.
- `Rindle.Profile`: compile-time profile DSL that can carry delivery options such as public/private policy.
- `Rindle.Domain.MediaVariant`: variant state is already queryable, which is enough to drive safe fallback logic.

### Established Patterns
- Profile-scoped configuration is already the norm.
- Public APIs return tagged tuples and avoid hidden raises.
- Queryable DB state is preferred over inferred runtime state.
- The library favors thin facades over monolithic public modules.

### Integration Points
- Delivery helpers should hang off the current `Rindle` facade and profile DSL.
- Telemetry should instrument the existing upload, variant, and delivery boundaries without changing the underlying state machines.
- `picture_tag/3` should resolve variant URLs through the delivery layer, not bypass it.

</code_context>

<deferred>
## Deferred Ideas

- None — the phase discussion stayed within scope.

</deferred>

---

*Phase: 03-delivery-observability*
*Context gathered: 2026-04-25*
