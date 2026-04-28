---
phase: 06-adopter-runtime-ownership
verified: 2026-04-28T09:46:37Z
status: passed
score: 8/8 must-haves verified
overrides_applied: 0
---

# Phase 6: Adopter Runtime Ownership Verification Report

**Phase Goal:** the adopter app truly owns the runtime Repo boundary, and the public Rindle APIs no longer require or leak `Rindle.Repo` in consumer code paths
**Verified:** 2026-04-28T09:46:37Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Adopters can configure the runtime Repo via `config :rindle, :repo, MyApp.Repo`. | ✓ VERIFIED | [`lib/rindle/config.ex`](./lib/rindle/config.ex) `repo/0` reads `Application.get_env(:rindle, :repo, Rindle.Repo)` at lines 11-14; [`test/rindle/config/config_test.exs`](./test/rindle/config/config_test.exs) lines 32-53 prove override + fallback; `mix test test/rindle/config/config_test.exs` passed. |
| 2 | Public facade runtime paths no longer hard-code `Rindle.Repo` for `attach/4`, `detach/3`, or `upload/3`. | ✓ VERIFIED | [`lib/rindle.ex`](./lib/rindle.ex) lines 125-177, 198-230, and 327-359 resolve `repo = Rindle.Config.repo()` and transact through that seam; `rg -n 'Rindle\\.Repo\\.(transaction|get!|get|insert!?|update!?|delete!?|all|one|preload)' lib/rindle.ex lib/rindle/upload/broker.ex` returned no matches. |
| 3 | Direct-upload broker flows use the configured Repo rather than `Rindle.Repo`. | ✓ VERIFIED | [`lib/rindle/upload/broker.ex`](./lib/rindle/upload/broker.ex) lines 28-65, 101-122, and 143-189 use `Config.repo()` for transaction/get/preload/update paths; [`test/rindle/upload/broker_test.exs`](./test/rindle/upload/broker_test.exs) lines 13-50 and 72-76 inject `TestRepoProbe`, and lines 101-103, 124-127, and 166-168 assert broker calls hit the configured repo; `mix test test/rindle/upload/broker_test.exs` passed. |
| 4 | The proxied upload lane proves `Rindle.upload/3` succeeds under an adopter Repo override. | ✓ VERIFIED | [`test/rindle/upload/lifecycle_integration_test.exs`](./test/rindle/upload/lifecycle_integration_test.exs) lines 181-277 override `:rindle, :repo` to `Rindle.Adopter.CanonicalApp.Repo`, set `sandbox_repo`, and read back through the adopter repo; `mix test test/rindle/upload/lifecycle_integration_test.exs:183` passed. |
| 5 | The canonical adopter integration uses an adopter-owned Repo end-to-end and no longer relies on the shared `Rindle.Repo` loophole. | ✓ VERIFIED | [`test/support/data_case.ex`](./test/support/data_case.ex) lines 22-25 select sandbox ownership from `tags[:sandbox_repo]`; [`test/adopter/canonical_app/lifecycle_test.exs`](./test/adopter/canonical_app/lifecycle_test.exs) lines 13, 22, and 65-79 wire `Oban.Testing`, sandbox ownership, and `Application.put_env(:rindle, :repo, Rindle.Adopter.CanonicalApp.Repo)`; lines 102-185 exercise initiate/sign/verify/delivery/attach/detach against adopter-repo reads; `mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs` passed. |
| 6 | Phase 6 keeps Oban scope explicit: default `Oban` compatibility is proven, named-instance ownership is not claimed. | ✓ VERIFIED | [`guides/background_processing.md`](./guides/background_processing.md) lines 20-34 and 76-79 state adopter ownership of the default Oban path and defer `:oban_name`; [`test/test_helper.exs`](./test/test_helper.exs) line 10 starts the default `Oban` module for tests and the adopter proofs still pass against that contract. |
| 7 | Adopter-facing guides explain Repo ownership in adopter-first terms instead of teaching `Rindle.Repo`. | ✓ VERIFIED | [`guides/getting_started.md`](./guides/getting_started.md) lines 43-57 teach `config :rindle, :repo, MyApp.Repo`; [`guides/troubleshooting.md`](./guides/troubleshooting.md) lines 37-40, 62, and 198-217 use `MyApp.Repo`; `rg -n 'Rindle\\.Repo|Requires `Rindle\\.Repo`|config :rindle, :repo, Rindle\\.Repo' lib/rindle.ex lib/rindle/upload/broker.ex guides/getting_started.md guides/background_processing.md guides/troubleshooting.md` returned no matches. |
| 8 | Copy-paste examples align with the canonical direct-upload proof and the dedicated proxied-upload adopter proof. | ✓ VERIFIED | [`guides/getting_started.md`](./guides/getting_started.md) lines 84-121 mirror `Broker.initiate_session`, `Broker.verify_completion`, `Rindle.Delivery.url`, and `Rindle.upload/3`; the canonical adopter test at [`test/adopter/canonical_app/lifecycle_test.exs`](./test/adopter/canonical_app/lifecycle_test.exs) lines 102-185 and the proxied adopter proof at [`test/rindle/upload/lifecycle_integration_test.exs`](./test/rindle/upload/lifecycle_integration_test.exs) lines 246-277 cover those same entrypoints. |

**Score:** 8/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/rindle/config.ex` | Runtime Repo accessor for adopter-owned resolution | ✓ VERIFIED | Exists, substantive, and exports `repo/0` at lines 11-14. |
| `lib/rindle.ex` | Repo-neutral public facade for attach/detach/upload | ✓ VERIFIED | Exists, substantive, and all three public entrypoints use `Rindle.Config.repo/0`. |
| `lib/rindle/upload/broker.ex` | Repo-neutral direct-upload broker entrypoints | ✓ VERIFIED | Exists, substantive, and all broker persistence paths use `Config.repo()`. |
| `test/rindle/config/config_test.exs` | Repo accessor regression coverage | ✓ VERIFIED | Covers configured override and fallback behavior; executable proof passed. |
| `test/rindle/upload/broker_test.exs` | Broker regression coverage for runtime Repo resolution | ✓ VERIFIED | Uses `TestRepoProbe` to prove runtime repo calls hit the configured seam. |
| `test/support/data_case.ex` | Per-test sandbox ownership selection | ✓ VERIFIED | `sandbox_repo` selector is wired into sandbox owner startup. |
| `test/adopter/canonical_app/lifecycle_test.exs` | Canonical adopter runtime proof against adopter Repo config | ✓ VERIFIED | Adopter repo override + direct-upload/delivery/attach/detach flow executed successfully. |
| `test/rindle/upload/lifecycle_integration_test.exs` | Dedicated adopter-repo proxied-upload proof | ✓ VERIFIED | Adopter-only proxied upload module exists and its focused test passed. |
| `guides/getting_started.md` | Adopter-first setup and lifecycle instructions | ✓ VERIFIED | Shows `MyApp.Repo` ownership and matches the public proof lane. |
| `guides/background_processing.md` | Explicit Oban ownership statement and scope boundary | ✓ VERIFIED | Documents default-Oban-only support and named-instance deferral. |
| `guides/troubleshooting.md` | Adopter-owned Repo examples for debugging and inspection | ✓ VERIFIED | Uses `MyApp.Repo` queries throughout adopter-facing diagnostics. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `lib/rindle.ex` | `lib/rindle/config.ex` | single runtime repo resolution per public entrypoint | ✓ WIRED | `Rindle.Config.repo()` at lines 126, 199, and 328 of [`lib/rindle.ex`](./lib/rindle.ex). |
| `lib/rindle.ex` | Ecto transaction callback repo arg | purge callbacks use transaction repo instead of re-fetching via `Rindle.Repo` | ✓ WIRED | `tx_repo.get!` in `attach/4` line 158 and `detach/3` line 213. |
| `lib/rindle/upload/broker.ex` | `lib/rindle/config.ex` | runtime repo lookup for session/asset persistence | ✓ WIRED | `Config.repo()` at lines 29, 102, and 144. |
| `test/rindle/upload/broker_test.exs` | configured repo seam | injected probe around adopter repo | ✓ WIRED | `Application.put_env(:rindle, :repo, TestRepoProbe)` at line 75 plus `assert_received` checks at lines 101-103, 124-127, and 166-168. |
| `test/support/data_case.ex` | `test/adopter/canonical_app/lifecycle_test.exs` | adopter-only sandbox owner | ✓ WIRED | `sandbox_repo` lookup at line 23; canonical test sets `@moduletag sandbox_repo: Rindle.Adopter.CanonicalApp.Repo` at line 22. |
| `test/adopter/canonical_app/lifecycle_test.exs` | `config :rindle, :repo` | test-scoped env override for adopter runtime proof | ✓ WIRED | `Application.put_env(:rindle, :repo, Rindle.Adopter.CanonicalApp.Repo)` at line 69. |
| `test/rindle/upload/lifecycle_integration_test.exs` | `config :rindle, :repo` | dedicated adopter Repo override around `Rindle.upload/3` | ✓ WIRED | `Application.put_env(:rindle, :repo, Rindle.Adopter.CanonicalApp.Repo)` at line 221. |
| `guides/getting_started.md` | proof lanes | matching direct-upload and proxied-upload examples | ✓ WIRED | `config :rindle, :repo, MyApp.Repo` at line 52 and lifecycle/proxied examples at lines 84-121 mirror the adopter proof files. |
| `guides/background_processing.md` | default Oban contract | explicit default-only scope note | ✓ WIRED | Lines 20-34 and 76-79 describe default Oban ownership and `:oban_name` deferral. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `lib/rindle.ex` | `repo` | `Rindle.Config.repo/0` -> `Application.get_env(:rindle, :repo, Rindle.Repo)` | Yes | ✓ FLOWING |
| `lib/rindle/upload/broker.ex` | `repo` | `Config.repo()` -> configured repo module used for `transaction/get/preload/update` | Yes | ✓ FLOWING |
| `test/adopter/canonical_app/lifecycle_test.exs` | adopter runtime repo | `Application.put_env(:rindle, :repo, Rindle.Adopter.CanonicalApp.Repo)` + adopter-only sandbox owner | Yes — exercised by passing adopter test | ✓ FLOWING |
| `test/rindle/upload/lifecycle_integration_test.exs` | proxied adopter repo path | `Application.put_env(:rindle, :repo, Rindle.Adopter.CanonicalApp.Repo)` + adopter-only repo reads | Yes — exercised by passing focused integration test | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Repo accessor override/fallback regression | `mix test test/rindle/config/config_test.exs` | `4 tests, 0 failures` | ✓ PASS |
| Broker runtime Repo seam | `mix test test/rindle/upload/broker_test.exs` | `9 tests, 0 failures` | ✓ PASS |
| Proxied adopter-repo proof | `mix test test/rindle/upload/lifecycle_integration_test.exs:183` | `1 test, 0 failures (4 excluded)` | ✓ PASS |
| Canonical adopter lifecycle | `mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs` | `1 test, 0 failures` | ✓ PASS |
| No direct `Rindle.Repo` persistence calls remain in public runtime files | `rg -n 'Rindle\\.Repo\\.(transaction|get!|get|insert!?|update!?|delete!?|all|one|preload)' lib/rindle.ex lib/rindle/upload/broker.ex` | no matches | ✓ PASS |
| No adopter-facing `Rindle.Repo` wording remains in the Phase 6 guide surface | `rg -n 'Rindle\\.Repo|Requires `Rindle\\.Repo`|config :rindle, :repo, Rindle\\.Repo' lib/rindle.ex lib/rindle/upload/broker.ex guides/getting_started.md guides/background_processing.md guides/troubleshooting.md` | no matches | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| `ADOPT-01` | `06-01` | Adopter can configure Rindle's runtime Repo via `config :rindle, :repo, MyApp.Repo` | ✓ SATISFIED | `Rindle.Config.repo/0` in [`lib/rindle/config.ex`](./lib/rindle/config.ex) lines 11-14 plus passing config tests at [`test/rindle/config/config_test.exs`](./test/rindle/config/config_test.exs) lines 32-53. |
| `ADOPT-02` | `06-01`, `06-02` | Public runtime APIs use the configured adopter Repo instead of hard-coded `Rindle.Repo` | ✓ SATISFIED | Public facade and broker use runtime repo seam; broker probe tests prove configured repo calls; no direct `Rindle.Repo` persistence calls remain in the public runtime files. |
| `ADOPT-03` | `06-02` | Canonical adopter integration proves upload, attach, detach, and delivery flows work with an adopter-owned Repo | ✓ SATISFIED | Passing adopter lifecycle test at [`test/adopter/canonical_app/lifecycle_test.exs`](./test/adopter/canonical_app/lifecycle_test.exs) plus passing focused proxied adopter proof at [`test/rindle/upload/lifecycle_integration_test.exs`](./test/rindle/upload/lifecycle_integration_test.exs). |
| `ADOPT-04` | `06-02`, `06-03` | Guides and examples document adopter-owned Repo and Oban ownership without repo-internal assumptions | ✓ SATISFIED | `guides/getting_started.md`, `guides/background_processing.md`, and `guides/troubleshooting.md` all use adopter-first Repo/Oban wording and contain no `Rindle.Repo` guide leakage. |

Phase-6 orphaned requirements: none. Every Phase 6 requirement in [`REQUIREMENTS.md`](./.planning/REQUIREMENTS.md) is claimed by at least one Phase 6 plan.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| None | - | - | - | No blocker or warning-level stub patterns were found in the phase artifacts. |

### Gaps Summary

No blocking gaps found. The adopter-owned Repo seam exists, the public facade and direct-upload broker are wired through it, the canonical and proxied adopter proofs execute successfully, and the guide surface matches the delivered Repo/Oban ownership contract.

---

_Verified: 2026-04-28T09:46:37Z_
_Verifier: Codex (gsd-verifier)_
