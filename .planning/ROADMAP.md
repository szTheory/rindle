# Roadmap: Rindle

## Milestones

- 🚧 **v1.24 Core Clarity & Quality Ratchet** — Phases 121–126 (active; behavior-preserving maintenance)
- ✅ **v1.23 Postgres Schema Isolation** — Phases 117–120 (shipped 2026-08-20, Hex 0.4.0, 12/12 requirements, 4/4 verified phases; [archive](milestones/v1.23-ROADMAP.md), [requirements](milestones/v1.23-REQUIREMENTS.md), [audit](milestones/v1.23-MILESTONE-AUDIT.md))
- ✅ **v1.22 OSS Quality & Trust Hardening** — Phases 113–116 (shipped 2026-07-02; [archive](milestones/v1.22-ROADMAP.md), [requirements](milestones/v1.22-REQUIREMENTS.md), [audit](milestones/v1.22-MILESTONE-AUDIT.md))
- ✅ **v1.21 CI/DX Reliability Tail** — Phases 108–112 (shipped 2026-06-29; [archive](milestones/v1.21-ROADMAP.md), [requirements](milestones/v1.21-REQUIREMENTS.md), [audit](milestones/v1.21-MILESTONE-AUDIT.md))

<details>
<summary>Historical milestone index</summary>

- ✅ **v1.20 CI/CD Performance** — Phases 103–107 (shipped 2026-06-22; [archive](milestones/v1.20-ROADMAP.md), [requirements](milestones/v1.20-REQUIREMENTS.md), [audit](milestones/v1.20-MILESTONE-AUDIT.md))
- ✅ **v1.19 Design-System Stress-Test** — Phases 94–102 (shipped 2026-06-19; [archive](milestones/v1.19-ROADMAP.md), [audit](milestones/v1.19-MILESTONE-AUDIT.md))
- ✅ **v1.18 Admin Console & Adoption Lab** — Phases 86–93 (shipped 2026-06-20; [archive](milestones/v1.18-ROADMAP.md), [requirements](milestones/v1.18-REQUIREMENTS.md), [audit](milestones/v1.18-MILESTONE-AUDIT.md))
- ✅ **b1.0 Brand Foundations** — Phases 81–85 (shipped 2026-06-10; [archive](milestones/b1.0-ROADMAP.md), [audit](milestones/b1.0-MILESTONE-AUDIT.md))
- ✅ **v1.17 Adopter-Confidence Hygiene** — Phases 78–80 (shipped 2026-05-27; [archive](milestones/v1.17-ROADMAP.md), [audit](milestones/v1.17-MILESTONE-AUDIT.md))
- ✅ **v1.16 CI Enforcement & Planning Hygiene** — Phases 75–77 (shipped 2026-05-27; [archive](milestones/v1.16-ROADMAP.md))
- ✅ **v1.15 Maintenance & Proof Honesty** — Phases 71–74 (shipped 2026-05-27; [audit](milestones/v1.15-MILESTONE-AUDIT.md))
- ✅ **v1.14 Bulk Owner-Erasure Orchestration** — Phases 67–70 (shipped 2026-05-27; [archive](milestones/v1.14-ROADMAP.md))
- ✅ **v1.13 Cancel Direct Upload** — Phases 64–66 (shipped 2026-05-27; [archive](milestones/v1.13-ROADMAP.md))
- ✅ **v1.12 Adopter Truth & Maintenance Hygiene** — Phases 60–63 (shipped 2026-05-27; [archive](milestones/v1.12-ROADMAP.md))
- ✅ **v1.11 Tus Protocol Completion** — Phases 56–59 (shipped 2026-05-27; [archive](milestones/v1.11-ROADMAP.md))
- ✅ **v1.10 Owner Account Erasure** — Phases 53–55 (shipped 2026-05-26; [archive](milestones/v1.10-ROADMAP.md))
- ✅ **v1.9 Phoenix Tus DX Completion** — Phases 48–52 (shipped 2026-05-25; [archive](milestones/v1.9-ROADMAP.md))
- ✅ **v1.8 Resumable Browser Ingest** — Phases 42–47 (shipped 2026-05-25; [archive](milestones/v1.8-ROADMAP.md))
- ✅ **v1.7 GCS Resumable Adapter** — Phases 37–41 (shipped 2026-05-08; [archive](milestones/v1.7-ROADMAP.md))
- ✅ **v1.6 Provider Boundary + Mux** — Phases 33–36 (shipped 2026-05-07; [archive](milestones/v1.6-ROADMAP.md))
- ✅ **v1.5 Adopter Hardening & Lifecycle Repair** — Phases 29–32 (shipped 2026-05-06; [archive](milestones/v1.5-ROADMAP.md))
- ✅ **v1.4 Video & Audio Wedge** — Phases 23–28 (shipped 2026-05-05; [archive](milestones/v1.4-ROADMAP.md))
- ✅ **v1.3 Live Publish & API Ergonomics** — Phases 15–22 (shipped 2026-05-02; [archive](milestones/v1.3-ROADMAP.md))
- ✅ **v1.2 First Hex Publish** — Phases 10–14 (shipped 2026-04-29; [archive](milestones/v1.2-ROADMAP.md))
- ✅ **v1.1 Adopter Hardening** — Phases 6–9 (shipped 2026-04-28; [archive](milestones/v1.1-ROADMAP.md))
- ✅ **v1.0 MVP** — Phases 1–5 (shipped 2026-04; [archive](milestones/v1.0-ROADMAP.md))

</details>

Historical milestones and phase detail are retained in `.planning/milestones/`.

<details>
<summary>✅ v1.23 Postgres Schema Isolation (Phases 117–120) — SHIPPED 2026-08-20</summary>

Rindle 0.4.0 isolates its six domain tables and migration marker in `rindle` by default, retains an
explicit `public` compatibility build, provides a bounded host-owned populated-install move and guarded
reverse, keeps Oban and the host migration ledger independent, and proves the contract through packed
generated apps, Cohort, operational diagnostics, documentation parity, exact-source CI, and the public
Hex artifact.

- [x] Phase 117: Prefix Routing Architecture (5/5 plans) — completed 2026-08-08
- [x] Phase 118: Isolated Migration & Safe Upgrade (6/6 plans) — completed 2026-08-09
- [x] Phase 119: Ownership Boundaries & Diagnostics (5/5 plans) — completed 2026-08-09
- [x] Phase 120: Adoption Proof & Release Truth (14/14 plans) — completed 2026-08-20

Archive: [milestones/v1.23-ROADMAP.md](milestones/v1.23-ROADMAP.md); requirements:
[milestones/v1.23-REQUIREMENTS.md](milestones/v1.23-REQUIREMENTS.md); audit:
[milestones/v1.23-MILESTONE-AUDIT.md](milestones/v1.23-MILESTONE-AUDIT.md).

</details>

## Phases

- [x] **Phase 121: Truthful Quality Signals & Mechanical Hygiene** - Restore blocking, evidence-based quality gates and establish the invariant-preserving refactor contract. (completed 2026-08-22)
- [x] **Phase 122: Live Truth & Compile Clarity** - Reconcile live source and documentation truth while removing the internal schema compile cycle. (completed 2026-08-23)
- [ ] **Phase 123: Runtime Operations Decomposition** - Make runtime diagnostics, migration preflight, and status code easier to reason about without contract drift.
- [ ] **Phase 124: Upload Path Clarity** - Decompose tus and broker internals into cohesive, contract-preserving boundaries.
- [ ] **Phase 125: Behavioral Test Support** - Replace oversized and self-inspecting test support with focused behavioral proof and async-isolation evidence.
- [ ] **Phase 126: Curated Type Ratchet** - Retire the actionable Dialyzer baseline on the supported toolchain and block its return.

## Phase Details

### Phase 121: Truthful Quality Signals & Mechanical Hygiene

**Goal**: Maintainers receive truthful, blocking quality feedback for deterministic regressions and can make every later refactor against an explicit behavior-preservation contract.
**Depends on**: Nothing (first phase)
**Requirements**: SIGNAL-01, SIGNAL-02, SIGNAL-03, SIGNAL-04, SAFE-01
**Success Criteria** (what must be TRUE):

  1. A deterministic public-contract or documentation-parity regression fails a blocking CI result, while AV-dependent checks visibly declare and prove their prerequisites rather than disappearing behind advisory status.
  2. Running the documentation doctor reports measured public module, function, and spec coverage that meets the enforced ratchet, and its gate fails when measured health regresses.
  3. Credo blocks actionable warnings, complexity/nesting, and public docs/spec drift while explicitly retaining only low-value style preferences as advisory.
  4. Mechanically proven residue and recurrence-prone root lint outputs are removed or narrowly ignored without deleting unique audit, historical, debug, or maintainer evidence.
  5. Every subsequent refactor slice has a runnable regression contract proving unchanged public signatures, schema/migration behavior, telemetry names and metadata, error shapes, and supported CI/release invariants.

**Plans**: 7/7 plans executed

**Wave 1**

- [x] 121-01-PLAN.md — Establish the SAFE-01 refactor regression contract.
- [x] 121-02-PLAN.md — Restore deterministic Contract truth and select real AV proof.
- [x] 121-03-PLAN.md — Enforce measured public Doctor coverage.
- [x] 121-04-PLAN.md — Clear the actionable Credo warning baseline mechanically.
- [x] 121-05-PLAN.md — Lock exact-file, tracked-safe repository cleanup.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 121-06-PLAN.md — Add the curated Credo aggregate and stable debt inventory.

**Wave 3** *(blocked on Waves 1–2 completion)*

- [x] 121-07-PLAN.md — Wire truthful gates into CI Summary and local workflows.

### Phase 122: Live Truth & Compile Clarity

**Goal**: Current code, tests, and maintainer/adopter documentation accurately describe shipped behavior, and contributors can compile without the internal schema cycle.
**Depends on**: Phase 121
**Requirements**: CLARITY-01, CLARITY-02, CLARITY-03
**Success Criteria** (what must be TRUE):

  1. A reader of live source and tests finds domain rationale instead of obsolete Phase, Plan, or EXPECTED-RED commentary, with historical planning archives unchanged.
  2. Current maintainer and adopter documentation accurately describes implemented CI lanes, support posture, Admin navigation labels, and shipped tus and streaming behavior without forward-looking claims that are no longer true.
  3. Contributors can compile and inspect the project without the `Rindle.Schema` seven-module cycle, while public schema ownership and prefix behavior remain byte-for-byte compatible.

**Plans**: 5/5 plans executed and verified

**Wave 1 — compile truth**

- [x] 122-01-PLAN.md — Remove the schema compile cycle and compose objective xref proof into SAFE-01.

**Wave 2 — bounded live truth** *(blocked on Wave 1)*

- [x] 122-02-PLAN.md — Replace stale source chronology with current domain rationale.
- [x] 122-03-PLAN.md — Replace stale upload-test chronology with observable contract language.
- [x] 122-04-PLAN.md — Align Admin guides with rendered labels and host-owned security boundaries.

**Wave 3 — adopter/maintainer truth and phase gate** *(blocked on Waves 1–2)*

- [x] 122-05-PLAN.md — Reconcile CI/support/tus/streaming docs and run full preservation proof.

### Phase 123: Runtime Operations Decomposition

**Goal**: Runtime operational code is organized by diagnostic responsibility while retaining every existing operator-facing behavior and safety boundary.
**Depends on**: Phase 122
**Requirements**: OPS-01, OPS-02, OPS-03
**Success Criteria** (what must be TRUE):

  1. Maintainers can follow `Rindle.Ops.RuntimeChecks` through a small orchestration boundary and cohesive collaborators for each diagnostic domain, with result and telemetry contracts unchanged.
  2. Populated-install migration preflight is understandable through named, bounded validation components while its fixed owned-table catalog, transaction order, and reversal safety remain unchanged.
  3. Runtime-status collection, formatting, and command concerns are independently readable while flags, output shapes, limits, and failure semantics remain unchanged.

**Plans**: 3 plans

**Wave 1 — runtime diagnostic orchestration**

- [x] 123-01-PLAN.md — Extract cohesive runtime-check domains behind the unchanged orchestration/result/telemetry façade.

**Wave 2 — populated-install preflight** *(blocked on Wave 1)*

- [x] 123-02-PLAN.md — Separate migration snapshot and directional validation while V1 retains all catalog, DDL, transaction, and reversal authority.

**Wave 3 — runtime-status collection and presentation** *(blocked on Wave 2)*

- [x] 123-03-PLAN.md — Separate status collection and command formatting, then run the complete preservation and supported-CI gate.

### Phase 124: Upload Path Clarity

**Goal**: The tus and upload-broker paths have clear responsibility boundaries without changing their public protocol or storage behavior.
**Depends on**: Phase 123
**Requirements**: UPLOAD-01, UPLOAD-02
**Success Criteria** (what must be TRUE):

  1. Maintainers can trace a tus request through parsing, protocol validation, storage effects, and response construction in cohesive units while Plug contract, resumability, and error vocabulary stay unchanged.
  2. Maintainers can trace upload-broker validation, capability negotiation, session persistence, and completion orchestration in cohesive units while public APIs and storage-adapter behavior stay unchanged.

**Plans**: TBD

### Phase 125: Behavioral Test Support

**Goal**: Test support proves observable contracts with focused ownership, including conclusive evidence on async isolation.
**Depends on**: Phase 124
**Requirements**: TEST-01, TEST-02, TEST-03, TEST-04
**Success Criteria** (what must be TRUE):

  1. Generated-app proof support is split into focused, discoverable modules while packed-adopter coverage remains unchanged.
  2. Tests assert observable behavior, compiled metadata, or explicit structural contracts rather than self-reading helper or source strings for implementation text.
  3. Documentation-parity suites are organized by public contract domain with shared helpers, equivalent assertions, and failures that identify the owning contract.
  4. Async-isolation issue #42 has stress evidence against the shipped single-run coverage and process-scoped repo override, and is either closed as non-reproducible or narrowed to a concrete remaining failure.

**Plans**: TBD

### Phase 126: Curated Type Ratchet

**Goal**: The supported Elixir/OTP cell has an actionable, enforced Dialyzer baseline with no retirement ambiguity.
**Depends on**: Phase 125
**Requirements**: TYPE-01, TYPE-02
**Success Criteria** (what must be TRUE):

  1. The supported Elixir 1.17 / OTP 27 home cell passes Dialyzer, and every retained ignore is justified while unsupported local-toolchain noise does not determine acceptance.
  2. CI blocks newly introduced actionable Dialyzer findings through a curated gate, with issue #76 closed using the resulting baseline evidence.

**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 121. Truthful Quality Signals & Mechanical Hygiene | 7/7 | Complete    | 2026-08-22 |
| 122. Live Truth & Compile Clarity | 4/5 | In Progress|  |
| 123. Runtime Operations Decomposition | 0/3 | Planned | - |
| 124. Upload Path Clarity | 0/TBD | Not started | - |
| 125. Behavioral Test Support | 0/TBD | Not started | - |
| 126. Curated Type Ratchet | 0/TBD | Not started | - |

## Deferred to a Demand-Gated Milestone

- Force-delete semantics for still-shared assets (LIFE-06) — compliance pull only.
- Second streaming provider (Cloudflare/Bunny) — explicit adopter demand only.
- IETF RUFH / tus 2.0; GCS-as-tus-backend / R2-native tus proxying.
- Rindle-owned standalone tus JS client package and richer uploader abstractions.
- Signed dynamic image transforms and explicit original EXIF/GPS stripping.
- `mix test --partitions` parallelization — evidence-gated on measured core starvation (DEFER-02).

---
*Last updated: 2026-08-22 — v1.24 roadmap created from the approved finite, behavior-preserving requirement set. Signal restoration precedes refactors; Dialyzer retirement is last.*
