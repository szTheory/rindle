# Phase 75: Merge-Blocking Proof Lanes - Research

**Researched:** 2026-05-27
**Domain:** CI-03 — dedicated merge-blocking `proof` job in `ci.yml`
**Status:** Complete (synthesized from 75-CONTEXT.md + codebase inspection)

## Summary

Phase 75 closes the v1.15 **automated CI proof path** gap: `docs_parity_test.exs` and
`batch_owner_erasure_task_test.exs` run locally and in advisory `quality` coveralls, but
are not explicit merge-blocking steps. A dedicated `proof` job (Elixir 1.17/OTP 27, Postgres,
no MinIO) is the correct lane — preserves Phase 71 advisory policy for credo/dialyzer/coveralls.

## Current State

| Artifact | Today |
|----------|-------|
| `ci.yml` `adopter` | Merge-blocking; includes bash grep for README/getting_started AV strings (lines ~521–574) — partial doc subset, not full parity suite |
| `docs_parity_test.exs` | 20 tests; includes TusPlug moduledoc lock (Phase 76); not a named CI step |
| `batch_owner_erasure_task_test.exs` | PROOF-06; uses `DataCase` — needs Postgres |
| `RUNNING.md` | Matrix lists `adopter` as "Canonical lifecycle + doc parity" — inaccurate after this phase |

## Recommended Wiring

```yaml
proof:
  name: Proof
  needs: quality
  # Postgres only — copy service block from `contract` job
  # Elixir 1.17 / OTP 27 only (no matrix)
  steps:
    - mix test test/install_smoke/docs_parity_test.exs
    - mix test test/rindle/batch_owner_erasure_task_test.exs
```

Insert after `contract` job, before `package-consumer` (logical grouping with other fast gates).

## Rejected Alternatives

See 75-CONTEXT.md — Options A (adopter), B (quality), D (integration), E (hybrid) all rejected.

## Key Files

- `.github/workflows/ci.yml` — add `proof` job; remove adopter grep step
- `RUNNING.md` — matrix row + post-merge checklist
- `test/install_smoke/docs_parity_test.exs` — assert `proof` documented (D-04)

## Dependencies

- **Phase 76 complete** — `docs_parity_test` includes TusPlug test; proof job runs full file
- **Phase 77 complete** — planning truth (not blocking CI work)

## Risks

| Risk | Mitigation |
|------|------------|
| Branch protection missing `Proof` | RUNNING.md post-merge checklist (D-01 pattern) |
| Duplicate test runs (proof + advisory coveralls) | Acceptable — ~26 fast tests |
| Adopter grep removal drops AV onboarding guard | Full `docs_parity_test` already asserts doctor/facade path |

## Nyquist

New automated gates: `mix test` for both proof targets in dedicated CI job + docs_parity RUNNING.md lock.
