---
phase: 109-subprocess-epipe-hardening
verified: 2026-06-28T20:55:00Z
status: passed
score: 6/6 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification: # No previous VERIFICATION.md — initial verification
---

# Phase 109: Subprocess :epipe Hardening Verification Report

**Phase Goal:** `Rindle.AV.Subprocess.run/3` never lets a broken-pipe transport exit (MuonTrap #98) kill its caller — making every AV invocation deterministic in tests AND in adopter Oban workers — and the stale security-invariant-13 prose is corrected to the actual MuonTrap-only path.
**Verified:** 2026-06-28T20:55:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria + PLAN must_haves)

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | `Subprocess.run/3` never propagates `:epipe`; caller still receives real `{output, status}` (EPIPE-01) | ✓ VERIFIED | `run/3` delegates to `run_isolated/5` (subprocess.ex:17); worker owns the port, drains late `{:EXIT, port, _}` via `receive ... after 0` (lines 44-49); parent monitors, never traps. Synthetic test injects `{:EXIT, port, :epipe}` and `refute_received {:EXIT, _, :epipe}` passes; 300-iter real-subprocess stress passes. `mix test subprocess_epipe_test.exs` → 3 tests, 0 failures. |
| 2 | Contract preserved (`{collectable, status \| :timeout}`, `into: ""`, `stderr_to_stdout: true`); invariants 8–13 byte-equivalent at argv; `build_args`/`build_opts` unchanged; no shell; Ffmpeg/Ffprobe call sites unchanged (EPIPE-02) | ✓ VERIFIED | `git diff ce18719~1..ce18719` shows ONLY `require Logger`, the single run/3 delegation swap, and appended NOTE + `run_isolated/5`. `build_args/3` + `build_opts/2` byte-unchanged. Call sites (`waveform.ex`, `ffmpeg.ex`, `av/audio.ex`, `av/video.ex`, `ffprobe.ex`) all still `Subprocess.run("ffmpeg"/"ffprobe", args)` with `{output, status}` pattern. `subprocess_test.exs` + `security/` → 24 tests, 0 failures. No shell (argv-list). |
| 3 | A legitimate ffmpeg cap-hit early-exit reported via real exit status, never `:epipe` (EPIPE-03) | ✓ VERIFIED | Shim sits BELOW run/3 / ABOVE MuonTrap.cmd, never on argv path; `{^ref, result}` returns the real `{output, status}` unmasked. `build_args` (`-timelimit`/`-t`/`-fs`) byte-unchanged. Non-`:epipe` deaths re-raise via `exit(reason)` (line 66, D-06) — real failures never masked. Security suite (19 tests) green. |
| 4 | Deterministic `@tag :regression` repro fails unpatched / passes patched; two flaking tests pass unmodified; shim no-op-degrades on upstream fix (no leaked monitors/processes); comment cites #98 (EPIPE-04/EPIPE-05) | ✓ VERIFIED | 3 `@tag :regression @tag :av` assertions pass patched (synthetic drain, pre-reply retry w/ one #98 Logger.debug, 300-iter stress). Flaking tests `ffmpeg_test.exs` + `lifecycle_repair_test.exs` byte-unchanged since pre-109 (last touched 45b51ab/1cfb960) → 14 tests, 0 failures. No-op degradation: `after 0` drains nothing if no `:epipe`, `{ref, result}` always wins, `demonitor [:flush]` leaks nothing. NOTE block cites #98 URL + removal condition (subprocess.ex:20-33). |
| 5 | `:canary` excluded from BOTH default-suite branches; advisory canary probes UNGUARDED `MuonTrap.cmd/3`, fails loudly with removal coordinates; routed nightly `--include canary` + `continue-on-error: true`, never PR gate (EPIPE-05/D-12) | ✓ VERIFIED | `grep -c ":canary" test_helper.exs` → 2 (both branches). Bare `mix test canary_test.exs` → 0 tests, 1 excluded. Canary probes `MuonTrap.cmd("sh", [...])` (never `Subprocess.run`), 500 iters, loud message names #98 URL + `Application.spec(:muontrap, :vsn)` + shim file + canary file + regression test. Nightly step (`grep -c ... --include canary` → 1) has `continue-on-error: true` in `compat-matrix`. |
| 6 | PROJECT.md invariant 13's stale "Rambo on macOS/Windows" clause corrected to MuonTrap-only path; Key-Decisions `(FFmpex + MuonTrap)` → `(MuonTrap runner; argv built in-house, not FFmpex)`; merge-blocking CI grep guard (TRUTH-01) | ✓ VERIFIED | PROJECT.md:458-464 reads "MuonTrap is the sole subprocess runner on every platform... cgroup caps Linux-only... There is no Rambo dependency." Key-Decisions:508 reads "(MuonTrap runner; argv built in-house, not FFmpex)". No Rambo in mix.lock. TRUTH-01 grep guard runs in the `quality` PR-gating job (ci.yml:87-93), simulated locally → `TRUTH-01-OK` (exit 0). `name: CI` + filename byte-unchanged. |

**Score:** 6/6 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/rindle/av/subprocess.ex` | `@doc false def run_isolated/5` + `require Logger` + NOTE block | ✓ VERIFIED | All present (lines 6, 20-33, 34-68); wired via run/3:17; build_args/opts untouched |
| `test/rindle/av/subprocess_epipe_test.exs` | 3 `@tag :regression @tag :av` assertions | ✓ VERIFIED | 3 tests, 0 failures; deterministic across `--seed 0` |
| `test/test_helper.exs` | `:canary` in both exclude branches | ✓ VERIFIED | Both branches (lines 27, 28); `:regression`/`:av` NOT excluded |
| `test/rindle/av/subprocess_epipe_canary_test.exs` | advisory tripwire, `@moduletag :canary` + `:av` | ✓ VERIFIED | Probes UNGUARDED MuonTrap.cmd, 500 iters, loud removal message |
| `.github/workflows/nightly.yml` | `--include canary` step, `continue-on-error: true` | ✓ VERIFIED | compat-matrix:125-127, after coverage step |
| `.planning/PROJECT.md` | invariant-13 + Key-Decisions corrected | ✓ VERIFIED | Lines 458-464, 508; Rindle.tmp/Ops-reaper sentence preserved |
| `.github/workflows/ci.yml` | merge-blocking TRUTH-01 grep guard in PR lane | ✓ VERIFIED | `quality` job, ci.yml:87-93; `name: CI` unchanged |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `run/3` | `run_isolated/5` | `run_isolated(cmd, modified_args, muon_opts, 1, &MuonTrap.cmd/3)` | ✓ WIRED | subprocess.ex:17; lines 14-16 byte-identical |
| synthetic test | `run_isolated/5` | direct `@doc false def` arity call (no apply/3) | ✓ WIRED | epipe_test.exs:31,65 inject run_fun |
| `:canary` exclude | Plan 02 canary | test_helper.exs both branches | ✓ WIRED | bare `mix test` → 1 excluded |
| nightly `--include canary` | canary file | overrides default exclude | ✓ WIRED | nightly.yml:127 |
| TRUTH-01 grep | PROJECT.md prose | ci.yml quality-lane grep | ✓ WIRED | guard simulates to TRUTH-01-OK |

### Prohibition Checks (must_haves.prohibitions, D-02/D-03)

| Prohibition | Status | Evidence |
| --- | --- | --- |
| D-02: no permanent caller `:trap_exit` mutation; trap_exit ONLY inside throwaway worker; parent monitors not traps | ✓ VERIFIED (judgment) | `Process.flag(:trap_exit, true)` appears ONLY at line 41 inside the `spawn_monitor` closure; parent path uses `spawn_monitor` + `Process.demonitor(mon, [:flush])`, no trap_exit on caller |
| D-03: no `Task.async`/`Task.Supervisor.async_nolink`/`GenServer`; must be spawn_monitor + trap_exit'd worker | ✓ VERIFIED (judgment) | `grep "Task\."` → 0; `grep "GenServer"` → 0; `spawn_monitor` present at line 40 |

Both prohibitions are judgment-tier and deterministically verified by grep — the must-NOT conditions did not occur. Not flagged.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Regression suite passes patched (EPIPE-01/04/05) | `mix test subprocess_epipe_test.exs --seed 0` | 3 tests, 0 failures | ✓ PASS |
| Flaking tests pass unmodified (EPIPE-04) | `mix test ffmpeg_test.exs lifecycle_repair_test.exs --seed 0` | 14 tests, 0 failures | ✓ PASS |
| Contract + argv invariants preserved (EPIPE-02/03) | `mix test subprocess_test.exs security/ --seed 0` | 24 tests, 0 failures | ✓ PASS |
| Canary excluded from default suite (D-12) | `mix test canary_test.exs` | 0 tests, 1 excluded | ✓ PASS |
| TRUTH-01 grep guard | (ci.yml guard simulated locally) | TRUTH-01-OK, exit 0 | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| EPIPE-01 | 109-01 | run/3 never propagates :epipe; real {output,status} returned | ✓ SATISFIED | Truth 1; regression suite green |
| EPIPE-02 | 109-01 | Contract + invariants 8–13 byte-equivalent; call sites unchanged | ✓ SATISFIED | Truth 2; git diff scoped to 3 changes |
| EPIPE-03 | 109-01 | cap-hit early-exit via real status, never :epipe | ✓ SATISFIED | Truth 3; security suite green |
| EPIPE-04 | 109-01 | deterministic regression fails unpatched/passes patched; flaking tests unmodified | ✓ SATISFIED | Truth 4; flaking tests byte-unchanged + green |
| EPIPE-05 | 109-01, 109-02 | forward-compat no-op; no leaked monitors; canary signal; #98 comment | ✓ SATISFIED | Truths 4, 5; NOTE block + advisory canary |
| TRUTH-01 | 109-02 | invariant-13 Rambo clause corrected to MuonTrap-only | ✓ SATISFIED | Truth 6; PROJECT.md + CI grep guard |

All 6 phase requirement IDs declared in PLAN frontmatter are present in REQUIREMENTS.md (lines 24-28, 61), marked `[x]`, and mapped to Phase 109 (status Complete, lines 89-94). No orphaned requirements.

### Anti-Patterns Found

None. No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` in any phase-modified file. No stub returns, no hollow props, no console-only implementations.

### Human Verification Required

None. All truths verified programmatically via deterministic tests, git-diff scope checks, grep guards, and behavioral spot-checks. The one inherently-probabilistic behavior (the OS-race canary actually reproducing #98) is by-design advisory-only (`continue-on-error: true`, never gates), so its non-reproduction on a dev cell is not a goal-blocking gap — the load-bearing correctness properties (verbatim body, all four removal coordinates, default-suite exclusion) are all verified.

### Gaps Summary

No gaps. The phase goal is fully achieved in the codebase:
- The `:epipe` absorption shim (`run_isolated/5`) is implemented, wired at the single AV chokepoint, and proven by a merge-blocking deterministic + stress regression suite that passes patched.
- The contract and security invariants 8–13 are byte-equivalent by construction (git diff confirms `build_args`/`build_opts` untouched; call sites unchanged).
- The locked design prohibitions (D-02 worker-scoped trap_exit + parent monitor; D-03 no Task/GenServer) hold.
- The advisory cleanup canary, its nightly home, and the `:canary` default-suite exclusion are all in place.
- PROJECT.md invariant 13 + Key-Decisions row are corrected to the MuonTrap-only path, guarded by a merge-blocking CI grep in the PR-gating `quality` lane, with `name: CI`/filename unchanged.

---

_Verified: 2026-06-28T20:55:00Z_
_Verifier: Claude (gsd-verifier)_
