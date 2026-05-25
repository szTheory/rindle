# Phase 45: Browser -> Mux Direct Creator Upload (sibling, droppable) - Context

**Gathered:** 2026-05-24 (assumptions mode + subagent research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Let a browser upload a large video directly to Mux through a Rindle-brokered
one-time URL, then let Rindle reconcile the resulting provider asset and notify
adopters through the already-shipped webhook/PubSub/provider-asset machinery.
This completes the reserved v1.6 direct-creator-upload seam as an additive,
droppable sibling slice.

This phase does NOT rework the tus spine, does NOT route bytes through
`MediaUploadSession`/`verify_completion/2`, does NOT mutate the shipped
`MuxWeb` preset semantics, and does NOT add a provider-side cancel flow.
</domain>

<decisions>
## Implementation Decisions

### Public ownership boundary
- **D-01:** Add a thin streaming-owned public entrypoint,
  `Rindle.Streaming.create_direct_upload/2`, as the main server-side seam for
  browser->Mux direct upload. It owns capability gating, local row creation,
  correlation-token stamping, and the public return shape.
- **D-02:** Do NOT reuse `Rindle.Upload.Broker`'s `MediaUploadSession`
  lifecycle as the public ownership model. Browser->Mux direct upload bypasses
  adopter storage and has no meaningful `upload_key` or broker-side
  `verify_completion/2` step. Reuse Broker patterns internally where useful
  (`Ecto.Multi`, compensation posture, redaction discipline), but not the row
  type or public abstraction.
- **D-03:** The durable local truth for this flow is a `media_provider_assets`
  row, not a `media_upload_sessions` row. Create the provider row before the
  browser starts uploading so webhook reconciliation always mutates existing
  local state.

### Correlation and webhook linker
- **D-04:** Correlate `video.upload.asset_created` primarily via Mux
  `passthrough`, not via `provider_asset_id` or `upload_id`. Stamp an opaque
  Rindle-owned correlation token into `new_asset_settings.passthrough` at
  direct-upload creation time, then look up the row by that token when the
  webhook arrives.
- **D-05:** Add one additive nullable correlation column to
  `media_provider_assets` for the passthrough token, redact it alongside other
  provider-internal identifiers, and treat it as the single required lookup key
  for direct-upload linking.
- **D-06:** Upgrade the current `video.upload.asset_created` webhook branch
  from a no-op into the upload->asset linker: look up by correlation token,
  stamp `provider_asset_id`, advance the row into the existing processing path,
  and broadcast the already-reserved `:provider_asset_created` PubSub event.
- **D-07:** `upload_id` stays internal. Persisting it is OPTIONAL and only
  justified as a secondary operator/debug hook for future provider-side
  retrieve/cancel tooling. It must never become the public API handle or the
  primary business key.

### Public return shape and secrecy
- **D-08:** The browser-facing server contract returns ONLY
  `%{upload_url, asset_id}` where `asset_id` is the durable Rindle-side asset
  handle. Never expose raw Mux `upload_id` or `provider_asset_id` to adopters.
- **D-09:** `upload_url` is a one-time bearer credential and must never be
  persisted, logged, emitted in telemetry, or surfaced in DOM/debug helpers
  beyond the immediate browser handoff.

### Frontend and adopter DX posture
- **D-10:** The documented baseline integration is a thin controller/JSON
  endpoint that calls `Rindle.Streaming.create_direct_upload/2` and returns the
  browser-safe contract. This is the primary path because it works for
  controllers, LiveView, and non-LiveView frontends with the least surprise.
- **D-11:** `Rindle.LiveView.allow_direct_upload/4` is the convenience path,
  layered over the same server contract via LiveView `:external` uploads. It is
  intentionally secondary in the docs and must not create a separate lifecycle
  or semantics.
- **D-12:** Browser upload UX should standardize on UpChunk as the documented
  client for the happy path. `mux-uploader` may be mentioned as an alternative,
  but Rindle does not center its contract around a required provider-owned UI
  component.
- **D-13:** The UI must preserve a visible post-transfer state split:
  `Uploading to Mux...` -> `Upload received. Linking provider asset...` ->
  `Asset linked. Preparing playback...` -> ready/error. PUT success is not the
  same thing as a ready provider asset.

### Profile ergonomics
- **D-14:** Keep `Rindle.Profile.Presets.MuxWeb` unchanged. Its current meaning
  is a locked signed-playback + Mux + `:server_push` posture and must not be
  silently widened into a mode bag.
- **D-15:** Add a sibling preset,
  `Rindle.Profile.Presets.MuxDirectUploadWeb`, as the best public DX for this
  phase. It should be a thin wrapper that locks the same streaming provider and
  playback posture while setting `ingest_mode: :direct_creator_upload`.
- **D-16:** Preserve the lower-level escape hatch: advanced adopters can keep
  using `Rindle.Profile.Presets.Web` plus an explicit `delivery: [streaming: …]`
  block when they want full control.

### Operational / protocol posture
- **D-17:** `cors_origin` is required for browser direct upload and must be
  treated as a first-class config/docs footgun. Default it from the request
  origin in examples; do not normalize to `"*"` in production guidance.
- **D-18:** Keep webhook processing idempotent and Oban-backed. Duplicates,
  retries, and out-of-order events are expected provider behavior; the Phase 45
  linker must preserve the current worker's idempotent posture.
- **D-19:** Polling is a fallback only. PubSub remains the primary adopter
  readiness signal; polling may be documented for environments that cannot
  subscribe, but it must reuse the same visible state model and labels.

### the agent's Discretion
- Exact naming of the new correlation column, as long as it is explicit,
  provider-scoped, and redacted.
- Whether `upload_id` is persisted now or deferred, as long as D-07 and D-08
  hold.
- Whether the sibling preset is named `MuxDirectUploadWeb` or another equally
  explicit, least-surprise name.
- Exact controller route examples and LiveView helper copy, as long as the
  baseline-vs-convenience hierarchy in D-10/D-11 is preserved.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract
- `.planning/PROJECT.md` — project constitution, decision-making contract, and
  milestone posture.
- `.planning/REQUIREMENTS.md` — MUX-20..23 locked requirement contract.
- `.planning/ROADMAP.md` — Phase 45 goal, success criteria, and droppable
  sibling posture.
- `.planning/STATE.md` — current milestone status and operator preference for
  research-first, cohesive recommendation sets.

### Locked direct-upload research
- `.planning/research/v1.8/MUX-DIRECT-UPLOAD-RESEARCH.md` — authoritative
  research pass for Phase 45; especially the streaming entrypoint posture,
  passthrough correlation, controller/LiveView DX split, and sibling-preset
  recommendation.
- `.planning/research/v1.8-MUX-SDK-BOUNDARY.md` — Mux SDK boundary guidance.

### Prior locked phase context
- `.planning/phases/42-tus-protocol-edge-bare-plug/42-CONTEXT.md` — carry-forward
  redaction, capability honesty, and thin-edge design posture.
- `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-CONTEXT.md`
  — carry-forward auth/DX/telemetry/operator posture.
- `.planning/phases/45-browser-mux-direct-creator-upload-sibling-droppable/45-UI-SPEC.md`
  — locked UI and interaction contract for the browser upload flow.

### In-repo implementation anchors
- `lib/rindle/streaming/provider.ex` — reserved `create_direct_upload/2`
  callback and provider event contract.
- `lib/rindle/streaming/provider/mux.ex` — Mux adapter patterns and capability
  surface.
- `lib/rindle/streaming/provider/mux/http.ex` — SDK-boundary HTTP wrapper.
- `lib/rindle/streaming/provider/mux/event.ex` — typed
  `video.upload.asset_created` normalization.
- `lib/rindle/workers/ingest_provider_webhook.ex` — current no-op branch to
  upgrade into the linker.
- `lib/rindle/domain/media_provider_asset.ex` — durable provider-row schema and
  redaction rules.
- `lib/rindle/domain/provider_asset_fsm.ex` — allowed provider-state
  transitions.
- `lib/rindle/profile/presets/mux_web.ex` — current locked server-push preset.
- `lib/rindle/profile/validator.ex` — streaming DSL / `ingest_mode` validation.
- `lib/rindle/live_view.ex` — existing optional LiveView seam to extend.
- `guides/streaming_providers.md` — adopter-facing streaming guide to extend.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle.Streaming.Provider` already reserves `create_direct_upload/2` and the
  provider-event contract already carries optional `upload_id`.
- The Mux event normalizer already correctly distinguishes `data.id` (upload
  id) from `data.asset_id` (provider asset id), avoiding the main silent-linking
  footgun.
- `IngestProviderWebhook` already has idempotent Oban uniqueness, PubSub
  broadcasting, and a deferred `video.upload.asset_created` branch ready to be
  upgraded.
- `MediaProviderAsset` already models the right durable state machine for this
  flow (`pending` -> `uploading` -> `processing` -> `ready`).
- `Rindle.LiveView` already offers the optional module-gated integration style
  Phase 45 should follow rather than replace.

### Established Patterns
- Public seams in Rindle are explicit and additive; framework-specific helpers
  wrap core contracts instead of owning them.
- Capability honesty is a hard rule. Direct-upload support should be advertised
  only by providers that truly implement it.
- Provider-internal identifiers are secret-grade and must be redacted in
  telemetry, logs, and `Inspect`.
- Webhook-driven provider transitions are asynchronous, idempotent, and
  PubSub-visible; provider readiness is never inferred from client-side success
  alone.

### Integration Points
- `Rindle.Streaming.create_direct_upload/2` -> create local provider row ->
  call `Mux.Video.Uploads.create/2` via adapter -> hand `upload_url` to browser.
- Browser upload completion -> Mux webhook -> `IngestProviderWebhook` linker ->
  `:provider_asset_created` broadcast -> existing provider-ready path ->
  `:provider_asset_ready` broadcast.
- Controller examples and `Rindle.LiveView.allow_direct_upload/4` both sit on
  top of the same server contract and asset-state model.
</code_context>

<specifics>
## Specific Ideas

- Prefer `passthrough` as an opaque Rindle-owned correlation token, not a raw
  Mux identifier or reusable user-facing handle.
- Document UpChunk as the default browser uploader and explicitly call out that
  each new upload requires a fresh one-time URL.
- Return the durable Rindle `asset_id` immediately so the UI can subscribe to
  `:provider_asset` events before the browser upload completes.
- Keep the controller/JSON variant as the baseline docs story even when a
  LiveView helper lands; that preserves the library’s optional-framework
  posture.
</specifics>

<deferred>
## Deferred Ideas

- Persisting `upload_id` as a secondary operator/debug field — acceptable, but
  not required for Phase 45.
- Provider-side cancel support (`cancel_direct_upload/1`) — deferred unless a
  concrete adopter need appears.
- Centering docs around `mux-uploader` or shipping a Rindle-owned uploader
  component — out of scope for this thin DX slice.
- Polling-first UX — fallback only, not the primary contract.
- Any attempt to fold browser->Mux direct upload into `MediaUploadSession` or
  mutate `MuxWeb` semantics — explicitly rejected here.
</deferred>

---

*Phase: 45-browser-mux-direct-creator-upload-sibling-droppable*
*Context gathered: 2026-05-24*
