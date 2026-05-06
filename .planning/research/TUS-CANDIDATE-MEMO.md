# Candidate Milestone Memo: tus / Resumable Upload Protocol for Rindle

**Project:** Rindle
**Date:** 2026-05-05
**Recommendation score:** 4/10 for "next milestone now"
**Confidence:** MEDIUM

## 1. Candidate Summary

A meaty but bounded v1.5 would be:

- Add a new additive upload family, not a mutation of presigned PUT or multipart:
  - `initiate_resumable_upload/2`
  - `resume_resumable_upload/2` or `head_resumable_upload/1`
  - `cancel_resumable_upload/1`
  - `complete_resumable_upload/2`
- Introduce a broker-owned resumable session row that still ends in the existing trusted verification and promotion lane.
- Ship one honest server-side seam only:
  - either a minimal in-process Plug/Phoenix tus endpoint, or
  - an explicit external-tusd integration contract.
- Preserve adopter-owned `Repo`, Oban cleanup, tagged capability negotiation, and existing broker telemetry.
- Limit scope to tus core + creation + expiration. Defer checksum, concatenation, termination auth edge cases, and provider-specific optimizations unless required to make the core safe.

That is bounded enough to ship, but it is still a larger systems milestone than it first appears because tus is not just "multipart with offsets". It introduces a server-managed upload resource lifecycle.

## 2. Pros For Rindle Specifically

- Fits Rindle's "durable lifecycle" positioning better than a thin helper would. tus has explicit server-visible upload state, expiry, and resume semantics.
- Helps the AV wedge immediately. Large mobile-origin video/audio uploads are the clearest user pain that presigned PUT and even plain multipart do not solve as well.
- Reuses existing strengths: capability vocabulary, broker-owned sessions, adopter-owned Repo, Oban maintenance, and final verify/promote flow.
- Gives Rindle a stronger cross-provider story than an S3-only multipart path when implemented honestly.

## 3. Cons / Risks For Rindle Specifically

- Biggest risk: it pulls Rindle toward being an upload server, not just a lifecycle library. tus requires long-lived HTTP resource handling, HEAD/PATCH semantics, offset correctness, and more operational surface than current broker APIs.
- It does not collapse as neatly as multipart into "assemble object, then verify". Bytes arrive incrementally and the server becomes part of the hot path.
- Auth is subtle. tusd's own docs note there is currently no built-in mechanism ensuring the same user resumes the upload; they rely on hard-to-guess URLs and hook validation at creation time. Rindle's security posture is stricter than that baseline.
- Failure handling is broader: offset conflicts, partial writes, stale resumptions, intermediary/proxy PATCH behavior, and cleanup of half-finished server-side state.
- Elixir ecosystem maturity is weaker than the broader tus ecosystem. Current Hex options exist, but they are young or old, with light adoption signals.

## 4. Tradeoffs Versus Other Likely Candidates

- Provider adapters / streaming boundary:
  - Better next milestone if the goal is to solidify "Rindle is a lifecycle layer, not a platform".
  - Lower protocol surface area, stronger fit with the AV work just shipped.
  - Likely higher adopter leverage per unit complexity.
- GCS adapter:
  - Narrower and more bounded than tus.
  - Advances the existing reserved resumable capability posture with a specific provider instead of a protocol server.
  - Better if the goal is capability coverage rather than novel client/server behavior.
- Adopter hardening:
  - Lowest glamour, highest trust payoff.
  - If v1.4 AV has surfaced adopter pain, hardening likely returns more value sooner than tus.
- tus:
  - Best if Rindle wants to win specifically on unreliable-network ingest for large uploads.
  - Worst if the priority is staying tightly scoped as a lifecycle library with minimal always-on HTTP protocol surface.

## 5. Idiomatic Fit For Elixir / Phoenix / Ecto / Plug

- Ecto fit: good for persistent resumable session metadata and explicit lifecycle state.
- Oban fit: good for expiry sweeps, abandonment cleanup, and post-finish promotion.
- Plug/Phoenix fit: mechanically possible, but less natural than current short-request broker APIs because tus needs exact HEAD/PATCH protocol behavior and streaming-aware request handling.
- Library fit: mixed. A mounted Plug or route macro is idiomatic, but it changes Rindle from "issue upload instructions" to "serve resumable protocol endpoints".
- Best-fit Elixir shape if pursued:
  - mountable Plug/router endpoint
  - broker-owned DB session as source of truth
  - final `post-finish` equivalent that converges into `verify_completion`
  - explicit capability `:resumable_upload`
  - no silent fallback to presigned PUT or multipart

## 6. Lessons From Comparable Libraries / Frameworks

- tus protocol itself got the core right:
  - `HEAD` with authoritative `Upload-Offset`
  - `PATCH` with strict offset matching and `409` on mismatch
  - advertised extensions via `OPTIONS`
  - expiration as first-class behavior
- tusd got the boundary right:
  - treats upload handling as its own server concern
  - exposes hooks for pre-create, pre-finish, post-finish instead of pretending uploads are ordinary controller actions
  - but tusd also exposes a footgun for Rindle: post-processing retries are not built in; they recommend a separate task system. Rindle would need Oban to own that reliably.
- tus-ruby-server got the integration lesson right:
  - mountable server endpoint
  - explicit cleanup of expired uploads
  - clear warning that mainstream app servers can tie up workers and require chunking
- Shrine got the product-boundary lesson right:
  - tus is glue around the attachment lifecycle, not the lifecycle itself
  - it keeps direct S3 multipart and tus as separate choices instead of merging them into one confusing abstraction
- What Rindle should copy:
  - separate upload protocol seam from lifecycle promotion seam
  - explicit expiry cleanup
  - mountable route/plug shape if in-process
  - no hidden downgrade behavior
- What Rindle should avoid:
  - pretending resumable upload can reuse the current `sign_url` shape
  - hiding auth/resume security assumptions inside opaque upload URLs
  - shipping many tus extensions in v1
  - coupling lifecycle correctness to long-running request workers

## 7. DX Implications

- API shape:
  - Must be a distinct resumable family, not "multipart but friendlier".
  - Adopters will expect a client pairing, likely `tus-js-client` or Uppy Tus.
- Configuration burden:
  - endpoint mounting
  - auth strategy for creation and resume
  - expiry windows
  - storage backing for partial data
  - CORS / proxy PATCH support
- Failure modes:
  - `409` offset mismatch
  - expired upload URL/resource
  - resumed by stale client state
  - promoted asset missing because completion hook failed
  - partial data persisted but lifecycle row not advanced
- Principle of least surprise:
  - `Rindle.upload/3` should stay boring and intact.
  - tus must be clearly documented as advanced and protocol-specific.
  - completion must still end in the same verification vocabulary and broker lifecycle patterns as other ingest paths.

## 8. Recommendation Score

**4/10** for next milestone now.

Reason:

- tus is real and valuable, especially for mobile AV uploads.
- But for Rindle today, it is a boundary-expanding milestone with more protocol and operational complexity than GCS, provider adapters/streaming boundaries, or adopter hardening.
- The best near-term use of the reserved resumable capability work is probably a provider-scoped milestone first, or a sharper external-tusd integration design, before an in-core tus server surface.

## Sources

- Local project context:
  - [.planning/PROJECT.md](/Users/jon/projects/rindle/.planning/PROJECT.md)
  - [.planning/MILESTONES.md](/Users/jon/projects/rindle/.planning/MILESTONES.md)
  - [.planning/milestones/v1.1-REQUIREMENTS.md](/Users/jon/projects/rindle/.planning/milestones/v1.1-REQUIREMENTS.md)
  - [README.md](/Users/jon/projects/rindle/README.md)
  - [guides/storage_capabilities.md](/Users/jon/projects/rindle/guides/storage_capabilities.md)
  - [lib/rindle/storage.ex](/Users/jon/projects/rindle/lib/rindle/storage.ex)
  - [lib/rindle/upload/broker.ex](/Users/jon/projects/rindle/lib/rindle/upload/broker.ex)
- Official / primary:
  - https://tus.io/protocols/resumable-upload
  - https://tus.io/implementations
  - https://tus.github.io/tusd/advanced-topics/hooks/
  - https://tus.github.io/tusd/storage-backends/aws-s3/
  - https://github.com/tus/tus-node-server
  - https://uppy.io/docs/tus/
  - https://shrinerb.com/docs/getting-started
  - https://github.com/janko/tus-ruby-server
- Elixir ecosystem:
  - https://hex.pm/packages/tussle
  - https://hexdocs.pm/tussle/Tussle.Routes.html
  - https://hexdocs.pm/exotus/Exotus.html
