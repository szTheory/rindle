# Roadmap: Rindle

## Milestones

- 🚧 **v1.26 Pre-Adopter Readiness & Quality Consolidation** — Phases 133–139 (planned, 38 requirements)
- ✅ **v1.25 Maintainer Craft & Feedback Velocity** — Phases 127–132 (shipped 2026-08-27; [archive](milestones/v1.25-ROADMAP.md), [requirements](milestones/v1.25-REQUIREMENTS.md), [audit](milestones/v1.25-MILESTONE-AUDIT.md))
- ✅ **v1.24 Core Clarity & Quality Ratchet** — Phases 121–126 (shipped 2026-08-23; [archive](milestones/v1.24-ROADMAP.md), [requirements](milestones/v1.24-REQUIREMENTS.md), [audit](milestones/v1.24-MILESTONE-AUDIT.md))
- ✅ **v1.23 Postgres Schema Isolation** — Phases 117–120 (shipped 2026-08-20; [archive](milestones/v1.23-ROADMAP.md), [requirements](milestones/v1.23-REQUIREMENTS.md), [audit](milestones/v1.23-MILESTONE-AUDIT.md))
- ✅ **v1.22 OSS Quality & Trust Hardening** — Phases 113–116 (shipped 2026-07-02; [archive](milestones/v1.22-ROADMAP.md), [requirements](milestones/v1.22-REQUIREMENTS.md), [audit](milestones/v1.22-MILESTONE-AUDIT.md))

Earlier milestone detail is retained in `.planning/milestones/` and indexed by `.planning/MILESTONES.md`.

## Overview

v1.26 makes readiness demonstrable before Rindle's first real adopter. It first freezes exact-head
evidence and restores trustworthy Nightly and project truth, then isolates dependency and inbox
decisions from candidate-backed repository, code-craft, and measured CI improvements. The final three
phases extend the existing Cohort proof into a built-package synthetic twin, execute a deterministic
failure-and-recovery matrix, and close from one clean exact-head checkout. Throughout, automation must
prove every requirement without aesthetic churn or drift in public API, schema/migrations, telemetry,
error vocabulary, release coupling, supported behavior, or the accepted pull-request timing envelope.

## Phases

- [ ] **Phase 133: Evidence Charter and Live Truth** - Establish immutable evidence authority and restore truthful Nightly, incident, release, and adoption signals.
- [ ] **Phase 134: Dependency, Security, and Inbox Disposition** - Give every live advisory and remote item an attributable, evidence-backed disposition.
- [ ] **Phase 135: Repository and Code-Craft Consolidation** - Remove only proven residue and improve candidate-backed readability under preserved contracts.
- [ ] **Phase 136: Measured Quality and CI Ratchets** - Tighten measured quality, contributor, and CI/CD guarantees without weakening signal or speed.
- [ ] **Phase 137: Built-Package Twin Foundation** - Establish a production-faithful synthetic-adopter substrate with authoritative receipts and cleanup.
- [ ] **Phase 138: Lifecycle Failure and Recovery Matrix** - Prove deterministic lifecycle recovery and zero unapproved residue through supported boundaries.
- [ ] **Phase 139: Exact-Head Readiness Closure** - Produce one fail-closed, exact-head readiness verdict while keeping independent adoption open.

## Phase Details

### Phase 133: Evidence Charter and Live Truth

**Goal**: Maintainers can trust exact-head quality, Nightly, incident, release, support, and adoption evidence before any cleanup changes the baseline.
**Depends on**: Phase 132 (v1.25 shipped)
**Requirements**: EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08
**Success Criteria** (what must be TRUE):

  1. A validator accepts a census only when it is bound to the current immutable SHA, covers every applicable quality dimension, deduplicates candidates, and assigns each exactly one `fix`, `retain`, or trigger-bound `defer` disposition.
  2. Supported Nightly Dialyzer cells pass with both fresh and restored PLTs, while stale or incompatible PLT evidence is rejected or rebuilt by automated regression proof.
  3. Nightly aggregation fails for failed, cancelled, unexpected, or impermissibly skipped gating states, and automated incident tests prove one exact-run-bound issue opens or updates on failure and closes only after qualifying scheduled recovery.
  4. Executable parity checks derive release, planning, support, and adoption-proof claims from authoritative state and reject every unmarked version, lane-severity, or package-proof contradiction.

**Plans**: 17/17 plans executed; 6 pending gap closure

Plans:

**Wave 1**

- [x] 133-01-PLAN.md — Create and freeze the exact-head machine-validated evidence census.
- [x] 133-02-PLAN.md — Restore fresh and restored supported-cell Dialyzer evidence with exact PLT identity.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 133-03-PLAN.md — Make Nightly aggregation strict, fail-closed, and authoritative.

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 133-04-PLAN.md — Implement the exact-run scheduled rolling incident lifecycle.

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 133-05-PLAN.md — Derive version, workflow, history, and package-proof truth from authorities.

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 133-06-PLAN.md — Reconcile active claims and run the complete automation-first evidence gate.

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 133-07-PLAN.md — Collect and validate exact-head supported Nightly evidence without incident mutation.

**Wave 7** *(blocked on Wave 6 completion)*

- [x] 133-08-PLAN.md — Reject caller-forged package authority while retaining real generated-consumer provenance.

**Wave 8** *(blocked on Wave 7 completion)*

- [x] 133-09-PLAN.md — Reject remote, incident, and local-authority receipt mutations without emitting forbidden GitHub mutations.

**Wave 9** *(blocked on Wave 8 completion)*

- [x] 133-10-PLAN.md — Enforce exact supported toolchain and cache-key evidence in collection and receipt revalidation.

**Wave 10** *(blocked on Wave 9 completion)*

- [x] 133-11-PLAN.md — Reconcile pending Phase 133 truth and contain every destructive PLT reset beneath the repository-owned root.

**Wave 11** *(blocked on Wave 10 completion)*

- [x] 133-12-PLAN.md — Select delayed exact Nightly runs by zero/one/many post-boundary cardinality.
- [x] 133-13-PLAN.md — Authenticate every census detector row and contain observation provenance.
- [x] 133-14-PLAN.md — Replace forgeable package/adoption maps with authenticated immutable receipts.

**Wave 12** *(blocked on Wave 11 completion)*

- [x] 133-15-PLAN.md — Derive release coupling and sole-required-check truth from executable structured semantics.

**Wave 13** *(blocked on Waves 11–12 completion)*

- [x] 133-16-PLAN.md — Bind local census and live-truth authority to immutable Git objects.

**Wave 14** *(blocked on Wave 13 completion)*

- [x] 133-17-PLAN.md — Freeze the repaired baseline and recollect one fresh exact-subject Nightly receipt.

### Phase 134: Dependency, Security, and Inbox Disposition

**Goal**: Maintainers can account for every current remote item and dependency risk without bulk mutation or ambiguous rollback.
**Depends on**: Phase 133
**Requirements**: INBOX-01, INBOX-02, SEC-09, DEPS-01
**Success Criteria** (what must be TRUE):

  1. A timestamped, read-only collector inventories every open issue, pull request, check state, reported advisory, and relevant branch-protection setting without mutating GitHub state.
  2. A machine-checkable ledger assigns each open issue and pull request exactly one merge, close, retain, supersede, or evidence-gated defer disposition and rejects missing or stale entries.
  3. Every reported advisory records its dependency path, supported-runtime reachability, fix version, and either verified resolution or a bounded exception with an executable expiry trigger.
  4. Each landed dependency risk group is independently attributable and passes supported-toolchain, public-contract, built-package consumer, and relevant twin gates before its remote disposition can close.

**Plans**: TBD

### Phase 135: Repository and Code-Craft Consolidation

**Goal**: The tracked repository and candidate-backed code read as intentional, self-describing work with no mechanically proven residue and no contract drift.
**Depends on**: Phase 134
**Requirements**: CRAFT-03, CRAFT-04, CRAFT-05, CRAFT-06, HYGIENE-03
**Success Criteria** (what must be TRUE):

  1. An executable artifact ledger accounts for every tracked, ignored, generated, or candidate artifact by authority, consumer, package status, and retain/delete/ignore disposition; regeneration and package-exclusion checks detect drift.
  2. Automated scans reject unallowlisted planning-era identifiers, mojibake, duplicated prose, obsolete narration, and artifact comments in live code, tests, scripts, configuration, and workflows.
  3. Every readability change traces to the frozen candidate ledger and passes behavioral and boundary checks proving improved naming, cohesion, ownership, or failure semantics without public API, schema/migration, telemetry, error, or release-contract drift.
  4. Repository hygiene fails on fetch failure, wrong branch, tracked junk, generated drift, incomplete `mix ci`, or post-verification worktree residue, while narrow ignore rules preserve intentional history and generated authority.

**Plans**: TBD

### Phase 136: Measured Quality and CI Ratchets

**Goal**: Contributors receive bounded, reproducible quality and CI feedback whose measured guarantees cannot silently regress.
**Depends on**: Phase 135
**Requirements**: MAINT-04, TYPE-03, COV-06, TEST-08, CI-15, CI-16, DX-05
**Success Criteria** (what must be TRUE):

  1. Complexity and Dialyzer ledgers reject baseline growth or broader suppressions; every removal carries behavior-preservation evidence and every retained identity keeps a machine-checkable removal trigger on the supported toolchain.
  2. One fresh canonical coverage run preserves or raises the exact accepted floor, and executable tests cover changed risk branches through behavior rather than source-literal or percentage-only assertions.
  3. Issue #42's finite isolation experiment either completes successfully or emits a reproducible failing receipt with explicit uncertainty and an evidence-triggered next action; reruns cannot erase the result.
  4. A clean supported environment can follow one tested command map from bootstrap through focused and full verification without reconstructing workflow YAML.
  5. Structural CI checks verify workflow semantics, cache contracts, immutable or checksum-verified inputs, and justified timeouts while preserving `ci.yml`, workflow `CI`, sole required `CI Summary`, fork safety, exact-SHA release coupling, and a fresh exact-ten receipt within the <=480-second median/<=600-second p95 envelope after topology changes.

**Plans**: TBD

### Phase 137: Built-Package Twin Foundation

**Goal**: Maintainers can run a production-faithful synthetic adopter against the freshly built package and trust its redacted lifecycle and residue evidence.
**Depends on**: Phase 136
**Requirements**: TWIN-01, TWIN-02, TWIN-03, TWIN-04, TWIN-05, TWIN-06
**Success Criteria** (what must be TRUE):

  1. The twin installs a freshly built external Hex artifact and fails if repository paths, private modules, source introspection, or prebuilt local BEAM output can influence the run.
  2. The host provisions and verifies adopter-owned Repo, Oban, migrations, PostgreSQL, MinIO, and media runtimes solely through supported Rindle contracts.
  3. Deterministic fail-N-then-delegate faults enter only through documented storage, processor, provider, HTTP, tus, or webhook boundaries, and a contract guard rejects twin-only production APIs or private coupling.
  4. Retry evidence comes from persisted database-backed Oban execution, while restart evidence terminates and resumes a separately supervised runtime without duplicate stimulus.
  5. Every registered scenario emits a schema-validated, redacted receipt bound to source SHA, package checksum, toolchain, transitions, job attempts, external effects, terminal state, cleanup, and residue, stamped as maintainer-operated synthetic evidence that cannot satisfy the independent-pilot gate.

**Plans**: TBD

### Phase 138: Lifecycle Failure and Recovery Matrix

**Goal**: Maintainers can execute the supported lifecycle's critical interruptions and observe deterministic convergence with no unapproved residue.
**Depends on**: Phase 137
**Requirements**: RECOV-01, RECOV-02, RECOV-03, RECOV-04, RECOV-05, RECOV-06
**Success Criteria** (what must be TRUE):

  1. An interrupted tus upload resumes from its committed offset after client recreation and converges to exactly one ready asset and one object.
  2. A transient storage-delete failure preserves durable state, records a real Oban retry, later succeeds, and treats authoritative absence as idempotent success.
  3. A real AV processing failure is visible through supported diagnostics and recovers through the supported repair path to a consistent terminal state.
  4. Duplicate and out-of-order provider events plus a host restart between durable stages converge without duplicate provider state, duplicate stimulus, lost work, inconsistent terminal state, or secret-bearing telemetry.
  5. After an interrupted cleanup, an idempotent janitor rerun leaves zero unapproved database, job, object, provider, multipart, or temporary-file residue, and the full matrix emits independently verified receipts.

**Plans**: TBD

### Phase 139: Exact-Head Readiness Closure

**Goal**: Maintainers can obtain one authoritative readiness verdict for the current immutable revision without overstating synthetic evidence as real adoption.
**Depends on**: Phase 138
**Requirements**: READY-01, READY-02, READY-03, READY-04, READY-05
**Success Criteria** (what must be TRUE):

  1. One isolated exact-head checkout passes supported toolchains, formatting, compilation, Credo, Dialyzer, Doctor, coverage, security, docs, built-package, generated-consumer, twin, and repository-hygiene gates.
  2. The same exact head has green `main` CI and Nightly conclusions, and an automated topology check proves branch protection matches the preserved sole-required-check and release-coupling contract.
  3. A current remote-state verifier confirms every open item and advisory has an evidence-backed disposition and no release blocker is undispositioned.
  4. One fail-closed readiness manifest rejects missing, stale, partial, impermissibly skipped, foreign-SHA, unclean, residue-bearing, or unexplained evidence.
  5. Automated release and adoption-truth checks keep the named independent Phoenix pilot open and reject any claim that the synthetic twin satisfies real-adopter validation or authorizes 1.0.

**Plans**: TBD

## Progress

**Execution Order:** 133 -> 134 -> 135 -> 136 -> 137 -> 138 -> 139

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 133. Evidence Charter and Live Truth | 17/17 | In Progress|  |
| 134. Dependency, Security, and Inbox Disposition | 0/TBD | Not started | - |
| 135. Repository and Code-Craft Consolidation | 0/TBD | Not started | - |
| 136. Measured Quality and CI Ratchets | 0/TBD | Not started | - |
| 137. Built-Package Twin Foundation | 0/TBD | Not started | - |
| 138. Lifecycle Failure and Recovery Matrix | 0/TBD | Not started | - |
| 139. Exact-Head Readiness Closure | 0/TBD | Not started | - |

---
*Last updated: 2026-09-09 after v1.26 roadmap creation; awaiting roadmap approval.*
