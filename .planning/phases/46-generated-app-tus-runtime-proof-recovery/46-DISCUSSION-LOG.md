# Phase 46: generated-app-tus-runtime-proof-recovery - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution
> agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-24
**Phase:** 46-generated-app-tus-runtime-proof-recovery
**Mode:** assumptions
**Areas analyzed:** recovery scope, proof authority, stale-vs-current evidence,
failure-handling posture

## Assumptions Presented

### Recovery scope
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 46 should stay focused on proof recovery and durable re-verification, not tus redesign. | Likely | `.planning/ROADMAP.md`, `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-CONTEXT.md`, `.planning/phases/42-tus-protocol-edge-bare-plug/42-CONTEXT.md` |

### Proof authority
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The real package-consumer lane `bash scripts/install_smoke.sh tus` remains the authoritative `TUS-14` proof and must not be replaced with fake-only coverage. | Confident | `scripts/install_smoke.sh`, `test/install_smoke/generated_app_smoke_test.exs`, `test/install_smoke/support/generated_app_helper.ex`, `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-03-PLAN.md` |
| The package-consumer proof contract still depends on a real interrupted upload plus resume against MinIO, with downstream asset convergence assertions. | Confident | `test/install_smoke/support/generated_app_helper.ex`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md` |

### Stale-vs-current evidence
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The earlier `ECONNRESET` / `socket hang up` report in `44-VERIFICATION.md` is likely stale because the current tree contains a passing generated-app tus artifact and a newer validation note saying the blocker was superseded. | Likely | `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md`, `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VALIDATION.md`, `tmp/install_smoke_tus_last_run.json` |
| Phase 46 should begin with a fresh rerun and only patch if that rerun is red. | Likely | `tmp/install_smoke_tus_last_run.json`, `.planning/PROJECT.md`, `.planning/STATE.md` |

### Failure handling
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| If the proof is still red, the existing Node/Elixir smoke breadcrumbs are the right root-cause surface and should be reused rather than inventing a new debug path. | Confident | `scripts/install_smoke.sh`, `test/install_smoke/support/generated_app_helper.ex`, `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-04-PLAN.md` |

## Corrections Made

No corrections. User confirmed the assumptions as presented.

## External Research

None. The phase decisions were grounded in current in-repo artifacts, prior
phase context, and the persisted generated-app tus proof evidence.
