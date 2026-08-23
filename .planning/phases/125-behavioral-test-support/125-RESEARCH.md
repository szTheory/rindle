# Phase 125: Behavioral Test Support - Research

**Researched:** 2026-08-23
**Domain:** Elixir/ExUnit test-support decomposition, documentation parity, and async-isolation stress evidence
**Confidence:** HIGH for repository facts; MEDIUM for the proposed stress threshold

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TEST-01 | Generated-app proof support is split from the 3,955-line helper into focused modules with one discoverable responsibility each and unchanged packed-adopter coverage. | Exact helper boundaries, consumers, and high-level entry points are mapped below. |
| TEST-02 | Tests validate observable behavior, compiled metadata, or explicit structural contracts instead of reading their own helper/source text to assert implementation strings. | The six helper-text tests and their behavioral/metadata replacements are enumerated below. |
| TEST-03 | Large documentation-parity suites are split by public contract domain with shared helpers, equivalent assertions, and clearer failure ownership. | The 1,118-line suite's four stable public-contract domains and reusable readers/assertions are mapped below. |
| TEST-04 | Async-isolation issue #42 is stress-tested against shipped single-run coverage and process-scoped repo override; close with evidence or narrow to a remaining concrete failure. | Existing process-local seam, guard, focused isolation proof, and a repeatable full-coverage stress protocol are mapped below. |
| SAFE-01 | Maintenance preserves public signatures, schema/migrations, telemetry names/metadata, error shapes, and CI/release invariants. | Preserve and run the existing `scripts/maintainer/refactor_contract.sh` contract; do not change protected product surfaces. |

## Project Constraints (from AGENTS.md)

- Keep edits focused and run the checks named by `RUNNING.md` for the change. [VERIFIED: AGENTS.md]
- Keep `main` green on Quality/coveralls, Integration, Proof, Package Consumer, and Adopter merge-blocking jobs. [VERIFIED: AGENTS.md]
- Prefer PR-first execution for serious milestone work. [VERIFIED: AGENTS.md]
- Do not reopen speculative feature milestones during demand-gated pause; this phase is the already-approved finite v1.24 maintenance work. [VERIFIED: AGENTS.md, PROJECT.md]
- Do not alter product scope or shipped claims; no Phase 125 change may touch public API, schema, migrations, telemetry, error vocabulary, release topology, or admin features. [VERIFIED: PROJECT.md, STATE.md]

## Summary

Phase 125 is a test-only decomposition. `test/install_smoke/support/generated_app_helper.ex` is 3,955 lines and currently combines pure contracts, temporary workspace/package setup, Phoenix source patching, generated migration/test source, environment construction, command execution, and per-profile source templates. Its public test-facing API is small: contract/report helpers, scenario predicates, proof entry points, cleanup, and package provenance. Preserve that API as a thin facade while moving cohesive private work into focused `Rindle.InstallSmoke.GeneratedApp.*` support modules. [VERIFIED: codebase inspection — `wc -l`, helper public-function inventory, and consumers]

The main TEST-02 offenders are five assertions in `generated_app_smoke_test.exs` that read the helper and match implementation strings, plus `phoenix_tus_truth_parity_test.exs`, which snapshots generated-helper text. Replace them with generated-app report assertions, pure focused-contract tests, compiled exports/capability checks, and an injectable bounded command-runner test. Do not remove source-based checks where the source artifact itself is the contract: markdown documentation, workflow policy, shell runner topology, and package contents may retain narrowly structural source inspection. [VERIFIED: codebase inspection — exact `File.read!` call sites and existing SAFE-01 structural test]

Issue #42's original global-repo-swap cause is mitigated in shipped code: `Config.repo/0` first looks for a process-dictionary override, walking Task `$callers`, and `CountingFailingTxnRepo` sets/clears that override locally. The existing isolation test proves an unrelated bare spawned process resolves the real repo while the double is active; the async static guard rejects new global `:rindle, :repo` swaps unless explicitly allowlisted. The remaining work is confidence evidence under the current one-pass ExCoveralls command and a clear issue disposition, not another production isolation redesign. [VERIFIED: codebase inspection — `lib/rindle/config.ex`, counting double, isolation test, async guard, CI workflow; CITED: https://hexdocs.pm/elixir/1.17/Task.html]

**Primary recommendation:** Preserve the current high-level generated-app facade; extract by effect domain, replace helper text snapshots with outcome/metadata/structural proof, split docs parity by adopter-facing contract domain, then run and publish a deterministic multi-seed async stress matrix before resolving issue #42.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Generated Phoenix-app proof | Test harness | OS/subprocess + Database | Support code creates a temporary consumer, invokes Mix commands, and reports observable install/boot/migration behavior. [VERIFIED: codebase inspection] |
| Contract fixtures and catalog validation | Test harness | Database | Pure support contracts validate report shape; generated-app runs remain the authority for real schema/catalog outcomes. [VERIFIED: codebase inspection] |
| Documentation parity | Test harness | Static docs + compiled BEAM metadata | Tests own document reading and shared assertions; `Code.fetch_docs/1` is the correct compiled-metadata boundary for module documentation. [VERIFIED: codebase inspection] |
| Repo override isolation | Elixir process runtime | Test harness + Database sandbox | `Rindle.Config` resolves the local override and `$callers`; tests coordinate separate processes and `Sandbox.allow/3`. [VERIFIED: codebase inspection; CITED: https://hexdocs.pm/elixir/1.17/Task.html] |
| Issue #42 evidence | CI/test harness | GitHub issue tracker | Repeated fresh coverage invocations and focused concurrent proof establish evidence; the issue record receives only the resulting disposition. [VERIFIED: codebase inspection, GitHub issue #42]

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir / ExUnit | project toolchain Elixir 1.17 / OTP 27 | Test modules, tags, process coordination, assertions | Existing repository test framework and supported CI cell. [VERIFIED: `.tool-versions`, RUNNING.md, CI workflow] |
| Ecto SQL Sandbox | locked `ecto_sql` 3.13.5 | Isolates and explicitly shares test DB connections | Existing DataCase and isolation proof already use it. [VERIFIED: `mix.lock`, `test/rindle/config/repo_override_isolation_test.exs`] |
| ExCoveralls | locked 0.18.5 | Shipped one-run coverage command | Quality executes `mix coveralls.multiple --type local --type json`, rather than the retired second coverage suite run. [VERIFIED: `mix.lock`, `.github/workflows/ci.yml`, RUNNING.md] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Elixir `Task` / `Process` | stdlib | Task caller lineage and isolated process coordination | Use `Task` only to prove intentional `$callers` inheritance; use bare `spawn` for an unrelated-reader proof. [CITED: https://hexdocs.pm/elixir/1.17/Task.html; VERIFIED: existing isolation test] |
| `Code.fetch_docs/1` | stdlib | Compiled documentation metadata | Use for public module/moduledoc claims, instead of matching implementation source. [VERIFIED: `docs_parity_test.exs`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Focused support modules behind a facade | Rewrite generated-app proof into a new framework | Unnecessary risk to packed-adopter authority and no TEST requirement needs it. [VERIFIED: phase requirements and current test architecture] |
| Fresh-process seeded coverage stress | `mix test --partitions` | Partitioning is explicitly deferred pending measured starvation and would change the thing under test. [VERIFIED: ROADMAP.md] |
| Outcome/metadata assertions | Helper/source-string snapshots | Strings couple tests to private layout and fail on behavior-preserving refactors. [VERIFIED: TEST-02 and current offending tests] |

**Installation:** No new package is authorized or required. [VERIFIED: PROJECT.md, phase scope]

## Architecture Patterns

### System Architecture Diagram

```text
generated_app_smoke_test / docs-domain suites / stress runner
                 |
                 v
      GeneratedApp facade (stable test-facing entry points)
       |          |          |             |
       v          v          v             v
   Contracts   Workspace   App/Migration  Command/Profile sources
       |          |          |             |
       +----------+----------+-------------+
                              |
                              v
                  temporary Phoenix consumer + Postgres
                              |
                              v
               report / exit status / catalog snapshot / compiled metadata
                              |
                              v
                  focused observable assertions and issue evidence
```

### Recommended Project Structure

```text
test/install_smoke/
├── support/generated_app_helper.ex          # compatibility facade only
├── support/generated_app/
│   ├── contracts.ex                         # pure contracts, catalog/report validators
│   ├── workspace.ex                         # tmp root, package build, cleanup
│   ├── app_builder.ex                       # Phoenix generation and source/config patching
│   ├── migrations.ex                        # host/Rindle/upgrade fixtures and runners
│   ├── command_runner.ex                    # bounded process execution and diagnostics
│   └── profiles.ex                          # profile env plus generated image/video/tus/gcs/mux tests
├── docs_parity/
│   ├── support.ex                           # document readers, section/order/compiled-doc helpers
│   ├── install_and_migrations_test.exs
│   ├── onboarding_and_capabilities_test.exs
│   ├── operations_and_release_test.exs
│   └── product_and_admin_test.exs
└── async_isolation_stress_test.exs or maintainer script # only repeatable stress orchestration
```

### Pattern 1: Stable Facade, Cohesive Private Support Owners

**What:** Keep `Rindle.InstallSmoke.GeneratedAppHelper` as the single import/require target and preserve its existing public function names and return maps. Delegate private concerns to focused modules receiving explicit inputs; do not expose the new modules as product API. [VERIFIED: current generated-app consumers and phase boundary]

**When to use:** Every extraction from the oversized helper. Start with pure contracts and command runner, then workspace/app/migrations, then profile source generators; do not mix unrelated effects in one module. [VERIFIED: helper responsibility inventory]

**Boundary checks:** Existing `prove_package_install!/1`, public compatibility, isolation upgrade, legacy upgrade, cleanup, profile/scenario predicates, and package provenance must produce the same reports and tags. Packed-adopter proof remains unchanged. [VERIFIED: `generated_app_smoke_test.exs` and ROADMAP.md]

### Pattern 2: Test the Contract at its Observable Layer

**What:** Select evidence in this order: generated-app output/report for consumer behavior; `function_exported?/3`/`Code.fetch_docs/1` for compiled metadata; and narrowly parsed structure only if the script/document itself is the shipped policy. [VERIFIED: TEST-02; existing API and SAFE-01 tests]

**Replacement map:**

| Current source snapshot | Replace with | Evidence layer |
|---|---|---|
| Oban before/after helper strings | Assert actual generated isolation-upgrade report has equal public `oban_jobs` snapshots and retains the expected catalog validator behavior. | Generated-app outcome + pure contract |
| OID placeholder/alias SQL strings | Remove the implementation-specific assertion; retain report-level catalog preservation/rejection cases and real upgrade proof. | Observable schema/catalog behavior |
| `doctor_ready?` expression strings | Assert generated smoke report marks doctor ready only after the real generated app command succeeds; add a focused report-normalizer negative case if needed. | Command result/report behavior |
| `Task.yield`/shutdown/stage string snapshot | Unit-test a focused command runner with an injected fast success and deliberately timed-out command/timeout, asserting bounded timeout map and stage-labelled failure. | Behavior |
| `mktemp` source snapshot | Invoke workspace allocator twice, assert distinct existing roots under system temp, then cleanup both. | Filesystem behavior |
| Phoenix helper source strings | Assert the actual tus generated-app report exposes expected uploader/endpoint/session/asset and completion evidence; keep guide prose assertions and use compiled `Rindle.LiveView` export/capability checks. | Generated-app behavior + compiled metadata |

### Pattern 3: Documentation-Parity Domain Suites with Shared Support

**What:** Replace one 1,118-line `DocsParityTest` with domain-owned modules that share only document loading, section extraction, ordering, and compiled-doc readers. Keep assertions verbatim/equivalent as they move; do not change product documentation in this phase. [VERIFIED: test inventory and TEST-03]

**Recommended domains:**

| Suite | Owns | Existing test block |
|---|---|---|
| `install_and_migrations_test` | README/getting-started/upgrading, Rindle.Migration, public/default schema path | lines 176–527 plus generated migration fixture parity |
| `onboarding_and_capabilities_test` | lifecycle, convenience API, product fit, AV and storage onboarding, tus moduledoc | lines 105–175 and 528–635, 739–843 |
| `operations_and_release_test` | CI/toolchain, release/upgrade navigation, running matrix, nine tasks, doctor/runtime split | lines 57–104 and 636–878 |
| `product_and_admin_test` | owner erasure/user flows and admin-console promises | lines 879–1024 |

Use a map of named document paths in `DocsParity.Support.setup_docs/0` rather than repeated `File.read!` calls. Preserve test names or prepend the domain in failure messages so failures identify the owning contract. [VERIFIED: `docs_parity_test.exs`]

### Anti-Patterns to Avoid

- **Big-bang helper rewrite:** It would combine process, filesystem, generated source, database, and environment changes, obscuring which contract broke. Extract one domain at a time behind the facade. [VERIFIED: helper inventory]
- **Reintroducing global repo configuration:** Do not use `Application.put_env(:rindle, :repo, ...)` in the double or stress harness. The all-module guard exists precisely to block this. [VERIFIED: `async_safety_guard_test.exs`]
- **Testing a new stress runner by its text:** Assert repeat count, seed list, command exit and captured failures as data; the runner should orchestrate existing shipped commands, not become another source snapshot target. [ASSUMED]
- **Changing CI topology to make stress easier:** Do not add partitions or a second coverage run. Exercise the exact shipped single-run Quality command. [VERIFIED: ROADMAP.md, CI workflow]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Async test isolation | Global config save/restore or a custom global lock | Existing process-dictionary repo override, `$callers` walk, and Ecto Sandbox allowance | The shipped seam already separates unrelated processes while retaining descendant inheritance. [VERIFIED: codebase inspection; CITED: https://hexdocs.pm/elixir/1.17/Task.html] |
| Consumer-app acceptance | In-memory imitation of Phoenix install behavior | Existing generated Phoenix app/package proof | Packed-consumer behavior, compilation, migrations, boot, and reports are the actual contract. [VERIFIED: generated-app helper and ROADMAP.md] |
| Documentation metadata | Parsing `.ex` source for docs | `Code.fetch_docs/1` and existing compiled-doc helper | Compiled metadata is the shipped ExDoc-facing boundary. [VERIFIED: `docs_parity_test.exs`] |
| Coverage reproduction | A second ad hoc suite or changed CI lane | `mix coveralls.multiple --type local --type json` exactly as Quality runs it | The single run is the shipped flake-exposure reduction. [VERIFIED: RUNNING.md, CI workflow] |

**Key insight:** This phase gains confidence by exercising the same consumer/process boundaries users and CI exercise, not by freezing incidental helper implementation text. [VERIFIED: TEST-01 through TEST-04]

## Common Pitfalls

### Pitfall 1: Breaking require/load order while splitting support modules

**What goes wrong:** A generated-app test fails to compile because the facade delegates to an unrequired support module or a support module still references facade-private functions. [VERIFIED: `Code.require_file` is the current load mechanism]

**How to avoid:** Have the facade require support modules in dependency order, make inter-module APIs explicit, and run the phase's fast contract tests before every generated-app integration tag. Preserve the existing facade module/name as the only consumer import. [ASSUMED]

### Pitfall 2: Replacing one source snapshot with another

**What goes wrong:** Moving string matches from `GeneratedAppHelper` into support modules preserves refactor friction without improving contract coverage. [VERIFIED: exact helper source assertions in `generated_app_smoke_test.exs`]

**How to avoid:** Each moved test must name an outcome, compiled metadata assertion, or explicit script/document structural property; reject tests whose only signal is an implementation substring. [VERIFIED: TEST-02]

### Pitfall 3: Splitting documentation tests by file, not contract

**What goes wrong:** Multiple suites each read the same documents and assertions become duplicated or silently diverge. [VERIFIED: current suite reads shared README/guide/upgrade/running documents]

**How to avoid:** Group by public adopter/maintainer contract and share one support loader and section helpers. Each suite should own its failure vocabulary. [VERIFIED: TEST-03]

### Pitfall 4: Calling a small concurrency test conclusive stress evidence

**What goes wrong:** The existing isolation proof validates the old-to-new causal delta but does not sample the full one-run coverage workload or seed variability. [VERIFIED: existing one-test isolation proof; issue #42]

**How to avoid:** Keep the focused proof, add a bounded repeated fresh-process stress protocol using the exact Quality coverage command, record seed/iteration/toolchain/command/head SHA, and treat any failure as a concrete issue update rather than retrying it away. [VERIFIED: issue #42, RUNNING.md; ASSUMED: recommended evidence format]

### Pitfall 5: Masking an issue #42 failure

**What goes wrong:** Retrying until green or closing on a partial run loses the diagnostic evidence needed if fixture collisions still exist. [VERIFIED: issue #42 describes rare order-dependent DB collisions]

**How to avoid:** Stop at first failing iteration, archive sanitized command output/JUnit/seed and query error class, then leave the issue open and narrow it to the minimal reproducer. Only close after the agreed repeat matrix and exact-head CI are green. [ASSUMED]

## Code Examples

### Process-local override stress shape

```elixir
# Existing production/test seam; stress it without changing Rindle.Config.
for seed <- seeds do
  assert {:ok, 0} = run_fresh_quality_coverage(seed)
end

CountingFailingTxnRepo.with_counting_repo(1, fn ->
  assert Config.repo() == CountingFailingTxnRepo
  # An unrelated bare spawn must resolve Rindle.Repo while the override is active.
end)
```

The relevant documented distinction is intentional: Task caller tracking uses the process dictionary's `$callers` chain, while processes are isolated by default. The existing proof correctly uses bare `spawn` for the unrelated reader and `Sandbox.allow/3` before its transaction. [CITED: https://hexdocs.pm/elixir/1.17/Task.html; CITED: https://elixir.hexdocs.pm/processes.html; VERIFIED: `repo_override_isolation_test.exs`]

### Documentation support shape

```elixir
defmodule Rindle.InstallSmoke.DocsParity.Support do
  def load_docs(paths), do: Map.new(paths, fn {name, path} -> {name, File.read!(path)} end)
  def compiled_moduledoc!(module), do: module |> Code.fetch_docs() |> extract_moduledoc!()
  def section_between!(document, start_at, stop_at), do: # existing helper semantics
end
```

Keep the current helper semantics and test assertions; the example only illustrates ownership, not a required public API. [VERIFIED: existing `docs_parity_test.exs` helpers]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Quality ran the suite plus a coverage rerun | One `coveralls.multiple --type local --type json` invocation emits both gate and JSON | v1.21 | The historical doubled flake exposure is removed; Phase 125 must stress this current command rather than revive the old path. [VERIFIED: RUNNING.md, CI workflow, issue #42] |
| Counting double globally changed `:rindle, :repo` | Process-local override plus `$callers` lookup | v1.21 Phase 110 | Unrelated async processes no longer observe the failing double. [VERIFIED: Phase 110 verification and current code] |
| `generated_app_helper.ex` is one mixed support owner | Focused support modules behind a compatibility facade | Phase 125 target | Improves discoverability while retaining packed-adopter behavior. [VERIFIED: TEST-01] |

**Deprecated/outdated:** A second coverage suite run and a global repo swap are both explicitly out of bounds. [VERIFIED: RUNNING.md, `async_safety_guard_test.exs`]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | A focused command runner can accept a safe test-only timeout/command injection without changing externally observable generated-app behavior. | Replacement map / Pattern 1 | Low; execution can instead test a pure result-normalizer while retaining current runner. |
| A2 | A 25-seed fresh Quality-command matrix plus focused repeated isolation proof is a sufficient pre-closure threshold for a historically rare flake. | Async stress protocol | Medium; it may be insufficient to convince the maintainer or issue evidence may reveal a failure. |
| A3 | Docs suite filenames/domains proposed here are the least-surprising ownership split. | Recommended Project Structure | Low; filenames are private test organization. |

## Open Questions

1. **What exact repeat count should issue #42 closure claim?**
   - What we know: issue #42 is rare/order-dependent; CI now executes the single-run coverage command; the local toolchain is Elixir 1.19/OTP 28 while the supported CI authority is 1.17/OTP 27. [VERIFIED: issue #42, RUNNING.md, local environment]
   - What's unclear: no historical frequency supports a mathematically conclusive run count.
   - Recommendation: use 25 distinct deterministic seeds as the local stress floor, preserve every iteration result, then require the exact-head supported CI Quality matrix/CI Summary before closing. If any iteration fails, stop and narrow instead. [ASSUMED]

2. **Can Phase 125 close GitHub issue #42 itself?**
   - What we know: the roadmap requires close-or-narrow disposition and the issue is currently open. [VERIFIED: ROADMAP.md, GitHub issue #42]
   - Recommendation: plan a final human-visible issue update only after evidence is committed and exact-head CI passes. If it fails, post the minimal reproducer and leave it open. This is external state, so do not close it as a side effect of local test edits. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---:|---|---|
| Elixir/Mix | focused tests and stress command | ✓ | 1.19.5 / OTP 28 locally | Supported 1.17 / OTP 27 CI is final authority |
| PostgreSQL client | generated-app/database proof diagnostics | ✓ | psql 14.17 | CI database service |
| Docker | optional local service-backed checks | ✓ | 29.5.2 | CI service environment |
| Node | existing tus generated-app profile only | ✓ | 20.18.1 | CI/profile tags control execution |

**Missing dependencies with no fallback:** None identified for planning. The local Elixir/OTP cell is newer than the support cell, so it is diagnostic rather than closure authority. [VERIFIED: local environment, ROADMAP.md]

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit (project native) with Ecto SQL Sandbox and ExCoveralls [VERIFIED: `test/test_helper.exs`, `mix.exs`] |
| Config file | `test/test_helper.exs` [VERIFIED: codebase inspection] |
| Quick run command | `MIX_ENV=test mix test test/install_smoke/generated_app_smoke_test.exs test/install_smoke/docs_parity_test.exs test/rindle/config/repo_override_isolation_test.exs test/async_safety_guard_test.exs --seed 0` [ASSUMED: focused aggregation] |
| Full suite command | `mix coveralls.multiple --type local --type json --slowest 20` [VERIFIED: RUNNING.md, CI workflow] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| TEST-01 | Facade-backed generated-app proofs keep package/consumer outcomes unchanged after support split | integration/adopter | `MIX_ENV=test mix test test/install_smoke/generated_app_smoke_test.exs --seed 0` plus existing tagged package/adopter lanes | ✅ |
| TEST-02 | No helper implementation-string snapshots; replacement contract behavior/metadata passes | unit + structural | focused generated-app contract and Phoenix tus parity tests | ❌ Wave 0 adjustment |
| TEST-03 | Domain suites retain all docs assertions with shared support | unit/static docs | `MIX_ENV=test mix test test/install_smoke/docs_parity --seed 0` | ❌ Wave 0 split |
| TEST-04 | Repeated current coverage plus override isolation evidence yields close-or-narrow issue disposition | stress + integration | fresh-process loop of `mix coveralls.multiple --type local --type json --seed <seed>` and focused isolation test | ❌ Wave 0 stress harness |
| SAFE-01 | Protected public/schema/telemetry/error/release contracts stay intact | contract | `bash scripts/maintainer/refactor_contract.sh` | ✅ |

### Sampling Rate

- **Per task commit:** focused test file(s), `mix format --check-formatted`, and `bash scripts/maintainer/refactor_contract.sh` when shared test support changes. [VERIFIED: existing Phase 124 verification posture]
- **Per wave merge:** `mix test` for affected install-smoke/docs/isolation suites with `--seed 0`. [ASSUMED]
- **Phase gate:** exact shipped Quality coverage command on 25 recorded seeds; final supported exact-head CI Summary green. [ASSUMED; VERIFIED: CI Summary authority]

### Wave 0 Gaps

- [ ] `test/install_smoke/docs_parity/support.ex` and domain test files — preserve current assertions while making ownership explicit.
- [ ] Focused generated-app command-runner/workspace behavioral tests — replace helper text snapshots.
- [ ] Reproducible async-isolation stress runner/report format — records command, seeds, toolchain, SHA, and first failure.
- [ ] No framework installation — existing ExUnit/Ecto/ExCoveralls stack covers the phase. [VERIFIED: mix project/lock]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | No | Test-support-only phase; preserve existing security contract tests. [VERIFIED: phase scope] |
| V3 Session Management | No | No session behavior change. [VERIFIED: phase scope] |
| V4 Access Control | No | No authorization behavior change. [VERIFIED: phase scope] |
| V5 Input Validation | Yes, test harness inputs | Keep explicit profile/tag/command inputs and do not construct unsafe shell strings from untrusted values. [ASSUMED] |
| V6 Cryptography | No | No cryptographic behavior change. [VERIFIED: phase scope] |

### Known Threat Patterns for Test Support

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Generated command/environment leaks credentials into an issue report | Information disclosure | Report only command class, seed, exit, sanitized failure summary, and CI links; do not post environment values or full temporary app config. [ASSUMED] |
| Stress runner masks failure through retries or `|| true` | Repudiation | Stop on first failure and preserve seed/output; return nonzero. [ASSUMED] |
| Refactor alters protected runtime behavior | Tampering | Run SAFE-01 and preserve no-product-change scope audit. [VERIFIED: SAFE-01, PROJECT.md] |

## Sources

### Primary (HIGH confidence)

- Repository code: `test/install_smoke/support/generated_app_helper.ex`, `generated_app_smoke_test.exs`, `docs_parity_test.exs`, `phoenix_tus_truth_parity_test.exs` — helper size, responsibilities, consumers, and snapshot targets.
- Repository code: `lib/rindle/config.ex`, `test/support/counting_failing_txn_repo.ex`, `test/rindle/config/repo_override_isolation_test.exs`, `test/async_safety_guard_test.exs` — shipped isolation mechanism and guard.
- Repository policy: `.github/workflows/ci.yml`, `RUNNING.md`, `scripts/maintainer/refactor_contract.sh`, `.planning/PROJECT.md`, `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, `AGENTS.md` — single-run coverage, constraints, requirements, and invariants.
- GitHub issue [#42](https://github.com/szTheory/rindle/issues/42) — original flake symptoms and status.

### Secondary (MEDIUM confidence)

- [Elixir Task documentation](https://hexdocs.pm/elixir/1.17/Task.html) — `$callers` lineage and Task semantics.
- [Elixir Processes guide](https://elixir.hexdocs.pm/processes.html) — process isolation and message-passing model.

### Tertiary (LOW confidence)

- The recommended 25-seed stress threshold and report schema are explicitly marked `[ASSUMED]`; no source supplies a statistically conclusive count for this historical flake.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — no new libraries; current lockfile, test helper, and CI commands were inspected.
- Architecture: HIGH — helper ownership, consumers, source snapshots, and docs-suite inventory were inspected directly.
- Pitfalls: HIGH for existing source/global-state risks; MEDIUM for stress-run count and closure protocol.

**Research date:** 2026-08-23
**Valid until:** 30 days for repository structure; re-check CI command and issue state immediately before execution.
