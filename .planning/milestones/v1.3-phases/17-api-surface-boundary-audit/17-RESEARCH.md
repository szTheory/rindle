# Phase 17: API Surface Boundary Audit - Research

**Researched:** 2026-04-30
**Domain:** Elixir library public API boundary management, ExDoc visibility, and semver-safe compatibility shims [VERIFIED: codebase grep][CITED: https://hexdocs.pm/ex_doc/ExDoc.html][CITED: https://hexdocs.pm/elixir/writing-documentation.html]
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

Copied verbatim from `.planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md`. [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md]

### Locked Decisions
- **D-01:** Rindle will use a **layered public surface**: `Rindle` as the primary first-run facade, plus a small set of explicitly supported subsystem modules for advanced and operational use. Do not treat the entire visible namespace as public.
- **D-02:** First-tier adopter docs must start with exactly two concepts: `Rindle` and `Rindle.Profile`. README and getting-started content should teach the facade-first path, not lower-level modules by default.
- **D-03:** The following modules remain intentionally public because adopters are expected to reference them directly: `Rindle`, `Rindle.Profile`, `Rindle.Upload.Broker`, `Rindle.Delivery`, `Rindle.Storage`, `Rindle.Storage.S3`, `Rindle.Storage.Local`, `Rindle.Authorizer`, `Rindle.Analyzer`, `Rindle.Scanner`, `Rindle.Processor`, `Rindle.LiveView`, `Rindle.HTML`, `Mix.Tasks.Rindle.*`, `Rindle.Workers.AbortIncompleteUploads`, and `Rindle.Workers.CleanupOrphans`.
- **D-04:** Domain schema modules (`Rindle.Domain.MediaAsset`, `MediaAttachment`, `MediaUploadSession`, `MediaVariant`, and `MediaProcessingRun`) remain public **as queryable/reference data types only**. Lifecycle mutation and orchestration stay on `Rindle` and the explicitly supported advanced modules, not on FSM internals.

### Hidden/internal boundary
- **D-05:** Hide implementation-only modules from ExDoc with `@moduledoc false`. This includes `Rindle.Config`, `Rindle.Repo`, `Rindle.Security.*`, `Rindle.Profile.Validator`, `Rindle.Profile.Digest`, `Rindle.Storage.Capabilities`, `Rindle.Domain.AssetFSM`, `Rindle.Domain.UploadSessionFSM`, `Rindle.Domain.VariantFSM`, `Rindle.Domain.StalePolicy`, `Rindle.Workers.PromoteAsset`, `Rindle.Workers.ProcessVariant`, and `Rindle.Workers.PurgeStorage`.
- **D-06:** `Rindle.Ops.*` should be treated as hidden/internal for now. Keep the public operational story on `mix rindle.*` tasks and the two adopter-scheduled maintenance workers, rather than supporting direct in-process `Rindle.Ops.*` invocation as long-term contract.
- **D-07:** Do not rely on `@doc false` alone to define module boundaries. If a module is implementation-only, hide the module itself; `@doc false` is only for narrow compatibility shims on otherwise-public modules.

### Naming and semver posture
- **D-08:** No breaking renames or removals land on `0.1.x` unless they are additive-compatible. Phase 17 should prefer additive aliases, hidden compatibility shims, and explicit deferral over surprising published adopters.
- **D-09:** Add `Rindle.verify_completion/2` now as the preferred public name for the direct-upload verification boundary. Keep `Rindle.verify_upload/2` as a compatibility shim during `0.1.x`, and teach `verify_completion/2` in docs going forward.
- **D-10:** Keep `Rindle.complete_multipart_upload/3` unchanged. It names a transport-specific multipart completion step and should not be forced into false symmetry with the direct-upload verification concept.
- **D-11:** Record `verify_upload/2` as legacy compatibility surface, not the canonical future-facing verb. Any hard removal belongs to `v0.2.0` or later.

### Observability and helper exposure
- **D-12:** `Rindle.log_variant_processing_failure/3` should stop being part of the documented public facade. Move its implementation behind a hidden internal module, keep a thin `Rindle` compatibility shim in `0.1.x`, and mark the facade entrypoint `@doc false` with explicit rationale.
- **D-13:** Rindle's public observability posture stays **telemetry-first**, not “call this logging helper” first. If richer adopter-facing observability is needed later, add stable telemetry or documented operator hooks instead of promoting internal logging helpers.

### Documentation IA and DX
- **D-14:** ExDoc should reflect tiers explicitly via `groups_for_modules`. Recommended groups: `Facade`, `Profiles`, `Upload`, `Delivery`, `Optional Integrations`, `Extension Points`, `Storage Adapters`, `Operations`, and `Data Types`.
- **D-15:** Getting-started docs should show the facade path (`Rindle.initiate_upload` / `Rindle.verify_completion` or `Rindle.upload`, `Rindle.attach`, `Rindle.url`) and only branch into `Rindle.Upload.Broker`, `Rindle.Delivery`, `LiveView`, adapter, and extension-point material in advanced sections.
- **D-16:** Do not leave real `@moduledoc` text on implementation modules just because the docs read well. In this ecosystem, visible docs are an API promise; ExDoc output must match the intended support boundary.

### Decision-making preference
- **D-17:** Planning and implementation should continue to use the repo's existing preference: agent decides by default, with escalation only for genuinely high-impact choices such as public semver breaks, destructive data/security changes, irreversible infra/cost moves, or product-scope shifts. This phase's boundary recommendations are locked accordingly without further blocking questions.

### the agent's Discretion
- Exact `groups_for_modules` naming and grouping order in `mix.exs`, as long as the layered IA remains clear.
- Exact compatibility-shim wording for deprecated or hidden functions in `Rindle`.
- Exact file/module name for the hidden observability helper behind `log_variant_processing_failure/3`.
- Exact guide split between onboarding, optional integrations, operations, and reference material, as long as the facade-first path stays primary.

### Deferred Ideas (OUT OF SCOPE)
- Remove the `verify_upload/2` compatibility shim in `v0.2.0` or later once the facade/docs/test surface has fully converged on `verify_completion/2`.
- Remove the `Rindle.log_variant_processing_failure/3` compatibility shim in `v0.2.0` or later if no adopter need emerges.
- Revisit whether `Rindle.Ops.*` should become intentionally supported operator APIs only if a real adopter use case appears; default is hidden for now.
- If Phase 18 or later wants stronger “public API manifest” guarantees, consider adding explicit contract tests around visible modules/functions instead of relying on ExDoc visibility alone.
- Project-wide GSD preference shifting is already effectively present via `.planning/STATE.md` plus saved feedback-memory precedent; no new config mechanism should be invented in this phase without a broader workflow change.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| API-01 | Resolve `verify_upload/2` vs `complete_multipart_upload/3` vocabulary inconsistency [VERIFIED: .planning/REQUIREMENTS.md] | Add `Rindle.verify_completion/2`, retain `verify_upload/2` as legacy shim, and update facade-first docs/examples to teach the new name while keeping multipart terminology transport-specific [VERIFIED: lib/rindle.ex][VERIFIED: lib/rindle/upload/broker.ex][VERIFIED: lib/rindle/live_view.ex][VERIFIED: README.md][CITED: https://hexdocs.pm/elixir/writing-documentation.html] |
| API-02 | Remove `log_variant_processing_failure/3` from the public facade or explicitly mark it internal [VERIFIED: .planning/REQUIREMENTS.md] | Move implementation into a hidden internal module, keep a thin `Rindle` wrapper for `0.1.x`, and mark the wrapper `@doc false` with rationale [VERIFIED: lib/rindle.ex][CITED: https://hexdocs.pm/elixir/writing-documentation.html] |
| API-03 | Make public names consistent across the public surface [VERIFIED: .planning/REQUIREMENTS.md] | Audit generated docs plus source exports against the locked allowlist/denylist, then update facade docs, LiveView docs, and guide snippets so visible names converge on the locked contract [VERIFIED: lib/rindle.ex][VERIFIED: lib/rindle/live_view.ex][VERIFIED: test/install_smoke/docs_parity_test.exs][VERIFIED: mix docs output] |
| API-04 | Hide all internal modules/functions before the documentation sprint [VERIFIED: .planning/REQUIREMENTS.md] | Use `@moduledoc false` for internal modules and reserve `@doc false` for narrow public-module shims; verify with `mix docs` and `Code.fetch_docs/1` [CITED: https://hexdocs.pm/elixir/writing-documentation.html][CITED: https://hexdocs.pm/ex_doc/ExDoc.html][VERIFIED: mix run Code.fetch_docs audit][VERIFIED: mix docs output] |
| API-05 | Record the breaking-change determination for published signatures [VERIFIED: .planning/REQUIREMENTS.md] | Produce an explicit boundary/semver decision artifact stating that published `0.1.4` surface changes are additive only in `0.1.x`, with removals deferred to `v0.2.0+` [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md][VERIFIED: mix.exs][CITED: https://hex.pm/packages/rindle][CITED: https://hexdocs.pm/elixir/compatibility-and-deprecations.html] |
</phase_requirements>

## Summary

Phase 17 is not a generic documentation pass; it is a contract-locking pass on an already-published `0.1.4` Hex package whose current docs expose far more surface than the locked context intends. The live HexDocs API reference currently lists internal modules such as `Rindle.Config`, `Rindle.Ops.*`, `Rindle.Profile.Digest`, `Rindle.Profile.Validator`, `Rindle.Security.*`, FSM modules, and internal workers as public pages, and the generated local docs reproduce that same exposure because those modules still carry normal `@moduledoc` text today [CITED: https://hexdocs.pm/rindle/api-reference.html][VERIFIED: mix docs output][VERIFIED: mix run Code.fetch_docs audit][VERIFIED: codebase grep].

The implementation path should be mechanical and testable: build a current module/function manifest from generated docs plus `Code.fetch_docs/1`, compare it to the locked allowlist/denylist in `17-CONTEXT.md`, hide denied modules with `@moduledoc false`, add the additive `Rindle.verify_completion/2` facade alias, downgrade `verify_upload/2` to documented legacy compatibility surface, and move `log_variant_processing_failure/3` behind a hidden module while keeping a shim on `Rindle` for `0.1.x` [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md][VERIFIED: lib/rindle.ex][VERIFIED: lib/rindle/upload/broker.ex][CITED: https://hexdocs.pm/elixir/writing-documentation.html].

Phase 17 should also leave behind explicit planning artifacts for Phase 18: a stable public API manifest, a breaking-change decision record, updated ExDoc module grouping, and verification tests that fail if hidden modules reappear or if facade-first docs regress back to broker-first teaching [VERIFIED: .planning/ROADMAP.md][VERIFIED: test/install_smoke/docs_parity_test.exs][VERIFIED: mix.exs][CITED: https://hexdocs.pm/ex_doc/ExDoc.html].

**Primary recommendation:** Implement Phase 17 as a source-of-truth boundary audit driven by generated docs and `Code.fetch_docs/1`, with additive shims only on the published `0.1.x` line and no undocumented public pages left visible when the phase closes [CITED: https://hexdocs.pm/elixir/writing-documentation.html][CITED: https://hexdocs.pm/ex_doc/ExDoc.html][CITED: https://hex.pm/packages/rindle].

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Public module boundary | Library source (`lib/`) | ExDoc config (`mix.exs`) | Visibility is authored in module attributes, while ExDoc renders the resulting public set and groups it in HexDocs output [VERIFIED: lib/**/*.ex module scan][VERIFIED: mix.exs][CITED: https://hexdocs.pm/ex_doc/ExDoc.html] |
| Public function naming and compatibility shims | `Rindle` facade | Callers/docs/tests | The naming inconsistency is exposed at the facade and taught in docs, while broker internals already use `verify_completion/2` [VERIFIED: lib/rindle.ex][VERIFIED: lib/rindle/upload/broker.ex][VERIFIED: lib/rindle/live_view.ex][VERIFIED: README.md] |
| Internal observability helper hiding | Hidden internal module | `Rindle` facade shim | The actual logging implementation should move internal, but `Rindle` retains the compatibility wrapper during `0.1.x` [VERIFIED: lib/rindle.ex][VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md] |
| Docs information architecture | ExDoc config (`mix.exs`) | README/guides | Module grouping lives in ExDoc config, while facade-first onboarding must be reflected in top-level guides [VERIFIED: mix.exs][VERIFIED: README.md][VERIFIED: guides/getting_started.md][CITED: https://hexdocs.pm/ex_doc/ExDoc.html] |
| Semver/breaking-change determination | Phase artifact in `.planning/` | Code comments/docs metadata | The decision must exist outside source code so Phase 18 can trust the boundary before adding `@doc`/`@spec` coverage [VERIFIED: .planning/ROADMAP.md][VERIFIED: .planning/REQUIREMENTS.md][CITED: https://hex.pm/packages/rindle] |
| Verification of hidden/public split | Generated docs + tests | `Code.fetch_docs/1` audit | The docs build proves what ExDoc publishes, while `Code.fetch_docs/1` provides an independent source-level manifest check from compiled beams [CITED: https://hexdocs.pm/elixir/writing-documentation.html][VERIFIED: mix docs output][VERIFIED: mix run Code.fetch_docs audit] |

## Standard Stack

### Core
| Library / Tool | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir docs attributes (`@moduledoc`, `@doc`, `@deprecated`) | Elixir 1.19.5 | Define visible vs hidden API contract and deprecation metadata | Elixir treats documentation as API contract and provides the language-native hiding/deprecation primitives this phase needs [VERIFIED: `elixir --version`][CITED: https://hexdocs.pm/elixir/writing-documentation.html] |
| ExDoc | 0.40.1 | Generate and group published API docs | ExDoc is the current docs generator in the repo, honors `@moduledoc false`, and supports `groups_for_modules` for the tiered IA [VERIFIED: mix.lock][VERIFIED: mix.exs][CITED: https://hexdocs.pm/ex_doc/ExDoc.html] |
| `Code.fetch_docs/1` | Elixir 1.19.5 | Audit compiled public docs metadata without parsing source manually | It reads the docs chunk from compiled beams and gives a deterministic manifest for visibility checks [VERIFIED: `elixir --version`][CITED: https://hexdocs.pm/elixir/writing-documentation.html] |

### Supporting
| Library / Tool | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `mix docs --warnings-as-errors` | Mix 1.19.5 / ExDoc 0.40.1 | Rebuild API reference and catch broken references | Use on every boundary change that affects docs visibility, grouping, or renamed public examples [VERIFIED: `mix --version`][VERIFIED: test/install_smoke/package_metadata_test.exs][VERIFIED: test/install_smoke/release_docs_parity_test.exs] |
| ExUnit docs/install smoke tests | Repo-local | Prevent README/guide regressions while the public story is re-centered on `Rindle` | Extend existing parity tests rather than inventing a new docs harness [VERIFIED: test/install_smoke/docs_parity_test.exs][VERIFIED: test/install_smoke/release_docs_parity_test.exs] |
| `mix xref graph` | Mix 1.19.5 | Sanity-check whether boundary work needs structural dependency refactors | Use as a confidence check; this repo currently reports no compile-connected cycles for the phase-relevant graph pass [VERIFIED: `mix --version`][VERIFIED: `mix xref graph --format cycles --label compile-connected`] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Code.fetch_docs/1` + generated docs | Regex-only source grep | Regex sees declarations but not the compiled docs chunk ExDoc actually consumes, so it is weaker for contract verification [CITED: https://hexdocs.pm/elixir/writing-documentation.html][VERIFIED: codebase grep] |
| `@moduledoc false` on internal modules | `@doc false` on each internal function | Elixir explicitly warns that `@doc false` does not make a function private and recommends hiding whole internal modules instead [CITED: https://hexdocs.pm/elixir/writing-documentation.html] |
| Additive facade alias in `0.1.x` | Renaming/removing published function now | The package is already live as `0.1.4`, and locked context defers breaking removals to `v0.2.0+` [CITED: https://hex.pm/packages/rindle][VERIFIED: mix.exs][VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md] |

**Installation:** No new dependency is required for Phase 17 itself; the repo already ships ExDoc and the rest of the needed toolchain [VERIFIED: mix.exs][VERIFIED: mix.lock].

**Version verification:** `mix.exs` targets Elixir `~> 1.15` and currently builds under Elixir `1.19.5`; `mix.lock` pins `ex_doc` to `0.40.1`; Hex.pm shows `rindle` `v0.1.4` last updated on April 29, 2026 [VERIFIED: mix.exs][VERIFIED: `elixir --version`][VERIFIED: mix.lock][CITED: https://hex.pm/packages/rindle].

## Architecture Patterns

### System Architecture Diagram

```text
Source modules in lib/
  -> module attributes define visibility (`@moduledoc` / `@doc`) [CITED: https://hexdocs.pm/elixir/writing-documentation.html]
  -> `mix docs --warnings-as-errors` renders published API reference [VERIFIED: mix docs output]
  -> ExDoc `groups_for_modules` organizes the visible modules into public tiers [CITED: https://hexdocs.pm/ex_doc/ExDoc.html]
  -> README / guides teach the chosen facade-first path [VERIFIED: README.md][VERIFIED: guides/getting_started.md]
  -> ExUnit parity tests confirm the docs story matches the intended contract [VERIFIED: test/install_smoke/docs_parity_test.exs]
  -> Phase 18 consumes the resulting boundary manifest and semver record before adding broad `@doc` / `@spec` coverage [VERIFIED: .planning/ROADMAP.md]
```

### Recommended Project Structure
```text
lib/
├── rindle.ex                    # public facade + compatibility shims [VERIFIED: lib/rindle.ex]
├── rindle/upload/broker.ex      # supported advanced upload subsystem [VERIFIED: lib/rindle/upload/broker.ex]
├── rindle/{delivery,profile,...}.ex  # intentionally public subsystem and behaviour modules [VERIFIED: module scan]
├── rindle/{config,ops,security,...}  # internal modules to hide with `@moduledoc false` [VERIFIED: module scan]
└── mix/tasks/                   # public operator entrypoints; keep visible [VERIFIED: module scan]

guides/
├── getting_started.md           # facade-first onboarding after Phase 17 [VERIFIED: guides/getting_started.md]
├── operations.md                # public operational story via mix tasks [VERIFIED: guides/operations.md]
└── core_concepts.md             # reference data types and lifecycle explanation [VERIFIED: guides/core_concepts.md]

test/
├── install_smoke/               # docs parity and published-surface tests [VERIFIED: test/install_smoke/docs_parity_test.exs]
└── rindle/                      # targeted facade, broker, LiveView, and config tests [VERIFIED: test/rindle/live_view_test.exs][VERIFIED: test/rindle/upload/broker_test.exs]
```

### Pattern 1: Public Surface Manifest Audit
**What:** Generate a manifest of visible modules/functions from compiled docs and compare it to the locked public/internal lists before changing any docs prose [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md][VERIFIED: mix run Code.fetch_docs audit].
**When to use:** At the start of Phase 17 and again as the phase gate before Phase 18 [VERIFIED: .planning/ROADMAP.md].
**Example:**
```elixir
# Source: https://hexdocs.pm/elixir/writing-documentation.html
Code.fetch_docs(Rindle)
```

### Pattern 2: Hidden Internal Module, Thin Public Shim
**What:** Move true implementation helpers into a hidden module and leave only a narrow compatibility wrapper on a public module when semver requires it [CITED: https://hexdocs.pm/elixir/writing-documentation.html][VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md].
**When to use:** `log_variant_processing_failure/3` and any future `0.1.x` compatibility helper that must remain callable but should stop being documented [VERIFIED: lib/rindle.ex].
**Example:**
```elixir
# Source: https://hexdocs.pm/elixir/writing-documentation.html
defmodule MyApp.Hidden do
  @moduledoc false
end
```

### Pattern 3: Facade-First Alias With Legacy Verb Preserved
**What:** Introduce the preferred facade name additively and delegate the legacy name to it until the next breaking line [VERIFIED: lib/rindle.ex][VERIFIED: lib/rindle/upload/broker.ex][VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md].
**When to use:** `Rindle.verify_completion/2` and `Rindle.verify_upload/2` in `0.1.x` [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md].
**Example:**
```elixir
# Source: repo pattern derived from lib/rindle.ex + locked context
def verify_completion(session_id, opts \\ []), do: Broker.verify_completion(session_id, opts)
def verify_upload(session_id, opts \\ []), do: verify_completion(session_id, opts)
```

### Likely Repo Touchpoints

- `mix.exs` needs `groups_for_modules` and likely `source_ref: "v#{@version}"` alignment if docs should link to tagged source cleanly [VERIFIED: mix.exs][CITED: https://hexdocs.pm/ex_doc/ExDoc.html].
- `lib/rindle.ex` is the main compatibility surface for `verify_completion/2`, legacy `verify_upload/2`, and hiding `log_variant_processing_failure/3` [VERIFIED: lib/rindle.ex].
- `lib/rindle/live_view.ex` still documents and calls `Rindle.verify_upload/1`, so it must be aligned with the new preferred name or explicitly documented as using the legacy shim [VERIFIED: lib/rindle/live_view.ex].
- Internal modules named in D-05 and D-06 need `@moduledoc false`, especially `Rindle.Config`, `Rindle.Ops.*`, `Rindle.Security.*`, FSM modules, internal workers, and profile helpers [VERIFIED: module scan][VERIFIED: codebase grep].
- `README.md` and `guides/getting_started.md` currently teach broker-first direct upload, and existing docs parity tests assert that broker-first wording today, so those tests will need Phase 17 updates as the onboarding story changes [VERIFIED: README.md][VERIFIED: guides/getting_started.md][VERIFIED: test/install_smoke/docs_parity_test.exs].

### Anti-Patterns to Avoid
- **Docs-first before boundary-first:** Adding broad `@doc` coverage before hiding internals will turn accidental modules into harder-to-retract API promises [CITED: https://hexdocs.pm/elixir/writing-documentation.html][VERIFIED: .planning/ROADMAP.md].
- **Regex-only public API audit:** Grepping `def` lines cannot tell you what compiled docs and HexDocs actually expose [CITED: https://hexdocs.pm/elixir/writing-documentation.html].
- **Using `@doc false` as a privacy mechanism:** Elixir explicitly states hidden docs do not make a function private [CITED: https://hexdocs.pm/elixir/writing-documentation.html].
- **Breaking rename on `0.1.x`:** The package is already published as `0.1.4`, so planner tasks should not remove or rename public functions in place on this line [CITED: https://hex.pm/packages/rindle][VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md].

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Public API visibility audit | Custom parser for module docs and function exports | `Code.fetch_docs/1` plus `mix docs` output | Elixir already stores docs in BEAM chunks and ExDoc already decides published visibility from those docs [CITED: https://hexdocs.pm/elixir/writing-documentation.html][CITED: https://hexdocs.pm/ex_doc/ExDoc.html] |
| Sidebar information architecture | Hand-edited HTML docs navigation | ExDoc `groups_for_modules` | ExDoc already supports ordered module grouping for API references [CITED: https://hexdocs.pm/ex_doc/ExDoc.html] |
| Compatibility migration policy | Ad hoc comments in code only | Explicit semver decision artifact in the phase directory | Phase 18 needs a stable contract record, not scattered rationale across source files [VERIFIED: .planning/ROADMAP.md][VERIFIED: .planning/REQUIREMENTS.md] |
| Public-surface verification | Manual eyeballing of HexDocs after each change | ExUnit smoke tests plus docs build | The repo already has docs parity tests and `mix docs --warnings-as-errors` expectations [VERIFIED: test/install_smoke/docs_parity_test.exs][VERIFIED: test/install_smoke/package_metadata_test.exs] |

**Key insight:** This phase should use the language and doc generator as the contract system instead of layering a separate custom API-boundary mechanism on top [CITED: https://hexdocs.pm/elixir/writing-documentation.html][CITED: https://hexdocs.pm/ex_doc/ExDoc.html].

## Common Pitfalls

### Pitfall 1: Hiding an intended extension seam
**What goes wrong:** A module that adopters are supposed to call directly gets hidden because it "looks internal" in the tree [VERIFIED: module scan][VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md].
**Why it happens:** The repo currently exposes almost everything, while the locked boundary is selective and layered rather than namespace-wide [CITED: https://hexdocs.pm/rindle/api-reference.html][VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md].
**How to avoid:** Start from the locked public allowlist in D-03/D-04 and treat everything else as deny-by-default only after explicit comparison to that allowlist [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md].
**Warning signs:** Proposed hide list includes `Rindle.Storage.Local`, `Rindle.Storage.S3`, or any `Mix.Tasks.Rindle.*` module even though the context keeps them public [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md][VERIFIED: .planning/ROADMAP.md].

### Pitfall 2: Updating the facade name but missing secondary teaching surfaces
**What goes wrong:** `Rindle.verify_completion/2` exists, but LiveView docs, README snippets, and parity tests still teach `verify_upload/2` or broker-first calls [VERIFIED: lib/rindle/live_view.ex][VERIFIED: README.md][VERIFIED: guides/getting_started.md][VERIFIED: test/install_smoke/docs_parity_test.exs].
**Why it happens:** The canonical workflow is duplicated across top-level docs, tests, and optional integrations [VERIFIED: README.md][VERIFIED: guides/getting_started.md][VERIFIED: test/install_smoke/docs_parity_test.exs].
**How to avoid:** Bundle facade alias, docs edits, and parity test changes into the same wave rather than treating naming cleanup as source-only work [VERIFIED: test/install_smoke/docs_parity_test.exs].
**Warning signs:** The code exports `verify_completion/2` but `mix docs` and README examples still show only broker verification or the legacy facade name [VERIFIED: lib/rindle.ex][VERIFIED: mix docs output].

### Pitfall 3: Thinking hidden docs equal private API
**What goes wrong:** Internal helpers are hidden in ExDoc, but callers still rely on them because they remain exported and easy to import/call [CITED: https://hexdocs.pm/elixir/writing-documentation.html].
**Why it happens:** `@moduledoc false` and `@doc false` affect documentation, not visibility at runtime [CITED: https://hexdocs.pm/elixir/writing-documentation.html].
**How to avoid:** For true implementation helpers, move logic into hidden modules and minimize public shim bodies so Phase 18 does not accidentally document them later [CITED: https://hexdocs.pm/elixir/writing-documentation.html][VERIFIED: lib/rindle.ex].
**Warning signs:** A public module has multiple undocumented helper functions or the shim contains substantive business logic instead of a narrow delegate/log wrapper [VERIFIED: lib/rindle.ex].

### Pitfall 4: Treating requirement text as authoritative when it conflicts with locked context
**What goes wrong:** Planning hides `Rindle.Storage.Local` and `Rindle.Storage.S3` because `API-04` wording mentions them, even though D-03 explicitly keeps them public [VERIFIED: .planning/REQUIREMENTS.md][VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md].
**Why it happens:** The roadmap and requirements contain older generic wording, while the discuss-phase context locked the actual boundary after deeper review [VERIFIED: .planning/ROADMAP.md][VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md].
**How to avoid:** Treat `17-CONTEXT.md` as the authoritative boundary list and add a requirement-reconciliation note as a phase artifact [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md].
**Warning signs:** Planner tasks mention hiding public storage adapters or public mix tasks without an explicit override decision [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md].

## Code Examples

Verified patterns from official sources:

### Hide an internal module
```elixir
# Source: https://hexdocs.pm/elixir/writing-documentation.html
defmodule MyApp.Hidden do
  @moduledoc false
end
```

### Mark a public function as deprecated in docs
```elixir
# Source: https://hexdocs.pm/elixir/writing-documentation.html
@doc deprecated: "Use Foo.bar/2 instead"
def foo(arg), do: Foo.bar(arg, [])
```

### Group public modules in ExDoc
```elixir
# Source: https://hexdocs.pm/ex_doc/ExDoc.html
groups_for_modules: [
  "Data types": [Atom, Regex, URI],
  "Collections": [Enum, MapSet, Stream]
]
```

### Read compiled docs metadata
```elixir
# Source: https://hexdocs.pm/elixir/writing-documentation.html
Code.fetch_docs(Rindle)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Treat visible namespace as de facto public | Treat docs visibility as an intentional API contract and hide internals explicitly | Current Elixir/ExDoc guidance in Elixir 1.19.5 / ExDoc 0.40.1 [CITED: https://hexdocs.pm/elixir/writing-documentation.html][CITED: https://hexdocs.pm/ex_doc/ExDoc.html] | Phase 17 should shrink the published surface before Phase 18 adds more documentation weight |
| Docs-only navigation by namespace order | Docs navigation grouped by user-facing role with `groups_for_modules` | Supported in ExDoc 0.40.1 [CITED: https://hexdocs.pm/ex_doc/ExDoc.html] | The planner should schedule `mix.exs` IA work, not only source-module hiding |
| Rename published API in place | Additive alias + compatibility shim on live minor line; remove later on breaking line | Required by locked `0.1.x` posture after publishing `0.1.4` [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md][CITED: https://hex.pm/packages/rindle] | `verify_completion/2` can ship now, but `verify_upload/2` removal cannot |

**Deprecated/outdated:**
- Namespace-wide "everything documented is public" as a passive side effect of existing `@moduledoc` blocks is outdated for this phase because the boundary is now explicitly locked and narrower than the current API reference [CITED: https://hexdocs.pm/rindle/api-reference.html][VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md].

## Assumptions Log

All substantive claims in this research were verified against official docs, the live codebase, or the live published package/docs. No user confirmation is required before planning on accuracy grounds [VERIFIED: research evidence in this file].

## Resolved Questions

1. **Requirement wording vs locked boundary for storage adapters — RESOLVED**
   - Resolution: Treat D-03 as authoritative. `Rindle.Storage.Local` and `Rindle.Storage.S3` remain intentionally public, and Phase 17 must record that override in a dedicated artifact: `.planning/phases/17-api-surface-boundary-audit/17-BREAKING-CHANGE-DECISION.md` [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md][VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-04-PLAN.md].
   - Planning consequence: Boundary tests and ExDoc grouping should positively assert those adapters remain visible, while the decision artifact makes the older roadmap/requirements wording non-ambiguous for Phase 18 [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-02-PLAN.md][VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-04-PLAN.md].

2. **Whether `verify_upload/2` should emit compiler warnings or docs-only deprecation — RESOLVED**
   - Resolution: Use docs-only deprecation on `0.1.x` with `@doc deprecated: "Use verify_completion/2"` on the legacy shim, and do not use the warning-emitting `@deprecated` attribute in Phase 17 [CITED: https://hexdocs.pm/elixir/writing-documentation.html][VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-04-PLAN.md].
   - Planning consequence: Executors should preserve compatibility without introducing new compiler-warning noise for existing adopters; any harder warning/removal remains deferred to `v0.2.0+` [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md][VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-04-PLAN.md].

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Source audit, `Code.fetch_docs/1`, test runs | ✓ [VERIFIED: `elixir --version`] | 1.19.5 [VERIFIED: `elixir --version`] | — |
| Mix | `mix docs`, `mix test`, `mix xref` | ✓ [VERIFIED: `mix --version`] | 1.19.5 [VERIFIED: `mix --version`] | — |
| ExDoc | Generated API reference verification | ✓ via project dependency [VERIFIED: mix.lock][VERIFIED: `mix docs` run] | 0.40.1 [VERIFIED: mix.lock] | — |

**Missing dependencies with no fallback:** None [VERIFIED: environment audit].

**Missing dependencies with fallback:** None [VERIFIED: environment audit].

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit on Elixir 1.19.5 [VERIFIED: test/test_helper.exs][VERIFIED: `elixir --version`] |
| Config file | `test/test_helper.exs` [VERIFIED: test/test_helper.exs] |
| Quick run command | `mix test test/rindle_test.exs test/rindle/live_view_test.exs test/install_smoke/docs_parity_test.exs -x` [VERIFIED: test file presence] |
| Full suite command | `mix test` [VERIFIED: Mix project conventions][VERIFIED: test tree] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| API-01 | `Rindle.verify_completion/2` exists and legacy `verify_upload/2` still works | unit | `mix test test/rindle/api_surface_boundary_test.exs test/rindle/live_view_test.exs -x` [VERIFIED: target files] | ✅ addressed by Plan 17-01 Wave 0 harness [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-01-PLAN.md] |
| API-02 | `log_variant_processing_failure/3` is hidden from docs but remains callable during `0.1.x` | unit + docs build | `mix docs --warnings-as-errors && mix test test/rindle/api_surface_boundary_test.exs -x` [VERIFIED: existing docs command usage] | ✅ addressed by Plan 17-01 Wave 0 harness [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-01-PLAN.md] |
| API-03 | README, getting-started, and optional integrations teach consistent public names | smoke | `mix test test/install_smoke/docs_parity_test.exs -x` [VERIFIED: existing test] | ✅ existing parity harness, but assertions must change [VERIFIED: test/install_smoke/docs_parity_test.exs] |
| API-04 | Hidden modules do not appear in generated docs | smoke | `mix docs --warnings-as-errors` plus new ExUnit assertion over generated output [VERIFIED: existing docs command usage] | ✅ addressed by Plan 17-01 Wave 0 harness [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-01-PLAN.md] |
| API-05 | Breaking-change decision exists and is explicit about `0.1.x` vs `v0.2.0` | manual + artifact | `rg -n "0\\.1\\.x|v0\\.2\\.0|verify_upload/2|verify_completion/2" .planning/phases/17-api-surface-boundary-audit/17-BREAKING-CHANGE-DECISION.md` [VERIFIED: command pattern fits planned artifact] | ✅ handled in Plan 17-04 as an end-of-phase artifact, not Wave 0 [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-04-PLAN.md] |

### Sampling Rate
- **Per task commit:** `mix test test/rindle_test.exs test/rindle/live_view_test.exs test/install_smoke/docs_parity_test.exs -x` [VERIFIED: test tree]
- **Per wave merge:** `mix docs --warnings-as-errors && mix test` [VERIFIED: test/install_smoke/package_metadata_test.exs][VERIFIED: test tree]
- **Phase gate:** Full suite green and generated docs confirm the locked allowlist/denylist [VERIFIED: phase goal + docs tooling]

### Wave 0 Gaps
- [x] `test/rindle/api_surface_boundary_test.exs` — consolidated Wave 0 boundary harness replacing the hypothetical split files above; covers hidden/public module visibility, facade aliasing, and compatibility-shim expectations [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-01-PLAN.md].
- [x] `test/install_smoke/docs_parity_test.exs` updates — Plan 17-01 converts the existing parity harness from broker-first to facade-first onboarding assertions [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-01-PLAN.md].
- [x] API-05 is intentionally closed outside Wave 0 by the planned artifact `.planning/phases/17-api-surface-boundary-audit/17-BREAKING-CHANGE-DECISION.md` in Plan 17-04 [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-04-PLAN.md].

## Security Domain

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no [VERIFIED: codebase has no user-auth subsystem in phase scope] | — |
| V3 Session Management | no [VERIFIED: codebase scope is media upload sessions, not user session management] | — |
| V4 Access Control | yes [VERIFIED: lib/rindle/delivery.ex][VERIFIED: lib/rindle/authorizer.ex] | `Rindle.Authorizer` and delivery policy gating [VERIFIED: lib/rindle/delivery.ex] |
| V5 Input Validation | yes [VERIFIED: lib/rindle/security/upload_validation.ex][VERIFIED: lib/rindle/profile/validator.ex] | `Rindle.Security.UploadValidation` and `Rindle.Profile.Validator` [VERIFIED: codebase grep] |
| V6 Cryptography | yes [VERIFIED: lib/rindle/profile/digest.ex][VERIFIED: lib/rindle/storage/s3.ex] | `:crypto.hash` for recipe digests and signed URL support via storage adapters [VERIFIED: codebase grep] |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Accidental publication of internal operational/security helpers | Information Disclosure | Hide internal modules with `@moduledoc false` and verify generated docs output [CITED: https://hexdocs.pm/elixir/writing-documentation.html][VERIFIED: mix docs output] |
| Adopters bypassing intended delivery authorization path | Elevation of Privilege | Keep public delivery surface on `Rindle.Delivery` and `Rindle.Authorizer`; do not promote `Rindle.Ops.*` or security helpers as supported API [VERIFIED: lib/rindle/delivery.ex][VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md] |
| Client completing upload without server verification | Tampering | Preserve `verify_completion/2` as the canonical verified boundary and keep upload verification explicit in docs [VERIFIED: lib/rindle/upload/broker.ex][VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md] |
| Public helper encouraging log-driven rather than telemetry-driven observability | Repudiation / Operational ambiguity | Hide `log_variant_processing_failure/3` from docs and keep telemetry as the adopter-facing observability contract [VERIFIED: lib/rindle.ex][VERIFIED: guides/background_processing.md][VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md] |

## Sources

### Primary (HIGH confidence)
- `.planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md` - locked public/internal boundary, semver posture, and docs IA decisions [VERIFIED: local file]
- `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, `.planning/PROJECT.md` - requirement mapping and milestone constraints [VERIFIED: local files]
- `mix.exs`, `mix.lock`, `lib/**/*.ex`, `README.md`, `guides/*.md`, `test/**/*.exs` - current implementation and verification surface [VERIFIED: codebase grep]
- https://hexdocs.pm/elixir/writing-documentation.html - hiding internal modules/functions, docs metadata, `Code.fetch_docs/1` [CITED: https://hexdocs.pm/elixir/writing-documentation.html]
- https://hexdocs.pm/ex_doc/ExDoc.html - `groups_for_modules`, `filter_modules`, and docs generation behavior [CITED: https://hexdocs.pm/ex_doc/ExDoc.html]
- https://hexdocs.pm/elixir/compatibility-and-deprecations.html - compatibility and soft/hard deprecation framing [CITED: https://hexdocs.pm/elixir/compatibility-and-deprecations.html]
- https://hexdocs.pm/rindle/api-reference.html and https://hexdocs.pm/rindle/Rindle.html - current live published surface and facade docs [CITED: https://hexdocs.pm/rindle/api-reference.html][CITED: https://hexdocs.pm/rindle/Rindle.html]
- https://hex.pm/packages/rindle - published package version `0.1.4` and publication date [CITED: https://hex.pm/packages/rindle]

### Secondary (MEDIUM confidence)
- None.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - The phase uses the existing language/runtime/doc tooling already present in the repo and verified locally [VERIFIED: mix.exs][VERIFIED: mix.lock][VERIFIED: environment audit].
- Architecture: HIGH - The locked context is explicit, and the current accidental surface is directly observable in code and live docs [VERIFIED: .planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md][CITED: https://hexdocs.pm/rindle/api-reference.html].
- Pitfalls: HIGH - The main risks are concrete mismatches already visible in source, docs, and tests [VERIFIED: README.md][VERIFIED: lib/rindle/live_view.ex][VERIFIED: test/install_smoke/docs_parity_test.exs].

**Research date:** 2026-04-30
**Valid until:** 2026-05-30
