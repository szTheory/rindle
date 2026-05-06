# Recommendation Memo: Provider Adapters and Streaming Boundary for Rindle

**Date:** 2026-05-05  
**Decision:** useful direction, but not the best next milestone unless tightly scoped  
**Recommendation score:** **6/10** for "next milestone now"

## 1. Candidate Summary

A meaty but bounded `v1.5` would **not** build streaming in core. It would productize the seam already reserved by `Rindle.Delivery.streaming_url/3` and add **provider-delegated playback/processing integration** with one reference provider.

Bounded `v1.5` scope:

- Turn `Rindle.Streaming.Provider` from reserved behaviour into a real adapter contract.
- Keep `streaming_url/3` as the only playback entrypoint; dispatch to provider when a provider-backed asset/variant exists, else keep current progressive behavior.
- Add durable provider reference storage for assets/variants: provider name, opaque provider asset ID, playback locator, provider status, last sync error, public/private policy.
- Add Oban jobs for provider sync/retry and signed webhook ingestion for async provider readiness/failure updates.
- Map Rindle named presets to provider-side presets/policies instead of exposing raw provider knobs.
- Keep delivery private-by-default; support provider-signed playback, not public manifests by default.
- Ship **one** reference adapter only. Mux is the best fit; Cloudflare Stream is a plausible second adapter later.

Out of scope for this milestone:

- Core HLS/DASH/DRM/live features
- Generic “video platform” abstractions beyond playback URL + delegated status
- Multi-provider parity in v1.5
- tus in core unless the chosen provider requires it for direct uploads

## 2. Pros for Rindle Specifically

- It matches the repo’s explicit boundary: Rindle owns lifecycle; providers own streaming complexity.
- `streaming_url/3` already reserves the namespace, so adopters would gain capability without template churn.
- It preserves the adopter-owned Repo and Oban model: provider state is durable in Ecto, provider work is async in Oban.
- It extends private-by-default cleanly through signed playback IDs/tokens.
- It gives Rindle a credible answer for teams that want video support without running FFmpeg-heavy infrastructure themselves.

## 3. Cons/Risks for Rindle Specifically

- The biggest risk is **locking the wrong public abstraction** before real adopter feedback exists. v1.4 deliberately deferred this.
- Provider adapters create a new category of failure: webhook drift, remote eventual consistency, token expiry, provider-side stuck processing.
- A generic adapter API can easily become lowest-common-denominator mush if v1.5 tries to cover Mux, Cloudflare Stream, and Transloadit at once.
- It shifts Rindle closer to “managed video integration library,” which is adjacent to its mission but easier to over-expand than storage adapters.
- Testing burden rises sharply because CI needs provider-contract proofs or high-fidelity fakes.

## 4. Tradeoffs Versus Other Likely Candidates

- **Versus GCS resumable adapter:** GCS resumable is the cleaner next milestone. It fits the existing storage capability contract, helps all media kinds, and does not risk widening Rindle into streaming product territory. GCS docs also make clear resumable uploads are the recommended path for large uploads and have concrete session semantics Rindle can model cleanly.
- **Versus tus protocol support:** tus is strategically useful, especially for unreliable networks and large uploads, but it is broader protocol surface than Rindle currently needs. It is better after either a concrete provider need or a stronger adopter-interoperability signal.
- **Versus adopter hardening:** adopter hardening is the safest choice if early v1.4 feedback exposes rough edges. It has lower upside than provider adapters, but lower API-risk too.

My priority order today:

1. GCS resumable adapter
2. Provider boundary plus one reference adapter
3. Adopter hardening
4. tus protocol support

## 5. Idiomatic Fit for Elixir/Phoenix/Ecto/Plug

This is idiomatic **if** the implementation stays boring:

- Ecto persists provider state and auditability.
- Oban owns retries, sync, timeout, and webhook follow-up jobs.
- Phoenix/Plug handle signed webhook verification and token-minting endpoints.
- Behaviours define adapter seams; adapters stay pure request/response modules.

It becomes non-idiomatic if Rindle starts owning long-lived streaming sessions, segment serving, or provider-specific workflow engines inside the BEAM.

## 6. Lessons from Comparable Libraries/Frameworks

- **Active Storage:** got the redirect boundary right, but blurred playback concerns. Rindle should keep `url/3` and `streaming_url/3` separate.
- **Shrine:** got backgrounding and atomic promotion right. Rindle should copy the “async and race-aware” posture for provider sync.
- **Spatie:** good day-2 ergonomics, but punts too much video behavior to adopters. Rindle should ship a real reference adapter, not prose only.
- **Mux / Cloudflare Stream:** they hide codec ladders, ingest internals, and playback mechanics behind opaque IDs, upload URLs, and webhooks. Rindle should copy that opacity and avoid leaking provider implementation detail into public API.

Footguns to avoid:

- raw provider settings in profiles
- more than one provider in the first milestone
- making storage keys part of the playback contract
- polling-only readiness without webhook support

## 7. DX Implications

Principle-of-least-surprise API shape:

- `streaming_url/3` stays stable and returns either provider-backed or progressive playback.
- Profiles opt into a provider with named presets and explicit delivery policy, not dozens of provider fields.
- Failures stay tagged and operator-readable: `:streaming_not_configured`, `:provider_asset_not_ready`, `:provider_webhook_invalid`, `:provider_sync_failed`.

DX burden to manage:

- configuration for credentials, webhook secret, and signing keys
- provider lifecycle visibility in admin/troubleshooting queries
- clear fallback behavior when provider asset is not ready yet

The least surprising rule is: **provider delegation is additive per profile or preset; existing AV progressive flows remain unchanged.**

## 8. Recommendation

**Do not make this the next milestone unless it is explicitly scoped as “provider boundary + one reference adapter,” not “streaming support.”**

If the goal is the highest-confidence next step for Rindle overall, pick **GCS resumable adapter first**. If the goal is the highest strategic leverage for video credibility, this provider-boundary milestone is a good **second** choice and should target **Mux first**.

## Sources

- Repo context:
  - `.planning/PROJECT.md`
  - `.planning/MILESTONES.md`
  - `.planning/milestones/v1.4-REQUIREMENTS.md`
  - `lib/rindle/delivery.ex`
  - `lib/rindle/streaming/provider.ex`
- Comparable docs:
  - Rails Active Storage Overview: https://guides.rubyonrails.org/active_storage_overview.html
  - Shrine processing: https://shrinerb.com/docs/processing
  - Shrine derivatives / atomic helpers: https://shrinerb.com/docs/plugins/derivatives and https://shrinerb.com/docs/plugins/atomic_helpers
  - Spatie Media Library conversions: https://spatie.be/docs/laravel-medialibrary/v11/converting-images/defining-conversions
  - GCS resumable uploads: https://cloud.google.com/storage/docs/resumable-uploads
  - tus protocol: https://tus.io/protocols/resumable-upload
  - Mux direct uploads: https://www.mux.com/docs/guides/upload-files-directly and https://www.mux.com/docs/api-reference/video/direct-uploads/create-direct-upload
  - Cloudflare Stream direct creator uploads: https://developers.cloudflare.com/stream/uploading-videos/direct-creator-uploads/
