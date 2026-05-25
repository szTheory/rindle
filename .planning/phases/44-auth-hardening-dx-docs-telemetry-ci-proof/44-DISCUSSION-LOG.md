# Phase 44: Auth Hardening, DX, Docs, Telemetry, CI Proof - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution
> agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-23
**Phase:** 44-auth-hardening-dx-docs-telemetry-ci-proof
**Mode:** assumptions + targeted research
**Areas analyzed:** resume authorization, public error contract and operator DX,
telemetry contract, generated-app proof, project-level decision preference

## Assumptions Presented

### Resume authorization
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| HMAC-signed tus URLs remain the default resume authority, with same-user resume as an optional additive hook. | Confident | `lib/rindle/upload/tus_plug.ex`, `guides/resumable_uploads.md`, `.planning/REQUIREMENTS.md`, `.planning/research/v1.8/TUS-RESEARCH.md` |
| Actor extraction should remain adopter-defined through the mount/auth pipeline rather than standardized by Rindle. | Confident | `lib/rindle/upload/tus_plug.ex`, `prompts/gsd-rindle-elixir-oss-dna.md` |

### Public contract and operator DX
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| `Rindle.Error` should stay narrow and fix-oriented while `TusPlug` keeps protocol-native HTTP semantics. | Confident | `lib/rindle/error.ex`, `lib/rindle/upload/tus_plug.ex`, `.planning/ROADMAP.md` |
| `mix rindle.doctor` and the guide should absorb cross-component setup drift instead of a wider public tus atom taxonomy. | Confident | `lib/rindle/ops/runtime_checks.ex`, `lib/mix/tasks/rindle.doctor.ex`, `guides/resumable_uploads.md`, `prompts/gsd-rindle-elixir-oss-dna.md` |
| POLISH-02 should be selective, not a blanket Phase 35 cleanup pass. | Likely | `.planning/milestones/v1.6-phases/35-signed-webhook-plug-idempotent-ingest/35-REVIEW.md`, `.planning/ROADMAP.md` |

### Telemetry and proof
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| tus should reuse the existing `[:rindle, :upload, :resumable, *]` namespace with a topology discriminator in metadata. | Confident | `lib/rindle/upload/resumable_telemetry.ex`, `test/rindle/contracts/telemetry_contract_test.exs`, `.planning/REQUIREMENTS.md` |
| One real generated-app interrupted-upload proof should remain merge-blocking. | Confident | `test/install_smoke/support/generated_app_helper.ex`, `test/install_smoke/generated_app_smoke_test.exs`, `.planning/ROADMAP.md` |

### Project-level decision policy
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The maintainer preference is already “research first, then decide by default”; it should be made durable in `PROJECT.md` and reflected in bootstrap material. | Confident | `.planning/STATE.md`, `prompts/gsd-rindle-gsd-bootstrap-brief.md`, `prompts/gsd-rindle-elixir-oss-dna.md` |

## Corrections Made

No corrections — the user asked to deepen the research, follow the recommendations, and proceed.

## External Research

- tus protocol: creation/expiration/termination semantics, `Upload-Expires`, and
  `404`/`410` guidance validated against `tus.io`.
- Phoenix LiveView: external uploader posture and UpChunk integration validated
  against `hexdocs.pm/phoenix_live_view`.
- Rails Active Storage: direct-upload/analyzer/preview posture and explicit
  cleanup warnings validated against `guides.rubyonrails.org` and
  `api.rubyonrails.org`.
- Shrine: atomic helpers, instrumentation, and direct-upload/operator patterns
  validated against `shrinerb.com`.
- Mux: direct-upload bearer-URL and server-issued endpoint posture validated
  against `mux.com`.
- Elixir library guidance: stable public docs/contracts and dependency guidance
  validated against `hexdocs.pm/elixir`.
