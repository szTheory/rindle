---
phase: 110-async-isolation-hardening
verified: 2026-06-28T00:00:00Z
status: passed
score: 12/12 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: null
  previous_score: null
---

# Phase 110: Async-isolation hardening Verification Report

**Phase Goal:** `Rindle.Config.repo/0` consults a `$callers`-aware process-dictionary override before the application env, eliminating the global `Application.put_env(:rindle, :repo, …)` in the counting-repo double — so the failing-txn double is process-scoped (like Sandbox/Mox) and can never pollute a concurrent async reader — and the v1.20 async-safety guard gains a rule that makes the footgun un-reintroducible.
**Verified:** 2026-06-28
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | `Config.repo/0` consults a `$callers`-aware process-dict override before app env; byte-unchanged default when no override | ✓ VERIFIED | `lib/rindle/config.ex:12-16` — `with nil <- repo_override(self()) do Application.get_env(:rindle, :repo, Rindle.Repo) end`; literal app-env fallback line preserved. `config_test.exs` (no override → app-env path) passes 4/4. |
| 2 | `put_repo_override/1` sets per-process override; `delete_repo_override/0` clears it — process-dict only, no `Application.put_env` | ✓ VERIFIED | `lib/rindle/config.ex:22,26` — `Process.put(@repo_override_key, mod)` / `Process.delete(@repo_override_key)`. No `Application.put_env/delete_env` in the seam. |
| 3 | Override set in parent is visible to `$callers`-linked child (Task/inline-Oban) | ✓ VERIFIED | `caller_repo_override/1` (`lib/rindle/config.ex:95-100`) walks `:"$callers"`, recurses through `repo_override/1`; code-review confirmed empirically; isolation test relies on this (B with no `$callers` link sees `Rindle.Repo`). |
| 4 | `with_counting_repo/2` installs the double via `Config.put_repo_override/1`, clears in `after`; NO `Application.put_env/delete_env(:rindle, :repo)` | ✓ VERIFIED | `test/support/counting_failing_txn_repo.ex:8,15`. Negative grep for `put_env/delete_env(:rindle, :repo` → NONE in the double. |
| 5 | Fail-config (`fail_after`/`fail_reason`) reads the process dict, not Application env; no global mutation remains | ✓ VERIFIED | `counting_failing_txn_repo.ex:9,83-91` — `@config_key` process-dict; `fail_after/0`/`fail_reason/0` read `Process.get(@config_key, [])`. No Application env for `:counting_failing_txn_repo`. |
| 6 | StreamingDispatchTest, OwnerErasureBatchProofTest, BatchOwnerErasureTaskTest are `async: true` and pass | ✓ VERIFIED | All three declare `use Rindle.DataCase, async: true`; suites run **28 tests, 0 failures** under async (0.2s). |
| 7 | Guard gains `:global_repo_swap` rule flagging `put_env/delete_env(:rindle, :repo, …)` in ANY module, message points at `put_repo_override/1` | ✓ VERIFIED | `async_safety_guard_test.exs:321-327` (classifier), `512-533` (message names `Rindle.Config.put_repo_override/1`). Negative probe (non-allowlisted `async:false` module with `put_env(:rindle,:repo,Foo)`) drove the rule RED at the exact line. |
| 8 | `:global_repo_swap` is in `@primitive_names` | ✓ VERIFIED | `async_safety_guard_test.exs:53`. |
| 9 | Guard scans ALL modules (not only async:true) via separate path; existing per-async:true rules unchanged | ✓ VERIFIED | `parse_all_modules/1` (`:163-177`, mirrors `parse_async_true_modules/1` minus the async filter); `collect_global_repo_swaps/1` (`:304-314`) is a separate pass. Existing two tests + `classify/2` clauses unchanged (both pass). |
| 10 | `@async_safety_allow [:global_repo_swap]` allowlist honored on the 9 legitimate swappers; suite green | ✓ VERIFIED | All 9 files carry the allow atom (grep confirmed each); guard suite **3 tests, 0 failures**. |
| 11 | config_test.exs keeps `put_env(:rindle,:repo)` and is allowlisted (D-10), NOT migrated | ✓ VERIFIED | `config_test.exs:45,57` retain `put_env`/`delete_env`; allowlisted (D-10). Counting double NOT allowlisted (grep → 0). |
| 12 | ISO-05 concurrency proof: process A force-fails + sees double while unrelated B reads `Rindle.Repo` + succeeds; FAILS on old impl, PASSES on new | ✓ VERIFIED | `repo_override_isolation_test.exs` passes **1 test, 0 failures** (async:true). **RED→GREEN delta proven empirically:** simulating the old global `put_env` impl in the double drove the proof RED (B observed `CountingFailingTxnRepo`); the real process-scoped impl is GREEN (B observed `Rindle.Repo`). |

**Score:** 12/12 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `lib/rindle/config.ex` | `repo/0` resolver + setters + `$callers`-walk helpers | ✓ VERIFIED | All present; compiles clean; includes tuple-safe `List.keyfind/3` cross-process read (Plan 04 bug fix). Wired — `Config.repo/0` is the universal repo-resolution path. |
| `test/support/counting_failing_txn_repo.ex` | process-scoped `with_counting_repo/2` + process-dict fail config | ✓ VERIFIED | Process-local override + `@config_key`; passthrough generator (`__info__(:functions)`) intact (`:66-73`); no global mutation. |
| `test/async_safety_guard_test.exs` | `:global_repo_swap` classifier + all-modules scan + `@primitive_names` entry | ✓ VERIFIED | All present and wired into a third test; negative probe confirms the rule fires. |
| `test/rindle/config/repo_override_isolation_test.exs` | ISO-05 concurrency proof, async:true | ✓ VERIFIED | Present, async:true, passes; encodes the old→new delta (proven RED under simulated old impl). |
| 9 swapper modules w/ `@async_safety_allow [:global_repo_swap]` | allowlist + `# why:` | ✓ VERIFIED | All 9 confirmed; counting double NOT allowlisted. |
| 3 re-promoted modules → async:true | root-caused comments | ✓ VERIFIED | All three `async: true`; 28 tests pass. |

### Key Link Verification

| From | To | Via | Status |
| ---- | -- | --- | ------ |
| `Config.repo/0` | app-env fallback | `repo_override(self())` → `caller_repo_override/1` → `process_get/2` (`$callers` walk), falling through to `Application.get_env(:rindle, :repo, Rindle.Repo)` | ✓ WIRED |
| `with_counting_repo/2` | `Config.put_repo_override(__MODULE__)` + `Process.put(@config_key)`; `after` → `delete_repo_override/0` + `Process.delete` | install/clear | ✓ WIRED |
| guard all-modules scan | `classify_global_repo_swap/1` → reject allowlisted → offenders | merge gate | ✓ WIRED (negative probe fires) |
| process A (override) | bare-`spawn` B (no `$callers` link) reads `Config.repo() == Rindle.Repo`, runs successful txn in A's window | isolation proof | ✓ WIRED (RED→GREEN delta empirically confirmed) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| ISO-05 proof passes (new impl) | `mix test repo_override_isolation_test.exs` | 1 test, 0 failures | ✓ PASS |
| ISO-05 proof FAILS on old impl | simulate global `put_env` in double, re-run | 1 test, 1 failure (B saw `CountingFailingTxnRepo`) | ✓ PASS (delta proven) |
| `:global_repo_swap` rule fires | inject non-allowlisted `put_env(:rindle,:repo,Foo)`, run guard | 3 tests, 1 failure — flagged at exact line | ✓ PASS |
| config/guard/isolation suites green | `mix test` (3 files) | 8 tests, 0 failures | ✓ PASS |
| 3 re-promoted async suites | `mix test` (3 files) | 28 tests, 0 failures | ✓ PASS |
| No residual global swap in double | grep `put_env/delete_env(:rindle, :repo` in double | NONE | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
| ----------- | ----------- | ------ | -------- |
| ISO-01 | 110-01 | ✓ SATISFIED | `repo/0` `$callers`-aware override before app env; byte-unchanged default (truth 1). |
| ISO-02 | 110-01 | ✓ SATISFIED | `put_repo_override/1` + `delete_repo_override/0`, process-dict only (truth 2). |
| ISO-03 | 110-02 | ✓ SATISFIED | Process-scoped double, no global swap; 3 modules re-promoted async:true (truths 4,5,6). |
| ISO-04 | 110-03 | ✓ SATISFIED | `:global_repo_swap` rule, all-modules scan, allowlist, negative probe fires (truths 7-11). |
| ISO-05 | 110-04 | ✓ SATISFIED | Concurrency proof passes new / fails old — empirically confirmed (truth 12). |

All 5 declared requirement IDs (ISO-01..05) are present in REQUIREMENTS.md (lines 43-47, 95-99), marked Complete, and accounted for in plans. No orphaned requirements.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `repo_override_isolation_test.exs` | 14-20, 38 | Stale comment: describes B as `Task.async` from the test process, but code (line 44) uses bare `spawn` | ℹ️ Info | Documentation drift only; matches code-review IN-03. Test correctness unaffected (passes; delta proven). No debt marker, no behavioral impact. |

No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK` debt markers in any modified file. No stubs, no hardcoded-empty data, no orphaned artifacts.

### Code-Review Advisory Notes (non-blocking)

- **WR-01** (`110-REVIEW.md`): cyclic `$callers` causes unbounded recursion in `repo_override/1` (only a single-hop self-guard). Low practical reachability (OTP populates `$callers` monotonically; Rindle never writes it), classified WARNING by the reviewer, not a BLOCKER. The phase goal (process-scoped, no global pollution) is achieved; this is a defense-in-depth hardening opportunity for a future patch, not a goal gap. Surfaced here as advisory per the verification brief.
- **WR-02 / WR-03**: `@spec` return-value description and `with nil <-` boundary fragility on the test-only seam — quality refinements, no current incorrect behavior (the seam is `@doc false`, test-only, and only ever receives a module atom).

### Gaps Summary

None. All 12 must-haves are verified with codebase evidence. The two load-bearing behavioral properties were proven empirically rather than by presence: (1) the `:global_repo_swap` guard genuinely goes RED on a fresh non-allowlisted swap, and (2) the ISO-05 proof genuinely distinguishes the old global-`put_env` impl (RED — reader polluted) from the new process-scoped impl (GREEN — reader isolated). The byte-unchanged default path is preserved (literal app-env fallback line intact; `config_test` green). The working tree was left clean after both empirical probes.

---

_Verified: 2026-06-28_
_Verifier: Claude (gsd-verifier)_
