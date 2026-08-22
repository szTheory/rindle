# Requirements: Rindle v1.24 Core Clarity & Quality Ratchet

**Defined:** 2026-08-22
**Core Value:** Media, made durable.

## v1.24 Requirements

### Truthful Quality Signals

- [x] **SIGNAL-01**: Maintainers receive a blocking contract-suite result for deterministic public
  contract and documentation parity failures, while environment-dependent AV checks declare and prove
  their prerequisites instead of being hidden by blanket advisory status.

- [x] **SIGNAL-02**: Maintainers can run the documentation doctor and see actual public module,
  function, and spec coverage meet the repository's enforced ratchet; the gate tests measured health,
  not merely configured threshold values.

- [x] **SIGNAL-03**: Maintainers receive blocking Credo feedback for warnings, excessive complexity or
  nesting, and public docs/spec drift, while low-value style preferences remain explicitly advisory.

- [x] **SIGNAL-04**: Mechanically proven repository residue is removed without deleting unique audit,
  historical, debug, or maintainer evidence; recurrence-prone root lint outputs are ignored narrowly.

### Live Truth and Compile Clarity

- [ ] **CLARITY-01**: Readers of current source and tests see domain rationale rather than obsolete
  Phase/Plan/EXPECTED-RED commentary; historical planning archives remain untouched.

- [ ] **CLARITY-02**: Readers of current maintainer and adopter documentation see the implemented CI
  lanes, support posture, Admin navigation labels, and shipped tus/streaming state without stale
  forward references.

- [x] **CLARITY-03**: Contributors can compile and inspect the project without the `Rindle.Schema`
  seven-module compile cycle, while schema ownership and prefix behavior remain byte-for-byte
  compatible at public boundaries.

### Runtime Operations Architecture

- [ ] **OPS-01**: Maintainers can read `Rindle.Ops.RuntimeChecks` as a small orchestration boundary with
  cohesive collaborators for independent diagnostic domains and unchanged result/telemetry contracts.

- [ ] **OPS-02**: Maintainers can reason about populated-install migration preflight through named,
  bounded validation components without changing the fixed owned-table catalog, transaction order, or
  reversal safety.

- [ ] **OPS-03**: Maintainers can read runtime-status collection, formatting, and command concerns in
  separate cohesive units without changing flags, output shapes, limits, or failure semantics.

### Upload Path Clarity

- [ ] **UPLOAD-01**: Maintainers can follow tus request parsing, protocol validation, storage effects,
  and response construction through cohesive boundaries while preserving the existing Plug contract,
  resumable semantics, and error vocabulary.

- [ ] **UPLOAD-02**: Maintainers can follow upload broker validation, capability negotiation, session
  persistence, and completion orchestration through cohesive boundaries while preserving all public
  APIs and storage-adapter behavior.

### Behavioral Test Support

- [ ] **TEST-01**: Generated-app proof support is split from the 3,955-line helper into focused modules
  with one discoverable responsibility each and unchanged packed-adopter coverage.

- [ ] **TEST-02**: Tests validate observable behavior, compiled metadata, or explicit structural
  contracts instead of reading their own helper/source text to assert implementation strings.

- [ ] **TEST-03**: Large documentation-parity suites are split by public contract domain with shared
  helpers, equivalent assertions, and clearer failure ownership.

- [ ] **TEST-04**: Async-isolation issue #42 is stress-tested against the shipped single-run coverage and
  process-scoped repo override; the issue is closed with evidence if it no longer reproduces or narrowed
  to a concrete remaining failure if it does.

### Curated Type Ratchet

- [ ] **TYPE-01**: The supported Elixir 1.17 / OTP 27 home cell passes Dialyzer after each retained
  ignore entry is justified or removed; unsupported local toolchain noise does not define acceptance.

- [ ] **TYPE-02**: CI blocks newly introduced actionable Dialyzer findings through a curated gate, and
  issue #76 is closed with the resulting baseline evidence.

### Behavior Preservation

- [x] **SAFE-01**: Every refactor slice proves unchanged public API signatures, schema/migration
  behavior, telemetry event names and metadata, error atoms/shapes, and supported CI/release invariants.

## Future Requirements

### Product Pull

- **LIFE-06**: Force-delete still-shared assets only after a compliance or legal ticket.
- **STREAM-10**: Add a second streaming provider only after a named adopter and provider choice.
- **DEFER-02**: Add ExUnit partitions only after measured core starvation demonstrates value.

## Out of Scope

| Item | Reason |
|------|--------|
| Public API, schema, migration, telemetry, or error-vocabulary redesign | This is a behavior-preserving maintenance milestone. |
| Admin-console feature or visual redesign | The operator UI is not the maintainer's current focus; only truth-label corrections are allowed. |
| Broad dependency or toolchain upgrade | Upgrade reachability and security posture require a separate risk-ranked change set. |
| Historical planning/archive prose normalization | Archives are durable provenance; only current live comments/docs are reconciled. |
| Blanket style cleanup or alias rewrites | Low-value subjective churn is not a quality ratchet. |
| Splitting `Rindle` facade or any file solely by line count | Decomposition requires proven mixed responsibilities and clearer contracts. |
| Forced package release | Refactor-only changes use non-release-triggering commit types unless adopter-visible behavior changes. |

## Traceability

Populated during roadmap creation. Each v1.24 requirement maps to exactly one phase.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SIGNAL-01 | Phase 121 | Complete |
| SIGNAL-02 | Phase 121 | Complete |
| SIGNAL-03 | Phase 121 | Complete |
| SIGNAL-04 | Phase 121 | Complete |
| SAFE-01 | Phase 121 | Complete |
| CLARITY-01 | Phase 122 | Pending |
| CLARITY-02 | Phase 122 | Pending |
| CLARITY-03 | Phase 122 | Complete |
| OPS-01 | Phase 123 | Pending |
| OPS-02 | Phase 123 | Pending |
| OPS-03 | Phase 123 | Pending |
| UPLOAD-01 | Phase 124 | Pending |
| UPLOAD-02 | Phase 124 | Pending |
| TEST-01 | Phase 125 | Pending |
| TEST-02 | Phase 125 | Pending |
| TEST-03 | Phase 125 | Pending |
| TEST-04 | Phase 125 | Pending |
| TYPE-01 | Phase 126 | Pending |
| TYPE-02 | Phase 126 | Pending |

**Coverage:**

- v1.24 requirements: 19 total
- Mapped to phases: 19
- Unmapped: 0

---
*Requirements defined: 2026-08-22*
*Last updated: 2026-08-22 after v1.24 roadmap creation (19/19 requirements mapped)*
