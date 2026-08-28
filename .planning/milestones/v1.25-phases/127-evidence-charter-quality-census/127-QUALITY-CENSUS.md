# Phase 127 Quality Census

**Scope:** non-Admin shipped code, tests, maintainer scripts, contributor guidance, and required CI

**Captured:** 2026-08-24

**Decision rule:** change code only when the result improves reader orientation, ownership, failure
diagnosis, or feedback latency without weakening a behavior or proof contract.

## Craft rubric

A candidate earns implementation work when it has at least one concrete reader cost:

- one owner contains unrelated decisions that change for different reasons;
- history explains when code arrived but not why its present behavior is necessary;
- a test knows private source layout instead of an observable or structured contract;
- a required feedback lane waits or installs tools without a data or proof dependency;
- a measured complexity finding obscures a decision boundary that can be named cleanly.

Line count, advisory count, dependency direction, and prose taste are discovery signals only. They
do not justify extraction, alias churn, abstraction, or a new permanent gate by themselves.

## Baseline receipts

| Signal | Baseline | Closure rule |
|--------|----------|--------------|
| Required PR CI | 29 non-cancelled runs: 13.8 min median, 15.4 min p95 | 10 comparable runs at <=8 min median and <=10 min p95 |
| Required image consumer | roughly 8–9 min and sequenced after Quality | starts independently; same packed image proof and CI Summary gate |
| Coverage | 82.13% across 6,268 executable lines | authoritative result stays >=82.13% |
| Strict Credo | 143 advisories: 83 design, 44 refactor, 16 readability | advisory total is descriptive, not a blanket cleanup target |
| Curated complexity | 35 weighted findings: 13 cyclomatic, 22 nesting | remove the four IntegrationChecks findings; weighted baseline <=31 |
| Explicit planning markers | 646 non-Admin candidate lines; 129 test names | every candidate reviewed; changed production prose is present-tense |
| Source-reading tests | 54 files | no private-helper layout snapshots; artifact contracts state their boundary |
| Runtime dependency graph | four cycles: lengths 12, 5, 3, and 2 | no new compile-connected cycle |

## Candidate ledger

| Candidate | Disposition | Reader-value rationale / proof |
|-----------|-------------|--------------------------------|
| `RuntimeChecks.IntegrationChecks` owns Mux and GCS checks | **Fix** | Hide two cohesive provider owners behind the existing facade; preserve ordering, IDs, shapes, seams, telemetry, and vocabulary. |
| Four curated complexity/nesting findings in that module | **Fix** | Named provider helpers make control flow local; remove the exact findings rather than moving them. |
| Runtime-check mixed test suite | **Fix** | Separate core/ownership/migration, GCS/configuration, and existing streaming/orchestration contracts. |
| Upload-maintenance mixed test suite | **Fix** | Separate cleanup, standard/GCS abort, and tus retry/reaper behavior; share stable fixtures through one support case. |
| Production `lib/` comments that narrate phases/plans | **Fix** | Replace with current invariants and compatibility/safety reasons. Admin is explicitly out of scope. |
| Historical IDs in untouched tests and CI policy | **Defer** | A repository-wide rename is review-noisy and can obscure stable contract labels. Review by touched boundary; preserve archived provenance and separately schedule any file whose prose fails the rubric. |
| Required coverage command uses `--slowest 20` | **Fix** | ExUnit trace mode forces `max_cases: 1`; keep seed/JUnit/JSON evidence without serializing async tests. |
| Required image consumer waits for Quality and Optional Dependencies | **Fix** | It consumes neither lane's outputs; CI Summary still joins and gates all required results. |
| Node and FFmpeg setup in image-only consumer | **Fix** | Image profile uses libvips and MinIO, not Node or FFmpeg. Full video proof remains on main/release. |
| Development-environment version check recompiles dependencies | **Fix** | Read the already compiled test project with `--no-compile`; version semantics are unchanged. |
| Phoenix generator availability is unpinned and duplicated | **Fix** | One helper owns version 1.8.9 and proves cold install, reuse, and actionable mismatch failure. |
| Contributor command list omits `quality_signals` and lacks ownership routing | **Fix** | Correct the documented alias and publish a change-to-proof map. |
| Five-schema association cycle | **Retain** | Associations are the domain model; breaking them for a graph count would make schemas harder to navigate. |
| Twelve-node facade/worker cycle | **Defer** | No demonstrated compile or change-risk harm; extraction would invent a new abstraction boundary. |
| GCS three-node and Mux two-node configuration cycles | **Defer** | Small runtime configuration relationships are cohesive and have no measured compile penalty. |
| Ordered migration and upload decision tables | **Retain** | Branch density is the behavior and refusal vocabulary; table-shaped code is easier to audit intact. |
| Generated-app helper/source owners | **Retain** | They assemble one shipped clean-room consumer proof and change as one artifact. |
| Single CI workflow file | **Retain** | Required-check topology is easier to audit in one graph; optimize dependencies, not file count. |
| Broad strict-Credo design preferences | **Defer** | `alias`, pipe, nesting, and module-size suggestions require local reader evidence; no metric-only sweep. |
| Dependency/toolchain upgrades, test partitions, cache redesign | **Defer** | Separate risk and measurement work; no evidence justifies coupling it to this milestone. |

## Source-reading audit

All 54 files containing `File.read/1` or `File.read!/1` were classified:

| Class | Files | Disposition |
|-------|------:|-------------|
| Packed consumer, release, workflow, script, and documentation contracts under `test/install_smoke/` | 26 | **Retain.** These read shipped artifacts or executable fixtures, not private helper layout. |
| Async/focus/planning policy guards | 3 | **Retain.** They inspect repository policy across a bounded file set. |
| Behavioral fixtures, uploaded objects, generated reports, keys, and structured schema AST | 23 | **Retain.** The bytes or parsed structure are the exercised behavior. |
| Admin/brandbook files | 2 | **Excluded.** Explicit milestone boundary. |

The only production-source inspection in scope is
`schema_prefix_contract_test.exs`: it obtains each compiled module's source path from BEAM metadata,
parses the AST, and verifies the schema-prefix contract structurally. No test snapshots a private
function body or asserts a helper's line-oriented implementation.

## Provenance review boundary

- Historical `.planning/` archives are durable evidence and excluded.
- Admin and brandbook surfaces are excluded by the milestone charter.
- Public compatibility snapshots, release guards, planning-path hygiene, and stable contract labels
  may retain identifiers when the identifier is itself the enforced artifact.
- Production prose changed by this milestone must explain a current invariant, safety boundary,
  compatibility constraint, or failure behavior. A subjective “AI text” detector is forbidden.

## Change-to-proof skeleton

The current command map lives in `CONTRIBUTING.md`. Each slice runs its focused tests, then
`mix quality_signals`, SAFE-01 through `scripts/maintainer/refactor_contract.sh`, and the relevant
integration or packed-consumer boundary. Required-check names and release proof breadth do not
change.

## Closure still requiring external evidence

The ten-run PR timing receipt cannot be produced locally. Phase 132 remains open until ten
comparable, non-cancelled PR runs exist. Runner incidents may be excluded only with job-level
evidence, a named owner, and a dated follow-up.
