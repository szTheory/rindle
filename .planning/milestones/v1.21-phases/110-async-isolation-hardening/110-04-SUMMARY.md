---
phase: 110-async-isolation-hardening
plan: 04
subsystem: testing
tags: [async-isolation, repo-override, concurrency-proof, iso-05, callers-walk, hex-0.3.2]
status: complete

requires:
  - phase: 110-01
    provides: "Rindle.Config.repo/0 $callers-aware resolver + put_repo_override/1 + delete_repo_override/0"
  - phase: 110-02
    provides: "Process-scoped Rindle.Test.CountingFailingTxnRepo.with_counting_repo/2 (no global :rindle,:repo swap)"
provides:
  - "test/rindle/config/repo_override_isolation_test.exs — the async: true ISO-05 concurrency proof"
  - "Tuple-safe $callers process-dictionary read in Rindle.Config (lib bug fix surfaced by the proof)"
affects: []

tech-stack:
  added: []
  patterns:
    - "bare spawn (not Task.async) to create a reader with NO :\"$callers\" link — the canonical 'unrelated process tree' construction for proving process-scoped override isolation"
    - "explicit Ecto.Adapters.SQL.Sandbox.allow/3 from the test owner to a bare-spawned reader that shares no ownership lineage"

key-files:
  created:
    - test/rindle/config/repo_override_isolation_test.exs
  modified:
    - lib/rindle/config.ex

key-decisions:
  - "D-04-01: with_counting_repo/2 runs its callback INLINE, so process A == the test process; the reader B must therefore be spawned WITHOUT a $callers link to the test process. A bare spawn/1 (Task.async injects $callers) is the only construction that makes B genuinely unrelated — proven empirically (Task.async made B inherit the override and resolve the double)."
  - "D-04-02 [Rule 1 bug, lib touch]: fixed Rindle.Config process_get/2 cross-process branch — it used Keyword.get/3 on the raw process dictionary, but the override key is a tuple ({Rindle.Config, :repo_override}) and Keyword.get's guard requires an atom key, so it raised FunctionClauseError whenever the $callers walk inspected another process's dict with an override present. Replaced with tuple-safe List.keyfind/3. Committed fix: (bundles into Plan 01's release-please 0.3.2 patch per D-13)."
  - "D-04-03: B granted Sandbox.allow(Rindle.Repo, test_pid, reader) so its real transaction runs against the sandboxed repo despite sharing no ownership lineage with A (no $callers link == no automatic sandbox lookup)."

patterns-established:
  - "Pattern: prove process-local override isolation by reading the override from a bare-spawned, $callers-unlinked reader concurrently inside the override window — the reader resolving the REAL repo (not the double) is the green delta."

requirements-completed: [ISO-05]

coverage:
  - id: D1
    description: "ISO-05 concurrency proof: process A force-fails its 1st transaction and resolves the double; unrelated bare-spawned reader B resolves Rindle.Repo and runs a successful transaction concurrently inside A's window; module is async: true; encodes the old->new (global-put_env -> process-scoped) delta."
    requirement: "ISO-05"
    verification:
      - kind: integration
        ref: "grep -q 'async: true' test/rindle/config/repo_override_isolation_test.exs && mix test test/rindle/config/repo_override_isolation_test.exs => 1 test, 0 failures"
        status: pass
      - kind: integration
        ref: "mix test test/rindle/ test/async_safety_guard_test.exs => 3 doctests, 1099 tests, 0 failures, 4 skipped (no regression from the lib fix)"
        status: pass
      - kind: other
        ref: "mix compile --warnings-as-errors => exit 0"
        status: pass
    human_judgment: false

duration: 3min
completed: 2026-06-28
status: complete
---

# Phase 110 Plan 04: ISO-05 concurrency isolation proof Summary

**`test/rindle/config/repo_override_isolation_test.exs` (`async: true`) proves the counting double's repo override is process-scoped: process A force-fails its 1st transaction while an unrelated, `$callers`-unlinked bare-spawned reader B concurrently resolves `Rindle.Repo` and runs a successful transaction inside A's window. Writing the proof surfaced and fixed a latent tuple-key bug in the Plan 01 `$callers` resolver.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-06-28T19:00:49Z
- **Completed:** 2026-06-28T19:04:37Z
- **Tasks:** 1
- **Files created/modified:** 2 (1 test created, 1 lib fixed)

## Accomplishments

- Created `test/rindle/config/repo_override_isolation_test.exs` as `use Rindle.DataCase, async: true` — the held-out ISO-05 proof (research §8 / CONTEXT D-12). Inside one `with_counting_repo(1, fn -> … end)` window: process A asserts `Config.repo() == Rindle.Test.CountingFailingTxnRepo` and its 1st `transaction(fn -> :ok end)` returns `{:error, :plan, _, %{}}`; an unrelated reader B (bare `spawn`, message-gated) concurrently resolves `Config.repo() == Rindle.Repo` and its real transaction returns `{:ok, :ok}`.
- Fixed a real bug in `lib/rindle/config.ex` (Plan 01 resolver) that the proof surfaced: the cross-process `$callers`-walk read the inspected process dictionary with `Keyword.get/3`, which rejects the tuple override key `{Rindle.Config, :repo_override}` (its guard requires an atom key) and raised `FunctionClauseError`. Now uses tuple-safe `List.keyfind/3`.

## Tasks

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| (lib fix) | Tuple-safe $callers dict read in repo override resolver | 80ab4e1 | lib/rindle/config.ex |
| 1 | Write the ISO-05 concurrency isolation proof test | ceebd03 | test/rindle/config/repo_override_isolation_test.exs |

## Key Implementation Detail — why bare `spawn`, not `Task.async`

The plan's read_first sketched B as a `Task.async` created in the test process before A's window, reasoning that B's `$callers` would be the test process (no override) rather than A. That reasoning is incorrect for this double: `with_counting_repo/2` runs its callback **inline in the caller**, so **process A IS the test process**, and `put_repo_override/1` writes the override into the test process's own dictionary. A `Task.async` child carries the test process in `:"$callers"`, so it WOULD inherit A's override and resolve the double — the inverted (RED) case. This was confirmed empirically: the first `Task.async` attempt failed with B resolving `Rindle.Test.CountingFailingTxnRepo`.

The fix is a bare `spawn/1`: unlike `Task.async`, it injects no `:"$callers"`, so B is a genuinely unrelated process tree whose `Config.repo()` walk finds no override anywhere and falls through to `Rindle.Repo`. Because B shares no ownership lineage with A, it needs an explicit `Ecto.Adapters.SQL.Sandbox.allow(Rindle.Repo, test_pid, reader)` to run its real transaction against the sandboxed repo. Coordination is explicit message passing (`send(reader, :go)` from inside the window; `assert_receive {:reader_result, ^reader, …}`) so the read genuinely happens concurrently inside the open window.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Tuple-key crash in the `$callers` dict resolver (lib/ touch)**
- **Found during:** Task 1 (first run of the proof test).
- **Issue:** `Rindle.Config.process_get/2`'s cross-process branch did `Keyword.get(dict, {Rindle.Config, :repo_override})`. `Keyword.get/3`'s guard is `is_atom(key)`; a tuple key raises `(FunctionClauseError) no function clause matching in Keyword.get/3`. This fired whenever the resolver walked into another process's dictionary while an override was present — exactly what the concurrency proof does.
- **Fix:** Read the dictionary with tuple-safe `List.keyfind(dict, key, 0)`, returning the value or `nil`. Same-self path (`Process.get/1`) and the default no-override production path are byte-unchanged.
- **Files modified:** `lib/rindle/config.ex`
- **Commit:** `80ab4e1`
- **Release impact:** `fix:` conventional type — bundles into the same release-please **0.3.2** patch as Plan 01's lib touch (D-13). No public-API change, no new semver concern; the default production branch is unaffected (the bug only manifests when an override is present and a cross-process `$callers` walk occurs).
- **Scope note:** This adds a lib/ touch beyond the plan's declared `files_modified` (test only). It is a correctness fix (Rule 1) that blocked the deliverable (Rule 3) and is localized (one private clause, no architecture/API/library change), so it was auto-fixed rather than escalated. It does not introduce a *new* release relative to the milestone — it joins the already-authorized 0.3.2 patch.

**2. [Plan premise correction] Reader construction: bare `spawn` instead of `Task.async`**
- **Found during:** Task 1.
- **Issue:** The plan's suggested `Task.async`-in-the-test-process construction inverts the proof, because A == the test process (inline callback) and a `Task.async` child inherits the test process via `$callers`.
- **Fix:** Used a bare `spawn/1` (no `$callers`) plus explicit `Sandbox.allow/3` and message-passing coordination. The proof property is preserved exactly; only the spawn mechanism changed to honor the plan's own prohibition ("B must NOT be a `$callers` descendant of A").
- **Files:** test file only.
- **Commit:** `ceebd03`

## RED→GREEN delta (proof property)

- **GREEN (current Plan 01+02 tree):** B resolves `Rindle.Repo` and its transaction succeeds while A's window is open → `1 test, 0 failures`.
- **RED (old global-`put_env` impl):** B would resolve the globally-swapped `:rindle, :repo` (the double) and observe `{Rindle.Test.CountingFailingTxnRepo, …}` — empirically observed during the inverted `Task.async` attempt, which reproduces precisely the old-impl pollution the test guards against. Per the plan, `lib/` was not reverted to demonstrate this; the delta is encoded by the `{Rindle.Repo, {:ok, :ok}}` assertion.

## Known Stubs

None.

## Threat Flags

None. Test-only deliverable plus a localized internal resolver fix; no new network/auth/file/schema surface. Threat T-110-06 (silent regression of the isolation property) is now mitigated by an executable, default-suite, `async: true` lock.

## Verification

- `grep -q 'async: true' test/rindle/config/repo_override_isolation_test.exs` → present.
- `mix test test/rindle/config/repo_override_isolation_test.exs` → **1 test, 0 failures**.
- `mix compile --warnings-as-errors` → exit 0.
- `mix test test/rindle/ test/async_safety_guard_test.exs` → **3 doctests, 1099 tests, 0 failures, 4 skipped** (the lib fix introduced no regression; the `:global_repo_swap` guard suite stays green).

## Self-Check: PASSED

- FOUND: test/rindle/config/repo_override_isolation_test.exs (async: true, passes)
- FOUND: lib/rindle/config.ex (modified, compiles clean, full suite green)
- FOUND commit 80ab4e1 (lib fix)
- FOUND commit ceebd03 (Task 1 proof test)

---
*Phase: 110-async-isolation-hardening*
*Completed: 2026-06-28*
