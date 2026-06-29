# Phase 112 — Deferred Items

Out-of-scope discoveries logged during execution (not fixed; per the executor SCOPE BOUNDARY rule —
only issues DIRECTLY caused by the current task's changes are auto-fixed).

## Plan 01 (112-01)

### Pre-existing `actionlint` findings in `ci.yml` (NOT introduced by Phase 112)

`actionlint .github/workflows/ci.yml` exits 1 on 7 pre-existing findings that are byte-identical
before and after the Plan 01 changes (verified by running actionlint against the pre-Task-2 base
`ci.yml` — same 7 findings, same exit 1). The new `adoption-demo-e2e-smoke` job (lines ~998–1107)
introduces ZERO new findings. These belong to unrelated jobs and predate Phase 112:

| Location | Rule | Note |
|----------|------|------|
| `ci.yml:88` (×2) | SC2251 (info) | `! ...` skips errexit in the cohort-demo-smoke-adjacent script step |
| `ci.yml:165` | SC2209 (warning) | `MIX_ENV=test mix doctor ...` parsed as assignment by shellcheck |
| `ci.yml:293` | SC2209 (warning) | `MIX_ENV=test mix deps.get --no-optional-deps` |
| `ci.yml:296` | SC2209 (warning) | `MIX_ENV=test mix compile --no-optional-deps ...` |
| `ci.yml:411` | expression | `matrix.elixir` referenced in a job without a matrix |
| `ci.yml:679` | expression | `matrix.elixir` referenced in a job without a matrix |

Status: deferred — out of Phase 112 scope (PR↔main gate shift-left). Phase 112's Task 2 acceptance
is "the smoke job introduces no new actionlint findings", which holds.
