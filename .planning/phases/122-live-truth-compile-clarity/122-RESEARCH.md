# Phase 122: Live Truth & Compile Clarity - Research

**Researched:** 2026-08-22
**Domain:** Behavior-preserving Elixir/Ecto schema-macro refactor and shipped-documentation reconciliation
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### The agent's Discretion
- Treat `lib/`, `test/`, current guides, root docs, scripts, and active workflows as live truth; leave
  `.planning/milestones/**` and other historical planning archives unchanged.
- Rewrite only comments or assertions that are obsolete, forward-looking, or coupled to a Phase/Plan;
  preserve useful rationale by expressing the domain invariant directly.
- Reconcile CI lane names/severity, supported toolchain posture, Admin navigation labels, and shipped tus
  and streaming behavior against executable code and workflow truth.
- Break the schema cycle at the internal caller-allowlist dependency while retaining the macro boundary,
  supported prefixes, compile-time validation, exception semantics, compiled schema metadata, and struct
  metadata.
- Add objective regression proof for zero compile cycles and extend current parity/SAFE-01 contracts rather
  than adding brittle source-string snapshots of incidental implementation.

### the agent's Discretion

### Deferred Ideas (OUT OF SCOPE)

Runtime-operations decomposition belongs to Phase 123, upload-path decomposition to Phase 124, test-support
rearchitecture and async issue #42 to Phase 125, and Dialyzer retirement to Phase 126. Broad style churn,
dependency upgrades, Admin feature redesign, and historical archive normalization remain out of scope.
</user_constraints>

## Summary

Phase 122 is a deliberately narrow maintenance slice. It should repair only live source, tests, and adopter/maintainer guides whose prose still describes already-shipped work as future work, then remove the one measured `Rindle.Schema` compile-connected component. Historical planning archives under `.planning/milestones/` are evidence, not implementation inputs, and must remain untouched. [VERIFIED: `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `AGENTS.md`]

The current project compiles successfully, but `MIX_ENV=test mix xref graph --format cycles --label compile-connected --fail-above 0` reports one seven-file strongly connected component: `lib/rindle/schema.ex` and the six `Rindle.Domain.Media*` schemas. Each schema has compile-time calls to `Rindle.Schema.__using__/1`, `schema/2`, and `__after_compile__/2`; `Rindle.Schema` closes the component by retaining those six domain-module aliases in its internal caller allowlist. Replace that allowlist representation with non-module-reference identities (such as canonical module-name strings), while leaving `Rindle.Schema` as the sole macro, after-compile, and prefix authority. This preserves the active rejection guard, exception behavior, and each schema's compiled metadata while removing the reverse dependency. [VERIFIED: `mix xref graph --format cycles --label compile-connected --fail-above 0`; `mix xref trace lib/rindle/domain/media_asset.ex --label compile`; `lib/rindle/schema.ex`; `.planning/phases/122-live-truth-compile-clarity/122-CONTEXT.md`; [Mix xref docs](https://hexdocs.pm/mix/Mix.Tasks.Xref.html)]

The live truth pass has concrete, finite targets. The Admin design-system guide still names six retired labels (`Home/Status`, `Variants/Jobs`, `Runtime/Doctor`, `Actions`) while the rendered component and its primary behavior tests use `Overview`, `Assets`, `Upload sessions`, `Processing`, `Doctor`, and `Maintenance`. The storage-capabilities guide says Rindle does not ship tus, although `Rindle.Upload.TusPlug`, its guide, and the shipped `:tus_upload` capability prove otherwise. Several implementation/test comments retain stale Phase/Plan/EXPECTED-RED language even though the behavior is now live. [VERIFIED: `guides/admin_design_system.md`; `lib/rindle/admin/components.ex`; `test/brandbook/admin_design_system_validation_test.exs`; `guides/storage_capabilities.md`; `guides/resumable_uploads.md`; `test/rindle/upload/tus_plug_test.exs`; `test/rindle/storage/s3_tus_test.exs`]

**Primary recommendation:** execute three focused plans: reconcile the finite live commentary/docs inventory with behavior-backed parity locks; replace only the internal schema owner-allowlist representation; then run the Phase 121 SAFE-01 suite plus focused schema/docs/xref evidence.

## Exact Live-Truth Inventory

| Surface | Current contradiction / obsolete narration | Bounded repair |
|---|---|---|
| `guides/admin_design_system.md`, `guides/admin_console_ia.md` | They call legacy labels the navigation contract; the live component renders `Overview`, `Assets`, `Upload sessions`, `Processing`, `Doctor`, and `Maintenance`. | Update label lists and task descriptions to the rendered labels only; keep route suffixes unchanged. [VERIFIED: `lib/rindle/admin/components.ex`; `test/rindle/admin/live/home_assets_upload_test.exs`; `test/brandbook/admin_design_system_validation_test.exs`] |
| `guides/storage_capabilities.md`, `guides/profiles.md` | They say the resumable boundary is GCS-only, describe a reserved future vocabulary, and deny a shipped tus abstraction, while Local/S3 expose `:tus_upload` and `Rindle.Upload.TusPlug` is shipped. | Distinguish server-mediated tus on Local/S3 from GCS provider-direct resumability; preserve no-fallback and adapter-specific boundary claims. [VERIFIED: `lib/rindle/storage/local.ex`; `lib/rindle/storage/s3.ex`; `lib/rindle/upload/tus_plug.ex`; `guides/resumable_uploads.md`] |
| `guides/admin_console.md` | Intro says the console is the only new public surface "in this milestone" and presents the old action-hub vocabulary. | State the durable host-authenticated mount boundary and current task-first labels, without changing routes or Admin features. [VERIFIED: `guides/admin_console.md`; `lib/rindle/admin/components.ex`] |
| `lib/rindle/capability.ex`, `lib/rindle/streaming/provider/mux.ex`, `lib/rindle/streaming/provider/mux/event.ex`, `lib/rindle/profile/validator.ex`, `lib/rindle/workers/mux_sync_coordinator.ex` | Comments describe Phases 33–36 and future webhook/capacity work as if unshipped. | Replace only stale delivery chronology with current capability, webhook-normalization, preset, and polling invariants. [VERIFIED: cited live files] |
| `test/rindle/upload/tus_plug_test.exs`, `test/rindle/storage/s3_tus_test.exs`, `test/rindle/storage/storage_adapter_test.exs`, `test/rindle/ops/upload_maintenance_test.exs` | Explicit `EXPECTED RED`/Plan comments describe code paths that current assertions execute successfully. | Rewrite comments/describes around observable adapter dispatch, S3 tail buffering, truthful capability advertising, and tus expiry routing. [VERIFIED: cited tests] |
| `lib/rindle/delivery.ex` | The module introduction says a "future streaming provider" serves bytes although Mux streaming is shipped. | Describe redirect-oriented Rindle delivery and configured streaming providers in present tense. [VERIFIED: `lib/rindle/delivery.ex`; `guides/streaming_providers.md`] |

Do not make a blanket Phase-token ban. Keep immutable snapshot provenance and active safety rationale, including `test/rindle/backward_compat/v13_digest_snapshot_test.exs`, and exclude `.planning/**`, `CHANGELOG.md`, fixtures, generated/vendor files, and current complexity inventory from any cleanup guard. [VERIFIED: `.planning/phases/122-live-truth-compile-clarity/122-CONTEXT.md`; `test/rindle/backward_compat/v13_digest_snapshot_test.exs`]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Prefix selection and schema declaration | API / Backend | Database / Storage | `Rindle.Schema` compiles the selected Rindle prefix into each Ecto schema; Ecto consumes that metadata for SQL qualification. |
| Post-compilation prefix tamper detection | API / Backend | — | The macro-installed callback validates compiled schema metadata before the schema is accepted. |
| Schema ownership compatibility | API / Backend | Database / Storage | The six owned schemas, table sources, binary IDs, and `rindle`/`public` prefix are public behavior locked by tests and migrations. |
| Maintainer/adopter truth | Documentation | API / Backend | Guides explain the implemented CI, Admin, tus, and streaming behavior; code/tests are the authority they must match. |
| CI lane explanation | CI / Release | API / Backend | `ci.yml` and `RUNNING.md` describe the merge gate and release-train behavior; Phase 122 must not change its topology. |

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| CLARITY-01 | Current source/tests use domain rationale instead of obsolete Phase/Plan/EXPECTED-RED commentary; archives remain untouched. | Finite stale-comment inventory and non-archive-only search boundary below. |
| CLARITY-02 | Current docs state implemented CI, support, Admin labels, tus, and streaming without stale forward claims. | Live Admin-label and tus-capability contradictions, existing docs parity suites, and CI documentation sources below. |
| CLARITY-03 | No `Rindle.Schema` seven-module compile cycle; public ownership/prefix behavior unchanged. | Reproducible `mix xref` baseline, caller-allowlist decoupling pattern, and existing byte-level behavior tests below. |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Keep edits focused and run the checks named by `RUNNING.md` for the change.
- Preserve green `main` merge-blocking CI: Quality/coveralls, Integration, Proof, Package Consumer, and Adopter.
- Use a PR-first workflow for serious milestone work and do not alter the release train speculatively.
- Do not alter the single required `CI Summary` topology, release gate, workflow name, or supported release behavior.
- Update `.planning/PROJECT.md` only for intentional product-scope or shipped-claim changes; this phase is behavior-preserving and should not change it.
- Historical milestone content is retained in `.planning/milestones/`; this phase's requirement additionally locks it as immutable.
- UI/admin redesign is out of scope; only documentation/tests may be reconciled to the existing rendered labels.

## Standard Stack

### Core

| Library / tool | Version observed | Purpose | Why standard here |
|---|---:|---|---|
| Elixir / Mix | 1.19.5 | Compiler, `mix compile`, and `mix xref` graphing | Existing project toolchain; Mix documents `xref` cycle detection. [VERIFIED: local `elixir --version`; [Mix xref docs](https://hexdocs.pm/mix/Mix.Tasks.Xref.html)] |
| Ecto.Schema | existing locked dependency | Schema DSL and compiled source/prefix metadata | Current six domain schemas already use it through the Rindle macro. [VERIFIED: `lib/rindle/schema.ex`; six domain schema modules] |
| ExUnit | existing Elixir standard library | Prefix, source, docs, and contract regression evidence | Existing suite owns all relevant contract tests. [VERIFIED: `test/rindle/schema_prefix_contract_test.exs`; `test/install_smoke/docs_parity_test.exs`] |

### Supporting

| Tool | Purpose | When to use |
|---|---|---|
| `mix xref graph --format cycles --label compile-connected --fail-above 0` | Exact compile-cycle detector | Before and after the allowlist decoupling; fail if any compile-connected cycle remains. [CITED: https://hexdocs.pm/mix/Mix.Tasks.Xref.html] |
| `mix xref trace <file> --label compile` | Attribute compile edges to macro calls | Diagnose only if the representation change leaves a compile-connected component. [CITED: https://hexdocs.pm/mix/Mix.Tasks.Xref.html] |
| `scripts/maintainer/refactor_contract.sh` | SAFE-01 aggregate preservation gate | After every schema/doc slice and at phase gate. [VERIFIED: `.planning/phases/121-truthful-quality-signals-mechanical-hygiene/121-VERIFICATION.md`] |

### Alternatives Considered

| Instead of | Could use | Tradeoff |
|---|---|---|
| Replace only module aliases in caller allowlist | Remove `@after_compile` validation | Rejected: it weakens the existing raw-Ecto/callback-deletion protection and violates SAFE-01. [VERIFIED: `test/rindle/schema_prefix_contract_test.exs`] |
| Replace only module aliases in caller allowlist | Make each schema declare prefix/Ecto fields directly | Rejected: duplicates the single ownership authority and contradicts the schema-prefix contract test. [VERIFIED: `test/rindle/schema_prefix_contract_test.exs`] |
| Behavior-based docs parity | Broad rewrite of guides/comments | Rejected: phase is a finite truth repair, not a style/rewording initiative. [VERIFIED: `.planning/ROADMAP.md`; `.planning/STATE.md`] |

**Installation:** None. This phase adds no dependency and must not modify `mix.exs` / `mix.lock`.

## Package Legitimacy Audit

No external package is installed or upgraded in this phase; package legitimacy checks are not applicable. [VERIFIED: phase scope in `.planning/ROADMAP.md`]

## Architecture Patterns

### System Architecture Diagram

```text
compile configuration (:rindle_prefix)
                 |
                 v
        Rindle.Schema macro authority
          |                 |
          | macro expansion | string/segment allowlist comparison
          v                 v
six Rindle.Domain schemas --- `@after_compile Rindle.Schema`
          |                 |
          | compiled metadata | compares expected and actual prefix
          v                 v
   Ecto query/schema use      ArgumentError on a tampered declaration

code/tests/docs -> behavior-backed parity tests -> CI / SAFE-01 evidence
```

### Recommended Project Structure

```text
lib/rindle/
└── schema.ex                 # Existing sole macro/prefix/callback authority; string identity allowlist

test/rindle/
├── schema_prefix_contract_test.exs  # Existing ownership/tamper/prefix behavior
└── schema_compile_cycle_test.exs    # New xref regression proof, if process invocation is viable
```

### Pattern 1: Make the internal caller allowlist data, not module references

**What:** retain `use Rindle.Schema`, `Rindle.Schema.schema/2`, the compile-time prefix attribute, and the existing `@after_compile Rindle.Schema` callback. Replace only the six domain aliases in `@owned_schema_modules` with canonical non-module-reference identities, then compare the caller's module name to that closed set.

**When to use:** a macro must admit a closed set of consumers, but directly naming those consumers makes a reverse dependency that joins the macro's compile-time users into a compile-connected component.

**Example:**

```elixir
# lib/rindle/schema.ex
@owned_schema_modules [
  "Elixir.Rindle.Domain.MediaAsset",
  "Elixir.Rindle.Domain.MediaAttachment",
  "Elixir.Rindle.Domain.MediaProcessingRun",
  "Elixir.Rindle.Domain.MediaProviderAsset",
  "Elixir.Rindle.Domain.MediaUploadSession",
  "Elixir.Rindle.Domain.MediaVariant"
]

defp validate_owned_schema!(module) when is_atom(module) do
  if Atom.to_string(module) in @owned_schema_modules do
    :ok
  else
    raise ArgumentError,
          "Rindle.Schema is internal to Rindle-owned domain schemas; unsupported caller #{inspect(module)}"
  end
end
```

This preserves macro expansion and callback execution exactly while removing only `Rindle.Schema`'s direct module references to its consumers. Verify the actual post-change graph rather than assuming this representation is sufficient. [VERIFIED: existing callback/allowlist implementation in `lib/rindle/schema.ex`; `.planning/phases/122-live-truth-compile-clarity/122-CONTEXT.md`; [Mix xref docs](https://hexdocs.pm/mix/Mix.Tasks.Xref.html)]

### Pattern 2: Reconcile prose from implementation-first evidence

**What:** name current, observable behavior without milestone/plan chronology. For example, say that the six Admin surfaces are `Overview`, `Assets`, `Upload sessions`, `Processing`, `Doctor`, and `Maintenance`; say tus is a shipped plug protocol with its documented adapter-specific requirements.

**When to use:** implementation and tests are stable but a guide or comment is still written as a future plan.

**Example:** update a stale `EXPECTED RED until Plan 02` test/module comment to explain the currently asserted adapter dispatch or capability contract. Keep historical commit history and `.planning/milestones/` unchanged. [VERIFIED: stale examples in `test/rindle/upload/tus_plug_test.exs`, `test/rindle/storage/s3_tus_test.exs`, `test/rindle/storage/storage_adapter_test.exs`]

### Anti-patterns to Avoid

- **Removing the after-compile callback:** loses the active guard that rejects external raw-Ecto declarations after callback deletion.
- **Moving prefix configuration into runtime `Application.get_env/3`:** changes the documented/verified compile-time prefix ownership contract.
- **Copying current component labels into route slugs or module names:** the labels alone are the docs-truth repair; route suffixes and `active` keys remain behavior contracts.
- **Replacing all historical references mechanically:** some comments record durable safety rationale or an intentional immutable snapshot. Only rewrite proven-obsolete planning narration in live source/tests.
- **Changing CI jobs while correcting CI prose:** CI topology is a SAFE-01/release-train invariant.

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---|---|---|---|
| Compile-cycle detection | Custom dependency parser or source grep | `mix xref graph --format cycles --label compile-connected` | Mix has the compiler's dependency graph and reports strongly connected components. [CITED: https://hexdocs.pm/mix/Mix.Tasks.Xref.html] |
| Prefix behavior snapshot | New ad-hoc schema fixture/migration | Existing schema prefix, config, migration, and SAFE-01 contract suites | Existing tests already prove sources, IDs, metadata prefix, public/private compatibility, and migration behavior. [VERIFIED: `test/rindle/schema_prefix_contract_test.exs`; `test/rindle/domain/media_schema_test.exs`; `scripts/maintainer/refactor_contract.sh`] |
| Documentation authority | New external docs registry | Existing guides plus their focused parity tests | The project already maintains shipped documentation as testable artifacts. [VERIFIED: `test/install_smoke/docs_parity_test.exs`; `test/install_smoke/phoenix_tus_truth_parity_test.exs`; `test/install_smoke/streaming_cancel_docs_parity_test.exs`] |

## Runtime State Inventory

| Category | Items Found | Action Required |
|---|---|---|
| Stored data | None. The change alters only the internal caller-allowlist representation; domain table names, migration modules, and Ecto schema sources are not to change. [VERIFIED: `lib/rindle/schema.ex`; `test/rindle/domain/media_schema_test.exs`] | No data migration. Preserve existing schema/migration tests. |
| Live service config | `:rindle_prefix` remains a compile-time configuration value with supported `"rindle"` / `"public"` values; this phase must not modify live config. [VERIFIED: `lib/rindle/schema.ex`; `guides/getting_started.md`] | Code edit only; compile both supported configuration shapes through existing probes/contracts. |
| OS-registered state | None found in phase-owned schema/docs surfaces; no service registration or task name changes are proposed. [VERIFIED: phase scope; `RUNNING.md`] | None. |
| Secrets/env vars | None are renamed or re-keyed. Existing tus/streaming docs may describe secret wiring, but the phase must only correct factual prose. [VERIFIED: `guides/resumable_uploads.md`; `guides/streaming_providers.md`] | None. Do not expose or alter secrets. |
| Build artifacts | `_build/` compilation manifests/xref reports are regenerated locally and are not source-of-truth artifacts. [VERIFIED: `.gitignore`; local `mix compile --force`] | Regenerate with compile/xref checks; do not commit build artifacts. |

## Common Pitfalls

### Pitfall 1: Treating a clean compile as absence of a compile cycle

**What goes wrong:** `mix compile --force` succeeds, so a refactor is declared done while the seven-node compile-connected component remains.

**Why it happens:** the issue is recompilation coupling, not a compiler failure.

**How to avoid:** make the exact `mix xref graph --format cycles --label compile-connected` output a phase acceptance check; require no cycle containing `schema.ex` and the six owned domain schema files.

**Warning signs:** the xref output says `Cycle of length 7 (6 compile)` and lists all seven files. [VERIFIED: local command output; [Mix xref docs](https://hexdocs.pm/mix/Mix.Tasks.Xref.html)]

### Pitfall 2: Weakening the callback guard while decoupling the allowlist

**What goes wrong:** all shipped schemas appear correct, but an unsupported consumer can delete `@after_compile`, declare raw Ecto schema metadata, and bypass prefix enforcement.

**Why it happens:** the component is caused by reverse dependencies from the macro's direct domain aliases, tempting deletion of the callback or an open-ended allowlist rather than a data-only closed set.

**How to avoid:** preserve the existing callback target and run the dynamic `Code.compile_string/1` rejection test unchanged (or strengthen it only behaviorally).

**Warning signs:** `test "rejects callback deletion plus raw Ecto declaration from a non-owned consumer"` stops raising `ArgumentError`. [VERIFIED: `test/rindle/schema_prefix_contract_test.exs`]

### Pitfall 3: Fixing documentation by changing product behavior or route identifiers

**What goes wrong:** a docs-only Admin reconciliation changes slugs/routes, or tus prose changes error/capability semantics.

**Why it happens:** label names and support posture are conflated with implementation identifiers.

**How to avoid:** preserve `slug`, `suffix`, public errors, and CI topology; update prose/tests to point at the existing behavior.

**Warning signs:** changes to `@surfaces` slugs/suffixes, `.github/workflows/ci.yml` topology, public error terms, or migration files. [VERIFIED: `lib/rindle/admin/components.ex`; `.planning/STATE.md`; Phase 121 SAFE-01 report]

### Pitfall 4: Unbounded Phase/Plan comment removal

**What goes wrong:** broad search-and-replace erases legitimate history/safety rationale or edits immutable archives.

**Why it happens:** phase identifiers are plentiful, but only stale forward/dead-red narration is in scope.

**How to avoid:** maintain a reviewed target list outside `.planning/milestones/`; rewrite only comments whose current behavior contradicts their tense. Keep historical snapshots (for example the v1.3 digest fixture) explicitly historical.

**Warning signs:** diffs touch `.planning/milestones/`, CHANGELOG history, or a test snapshot's immutable provenance rather than a stale claim. [VERIFIED: `.planning/REQUIREMENTS.md`; `test/rindle/backward_compat/v13_digest_snapshot_test.exs`]

## Code Examples

### Reproducible compile-cycle evidence

```sh
MIX_ENV=test mix compile --force
MIX_ENV=test mix xref graph --format cycles --label compile-connected
MIX_ENV=test mix xref trace lib/rindle/domain/media_asset.ex --label compile
```

Expected pre-change evidence is one component of length seven, with six compile edges into `lib/rindle/schema.ex`. The post-change gate is that this output has no component containing the six schemas and `schema.ex`. [VERIFIED: local command output; [Mix xref docs](https://hexdocs.pm/mix/Mix.Tasks.Xref.html)]

### Existing preservation checks

```sh
MIX_ENV=test mix test \
  test/rindle/schema_prefix_contract_test.exs \
  test/rindle/domain/media_schema_test.exs \
  test/rindle/config/config_test.exs \
  test/rindle/schema_prefix_integration_test.exs

bash scripts/maintainer/refactor_contract.sh
```

Use the full SAFE-01 runner as the phase gate; it covers public signatures, schema/migration behavior, telemetry, error shapes, and release/CI invariants. [VERIFIED: `scripts/maintainer/refactor_contract.sh`; Phase 121 verification]

## State of the Art

| Old approach | Current approach | Impact |
|---|---|---|
| Milestone narration in live comments | Domain-focused explanation of the shipped invariant | Readers can understand the code without obsolete planning context. |
| Alias-based owner allowlist closes macro-to-consumer component | String/segment-based closed owner allowlist | Same public schema behavior with no seven-module compile-connected component. |
| Docs describe retired Admin labels and no shipped tus abstraction | Docs mirror rendered labels and shipped tus boundary | Adopters receive current support posture without a UI/API change. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | Replacing the six direct module aliases with canonical string/segment identities eliminates the reported component on this compiler version. | Architecture Patterns | Medium: exact post-change xref evidence is mandatory; adjust only the internal representation if it does not. |
| A2 | A focused ExUnit wrapper around `mix xref` is stable enough for the default suite. | Validation Architecture | Medium: if process invocation is brittle, retain the command as a deterministic phase/CI check rather than adding a flaky test. |

## Open Questions

1. **Which live Phase/Plan comments are explanatory history rather than stale narration?**
   - What we know: the four `EXPECTED RED` files and forward claims in `Capability`, Mux modules, and selected tests are plainly stale; many other comments explain active safety invariants.
   - What's unclear: the exact smallest reviewable target set.
   - Recommendation: plan a one-time evidence inventory, require each edit to replace a stale claim with domain rationale, and prohibit bulk replacement.

2. **Should the xref gate be a committed ExUnit test?**
   - What we know: Mix 1.19.5 provides stable machine-readable/CLI cycle output and the local command is deterministic.
   - What's unclear: whether invoking nested Mix in the normal ExUnit runtime has unwanted build-lock/process interaction.
   - Recommendation: prove a focused test once. If it is not reliably isolated, document and run the exact command in the phase verifier/CI policy rather than creating a self-inspecting test.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Elixir / Mix | Compile/xref/schema tests | ✓ | 1.19.5 | — |
| Erlang/OTP | Elixir compiler | ✓ | 28 | — |
| PostgreSQL test configuration | schema-prefix integration test | Not required for xref/docs-only slice | — | Run non-DB schema tests first; use established project integration environment for DB suite. |

**Missing dependencies with no fallback:** None for the docs/xref implementation path.

**Missing dependencies with fallback:** Database-backed prefix integration can use the repository's established integration lane rather than blocking the non-DB cycle proof.

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit (project-native) |
| Config file | `test/test_helper.exs`, `config/test.exs` |
| Quick run command | `MIX_ENV=test mix test test/rindle/schema_prefix_contract_test.exs test/rindle/domain/media_schema_test.exs test/rindle/config/config_test.exs` |
| Full suite command | `mix ci` and `bash scripts/maintainer/refactor_contract.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| CLARITY-01 | Live stale forward/dead-red commentary is replaced; archives excluded | focused source/docs regression plus review | focused files under `test/rindle/...` and parity suites | Partial — target-specific tests need prose updates/additions |
| CLARITY-02 | Admin/tus/streaming/support/CI prose matches shipped behavior | docs parity | `mix test test/install_smoke/docs_parity_test.exs test/install_smoke/phoenix_tus_truth_parity_test.exs test/install_smoke/streaming_cancel_docs_parity_test.exs test/brandbook/admin_design_system_validation_test.exs` | Yes, extend only for identified drift |
| CLARITY-03 | No seven-module xref cycle; schema ownership/prefix unchanged | compile graph plus unit/integration contract | xref command + schema prefix tests + SAFE-01 | Prefix tests yes; xref regression proof gap |
| SAFE-01 | Public/schema/migration/telemetry/error/release contracts remain unchanged | aggregate contract | `bash scripts/maintainer/refactor_contract.sh` | Yes |

### Sampling Rate

- **Per task commit:** focused docs/schema test command plus `MIX_ENV=test mix xref graph --format cycles --label compile-connected --fail-above 0` when touching the allowlist.
- **Per wave merge:** `bash scripts/maintainer/refactor_contract.sh`.
- **Phase gate:** `mix ci`, SAFE-01, exact xref check, and `./scripts/maintainer/repo_hygiene_check.sh` before PR/release handoff.

### Wave 0 Gaps

- [ ] Decide/prove the xref regression mechanism: a behavior-oriented ExUnit invocation only if it is stable; otherwise a named deterministic verifier command.
- [ ] Extend existing docs parity tests with only the corrected Admin labels and tus/streaming support boundaries.
- [ ] Add a reviewed non-archive stale-comment inventory/negative check only if it can avoid policing arbitrary prose or `.planning/` history.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | No | No auth behavior changes. |
| V3 Session Management | No | No session/config key changes. |
| V4 Access Control | Yes, documentation only | Preserve Admin host-auth posture; do not weaken production refusal guidance. |
| V5 Input Validation | Yes | Preserve `Rindle.Schema.validate_prefix!/1` and compile-time accepted-prefix validation. |
| V6 Cryptography | No | Do not alter tus/streaming secret handling. |

### Known Threat Patterns for This Slice

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Unauthorized schema declaration bypasses prefix guard | Tampering | Preserve callback-based validation and dynamic rejection test. |
| Docs overstate optional/runtime support | Repudiation / Information disclosure | Derive claims from code and existing contract tests; do not promise unsupported providers or routes. |
| Admin docs imply relaxed authentication | Elevation of privilege | Retain host-owned auth and production refusal language. |
| Refactor changes telemetry/errors/CI gates while moving internals | Tampering / Repudiation | Run SAFE-01 and do not modify those boundaries. |

## Sources

### Primary (HIGH confidence)

- `AGENTS.md` — repository/release-train constraints.
- `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md` — phase scope and requirements.
- `.planning/phases/121-truthful-quality-signals-mechanical-hygiene/121-VERIFICATION.md` — SAFE-01 and prior quality gates.
- `lib/rindle/schema.ex`, all six `lib/rindle/domain/media_*.ex` schemas — cycle implementation and public ownership model.
- `mix xref graph --format cycles --label compile-connected`, `mix xref trace ... --label compile`, `MIX_ENV=test mix compile --force` — fresh compile/xref evidence.
- `guides/admin_design_system.md`, `lib/rindle/admin/components.ex`, `guides/storage_capabilities.md`, `guides/resumable_uploads.md`, `guides/streaming_providers.md` — live truth evidence.
- Relevant schema/docs tests named in Validation Architecture — existing preservation and parity seams.

### Secondary (MEDIUM confidence)

- [Mix xref documentation](https://hexdocs.pm/mix/Mix.Tasks.Xref.html) — compiler graph semantics and recommended cycle commands.

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — no new stack; local installed toolchain and existing dependencies were inspected.
- Architecture: HIGH — the exact seven-file component, the six compile calls, and the reverse alias allowlist were reproduced locally; the representation change still requires post-change xref proof.
- Pitfalls: HIGH — derived from current schema guard tests, release constraints, and concrete stale docs/comments.

**Research date:** 2026-08-22
**Valid until:** 2026-09-21 (stable internal maintenance scope; re-run xref on a toolchain change)
