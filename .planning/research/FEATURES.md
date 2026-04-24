# Feature Research

**Domain:** Phoenix/Elixir media lifecycle library
**Researched:** 2026-04-24
**Confidence:** HIGH (based on PROJECT.md, reference implementations, and ecosystem context)

## Feature Landscape

### Table Stakes (Users Expect These)

Features library adopters assume exist. Missing these = library feels like a toy, not production-ready.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| File storage (local + S3) | Every media library stores files somewhere | MEDIUM | Must expose adapter capabilities, not pretend all backends are identical; R2 ≠ S3 |
| MIME validation + magic-byte sniffing | Security baseline — never trust client Content-Type | LOW | Client MIME is attacker-controlled; magic bytes are ground truth |
| Filename sanitization + generated keys | Predictable paths = path traversal risk | LOW | No user-controlled storage paths, ever |
| Ecto schema integration | Phoenix developers live in Ecto | MEDIUM | `has_one_attached` / `has_many_attached` analogues for Ecto changesets |
| Image variants / thumbnails | Core use case for 95%+ of adopters | HIGH | Named presets via profile DSL; libvips not ImageMagick |
| Background processing | Sync image processing in web request = slow, risky | MEDIUM | Oban workers; not optional |
| File size + type allowlists | Operators need policy enforcement | LOW | Extension, MIME, byte size, pixel count limits |
| Attachment lifecycle (attach/detach) | Files must be linkable and unlinkable to records | MEDIUM | Atomic attach/promote pattern prevents race conditions |
| Basic delivery (URL generation) | You have to serve the files | LOW | Private-by-default; public opt-in per profile |

### Differentiators (Competitive Advantage)

Features that set Rindle apart from Waffle and emergent competitors.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Normalized variant DB records | Queryable state = admin UI, retries, stale detection, cleanup — Waffle has none of this | HIGH | `media_variants` table; no JSON-only storage |
| Asset state machine (9 states) | Visibility into exactly where an asset is in its lifecycle; operators can query `quarantined` or `degraded` assets | HIGH | `staged → validating → analyzing → promoting → available → processing → ready / degraded / quarantined / deleted` |
| Upload session state machine | Direct uploads that don't leave orphaned objects when they fail | HIGH | `initialized → signed → uploading → uploaded → verifying → completed / aborted / expired / failed` |
| Stale variant detection via recipe digest | Recipe changes automatically flag variants for regeneration — no manual tracking | MEDIUM | Stable hash of recipe config; compare at runtime |
| Day-2 Mix tasks | `mix rindle.cleanup_orphans`, `mix rindle.regenerate_variants`, `mix rindle.verify_storage` — what keeps production healthy | MEDIUM | Most upload libraries ignore this entirely |
| Telemetry as public API contract | Operators can build dashboards and alerts without fear of breakage | MEDIUM | Named event contracts with documented metadata shapes |
| Signed URL delivery by default | Security posture that's correct out of the box | LOW | Private storage default; public requires explicit opt-in |
| Atomic promote pattern | Prevents stale background job from overwriting newer uploads | MEDIUM | Reload + verify before writing, inspired by Shrine |
| Async idempotent purge | Storage delete failures don't corrupt DB state; safe to retry | MEDIUM | Detach in DB transaction, enqueue storage delete after commit |
| Storage adapter capability negotiation | Honest about what each backend supports | LOW | `:presigned_put`, `:multipart_upload`, `:resumable_upload` capability flags |
| Profile/recipe DSL with compile-time validation | Catch configuration errors at compile time, not runtime | MEDIUM | `use Rindle.Profile`; digest computed from recipe |
| Responsive image helper | `picture_tag/3` with srcset + placeholder — DX for frontend delivery | LOW | Inspired by Spatie Media Library; reduces boilerplate |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem valuable but create real problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Unsigned dynamic transform API | "Just resize to any dimension on the fly" | DoS/cost vector: attackers enumerate pixel combinations to exhaust CPU/storage; imgproxy learned this the hard way | Named presets in profiles; signed dynamic transforms with pixel bounds as opt-in |
| JSON-only variant storage | Simpler schema, fewer tables | Breaks queryability: can't find stale variants, can't report on failures, can't run cleanup jobs — Day-2 operations become guesswork | Normalized `media_variants` table |
| Sync processing in web requests | Feels simpler for small apps | Blocks request, no retry on failure, no observability, degrades under load | Oban workers always; eager or lazy, but async |
| ImageMagick / FFmpeg in core deps | Broad format support | Security history (ImageTragick, hostile-input DoS in FFmpeg); requires sandboxing that most hosts don't have configured | libvips (Image/Vix) as default; IM/FFmpeg as explicit opt-in adapters with documented sandbox requirements |
| tus/resumable upload in v1 | "Large file support" | Complexity of tus server protocol exceeds v1 scope; presigned PUT handles 95%+ of cases well | Direct presigned PUT for v1; tus adapter in v1.x |
| S3 multipart upload in v1 | Large files, parallel upload | Adds significant adapter complexity; presigned PUT covers the primary case | Single presigned PUT for v1; multipart in v1.x |
| Admin LiveView UI in core | Nice DX | Increases surface area, opinionated UI is hard to compose, drags scope | LiveDashboard page or minimal read-only admin as stretch; full admin UI in v2 |
| Global CDN / URL signing in CDN keys | "CDN integration" | Rindle is a library, not an infrastructure layer; CDN config varies wildly per adopter | Signed URL delivery from storage; CDN behavior is adopter responsibility |
| Built-in GPU/AI pipeline | "Auto-tag images, generate alt text" | GPU runtime dependency in core = hard to install anywhere; AI providers change rapidly | Extension point backed by external providers; not a core dependency |
| PDF/Office/SVG processing by default | "Process all documents" | Requires hardened sandboxing universally unavailable; security risk without container isolation | Explicit opt-in with documented container/sandbox guidance |

## Feature Dependencies

```
[Profile/Recipe DSL]
    └──required by──> [Image Variants]
                          └──required by──> [Eager Variant Generation]
                          └──required by──> [Signed Lazy Variant Generation]
                          └──required by──> [Stale Variant Detection]

[Asset State Machine]
    └──required by──> [Upload Session State Machine]
    └──required by──> [Atomic Attach/Promote]
    └──required by──> [Variant State Machine]

[Oban Workers]
    └──required by──> [Eager Variant Generation]
    └──required by──> [Async Purge]
    └──required by──> [Day-2 Cron Cleanup]

[Storage Adapter]
    └──required by──> [Presigned PUT Direct Upload]
    └──required by──> [Signed URL Delivery]
    └──required by──> [mix rindle.verify_storage]

[Magic-byte MIME Detection]
    └──required by──> [Allowlist Validation]
    └──required by──> [Quarantine State]

[Recipe Digest]
    └──required by──> [Stale Variant Detection]
    └──required by──> [mix rindle.regenerate_variants]

[Normalized Variant DB Records]
    └──required by──> [Stale Variant Detection]
    └──required by──> [mix rindle.regenerate_variants]
    └──required by──> [Day-2 Operations]

[Signed URL Delivery] ──conflicts with──> [Public URL opt-in]
    (both exist, but public URL must be explicitly declared in profile)
```

### Dependency Notes

- **Profile DSL requires compile-time validation:** Recipe errors must surface at compile time because they gate variant generation; runtime-only errors mean bad deploys succeed silently
- **Asset state machine required by upload session:** Sessions transition assets through `staged → validating → ...`; the asset state machine is the substrate
- **Oban required by all async paths:** Not optional — all processing, purge, and cleanup paths run through Oban workers; no parallel runner
- **Recipe digest required by stale detection:** Without a stable hash of the recipe config, there's no way to know which variants are stale after a profile change
- **Normalized variant records required by Day-2 ops:** `mix rindle.regenerate_variants` must be able to query `stale` or `missing` variants — impossible with JSON-only storage

## MVP Definition

### Launch With (v1)

Minimum viable product — what Phoenix teams need to ship media with production confidence.

- [x] **Ecto schemas + migrations** — normalized tables for assets, attachments, variants, upload sessions, processing runs; queryable state is the foundation
- [x] **Core behaviours** — `Rindle.Storage`, `Rindle.Processor`, `Rindle.Analyzer`, `Rindle.Scanner`, `Rindle.Authorizer`
- [x] **Profile/recipe DSL** — `use Rindle.Profile` with compile-time validation and recipe digest
- [x] **Asset + variant + upload session state machines** — full lifecycle visibility
- [x] **Magic-byte MIME detection + allowlist validation** — security baseline, non-negotiable
- [x] **Local disk + S3-compatible storage adapters** — two adapters needed to prove the adapter interface
- [x] **Image variants via libvips (Image/Vix)** — the primary use case; named presets only
- [x] **Phoenix-proxied upload + direct presigned PUT upload** — two upload paths that cover 95%+ of real-world needs
- [x] **Eager variant generation via Oban** — async processing, always
- [x] **Atomic attach/promote** — prevents concurrent replacement race conditions
- [x] **Async idempotent purge** — detach in transaction, enqueue storage delete after commit
- [x] **Signed URL delivery (private-by-default)** — correct security posture out of the box
- [x] **Telemetry events (public contract)** — operators can observe from day one
- [x] **Responsive image helper (`picture_tag/3`)** — reduces frontend boilerplate, drives adoption
- [x] **Day-2 Mix tasks** — cleanup, regeneration, verification, abort; what separates a library from an upload wrapper
- [x] **Oban cron workers for scheduled cleanup** — automated hygiene without operator cron configuration
- [x] **Stale variant detection** — recipe digest changes trigger `stale` state; `mix rindle.regenerate_variants` resolves

### Add After Validation (v1.x)

Features to add once core patterns are validated in the field.

- [ ] **tus resumable upload adapter** — large file support; add when adopters hit presigned PUT size limits
- [ ] **S3 multipart upload** — parallel/large uploads; add when presigned PUT proves insufficient
- [ ] **GCS storage adapter** — POST-then-PUT resumable flow differs enough to deserve post-v1 attention
- [ ] **Cloudflare R2 adapter** — no presigned POST multipart; needs capability negotiation verified in the field
- [ ] **FFmpeg video adapter** — video lifecycle follows image patterns; add as plugin post-v1
- [ ] **Membrane audio adapter** — audio processing plugin post-v1
- [ ] **LiveDashboard integration page** — minimal read-only operational visibility; stretch goal
- [ ] **Signed lazy variant generation** — opt-in dynamic signed transforms with pixel bounds; useful after named presets prove insufficient

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] **Admin LiveView UI** — full admin UI is v2; too opinionated for v1 core
- [ ] **PDF preview adapter** — needs container/sandbox guidance that isn't universally available
- [ ] **Office/SVG processing** — same sandboxing concern as PDF
- [ ] **AI/ML processor extension** — extension point exists; official adapters follow adoption
- [ ] **HLS/DASH streaming** — media platform territory; Mux/Transloadit adapters, not Rindle core

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Ecto schemas + state machines | HIGH | MEDIUM | P1 |
| Profile/recipe DSL | HIGH | MEDIUM | P1 |
| Magic-byte MIME detection + allowlists | HIGH | LOW | P1 |
| Local disk storage adapter | HIGH | LOW | P1 |
| S3 storage adapter | HIGH | MEDIUM | P1 |
| Image variants (libvips) | HIGH | HIGH | P1 |
| Phoenix-proxied upload path | HIGH | MEDIUM | P1 |
| Direct presigned PUT upload | HIGH | MEDIUM | P1 |
| Eager Oban variant generation | HIGH | MEDIUM | P1 |
| Atomic attach/promote | HIGH | MEDIUM | P1 |
| Async idempotent purge | HIGH | MEDIUM | P1 |
| Signed URL delivery | HIGH | LOW | P1 |
| Telemetry (public contract) | HIGH | LOW | P1 |
| Day-2 Mix tasks | HIGH | MEDIUM | P1 |
| Stale variant detection | HIGH | LOW | P1 |
| Oban cron cleanup workers | MEDIUM | LOW | P1 |
| Responsive image helper | MEDIUM | LOW | P2 |
| Signed lazy variants | MEDIUM | MEDIUM | P2 |
| tus resumable upload | MEDIUM | HIGH | P2 |
| S3 multipart upload | MEDIUM | HIGH | P2 |
| GCS adapter | MEDIUM | MEDIUM | P2 |
| LiveDashboard page | LOW | MEDIUM | P2 |
| FFmpeg video adapter | MEDIUM | HIGH | P3 |
| Admin LiveView UI | LOW | HIGH | P3 |
| PDF/Office processing adapters | LOW | HIGH | P3 |
| AI processor adapters | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for v1 launch
- P2: Add in v1.x after validation
- P3: v2+ or ecosystem plugins

## Competitor Feature Analysis

| Feature | Waffle (Elixir) | phx_media_library (v0.6) | Active Storage (Rails) | Shrine (Ruby) | Our Approach |
|---------|-----------------|--------------------------|----------------------|---------------|--------------|
| Persistent variant state | None (filename conventions) | Unknown (study API) | None (lazy, no DB record) | Separate derivative records | First-class `media_variants` table |
| Upload sessions | None | Unknown | None | Upload endpoint abstraction | Full state machine with verification |
| State machines | None | Unknown | Partial (blob analysis) | Partial | Full asset + variant + session state machines |
| Background processing | Optional (manual) | Unknown | Active Job (optional) | Plugin-based | Oban required; not optional |
| Day-2 operations | None | Unknown | Partial (purge only) | Backgrounding plugin | v1 scope: cleanup, regenerate, verify, abort |
| Telemetry | None | Unknown | None | None | Public contract with documented schemas |
| Signed delivery | Limited | Unknown | Yes (default) | Yes (plugin) | Private-by-default; signed URLs |
| Dynamic transforms | None | Unknown | None | Plugin | Named presets only; signed opt-in |
| Storage adapter capabilities | None | Unknown | None | Plugin-based | Capability flags per adapter |
| MIME magic-byte detection | Limited | Unknown | Yes | Yes (plugin) | Always enforced; never trust client |
| Responsive image helper | None | Unknown | None | None | `picture_tag/3` with srcset |

**Note on phx_media_library:** Published March 2026 (v0.6.0). API must be studied before finalizing Rindle's public API surfaces to ensure meaningful differentiation and to avoid inadvertently mirroring a weaker design. Priority: study before M2 API finalization.

## Sources

- PROJECT.md — project requirements, constraints, key decisions, and out-of-scope definitions
- Active Storage (Rails) — attachment/blob/variant model; async purge pattern; lazy variant redirection
- Shrine (Ruby) — derivatives as DB records; atomic promote pattern; backgrounding/cleanup as first-class
- Spatie Media Library (PHP) — conversion regeneration commands; responsive srcset; opinionated DX defaults
- imgproxy — signed dynamic transform URL security model
- Mux/Transloadit — async upload session → state transition ergonomics
- Waffle (Elixir) — current Phoenix ecosystem baseline; gaps define Rindle's differentiation surface
- phx_media_library — nearest emerging Phoenix competitor (v0.6.0, March 2026); study before API finalization

---
*Feature research for: Rindle — Phoenix/Ecto media lifecycle library*
*Researched: 2026-04-24*
