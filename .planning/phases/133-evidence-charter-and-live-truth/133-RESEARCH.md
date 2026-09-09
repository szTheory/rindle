# Phase 133: Evidence Charter and Live Truth - Research

**Researched:** 2026-09-09
**Domain:** Repository-owned evidence manifests, GitHub Actions aggregate policy, Dialyxir PLT integrity, incident automation, and executable truth parity
**Confidence:** HIGH for repository topology and the observed Nightly failure; MEDIUM for the proposed internal manifest/helper boundaries until implementation tests exercise them

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Evidence census authority
- **D-01:** Use one versioned, machine-validated census manifest bound to the current immutable Git SHA,
  resolved toolchain, and detector/configuration inputs. A prose-only extension of the Phase 127 census
  is not authoritative.
- **D-02:** Cover the finite applicable taxonomy: correctness, maintainability, security, performance,
  reliability, compatibility, testing, documentation/accessibility, packaging, CI/CD, release
  engineering, and repository hygiene.
- **D-03:** Normalize and deduplicate candidate identity, then require every unique candidate to have
  exactly one `fix`, `retain`, or trigger-bound `defer` disposition. Missing, duplicate, open, or
  untriggered-defer entries fail validation.
- **D-04:** Freeze this census before Phases 135 and 136 change the baseline; later work must preserve
  candidate identity and trace each mutation back to the frozen ledger.

### Supported Nightly Dialyzer evidence
- **D-05:** Keep the single Elixir 1.17 / OTP 27 Nightly cell as the supported Dialyzer authority; do
  not widen the support matrix or move Dialyzer onto the PR critical path in this phase.
- **D-06:** Require independent automated evidence for both cold/fresh PLT construction and restored-PLT
  analysis. A warm-only pass, a cache-miss-only repair, or a green result obtained by widening
  `.dialyzer_ignore.exs` is insufficient.
- **D-07:** Preserve the existing narrow, identity-specific suppression policy. Stale or incompatible
  PLT evidence must be detected and rejected or rebuilt rather than retried into an unexplained green.
- **D-08:** Capture the current pre-mutation failure fingerprint through authenticated read-only GitHub
  evidence. Public metadata proves Nightly #94–#101 failed on SHA
  `45ebde5e1bb851eb6e8a943ef68c52a714684661` through the restored-cache path, but the exact Dialyzer
  warning and cache contents remain unknown until job logs are collected.

### Nightly verdict and incident lifecycle
- **D-09:** Add a Nightly-specific, fail-closed aggregate policy distinct from PR `CI Summary`. Every
  declared gating job must have explicit applicability; `failure`, `cancelled`, missing/unexpected
  results, and impermissible `skipped` results are non-green.
- **D-10:** An explicitly inapplicable repository- or secret-gated job may be exempted only through a
  machine-checked applicability rule. Configuration absence must not silently become passing evidence.
- **D-11:** The aggregate verdict controls both the Nightly workflow conclusion and incident eligibility;
  the human-readable summary alone is not evidence authority.
- **D-12:** Maintain one rolling `nightly-failure` incident. A qualifying scheduled failure opens it or
  appends exact-run evidence; a later scheduled all-green run on current `main` closes it with exact
  recovery-run evidence.
- **D-13:** `workflow_dispatch` remains diagnostic and cannot open, update, or close the incident. The
  lifecycle job must inspect all dependency results under scheduled-only gating rather than rely on
  `failure()` alone, which does not cover cancellation or skipped-only outcomes.

### Release, support, and adoption truth
- **D-14:** Derive the current version from release authorities (`mix.exs` and
  `.release-please-manifest.json`), lane severity/applicability from parsed workflow topology, and
  package-proof claims from built/unpacked consumer evidence. Literal string-presence tests may remain
  supplementary but are not authoritative.
- **D-15:** Reconcile active/live planning, maintainer, support, adoption, guide, test, and workflow
  surfaces. Preserve `.planning/milestones/**` and explicitly marked historical release receipts as
  immutable evidence rather than rewriting valid history.
- **D-16:** Reject unmarked 0.4.5/0.4.6 contradictions, false merge-blocking or live-lane claims, and
  package-proof claims that can fall back to repository source or prebuilt local artifacts.
- **D-17:** Preserve the existing `ci.yml`, workflow `CI`, sole required `CI Summary`, exact-SHA release
  coupling, fork safety, public contracts, and accepted PR timing envelope while repairing truth.

### the agent's Discretion
- Exact manifest filename, schema serialization, and whether narrow collectors are implemented in
  Elixir, shell, or both, provided the locked evidence and validation semantics above remain executable.
- Internal helper boundaries and test-fixture organization for Nightly aggregation and incident tests.
- The presentation format of human-readable census and Nightly summaries, provided machine verdicts
  remain authoritative and fail closed.

### Deferred Ideas (OUT OF SCOPE)

- Candidate cleanup and readability mutations remain in Phase 135.
- Complexity, Dialyzer suppression, coverage, async-isolation, and CI ratchets remain in Phase 136.
- Remote issue/PR and dependency disposition remains in Phase 134; Phase 133 only repairs the Nightly
  incident lifecycle already in scope.
- Synthetic adopter twin, lifecycle recovery matrix, and exact-head readiness manifest remain in Phases
  137–139.
- LIFE-06, STREAM-10, TRANS-01, PRIV-01, tus 2.0/RUFH, GCS-as-tus-backend, and uploader kits remain
  demand-gated future scope.
</user_constraints>

## Summary

Phase 133 should be planned as four coupled evidence contracts, not as a quality cleanup: (1) a checked-in charter/disposition ledger plus a generated exact-head census receipt, (2) a supported-cell Dialyzer runner that independently proves fresh and restored PLTs, (3) one strict Nightly verdict consumed by both the workflow and the incident lifecycle, and (4) a derived live-truth checker for version, lane topology, and package provenance. The repository already has the necessary implementation vocabulary: Bash plus `jq` for pure policies, ExUnit plus `YamlElixir` for structural workflow assertions, `Jason` for JSON, and built/unpacked generated-app proof. No dependency or new platform is warranted. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:129-163`; `scripts/ci/eval_ci_summary.sh:14-59`; `test/install_smoke/quality_signal_policy_test.exs:1-148`; `test/install_smoke/generated_app_smoke_test.exs:10-52`]

Authenticated job-log collection resolves the key pre-mutation unknown. Nightly #101 restored the exact primary key `plt-v2-Linux-X64-otp27-elixir1.17-6c351141...`, Dialyxir first reported “PLT is up to date!”, then Dialyzer failed with “Old PLT file”. Nightly #93 had used the same PLT key successfully under resolved OTP `27.3.4.16`; #101 resolved OTP `27.3.4.17`. The PLT key includes only the requested major/minor labels `otp27-elixir1.17`, whereas the existing dependency and build caches already use resolved patch-level setup outputs. The strongest diagnosis is therefore a PLT cache-identity defect exposed by an OTP patch change, not a new type warning. [VERIFIED: authenticated GitHub Actions logs for runs [#93](https://github.com/szTheory/rindle/actions/runs/33482708198) and [#101](https://github.com/szTheory/rindle/actions/runs/34324448817); `.github/workflows/nightly.yml:186-222`; `.github/actions/setup-elixir/action.yml:72-92`]

The current Nightly summary is presentation-only and cannot turn the run red; the incident job uses `failure()`, so it misses cancellation and impermissible skipped-only verdicts and has no recovery-close path. The live adoption matrix is also demonstrably stale: it calls full `adoption-demo-e2e` merge-blocking, while `RUNNING.md` and `ci.yml` place the lean `adoption-demo-e2e-smoke` in `CI Summary` and the full lane on `push:main` only. These are the concrete defects the plans should close, with mutation fixtures for every false-green and false-claim case. [VERIFIED: `.github/workflows/nightly.yml:401-497`; `examples/adoption_demo/docs/adoption-proof-matrix.md:1-41`; `RUNNING.md:55-80`; `.github/workflows/ci.yml:1427-1466`]

**Primary recommendation:** implement a single repository-owned evidence plane whose pure validators decide acceptance, then make workflows and prose consume those decisions; sequence the work as census contract → Dialyzer cache/fresh-restored proof → Nightly verdict/incident lifecycle → live-truth derivation and reconciliation. [ASSUMED]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Census collection and disposition validation | CI / Release Engineering | Repository / Documentation | It inventories repository evidence and emits a planning authority; it does not change runtime product behavior. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:21-32`] |
| PLT construction, validation, and analysis | CI / Release Engineering | API / Backend | Dialyxir analyzes compiled BEAM contracts, but Nightly owns cache identity and the accepted supported-cell result. [VERIFIED: `mix.exs:38-42`; `.github/workflows/nightly.yml:128-222`] |
| Nightly aggregate verdict | CI / Release Engineering | — | The verdict is a pure evaluation of declared job results plus applicability evidence. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:47-60`] |
| Rolling incident mutation | External GitHub service | CI / Release Engineering | The workflow decides eligibility; GitHub Issues persists the one rolling operational record. [VERIFIED: `.github/workflows/nightly.yml:433-497`] |
| Release/version truth | CI / Release Engineering | Repository / Documentation | `mix.exs` and the release manifest own current version; active docs/planning are consumers. The verbatim authorities are `@version "0.4.6"` and `".": "0.4.6"`. [VERIFIED: `mix.exs:4`; `.release-please-manifest.json:1-3`] |
| Lane severity/applicability truth | CI / Release Engineering | Repository / Documentation | Parsed workflow triggers, `if`, `needs`, and aggregate membership determine what actually runs and gates. [VERIFIED: `.github/workflows/ci.yml:1427-1466`; `.github/workflows/nightly.yml:19-23,401-452`] |
| Package-proof truth | Package / Built Artifact | CI / Release Engineering | The unpacked artifact and generated consumer prove package contents and reject repository fallback. [VERIFIED: `test/install_smoke/package_metadata_test.exs:102-133,311-339`; `test/install_smoke/generated_app_smoke_test.exs:10-52,231-279`] |

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| EVID-01 | Maintainers can generate a SHA-bound census covering every applicable quality dimension, with each unique candidate assigned exactly one `fix`, `retain`, or trigger-bound `defer` disposition. | Two-layer ledger/receipt architecture, finite detector map, canonical identity guidance, and invalid-fixture matrix below. [VERIFIED: `.planning/REQUIREMENTS.md:10`] |
| EVID-02 | Supported Nightly Dialyzer runs succeed with both fresh and restored PLTs, and automated regression proof rejects or rebuilds stale PLTs. | Exact #93/#101 failure fingerprint, resolved-version cache-key repair, narrow stale-PLT recovery, and independent mode tests below. [VERIFIED: `.planning/REQUIREMENTS.md:11`] |
| EVID-03 | Nightly aggregation fails when any declared gating job fails, is cancelled, or reports an unexpected state; skipped work cannot silently count as success. | Strict policy table, workflow-output applicability contract, and Bash truth-table test plan below. [VERIFIED: `.planning/REQUIREMENTS.md:12`] |
| EVID-04 | Nightly failures open or update one incident, while a qualifying scheduled recovery closes it with exact-run evidence. | Pure lifecycle decision function, one-label cardinality check, scheduled/current-main closure guard, and fake-`gh` regression matrix below. [VERIFIED: `.planning/REQUIREMENTS.md:13`] |
| TRUTH-08 | Release, planning, support, and adoption-proof claims derive from authoritative live state and contain no unmarked 0.4.5/0.4.6, lane-severity, or package-proof contradiction. | Authority graph and concrete adoption-matrix/version drift inventory below. [VERIFIED: `.planning/REQUIREMENTS.md:14`] |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Keep edits focused and run the checks named by `RUNNING.md` for the changed boundary. [VERIFIED: `AGENTS.md:46-50`]
- Close active requirements only through executable tests, probes, or evidence collectors; human verification/UAT cannot satisfy acceptance. Run `./scripts/maintainer/automation_first_contract.sh` after active planning changes. [VERIFIED: `AGENTS.md:52-56`; `scripts/maintainer/automation_first_contract.sh:52-148`]
- Keep `main` green on the merge-blocking Quality/coveralls, Integration, Proof, Package Consumer, and Adopter lanes and use PR-first execution for serious milestone work. [VERIFIED: `AGENTS.md:60-64`]
- Preserve `ci.yml`, workflow `CI`, the sole `CI Summary`, exact-SHA release coupling, fork safety, public contracts, and the accepted timing envelope. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:70-73`]
- Do not invent demand-gated product work; Phase 133 is evidence infrastructure and live-truth repair only. [VERIFIED: `AGENTS.md:64-65`; `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:179-189`]
- Before release preparation, run `./scripts/maintainer/repo_hygiene_check.sh`. [VERIFIED: `AGENTS.md:67`]

## Verified Discrete Contracts

The planner and executor must preserve these verbatim values:

- Census dispositions: `fix`, `retain`, `defer`; every `defer` is trigger-bound. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:28-30`]
- Supported Dialyzer cell: `Elixir 1.17 / OTP 27`. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:34-39`]
- Nightly non-green results: `failure`, `cancelled`, missing/unexpected results, and impermissible `skipped`; explicitly inapplicable work is the only skip exemption. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:47-60`]
- Existing PR aggregate values: `success|skipped` pass and every other result fails. This contract is PR-only and must not be reused unchanged for Nightly. [VERIFIED: `scripts/ci/eval_ci_summary.sh:14-20,44-59`]
- Current release value: `0.4.6`. [VERIFIED: `mix.exs:4`; `.release-please-manifest.json:2`]
- Sole required-check identity: workflow filename `ci.yml`, workflow name `CI`, check name `CI Summary`. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:72-73`; `.github/workflows/ci.yml:1427-1466`]

## Standard Stack

### Core

| Library / Tool | Version / Contract | Purpose | Why Standard |
|---|---|---|---|
| Bash | Repository-native scripts | Orchestration, pure exit-status policies, fake-command test seams | Existing aggregate and policy tests already use Bash and fail closed under `set -euo pipefail`. [VERIFIED: `scripts/ci/eval_ci_summary.sh:1-59`; `scripts/ci/test_ci_summary_gate.sh:1-87`] |
| `jq` | CI-provided; local `jq-1.7.1-apple` observed | Parse and normalize JSON policy/receipt inputs | Existing CI evaluator requires it and treats absence as failure. [VERIFIED: `scripts/ci/eval_ci_summary.sh:25-30`; local `jq --version`] |
| ExUnit | Elixir standard test framework | Structural validators, invalid fixtures, and parity tests | Existing workflow, cache, release, package, and Dialyzer policy tests use ExUnit. [VERIFIED: `test/install_smoke/quality_signal_policy_test.exs:1-148`; `test/install_smoke/ci_cache_hygiene_test.exs:101-153`; `test/install_smoke/dialyzer_ignore_policy_test.exs:1-95`] |
| `YamlElixir` | `2.12.2` | Parse `ci.yml` and `nightly.yml` as topology rather than prose | It is already locked and used by workflow-policy tests. [VERIFIED: `mix.lock:68`; `test/install_smoke/quality_signal_policy_test.exs:4-9`] |
| `Jason` | `1.4.5` | Encode/decode the versioned census and derived truth output | It is already locked and release parity already decodes JSON with it. [VERIFIED: `mix.lock:32`; `test/install_smoke/release_docs_parity_test.exs:31-39`] |
| Dialyxir | `1.4.7` | Build/check PLTs and execute supported type analysis | The project is locked to this version and configures one narrow ignore file. [VERIFIED: `mix.lock:12`; `mix.exs:38-42`] |
| GitHub CLI | local `2.95.0`; Actions runner-provided command | Read/update/close the rolling issue and collect exact-run evidence | The existing workflow already uses `gh issue list`, `comment`, and `create`; official CLI also exposes `issue close`. [VERIFIED: `.github/workflows/nightly.yml:456-497`; local `gh --version`; CITED: https://cli.github.com/manual/gh_issue_close] |

### Supporting

| Tool / Asset | Purpose | When to Use |
|---|---|---|
| `scripts/maintainer/credo_quality.sh` plus normalized baseline | Stable exact-multiset candidate precedent | Reuse its normalize→compare discipline when designing census candidate identity; do not merge the complexity ratchet into Phase 133. [VERIFIED: `scripts/maintainer/credo_quality.sh:4-45`] |
| `scripts/ci/eval_ci_summary.sh` plus truth table | Pure aggregate-policy precedent | Copy the separation of evaluator from workflow wiring, but implement Nightly's stricter applicability semantics independently. [VERIFIED: `scripts/ci/eval_ci_summary.sh:14-59`; `scripts/ci/test_ci_summary_gate.sh:24-87`] |
| `test/install_smoke/ci_lane_split_test.exs` | Workflow topology preservation | Extend/replace literal checks with parsed assertions for Nightly verdict and incident wiring. [VERIFIED: `test/install_smoke/ci_lane_split_test.exs:28-70,309-412`] |
| Built/unpacked package tests | Package claim authority | Use their emitted package root/provenance facts; do not infer proof from a repository path or prose mention. [VERIFIED: `test/install_smoke/package_metadata_test.exs:102-133,311-339`; `test/install_smoke/generated_app_smoke_test.exs:10-52`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Repository-owned JSON plus Bash/Elixir validators | New quality SaaS or evidence database | Rejected by the phase boundary: it would add a second authority and dependency without improving exact-head determinism. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:170-175`] |
| Resolved patch-level PLT keys plus stale-only rebuild | Delete all caches or retry any Dialyzer failure | Rejected: cache deletion proves only cold mode, while broad retry can turn genuine type warnings into unexplained green. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:37-41`] |
| Pure Nightly evaluator | Reuse PR `eval_ci_summary.sh` | Rejected: PR deliberately accepts all skips for fork safety; Nightly requires explicit applicability and fails unexpected skips. [VERIFIED: `scripts/ci/eval_ci_summary.sh:18-20,46-59`; `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:48-54`] |
| One scheduled lifecycle job driven by the strict verdict | Separate failure-only and recovery-only ad hoc jobs | One decision function prevents open/close predicates from drifting and is easier to mutation-test. [ASSUMED] |

**Installation:** None. Phase 133 should add no Mix, npm, or external runtime dependency. [VERIFIED: `.planning/research/STACK.md` “Recommendation” and “Installation”; `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:170-175`]

## Package Legitimacy Audit

No external package is installed or upgraded in this phase, so the package-legitimacy gate is not applicable. Existing locked packages are used through current repository seams. [VERIFIED: phase boundary in `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:9-14`; `.planning/research/STACK.md` “Installation”]

## Architecture Patterns

### System Architecture Diagram

```text
current immutable Git SHA
        |
        +--> detector registry --> normalized observations --> frozen candidate ledger
        |          |                       |                         |
        |          +-- applicability ------+                         +-- fix/retain/defer validator
        |                                                             (machine verdict)
        |
        +--> Elixir 1.17 / OTP 27 setup (resolved patch outputs)
        |          |
        |          +--> always-fresh PLT build + analysis
        |          +--> exact-key restore --> validate/analyze --> stale-only rebuild
        |                                                             |
        +-------------------------------------------------------------+ 
                                                                      v
declared Nightly jobs --> result + applicability + execution --> strict aggregate verdict
                                                                      |
                                +-------------------------------------+------------------+
                                |                                                        |
                                v                                                        v
                     failing workflow conclusion                       scheduled incident decision
                                                                               |
                                                    failure: open/update one exact-run issue
                                                    recovery: close one issue on current main

release authorities + parsed workflows + unpacked-package receipt
                                |
                                v
                    derived live-truth model --> docs/planning/adoption parity validator
```

This flow keeps human-readable summaries downstream of machine verdicts and keeps GitHub issue mutation downstream of the scheduled verdict. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:47-60`]

### Recommended Project Structure

The exact filenames are discretionary; this is the recommended ownership split. [ASSUMED]

```text
scripts/maintainer/
├── evidence_census.exs              # collect/normalize exact-head observations
├── validate_evidence_census.exs     # pure schema, coverage, identity, disposition checks
└── validate_live_truth.exs          # version/topology/package claim derivation

scripts/ci/
├── eval_nightly_summary.sh          # strict pure result/applicability policy
├── test_nightly_summary_gate.sh     # complete truth table
├── run_nightly_dialyzer.sh          # fresh/restored/stale-only behavior
├── test_nightly_dialyzer.sh         # fake-mix filesystem fixtures
├── eval_nightly_incident.sh         # pure open-update-close-noop decision
└── test_nightly_incident.sh         # fake-gh lifecycle fixtures

test/install_smoke/
├── evidence_census_test.exs         # valid plus malformed/duplicate/foreign fixtures
├── nightly_policy_test.exs          # parsed workflow topology and permissions
└── live_truth_parity_test.exs       # derived claims, marked-history exclusions

.planning/phases/133-evidence-charter-and-live-truth/
└── 133-EVIDENCE-CENSUS.json         # frozen disposition ledger/baseline authority
```

### Pattern 1: Separate the frozen ledger from the generated exact-head receipt

**What:** commit a reviewed, stable candidate ledger with detector identities and dispositions, while generating the SHA/toolchain/input-bound execution receipt at runtime. Validate both together. This avoids a self-referential artifact whose embedded SHA becomes stale merely because committing that artifact changes `HEAD`. [ASSUMED]

**When to use:** whenever a versioned evidence definition must persist across later phases but each run must still prove the exact immutable revision being evaluated. [ASSUMED]

**Required validation:** reject a foreign SHA, dirty worktree unless explicitly in a non-authoritative diagnostic mode, missing taxonomy member, duplicate observation, duplicate candidate ID, observation assigned to zero or multiple candidates, disposition outside the locked set, `retain` without rationale/evidence, and `defer` without an executable trigger. The disposition values are verbatim `fix`, `retain`, and `defer`. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:21-32`; ASSUMED for the recommended two-artifact serialization]

**Stable identity:** use a reviewer-owned candidate ID plus normalized detector observations; do not hash line numbers, absolute temporary paths, timestamps, or raw prose into identity. One candidate may own multiple observations when they share one root cause, but every observation maps to exactly one candidate. [ASSUMED]

### Pattern 2: Make taxonomy coverage explicit and finite

Each locked dimension should have an applicability record, at least one named detector when applicable, and a result/observation reference. The following initial registry maps the existing repository rather than inventing new scanners. [VERIFIED: taxonomy quote at `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:25-27`; ASSUMED for detector grouping]

| Dimension | Existing authoritative inputs |
|---|---|
| correctness | Default ExUnit, integration, contract, SAFE-01 results. [VERIFIED: `RUNNING.md:55-76`] |
| maintainability | Curated Credo identity multiset and prior finite census candidates. [VERIFIED: `scripts/maintainer/credo_quality.sh:22-45`; `.planning/milestones/v1.25-phases/127-evidence-charter-quality-census/127-QUALITY-CENSUS.md` “Baseline receipts”] |
| security | `mix_audit`, security invariants/contracts, and workflow permission/input checks. [VERIFIED: `mix.exs:126`; `.github/workflows/nightly.yml:27-29,453-455`] |
| performance | The accepted exact-ten PR timing receipt as a retained baseline input; no new ratchet in this phase. [VERIFIED: `.planning/PROJECT.md:64-68`; `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:72-73`] |
| reliability | Nightly strict verdict, PLT modes, incident lifecycle, and bounded advisory canary classification. [VERIFIED: `.github/workflows/nightly.yml:116-133,401-497`] |
| compatibility | Parsed supported/early-warning workflow cells and `.tool-versions`; only `Elixir 1.17 / OTP 27` owns Dialyzer authority. [VERIFIED: `.github/workflows/nightly.yml:31-55,135-176`; `.tool-versions:1-3`] |
| testing | Test topology, coverage artifact/floor reference, and automation-first contract. [VERIFIED: `RUNNING.md:82-143`; `AGENTS.md:52-56`] |
| documentation/accessibility | Doctor, docs parity, generated design/contrast gates, with accessibility kept distinct from lifecycle proof. [VERIFIED: `RUNNING.md:58-75`; `.planning/research/PITFALLS.md:301-305`] |
| packaging | `mix hex.build --unpack`, package metadata, prohibited path checks, generated consumer provenance. [VERIFIED: `test/install_smoke/package_metadata_test.exs:102-133,311-339`; `test/install_smoke/generated_app_smoke_test.exs:10-52`] |
| CI/CD | Parsed `ci.yml`/`nightly.yml`, strict aggregate truth tables, cache identity, and required-context preservation. [VERIFIED: `.github/workflows/ci.yml:1415-1466`; `.github/workflows/nightly.yml:401-497`] |
| release engineering | `mix.exs`, release manifest, release workflow exact-SHA coupling, and release parity tests. [VERIFIED: `mix.exs:4`; `.release-please-manifest.json:2`; `test/install_smoke/release_docs_parity_test.exs:31-39,105-151`] |
| repository hygiene | Repo hygiene script, tracked/ignored/generated evidence, and clean-worktree state recorded in the receipt. [VERIFIED: `AGENTS.md:67`; `.planning/research/PITFALLS.md:55-65,85-93`] |

### Pattern 3: Key PLTs by resolved toolchain and recover only the stale fingerprint

Expose `steps.beam.outputs.otp-version` and `steps.beam.outputs.elixir-version` from `.github/actions/setup-elixir`, then use those resolved values in the PLT key exactly as the dependency/build caches already do. The setup action's pinned upstream contract describes these outputs as the exact installed versions. [VERIFIED: `.github/actions/setup-elixir/action.yml:40-46,51-92`; authenticated read of pinned `erlef/setup-beam` action outputs; [run #93](https://github.com/szTheory/rindle/actions/runs/33482708198); [run #101](https://github.com/szTheory/rindle/actions/runs/34324448817)]

Run two independent supported-cell modes: one always removes/constructs a fresh PLT before analysis; the other restores the exact cache and analyzes it. In restored mode, rebuild only when a narrow validation/analysis result proves the PLT is stale/incompatible; propagate ordinary Dialyzer warnings and all unknown failures without retry. Run `mix dialyzer --list-unused-filters` as a guard if it remains compatible with the established ignore policy, but do not change `.dialyzer_ignore.exs` in Phase 133. [CITED: https://dialyxir.hexdocs.pm/readme.html; VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:37-41`; ASSUMED for exact wrapper mechanics]

### Pattern 4: Encode Nightly applicability as evidence, not a successful no-op

Every declared gating job should expose machine-readable applicability/execution facts. A meaningful test pass is distinct from an allowed exemption. The aggregate must enumerate the declared policy, compare it against `toJSON(needs)`, and reject missing/extra jobs or unknown statuses. [ASSUMED]

Recommended truth table: [ASSUMED]

| Job result | Applicability evidence | Execution evidence | Verdict |
|---|---|---|---|
| `success` | applicable | passed | green |
| `success` or `skipped` | explicitly inapplicable under an allowlisted repository/secret rule | not-run with reason | exempt, visibly not-run |
| `skipped` | applicable, missing, or unknown | any | red |
| `failure` or `cancelled` | any | any | red |
| missing/unexpected result or undeclared/missing job | any | any | red |

The job-level aggregate must use `if: always()` because GitHub otherwise skips downstream jobs after a failed or skipped dependency. The summary step should render the evaluator output only after the evaluator determines the exit code. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax]

### Pattern 5: Split incident decision from GitHub mutation

Create a pure lifecycle evaluator that returns one of four internal decisions—open, update, close, or no-op—then give a thin workflow adapter the only `issues: write` permission. The evaluator consumes event type, strict Nightly verdict, run URL/ID/attempt, run SHA, ref/default branch, and current remote `main` SHA. [ASSUMED]

The adapter must query all open issues with the exact `nightly-failure` label, fail on multiple matches, open when none exists on qualifying scheduled failure, append exact-run evidence when one exists, and close only after adding the exact scheduled recovery-run evidence. `workflow_dispatch` always produces no mutation. The existing label and diagnostic-trigger rules are verbatim `nightly-failure` and `workflow_dispatch`. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:55-60`; ASSUMED for duplicate-cardinality failure]

### Pattern 6: Derive live claims into one model before checking prose

Build one derived truth model from: `Mix.Project.config()[:version]` plus decoded `.release-please-manifest.json`; parsed `ci.yml` and `nightly.yml` triggers/conditions/needs; and built/unpacked generated-consumer provenance. Tests then compare active documentation/planning assertions to this model. Marked historical sections and `.planning/milestones/**` are excluded explicitly; an unmarked old version is a failure. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:62-73`; `test/install_smoke/release_docs_parity_test.exs:31-39`; `test/install_smoke/generated_app_smoke_test.exs:10-52`]

Concrete current reconciliation targets include `.planning/INBOX-TRIAGE.md` and `.planning/JTBD-MAP.md` references to Hex `0.4.5`, plus `examples/adoption_demo/docs/adoption-proof-matrix.md` claims that full Cohort E2E is merge-blocking. Some prior-version text in `CHANGELOG.md`, previous-milestone sections, and archived milestones is valid history and must be marked/preserved, not normalized. [VERIFIED: repository `rg` scan on 2026-09-09; `examples/adoption_demo/docs/adoption-proof-matrix.md:1-41`; `RUNNING.md:68-80`; `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:67-71`]

### Anti-Patterns to Avoid

- **One JSON file that claims both immutable baseline and current `HEAD` after it is committed:** committing it changes `HEAD`; separate stable ledger definition from generated exact-head receipt. [ASSUMED]
- **Candidate ID derived from line number or raw message:** normal cleanup would substitute identity and defeat Phase 135/136 traceability. [ASSUMED]
- **Treating a cache hit as PLT validity:** #101 was an exact cache hit and still failed as an old PLT. [VERIFIED: authenticated [run #101](https://github.com/szTheory/rindle/actions/runs/34324448817)]
- **Running `mix dialyzer --plt` as the only compatibility probe:** #101's normal check reported the PLT current before analysis rejected it. [VERIFIED: authenticated [run #101](https://github.com/szTheory/rindle/actions/runs/34324448817)]
- **Retrying any red Dialyzer run after deleting the PLT:** that can hide real warnings; only the proven stale/incompatible fingerprint may trigger rebuild. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:37-41`]
- **Copying PR skip-as-pass into Nightly:** PR's semantics intentionally solve fork-required-check behavior and are not Nightly evidence. [VERIFIED: `scripts/ci/eval_ci_summary.sh:14-20`; `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:48-54`]
- **Using `failure()` to drive incident mutation:** it does not encode the strict cancellation/skipped/applicability policy and has no recovery path. [VERIFIED: `.github/workflows/nightly.yml:433-452`; `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:58-60`]
- **Selecting the first matching incident silently:** duplicate rolling incidents would violate “one incident”; fail closed and surface repair. [ASSUMED]
- **Treating a substring mention as package evidence:** the current adoption checker only checks strings and file presence; the generated-app tests contain the stronger unpacked/no-fallback facts. [VERIFIED: `scripts/maintainer/check_adoption_proof_matrix.sh:13-66`; `test/install_smoke/generated_app_smoke_test.exs:10-52`]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| JSON parsing/encoding | Regex parser | Existing `Jason` and `jq` | Both are already present and used in repository evidence paths. [VERIFIED: `mix.lock:32`; `scripts/ci/eval_ci_summary.sh:25-53`] |
| Workflow topology | Line-oriented workflow grep as authority | `YamlElixir` parsed maps plus focused shell truth tables | YAML keys, needs, conditions, and outputs should be asserted structurally. [VERIFIED: `test/install_smoke/quality_signal_policy_test.exs:4-9,119-148`] |
| Candidate normalization | New quality scanner suite | Existing detector outputs plus one normalization/ledger layer | Phase 133 inventories evidence; later phases own cleanup and ratchets. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:9-14,129-150`] |
| PLT format inspection | Custom Erlang term decoder | Dialyxir/Dialyzer execution plus resolved cache identity and stale-only rebuild | The failure occurs at Dialyzer consumption; actual execution is the positive compatibility probe. [VERIFIED: authenticated [run #101](https://github.com/szTheory/rindle/actions/runs/34324448817); CITED: https://dialyxir.hexdocs.pm/readme.html] |
| GitHub issue HTTP client | Raw bespoke API client | Existing authenticated `gh` CLI | It already supports list/create/comment/close and is used in the workflow. [VERIFIED: `.github/workflows/nightly.yml:481-497`; CITED: https://cli.github.com/manual/gh_help_reference] |
| Release/package authority | Prose or checkout-local test | Existing release manifest plus unpacked package/generated app proof | Checkout success cannot establish shipped package contents or provenance. [VERIFIED: `test/install_smoke/package_metadata_test.exs:102-133,311-339`; `test/install_smoke/generated_app_smoke_test.exs:10-52`] |

**Key insight:** this phase should add composition and validation around existing evidence producers; replacing them would erase comparability immediately before the cleanup phases need a frozen baseline. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:21-32,129-163`]

## Common Pitfalls

### Pitfall 1: The census validates schema but not completeness

**What goes wrong:** a well-formed manifest omits a dimension, detector, or candidate and still passes. [ASSUMED]

**Why it happens:** JSON schema validates shapes more naturally than set equality and applicability coverage. [ASSUMED]

**How to avoid:** compare the manifest's dimension set exactly to the locked taxonomy; require applicable/inapplicable justification per dimension and observation-to-candidate bijection. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:25-32`; ASSUMED for representation]

**Warning signs:** empty dimensions disappear from output; total counts reconcile but candidate IDs do not; `defer` lacks a machine-evaluable trigger. [ASSUMED]

### Pitfall 2: A generated census cannot be frozen reproducibly

**What goes wrong:** timestamps, absolute paths, nondeterministic ordering, or dirty worktree contents change the artifact without a candidate change. [ASSUMED]

**How to avoid:** canonical ordering, repository-relative paths, explicit source SHA/dirty flag, exact detector/config hashes, deterministic serialization, and a two-run byte-equality test apart from explicitly volatile receipt fields. [ASSUMED]

### Pitfall 3: The PLT key tracks requested labels, not installed runtime

**What goes wrong:** a floating `27` selector resolves a new patch but restores a PLT built by the prior patch. This occurred between #93 and #101. [VERIFIED: authenticated GitHub Actions logs for [#93](https://github.com/szTheory/rindle/actions/runs/33482708198) and [#101](https://github.com/szTheory/rindle/actions/runs/34324448817)]

**How to avoid:** use resolved patch outputs in the PLT key and retain lock/config hashes; regression-test that a patch change changes the key. [VERIFIED: `.github/actions/setup-elixir/action.yml:72-92`; ASSUMED for new PLT key test]

### Pitfall 4: Warm success substitutes for fresh success

**What goes wrong:** rebuilding a stale cache makes restored analysis green, but no job proves a clean PLT can be built and analyzed from nothing. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:37-39`]

**How to avoid:** run fresh and restored modes as independent commands/evidence rows on the supported cell; do not let one branch skip the other. [ASSUMED]

### Pitfall 5: A successful no-op job is described as passed live proof

**What goes wrong:** both GCS jobs currently conclude `success` when their proof steps are skipped for missing secrets. [VERIFIED: authenticated [run #101](https://github.com/szTheory/rindle/actions/runs/34324448817); `.github/workflows/nightly.yml:262-295,335-389`]

**How to avoid:** emit explicit applicability/execution outputs and make the strict aggregate display `not-run`/reason rather than the job's superficial success. [ASSUMED]

### Pitfall 6: Incident automation closes on a diagnostic or stale recovery

**What goes wrong:** a green dispatch or a scheduled run whose SHA is no longer current closes a still-relevant incident. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:55-60`]

**How to avoid:** pure decision fixtures must require event `schedule`, strict all-green verdict, default branch, and run SHA equal to current remote `main`; API lookup failure cannot authorize closure. [ASSUMED]

### Pitfall 7: Historical truth is rewritten or live drift is excused as history

**What goes wrong:** a broad version replacement corrupts valid receipts, while a broad archive exclusion leaves active generated/support surfaces stale. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:67-71`]

**How to avoid:** define explicit historical markers/paths, scan all other active surfaces, and test a stale-version fixture both inside and outside the marked boundary. [ASSUMED]

### Pitfall 8: Workflow issue mutation becomes an injection or privilege boundary

**What goes wrong:** untrusted GitHub context is interpolated into shell, or the issue job receives broader permissions than required. [CITED: https://docs.github.com/en/actions/concepts/security/script-injections]

**How to avoid:** pass context through quoted environment variables, construct bodies from bounded trusted fields, keep workflow default `contents: read`, and grant only job-local `issues: write`. [VERIFIED: `.github/workflows/nightly.yml:27-29,453-479`; CITED: https://docs.github.com/en/actions/reference/security/secure-use]

## Code Examples

These are implementation skeletons, not locked filenames. New internal state names in the examples are proposed and therefore assumed until implemented. [ASSUMED]

### Strict aggregate call from workflow

```yaml
# Source pattern: .github/workflows/ci.yml:1452-1466 and official jobs.needs docs
nightly-summary:
  needs: [compat-matrix, dialyzer, gcs-soak, package-consumer-gcs-live]
  if: always()
  steps:
    - uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0
    - name: Evaluate Nightly gating results
      env:
        NEEDS_JSON: ${{ toJSON(needs) }}
      run: bash scripts/ci/eval_nightly_summary.sh
```

The verified result vocabulary used by the evaluator is `success`, `failure`, `cancelled`, and `skipped`; Nightly differs from PR by accepting `skipped` only with explicit inapplicability evidence. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:48-52`; `scripts/ci/eval_ci_summary.sh:46-52`]

### Resolved toolchain outputs from the existing composite

```yaml
# Source: pinned erlef/setup-beam output contract and existing composite output shape
outputs:
  resolved-elixir-version:
    value: ${{ steps.beam.outputs.elixir-version }}
  resolved-otp-version:
    value: ${{ steps.beam.outputs.otp-version }}
```

The upstream pinned action calls these `elixir-version` and `otp-version` and describes them as the exact installed versions; the current composite already uses them internally for dependency/build cache keys. [VERIFIED: authenticated read of `erlef/setup-beam@fc68ffb.../action.yml`; `.github/actions/setup-elixir/action.yml:72-92`]

### Census validator assertions

```elixir
# Source pattern: test/install_smoke/dialyzer_ignore_policy_test.exs:48-95
assert manifest.source_sha == System.cmd("git", ["rev-parse", "HEAD"]) |> elem(0) |> String.trim()
assert MapSet.new(manifest.dimensions) == MapSet.new(required_dimensions)
assert Enum.uniq_by(manifest.candidates, & &1.id) == manifest.candidates
assert Enum.all?(manifest.candidates, &valid_disposition?/1)
```

The exact required dimension list and disposition strings must come from the locked context, where the values are quoted verbatim as `correctness`, `maintainability`, `security`, `performance`, `reliability`, `compatibility`, `testing`, `documentation/accessibility`, `packaging`, `CI/CD`, `release engineering`, `repository hygiene`, and `fix`, `retain`, `defer`. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:25-30`]

### Incident mutation seam

```bash
# Source pattern: scripts/ci/test_ci_summary_gate.sh:24-36 and nightly.yml:456-497
decision="$(bash scripts/ci/eval_nightly_incident.sh)"
case "$decision" in
  open)   gh issue create --title "$title" --label "$label" --body-file "$body_file" ;;
  update) gh issue comment "$issue_number" --body-file "$body_file" ;;
  close)  gh issue close "$issue_number" --comment "$(<"$body_file")" ;;
  noop)   : ;;
  *)      exit 1 ;;
esac
```

The official CLI supports body files for create/comment and a closing comment for close; implementation should avoid command substitution for multi-line bodies if tests show quoting ambiguity. [CITED: https://cli.github.com/manual/gh_help_reference; https://cli.github.com/manual/gh_issue_close]

## State of the Art

| Old / Current Defect | Recommended Current Approach | Impact |
|---|---|---|
| Prose Phase 127 census | Versioned ledger plus exact-head generated receipt and validator | Later phases can trace changes without treating prose as authority. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:21-32`; ASSUMED for serialization] |
| PLT key uses requested `otp27-elixir1.17` | Key on resolved installed patch versions and validate/rebuild stale PLTs narrowly | OTP patch drift cannot poison a supposedly exact cache lineage. [VERIFIED: `.github/workflows/nightly.yml:186-217`; `.github/actions/setup-elixir/action.yml:72-92`] |
| Summary always succeeds | Pure strict evaluator controls job/workflow conclusion | A red/cancelled/unexpected/impermissibly skipped lane cannot coexist with a green authoritative summary. [VERIFIED: `.github/workflows/nightly.yml:401-431`; `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:48-54`] |
| Incident only opens/updates under `failure()` | Scheduled lifecycle consumes strict verdict and can open/update/close | Issue #88 becomes one auditable rolling incident rather than permanent noise. [VERIFIED: `.github/workflows/nightly.yml:433-497`; authenticated `gh issue view 88`] |
| Literal docs drift checks | Derived version/topology/package truth plus targeted prose assertions | Claims follow authorities and fail when topology or provenance changes. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:62-73`] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | The census should use a checked-in frozen ledger plus a generated exact-head receipt to avoid Git-SHA self-reference. | Architecture Pattern 1 | Medium: planner may select another serialization, but must still prove exact-head binding and durable baseline identity. |
| A2 | Candidate identity should be reviewer-owned and observation mapping explicit rather than hashing source locations. | Architecture Pattern 1 | Medium: poor identity design would make later cleanup look like candidate removal/substitution. |
| A3 | Two independent runner modes are the least-surprising way to satisfy fresh and restored PLT proof. | Architecture Pattern 3 | Medium: a different topology is acceptable only if automation proves both modes independently. |
| A4 | A single pure lifecycle evaluator returning open/update/close/no-op is the safest incident helper boundary. | Architecture Pattern 5 | Low: helper layout is discretionary, but predicates must remain one tested policy. |
| A5 | Explicit historical markers should delimit old version receipts outside `.planning/milestones/**`. | Architecture Pattern 6 | Medium: exact marker syntax is discretionary; without a bounded mechanism, the parity scan will either corrupt history or tolerate live drift. |
| A6 | Duplicate open `nightly-failure` issues should fail the lifecycle job rather than silently choosing one. | Architecture Pattern 5 | Low: this is a conservative fail-closed interpretation of the one-incident requirement. |

## Open Questions

1. **Where should the frozen census ledger live after Phase 133 archives?**
   - What we know: later Phases 135/136 must reference stable candidate identities, and active phase directories are eventually archived. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:31-32`]
   - What's unclear: whether the durable source should remain phase-local, move under `scripts/maintainer/`, or be copied into a milestone evidence directory. [ASSUMED]
   - Recommendation: keep the reviewed ledger phase-local for planning provenance and make validators accept an explicit ledger path; later plans should reference candidate IDs, not a hard-coded active-directory assumption. [ASSUMED]

2. **Should stale restored PLTs be rejected immediately or rebuilt once?**
   - What we know: the locked decision permits either rejection or rebuild, and #101 proves normal pre-analysis checking is insufficient. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:40-45`; authenticated [run #101](https://github.com/szTheory/rindle/actions/runs/34324448817)]
   - What's unclear: whether the desired operational behavior prioritizes fastest diagnosis or self-healing Nightly. [ASSUMED]
   - Recommendation: key by resolved versions, then rebuild exactly once only for the proven stale/incompatible fingerprint and record both attempts; propagate every other failure. [ASSUMED]

3. **How should secret absence affect the overall Nightly conclusion?**
   - What we know: an explicitly inapplicable secret-gated job may be exempted, but absence must be machine-checked and cannot be presented as passing live proof. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:51-54`]
   - What's unclear: which repositories/environments are declared applicable to live GCS evidence. [ASSUMED]
   - Recommendation: encode the upstream-repository plus secret-presence applicability rule in policy fixtures; render allowed absence as `not-run`, not `success`, and ensure no live-support claim consumes it. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Git | SHA binding and clean-state evidence | ✓ | `2.41.0` | — [VERIFIED: local `git --version`] |
| `jq` | Bash JSON evaluators | ✓ | `jq-1.7.1-apple` | Jason/Elixir for local validation only; CI scripts still require jq. [VERIFIED: local `jq --version`; `scripts/ci/eval_ci_summary.sh:25-30`] |
| GitHub CLI/auth | Run-log fingerprint and incident specimen | ✓ | `2.95.0`, authenticated as `szTheory` | Fixture-only tests if remote unavailable; live mutation remains scheduled CI-owned. [VERIFIED: local `gh --version` and `gh auth status`] |
| Elixir / OTP local | ExUnit and collectors | ✓, wrong supported pair | `Elixir 1.20.2 / OTP 29` | Run structural/unit work locally; authoritative Dialyzer proof must use CI's locked `Elixir 1.17 / OTP 27`. [VERIFIED: local `elixir --version`; `.tool-versions:1-2`] |
| Supported Elixir / OTP locally | Exact supported Dialyzer reproduction | ✗ | not installed in asdf | Use `erlef/setup-beam` in GitHub Actions; do not accept the local newer pair as substitute. [VERIFIED: local `asdf list`; `.github/workflows/nightly.yml:171-177`] |
| PostgreSQL | Existing test setup | ✓ | local service accepting connections on port 5432 | Existing CI service if local integration is unnecessary. [VERIFIED: local `pg_isready`; `.github/workflows/nightly.yml:152-165`] |
| Docker | Optional clean environment/support services | ✓ | `29.5.2` | GitHub-hosted runner services. [VERIFIED: local `docker --version` and `docker info`] |
| Node | Existing generated/brandbook checks | ✓ | `20.18.1` | — [VERIFIED: local `node --version`; `.tool-versions:3`] |

**Missing dependencies with no fallback:** None. The exact supported Dialyzer pair is not local, but GitHub Actions is the authoritative execution environment and is currently accessible. [VERIFIED: environment probes and authenticated Nightly run access]

**Missing dependencies with fallback:** Local Elixir 1.17 / OTP 27 is absent; use the pinned GitHub Actions setup for acceptance and keep local newer-toolchain results diagnostic. [VERIFIED: local `asdf list`; `.github/workflows/nightly.yml:171-177`]

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit plus repository-native Bash truth-table scripts. [VERIFIED: `test/install_smoke/quality_signal_policy_test.exs:1-148`; `scripts/ci/test_ci_summary_gate.sh:1-87`] |
| Config file | `test/test_helper.exs`, `config/test.exs`; Bash tests require only Bash and jq. [VERIFIED: repository files; `scripts/ci/eval_ci_summary.sh:25-30`] |
| Quick run command | `bash scripts/ci/test_nightly_summary_gate.sh && bash scripts/ci/test_nightly_dialyzer.sh && bash scripts/ci/test_nightly_incident.sh` [ASSUMED — Wave 0 files] |
| Structural run command | `mix test test/install_smoke/evidence_census_test.exs test/install_smoke/nightly_policy_test.exs test/install_smoke/live_truth_parity_test.exs` [ASSUMED — Wave 0 files] |
| Full suite command | `mix ci` plus focused supported-cell Nightly workflow evidence. `mix ci` intentionally omits Dialyzer/Nightly. [VERIFIED: `mix.exs:293-325`] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| EVID-01 | Exact-head, full taxonomy, deduplicated observations, exactly one disposition, triggered defer | Unit/contract with mutation fixtures | `mix test test/install_smoke/evidence_census_test.exs` | ❌ Wave 0 [ASSUMED] |
| EVID-02 | Fresh PLT passes; valid restore passes without rebuild; stale restore rebuilds/rejects; ordinary warning is not retried | Pure shell fixtures plus real supported-cell CI | `bash scripts/ci/test_nightly_dialyzer.sh`; scheduled/dispatch Nightly job | ❌ Wave 0 for script tests; workflow exists but needs repair [VERIFIED: `.github/workflows/nightly.yml:141-222`] |
| EVID-03 | All success passes; failed/cancelled/missing/unexpected/impermissible skip fails; allowed inapplicability is visible exemption | Bash truth table plus YAML topology | `bash scripts/ci/test_nightly_summary_gate.sh`; `mix test test/install_smoke/nightly_policy_test.exs` | ❌ Wave 0 [ASSUMED] |
| EVID-04 | Scheduled failure opens/updates one issue; scheduled current-main recovery closes; dispatch/stale SHA/no incident no-op; duplicate incidents fail | Pure evaluator and fake-`gh` adapter tests | `bash scripts/ci/test_nightly_incident.sh`; `mix test test/install_smoke/nightly_policy_test.exs` | ❌ Wave 0 [ASSUMED] |
| TRUTH-08 | Version derives from two authorities; lane claims derive from parsed topology; package claims require unpacked/no-fallback evidence; marked history exempt only | ExUnit parity plus existing package tests | `mix test test/install_smoke/live_truth_parity_test.exs test/install_smoke/package_metadata_test.exs test/install_smoke/generated_app_smoke_test.exs` | Partial: package/release tests exist; derived truth test is Wave 0 [VERIFIED: existing cited test files] |

### Required Mutation Fixtures

- Census: foreign SHA, dirty state, missing dimension, duplicate candidate ID, duplicated observation, unassigned observation, invalid disposition, retain without evidence, defer without trigger, and nondeterministic ordering. [ASSUMED]
- Dialyzer: valid restored PLT, exact old-PLT fingerprint, corrupt/missing PLT, build failure, genuine warning failure, and stale rebuild that still fails. [ASSUMED]
- Nightly: every result vocabulary member, missing/extra job, applicable skip, allowlisted inapplicable skip, successful no-op with missing execution marker, and malformed JSON. [ASSUMED]
- Incident: schedule/dispatch, open/closed/duplicate issue inventory, exact/stale main SHA, failure/cancelled/skipped-policy verdict, API failure, open/update/close command failure, and recovery comment before close. [ASSUMED]
- Truth: unmarked `0.4.5`, marked historical `0.4.5`, mismatch between `mix.exs` and manifest, full E2E mislabeled merge-blocking, Nightly secret absence mislabeled passed/live, repository-path fallback, and prebuilt-artifact substitution. [ASSUMED]

### Sampling Rate

- **Per task commit:** run the new pure shell tests or focused ExUnit contract for the touched evidence owner. [ASSUMED]
- **Per wave merge:** run all Phase 133 focused contracts, existing `ci_cache_hygiene_test.exs`, `ci_lane_split_test.exs`, `release_docs_parity_test.exs`, `package_metadata_test.exs`, and generated-app provenance tests appropriate to the change. [VERIFIED: existing tests cited above]
- **Phase gate:** `mix ci`, `bash scripts/maintainer/refactor_contract.sh`, `./scripts/maintainer/automation_first_contract.sh`, supported-cell fresh/restored Dialyzer evidence, one strict Nightly result, and `./scripts/maintainer/repo_hygiene_check.sh`. [VERIFIED: `AGENTS.md:50-67`; `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:34-60`]

### Wave 0 Gaps

- [ ] Census schema/validator fixtures and a deterministic collector seam. [ASSUMED]
- [ ] Pure Nightly verdict evaluator and complete Bash truth table. [ASSUMED]
- [ ] Dialyzer mode wrapper with fake-command fixtures and resolved-version cache-key assertions. [ASSUMED]
- [ ] Pure incident evaluator plus fake-`gh` mutation tests. [ASSUMED]
- [ ] Parsed workflow/live-truth parity test and explicit marked-history fixture. [ASSUMED]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | No | The workflow uses the ephemeral `github.token`; no user authentication surface changes. [VERIFIED: `.github/workflows/nightly.yml:457-459`] |
| V3 Session Management | No | No session or browser state is introduced. [VERIFIED: phase boundary `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:9-14`] |
| V4 Access Control | Yes | Workflow default `contents: read`; only the incident job receives `issues: write`; no contents write. [VERIFIED: `.github/workflows/nightly.yml:27-29,453-455`; CITED: https://docs.github.com/en/actions/reference/security/secure-use] |
| V5 Input Validation | Yes | Fail-closed JSON/schema validation, allowlisted statuses/applicability reasons, quoted environment inputs, and no direct untrusted context interpolation into shell. [CITED: https://docs.github.com/en/actions/concepts/security/script-injections] |
| V6 Cryptography | No new cryptography | Use Git SHA and existing cache/package hashes as identity/integrity metadata; do not design a custom signature system in this phase. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:22-24,63-66`] |

OWASP ASVS categories were checked for applicability; this phase chiefly exercises access control, input validation, error/logging truth, and configuration integrity rather than application authentication/session/cryptography. [CITED: https://owasp.org/www-project-application-security-verification-standard/]

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Event or branch text becomes shell code | Tampering / Elevation of privilege | Move context into quoted environment variables; accept only bounded status/SHA/URL shapes. [CITED: https://docs.github.com/en/actions/concepts/security/script-injections] |
| Overprivileged incident token modifies code/releases | Elevation of privilege | Job-local `issues: write`, workflow `contents: read`, and structural permission test. [VERIFIED: `.github/workflows/nightly.yml:27-29,453-455`; CITED: https://docs.github.com/en/actions/reference/security/secure-use] |
| Malformed result/application data yields false green | Tampering / Repudiation | Schema validation, exact declared-job set, unknown-state rejection, complete truth table. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:48-54`] |
| Secret absence is reported as successful live proof | Repudiation | Separate applicability, execution, and result; render absence as explicit not-run and block live claims. [VERIFIED: `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md:51-52`; authenticated [run #101](https://github.com/szTheory/rindle/actions/runs/34324448817)] |
| Issue automation closes the wrong incident | Tampering / Repudiation | Exact label/title policy, cardinality check, scheduled/current-main guard, exact recovery link, fake-CLI tests. [ASSUMED]
| Evidence receipt leaks absolute paths or secrets | Information disclosure | Repository-relative normalized locations, bounded logs, no raw secret/provider payloads. [CITED: https://docs.github.com/en/actions/reference/security/secure-use]

## Sources

### Primary (HIGH confidence)

- `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md` — locked evidence, Nightly, incident, parity, and scope decisions.
- `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/PROJECT.md`, `.planning/STATE.md`, and `AGENTS.md` — requirements, immutable contracts, starting state, and automation-first constraints.
- `.github/workflows/nightly.yml`, `.github/workflows/ci.yml`, and `.github/actions/setup-elixir/action.yml` — current execution, cache, result, permission, and topology authority.
- `scripts/ci/eval_ci_summary.sh`, `scripts/ci/test_ci_summary_gate.sh`, `scripts/maintainer/credo_quality.sh`, and `scripts/maintainer/check_adoption_proof_matrix.sh` — reusable policy patterns and current shallow checks.
- `test/install_smoke/quality_signal_policy_test.exs`, `ci_cache_hygiene_test.exs`, `ci_lane_split_test.exs`, `dialyzer_ignore_policy_test.exs`, `release_docs_parity_test.exs`, `package_metadata_test.exs`, and `generated_app_smoke_test.exs` — structural and built-artifact proof seams.
- Authenticated GitHub Actions [Nightly #93](https://github.com/szTheory/rindle/actions/runs/33482708198) and [Nightly #101](https://github.com/szTheory/rindle/actions/runs/34324448817) — resolved toolchain, identical PLT key, prior success, current old-PLT failure.
- Authenticated GitHub issue [#88](https://github.com/szTheory/rindle/issues/88) — one open `nightly-failure` incident with repeated exact-run comments and no recovery closure.
- Pinned `erlef/setup-beam@fc68ffb90438ef2936bbb3251622353b3dcb2f93` `action.yml` — exact installed-version outputs.

### Secondary (MEDIUM confidence)

- [GitHub Actions workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax) — `needs`, skip propagation, and `always()`.
- [GitHub Actions secure use](https://docs.github.com/en/actions/reference/security/secure-use) and [script injection](https://docs.github.com/en/actions/concepts/security/script-injections) — least privilege and context handling.
- [GitHub CLI manual](https://cli.github.com/manual/gh_help_reference) — issue list/create/comment/close interfaces.
- [Dialyxir 1.4.7 documentation](https://dialyxir.hexdocs.pm/readme.html) — PLT build/check behavior and ignore-filter options.
- [actions/cache](https://github.com/actions/cache) — exact-key `cache-hit` semantics.
- [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/) — security category applicability review.

### Tertiary (LOW confidence)

- None used as authority. Proposed helper boundaries and serialization details are explicitly tagged `[ASSUMED]` and logged above.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — no new dependency; versions and patterns were read from the repository and current authenticated environment.
- Architecture: MEDIUM-HIGH — ownership and flow follow locked decisions and existing seams; exact ledger serialization/helper filenames remain discretionary assumptions.
- Nightly/PLT diagnosis: HIGH — authenticated logs show identical major-only PLT key across resolved OTP patch change and the exact old-PLT failure.
- Pitfalls: HIGH for observed false-green/cache/topology defects; MEDIUM for proposed preventive fixture organization.
- Live-truth inventory: HIGH for the current 0.4.5 and adoption-matrix contradictions found by repository scan; active historical-marker syntax remains an implementation assumption.

**Research date:** 2026-09-09
**Valid until:** 2026-09-16 for live GitHub state and Nightly behavior; 2026-10-09 for stable repository architecture
