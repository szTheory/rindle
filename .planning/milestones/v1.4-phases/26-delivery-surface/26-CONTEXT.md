# Phase 26: Delivery Surface - Context

**Gathered:** 2026-05-05 (delegated research synthesis)
**Status:** Ready for planning

<domain>
## Phase Boundary

Adopters keep production signed-redirect delivery for media assets and gain a
range-aware local-development playback path for `Rindle.Storage.Local`, while
Rindle reserves a stable `streaming_url/3` surface so future streaming-provider
adapters can land without template churn.

In scope:
- Additive `Rindle.Delivery.streaming_url/3` API surface for progressive vs
  future manifest-style delivery
- `Rindle.Delivery.LocalPlug` for local, range-aware browser playback parity
- Safe delivery-time filename / `Content-Disposition` posture
- Signed-URL TTL guidance and additive delivery telemetry for the new surface

Out of scope:
- Bundled streaming-provider adapters (Mux / Cloudflare Stream / Transloadit)
- Per-content delivery DSL redesign
- Broad delivery metadata object redesign
- Production proxy streaming posture for non-local adapters
</domain>

<decisions>
## Implementation Decisions

### Streaming URL Surface
- **D-01:** Add `Rindle.Delivery.streaming_url/3` as a separate additive public
  function. Do not overload `url/3` with streaming flags or alternate return
  shapes.
- **D-02:** In v1.4, `streaming_url/3` delegates to `url/3` and returns
  `{:ok, %{url: url, kind: :progressive, mime: mime}}`.
- **D-03:** Keep `url/3` as the stable plain delivery primitive returning
  `{:ok, binary}`. Existing image/private/public delivery call sites must not
  churn.
- **D-04:** Do not introduce a provider/protocol abstraction in Phase 26 beyond
  reserving the streaming surface. Real provider behaviour can land once an
  actual non-progressive adapter exists and can prove the abstraction.
- **D-05:** `streaming_url/3` must share the same authorization, TTL, and error
  behaviour as `url/3` so the only public difference is the return shape.
- **D-06:** For v1.4, callers may pass `:mime` explicitly; otherwise the
  default progressive fallback may be `"video/mp4"`. Phase 27 helpers should
  pass the mime they already know from the variant/profile context rather than
  relying on guesswork inside delivery.

### Local Development Delivery
- **D-07:** Ship a narrow core `Rindle.Delivery.LocalPlug` in the main library.
  Do not extend `Rindle.Storage.Local.url/2` into an HTTP-routing abstraction,
  and do not split the plug into a separate package.
- **D-08:** `LocalPlug` is dev-parity-only by default and must say so loudly in
  `@moduledoc`. Production signed redirect remains the normative posture.
- **D-09:** `LocalPlug` verifies a signed token over `key + expiry +
  actor_subject`, resolves a path under the configured local root, and serves
  the file with `Plug.Conn.send_file/5`.
- **D-10:** Support single-range `Range:` requests only. Multi-range and
  unparseable `Range` headers fall back to `200 + full body` per the locked
  Phase 26 requirements.
- **D-11:** `LocalPlug` must fail fast at init/boot if mounted against any
  adapter other than `Rindle.Storage.Local`.
- **D-12:** Path handling in `LocalPlug` must validate the resolved path stays
  under the configured local root; no path-traversal-by-key allowance.

### Download Filenames and Content-Disposition
- **D-13:** Delivery-time download behaviour is explicit, not inferred from
  container metadata. Public API should accept caller intent (`filename`,
  `disposition` or equivalent delivery opts), and the library sanitizes and
  encodes it.
- **D-14:** Container metadata and tags are never a trusted source for
  download filenames. This follows the v1.4 security invariant that container
  metadata is untrusted UGC end-to-end.
- **D-15:** When Rindle emits `Content-Disposition`, it uses RFC 5987 /
  `filename*=` encoding with a sanitized basename.
- **D-16:** If a caller requests attachment-style delivery but omits a
  filename, a narrow internal fallback may derive one from trusted app-provided
  context or sanitized storage/upload naming. Raw storage keys must never be the
  preferred public-facing naming strategy.
- **D-17:** The same filename/disposition policy should work across both
  `LocalPlug` responses and signed-redirect adapter flows so adopters do not
  learn two delivery models.

### TTL and Telemetry
- **D-18:** Keep the existing single profile-level
  `signed_url_ttl_seconds` policy surface in code for v1.4. Do not add
  per-content TTL config to the profile DSL in this phase.
- **D-19:** Document per-content TTL guidance only:
  image `900s`, audio `3600s`, video VOD `7200s`, and long-form playback should
  use a refresh strategy at the adopter layer.
- **D-20:** The library should continue to steer adopters toward separate
  profiles when materially different delivery policies are needed, rather than
  widening the delivery DSL prematurely.
- **D-21:** Preserve existing `[:rindle, :delivery, :signed]` telemetry and add
  `[:rindle, :delivery, :streaming, :resolved]` for the new streaming API seam.
- **D-22:** Keep `[:rindle, :delivery, :range_request]` because the locked
  Phase 26 requirements require it, but scope it narrowly to
  `Rindle.Delivery.LocalPlug`. Treat it as a local/dev-parity signal, not the
  primary production delivery KPI.

### Decision-Making Preference
- **D-23:** Reinforce the standing project preference from `.planning/STATE.md`:
  downstream agents should front-load research, make coherent defaults, and
  escalate only for very high-impact decisions (public semver reshapes,
  destructive data/ops, security/compliance, or similarly irreversible moves).

### the agent's Discretion
- Exact option names/arity for `streaming_url/3` and delivery-time filename
  opts, so long as the public semantics above remain intact
- Whether to keep existing request-time `expires_in` override behaviour as an
  undocumented escape hatch vs document it narrowly
- Precise `LocalPlug` route shape, token serializer details, and helper wiring
  in Phase 27
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source of truth
- `.planning/ROADMAP.md` — Phase 26 goal, requirements, success criteria
- `.planning/REQUIREMENTS.md` — AV-04-01 through AV-04-08
- `.planning/PROJECT.md` — v1.4 delivery posture, security invariants,
  out-of-scope boundaries
- `.planning/STATE.md` — current milestone state and decision-making preference

### v1.4 research
- `.planning/research/v1.4/SYNTHESIS.md` — locked delivery-surface direction
- `.planning/research/v1.4/DELIVERY-DX.md` — local plug, streaming surface,
  TTL guidance, telemetry vocabulary
- `.planning/research/v1.4/FOOTGUNS.md` — filename/content-disposition and
  delivery-surface footguns

### Prior phase decisions
- `.planning/phases/24-domain-model-dsl-extension/24-CONTEXT.md` — `:kind` /
  `:output_kind`, probe trust model, metadata sanitization posture
- `.planning/phases/25-rindle-processor-av/25-CONTEXT.md` — explicit poster /
  waveform / AV delivery expectations Phase 26 must preserve

### Existing code seams
- `lib/rindle/delivery.ex` — current delivery API and telemetry shape
- `lib/rindle/storage/local.ex` — local storage semantics and capability limits
- `lib/rindle/storage/capabilities.ex` — adapter capability pattern
- `lib/rindle/profile.ex` — profile policy surface
- `lib/rindle/html.ex` — thin helper philosophy and current URL expectations
- `lib/rindle/live_view.ex` — current Phoenix-facing integration style
- `test/rindle/delivery_test.exs` — delivery contract coverage
- `test/rindle/html_test.exs` — helper contract coverage
- `test/rindle/contracts/telemetry_contract_test.exs` — telemetry public-contract precedent
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle.Delivery` already centralizes authorization, delivery mode, TTL
  injection, and tagged telemetry for URL resolution.
- `Rindle.Storage.Local` already knows how to resolve real filesystem paths and
  answer `head/2`; `LocalPlug` can build on that without changing the storage
  abstraction.
- `Rindle.Storage.Capabilities` already provides the pattern for honest adapter
  capability checks and tagged unsupported tuples.
- Existing delivery and telemetry tests provide a strong contract baseline for
  additive API work.

### Established Patterns
- Keep public APIs additive and thin rather than changing established return
  shapes in place.
- Keep transport/delivery concerns in `Rindle.Delivery`, not inside storage
  adapters.
- Keep Phoenix-facing helpers thin and explicit; they consume delivery APIs
  rather than embedding transport policy.
- Prefer profile-level policy over widening the DSL prematurely.

### Integration Points
- `lib/rindle/delivery.ex` will own `streaming_url/3` and shared policy wiring.
- `lib/rindle/delivery/local_plug.ex` is the new local-delivery seam.
- Storage adapters that support signed redirects remain the production path.
- Phase 27 helpers should call `streaming_url/3` for AV playback while image
  helpers can continue using `url/3` / `variant_url/4`.
</code_context>

<specifics>
## Specific Ideas

- Preserve the current semver-stable meaning of `url/3`; do not turn it into a
  polymorphic protocol object.
- Treat `streaming_url/3` as the call site Phoenix helpers should use for
  `<video>` / `<audio>` so future provider adapters do not force template churn.
- Keep the library user-friendly by baking the dev parity plug into core rather
  than making adopters discover and install a side package.
- Carry forward the stronger operating preference the user stated explicitly in
  this discussion: do deep delegated research up front, choose coherent defaults,
  and only escalate very impactful decisions.
</specifics>

<deferred>
## Deferred Ideas

- Real `Rindle.Streaming.Provider` abstraction once a non-progressive provider
  adapter exists and can prove the right boundary
- Per-content-type TTL configuration in the profile DSL
- Rich delivery metadata object beyond `%{url, kind, mime}`
- Any production proxy-streaming posture for remote adapters

None of the above belong in Phase 26.
</deferred>
