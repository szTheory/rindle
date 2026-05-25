# Phase 50: Phoenix Proof + Parity Closure - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `50-CONTEXT.md` — this log preserves the analysis.

**Date:** 2026-05-25T13:35:26Z
**Phase:** 50-phoenix-proof-parity-closure
**Mode:** assumptions + subagent research
**Areas analyzed:** package-consumer proof shape, parity gate scope, public contract semantics, shift-left decision posture

## Assumptions Presented

### Package-consumer proof shape
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Extend the existing generated-app `:tus` install-smoke lane into the canonical Phoenix / LiveView proof rather than inventing a second proof lane. | Confident | `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `test/install_smoke/generated_app_smoke_test.exs`, `test/install_smoke/support/generated_app_helper.ex`, `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md` |
| Keep the current bare `TusPlug` drop-and-resume proof as a lower-level sub-proof under the new Phoenix-facing proof. | Likely | `test/install_smoke/support/generated_app_helper.ex`, `.planning/phases/49-liveview-tus-productization/49-CONTEXT.md` |

### Parity gate scope
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| The correct parity scope is guide + helper + executable proof harness/report, not docs-only parity. | Confident | `.planning/REQUIREMENTS.md`, `test/install_smoke/phoenix_tus_truth_parity_test.exs`, `test/rindle/live_view_test.exs`, `test/install_smoke/support/generated_app_helper.ex` |
| Broad generated-app source snapshot parity would be high-noise and non-idiomatic for this repo. | Likely | `test/install_smoke/support/generated_app_helper.ex`, `test/install_smoke/docs_parity_test.exs`, `.github/workflows/ci.yml` |

### Public contract semantics
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| The package-consumer proof must exercise `allow_tus_upload/4`, `uploader: "RindleTus"`, and completion through `consume_uploaded_entries/3` / `verify_completion/2`, not only raw tus transport. | Confident | `guides/resumable_uploads.md`, `lib/rindle/live_view.ex`, `.planning/phases/49-liveview-tus-productization/49-CONTEXT.md`, `.planning/REQUIREMENTS.md` |
| Honest state boundaries (`uploading`, `verifying`, `ready`, `error`) belong in proof artifacts, not only in guide prose. | Likely | `guides/resumable_uploads.md`, `.planning/ROADMAP.md`, `.planning/phases/49-liveview-tus-productization/49-CONTEXT.md` |

### Shift-left decision posture
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Phase 50 should encode “one coherent recommendation set by default” directly in context so planning/execution do not reopen local proof/doc choices. | Confident | `.planning/PROJECT.md`, `prompts/gsd-rindle-elixir-oss-dna.md`, `prompts/gsd-rindle-gsd-bootstrap-brief.md` |

## Corrections Made

No corrections — the user explicitly requested analysis of all areas with one coherent recommendation set rather than a correction loop.

## Subagent Findings

### Proof harness options
- Recommended extending the existing generated-app `:tus` lane into the Phoenix /
  LiveView proof.
- Rejected a second Phoenix-specific generated-app lane as duplication-heavy.
- Rejected an in-repo-only harness as insufficient for the package-consumer proof requirement.

### Parity options
- Recommended narrow-contract parity across guide + helper + executable proof
  harness/report.
- Rejected docs-only parity as too weak.
- Rejected broad generated-app source snapshot parity as high-noise and
  non-idiomatic for the current test strategy.

### Prompt-corpus synthesis
- Reinforced a narrow, opinionated, auditable proof scope.
- Reinforced “truth over aspiration,” “one canonical path,” honest state
  vocabulary, and agent-decided local ergonomics unless blast radius is high.

## External Research

- **Phoenix LiveView uploads:** the idiomatic Phoenix layer is a thin upload
  contract centered on `allow_upload` / `consume_uploaded_entries`, reactive
  progress/error handling, and explicit external-upload ownership rather than a
  hidden abstraction. Source: https://hexdocs.pm/phoenix_live_view/uploads.html
- **Rails Active Storage:** useful lessons are lazy representation processing,
  persistent tracking of processed variants, background purging via
  `purge_later`, and warnings against arbitrary transform inputs. Source:
  https://guides.rubyonrails.org/active_storage_overview.html
- **Shrine:** useful lessons are concurrency-safe atomic promotion/persistence
  checks and explicit derivative processing/instrumentation instead of magical
  attachment mutation. Sources:
  https://shrinerb.com/docs/plugins/atomic_helpers
  https://shrinerb.com/docs/plugins/derivatives
- **Spatie Laravel Media Library:** good DX lessons are queued conversions by
  default and first-class responsive images with built-in tiny placeholders.
  Sources:
  https://spatie.be/docs/laravel-medialibrary/v11/converting-images/defining-conversions
  https://spatie.be/docs/laravel-medialibrary/v11/responsive-images/getting-started-with-responsive-images
- **imgproxy:** the security lesson remains to sign transformation URLs instead
  of exposing arbitrary unsigned transform surfaces. Source:
  https://docs.imgproxy.net/usage/signing_url
