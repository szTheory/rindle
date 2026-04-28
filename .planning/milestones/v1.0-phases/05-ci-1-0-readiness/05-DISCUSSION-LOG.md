# Phase 5: CI & 1.0 Readiness - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-04-26
**Phase:** 05-ci-1-0-readiness
**Mode:** assumptions
**Areas analyzed:** Telemetry emission backfill (scope), Contract lane (CI-06), Adopter lane (CI-08), Release lane (CI-09), Coverage + libvips (CI-03), Documentation structure (DOC-01..08)

## Critical Finding (Pre-Assumptions)

**Telemetry events are not actually emitted in `lib/`.**

REQUIREMENTS.md marks TEL-01..08 ✅ complete in Phase 3, but `grep -rn ":telemetry\." lib/` returns zero hits. Phase 3's `03-02-SUMMARY.md` only added "telemetry-friendly boundaries" — no `:telemetry.execute/3` calls were ever wired in. CI-06 (contract lane) cannot pass without backfilling emission. This finding expanded Phase 5 scope.

## Assumptions Presented

### Telemetry Emission Backfill
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Phase 5 backfills `:telemetry.execute/3` calls before authoring the contract lane | Confident | `grep ":telemetry\." lib/` returns 0 hits; only `mix.exs:62` has the dep declaration |

### Contract Lane (CI-06)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Implement under `test/rindle/contracts/` tagged `:contract`, run as `mix test --only contract` | Likely | Existing `test/rindle/contracts/behaviour_contract_test.exs`; tagged lanes already used (`:integration`, `:minio`) |
| Use `:telemetry.attach_many/4` to assert event names, required `profile`+`adapter` metadata, numeric measurements | Likely | Standard Elixir idiom; matches Phase 3 D-07/D-08 |

### Adopter Lane (CI-08)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| In-repo fixture at `test/adopter/canonical_app/` with adopter-owned Repo, runs as third CI job | Likely | PROJECT.md locks adopter-repo-first; `lib/rindle.ex` references `Rindle.Repo` directly in 5 places — adopter lane surfaces the leak |

### Release Lane (CI-09)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Manually-triggered (`workflow_dispatch` / tag-push only). `mix hex.publish --dry-run` + artifact inspection + post-publish parity diff | Likely | Current `ci.yml` uses zero `secrets.*` (fork-PR-safe); `mix.exs` already declares `package` + `licenses`; `@version 0.1.0-dev` indicates pre-1.0 |

### Coverage + libvips (CI-03)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `excoveralls` with 80% threshold via `coveralls.json`; quality lane installs `libvips-dev` via apt | Likely | STATE.md pending todo on libvips system dep; existing `ci.yml` runs bare `mix test` with no coverage; `lib/rindle/processor/image.ex` needs libvips |

### Documentation Structure (DOC-01..08)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `guides/` directory with one file per DOC-01..07; wired into `mix.exs docs/0` via `extras:` + `groups_for_extras:` | Likely | `mix.exs:81-83` already wires `extras: ["README.md"]`; standard ExDoc pattern |
| 5 domain schemas in `lib/rindle/domain/` need `@moduledoc`; `Rindle.Repo` gets `@moduledoc false` | Likely | grep audit identifies the gaps; adopter-repo-first stance dictates Repo invisibility |

### `phx_media_library` Study
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Out of scope for Phase 5; folds in only as a DOC-01 sanity check if material divergence is found | Confident | STATE.md todo is API-finalization-related; Phase 5 ships CI + docs, not API redesign |

## Corrections Made

### Telemetry gap → Scope expansion (high-impact decision)
- **Original assumption:** Phase 5 needs telemetry emission backfill before the contract lane can be wired
- **User selection:** Fold backfill into Phase 5 (Recommended)
- **Reason:** Pragmatic — keeps phase boundary intact; ships emission + verification in the same PR. Alternative (insert phase 3.1) would delay 1.0 without functional benefit.

### Adopter lane location
- **Original assumption:** In-repo fixture under `test/adopter/canonical_app/`
- **User selection:** In-repo fixture (Recommended) — confirmed
- **Reason:** Atomically gated with PRs, no drift, no cross-repo coordination overhead.

### Release lane trigger
- **Original assumption:** Manual / tag-push only
- **User selection:** Manual / tag-push only (Recommended) — confirmed
- **Reason:** Pre-1.0 with `0.1.0-dev` version; primary value is dry-run validation at release time. Fork PR safety preserved (no Hex API key leakage).

### Final assumptions check
- **User selection:** No, those all look right
- **Result:** Wrote CONTEXT.md with all assumptions as locked decisions plus the three corrections above.

## Auto-Resolved

Not applicable — no `--auto` flag used.

## External Research

Two topics were flagged as `Needs External Research` by the analyzer but were not pursued in this discussion:

1. `mix hex.publish --dry-run` exact behavior on a `0.1.0-dev` version string. **Routed to:** planner / phase-researcher to verify before wiring the release lane. Captured as a planner concern in CONTEXT.md D-12.
2. `phx_media_library v0.6.0` public API surface study. **Routed to:** deferred ideas in CONTEXT.md — not a Phase 5 blocker.
