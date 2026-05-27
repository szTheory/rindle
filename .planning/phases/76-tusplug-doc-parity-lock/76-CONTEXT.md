# Phase 76: TusPlug Doc Parity Lock - Context

**Gathered:** 2026-05-27 (gap closure research)
**Status:** Ready for planning
**Execute:** After Phase 77; before Phase 75

<domain>
## Phase Boundary

Close TRUTH-04 **integration depth** gap: TusPlug moduledoc scope has no automated regression lock.

**In scope (TRUTH-05):**
- Interpolate `@tus_extensions` in `@moduledoc` (move attribute above moduledoc)
- Add `Code.fetch_docs/1` contract test in `docs_parity_test.exs`
- Token asserts + stale-phrase refutes (Phase 70/74 TRUTH pattern)

**Out of scope:**
- New test file (`tus_plug_docs_parity_test.exs`) — D-18 pattern keeps TRUTH in `docs_parity_test.exs`
- OPTIONS cross-call inside docs_parity (runtime truth stays in `tus_plug_test.exs`)
- Credo custom check for moduledoc parity
- Public `tus_extensions/0` API for test-only needs
- Phase 75 CI wiring (ships standalone; advisory coveralls includes test immediately)

</domain>

<research>
## Research Synthesis

**Recommended blend:** `Code.fetch_docs/1` test (B) + `@tus_extensions` interpolation in moduledoc (C). Home is `docs_parity_test.exs` (A pattern).

**Prior art in repo:**
- `test/rindle/api_surface_boundary_test.exs` — `fetch_docs!/1`, `moduledoc!/1`, `normalize_whitespace/1`
- `test/rindle/tus_plug_test.exs` — OPTIONS header asserts exact extension string

**External lessons:**
- tus-js-client: honest extension scope in docs (creation/checksum/etc.) — Rindle prose is good; gap is regression lock
- accrue: separate docs-contract CI lane — Rindle consolidates in `docs_parity_test.exs` + future `proof` job

### Test design

**Test name:** `"TusPlug moduledoc matches shipped tus scope"`

**Positive asserts (tokens, not full prose):**
- `@expected_tus_extensions` verbatim in normalized moduledoc
- Individual extension tokens; `local` + `s3`; `PATCH`/`DELETE` with `implemented`
- Plug contract: `no Phoenix`, `@behaviour Plug`
- Deployment tokens: `sticky`, `node-affinity` or `node-local`, `:tus_tail_missing`

**Negative refutes:**
```elixir
refute Regex.match?(~r/Local only/i, moduledoc)
refute moduledoc =~ "Phase 42"
refute Regex.match?(~r/PATCH\s*\|\s*—/, moduledoc)
refute Regex.match?(~r/DELETE\s*\|\s*—/, moduledoc)
```

**Lib change:** Move `@tus_extensions` above `@moduledoc`; replace hardcoded string with `` `#{@tus_extensions}`. ``

</research>

<decisions>
## Locked Decisions

- **D-01:** Assert contract tokens and refutes — not paragraph wording (brittleness mitigation).
- **D-02:** Division of labor: `tus_plug_test` = runtime OPTIONS; `docs_parity_test` = moduledoc advertises same scope.
- **D-03:** Ship without waiting for Phase 75 CI job.

</decisions>

<tasks>
## Expected Tasks (2)

1. **76-01** — TusPlug moduledoc interpolation + `docs_parity_test.exs` fetch_docs contract test
2. **76-02** — Phase verification + audit gap TRUTH-04 integration note closure

</tasks>
