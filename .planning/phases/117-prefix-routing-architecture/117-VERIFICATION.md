---
phase: 117-prefix-routing-architecture
verified: 2026-08-09T03:27:16Z
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/5
  gaps_closed:
    - "The selected prefix remains bypassable when a Rindle.Schema consumer deletes :after_compile and deliberately declares through Ecto.Schema.schema/2."
  gaps_remaining: []
  regressions: []
deferred:
  - truth: "A fresh database has the rindle schema/tables provisioned, and release-facing public compatibility documentation and the public-to-rindle migration pairing are complete."
    addressed_in: "Phases 118 and 120"
    evidence: "Phase 118 success criteria 1-4 own schema provisioning and the safe public-to-rindle move; Phase 120 success criterion 3 owns the breaking-default/public-escape-hatch documentation. Current README and upgrade guide still describe the prior public/arbitrary-prefix contract."
---

# Phase 117: Prefix Routing Architecture Verification Report

**Phase Goal:** Adopters can rely on one explicit, proven Rindle schema-routing model: `rindle` by default or an intentional `public` compatibility configuration, with no normal data path silently falling back.
**Verified:** 2026-08-09T03:27:16Z
**Status:** passed
**Re-verification:** Yes — after Plan 117-05 gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A configured default build assigns `rindle` metadata to normal Rindle schemas without callers supplying query prefixes. | ✓ VERIFIED | `Rindle.Schema.prefix/0` has compile-time default `"rindle"`; all six owned schemas use it. A fresh `MIX_ENV=dev` attack probe that deletes `:after_compile`, writes `"public"`, and calls raw `Ecto.Schema.schema/2` was rejected before schema setup because its caller is not owned. |
| 2 | The explicit `public` compatibility build assigns normal Rindle behavior to `public`. | ✓ VERIFIED | `config/test.exs:19` explicitly compiles the test build with `:rindle_prefix, "public"`; the focused suite proves every owned schema's schema and new-struct metadata match that authority. |
| 3 | Facade operations, background work, `Ecto.Multi` callbacks, and loaded/new Rindle structs retain the selected prefix when decoy public tables exist. | ✓ VERIFIED | `schema_prefix_integration_test.exs` exercised `Rindle.attach/3`, `attachment_for/2`, `PromoteAsset.persist_probe_result/3`, loaded structs, and selected-versus-decoy PostgreSQL rows. The selected row changed; the decoy remained distinguishable and unchanged. |
| 4 | The project has one tested architectural decision with no mixed routing semantics exposed to adopters. | ✓ VERIFIED | `Rindle.Schema` is compile-time-only, supports exactly `rindle`/`public`, and is explicitly internal to the six owned schemas. Its caller allowlist rejects the prior combined callback-deletion/raw-Ecto attack before it can create opposite-prefix metadata. |
| 5 | The exact callback-deletion, opposite-prefix, raw-Ecto declaration bypass is rejected in both build postures; Repo, `search_path`, migration, and Oban routing are unchanged. | ✓ VERIFIED | Stored contract test rejects the combined attack in the explicit-public build; the independent default-build probe rejected it as well. `Rindle.Config.rindle_prefix/0` delegates to the compiled authority while `oban_prefix/0` remains independent; no Phase 117 code touches Repo, migrations, or Oban setup. |

**Score:** 5/5 truths verified (0 present, behavior-unverified)

### Deferred Items

Items below are not Phase 117 implementation gaps: later roadmap phases explicitly own them.

| # | Item | Addressed In | Evidence |
| --- | --- | --- | --- |
| 1 | Provisioned fresh `rindle` install, public-to-`rindle` move, and release-facing documentation of the new default/compatibility escape hatch | Phases 118 and 120 | Phase 118 provides schema provisioning and the host-controlled move; Phase 120 owns docs and packed-adopter proof. Existing README/upgrading guidance still has the superseded public/arbitrary-prefix wording. |

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/rindle/schema.ex` | Internal compile-time schema prefix authority | ✓ VERIFIED | Exists, substantive (82 lines), validates both allowed prefixes at compile time, binds the selected prefix, restores it at normal declaration, final-checks metadata, and rejects non-owned macro consumers before Ecto setup. |
| `lib/rindle/config.ex` | Diagnostics report the same Rindle authority while Oban stays independent | ✓ VERIFIED | `rindle_prefix/0` delegates to `Rindle.Schema.prefix/0`; `oban_prefix/0` retains its separate runtime configuration. |
| Six `lib/rindle/domain/media_*.ex` schemas | Current Rindle schemas consume the shared authority | ✓ VERIFIED | Every one uses `Rindle.Schema`, declares an unqualified `schema/2`, and the AST contract rejects direct `Ecto.Schema`, imports, remote declarations, or `@schema_prefix` assignments. |
| `test/rindle/schema_prefix_contract_test.exs` | Regression for the formerly successful combined bypass | ✓ VERIFIED | Dynamically compiles a non-owned consumer that deletes the callback, writes the opposite prefix, and invokes raw `Ecto.Schema.schema/2`; it must raise the bounded internal-boundary `ArgumentError`. |
| `test/rindle/schema_prefix_integration_test.exs` and `test/support/schema_prefix_case.ex` | Real selected-versus-decoy routing proof | ✓ VERIFIED | Fixtures create real PostgreSQL selected/decoy data without altering `search_path`; the two integration paths observe real state transitions. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `Rindle.Schema.__using__/1` | six owned schema modules | `__CALLER__.module` allowlist before quoted Ecto setup | ✓ WIRED | `schema.ex:25` calls `validate_owned_schema!/1`; the six module atoms are the only allowlist entries and all six sources use the macro. |
| `Rindle.Schema.__using__/1` | `Rindle.Schema.schema/2` | excludes Ecto `schema: 2`, imports only Rindle wrapper | ✓ WIRED | `schema.ex:29-31`; the six schema sources use the resulting unqualified declaration. |
| `Rindle.Schema.schema/2` | `Ecto.Schema.schema/2` | reasserts `Rindle.Schema.prefix/0` immediately before delegation | ✓ WIRED | `schema.ex:42-50` assigns the compiled prefix then performs the remote Ecto macro call; normal schema metadata and integration routing tests pass. |
| Contract regression | internal macro boundary | dynamic callback deletion + opposite prefix + raw Ecto declaration | ✓ WIRED | `schema_prefix_contract_test.exs:43-56,95-106` executes the combined attack and asserts the exact boundary error. |
| Integration suite | facade/Multi/worker/loaded/new paths | selected-versus-decoy database assertions | ✓ WIRED | Both integration tests passed against selected public rows and `rindle` decoys. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Owned schemas | Ecto schema/struct prefix | compile-time `:rindle_prefix` → `Rindle.Schema.prefix/0` → schema metadata | Yes — selected metadata drove facade and worker PostgreSQL reads/writes while decoys remained unchanged. | ✓ FLOWING |
| `Rindle.Schema.schema/2` | declaration prefix | compiled `Rindle.Schema.prefix/0` | Yes — it overwrites a preceding alternate attribute immediately before normal declaration. | ✓ FLOWING |
| Internal-boundary guard | raw Ecto attempt | caller module identity before setup | Yes — both public-build test and default-build probe reject the former bypass before any schema metadata is created. | ✓ ENFORCED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Focused prefix/config/domain/integration suite | `mix test test/rindle/config/config_test.exs test/rindle/domain/media_schema_test.exs test/rindle/schema_prefix_contract_test.exs test/rindle/schema_prefix_integration_test.exs --seed 0` | 35 tests, 0 failures | ✓ PASS |
| Default-build combined raw-Ecto attack | `MIX_ENV=dev mix compile --force && MIX_ENV=dev mix run --no-start -e '<delete callback; set public; raw Ecto probe>'` | `default raw-Ecto bypass rejected at owned boundary` | ✓ PASS |
| Formatting | `mix format --check-formatted lib/rindle/schema.ex test/rindle/schema_prefix_contract_test.exs test/rindle/config/config_test.exs` | exit 0 | ✓ PASS |
| Repository coverage gate | `mix coveralls.multiple --type local --type json --slowest 20` | 1,261 tests, 0 failures; 81.5% coverage | ✓ PASS |

### Probe Execution

Step 7c: SKIPPED — no Phase 117 probe script is declared and no conventional `scripts/**/tests/probe-*.sh` exists.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- |
| PREFIX-01 | 117-01 through 117-05 | Default Rindle-owned paths route to `rindle` without per-query prefixes | ✓ SATISFIED | Compile-time default, six schema metadata checks, and default-build attack rejection establish the routing architecture. Fresh database provisioning is explicitly Phase 118. |
| PREFIX-02 | 117-01 through 117-05 | Explicit coherent `public` compatibility configuration and migration pairing | ✓ SATISFIED (routing) | Public compile configuration, schema/struct metadata, normal selected-versus-decoy behavior, and raw-bypass rejection pass. Public migration pairing/docs are explicitly deferred to Phases 118/120. |
| PREFIX-03 | 117-01 through 117-05 | Facade, worker, Multi, loaded/new structs use selected prefix rather than silently falling back | ✓ SATISFIED | Selected-versus-decoy database tests cover facade/Multi and worker/loaded paths; new-struct metadata is asserted for every owned schema; boundary enforcement prevents the demonstrated alternate metadata route. |

No orphaned Phase 117 requirements were found: PREFIX-01, PREFIX-02, and PREFIX-03 appear in every phase plan and map to Phase 117 in `REQUIREMENTS.md`.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `test/rindle/config/config_test.exs` | 8 | Unused `@async_safety_allow` attribute warning | ⚠️ Warning | Pre-existing test-harness warning; no routing impact. |

No unreferenced `TBD`, `FIXME`, or `XXX` markers were found in the Phase 117 implementation/test files.

### Gaps Summary

The previous blocker is closed. The reported attack is now structurally impossible at the exposed `Rindle.Schema` boundary: the macro is not an adopter extension API, validates its caller before adding Ecto setup, and the regression exercises callback removal, opposite-prefix mutation, and remote Ecto declaration as one sequence. The normal six-schema path remains connected to real facade and worker data flows.

Fresh-schema provisioning, the public-to-`rindle` move, and release-facing docs are deliberately later-phase work with explicit roadmap ownership; they are recorded above as deferred rather than treated as Phase 117 failures.

---

_Verified: 2026-08-09T03:27:16Z_
_Verifier: the agent (gsd-verifier)_
