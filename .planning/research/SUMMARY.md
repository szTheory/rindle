# Project Research Summary

**Project:** Rindle — v1.26 Pre-Adopter Readiness & Quality Consolidation
**Domain:** Pre-adopter quality consolidation and synthetic lifecycle assurance for an Elixir/Phoenix/Ecto Hex library
**Researched:** 2026-09-09
**Confidence:** HIGH for repository scope and ordering; MEDIUM-HIGH for the new twin harness until phase-local proof

## Executive Summary

Rindle is a mature Phoenix/Ecto media-lifecycle library entering a maintenance and assurance milestone, not a greenfield build. The product already has strong public contracts, generated-package consumers, a canonical adopter, a realistic Cohort host, broad CI and release automation, 82.1343% exact coverage, a 31-finding reviewed complexity baseline, and a 35-entry removal-only Dialyzer baseline. The reason to act now is current evidence, not taste: repeated scheduled Nightly failures on immutable `main`, misleading Nightly aggregation, two open issues, six open Dependabot pull requests, reported Mint advisories, release/adoption-truth drift, planning-era residue in live comments, and failure/recovery claims that existing happy-path proof does not execute.

The recommended approach is an evidence plane around the existing product. First freeze a finite, current-head quality census and restore live Nightly, release, dependency, and inbox truth. Then make only candidate-backed repository, code, comment, static-analysis, test, and CI improvements. Preserve the product stack and all public behavior; add only checksum-verified actionlint for GitHub Actions semantics and replace mutable external inputs with exact checksums or image digests. Finally, extend Cohort—not a new demo—into a built-package synthetic adopter twin using real Postgres, persisted Oban jobs, MinIO/FFmpeg, public interfaces, deterministic test-host faults, restart stages, and validated JSON receipts.

The dominant risks are false confidence and cleanup churn. Counts must not improve through deletion, ignores, denominator changes, source-literal tests, reruns, or skipped work; CI must not become faster by moving failures into an advisory void; and the twin must not seed its target failure states, use inline-only Oban, import private implementation, or call itself a first adopter. Every change therefore binds to an immutable revision, a stable finding or scenario, preservation checks, and a machine-readable verdict. The milestone closes only from an exact-head clean checkout with zero unexplained residue and one fail-closed evidence manifest. Synthetic evidence reduces adopter risk but never satisfies the named independent Phoenix pilot gate for 1.0.

## Key Findings

### Recommended Stack

Keep the application and test stack unchanged. ExUnit, Oban.Testing, Mox, Bypass, Jason, Playwright, Cohort, generated package consumers, Credo, Dialyzer, Doctor, ExCoveralls, `mix_audit`, and repository-owned Bash/Elixir collectors already cover the required seams. Add no runtime dependency, product table, public module, fault API, event store, queue simulator, or fourth example application. See [STACK.md](./STACK.md).

**Core technologies and decisions:**

- **Elixir/OTP:** preserve the public Elixir `~> 1.15` floor and supported CI pairs; record exact resolved patch versions rather than widening compatibility during cleanup.
- **Phoenix/Ecto/PostgreSQL:** keep Cohort as the adopter-owned host and use existing domain, Oban, and storage state for durable observations; add no evidence database.
- **Oban 2.21:** enqueue through production code and use database-backed manual drains for deterministic retry evidence; reserve a supervised normal-mode subprocess for true restart/recovery.
- **Mox/Bypass/cassettes:** inject deterministic faults at published behaviour and HTTP/provider seams in test support, never through production `lib/` switches.
- **MinIO and FFmpeg/FFprobe:** exercise real local storage and media processes while pinning images/binaries by immutable digest or verified release checksum.
- **Jason and Playwright:** emit one validated JSON authority artifact and extend existing Cohort browser proof; do not add a schema framework, Cypress, or a browser SaaS.
- **Credo, Dialyzer, Doctor, ExCoveralls, and `mix_audit`:** retain the curated gates and removal-only policies; tools surface candidates but do not dictate architecture.
- **actionlint 1.7.12:** the sole new tool, installed from the exact release asset with its published SHA-256; run once through the existing CI-script seam and the local `mix ci` path.

### Expected Features

The milestone's “features” are readiness capabilities with executable acceptance, not new adopter-facing product breadth. See [FEATURES.md](./FEATURES.md).

**Must have (table stakes):**

- A versioned current-head quality census spanning the complete finite quality taxonomy, with every deduplicated candidate assigned exactly one `fix`, `retain`, or trigger-bound `defer` disposition.
- Repaired supported-toolchain Nightly Dialyzer behavior for fresh and cache-hit PLTs, truthful aggregate conclusions, and one incident lifecycle that opens/updates on failure and closes only after qualifying scheduled recovery.
- Explicit dependency-security and remote-inbox disposition for the live Mint advisories, two issues, and six Dependabot PRs; inbox zero is not required, but undispositioned work is forbidden.
- Reconciled release, adoption, planning, and support claims derived from authoritative files rather than duplicated stale literals.
- Proven repository hygiene from a clean checkout: intentional tracked content, narrow ignore rules, reproducible generated assets, correct package contents, and no post-run residue.
- Candidate-bounded self-describing code and present-tense comments, retaining rationale, invariants, ownership, ordering, security, and failure semantics while removing obsolete narration and artifacting.
- Removal-only complexity and type ratchets, behavior-led test/coverage work, finite resolution or honest retention of issue #42, reproducible contributor commands, and bounded deterministic CI that preserves the accepted PR envelope of no more than 480 seconds median and 600 seconds p95.
- A Cohort-centered twin that consumes a freshly built external package, uses adopter-owned Repo/Oban/migrations and real local services, rejects checkout fallback/private coupling, and executes failure rather than seeding its target state.
- A finite scenario set covering interrupted tus resume, transient purge retry, AV failure and repair, duplicate/out-of-order provider events, process restart, idempotent rerun, and cleanup with zero owned residue.
- Versioned machine-readable receipts tied to source SHA and package checksum, plus one exact-head readiness manifest that rejects stale, partial, skipped-as-green, foreign-SHA, or dirty evidence.

**Should have (differentiating assurance):**

- Cross-layer receipts correlating public stimulus, durable lifecycle rows, Oban attempts, storage/provider effects, redacted telemetry, recovery, and cleanup.
- Deterministic fail-N-then-delegate fault choreography without changing the shipped package API.
- A restartable, deadline-bounded twin controller whose durable stages survive BEAM termination without duplicate stimulus.
- Explicit residue accounting and an idempotent janitor tested under interruption.
- A support-claim map that names proof level (`local`, `cassette`, or `live`) and refuses to describe absent/skipped evidence as verified.
- A quality-debt budget whose default is negative delta and whose exceptions retain stable identity, owner, rationale, and removal trigger.

**Defer beyond v1.26:**

- The named independent Phoenix pilot and real-adopter validation; the maintainer-operated twin is deliberately not a substitute.
- LIFE-06, STREAM-10, TRANS-01, PRIV-01, tus 2.0/RUFH, GCS-as-tus-backend, uploader kits, and any other unsupported product breadth without its required adopter/compliance signal.
- Runtime-facade, GCS, or Mux compile-cycle decomposition; partitioning; and broad cache-topology redesign unless the census produces current measured harm.
- Broad dependency batches, 100% coverage, comment-density/file-size targets, randomized chaos, live-cloud PR gates, and general-purpose quality platforms.

### Architecture Approach

Add an evidence plane around Rindle rather than changing the product plane. A current-SHA census owns disposition truth; existing preservation suites freeze public API, migrations/schema, telemetry, errors, compile boundaries, and release coupling; existing generated-app machinery owns package identity and no-fallback proof; and Cohort owns the new test-only scenario registry, deterministic external-boundary fault controls, staged runner, receipt builder/verifier, and cleanup ledger. CI runs fast structural contracts on every PR, the full deterministic twin on `push:main`, and separately labelled live/provider repetition on Nightly. See [ARCHITECTURE.md](./ARCHITECTURE.md).

**Major components:**

1. **Quality census coordinator** — runs repository-owned detectors, normalizes stable findings, and rejects missing, duplicate, or open dispositions.
2. **Preservation and hygiene contracts** — protect public/runtime/release behavior while proving tracked content, ignores, generated outputs, package contents, and clean-checkout closure.
3. **Package provenance owner** — builds one external unpacked Hex artifact and records source SHA, package digest, manifest, toolchain, and `repository_path_fallback?: false`.
4. **Cohort scenario registry and runner** — declares a finite matrix, drives only public facades/HTTP/tus/webhook seams, and coordinates prepare/fail/restart/recover/verify stages.
5. **Test-host fault controls** — fail named storage, processor, and provider operations on deterministic attempts, then delegate to real dependencies.
6. **Receipt builder, verifier, and resource ledger** — records redacted observations and rejects unknown, partial, skipped, foreign, unclean, or stale results.
7. **CI evidence placement** — keeps `ci.yml`, workflow `name: CI`, `CI Summary`, exact-SHA release coupling, independent required roots, and PR timing invariants unchanged unless separately proven.

### Critical Pitfalls

See [PITFALLS.md](./PITFALLS.md) for the full threat catalogue.

1. **Aesthetic churn masquerading as maintainability** — freeze the census first; require a measured trigger, bounded owner, before/after evidence, and preservation suite for every craft change.
2. **Comment or repository cleanup destroying useful provenance** — prefer names and structure, retain present-tense rationale, and require generator/consumer/package proof before deleting or ignoring anything.
3. **Metrics, coverage, or Dialyzer theater** — bind baselines to SHA/toolchain/config/denominator and stable finding identity; prohibit broader ignores, private-literal tests, rerun-to-green, and unexplained identity substitution.
4. **CI optimization creating false green or breaking releases** — model fork PR, same-repo PR, push-main, dispatch, secret-absent, failure, cancel, and skip outcomes; preserve the sole aggregate check and full exact-SHA release gate.
5. **A twin proving its own implementation** — consume the built package, prohibit private calls and target-state seeding, create failures through executed work, and observe public results plus durable DB/job/storage/telemetry effects.
6. **Skipped live proof or leaked residue reported as success** — distinguish `passed`, `failed`, and `not_run`; namespace all resources, run cleanup even after failure, independently verify zero residue, and never let upload success determine the job verdict.
7. **Synthetic evidence promoted to adopter validation** — stamp receipts `evidence_subject: synthetic_maintainer_twin` and keep the independent-pilot requirement open.

## Implications for Roadmap

Research proposed seven- and eight-phase variants. The smallest coherent dependency-ordered recommendation is seven phases, continuing after v1.25 at Phase 133. It combines closely coupled evidence work while preserving separate rollback and verification boundaries for dependency changes, craft changes, and twin construction.

### Phase 133: Evidence Charter and Live Truth

**Rationale:** Evidence must be trustworthy before any cleanup or optimization can claim improvement. The current scheduled Dialyzer red and misleading Nightly summary are release-readiness blockers.

**Delivers:** immutable baseline metadata; complete quality taxonomy; versioned census/disposition schema; tested collectors; exact Nightly failure fingerprint; cold/warm supported-cell PLT repair; truthful aggregation; scheduled incident open/update/close behavior; release/planning/adoption parity.

**Addresses:** current-head census, Nightly recovery, truthful incident lifecycle, release/planning truth.

**Avoids:** infinite enumeration, stale/self-referential metrics, green-by-ignore, rerun-to-green, and synthetic-adopter claim inflation.

### Phase 134: Dependency, Security, and Inbox Disposition

**Rationale:** Dependency changes and remote mutations need isolated attribution and rollback; combining them with craft refactors would make failures ambiguous.

**Delivers:** read-only inbox snapshot; reachability and supported-toolchain analysis for reported advisories; one machine-readable disposition per open issue and PR; small risk-group dependency changes where authorized; exact-check/package/adopter proof; retained/deferred triggers for items that must remain open.

**Addresses:** security-advisory closure, six Dependabot PRs, issues #42/#88, compatibility truth.

**Avoids:** bulk merge/close, inbox-zero theater, dependency/refactor coupling, and premature incident closure.

### Phase 135: Repository and Code-Craft Consolidation

**Rationale:** Craft work begins only from the frozen census and stable live baseline. Repository provenance and comment meaning must be understood before deletion or rewriting.

**Delivers:** tracked/ignored/generated-content ledger; narrow `.gitignore` corrections; byte-identical regeneration checks; package-exclusion proof; reviewed disposition of live planning IDs, mojibake, duplicate prose, and artifact comments; candidate-scoped naming, cohesion, and readability improvements under SAFE/refactor/public-contract gates.

**Addresses:** repository hygiene, clean-checkout reproducibility, self-describing code, present-tense comments, proven residue cleanup.

**Avoids:** blanket rewrites, comment quotas, arbitrary splits, archive destruction, broad ignore rules, and accidental API/schema/telemetry/error drift.

### Phase 136: Measured Quality and CI Ratchets

**Rationale:** Once repository and ownership boundaries are clear, measured debt can be reduced without confusing baseline residue with new behavior. Existing CI truth and supply-chain inputs should be hardened before the twin depends on them.

**Delivers:** removal-only complexity and Dialyzer identities; behavior-led coverage/test improvements; bounded #42 evidence; contributor reproduction map; checksum-verified actionlint; immutable image/binary inputs; justified job/process timeouts; cache and workflow-event contracts; removal of equivalent duplicate CI work; exact-ten PR timing receipt after any topology change.

**Addresses:** complexity/type/test/coverage integrity, contributor bootstrap, deterministic bounded CI/CD, supply-chain reproducibility.

**Avoids:** metric gaming, accepted-cycle reopening, private-source snapshots, mutable downloads, six-hour hangs, skip-propagation mistakes, and median-only optimization.

### Phase 137: Built-Package Twin Foundation

**Rationale:** Evidence and cleanup contracts must exist before destructive scenarios. Defining package identity, receipt semantics, namespaces, and process stages first prevents each scenario from inventing incompatible proof.

**Delivers:** external unpacked-package consumption with no checkout fallback; finite scenario registry; public-boundary/private-coupling guard; database-backed manual Oban substrate; supervised restart stage; deterministic fail-N-then-delegate adapters; append-only resource ledger; idempotent janitor; versioned redacted JSON receipt and fail-closed verifier.

**Addresses:** built-package synthetic adopter, deterministic fault choreography, restartable controller, residue accounting, receipt authority.

**Avoids:** a fourth demo, production fault switches, inline-only retry claims, target-state seeding, private-worker simulation, shared namespaces, and upload-as-pass.

### Phase 138: Lifecycle Failure and Recovery Matrix

**Rationale:** Backend durability and receipt machinery should be proven before adding browser/provider breadth. Each scenario must execute a real failure and converge through supported behavior.

**Delivers:** storage purge transient→persisted retry→success/authoritative absence; AV/variant failure→visible state→public repair; host restart between durable transitions; interrupted browser tus upload→offset-correct resume; duplicate/out-of-order provider inputs→idempotent convergence; idempotent reruns; cleanup-interruption and janitor-twice proof; full twin CI placement after measurement.

**Addresses:** failure/recovery table stakes, cross-layer receipts, support-claim coverage map, deterministic local/cassette assurance.

**Avoids:** happy-path demo expansion, swallowed drain errors, fake restarts, contaminated retries, and cassettes/minio mislabeled as live-provider proof.

### Phase 139: Exact-Head Readiness Closure

**Rationale:** Readiness is a property of one immutable revision and package after all mutations settle, not the sum of stale phase-local successes.

**Delivers:** isolated clean-checkout execution; supported toolchain, format/compile/Credo/Dialyzer/Doctor/coverage/security/docs proof; package and generated-consumer proof; complete twin receipt; honest live-provider `passed|failed|not_run` companion receipts; green exact-head CI and Nightly; release-train and inbox reconciliation; pre/post worktree and ignored-residue inventory; one fail-closed closeout manifest.

**Addresses:** clean readiness closure and truthful adopter-readiness claims.

**Avoids:** shared-worktree false greens, stale/wrong-SHA evidence, secret-gated skips reported as pass, residue leaks, and synthetic evidence satisfying the 1.0 pilot.

### Phase Ordering Rationale

- Freeze current evidence before mutation so cleanup cannot erase its own baseline and metrics remain comparable.
- Repair blocking live truth before aesthetic work; isolate dependency/inbox changes from refactors for attribution and rollback.
- Complete repository/code ownership work before ratcheting metrics and CI; harden existing CI inputs before building new assurance on them.
- Freeze package, receipt, fault, restart, namespace, and cleanup contracts before scenario implementation.
- Prove backend failure/recovery before browser/provider breadth; integrate the full twin only after its cost and determinism are measured.
- Re-run everything from one isolated exact-head checkout after all changes settle; no human UAT or synthetic-adopter claim closes an automated requirement.

### Research Flags

Phases likely needing deeper research during planning:

- **Phase 133:** capture the exact immutable Nightly failure and determine the minimum correct PLT cache/rebuild authority; remote recurrence establishes urgency but is not a diagnosis.
- **Phase 134:** inspect every dependency lock diff and advisory path; current remote status cannot determine safe grouping, reachability, or mutation authority.
- **Phase 137:** design the minimum production-faithful Oban topology, package handoff, restart controller, redaction schema, and fault seams against current Cohort/Rindle ownership.
- **Phase 138:** inspect exact tus, purge, AV, Mux/webhook, telemetry, and cleanup seams; provider payloads and recovery transitions must come from current code and official contracts, not memory.
- **Phase 139:** resolve current live-provider credential/API/cleanup conditions and define honest `not_run` handling without delaying deterministic closure.

Phases with sufficiently established patterns to skip broad research:

- **Phase 135:** repository provenance, Git ignore, regeneration, present-tense comment, and preservation-contract patterns are fully specified; use targeted code inspection during planning.
- **Phase 136:** existing baselines and CI invariants are strong; only exact image digests/checksums and measured timeout/timing values require validation, not another ecosystem survey.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Existing dependencies, tool versions, workflows, and integration seams were inspected directly; only future external digests/checksums require implementation-time resolution. |
| Features | HIGH | Scope follows the current repository, v1.25 exact baselines, live Nightly/inbox signals, and explicit v1.26 boundaries. |
| Architecture | MEDIUM-HIGH | Evidence-plane boundaries and proof-layer ownership are grounded in existing package/Cohort infrastructure; the new restart/fault harness still needs phase-local execution proof. |
| Pitfalls | HIGH | Risks are tied to concrete workflow, hygiene, Dialyzer, Oban, adoption-matrix, and release behaviors plus official GitHub/Oban/Git semantics. |

**Overall confidence:** HIGH for milestone roadmap and boundaries; MEDIUM-HIGH for detailed twin mechanics.

### Gaps to Address

- **Nightly root cause:** capture the exact current failure logs and cache metadata before changing the PLT key or rebuild policy.
- **Dependency grouping:** evaluate each of the six PRs independently against supported toolchains, package consumers, and advisory reachability before grouping or mutating remote state.
- **Container and binary identities:** resolve target-architecture digests for Postgres/MinIO/Playwright and immutable checksums for MinIO Client and the selected retained FFmpeg build.
- **actionlint policy:** run 1.7.12 against current workflows and allow only evidence-backed repository-specific exceptions.
- **Oban twin topology:** prove when manual database-backed drains suffice and where a separately supervised normal-mode BEAM is required for restart semantics.
- **Processor injection:** if the current variant worker cannot select a host processor through supported configuration, use a corrupt fixture/runtime precondition and the existing public repair API rather than adding a twin-only product API.
- **Mux/GCS realism:** deterministic provider disorder is synthetic contract evidence; live APIs remain separately labelled and may honestly be `not_run` when credentials are unavailable.
- **CI placement:** keep the full twin off the PR critical path by default; add at most a measured tracer if the exact-ten receipt remains inside the accepted envelope.
- **Architecture source gap:** no codebase-map architecture dossier is available; phase planning should continue using inspected behaviors, proof code, workflows, `RUNNING.md`, and locked project decisions.

## Sources

### Primary (HIGH confidence)

- [PROJECT.md](../PROJECT.md) — milestone goal, no-churn boundary, support truth, locked product decisions, accepted v1.25 baselines, and independent-adopter limitation.
- [STACK.md](./STACK.md), [FEATURES.md](./FEATURES.md), [ARCHITECTURE.md](./ARCHITECTURE.md), and [PITFALLS.md](./PITFALLS.md) — the four v1.26 research dossiers synthesized here.
- Repository implementation and policy surfaces cited by the dossiers: `mix.exs`, `mix.lock`, `.dialyzer_ignore.exs`, `RUNNING.md`, `.github/workflows/ci.yml`, `.github/workflows/nightly.yml`, setup composites, release workflows, hygiene/refactor scripts, generated-app consumers, canonical adopter, Cohort, and the adoption-proof matrix.
- Immutable repository evidence cited by the dossiers: v1.25 audit and receipts, 31 reviewed complexity findings, 35 supported-toolchain Dialyzer filters, and 82.1343% exact coverage.
- Live GitHub snapshot captured by research on 2026-09-09: repeated Nightly failures, issues #42/#88, six Dependabot PRs, and current advisory output.

### Secondary (MEDIUM confidence)

- Official GitHub Actions documentation — workflow semantics, secure pinning, caches, artifacts, and job/step timeout behavior.
- Official Oban documentation — inline/manual testing boundaries, `perform_job/3`, `drain_queue/2`, retries, and persisted job execution.
- Official Elixir/Dialyxir documentation — coverage meaning and warning-ignore policy.
- Official Git, Hex, Docker, actionlint, MinIO, BtbN FFmpeg, ISO/IEC 25010/25023, NIST V&V/digital-twin, and JSON/RFC references cited in the detailed dossiers.

## Files Created/Modified

- `.planning/research/STACK.md` — stack and tooling recommendations.
- `.planning/research/FEATURES.md` — readiness capabilities and anti-features.
- `.planning/research/ARCHITECTURE.md` — evidence-plane and twin architecture.
- `.planning/research/PITFALLS.md` — failure modes and automated mitigations.
- `.planning/research/SUMMARY.md` — synthesized roadmap implications.

## Commits

- `3ec0d2a` — `docs: complete project research`

## Self-Check

✅ Passed: all five research artifacts exist, the synthesis is substantive and sentinel-free, the seven-phase roadmap preserves the locked boundaries, and the original research commit resolves in Git history.

---
*Research completed: 2026-09-09*
*Ready for roadmap: yes*
