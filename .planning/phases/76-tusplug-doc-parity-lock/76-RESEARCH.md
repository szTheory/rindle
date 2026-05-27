# Phase 76: TusPlug Doc Parity Lock - Research

**Researched:** 2026-05-27
**Domain:** TRUTH-05 — automated TusPlug moduledoc regression lock via `Code.fetch_docs/1`
**Confidence:** HIGH

---

## Summary

Phase 74 fixed TusPlug `@moduledoc` prose manually (TRUTH-04) but left **no automated
lock** — the v1.15 audit records this as an integration gap (`tus_plug.ex moduledoc →
docs_parity_test`). Phase 76 closes **TRUTH-05** by:

1. Moving `@tus_extensions` above `@moduledoc` and interpolating it (single source of truth
   with OPTIONS `tus-extension` header at line 192).
2. Adding a `Code.fetch_docs/1` contract test in `docs_parity_test.exs` (token asserts +
   stale-phrase refutes — Phase 70/74 TRUTH pattern).

**No new test file** — D-18 keeps TRUTH gates in `docs_parity_test.exs`. Runtime OPTIONS
truth stays in `tus_plug_test.exs` (division of labor D-02).

---

## Current State (confirmed in repo)

| Artifact | State | Gap |
|----------|-------|-----|
| `lib/rindle/upload/tus_plug.ex` | Moduledoc accurate post-74; `@tus_extensions` at line 87 **below** moduledoc | Hardcoded extension string on line 26 duplicates attribute |
| `test/rindle/upload/tus_plug_test.exs` | OPTIONS asserts exact header string | Runtime truth — keep |
| `test/install_smoke/docs_parity_test.exs` | Nine-task ops parity; no TusPlug moduledoc gate | Missing TRUTH-05 lock |
| `test/rindle/api_surface_boundary_test.exs` | `fetch_docs!/1`, `moduledoc!/1`, `normalize_whitespace/1` | Copy pattern for docs_parity |

---

## Lib Change: Attribute Interpolation

Elixir requires module attributes referenced in `@moduledoc` to be defined **before** the
moduledoc. Current order is wrong for interpolation:

```elixir
# BEFORE (current)
@moduledoc """
...
`creation,expiration,termination,checksum,creation-defer-length,concatenation`.
"""
@tus_extensions "creation,expiration,termination,checksum,creation-defer-length,concatenation"

# AFTER (target)
@tus_extensions "creation,expiration,termination,checksum,creation-defer-length,concatenation"
@moduledoc """
...
`#{@tus_extensions}`.
"""
```

**Invariant:** `@tus_extensions` value unchanged; OPTIONS header still uses same attribute.

---

## Test Design

**Test name:** `"TusPlug moduledoc matches shipped tus scope"`

**Module under test:** `Rindle.Upload.TusPlug`

**Helpers:** Add private `fetch_docs!/1`, `moduledoc!/1`, `normalize_whitespace/1` to
`docs_parity_test.exs` (mirror `api_surface_boundary_test.exs` lines 267–292).

**Positive asserts (tokens, not full prose):**

- `@expected_tus_extensions` verbatim in normalized moduledoc
- Individual extension tokens: `creation`, `expiration`, `termination`, `checksum`,
  `creation-defer-length`, `concatenation`
- Backing tokens: `local` + `s3` (case-insensitive via normalized doc)
- Methods: `PATCH` + `implemented`, `DELETE` + `implemented`
- Plug contract: `no Phoenix`, `@behaviour Plug`
- Deployment: `sticky`, `node-affinity` or `node-local`, `:tus_tail_missing`

**Negative refutes:**

```elixir
refute Regex.match?(~r/Local only/i, moduledoc)
refute moduledoc =~ "Phase 42"
refute Regex.match?(~r/PATCH\s*\|\s*—/, moduledoc)
refute Regex.match?(~r/DELETE\s*\|\s*—/, moduledoc)
```

**Out of scope:** OPTIONS cross-call inside docs_parity (runtime stays in `tus_plug_test.exs`).

---

## Prior Art

| Phase | Pattern | Reuse |
|-------|---------|-------|
| 74-01 | TusPlug moduledoc truth + docs_parity nine-task gate | Test home + token assert style |
| 70 | Thin index; no flag-table duplication | Keep test token-based |
| `api_surface_boundary_test.exs` | `Code.fetch_docs/1` + moduledoc extraction | Helper copy |

---

## Phase 76-02 Scope (verification + audit)

After 76-01 lands:

- Create `76-VERIFICATION.md` with TRUTH-05 evidence
- Mark `TRUTH-05` `[x]` in `.planning/REQUIREMENTS.md`
- Resolve v1.15 audit integration gap entry `TRUTH-04` (moduledoc → docs_parity) — note
  closed by TRUTH-05 / Phase 76; do **not** touch CI-01 or PROOF-06 gaps (Phase 75)

---

## Pitfalls

1. **Attribute order** — `@tus_extensions` must precede `@moduledoc` or compile fails.
2. **Duplicating OPTIONS test** — do not call TusPlug from docs_parity; runtime in tus_plug_test.
3. **Brittle prose asserts** — token/refute only (D-01).
4. **New test file** — forbidden by D-18; home is `docs_parity_test.exs`.
5. **Phase 75 CI wiring** — ship standalone; advisory coveralls picks up test immediately.

---

## Validation Architecture

Nyquist enabled. Phase 76 adds one new automated gate:

| Gate | Command | When |
|------|---------|------|
| TusPlug moduledoc parity | `mix test test/install_smoke/docs_parity_test.exs` | After 76-01 tasks |
| Compile sanity | `mix compile --force` | After lib attribute move |
| Regression | `mix test test/rindle/upload/tus_plug_test.exs` | Optional sanity (no handler changes) |

Plan 76-02 verification: grep REQUIREMENTS for `[x] **TRUTH-05**`; audit gap resolved.

---

## RESEARCH COMPLETE
