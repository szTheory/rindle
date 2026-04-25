# Rindle GSD Bootstrap Brief (Auto Mode)

## Context

This brief is optimized for `/gsd-new-project --auto`.
It should be treated as the authoritative starting context for Rindle project initialization.

## What we are building

Rindle is an open-source Phoenix/Ecto-native media lifecycle library.

It is not "file upload helpers."
It is the durable lifecycle layer after upload:

- upload session management
- staged object verification
- asset modeling
- attachment modeling
- variants/derivatives generation
- background processing
- secure delivery
- observability
- day-2 operations (repair/regenerate/cleanup)

## Product thesis

Upload is the beginning, not the lifecycle.

Rindle should help Phoenix teams ship media features with production confidence:

- explicit state
- strict defaults
- idempotent processing
- observable failures
- operator-friendly maintenance paths

## Reader intent for this GSD init

Initialize a new project roadmap for Rindle that is:

- image-first for v1 implementation
- media-agnostic at the core model level
- production-grade by default
- honest about tradeoffs and non-goals

## Core value (lock this)

Media, made durable.

## Locked decisions for initialization

These should be treated as defaults unless a later explicit decision overrides them.

1. **Core architecture:** media-agnostic domain core, image-first implementation.
2. **Persistence:** normalized Ecto tables for assets, attachments, variants, upload sessions, processing runs.
3. **Variants model:** variants are first-class records (queryable state), not hidden file naming conventions.
4. **Processing model:** async-first, idempotent jobs; avoid heavy in-request transforms.
5. **Security defaults:** strict allowlists, generated storage keys, signed/private delivery, scanner hooks.
6. **Transform policy:** named variants by default; dynamic transforms are opt-in, signed, and bounded.
7. **Operational scope:** day-2 operations are in v1 scope (cleanup, verify, regenerate, reconcile).
8. **Telemetry:** telemetry naming and metadata policy are public contracts.
9. **CI/release:** quality gates + docs contracts + release parity checks are required from early milestone stages.
10. **Adopter truth:** at least one canonical host/adopter integration path is continuously verified.

## Primary personas and jobs

### Phoenix app developer

- Attach media to Ecto schemas quickly.
- Handle uploads (controller, LiveView, direct upload) safely.
- Render thumbnails/responsive images and private URLs.

### Platform/senior engineer

- Enforce media policies per use case.
- Extend analyzers/processors/storage adapters.
- Keep consistency under retries and concurrent updates.

### Operator/SRE

- Observe queue latency/failures.
- Detect and repair stale/missing/orphan media.
- Keep storage cost under control.

### Security/compliance

- Ensure untrusted file handling defaults are safe.
- Guarantee auditability and restricted delivery paths.

## v1 scope (in)

1. Ecto-backed lifecycle model:
   - assets
   - attachments
   - variants/derivatives
   - upload sessions
   - processing runs
2. Upload paths:
   - Phoenix-proxied path
   - direct upload broker (start with S3-compatible presigned PUT flow)
3. Processing:
   - image variants (Image/Vix-first path)
   - named recipes
   - eager + bounded lazy modes
4. Delivery:
   - private/signed URL strategy
   - safe public option where explicitly configured
5. Operations:
   - regenerate stale/missing variants
   - cleanup expired sessions/orphans
   - storage verification/reconciliation helpers
6. Observability:
   - telemetry events and sample metrics
7. Docs/adoption:
   - clear quickstart
   - canonical host integration example
   - migration notes from simpler upload stacks where relevant

## v1 non-goals (lock these)

- Full media platform scope (HLS ladders/DRM/global streaming management).
- Arbitrary unsigned dynamic transformation API.
- Built-in GPU/AI runtime requirements.
- Office/PDF/SVG broad processing by default without hardened sandboxing guidance.
- "Cloud replacement" positioning.

## Security and correctness invariants (must hold)

1. Never trust client MIME/filename alone; enforce sniffing and allowlists.
2. Do not attach/process direct uploads until completion is verified.
3. Do not allow unbounded variant explosion.
4. Storage side effects are not hidden in DB transactions.
5. Purge paths are async, idempotent, and auditable.
6. Concurrent replacement races must resolve safely without stale overwrites.
7. Missing/stale/failed variant states are visible, queryable, and actionable.

## CI and release expectations (must exist early)

1. Quality lane:
   - formatting
   - compile warnings-as-errors
   - tests
   - credo
   - dialyzer
2. Contract lane:
   - docs contracts
   - workflow/release config validation
3. Integration lane:
   - storage + DB + processing path
4. Adopter lane:
   - canonical host integration proof
5. Release lane:
   - release automation
   - dry-run publish
   - post-publish parity verification

## Documentation posture

Docs must be practical, copy-pasteable, and production-aware.
Avoid hype language and "magic" framing.

Essential docs early:

- getting started
- core concepts/lifecycle
- profile/recipe definitions
- secure delivery
- background processing
- operations and cleanup
- failure modes and troubleshooting

## Branding and voice constraints

Rindle voice should be:

- calm
- explicit
- honest about footguns
- peer-to-peer maintainer tone

Avoid:

- "AI sparkle" positioning
- generic SaaS language
- overpromising claims

## Acceptance bar for initial roadmap

The roadmap generated by GSD should:

1. reflect locked decisions above without relitigating basics;
2. include explicit phase-level verification criteria;
3. include day-2 operational slices (not deferred indefinitely);
4. include release and docs quality work as first-class phases;
5. avoid scope inflation into full media-platform territory.

## Preferred initialization defaults

If the workflow asks defaults and no human override is provided:

- granularity: standard or fine (prefer explicit, testable slices)
- parallelization: parallel where plans are independent
- workflow research: enabled
- plan-check: enabled
- verifier: enabled
- commit docs: enabled (unless explicitly requested local-only)

## Input references to load during planning

- `prompts/rindle-brand-book.md`
- `prompts/phoenix-media-uploads-lib-deep-research.md`
- `prompts/gsd-rindle-research-index.md`
- `prompts/gsd-rindle-elixir-oss-dna.md`
