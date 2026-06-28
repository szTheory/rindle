---
phase: 109-subprocess-epipe-hardening
plan: 01
subsystem: infra
tags: [muontrap, subprocess, epipe, spawn_monitor, trap_exit, ffmpeg, regression-test, av]

# Dependency graph
requires:
  - phase: 109 (context/research)
    provides: Option-b1 locked shim design (D-01..D-17), the deterministic injection seam (D-08a), iteration counts (D-08b)
provides:
  - "Rindle.AV.Subprocess.run_isolated/5 — spawn_monitor + trap_exit'd worker that absorbs MuonTrap #98 :epipe at the single AV chokepoint"
  - "merge-blocking :epipe regression suite (deterministic synthetic + pre-reply retry + real-subprocess stress)"
  - ":canary excluded from both default-suite branches in test_helper.exs (load-bearing safety for Plan 02's canary)"
affects: [109-02, subprocess-epipe-hardening, ffmpeg, ffprobe, oban-av-workers]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "spawn_monitor + throwaway trap_exit'd worker as the async-exit isolation seam (parent monitors, never traps)"
    - "injectable run_fun (default &MuonTrap.cmd/3) as the idiomatic Elixir DI test seam — public 3-arity contract byte-identical"
    - "@doc false def (not defp) so the synthetic test calls the seam directly without apply/3 (mirrors build_opts/build_args)"

key-files:
  created:
    - test/rindle/av/subprocess_epipe_test.exs
  modified:
    - lib/rindle/av/subprocess.ex
    - test/test_helper.exs

key-decisions:
  - "run/3 delegates to @doc false run_isolated/5 (spawn_monitor + trap_exit'd worker); build_args/3 + build_opts/2 byte-unchanged (EPIPE-02/03)"
  - "bounded SINGLE retry on a pre-reply {:DOWN, :epipe} via explicit retries_left (D-05); one Logger.debug citing #98 (D-07); all other :DOWN -> exit(reason) (D-06)"
  - "retry-branch test pins the primary Logger level to :debug for Rindle.AV.Subprocess (Logger.put_module_level + on_exit cleanup) so the D-07 breadcrumb survives capture independent of the global level"
  - ":canary added to BOTH test_helper.exs exclude branches (D-12) — a bare @tag :canary can never gate a PR"

patterns-established:
  - "Async transport-signal isolation: own the risky port in a throwaway trap_exit'd worker; parent uses a MONITOR so the caller's :trap_exit flag is never mutated"
  - "Deterministic regression for an OS-race bug: inject the terminal signal via a run_fun seam (zero OS race) for determinism; a separate high-iteration real-subprocess stress test owns the fails-unpatched/passes-patched property"

requirements-completed: [EPIPE-01, EPIPE-02, EPIPE-03, EPIPE-04, EPIPE-05]

coverage:
  - id: D1
    description: "run/3 absorbs a terminal MuonTrap #98 :epipe and still returns the real {output, status}; no :epipe leaks to the caller"
    requirement: "EPIPE-01"
    verification:
      - kind: unit
        ref: "test/rindle/av/subprocess_epipe_test.exs#run_isolated absorbs a terminal :epipe and still returns the real {output, status}"
        status: pass
    human_judgment: false
  - id: D2
    description: "build_args/3 + build_opts/2 byte-unchanged; {collectable, non_neg_integer | :timeout} contract preserved; no shell; ffmpeg/ffprobe call sites untouched"
    requirement: "EPIPE-02"
    verification:
      - kind: unit
        ref: "test/rindle/av/subprocess_test.exs (5 tests, 0 failures)"
        status: pass
      - kind: other
        ref: "git diff lib/rindle/av/subprocess.ex — only require Logger + run/3 delegation line + appended run_isolated/5 + NOTE block; build_args/build_opts bodies unchanged"
        status: pass
    human_judgment: false
  - id: D3
    description: "Invariants 8–13 byte-equivalent at argv: shim sits between run/3 and MuonTrap.cmd, argv path untouched"
    requirement: "EPIPE-03"
    verification:
      - kind: other
        ref: "git diff lib/rindle/av/subprocess.ex — no changes to build_args/3 or build_opts/2"
        status: pass
    human_judgment: false
  - id: D4
    description: "New regression fails unpatched / passes patched; reproduces :epipe on high-output prompt-exit child across 300-iteration loop"
    requirement: "EPIPE-04"
    verification:
      - kind: integration
        ref: "test/rindle/av/subprocess_epipe_test.exs#run/3 never lets a broken-pipe (:epipe) exit kill the caller, even on large output"
        status: pass
    human_judgment: false
  - id: D5
    description: "Forward-compatible no-op on upstream fix; no leaked monitors/processes (demonitor [:flush] + after 0 drain); # NOTE block cites #98 + removal condition"
    requirement: "EPIPE-05"
    verification:
      - kind: unit
        ref: "test/rindle/av/subprocess_epipe_test.exs#run_isolated retries exactly once on a pre-reply :epipe death and emits one #98 breadcrumb"
        status: pass
    human_judgment: false

# Metrics
duration: 3min
completed: 2026-06-28
status: complete
---

# Phase 109 Plan 01: Subprocess :epipe Absorption Shim Summary

**`Rindle.AV.Subprocess.run/3` now delegates to a `spawn_monitor` + `trap_exit`'d worker (`run_isolated/5`) that absorbs the MuonTrap #98 broken-pipe `{:EXIT, port, :epipe}` async exit so it can never kill the caller, proven by a merge-blocking deterministic-synthetic + real-subprocess-stress regression suite.**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-06-28T17:03:53Z
- **Completed:** 2026-06-28T17:06:33Z
- **Tasks:** 3
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments
- Landed the Option-b1 `:epipe` absorption shim at the single AV chokepoint: `run/3` delegates to a new `@doc false def run_isolated/5` that owns the MuonTrap port inside a throwaway `spawn_monitor`'d, `trap_exit`'d worker; a late `{:EXIT, port, :epipe}` is drained (`after 0`) and dies with the worker. The parent MONITORS (never traps), so the caller's `:trap_exit` flag is never mutated (D-02).
- Bounded SINGLE retry on the rare pre-reply `{:DOWN, :epipe}` death via an explicit `retries_left` counter (D-05), emitting exactly one `Logger.debug` citing #98 (D-07); every other `:DOWN` reason re-raises via `exit(reason)` (D-06) so real failures are never masked.
- `build_args/3` and `build_opts/2` are byte-unchanged; the `{collectable, non_neg_integer | :timeout}` contract and the no-shell argv path are preserved by construction (EPIPE-02/EPIPE-03).
- Shipped the merge-blocking regression suite: deterministic synthetic drain-after-reply, deterministic pre-reply retry (with `Logger.debug` capture), and a 300-iteration `yes | head -n 100000` real-subprocess stress test (EPIPE-04). All three pass against the patched shim; the stress test would trip an unpatched `run/3`.
- Excluded `:canary` from BOTH `test_helper.exs` exclude branches (D-12) — the load-bearing safety so Plan 02's `@tag :canary` file can never gate a PR.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add `:canary` to test_helper.exs exclude branches** - `ec5266e` (test)
2. **Task 2: Implement run_isolated/5 :epipe absorption shim** - `ce18719` (fix)
3. **Task 3: Merge-blocking :epipe regression suite** - `5f1a813` (test)

_Task 2 carries `tdd="true"`; the implementation and its driving test (Task 3) were committed as the two distinct task commits per the plan's task split._

## Files Created/Modified
- `lib/rindle/av/subprocess.ex` - Added `require Logger`; replaced the inline `MuonTrap.cmd/3` in `run/3` with `run_isolated(cmd, modified_args, muon_opts, 1, &MuonTrap.cmd/3)`; appended the `# NOTE (EPIPE-07, MuonTrap #98)` block + the `@doc false def run_isolated/5` shim.
- `test/rindle/av/subprocess_epipe_test.exs` - NEW: three `@tag :regression`/`@tag :av` assertions (synthetic drain-after-reply, pre-reply retry branch, real-subprocess stress).
- `test/test_helper.exs` - Added `:canary` to both `exclude_tags` branches (load-bearing D-12 safety).

## Decisions Made
- **`@doc false def run_isolated/5` over `defp`** (RESEARCH Pitfall 2): mirrors the existing `@doc false def build_opts`/`build_args` precedent so the synthetic test calls the seam directly without `apply/3`.
- **Retry-branch test pins the Logger level explicitly** (deviation Rule 1, see below): `capture_log([level: :debug], ...)` alone returned an empty log because the primary Logger level gated the `:debug` record before the capture handler saw it. Added `Logger.put_module_level(Rindle.AV.Subprocess, :debug)` + an `on_exit` cleanup so the D-07 breadcrumb is captured deterministically regardless of the global level. This makes the test deterministic without weakening the assertion (still asserts exactly one `#98` line).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Pre-reply retry test captured an empty log under the default Logger level**
- **Found during:** Task 2/3 verification (`mix test ... --seed 0`)
- **Issue:** The plan's recommended `capture_log([level: :debug], fn -> ... end)` returned `""` on this Elixir 1.17/OTP 27 home cell — the primary Logger level filtered the `:debug` record before the capture handler received it, so `assert log =~ "muontrap/issues/98"` failed even though the retry path (counter == 2, `{"OK", 0}` returned) executed correctly.
- **Fix:** Added `Logger.put_module_level(Rindle.AV.Subprocess, :debug)` with an `on_exit/1` cleanup (`Logger.delete_module_level/1`) inside the retry test so the `:debug` breadcrumb survives the primary level filter. The assertion is unchanged in intent (still asserts exactly one `#98` line) and the production code (`Logger.debug` in the retry branch) is untouched.
- **Files modified:** test/rindle/av/subprocess_epipe_test.exs
- **Verification:** `mix test test/rindle/av/subprocess_epipe_test.exs --seed 0` → 3 tests, 0 failures (deterministic across `--seed 0` reruns).
- **Committed in:** `5f1a813` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (1 bug — test determinism)
**Impact on plan:** The fix is test-only and makes the D-07 assertion deterministic; the locked shim design and the production `Logger.debug` are byte-for-byte as specified. No scope creep; no production behavior change.

## Issues Encountered
None beyond the deviation above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- The shim, the merge-blocking regression suite, and the load-bearing `:canary` exclude are all in place.
- **Plan 02 is now unblocked:** it can ship the advisory `@tag :canary` file (probing the UNGUARDED `MuonTrap.cmd/3`), route it to the Nightly lane via `--include canary`, apply the TRUTH-01 PROJECT.md doc corrections (D-15/16/17 — invariant 13 "Rambo" + Key-Decisions "FFmpex + MuonTrap"), and add the CI grep enforcement step — none of which can gate a PR because `:canary` is now excluded by default.

## Self-Check: PASSED

- Files: `lib/rindle/av/subprocess.ex`, `test/rindle/av/subprocess_epipe_test.exs`, `test/test_helper.exs`, `109-01-SUMMARY.md` — all present.
- Commits: `ec5266e`, `ce18719`, `5f1a813` — all present in git history.

---
*Phase: 109-subprocess-epipe-hardening*
*Completed: 2026-06-28*
