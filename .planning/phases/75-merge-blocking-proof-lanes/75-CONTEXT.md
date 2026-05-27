# Phase 75: Merge-Blocking Proof Lanes - Context

**Gathered:** 2026-05-27 (gap closure research)
**Status:** Ready for planning
**Execute:** Last (after Phases 77 and 76)

<domain>
## Phase Boundary

Close v1.15 **automated CI proof path** gap: high-signal proof/parity tests run locally but not as explicit merge-blocking CI steps.

**In scope (CI-03):**
- New dedicated merge-blocking `proof` job in `ci.yml`
- Run `docs_parity_test.exs` + `batch_owner_erasure_task_test.exs` explicitly
- Remove adopter partial doc grep (superseded by full parity suite)
- Update `RUNNING.md` CI lane severity matrix + post-merge checklist

**Out of scope:**
- Making coveralls, credo, dialyzer, or doctor merge-blocking (Phase 71 policy)
- `release.yml` gate-ci-green BYPASS removal
- MinIO/FFmpeg in proof job (not needed for these tests)
- Running proof job on both Elixir matrix versions (1.17/27 only, like contract/adopter)

</domain>

<research>
## Research Synthesis — Coherent Recommendation

**Approach C: dedicated `proof` job** (merge-blocking, `needs: quality`, Postgres, Elixir 1.17/OTP 27).

| Target | Action |
|--------|--------|
| `docs_parity_test.exs` | `proof` job — blocking step |
| `batch_owner_erasure_task_test.exs` | `proof` job — blocking step |
| Adopter bash grep (~521–574) | **Delete** — redundant subset |
| `mix coveralls` in quality | **Unchanged advisory** |

### Why not alternatives

| Option | Why rejected for Rindle |
|--------|-------------------------|
| A — both in adopter | PROOF-06 is operator proof, not adopter lifecycle; inflates heavy MinIO lane |
| B — both in quality | 2× matrix cost; blurs compile gate; making coveralls blocking reverses Phase 71 |
| D — integration job | Wrong ownership; wastes MinIO on file-read/mix-task tests |
| E — hybrid adopter+integration | Splits audit closure; mislabels failure triage |

### Rationale (DNA-aligned)

- **CI is contract surface** — named `Proof` lane matches audit language and accrue/sigra/scrypath layered proof pattern
- **Targeted blocking, full suite advisory** — Phase 71 policy preserved; pitfall closures block, broad regression signals stay advisory
- **Correct lane semantics:** docs parity = docs contract; PROOF-06 = day-2 operator proof; adopter = host lifecycle
- **Cost:** ~26 fast tests; no libvips/FFmpeg/MinIO; single Elixir version like sibling jobs

### Risks / mitigations

| Risk | Mitigation |
|------|------------|
| Branch protection missing `Proof` | RUNNING.md post-merge checklist (Phase 71 D-12 pattern) |
| Duplicate runs (proof + advisory coveralls) | Acceptable — cheap tests, high signal |
| Mix-task flakiness | PROOF-06 already hermetic (CountingFailingTxnRepo, Mix.Shell.Process) |

</research>

<decisions>
## Locked Decisions

- **D-01:** Job name `proof`, display name `Proof` — stable for branch protection.
- **D-02:** Copy Postgres service setup from `contract` job; no MinIO.
- **D-03:** Adopter job header: "canonical adopter lifecycle" only (remove doc parity claim).
- **D-04:** Optional: extend `docs_parity_test.exs` to assert RUNNING.md mentions `proof` job (TRUTH lock) — include if phase scope allows.

</decisions>

<tasks>
## Expected Tasks (4)

1. **75-01** — Add `proof` job to `ci.yml` (two merge-blocking test steps)
2. **75-02** — Remove adopter partial doc grep; update adopter job comments
3. **75-03** — Update `RUNNING.md` severity matrix + post-merge checklist
4. **75-04** — Local verify + optional docs_parity RUNNING.md assertion

</tasks>
