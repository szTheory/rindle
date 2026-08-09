---
phase: 117-prefix-routing-architecture
verified: 2026-08-09T02:27:11Z
status: gaps_found
score: 3/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/4
  gaps_closed: []
  gaps_remaining:
    - "A consumer can remove the sole final-prefix guard and compile a schema with metadata that differs from Rindle.Schema.prefix/0."
  regressions: []
gaps:
  - truth: "The project has one tested routing authority; a Rindle.Schema consumer cannot finish compilation with final Ecto prefix metadata different from Rindle.Schema.prefix()/0."
    status: failed
    reason: "The only finalization enforcement is the consumer-owned @after_compile attribute. A consumer can delete it after use Rindle.Schema, set @schema_prefix to the alternate allowed prefix, and compile successfully."
    artifacts:
      - path: "lib/rindle/schema.ex"
        issue: "Registers @after_compile Rindle.Schema in mutable consumer module state but does not reassert the authority at schema/2 declaration time."
      - path: "test/rindle/schema_prefix_contract_test.exs"
        issue: "Tests only Module.put_attribute/3; it does not include Module.delete_attribute(__MODULE__, :after_compile) before the override."
    missing:
      - "Make the schema declaration boundary reassert the compiled prefix immediately before Ecto consumes it (for example, a Rindle.Schema.schema/2 wrapper while excluding raw Ecto.Schema.schema/2 from the consumer import)."
      - "Retain finalization as defense in depth and add regressions for callback deletion plus alternate-prefix mutation in both the default rindle and explicit public builds."
deferred:
  - truth: "Release-facing public compatibility documentation and the public-to-rindle migration pairing are complete."
    addressed_in: "Phases 118 and 120"
    evidence: "Phase 118 success criteria own the data-preserving public-to-rindle move; Phase 120 success criterion 3 owns documentation of the breaking default and public escape hatch."
---

# Phase 117: Prefix Routing Architecture Verification Report

**Phase Goal:** Adopters can rely on one explicit, proven Rindle schema-routing model: `rindle` by default or an intentional `public` compatibility configuration, with no normal data path silently falling back.
**Verified:** 2026-08-09T02:27:11Z
**Status:** gaps_found
**Re-verification:** Yes — after Plan 117-03 gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A configured default build assigns `rindle` metadata to normal Rindle schemas without callers supplying per-query prefixes. | ✓ VERIFIED | `Rindle.Schema.prefix/0` defaults its compile-time config to `"rindle"`; all six owned schemas use it. A `MIX_ENV=dev` unmodified consumer compiles with that authority, and the ordinary post-`use` public override raises the bounded mismatch error. Schema provisioning itself is Phase 118 scope. |
| 2 | The explicit `public` compatibility build assigns the same normal Rindle behavior to `public`. | ✓ VERIFIED | `config/test.exs` selects `"public"`; focused tests pass (35 tests), including real facade/Multi and worker persistence against selected `public` tables with `rindle` decoys. |
| 3 | Facade, `Ecto.Multi`, worker, loaded-struct, and new-struct paths retain the selected prefix when decoy tables exist. | ✓ VERIFIED | `schema_prefix_integration_test.exs` passed: `Rindle.attach/3`, `attachment_for/2`, and `PromoteAsset.persist_probe_result/3` read/write selected rows while the decoy remains unchanged. The test checks returned and loaded struct metadata. |
| 4 | One tested architectural authority prevents a schema consumer from finishing with metadata different from `Rindle.Schema.prefix/0`. | ✗ FAILED | Independent probes deleted the consumer's `:after_compile` attribute before changing `:schema_prefix`. Default build output was `{"rindle", "public", "public"}`; public build output was `{"public", "rindle", "rindle"}` for `{authority, schema metadata, struct metadata}`. |

**Score:** 3/4 truths verified (0 present, behavior-unverified)

### Deferred Items

| # | Item | Addressed In | Evidence |
| --- | --- | --- | --- |
| 1 | Release-facing public compatibility docs and migration pairing | Phases 118 and 120 | Phase 118 owns the public-to-`rindle` move; Phase 120 owns consistent release documentation and packed-adopter proof. |

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/rindle/schema.ex` | Shared, compile-time routing authority | ⚠️ PARTIAL | Exists and is substantive: validates only `rindle`/`public`, binds the prefix before the consumer quote, retains binary keys, and has `__after_compile__/2`. Its sole final guard is removable by consumer code, so it does not enforce its stated invariant. |
| `lib/rindle/config.ex` | Diagnostics reflect the compiled Rindle authority; Oban stays independent | ✓ VERIFIED | `rindle_prefix/0` delegates to `Rindle.Schema.prefix/0`; `oban_prefix/0` remains a separate runtime value. Focused config test sets Oban to `host_oban` without retargeting Rindle. |
| Six `lib/rindle/domain/media_*.ex` schemas | All present Rindle-owned schemas use the shared macro | ✓ VERIFIED | AST contract test and `media_schema_test.exs` confirm each uses `Rindle.Schema`, carries selected schema/struct metadata, and preserves binary ID/foreign-key metadata. No direct `Ecto.Schema` or `@schema_prefix` appears in those six sources. |
| `test/rindle/schema_prefix_contract_test.exs` | Negative regression for prefix authority | ⚠️ PARTIAL | The ordinary `Module.put_attribute/3` attack is covered and passes, but the test omits callback removal, the route that actually defeats the guard. |
| `test/rindle/schema_prefix_integration_test.exs` and `test/support/schema_prefix_case.ex` | Selected-versus-decoy runtime routing proof | ✓ VERIFIED | Non-stub PostgreSQL fixtures create distinguishable selected/decoy rows without changing `search_path`; both tests passed. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `Rindle.Schema.prefix/0` | consumer `@schema_prefix` | `quote bind_quoted: [prefix: prefix]` | ✓ WIRED | `schema.ex` resolves the already-compiled authority outside the quote and assigns that bound value in the consumer. |
| `Rindle.Schema.__using__/1` | `Rindle.Schema.__after_compile__/2` | consumer `@after_compile Rindle.Schema` | ⚠️ PARTIAL | The registration exists, but it lives in mutable consumer module state and can be deleted before compilation ends. |
| `Rindle.Schema.__after_compile__/2` | consumer `__schema__(:prefix)` | equality check | ⚠️ PARTIAL | The equality check is substantive and rejects the ordinary mutation, but is never invoked after `Module.delete_attribute(__MODULE__, :after_compile)`. |
| contract test | finalization boundary | dynamic compiled consumer | ✗ NOT_WIRED FOR CALLBACK REMOVAL | The test compiles a consumer with `Module.put_attribute/3`, but no test exercises deletion of the enforcement callback. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `Rindle.Schema` and six domain schemas | Ecto schema/struct prefix | compile-time `:rindle_prefix` → macro-bound `@schema_prefix` | Yes — selected-prefix metadata routes the integration reads/writes and struct metadata | ✓ FLOWING for existing schemas |
| finalization guard | final schema prefix comparison | consumer `@after_compile` callback | No, adversarially bypassable — callback removal prevents the check from running | ✗ DISCONNECTED enforcement |
| integration fixtures | selected/decoy assets | PostgreSQL schemas and distinguishable storage keys | Yes — assertions show reads/writes reach selected rows and leave decoys untouched | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Existing config, metadata, facade/Multi, loaded/new struct, and worker routes | `mix test test/rindle/config/config_test.exs test/rindle/domain/media_schema_test.exs test/rindle/schema_prefix_contract_test.exs test/rindle/schema_prefix_integration_test.exs --seed 0` | 35 tests, 0 failures; one pre-existing unused-attribute warning | ✓ PASS |
| Ordinary default-build post-use override is rejected | `MIX_ENV=dev mix run --no-start -e '<ordinary public override probe>'` | Raised `Rindle.Schema prefix mismatch ... expected "rindle", got "public"` | ✓ PASS |
| Default-build callback-removal bypass is rejected | `MIX_ENV=dev mix run --no-start -e '<delete :after_compile; set public; schema>'` | Compiled; output `{"rindle", "public", "public"}` | ✗ FAIL |
| Public-build callback-removal bypass is rejected | `MIX_ENV=test mix run --no-start -e '<delete :after_compile; set rindle; schema>'` | Compiled; output `{"public", "rindle", "rindle"}` | ✗ FAIL |
| Formatting for Plan 03 files | `mix format --check-formatted lib/rindle/schema.ex test/rindle/schema_prefix_contract_test.exs test/rindle/config/config_test.exs` | Exit 0 | ✓ PASS |

### Probe Execution

Step 7c: SKIPPED — the phase plans/summaries declare no `probe-*.sh` executable and no conventional project probe applies.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| PREFIX-01 | 117-01, 117-02, 117-03 | Default Rindle-owned state routes to `rindle` without callers adding prefixes | ⚠️ PARTIAL / BLOCKED | The intended default is correctly compiled into the six current schemas, but a macro consumer can remove the enforcement callback and compile with `public` metadata. The claimed single authority is therefore not enforceable. |
| PREFIX-02 | 117-01, 117-02, 117-03 | Explicit legacy `public` compatibility through one coherent prefix configuration and migration pairing | ⚠️ PARTIAL / BLOCKED | The explicit public build and its normal routes work, but the same callback-removal probe compiles a consumer with `rindle` metadata. Migration/doc pairing remains explicitly deferred to Phases 118/120. |
| PREFIX-03 | 117-01, 117-02, 117-03 | Facade, worker, Multi, loaded/new struct paths use selected prefix rather than silently falling back | ⚠️ PARTIAL / BLOCKED | Present shipped paths pass selected/decoy integration tests and Oban remains independent, but the architectural guard can be removed so the invariant is not durable for a consumer/changed owned schema. |

No orphaned Phase 117 requirements were found: all three IDs appear in every 117 plan and map to Phase 117 in `.planning/REQUIREMENTS.md`.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `lib/rindle/schema.ex` | 25 | Sole enforcement stored as mutable `@after_compile` consumer attribute | 🛑 Blocker | Consumer removes it and bypasses the final-prefix equality check. |
| `test/rindle/schema_prefix_contract_test.exs` | 37-57 | Negative test covers only the weaker mutation | 🛑 Blocker | Test passes while the callback-removal bypass remains untested and exploitable. |
| `test/rindle/config/config_test.exs` | 8 | Unused `@async_safety_allow` warning | ⚠️ Warning | No routing impact; emitted during focused test run. |

No unreferenced `TBD`, `FIXME`, or `XXX` markers were found in the Plan 117 modified implementation/test files.

### Gaps Summary

Plan 117-03 closed the originally tested direct `Module.put_attribute/3` mutation, but not the claimed architectural invariant. `@after_compile` is ordinary mutable module state of the schema consumer; deleting it before changing `@schema_prefix` suppresses `Rindle.Schema.__after_compile__/2` entirely. This produces mismatched schema and struct prefix metadata in both supported build modes.

This is a **BLOCKER**: Phase 117 has not proved or delivered one enforceable routing model. The migration and release-documentation work is correctly deferred, but it does not address this implementation-level authority bypass.

**Next command:** `$gsd-plan-phase 117 --gaps`

---

_Verified: 2026-08-09T02:27:11Z_
_Verifier: the agent (gsd-verifier)_
