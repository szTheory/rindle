# Phase 12: Public Verification and Release Operations - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-04-28
**Phase:** 12-public-verification-and-release-operations
**Mode:** assumptions
**Areas analyzed:** Public Verification Execution, Verification Environment Isolation, Release Rollback Mechanics, Runbook Distribution Strategy

## Assumptions Presented

### Public Verification Execution
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| The consumer verification step will fetch Rindle from the public Hex.pm registry via standard `mix deps.get` network resolution, completely replacing the local `path:` dependency override used in current smoke tests. | Confident | `test/install_smoke/generated_app_smoke_test.exs` |

### Verification Environment Isolation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| The post-publish verification will run in a pristine environment without the `HEX_API_KEY` or local repository state to simulate an anonymous user. | Likely | `.github/workflows/release.yml` |

### Release Rollback Mechanics
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Package rollback and revert procedures will be manual maintainer actions documented in the runbook, rather than automated CI rollback jobs. | Likely | `guides/release_publish.md` |

### Runbook Distribution Strategy
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| The updated maintainer runbook (including rollback paths) will continue to be shipped as a public HexDoc page, but actively fenced off from the canonical adopter onboarding flow. | Confident | `scripts/assert_release_docs_html.sh` |

## Corrections Made

No corrections — all assumptions confirmed.

## External Research

- Hex.pm Indexing Delay: Hex CDN takes 1-5 minutes to index. Verification CI step *must* implement a polling/retry mechanism. (Source: Fastly/Hex docs)
- Hex.pm Revert Constraints: 1-hour window for revert (24h for first release); version CAN be reused if reverted in time. Manual rollback is confirmed viable. (Source: Hexdocs)
