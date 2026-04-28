# Requirements: Rindle

**Defined:** 2026-04-28
**Core Value:** Media, made durable.

## v1.1 Requirements

### Adopter Runtime Ownership

- [ ] **ADOPT-01**: Adopter can configure Rindle's runtime Repo via
  `config :rindle, :repo, MyApp.Repo`
- [ ] **ADOPT-02**: Public runtime APIs use the configured adopter Repo instead
  of hard-coded `Rindle.Repo`
- [ ] **ADOPT-03**: Canonical adopter integration proves upload, attach,
  detach, and delivery flows work with an adopter-owned Repo
- [ ] **ADOPT-04**: Guides and examples document adopter-owned Repo and Oban
  ownership without repo-internal assumptions

### Multipart Uploads

- [ ] **MULT-01**: User can initiate an S3 multipart upload session when the
  selected storage adapter advertises multipart capability
- [ ] **MULT-02**: User can upload parts, complete the multipart upload, and
  verify completion before promotion proceeds
- [ ] **MULT-03**: Timed-out or abandoned multipart uploads can be aborted by
  maintenance flows to prevent orphaned storage costs
- [ ] **MULT-04**: Requesting multipart upload on an adapter without multipart
  capability returns a tagged unsupported-capability error

### Storage Capability Confidence

- [ ] **CAP-01**: Storage adapters advertise precise capability flags for
  delivery and upload flows (`:presigned_put`, `:multipart_upload`,
  `:signed_url`, future-resumable-safe extension points)
- [ ] **CAP-02**: MinIO/S3 integration tests exercise both presigned PUT and
  multipart flows end-to-end against real storage
- [ ] **CAP-03**: Cloudflare R2 compatibility is documented and verified so
  unsupported flows fail explicitly rather than implicitly degrading
- [ ] **CAP-04**: Capability negotiation remains extensible for a future GCS
  resumable adapter without breaking current adapter contracts

### Install and Release Confidence

- [ ] **RELEASE-01**: A fresh Phoenix adopter can install Rindle from the built
  package and complete the canonical upload-to-delivery path
- [ ] **RELEASE-02**: CI includes a package-consumer smoke path that validates
  installability from the built artifact rather than only from the repo source
- [ ] **RELEASE-03**: README and getting-started guidance match the canonical
  adopter path, including Repo ownership and upload capability constraints

## v1.x Requirements

### Additional Providers and Protocols

- **GCS-01**: Google Cloud Storage adapter implements a POST-then-PUT
  resumable upload flow behind explicit capability flags
- **TUS-01**: tus/resumable upload adapter supports resume-from-offset flows
  for long-running uploads

### Additional Media Domains

- **VIDEO-01**: FFmpeg- or Membrane-based video processor plugins support named
  derivatives without changing the image-first core
- **DOC-EXT-01**: PDF preview adapter is offered only with documented sandbox
  guidance

## Out of Scope

| Feature | Reason |
|---------|--------|
| Full GCS adapter in v1.1 | Keep v1.1 focused on capability design plus the highest-leverage S3-compatible path first |
| tus protocol in v1.1 | Multipart support is the nearer production need and fits current storage focus better |
| Broad non-S3 multipart parity | Provider-specific semantics differ too much to promise universal parity in one milestone |
| Admin LiveView UI | Trust is better increased by runtime correctness, provider confidence, and install proof first |
| New media families (video/audio/PDF) | Image-first remains the deliberate wedge until adopter/runtime boundaries are stronger |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ADOPT-01 | Phase 6 | Pending |
| ADOPT-02 | Phase 6 | Pending |
| ADOPT-03 | Phase 6 | Pending |
| ADOPT-04 | Phase 6 | Pending |
| MULT-01 | Phase 7 | Pending |
| MULT-02 | Phase 7 | Pending |
| MULT-03 | Phase 7 | Pending |
| MULT-04 | Phase 7 | Pending |
| CAP-01 | Phase 8 | Pending |
| CAP-02 | Phase 8 | Pending |
| CAP-03 | Phase 8 | Pending |
| CAP-04 | Phase 8 | Pending |
| RELEASE-01 | Phase 9 | Pending |
| RELEASE-02 | Phase 9 | Pending |
| RELEASE-03 | Phase 9 | Pending |

**Coverage:**
- v1.1 requirements: 15 total
- Mapped to phases: 15
- Unmapped: 0

---
*Requirements defined: 2026-04-28*
*Last updated: 2026-04-28 after milestone v1.1 initialization*
