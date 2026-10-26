# Requirements: Rindle v1.26 Pre-Adopter Readiness & Quality Consolidation

**Defined:** 2026-09-09
**Core Value:** Media, made durable.

## v1.26 Requirements

### Evidence and Live Truth

The five Phase 133 requirements remain pending until a fresh Plan 133-37 exact-subject receipt and
the terminal automated reconciliation gates both pass. The immutable halted attempts in Plans 133-27
and 133-32, a Plan 133-36 authorization stop, or a failed Plan 133-37 attempt provide history but no
completion credit.

- [x] **EVID-01**: Maintainers can generate a SHA-bound census covering every applicable quality dimension, with each unique candidate assigned exactly one `fix`, `retain`, or trigger-bound `defer` disposition.
- [x] **EVID-02**: Supported Nightly Dialyzer runs succeed with both fresh and restored PLTs, and automated regression proof rejects or rebuilds stale PLTs.
- [x] **EVID-03**: Nightly aggregation fails when any declared gating job fails, is cancelled, or reports an unexpected state; skipped work cannot silently count as success.
- [x] **EVID-04**: Nightly failures open or update one incident, while a qualifying scheduled recovery closes it with exact-run evidence.
- [x] **TRUTH-08**: Release, planning, support, and adoption-proof claims derive from authoritative live state and contain no unmarked 0.4.5/0.4.6, lane-severity, or package-proof contradiction.

### Security, Dependencies, and Inbox

- [x] **INBOX-01**: Maintainers can capture a timestamped, read-only inventory of every open issue, pull request, check state, advisory, and relevant branch-protection setting.
- [x] **INBOX-02**: Every open issue and pull request has an explicit merge, close, retain, supersede, or evidence-gated defer disposition; inbox zero is not required.
- [x] **SEC-09**: Every reported dependency advisory has a recorded dependency path, supported-runtime reachability analysis, fix version, and verified resolution or bounded exception.
- [x] **DEPS-01**: Dependency updates land only in independently attributable risk groups after supported-toolchain, package-consumer, contract, and relevant twin evidence passes.

### Repository and Code Craft

- [x] **CRAFT-03**: Every tracked, ignored, generated, or candidate artifact has documented authority, consumer, package status, and retain/delete/ignore disposition.
- [x] **CRAFT-04**: Planning-era identifiers in live code, tests, scripts, config, and workflows are removed or rewritten unless an allowlisted present-tense policy reason requires them.
- [x] **CRAFT-05**: Readability changes originate from the frozen candidate ledger and improve naming, cohesion, ownership, or failure semantics while preserving public and behavioral contracts.
- [x] **CRAFT-06**: Mojibake, duplicated prose, obsolete narration, and mechanically proven residue are removed, with an automated regression scan preventing recurrence.
- [x] **HYGIENE-03**: Repository hygiene fails honestly on fetch failure, wrong branch, tracked junk, generated drift, incomplete `mix ci`, or post-verification worktree residue.

### Measured Quality and CI

- [x] **MAINT-04**: The reviewed complexity baseline cannot grow; each removal has behavior-preservation evidence, while retained findings keep stable identity and a removal trigger.
- [x] **TYPE-03**: Dialyzer suppressions are removal-only, narrowly identity-matched, and validated on the supported toolchain without substitution or broader ignores.
- [x] **COV-06**: A fresh canonical coverage run preserves or raises the exact accepted floor, while changed risk branches receive behavioral rather than percentage-driven tests.
- [x] **TEST-08**: Issue #42's finite async-isolation experiment completes or remains open with a reproducible failure, explicit uncertainty, and evidence-based next trigger.
- [x] **CI-15**: Workflow semantics, caches, downloads, images, and process-heavy jobs are structurally validated, immutable or checksum-verified where practical, and bounded by justified timeouts.
- [ ] **CI-16**: CI changes preserve `ci.yml`, workflow `CI`, the sole `CI Summary` required context, exact-SHA release gating, fork safety, and exact-head proof. The original exact-ten <=480-second median/<=600-second p95 PR envelope is deferred unfinished to SEED-261021-918 by the 2026-10-21 user decision; no speed acceptance credit.
- [x] **DX-05**: A contributor can bootstrap a clean supported environment and select the correct focused or full verification command without reverse-engineering workflow YAML.

### Synthetic Adopter Twin

- [x] **TWIN-01**: Every twin artifact identifies itself as maintainer-operated synthetic evidence and explicitly states that it does not satisfy the independent-adopter requirement.
- [x] **TWIN-02**: The twin consumes a freshly built external Hex artifact and fails if it falls back to repository paths, private modules, source introspection, or prebuilt local BEAM output.
- [x] **TWIN-03**: The twin uses adopter-owned Repo, Oban, migrations, PostgreSQL, MinIO, and media runtimes through supported contracts.
- [x] **TWIN-04**: Deterministic failures enter only through documented storage, processor, provider, HTTP, tus, or webhook boundaries; no twin-only production API is added.
- [x] **TWIN-05**: Real retry claims use persisted database-backed Oban execution, and restart claims terminate and resume a separately supervised runtime without duplicate stimulus.
- [x] **TWIN-06**: Every scenario emits a redacted, versioned receipt bound to source SHA, package checksum, toolchain, transitions, job attempts, external effects, terminal state, cleanup, and residue.

### Failure and Recovery Matrix

- [x] **RECOV-01**: An interrupted tus upload resumes from committed offset after client recreation and converges to exactly one ready asset and object.
- [x] **RECOV-02**: A transient storage-delete failure preserves durable state, produces an Oban retry, succeeds later, and treats authoritative absence idempotently.
- [x] **RECOV-03**: A real AV processing failure becomes visible through supported diagnostics and recovers through the supported repair path.
- [x] **RECOV-04**: Duplicate and out-of-order provider events converge idempotently without duplicate provider state or secret-bearing telemetry.
- [x] **RECOV-05**: Host restart between durable lifecycle stages resumes without duplicate stimulus, lost work, or inconsistent terminal state.
- [x] **RECOV-06**: Interrupted cleanup followed by an idempotent janitor run leaves zero unapproved database, job, object, provider, multipart, or temporary-file residue.

### Exact-Head Closure

October25 policy amendment: READY-01–05 acceptance may certify an explicitly selected
previously-main snapshot under `rindle-snapshot-v2`. All local/Actions evidence binds to
that fixed SHA; current remote-source and authority facts stay fresh. Completion records
must name the historical subject, interval and durable locator; later main gains no credit.
No requirement is closed by this policy amendment or its implementation fixtures.

- [ ] **READY-01**: One isolated exact-head checkout passes supported toolchains, formatting, compilation, Credo, Dialyzer, Doctor, coverage, security, docs, package, generated-consumer, twin, and repository-hygiene gates.
- [ ] **READY-02**: The selected authenticated previously-main snapshot's full push-main CI and real scheduled Nightly are green and branch-protection requirements match the tested workflow topology.
- [ ] **READY-03**: Every open remote item and advisory has a current evidence-backed disposition, with no undispositioned release blocker.
- [ ] **READY-04**: One fail-closed readiness manifest rejects missing, stale, partial, skipped-as-green, foreign-SHA, unclean, or unexplained evidence.
- [ ] **READY-05**: Milestone closure leaves the named independent Phoenix pilot requirement open and makes no real-adopter or 1.0 claim.

## Future Requirements

### Independent Adoption

- **PILOT-01**: A named non-maintainer Phoenix adopter integrates the released package without maintainer-only repository access and produces executable adoption evidence.
- **PILOT-02**: Rindle graduates to 1.0 only after the independent pilot demonstrates that the public contract is stable enough for SemVer major-only breaking changes.

### Demand-Gated Product Breadth

- **LIFE-06**: An authorized compliance or legal requirement defines force-delete behavior for still-shared assets.
- **STREAM-10**: A named adopter and provider choice authorize a second streaming provider.
- **TRANS-01**: Explicit product demand authorizes signed dynamic media transforms.
- **PRIV-01**: Explicit product demand authorizes EXIF privacy stripping for original assets.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Blanket repository rewrite, rename-only pass, or arbitrary file/function splitting | Creates review churn and blame loss without evidence of reduced change risk. |
| Comment-density targets or deleting all comments | Counts cannot distinguish obsolete narration from load-bearing rationale and invariants. |
| 100% line coverage | Encourages percentage theater; v1.26 adds behavioral proof only where current risks justify it. |
| A fourth demo or sample application | Cohort, canonical adopter, and generated consumers already provide the required host layers. |
| Twin-only production fault APIs or evidence tables | Synthetic proof must use existing public or adopter-owned boundaries without widening the shipped contract. |
| Treating the synthetic twin as an independent adopter | Maintainer-operated evidence cannot reveal independent integration friction or product demand. |
| Live-cloud calls on every pull request | Secrets, cost, quotas, fork safety, and nondeterminism conflict with fast trustworthy PR feedback. |
| Broad dependency batch or combinatorial compatibility matrix | Each update needs attributable risk and the existing supported diagonal already defines compatibility. |
| Deleting historical `.planning/` or generated assets without provenance proof | Those files may carry maintainer history, generator authority, or shipped consumers. |
| Public API, schema/migration, telemetry, or error-vocabulary redesign under cleanup scope | These are preserved contracts unless an executed correctness defect receives a separate scoped decision. |
| LIFE-06, STREAM-10, TRANS-01, PRIV-01, tus 2.0/RUFH, GCS-as-tus-backend, or uploader kits | Each remains demand-gated and lacks its required external authorization signal. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| EVID-01 | Phase 133 | Complete |
| EVID-02 | Phase 133 | Complete |
| EVID-03 | Phase 133 | Complete |
| EVID-04 | Phase 133 | Complete |
| TRUTH-08 | Phase 133 | Complete |
| INBOX-01 | Phase 134 | Complete |
| INBOX-02 | Phase 134 | Complete |
| SEC-09 | Phase 134 | Complete |
| DEPS-01 | Phase 134 | Complete |
| CRAFT-03 | Phase 135 | Complete |
| CRAFT-04 | Phase 135 | Complete |
| CRAFT-05 | Phase 135 | Complete |
| CRAFT-06 | Phase 135 | Complete |
| HYGIENE-03 | Phase 135 | Complete |
| MAINT-04 | Phase 136 | Complete |
| TYPE-03 | Phase 136 | Complete |
| COV-06 | Phase 136 | Complete |
| TEST-08 | Phase 136 | Complete |
| CI-15 | Phase 136 | Complete |
| CI-16 | Phase 136 / SEED-261021-918 | Active scope verified; numeric speed target deferred unfinished (zero credit) |
| DX-05 | Phase 136 | Complete |
| TWIN-01 | Phase 137 | Complete |
| TWIN-02 | Phase 137 | Complete |
| TWIN-03 | Phase 137 | Complete |
| TWIN-04 | Phase 137 | Complete |
| TWIN-05 | Phase 137 | Complete |
| TWIN-06 | Phase 137 | Complete |
| RECOV-01 | Phase 138 | Complete |
| RECOV-02 | Phase 138 | Complete |
| RECOV-03 | Phase 138 | Complete |
| RECOV-04 | Phase 138 | Complete |
| RECOV-05 | Phase 138 | Complete |
| RECOV-06 | Phase 138 | Complete |
| READY-01 | Phase 139 | Pending |
| READY-02 | Phase 139 | Pending |
| READY-03 | Phase 139 | Pending |
| READY-04 | Phase 139 | Pending |
| READY-05 | Phase 139 | Pending |

**Coverage:**

- v1.26 requirements: 38 total
- Mapped to phases: 38
- Unmapped: 0

---
*Requirements defined: 2026-09-09*
*Last updated: 2026-09-12 after reopening Phase 133 claims pending fresh exact-subject automated qualification.*
