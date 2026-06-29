---
phase: 110-async-isolation-hardening
plan: 03
subsystem: testing
tags: [async-isolation, async-safety-guard, global-repo-swap, meta-test, allowlist, ISO-04]

requires:
  - phase: 110-01
    provides: "Rindle.Config.put_repo_override/1 — the sanctioned setter the new rule's failure message points authors at"
  - phase: 110-02
    provides: "process-scoped CountingFailingTxnRepo (no global :rindle,:repo swap) so the counting double is NOT an offender / NOT allowlisted"
provides:
  - "test/async_safety_guard_test.exs :global_repo_swap rule + all-modules scan path + @primitive_names entry"
  - "9 legitimate :rindle/:repo swapper modules carrying @async_safety_allow [:global_repo_swap]"
affects: [110-04]

tech-stack:
  added: []
  patterns:
    - "separate all-modules AST scan path (parse_all_modules/1) applying ONLY the :global_repo_swap classifier, honoring @async_safety_allow on async:false modules"

key-files:
  created: []
  modified:
    - test/async_safety_guard_test.exs
    - test/rindle/config/config_test.exs
    - test/rindle/storage/local_tus_test.exs
    - test/rindle/workers/maintenance_workers_test.exs
    - test/rindle/ops/upload_maintenance_test.exs
    - test/rindle/upload/broker_test.exs
    - test/rindle/upload/tus_plug_test.exs
    - test/rindle/upload/tus_local_backing_test.exs
    - test/rindle/upload/lifecycle_integration_test.exs
    - test/adopter/canonical_app/lifecycle_test.exs

key-decisions:
  - "D-07/D-11: classify_global_repo_swap/1 pins [:rindle, :repo | _] so :rindle,:repo_probe_owner and :rindle,:counting_failing_txn_repo are NOT flagged"
  - "D-08: new rule scans EVERY module via parse_all_modules/1 (mirrors parse_async_true_modules/1 minus the async filter); existing async:true-only classifiers + their two tests are byte-unchanged"
  - "D-09: 9 legitimate adopter/probe-repo swappers each get @async_safety_allow [:global_repo_swap] + a # why: comment"
  - "D-10: config_test keeps put_env (tests the app-env resolution path itself) and is allowlisted, not migrated"
  - "lifecycle_integration_test: the allow attribute lives in the 2nd module (AdopterRepoLifecycleIntegrationTest), which owns the swap at line 478 — not the first module"
  - "counting double (test/support/counting_failing_txn_repo.ex) is NOT allowlisted (Plan 02 removed its global swap)"
  - "Test-only change: commits use test: (NOT fix:) so release-please does not re-trigger the 0.3.2 patch publish — the phase's only lib/ touch was 110-01"

patterns-established:
  - "Pattern: an all-modules (async-flag-agnostic) meta-test pass forbids a globally-read library config key swap anywhere in the test tree, with a per-module allowlist escape hatch + # why: justification"

requirements-completed: [ISO-04]

coverage:
  - id: D1
    description: ":global_repo_swap rule added (classify_global_repo_swap/1 + collect_global_repo_swaps/1 + parse_all_modules/1 all-modules scan + @primitive_names entry); failure message names Config.put_repo_override/1; flags only :rindle,:repo (not :repo_probe_owner / :counting_failing_txn_repo); existing two tests + classifiers unchanged"
    requirement: "ISO-04"
    verification:
      - kind: other
        ref: "RED probe: pre-allowlist run flagged exactly the 9 swapper files (only the :repo key, lifecycle_integration:478 attributed to the 2nd module); 2 existing tests stayed green"
        status: pass
      - kind: integration
        ref: "mix test test/async_safety_guard_test.exs => 3 tests, 0 failures (after allowlists)"
        status: pass
  - id: D2
    description: "9 legitimate swappers allowlisted with # why: comments; counting double NOT allowlisted; negative probe proved the rule fires then was reverted; full guard suite green; mix compile --warnings-as-errors clean"
    requirement: "ISO-04"
    verification:
      - kind: other
        ref: "negative probe (transient put_env(:rindle,:repo,Foo) in the non-allowlisted guard module) -> :global_repo_swap test RED at async_safety_guard_test.exs:80; reverted -> 3/0 green"
        status: pass
      - kind: other
        ref: "grep gate: all 9 files carry async_safety_allow + :global_repo_swap; ! grep async_safety_allow counting_failing_txn_repo.ex; mix compile --warnings-as-errors exit 0"
        status: pass
    human_judgment: false

duration: 4min
completed: 2026-06-28
status: complete
---

# Phase 110 Plan 03: `:global_repo_swap` async-safety guard rule + 9-swapper allowlist Summary

**The v1.20 async-safety guard now scans EVERY test module (async-flag-agnostic) and red-gates any `Application.put_env`/`delete_env(:rindle, :repo, …)` outside a per-module `@async_safety_allow [:global_repo_swap]`, pointing authors at the sanctioned `Config.put_repo_override/1` — making the global-repo-swap footgun un-reintroducible; the 9 legitimate adopter/probe swappers are allowlisted and the suite is green (3/0).**

## Performance

- **Duration:** 4 min
- **Tasks:** 2
- **Files modified:** 10

## What Was Built

- **`:global_repo_swap` rule (Task 1, `test/async_safety_guard_test.exs`):**
  - `:global_repo_swap` added to `@primitive_names`.
  - New `parse_all_modules/1` — mirrors `parse_async_true_modules/1` MINUS the
    `Enum.filter(&async_true?/1)` line (D-08), returning every module
    (`%{module, relpath, allow, body}`) and honoring the existing
    `@async_safety_allow` allowlist on the now-scanned `async: false` modules.
    `setup_all` builds an `all_modules` list alongside the unchanged `modules` list.
  - `classify_global_repo_swap/1` matches the research §iv locked AST shape
    `{{:., meta, [{:__aliases__, _, [:Application]}, m]}, _, [:rindle, :repo | _]}`
    when `m in [:put_env, :delete_env]`. The `[:rindle, :repo | _]` head pins the
    first two positional args so `:rindle, :repo_probe_owner` and
    `:rindle, :counting_failing_txn_repo` (D-11) are NOT flagged.
  - `collect_global_repo_swaps/1` — a separate prewalk pass applying ONLY the new
    classifier (the existing `collect_offenders/2` + its classifiers are untouched).
  - A THIRD test asserts zero offenders over `all_modules`, with a dedicated
    `global_repo_swap_failure_message/1` that directs authors to
    `Rindle.Config.put_repo_override/1` (cleared via `delete_repo_override/0`).
  - The two existing tests, `parse_async_true_modules/1`, `async_true?/1`, and every
    existing `classify/2` clause are byte-unchanged.

- **9-swapper allowlist (Task 2):** each legitimate `:rindle, :repo` swapper carries
  `@async_safety_allow [:global_repo_swap]` + a one-line `# why:` comment under its
  `use ... async: false` line:
  - `config/config_test` (D-10 rationale: tests the app-env resolution path itself,
    keeps `put_env`), `storage/local_tus_test`, `workers/maintenance_workers_test`,
    `ops/upload_maintenance_test`, `upload/broker_test`, `upload/tus_plug_test`,
    `upload/tus_local_backing_test`, `adopter/canonical_app/lifecycle_test`, and
    `upload/lifecycle_integration_test` (allow placed in the **2nd** module
    `Rindle.Upload.AdopterRepoLifecycleIntegrationTest`, which owns the swap at line 478).
  - `test/support/counting_failing_txn_repo.ex` is NOT allowlisted — Plan 02 removed
    its global swap, so it is correctly not an offender.

## Tasks

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Add :global_repo_swap rule + all-modules scan path to the guard | 77aad32 | test/async_safety_guard_test.exs |
| 2 | Allowlist the 9 legitimate :rindle/:repo swappers + negative-probe | 52574ec | 9 swapper test modules |

_TDD note: both tasks carried `tdd="true"`, but the phase config has `tdd_mode: false` and the plan's `done` criteria specify the gate as the third test + negative probe + `mix compile --warnings-as-errors` (no standalone RED test file is created — Plan 04 supplies the concurrency proof). Consistent with Plans 01/02; not a gap. The Task 1 commit IS the rule's RED-by-design state (the suite went red on the 9 swappers until Task 2's allowlists landed), and the Task 2 negative probe is the GREEN-proving RED→revert._

## Verification

- `grep ':global_repo_swap' test/async_safety_guard_test.exs` → present (`@primitive_names`, classifier, failure message).
- `grep -cE 'put_repo_override' test/async_safety_guard_test.exs` → 2 (failure-message references).
- **RED probe (Task 1, pre-allowlist):** the new test flagged exactly the 9 swapper files — only the `:repo` key (`:repo_probe_owner` NOT flagged), `lifecycle_integration_test:478` attributed to the 2nd module — while the 2 existing tests stayed green.
- **Negative probe (Task 2):** a transient `Application.put_env(:rindle, :repo, NegativeProbeRepo)` in the non-allowlisted guard module drove the `:global_repo_swap` test RED at `async_safety_guard_test.exs:80`; reverted from a backup (NegativeProbeRepo grep → 0).
- `mix test test/async_safety_guard_test.exs` → **3 tests, 0 failures** (0.4s async) with the allowlists in place.
- All 9 files carry `async_safety_allow` + `:global_repo_swap`; `! grep async_safety_allow counting_failing_txn_repo.ex` → clean.
- `mix compile --warnings-as-errors` → exit 0 (no unused-attribute or other warnings).

## Decisions Made

- Followed the plan exactly: D-07 classifier shape, D-08 separate all-modules scan, D-09 9-module allowlist, D-10 config_test kept on `put_env`, D-11 `:repo`-only scope.
- The `lifecycle_integration_test.exs` allow attribute was placed in the 2nd module (`AdopterRepoLifecycleIntegrationTest`) per the grep-verified ownership of the swap, not the first module — a parse-correctness detail the per-module scan requires.
- Commit types: `test(110-03)` for both — deliberately NOT `fix:`, so release-please does not re-bundle these into a publish; the phase's only `lib/` touch (the 0.3.2 trigger) was Plan 01.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — meta-test/CI-enforcement change only. No external input, no auth/data-flow surface, no schema/migration changes. The plan's `<threat_model>` T-110-04 (re-introduction of the global-repo-swap footgun) is mitigated exactly as specified and verified by the Task 2 negative probe.

## Next Phase Readiness

- ISO-04 satisfied: the `:global_repo_swap` rule is live, allowlist-honored, `:repo`-scoped, and merge-blocking; the 9 legitimate swappers are documented and green.
- Plan 04's ISO-05 concurrency/isolation proof test can rely on the guard preventing any new global swap from re-polluting the process-scoped double exercised under async contention.

## Self-Check: PASSED

- FOUND: test/async_safety_guard_test.exs (:global_repo_swap rule + all-modules scan, compiles clean)
- FOUND: 9 swapper modules carry @async_safety_allow [:global_repo_swap]
- FOUND: test/support/counting_failing_txn_repo.ex NOT allowlisted
- FOUND commit 77aad32 (Task 1)
- FOUND commit 52574ec (Task 2)

---
*Phase: 110-async-isolation-hardening*
*Completed: 2026-06-28*
