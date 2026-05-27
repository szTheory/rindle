---
phase: 75
verified: 2026-05-27T20:30:00Z
status: passed
requirements: [CI-03]
---

# Phase 75 Verification

## Goal

Close the v1.15 automated CI proof path gap with a dedicated merge-blocking `proof` job
running docs parity and operator proof tests explicitly in CI.

## Success criteria

| Criterion | Status | Evidence |
|-----------|--------|----------|
| `proof` job in ci.yml with both test steps | **pass** | `grep -q '^  proof:' .github/workflows/ci.yml`; steps for `docs_parity_test.exs` and `batch_owner_erasure_task_test.exs` |
| Adopter partial doc grep removed | **pass** | `! grep -q 'Verify AV onboarding docs stay on the public facade path' .github/workflows/ci.yml` |
| RUNNING.md matrix + checklist updated | **pass** | `proof` row merge-blocking; post-merge checklist includes `Proof` |
| Quality advisory policy unchanged | **pass** | `continue-on-error: true` remains on coveralls/dialyzer/credo in quality job only |
| CI-03 satisfied | **pass** | All five plans complete; local tests green |

## Requirement coverage

- **CI-03** — **satisfied**: dedicated merge-blocking `proof` job; adopter grep removed; RUNNING.md updated; docs_parity_test locks proof lane documentation.

## Integration gap closure

v1.15 audit gaps closed by **CI-03 (Phase 75)**:

- **CI-01** (docs_parity → ci): full `docs_parity_test.exs` now runs in merge-blocking `proof` job instead of partial adopter grep.
- **PROOF-06** (batch test → ci): `batch_owner_erasure_task_test.exs` explicit merge-blocking step in `proof` job.
- **flows** "Automated CI proof path": resolved — proof/parity tests no longer advisory-only or partial grep.

## Commands run

```bash
grep -q '^  proof:' .github/workflows/ci.yml
mix test test/install_smoke/docs_parity_test.exs          # 21 tests, 0 failures
mix test test/rindle/batch_owner_erasure_task_test.exs    # 7 tests, 0 failures
```

## Human verification

None required.
