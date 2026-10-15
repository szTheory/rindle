# Architecture Patterns

**Domain:** Pre-adopter quality consolidation and synthetic media-lifecycle assurance
**Project:** Rindle v1.26
**Researched:** 2026-09-09
**Overall confidence:** HIGH for repository integration and ordering; MEDIUM for the new twin harness until phase-local execution proves it

## Recommended Architecture

v1.26 should add an **evidence plane around the existing product**, not a second product and not a
test-only rewrite of Rindle internals. Production remains the current Phoenix/Ecto library: adopter-owned
Repo and Oban, `Rindle.Storage` and `Rindle.Processor` behaviours, the
`Rindle.Streaming.Provider` boundary, public lifecycle facades, durable FSM rows, telemetry, and
release automation. New work belongs in repository-owned census/validation scripts and in a
Cohort-hosted, test-only scenario harness.

```text
immutable source SHA
        |
        +--> truth + quality census ---------------------> disposition ledger
        |      (read-only detectors)                       fix | retain | defer
        |
        +--> mix hex.build --unpack ---------------------> unpacked package
                                                             |
                         +-----------------------------------+-------------------+
                         |                                                       |
                         v                                                       v
              generated Phoenix consumer                              Cohort twin runner
              install/migrate/boot proof                      (test/support, no product UI)
                                                                 |
                    public Rindle facades + HTTP/tus/webhook seams
                                                                 |
                    real Postgres + MinIO + adopter-owned Oban
                         |               |                |
                  domain/FSM rows    Oban.Job rows    storage objects
                         \               |                /
                          +------ telemetry/public output ------+
                                             |
                                  versioned JSON receipt
                                             |
                            schema verifier + CI artifact upload
```

The current proof layers remain distinct and complementary:

- **Generated-package proof** owns install, migration, boot, package-content, and dependency-source
  fidelity. `GeneratedApp.Workspace` already produces an unpacked package with
  `mix hex.build --unpack`, distinguishes package/network install modes, and reports
  `repository_path_fallback?: false`.
- **Canonical adopter proof** owns small, readable public lifecycle examples and documentation parity.
  It should not grow complex fault orchestration. Its current `perform_job/2` calls are appropriate
  for focused lifecycle contracts, but do not prove scheduler retry, snooze, or persisted terminal state.
- **Cohort** owns realistic host wiring, browser journeys, Postgres/MinIO integration, and the new
  failure-and-recovery twin. Reuse its profiles, migrations, endpoint, and supervised Repo/Oban
  topology without adding a public demo screen or a fourth example app.
- **CI/release workflows** own where evidence runs and whether it blocks. `ci.yml` and workflow
  `name: CI` remain invariant because release automation resolves both; `CI Summary` remains the only
  required PR context.

### Component Boundaries

| Component | Status | Responsibility | Communicates With |
|-----------|--------|----------------|-------------------|
| Quality census coordinator | New maintainer script | Run finite detectors, normalize findings, require `fix`, `retain`, or evidence-gated `defer` | Git index, Mix tasks, workflow validators, receipt schema |
| Preservation contracts | Existing; extend only from evidence | Freeze public API, schema/migration, telemetry, error vocabulary, compile graph, and release coupling | `refactor_contract.sh`, contract/meta-tests |
| Repository hygiene validator | Narrowly extended | Check tracked residue, ignore rules, release truth, clean-checkout reproducibility, and clean-worktree closure without broad deletion | Git plumbing, release ledgers, automation-first validator |
| Package builder/provenance owner | Existing; extend report | Build/identify unpacked Hex artifact, source SHA, package digest, and no-repository-fallback fact | `GeneratedApp.Workspace`, Hex, package metadata tests |
| Generated app consumer | Existing | Prove a fresh Phoenix app installs, migrates, boots, and exercises the built package | Unpacked package, Postgres, MinIO, host-owned Oban |
| Canonical adopter lifecycle | Existing; keep focused | Preserve concise public API examples and happy-path lifecycle/docs parity | Public APIs, MinIO, adopter Repo, isolated worker execution |
| Cohort twin scenario registry | New under `examples/adoption_demo/test/support/` | Declare bounded scenarios, preconditions, public actions, expected observations, cleanup invariants | Scenario runner and receipt builder |
| Cohort fault controls | New test-only host implementations | Fail named public adapter/processor/provider operations on deterministic attempts, then delegate/recover | `Rindle.Storage`, `Rindle.Processor`, `Rindle.Streaming.Provider` |
| Cohort stage runner | New CI/maintainer wrapper | Build package once, configure Cohort against it, run stages, perform real process restarts, preserve status, clean resources | Package builder, Cohort, Postgres, MinIO, verifier |
| Receipt builder/verifier | New test support plus structural test | Emit/validate versioned redacted facts; reject missing, partial, skipped, foreign-SHA, or unclean receipts | Scenario observations, source/package identity, CI upload |
| Full twin CI job | New or extracted after measurement | Run deterministic failure/recovery matrix off PR critical path and publish receipts without masking failures | Push-main `ci.yml` conclusion, optional Nightly repetition |
| Fast twin contracts | New in existing PR lanes | Validate registry, receipt schema, fault determinism, and no private-module dependency | `proof`/`adoption-demo-unit`; `CI Summary` |

### Recommended Project Shape

```text
examples/adoption_demo/test/support/digital_twin/
├── scenario.ex             # declarative scenario contract
├── registry.ex             # finite list; no dynamic discovery
├── runner.ex               # public actions and observations
├── receipt.ex              # schema/version/redaction/verdict
├── storage_fault.ex        # Rindle.Storage; fail-N then delegate
├── processor_fault.ex      # Rindle.Processor deterministic failure
└── provider_fault.ex       # Rindle.Streaming.Provider event script

examples/adoption_demo/test/digital_twin/
├── lifecycle_recovery_test.exs
├── tus_interruption_test.exs
├── provider_disorder_test.exs
└── restart_cleanup_test.exs

scripts/ci/adoption_twin.sh
scripts/ci/verify_twin_receipt.*
scripts/maintainer/quality_census.*
```

Exact names/file count are discretionary; the boundary is not. Twin modules must not be compiled into
the `rindle` package, added to `lib/`, or exposed as adopter API. Cohort may receive minimal test
configuration seams, but its visible product surface should not become a chaos-control console.

## Evidence Ownership

Each claim has one canonical owner. Duplicate assertions may defend it, but must not create an
independent vocabulary.

| Claim | Canonical owner | Evidence |
|------|-----------------|----------|
| Current quality debt/disposition | Quality census manifest | Stable ID, detector, owner, baseline, decision, proof command |
| Public behavior preserved | Existing contract suites + SAFE-01 | Foreground failing command; no `.planning/` dependency |
| Package contents/API | Package metadata/generated-app tests | Unpacked package root, metadata, prohibited-path checks |
| No source-tree fallback | Package provenance report | Install source, digest, `repository_path_fallback?: false`, dependency outside checkout |
| Lifecycle/retry/recovery occurred | Cohort twin receipt | Domain sequence, persisted Oban attempts/errors, storage facts, public result |
| Browser interruption resumed | Playwright/tus scenario | Browser progress plus server-observed offsets; no direct storage shortcut |
| Provider disorder converged | Provider/webhook scenario | Public input, provider FSM result, dedupe, redacted telemetry |
| Cleanup removed owned residue | Twin cleanup verifier | Scenario rows/jobs/objects/temp paths absent; unrelated fixtures retained |
| CI result authoritative | Workflow/job conclusion | Scenario exit plus verifier exit; upload is supplemental |
| Release allowed | Exact-SHA `ci.yml` gate | Full push-main conclusion; no bypass/rename |

The receipt is **facts, not prose**. Use versioned JSON containing source SHA, package name/version/digest
and fallback status, scenario ID/seed/duration, bounded domain/job/telemetry/storage observations,
cleanup facts, and terminal verdict. IDs, paths, exception messages, provider metadata, and raw payloads
require redaction. Never record provider asset/upload IDs, session URIs, signed URLs, credentials, or
unbounded logs. Use the existing redacted-tag convention or a receipt-local one-way digest.

## Data Flow

### Census to change

1. Capture immutable SHA, supported toolchain, branch/worktree state, and live CI/release truth.
2. Run read-only detectors across correctness, maintainability, security, performance, reliability,
   compatibility, tests, docs/accessibility, packaging, CI/CD, release, and repository hygiene.
3. Normalize findings into stable IDs and deduplicate shared root causes.
4. Disposition every candidate. `retain`/`defer` require executable evidence and revisit triggers.
5. Freeze the census before refactor or CI topology edits. Append discoveries; never rewrite baseline.
6. Every change names its candidate and proof; reject broad aesthetic sweeps without a census entry.

### Package to twin

1. From a clean checkout, build one unpacked package per twin run with `mix hex.build --unpack`.
2. Record source SHA, version, file manifest/digest, and unpacked root before dependency fetch.
3. Set `RINDLE_DEMO_RINDLE_PATH` to that external root and prohibit Cohort's `../..` fallback in CI.
4. Migrate host-owned Oban and Rindle through Cohort's adopter migrations.
5. Start Cohort with Postgres/MinIO and **manual database-backed Oban**, not inline mode.
6. Drive public facades, HTTP/tus/webhook endpoints, and published behaviours; observe durable state.
7. Drain real queues, including scheduled work only when declared. Assert persisted attempt/state/error.
8. For restart scenarios, stop the BEAM between stages while retaining DB/storage, then start fresh.
9. Write/verify a terminal receipt, clean scenario resources, and verify zero residue. Cleanup can fail.
10. Upload the receipt with bounded retention while preserving scenario/verifier exit status.

### Failure-and-recovery matrix

| Scenario | Injection boundary | Required observations | Recovery proof |
|----------|--------------------|-----------------------|----------------|
| Storage purge transient | Host `Rindle.Storage` wrapper fails `delete/2` once, delegates otherwise | Rows retained on failure; Oban job is retryable with bounded error | Next attempt tolerates missing keys, deletes remaining objects, then durable rows |
| Tus interruption/resume | Browser/network interruption at public TusPlug | Fingerprint/resume behavior and server committed offset | PATCH resumes at offset; unchanged `verify_completion/2`; bytes/digest match |
| Variant/AV failure + repair | Public processor/runtime boundary or controlled corrupt fixture | Visible failed variant, job attempts/errors, runtime-status recommendation | Public repair/requeue reaches ready and cleans temp/storage residue |
| Provider disorder | Public webhook and/or host provider behaviour emits duplicate/out-of-order/error/ready | Verification/normalization, provider FSM, dedupe, redacted telemetry | Re-delivery/sync converges to one terminal outcome without ID leakage |
| Process restart | External runner terminates/restarts Cohort | DB rows/jobs/upload state/objects survive; no memory-only oracle | Fresh process resumes via public runtime ownership |
| Partial-failure cleanup | Scenario-scoped DB/storage/temp/job ownership | Receipt lists owned resources before cleanup | Owned residue absent; unrelated seed data stable |

Provider disorder is **synthetic provider-contract evidence**, even when using Mux-shaped webhooks. It
does not prove live Mux. Existing cassette and secret-gated Mux soak retain adapter/live ownership.

## Patterns to Follow

### Public ports, durable observations

Implement host fault controls at published behaviours or public HTTP/webhook seams. Assert public
results, documented telemetry, Ecto rows, Oban jobs, and storage. This stays stable through private
refactors and preserves the no-storage-I/O-in-transactions invariant.

### Deterministic fail-N-then-delegate

Each fault names an operation, attempt number, tagged response, scenario ID, and reset. Success delegates
to real MinIO/processor behavior. This executes the actual failure path without probabilistic sabotage.

### Manual Oban with production execution semantics

Enqueue through production code, drain named queues, and query `Oban.Job`. Include scheduled/recursive
work only by scenario contract. Official Oban docs distinguish manual mode from inline mode: inline
bypasses the database, while `drain_queue/2` uses the real execution mechanism and records retries.

### External restart stages

Coordinate prepare, terminate, resume, and verify in separate BEAM processes. Persist scenario identity
and domain data, never closures/PIDs. Restarting a child or clearing an Agent is not app-restart proof.

### Receipt contract; artifact debug aid

A pure verifier rejects partial receipts, wrong SHA/package, skipped stages, missing cleanup, and
false-green verdicts. CI artifact upload aids diagnosis but never decides success.

### Structural validators for invariants

Keep fast tests for package exclusion/provenance, workflow topology, receipt schema, finite scenarios,
comment/residue policy, and release coupling. Extend the repository's existing meta-test idiom rather
than add a new policy framework.

## Anti-Patterns to Avoid

| Anti-pattern | Why it fails | Use instead |
|--------------|--------------|-------------|
| Private-worker simulator: private calls/structs/source snapshots/internal Mux client stubs | Proves implementation mimicry, misses orchestration wiring, resists safe refactor | Public facades/HTTP/behaviours plus durable outcomes |
| Inline or `perform_job/2` evidence labelled retry proof | Does not exercise persisted scheduling/retry/terminal state | Keep direct execution in unit tests; manual Oban for twin claims |
| Fourth demo or shipped `Rindle.Twin` API | Duplicates proof layers and expands support surface | Cohort test-support + maintainer runner |
| Repository path fallback | Hides missing package files/metadata/config | External unpacked artifact with recorded digest and fail-closed provenance |
| Random/time-based chaos | Flaky, slow, irreproducible | Fixed fail counts, explicit deadlines, terminal receipts |
| Skip-as-green/upload-as-pass | Manufactures confidence | Required local scenarios fail closed; live soaks remain separately labelled |
| Aesthetic refactor before truth | Obscures causes and destroys comparability | Frozen census, then candidate-scoped change + proof |

## CI Placement

| Tier | Placement | Content | Gate semantics |
|------|-----------|---------|----------------|
| Fast structural | Existing `proof`, `adoption-demo-unit`, CI script tests | Census/receipt schema, finite registry, no-private-dependency, package provenance | Every PR through `CI Summary` |
| Representative behavioral | Existing adopter/lean browser/package lanes; add only after timing | One bounded local recovery tracer if within budget | Merge-blocking only with comparable timing evidence |
| Full twin | Separate push-main job in `ci.yml` or bounded existing full-Cohort stage | Built-package Cohort, all deterministic recovery/restart/cleanup | Non-masked; omitted from PR summary; failure makes whole `CI` run red and blocks release |
| Repetition/live | `nightly.yml` and existing secret-gated soaks | Repeated deterministic matrix, toolchain drift, live GCS/Mux | Advisory to branch protection; never substitutes for local proof |

Do not put the full twin on the PR critical path by default. Measure first. If one tracer fits the
accepted median/p95 envelope, place it in an existing required root instead of adding a branch-protection
context. Preserve independent required roots, `ci.yml`, `name: CI`, `CI Summary`, and release whole-run
gating. Use pinned `upload-artifact`, `if: always()`, `if-no-files-found: error`, and short retention;
keep workflow permissions read-only and receipts redacted.

## Dependency-Ordered Build Plan

1. **Truth restoration and frozen census**
   - Minimally repair the supported-toolchain Nightly Dialyzer failure.
   - Reconcile release/adoption/project truth and triage live issues/PRs.
   - Capture clean baselines and enumerate candidates before refactor/CI edits.

2. **Evidence contracts and package provenance**
   - Freeze receipt/redaction/scenario/package identity/timeout/zero-residue contracts.
   - Add fast validators before expensive scenarios; extend the existing artifact builder.

3. **Measured repository and code craft**
   - Fix census-backed clarity, comment, residue, complexity, type, coverage, and bootstrap items.
   - Run SAFE-01/domain proof per cohesive owner. Deletion requires consumer/provenance evidence.

4. **Cohort twin foundation and backend recovery**
   - Add registry, public-port fault controls, manual Oban, receipts, package-only boot, cleanup.
   - Prove purge retry, variant failure/repair, durable jobs, and real process restart first.

5. **Browser and provider disorder**
   - Extend tus Playwright proof to interruption/resume with offsets/bytes.
   - Exercise duplicate/out-of-order provider events through public seams; preserve Mux proof layers.

6. **CI/CD integration and efficiency ratchet**
   - Put fast validators on PR and full twin on push-main; add Nightly repetition after stability.
   - Measure critical path/cost before changing dependencies, caching, or PR coverage.

7. **Clean-checkout readiness closure**
   - Run toolchain, package, generated consumer, twin, docs, hygiene, CI, Nightly, release-train,
     remote-inbox, and clean-worktree checks from fresh checkout.
   - Accept only verified receipts tied to closing SHA/package; no manual UAT closes requirements.

**Ordering rationale:** truth/census precedes mutation; evidence contracts precede scenarios; durable
backend recovery precedes browser/provider breadth; CI changes follow measurements; clean-checkout
proof runs after mutations settle.

## Scalability Considerations

| Concern | Current milestone | First adopter | Later scale |
|---------|-------------------|---------------|-------------|
| Scenarios | Finite curated registry | Add only incidents/named workflows | Partition by capability, not randomization |
| Fault state | Scenario-scoped control + durable observations | Per-run namespace | External service only if cross-node need appears |
| DB/storage | Explicit prefix/UUID and cleanup | Per-run DB/object prefix | Disjoint DB/buckets for parallel workers |
| Oban | Manual bounded drains | Real supervised soak instance | Cross-node queues only from named requirement |
| Receipts | Small redacted JSON | CI artifacts + selected planning summary | Version schemas; aggregate outside product DB |
| CI cost | Full twin push-main; contracts PR | Add tracer if budget permits | Shard only after measured bottleneck |

## Gaps and Phase Research Flags

- The required `.planning/codebase/ARCHITECTURE.md` does not exist. Current architecture was
  reconstructed from assigned behaviours, proof code, workflows, `RUNNING.md`, and project decisions.
- Exact Mux disorder fixtures require phase-local review of the adapter/webhook plug; do not freeze
  payloads from memory.
- `ProcessVariant` selects built-in processors internally. If a host processor cannot be selected
  without public API change, use a controlled corrupt fixture/runtime precondition and existing repair
  API rather than adding an API solely for the twin.
- Full-twin PR placement remains measurement-gated; default is push-main plus PR structural coverage.

## Sources

### Repository (HIGH confidence)

- `.planning/PROJECT.md`, `.planning/DEVELOPMENT-TRAIN.md`
- `test/install_smoke/support/generated_app/workspace.ex` and generated-app helpers
- `test/adopter/canonical_app/lifecycle_test.exs`
- `examples/adoption_demo/README.md`, Mix/application config, proof matrix, and E2E specs
- `lib/rindle/storage.ex`, `lib/rindle/processor.ex`, `lib/rindle/streaming/provider.ex`
- `lib/rindle/workers/*`, `lib/rindle/ops/*`
- `.github/workflows/ci.yml`, `.github/workflows/nightly.yml`, `RUNNING.md`
- `scripts/maintainer/refactor_contract.sh`, `repo_hygiene_check.sh`, install-smoke meta-tests

### Official documentation (MEDIUM confidence after routed lookup)

- [Oban: Introduction to Testing](https://hexdocs.pm/oban/testing.html)
- [Oban: `drain_queue/2`](https://oban.hexdocs.pm/Oban.html#drain_queue/2)
- [Hex: `mix hex.build`](https://hex.hexdocs.pm/Mix.Tasks.Hex.Build.html)
- [GitHub Actions: Store and share workflow artifacts](https://docs.github.com/en/actions/tutorials/store-and-share-data)
- [GitHub Actions secure-use reference](https://docs.github.com/en/actions/reference/security/secure-use)
