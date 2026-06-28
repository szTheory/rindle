# Phase 110: Async-isolation hardening - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-28
**Phase:** 110-async-isolation-hardening
**Areas discussed:** Guard blast radius (ISO-04), async:true re-promotion scope (ISO-03), Second global key (ISO-04)

> Context: approach was already research-locked (`v1.21-ASYNC-ISOLATION.md`, HIGH) to Option (i)+(iv)
> — `$callers`-aware process-dict override + `:global_repo_swap` guard rule — and the `lib/config.ex`
> touch pre-authorized (D-v1.21-01). The discussion targeted only the scope/blast-radius questions
> the research and requirements left open, surfaced by a codebase scout that found 9 modules (not
> just the counting double) swapping `:rindle, :repo`.

---

## Guard blast radius (ISO-04)

The new `:global_repo_swap` rule flags `put_env/delete_env(:rindle, :repo, …)` in any module;
scout found 9 existing `async: false` modules doing this legitimately. How to treat the other 8.

| Option | Description | Selected |
|--------|-------------|----------|
| Allowlist the 8 w/ justification | Keep 8 async:false, add justified `@async_safety_allow [:global_repo_swap]`; only the counting double migrates. Minimal blast radius; guard still bites NEW swaps. | ✓ |
| Migrate the repo-doubles too | Migrate TestRepoProbe/FailingTransactionRepo users to the override, allowlist only config_test. ~5–6 files; kills more anti-pattern now. | |
| Narrow the rule to the double only | Flag only swaps to a counting/failing double. No allowlist churn but footgun stays reintroducible; research rejects. | |

**User's choice:** Allowlist the 8 w/ justification.
**Notes:** Minimal, ISO-01..05-scoped blast radius; the 8 are already serial and not the flake
source. `config_test` is the canonical allowlist case — it asserts `Config.repo() == CanonicalApp.Repo`
after `put_env`, so it MUST keep `put_env` and must NOT migrate (override would shadow the env). The
new rule requires a load-bearing structural change: the guard currently scans only `async: true`
modules, so a separate all-modules scan path is needed, honoring `@async_safety_allow` on async:false
modules. Migrating the other repo-doubles deferred to a future phase.

---

## async:true re-promotion scope (ISO-03)

Research §6 says revert StreamingDispatchTest (locked) "and the two mutators, if otherwise clean."

| Option | Description | Selected |
|--------|-------------|----------|
| Dispatch + both mutators | Promote StreamingDispatchTest AND both counting-double mutators (OwnerErasureBatchProofTest, BatchOwnerErasureTaskTest) to async:true. Recovers full serialization tax. | ✓ |
| Dispatch only (literal ISO-03) | Promote only StreamingDispatchTest. Smallest change; leaves recoverable async tax. | |

**User's choice:** Dispatch + both mutators.
**Notes:** Scout confirmed both mutators are async:false ONLY for the repo-swap reason — no other
unsafe primitive — so they're provably clean to promote once the double is process-scoped.

---

## Second global key (ISO-04)

`with_counting_repo/2` also mutates `:rindle, :counting_failing_txn_repo` (fail_after/fail_reason).

| Option | Description | Selected |
|--------|-------------|----------|
| Guard :repo only (per ISO-04) | Move both keys to the process dict (ISO-03), but guard flags only `:rindle, :repo` per ISO-04. The second key is double-internal/lower-risk. | ✓ |
| Guard both keys | Extend the rule to also flag `:counting_failing_txn_repo`. Stronger lock but exceeds ISO-04's literal scope; guards a key nothing in lib/ reads. | |

**User's choice:** Guard :repo only (per ISO-04).
**Notes:** Matches the spec exactly, no scope drift. The second key still moves to the process dict
(D-04) for cleanliness; it just isn't policed by the guard since no `lib/` code reads it.

## Claude's Discretion

- Exact `$callers`-walk helper names / cycle-guard (research §3 reference impl); the proof-test file
  path/name; per-module `@async_safety_allow` `# why:` wording; the guard all-modules-scan refactor
  shape (combined walk vs. second pass), provided async:true rules are unchanged and the allowlist is
  honored on async:false modules.

## Deferred Ideas

- Migrate the other lib-redirecting repo doubles (TestRepoProbe, FailingTransactionRepo) to
  `put_repo_override/1` — same anti-pattern, async:false, not the flake source → future phase.
- Durable shipped-artifact regression-lock meta-tests → Phase 111 (LOCK).
- Gate shift-left → Phase 112 (GATE).
