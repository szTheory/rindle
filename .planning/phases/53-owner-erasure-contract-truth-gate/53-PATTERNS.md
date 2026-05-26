# Phase 53: owner-erasure-contract-truth-gate - Pattern Map

**Mapped:** 2026-05-26
**Files analyzed:** 5
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/rindle.ex` | facade docs/types | request-response | `lib/rindle.ex` | exact |
| `test/rindle/api_surface_boundary_test.exs` | test | docs boundary | `test/rindle/api_surface_boundary_test.exs` | exact |
| `guides/user_flows.md` | guide | support truth | `guides/user_flows.md` | exact |
| `test/install_smoke/docs_parity_test.exs` | test | docs parity | `test/install_smoke/docs_parity_test.exs` | exact |
| `.planning/ROADMAP.md` | planning config | roadmap structure | `.planning/ROADMAP.md` | exact-structure |

## Pattern Assignments

### `lib/rindle.ex`

- Analog: `lib/rindle.ex`
- Reuse:
  - top-level `@moduledoc` sections for public lifecycle narrative
  - `@typedoc` + `@type` declarations near the facade root for public contract
    vocabulary
  - explicit "this does not do X" wording already used throughout the facade

**Concrete seams to copy**

- Public tagged-result typedoc pattern near `storage_result`
- Narrow public-lifecycle wording used by `verify_completion/2`,
  `attach/4`, and `detach/3`

### `test/rindle/api_surface_boundary_test.exs`

- Analog: `test/rindle/api_surface_boundary_test.exs`
- Reuse:
  - `Code.fetch_docs/1` for moduledoc assertions
  - boundary tests that freeze visible public claims without requiring runtime
    execution of future behavior

**Concrete seams to copy**

- existing `visible_function_doc?/3` and moduledoc helper style
- string-level assertions like the `Rindle.LiveView` moduledoc freeze tests

### `guides/user_flows.md`

- Analog: `guides/user_flows.md`
- Reuse:
  - job-story narrative
  - `>` block notes for narrow caveats
  - "Where Rindle is headed" style wording that distinguishes shipped truth
    from roadmap direction

**Concrete seams to copy**

- Story 5 account-deletion note near the `detach/3` walkthrough
- concise support-truth language: what is supported now, what remains a
  workaround, what is deferred

### `test/install_smoke/docs_parity_test.exs`

- Analog: `test/install_smoke/docs_parity_test.exs`
- Reuse:
  - `setup_all` file-read pattern
  - exact-string parity assertions against guide text
  - negative assertions to prevent drift back to the old recommended story

**Concrete seams to copy**

- multi-document `for doc <- [...]` loops
- `refute Regex.match?/2` checks for previously stale wording

### `.planning/ROADMAP.md`

- Analog: `.planning/ROADMAP.md`
- Reuse:
  - `### Phase {N}: ...` detail headings so `gsd-sdk query roadmap.get-phase`
    can parse the active phase
  - phase row + success-criteria layout already used elsewhere in the file

## Anti-Patterns

- Do not export runtime owner-erasure functions in Phase 53 just to make tests
  pass.
- Do not hide the three report buckets behind generic names.
- Do not let docs-parity tests only assert the new wording; also assert the old
  long-term recommendation is gone.
- Do not keep malformed roadmap detail headings once the phase is active.
