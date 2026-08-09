---
phase: 117-prefix-routing-architecture
verified: 2026-08-08T21:56:00-04:00
status: gaps_found
score: 2/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "The project has one tested architectural schema-routing decision; mixed routing semantics are not exposed to adopters."
    status: failed
    reason: "A consumer can replace @schema_prefix after `use Rindle.Schema`; Ecto then uses the replacement prefix while Rindle.Schema.prefix/0 retains the configured prefix. The source AST guard does not detect Module.put_attribute/3."
    artifacts:
      - path: "lib/rindle/schema.ex"
        issue: "The macro sets a mutable module attribute but has no final-prefix enforcement after the consuming schema compiles."
      - path: "test/rindle/schema_prefix_contract_test.exs"
        issue: "The structural check rejects only literal @schema_prefix AST nodes, not dynamic module-attribute mutation."
    missing:
      - "Enforce after schema compilation that module.__schema__(:prefix) equals Rindle.Schema.prefix()."
      - "Add a regression test that attempts Module.put_attribute(__MODULE__, :schema_prefix, \"public\") after use Rindle.Schema and proves compilation is rejected."
deferred:
  - truth: "Public compatibility is documented with the matching migration configuration."
    addressed_in: "Phases 118 and 120"
    evidence: "Phase 118 success criterion 2 supplies the public-to-rindle migration path; Phase 120 success criterion 3 requires docs to agree on the breaking default and escape hatch. Current README and guides still say public is default and advertise unsupported tenant_media prefixes."
---

# Phase 117: Prefix Routing Architecture Verification Report

**Phase Goal:** Adopters can rely on one explicit, proven Rindle schema-routing model: `rindle` by default or an intentional `public` compatibility configuration, with no normal data path silently falling back.
**Verified:** 2026-08-08T21:56:00-04:00
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A fresh configured application resolves normal Rindle schema metadata to `rindle` without per-query prefixes. | ✓ VERIFIED | `Rindle.Schema` defaults `Application.compile_env/3` to `"rindle"`; `ConfigTest` dynamically compiles an unset-config schema and asserts both `__schema__(:prefix)` and a new struct metadata prefix are `"rindle"`. All six current domain schemas use the macro. Provisioning actual tables is intentionally Phase 118 scope. |
| 2 | An adopter can select the documented `public` compatibility configuration and receive equivalent normal behavior. | ✗ FAILED (DEFERRED) | `config/test.exs` proves the compile-time `public` compatibility build and integration tests exercise it. But current README/getting-started/upgrading documentation still declares `public` the default and suggests unsupported `tenant_media`; the required migration pairing also remains later-phase work. See Deferred Items. |
| 3 | Facade operations, background work, Ecto.Multi callbacks, and loaded/new structs consistently retain the selected prefix in the presence of a decoy. | ✓ VERIFIED | `schema_prefix_integration_test.exs` passed with distinguishable `public` (selected) and `rindle` (decoy) tables: `Rindle.attach/3` covers `Ecto.Multi` and a new attachment; `attachment_for/2` covers facade read/preload; `PromoteAsset.persist_probe_result/3` updates a loaded struct; decoy rows stay unchanged. |
| 4 | There is one tested routing authority; mixed routing semantics cannot be introduced by a schema consumer. | ✗ FAILED | Independent compile probe: `use Rindle.Schema` then `Module.put_attribute(__MODULE__, :schema_prefix, "public")` produced `{ "rindle", "public", "public" }` for `{Rindle.Schema.prefix(), module.__schema__(:prefix), struct(module).__meta__.prefix}`. |

**Score:** 2/4 truths verified (0 present, behavior-unverified)

### Deferred Items

Items not yet met but explicitly addressed in later milestone phases.

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | Public compatibility documentation and matching migration pairing | Phases 118 and 120 | Phase 118 SC2 covers the public-to-`rindle` upgrade; Phase 120 SC3 requires docs to state the breaking default and escape hatch. |

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `lib/rindle/schema.ex` | Shared compile-time prefix macro | ⚠️ PARTIAL | Exists and is substantive (validated `rindle`/`public`, binary keys) and every current owned schema uses it, but its final prefix can be overwritten after `use`. |
| `lib/rindle/config.ex` | Diagnostics report compiled Rindle prefix, independent Oban prefix | ✓ VERIFIED | `rindle_prefix/0` delegates to `Rindle.Schema.prefix/0`; `oban_prefix/0` remains a separate runtime setting. The focused config test proves the two values can differ without changing the compiled Rindle value. |
| Six `lib/rindle/domain/media_*.ex` schemas | Domain table metadata uses shared macro | ✓ VERIFIED | Each module has `use Rindle.Schema`; contract and media-schema tests assert selected prefix, struct metadata, and binary keys. |
| `test/support/schema_prefix_case.ex` | Isolated selected/decoy fixture data source | ✓ VERIFIED | Creates only the decoy schema/tables, seeds selected and decoy values, and does not mutate `search_path`. |
| `test/rindle/schema_prefix_integration_test.exs` | Runtime routing proof | ✓ VERIFIED | Two non-stub integration tests passed. |
| `test/rindle/schema_prefix_contract_test.exs` | Regression guard against routing bypass | ✗ STUB FOR DYNAMIC BYPASS | It checks literal `@schema_prefix` syntax only; dynamic attribute mutation remains accepted. |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| `Rindle.Schema` | Six domain schemas | `use Rindle.Schema` before each `schema/2` block | ⚠️ PARTIAL | All six links exist, but the link does not prevent a later consumer mutation from changing Ecto metadata. |
| `Rindle.Config.rindle_prefix/0` | `Rindle.Schema.prefix/0` | direct delegation | ✓ WIRED | No mutable runtime `:rindle_prefix` value can override diagnostic routing. |
| Facade / worker operations | Ecto schema metadata | `Rindle.attach`, `attachment_for`, `PromoteAsset.persist_probe_result` | ✓ WIRED | Integration proof passes against selected/decoy fixtures. |
| Contract test | dynamic prefix overrides | AST validation | ✗ NOT_WIRED | No detection of `Module.put_attribute/3` or macro-expanded assignment; the negative invariant is untested. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `Rindle.Schema` / domain schemas | `@schema_prefix`, Ecto struct metadata | Compile-time `Application.compile_env(:rindle, :rindle_prefix, "rindle")` | Yes — used by Ecto query and struct metadata in integration tests | ⚠️ HOLLOW GUARD |
| Prefix integration test | `selected` / `decoy` rows | Sandbox-owned PostgreSQL fixtures in distinct schemas | Yes — rows have distinguishable keys and content types | ✓ FLOWING |

The primary data flow is real and test-exercised, but it is not immutable: the after-`use` mutation probe changes the consumer's Ecto metadata without changing the shared authority.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Current config, schema, contract, facade/Multi, loaded-struct, and worker routing tests | `mix test test/rindle/config/config_test.exs test/rindle/domain/media_schema_test.exs test/rindle/schema_prefix_contract_test.exs test/rindle/schema_prefix_integration_test.exs --seed 0` | 34 tests, 0 failures | ✓ PASS |
| Shared authority resists a post-`use` prefix change | `mix run --no-start -e '<dynamic schema with Module.put_attribute/3>'` | `{ "rindle", "public", "public" }` | ✗ FAIL |

### Probe Execution

Step 7c: SKIPPED — neither plans nor summaries declare probes, and no `scripts/*/tests/probe-*.sh` files exist.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| PREFIX-01 | 117-01, 117-02 | Default all owned domain state to `rindle` without caller query prefixes | ✗ BLOCKED | Current six schemas have the default macro metadata, but the macro does not remain the sole authority; a later owned schema can silently select another prefix. |
| PREFIX-02 | 117-01, 117-02 | Explicit legacy `public` compatibility through one documented coherent configuration and migration pairing | ⚠️ PARTIAL / DEFERRED | Public compilation and runtime routing are proven. Documentation and the migration pairing are explicitly scheduled to Phases 118/120 and currently contradict the new two-value contract. |
| PREFIX-03 | 117-01, 117-02 | Normal facade, worker, Multi, loaded/new struct paths use selected prefix | ⚠️ PARTIAL | Selected-`public` paths are integration-proven, but the same mutable-attribute bypass means the architectural guarantee is not enforceable. |

No orphaned Phase 117 requirements were found: all three are claimed by both phase plans and map to Phase 117 in `REQUIREMENTS.md`.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `test/rindle/schema_prefix_contract_test.exs` | 53-57 | Syntax-only negative guard | 🛑 Blocker | A passing contract test gives false confidence because dynamic module-attribute mutation bypasses it. |
| `test/rindle/config/config_test.exs` | 8 | Unused `@async_safety_allow` compile warning | ⚠️ Warning | Focused test run emits a warning; it does not block prefix routing. |

No unreferenced `TBD`, `FIXME`, or `XXX` debt markers were found in phase-modified source/test files.

### Gaps Summary

The submitted implementation proves that the six present schemas and several real operation paths use the selected prefix. It does **not** establish the required single routing authority: any consuming schema can mutate the ordinary `@schema_prefix` attribute after `use Rindle.Schema`, creating divergent routing that the current tests accept. This is a **BLOCKER** for the phase goal, not a human-verification question.

The public-compatibility documentation/migration mismatch is recorded as deferred because later roadmap phases explicitly own that release-facing work; it is not the reason for the blocking verdict.

---

_Verified: 2026-08-08T21:56:00-04:00_
_Verifier: the agent (gsd-verifier)_
