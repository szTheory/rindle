# Requirements: Rindle v1.3

**Defined:** 2026-04-29
**Core Value:** Media, made durable.

## v1.3 Requirements

### Publish Readiness

- [ ] **PUBLISH-01**: Maintainer can verify CI is green and all preflight gates pass on the release candidate commit before pushing a live tag
- [ ] **PUBLISH-02**: Maintainer can review package metadata (`:description`, `:licenses`, `:links`), confirm `CHANGELOG.md` exists with a `0.1.0` entry, inspect tarball contents via `mix hex.build --unpack`, and verify `rindle` is available as a Hex.pm package name before first publish
- [ ] **PUBLISH-03**: Maintainer can push a `v0.1.0` git tag and have the release workflow publish `rindle 0.1.0` to Hex.pm with no manual intervention beyond the tag push

### Publish Verification

- [ ] **VERIFY-01**: Adopter can add `{:rindle, "~> 0.1.0"}` to a fresh Phoenix app's `mix.exs` and have `mix deps.get` resolve from Hex.pm without access to the Rindle source repo
- [ ] **VERIFY-02**: Adopter can browse `hexdocs.pm/rindle` and find module documentation immediately after publish completes

### Routine Release

- [ ] **RELEASE-01**: Maintainer can follow a step-by-step runbook for all routine releases after `0.1.0` with no guesswork, updated to reflect any observed deviations from the first live publish
- [ ] **RELEASE-02**: Maintainer can execute `mix hex.publish --revert VERSION` within the correction window (24h for first publish, 1h for subsequent) using documented runbook steps

### API Naming

- [ ] **API-01**: Maintainer has resolved the `verify_upload/2` vs `complete_multipart_upload/3` vocabulary inconsistency — either renamed to a consistent verb or explicitly documented as distinct operations
- [ ] **API-02**: Maintainer has removed `log_variant_processing_failure/3` from the public `Rindle` facade or explicitly documented it as an internal observability utility
- [ ] **API-03**: Adopter can read consistent module and function names across the public `Rindle` surface with no mismatched verb, noun, or arity patterns

### API Surface Audit

- [ ] **API-04**: Maintainer has applied `@moduledoc false` or `@doc false` to all internal modules (Storage.Local, Storage.S3, Storage.Capabilities internal helpers, Security.*, Profile.Digest, domain FSMs) before any documentation sprint
- [ ] **API-05**: Maintainer has completed a breaking-change determination — renames affecting published function signatures are either shipped before `0.1.0` or explicitly deferred to `v0.2.0`

### Documentation & Typespec Coverage

- [ ] **API-06**: Adopter can read `@doc` annotations on every intentionally public module, function, and behaviour callback in the `Rindle` surface
- [ ] **API-07**: Adopter can use Dialyzer with accurate named struct types in `@spec` annotations (`MediaAsset.t()`, `Attachment.t()`, etc.) instead of opaque `map()` or `term()` return types on public functions
- [ ] **API-08**: CI enforces `@doc`/`@spec` coverage thresholds via `mix doctor --raise` so coverage regressions are caught before merge

### Convenience API

- [ ] **API-09**: Adopter can call `Rindle.attachment_for(owner, slot)` to fetch an attachment without writing a raw Ecto query
- [ ] **API-10**: Adopter can call `Rindle.ready_variants_for(asset)` to fetch ready variants without writing a raw Ecto query
- [ ] **API-11**: Adopter can use bang variants (`attach!/4`, `detach!/3`, `upload!/3`, `url!/3`, `variant_url!/4`) for happy-path callers who prefer exceptions over `{:error, reason}` tuples

## Future Requirements

### GCS Adapter

- **GCS-01**: Adopter can use a Google Cloud Storage adapter with resumable upload flow behind capability flags

### Resumable Protocol

- **TUS-01**: Adopter can use the tus resumable upload protocol as an alternative upload path

### Release Automation

- **CHNG-01**: CHANGELOG.md is updated automatically or semi-automatically from git history on each release
- **DLYXR-01**: CI includes a full Dialyzer clean pass that exits non-zero on any type error

## Out of Scope

| Feature | Reason |
|---------|--------|
| Admin LiveView UI | Operator workflows remain code/telemetry/task driven; out of scope until v2+ |
| FFmpeg/Membrane adapters | Image-first remains the wedge; video/audio follow after host-app/runtime boundaries are solid |
| PDF preview adapter | Out-of-scope until sandboxing posture is documented |
| Full HLS/DASH/DRM streaming | Rindle is a lifecycle library, not a media platform |
| Unsigned dynamic transformation API | DoS/cost vector; named presets and signed transforms only |
| GCS adapter in v1.3 | Deferred to future milestone; multipart/S3 first |
| tus/resumable protocol in v1.3 | Deferred to future milestone; evaluate once release distribution is routine |
| Breaking API changes after 0.1.0 | Any renames identified during API audit that affect published signatures target v0.2.0, not v0.1.x |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PUBLISH-01 | TBD | Pending |
| PUBLISH-02 | TBD | Pending |
| PUBLISH-03 | TBD | Pending |
| VERIFY-01 | TBD | Pending |
| VERIFY-02 | TBD | Pending |
| RELEASE-01 | TBD | Pending |
| RELEASE-02 | TBD | Pending |
| API-01 | TBD | Pending |
| API-02 | TBD | Pending |
| API-03 | TBD | Pending |
| API-04 | TBD | Pending |
| API-05 | TBD | Pending |
| API-06 | TBD | Pending |
| API-07 | TBD | Pending |
| API-08 | TBD | Pending |
| API-09 | TBD | Pending |
| API-10 | TBD | Pending |
| API-11 | TBD | Pending |

**Coverage:**
- v1.3 requirements: 18 total
- Mapped to phases: TBD (roadmap not yet created)
- Unmapped: 18 ⚠️ (to be resolved by roadmapper)

---
*Requirements defined: 2026-04-29*
*Last updated: 2026-04-29 after initial definition*
