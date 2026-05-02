# Phase 21: verify-02-hexdocs-reachability-probe - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-02T00:59:01Z
**Phase:** 21-verify-02-hexdocs-reachability-probe
**Mode:** assumptions
**Areas analyzed:** Workflow placement, Probe contract, Retry and backoff, Verification and documentation

## Assumptions Presented

### Workflow placement
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add the hexdocs reachability check as its own step inside `public_verify`, after `Wait for Hex.pm index (post-publish)` and before or alongside `Verify public Hex.pm artifact`. | Confident | `.planning/ROADMAP.md`, `.github/workflows/release.yml`, `scripts/public_smoke.sh` |

### Probe contract
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Probe `https://hexdocs.pm/rindle/$VERSION` with redirect-following public HTTP and fail on final non-2xx status. | Confident | `.planning/ROADMAP.md`, `.planning/v1.3-MILESTONE-AUDIT.md`, live `curl` checks on `https://hexdocs.pm/rindle/0.1.4` and `https://hexdocs.pm/rindle` (2026-05-01) |
| Use `GET`, not `HEAD`, as the default probe method. | Confident | Live `curl` checks showed the docs endpoints return `301` to `/index.html`; a non-following or HEAD-only check risks false negatives. |

### Retry and backoff
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Keep the docs probe aligned to the existing 5-minute / 15-second Hex index propagation window rather than introducing a different timeout policy. | Confident | `.planning/ROADMAP.md`, `.github/workflows/release.yml`, `.planning/phases/20-v1.3-verification-and-metadata-closure/20-CONTEXT.md` |

### Verification and documentation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Assert the probe through existing install-smoke parity tests, not through a live network test. | Confident | `.planning/ROADMAP.md`, `test/install_smoke/release_docs_parity_test.exs`, `test/install_smoke/package_metadata_test.exs`, `test/install_smoke/hex_release_exists_test.exs` |
| Update `guides/release_publish.md` in the same parity style as prior release changes so the workflow and runbook remain mechanically aligned. | Confident | `guides/release_publish.md`, `test/install_smoke/release_docs_parity_test.exs`, `.planning/phases/16-live-publish-execution-and-post-publish-verification/16-CONTEXT.md` |

## Corrections Made

No corrections — all assumptions confirmed.
