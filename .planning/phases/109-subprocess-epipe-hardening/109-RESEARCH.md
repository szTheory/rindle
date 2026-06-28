# Phase 109: Subprocess `:epipe` hardening - Research

**Researched:** 2026-06-28
**Domain:** Elixir/OTP subprocess signal handling (MuonTrap port driver, `:epipe` async exit)
**Confidence:** HIGH

> **APPROACH IS LOCKED.** The macro design is Option b1 (`spawn_monitor` + `trap_exit`'d worker
> shim around `MuonTrap.cmd/3`), research-locked at HIGH confidence in `v1.21-SUBPROCESS-EPIPE.md`
> and pinned by CONTEXT.md D-01..D-17. This document does NOT redesign anything. It resolves only
> the items CONTEXT.md left to "researcher/planner discretion": the deterministic-test injection
> seam (D-08a), the stress/canary iteration counts (D-08b/D-11), the advisory-lane mechanism (D-12),
> the `Logger.debug` string (D-07), and verifies the TRUTH-01 wording (D-15/16/17) against source.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions (the contract — do not relitigate)
- **D-01** `spawn_monitor` + `trap_exit`'d worker shape. `run/3` delegates to a new private `run_isolated/4` that `spawn_monitor`s a closure setting `Process.flag(:trap_exit, true)`, runs `MuonTrap.cmd/3`, `send`s `{ref, result}` to parent, then non-blockingly drains a late `{:EXIT, port, _}` (`receive ... after 0`). Parent selective-`receive`s `{ref, result}` → `Process.demonitor(mon, [:flush])` → return; or `{:DOWN, ...}`.
- **D-02** Reject in-place `trap_exit` (mutates caller's flag; mailbox cross-contamination). Worker uses trap_exit; parent uses a MONITOR (not link); `:DOWN` reason delivers regardless of parent trap_exit state.
- **D-03** Reject `Task.async` (links → propagates), `Task.Supervisor.async_nolink` (pulls supervisor dep), GenServer port-owner (wrong altitude).
- **D-04** Worker inner drain tightened to `{:EXIT, port, _} when is_port(port)`.
- **`build_args/3` and `build_opts/2` byte-untouched.**
- **D-05** Defensive `{:DOWN, ^mon, :process, ^pid, :epipe}` branch retries `run_isolated` EXACTLY ONCE via explicit `retries_left` counter (`run_isolated(cmd, args, opts, 1)` initial). NOT unbounded recursion.
- **D-06** All other `{:DOWN, ..., reason}` (genuine crash OR `:epipe` after retry exhausted) → `exit(reason)`. `:timeout` flows through `{ref, result}` (it is a MuonTrap return value, not an exit).
- **D-07** NO telemetry. Happy-path drained-epipe is SILENT. Emit ONE `Logger.debug/1` citing #98 ONLY in the rare pre-reply `:DOWN/:epipe` retry branch.
- **D-08** Two `@tag :regression` assertions in `test/rindle/av/subprocess_epipe_test.exs`, both merge-blocking. (a) deterministic synthetic; (b) bounded real-subprocess stress (owns EPIPE-04). `Process.flag(:trap_exit, true)` + `refute_received {:EXIT, _, :epipe}`.
- **D-09** The two originally-flaking tests pass UNMODIFIED.
- **D-10** Reject version-pinned tripwire (bug present in 1.7.0/1.8.0/2.0.0-rc.0; no fixed boundary).
- **D-11** Behavioral canary in `test/rindle/av/subprocess_epipe_canary_test.exs` probing UNGUARDED `MuonTrap.cmd/3`; asserts `:epipe` still reproduces; fails loudly when upstream fixes #98.
- **D-12** Canary is advisory-only; tag `:canary` (+ `:av`); OUT of merge-blocking PR gate.
- **D-13** `# NOTE (EPIPE-07, MuonTrap #98):` comment block above `run_isolated` with URL, OPEN status, affected versions, removal condition, canary coupling.
- **D-14** No-op degradation provable & double-handling-safe (EPIPE-05). One-line CHANGELOG `fix:` note. Ships `fix:` → Hex 0.3.2.
- **D-15/16/17** TRUTH-01 PROJECT.md doc corrections (invariant 13 wording; Key-Decisions row; Tier-A-only scope).

### Claude's Discretion (resolved in this doc)
- Exact internal injection seam for the deterministic synthetic test (D-08a) → §1.
- Precise iteration counts for D-08b / D-11 → §2, §3.
- The `Logger.debug` message string → §5.

### Deferred Ideas (OUT OF SCOPE)
- Upstream MuonTrap #98 fix (out-of-band).
- Eventual shim+canary removal (future cleanup, governed by D-13 removal condition).
- Async-isolation `Config.repo/0` `$callers` override → **Phase 110**.
- Durable shipped-artifact regression-lock meta-tests → **Phase 111**.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EPIPE-01 | `run/3` MUST NOT propagate `{:EXIT, port, :epipe}` to caller; benign terminal `:epipe` still returns real `{output, status}` | §1 (deterministic seam proves absorption), §7 (control-flow soundness) |
| EPIPE-02 | Exact contract preserved: `{collectable, non_neg_integer() \| :timeout}`; call sites in `ffmpeg.ex`/`ffprobe.ex` matching `{output, 0}`/`{output, status}` unchanged | Verified: call sites read (only pattern-match the tuple), `build_args/build_opts` byte-frozen |
| EPIPE-03 | Invariants 8–13 byte-equivalent at argv: `build_args/3` + `build_opts/2` unchanged, no shell | Verified: shim sits between `run/3` and `MuonTrap.cmd/3`; argv path untouched (§7) |
| EPIPE-04 | New regression test fails unpatched / passes patched; reproduces `:epipe` on high-output prompt-exit child across high-iteration loop | §2 (stress test N + iterations + wall-time budget) |
| EPIPE-05 | Forward-compatible no-op on upstream fix; no double-handling / leaked monitors/processes; code comment citing #98 | D-13/D-14 verified sound against `port.ex` (§7); `demonitor [:flush]` + `after 0` drain |
| TRUTH-01 | Correct PROJECT.md invariant-13 stale "Rambo on macOS/Windows" prose | §6 (D-15/16/17 verified byte-accurate against C source + mix.lock) |
</phase_requirements>

## Summary

The fix is fully specified by CONTEXT.md. Reading the live source confirms every load-bearing claim:
`Rindle.AV.Subprocess.run/3` (`lib/rindle/av/subprocess.ex:11-16`) calls `MuonTrap.cmd(cmd, modified_args, muon_opts)` inline; the call sites only pattern-match `{output, 0}` / `{output, status}`; and MuonTrap's `port.ex` `do_cmd/4` (lines 42-55) calls `report_bytes_handled/2` per chunk, which does `Port.command(port, ...)` (line 105) — the write that produces the async `{:EXIT, port, :epipe}`. Its `rescue ArgumentError` (line 112) catches only the synchronous failure mode, never the async exit signal. The b1 shim is the correct, minimal interposition.

This document resolves the open discretion items with concrete, planner-ready answers: (1) a tiny optional-arity test seam on `run_isolated` that lets the synthetic test inject a terminal `{:EXIT, port, :epipe}` with **zero OS race**; (2) `sh -c "yes | head -n 100000"`, `use_cgroups: false`, **300 iterations**, ~30-45s wall budget for the merge-blocking stress test; (3) **500 iterations** for the advisory canary; (4) the exact `Logger.debug` string; (5) byte-accurate verification of the D-15 invariant-13 rewrite against `deps/muontrap/c_src/muontrap.c`. The advisory-lane question is **resolved with good news**: a real `Nightly` lane exists (`.github/workflows/nightly.yml`), but it runs `mix coveralls` with the default exclude list and does NOT `--include canary`, so the **load-bearing fallback applies**: exclude `:canary` from the default suite so it can never gate PRs, and (optionally) add an explicit `--include canary` step to nightly.

**Primary recommendation:** Implement the D-01 shim verbatim with a 4th `retries_left` arg; add an optional 5th private-arity seam `run_isolated/5` (or an injectable `run_fun`) that the synthetic test uses to drive the absorption path deterministically while `run/3`'s public 3-arity contract stays byte-identical. Stress test = `yes | head -n 100000` × 300 iters merge-blocking; canary = unguarded `MuonTrap.cmd/3` × 500 iters tagged `:canary` and excluded from the PR gate.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Subprocess signal absorption (`:epipe` shim) | API / Backend (library internals) | — | The race lives in MuonTrap's port driver, reached only through `Subprocess.run/3` — the single chokepoint Rindle controls |
| argv construction + security caps (invariants 8–13) | API / Backend | — | `build_args/3`/`build_opts/2`; byte-frozen this phase |
| Parent-death kill + cgroup caps | OS / subprocess (MuonTrap C wrapper) | — | Unchanged — shim only changes which BEAM process owns the port |
| Regression/canary validation | Test infra (ExUnit) + CI lanes | — | Merge-blocking lane (regression) vs advisory Nightly lane (canary) |
| TRUTH-01 doc correction | Docs (PROJECT.md Tier A) | — | Text-string-targeted edit, archived artifacts untouched |

---

## §1 — D-08a: Deterministic synthetic test injection seam (the key open item)

### The problem with a "natural" deterministic test
You cannot deterministically force MuonTrap's port to emit `{:EXIT, port, :epipe}` from a real
subprocess — that IS the OS race (#98). Any test that runs a real child and hopes the epipe fires
is the stress test (§2), not a deterministic one. The deterministic test must drive the **shim's
absorption code path directly**, by injecting the terminal signal into the worker's mailbox / the
parent's receive, with no subprocess and no timing dependency.

### Recommended seam — an injectable inner-run function (smallest seam, public contract byte-identical)

Make `run_isolated` accept an **optional run-fun** as its last argument. `run/3` never passes it
(defaults to the real `&MuonTrap.cmd/3`), so the public 3-arity contract is byte-identical. The test
passes a fun that (a) returns the real `{output, status}` AND (b) sends a terminal
`{:EXIT, self_port_stub, :epipe}` to the worker so the `after 0` drain and the parent's
`demonitor [:flush]` are both exercised deterministically.

**Shape in `subprocess.ex`** (the planner writes the final code; this pins the seam contract):

```elixir
def run(cmd, args, opts \\ []) do
  opts = Keyword.put_new(opts, :use_cgroups, default_use_cgroups?())
  muon_opts = build_opts(opts)
  modified_args = build_args(cmd, args, opts)
  # Public path: real runner, single retry budget. Contract byte-identical.
  run_isolated(cmd, modified_args, muon_opts, 1, &MuonTrap.cmd/3)
end

# NOTE (EPIPE-07, MuonTrap #98): https://github.com/fhunleth/muontrap/issues/98 (OPEN as of
# 2026-06; reproduces in 1.7.0 / 1.8.0 / 2.0.0-rc.0). MuonTrap ACKs consumed stdout bytes by
# writing to its wrapper's stdin (port.ex report_bytes_handled/2 -> Port.command/2). When the
# child closes after the last chunk, that ACK write hits a dead reader and the port delivers an
# async {:EXIT, port, :epipe} to its OWNER. MuonTrap's `rescue ArgumentError` catches only the
# synchronous failure; this async exit kills the inline caller. We own the port in a throwaway
# trap_exit'd worker so the signal dies with the worker, and surface the real {output, status}.
# Removal condition: #98 fixed AND the :muontrap pin bumped to the fixed version. The live signal
# is test/rindle/av/subprocess_epipe_canary_test.exs — do NOT delete that canary without deleting
# this shim.
#
# `run_fun` is a test seam (default &MuonTrap.cmd/3); it lets the deterministic regression test
# drive the absorption path with no OS race. run/3 never passes it, so the public contract is
# byte-identical.
defp run_isolated(cmd, args, muon_opts, retries_left, run_fun) do
  parent = self()
  ref = make_ref()

  {pid, mon} =
    spawn_monitor(fn ->
      Process.flag(:trap_exit, true)
      result = run_fun.(cmd, args, muon_opts)
      send(parent, {ref, result})
      # Drain a possible late {:EXIT, port, :epipe} so it can't escape the worker.
      receive do
        {:EXIT, port, _reason} when is_port(port) -> :ok
      after
        0 -> :ok
      end
    end)

  receive do
    {^ref, result} ->
      Process.demonitor(mon, [:flush])
      result

    {:DOWN, ^mon, :process, ^pid, :epipe} when retries_left > 0 ->
      Logger.debug(
        "Rindle.AV.Subprocess: absorbed a pre-reply MuonTrap #98 :epipe exit; retrying once " <>
          "(see https://github.com/fhunleth/muontrap/issues/98)"
      )
      run_isolated(cmd, args, muon_opts, retries_left - 1, run_fun)

    {:DOWN, ^mon, :process, ^pid, reason} ->
      exit(reason)
  end
end
```

> Seam justification (D-02-style minimalism): the injectable `run_fun` is the **smallest** seam that
> makes the absorption path test-injectable. It adds zero public surface (private arity), zero deps,
> and zero behavior change on the production path. Alternatives considered and rejected: (a) a
> `Process.register`/message-injection-against-the-worker-mailbox approach — fragile, needs the
> worker pid which is internal; (b) exposing `run_isolated` publicly — widens API; (c) an
> `Application.get_env` runner override — global mutable state, async-test-hostile. The fun-arg is
> the idiomatic Elixir dependency-injection seam.

### Exact synthetic assertion shape (deterministic, no OS race)

```elixir
# test/rindle/av/subprocess_epipe_test.exs
@tag :regression
@tag :av
test "run_isolated absorbs a terminal :epipe and still returns the real {output, status}" do
  Process.flag(:trap_exit, true)

  # Inject a runner that returns the real contract AND fires a terminal {:EXIT, port, :epipe}
  # into the worker's mailbox so the drain + demonitor path runs deterministically — no subprocess.
  fake_port = Port.list() |> List.first() || :erlang.open_port({:spawn, "true"}, [:binary])
  run_fun = fn _cmd, _args, _opts ->
    send(self(), {:EXIT, fake_port, :epipe})
    {"OK", 0}
  end

  # Reach the private seam via the byte-identical wrapper used in run/3.
  assert {"OK", 0} =
           apply(Rindle.AV.Subprocess, :run_isolated, ["echo", ["x"], [], 1, run_fun])

  # The caller survived and no stray :epipe leaked into our mailbox.
  refute_received {:EXIT, _, :epipe}
end
```

Notes for the planner:
- `run_isolated` is `defp`; the test reaches it via `apply/3` (the function still exists at runtime).
  If the planner prefers, mark it `@doc false` `def run_isolated/5` instead of `defp` — both keep it
  out of the public/documented API. `apply` on a `defp` works in-module-compiled BEAM; the cleaner
  choice is `@doc false def run_isolated/5` so the test calls it directly without `apply`. **Recommend
  `@doc false def` over `defp`** for testability (mirrors the existing `@doc false def build_opts`).
- A simpler, equally-deterministic variant: have `run_fun` raise/`exit(:epipe)` BEFORE replying to
  exercise the `:DOWN/:epipe` retry branch (D-05) — add a second synthetic test that asserts the
  single retry succeeds and the Logger.debug breadcrumb is emitted (capture via `ExUnit.CaptureLog`).
  This gives explicit coverage of both branches (drain-after-reply AND pre-reply retry) with zero race.

**This synthetic test owns the determinism proof of the new code path; §2 owns EPIPE-04's
fails-unpatched/passes-patched property.**

---

## §2 — D-08b: Real-subprocess stress iteration count (owns EPIPE-04)

### Recommendation
- **Command:** `Subprocess.run("sh", ["-c", "yes | head -n 100000"], use_cgroups: false)`
- **Iterations:** **300**
- **Wall-time budget:** ~30–45s on CI (each iteration spawns `sh`+`yes`+`head`, emits ~100k lines
  ≈ 200KB, exits promptly — the worst case for the ACK-after-close race).

### Rationale
- #98 reproduces "reliably ~13k+ lines." `yes | head -n 100000` emits ~7.7× that per iteration,
  maximizing chunks → maximizing ACK writes → maximizing the race window per iteration. The research
  sketch used 50000×200; bumping lines to 100000 and iterations to 300 buys margin so an unpatched
  `run/3` trips with very high probability on a single CI run (the property EPIPE-04 demands), while
  staying cheap (`sh`/`yes`, never ffmpeg).
- `use_cgroups: false` is mandatory: CI/macOS dev have no cgroup mount; `build_opts/2` already gates
  cgroups on `:os.type() == {:unix, :linux}`, but passing `use_cgroups: false` keeps the test
  identical across Linux CI and macOS dev (the two platforms invariant 13 now claims, per §6).
- Keep `async: false` (spawns OS processes; global-ish) — matches the research sketch and `ffmpeg_test.exs:2`.

### Exact assertion shape

```elixir
@tag :regression
@tag :av
test "run/3 never lets a broken-pipe (:epipe) exit kill the caller, even on large output" do
  Process.flag(:trap_exit, true)

  results =
    for _ <- 1..300 do
      Subprocess.run("sh", ["-c", "yes | head -n 100000"], use_cgroups: false)
    end

  assert length(results) == 300
  assert Enum.all?(results, fn
           {_out, status} when is_integer(status) -> true
           _ -> false
         end)

  refute_received {:EXIT, _, :epipe}
end
```

> If CI wall-time proves tight, the planner may drop to 200 iterations (the research-validated floor)
> — but 300 is the recommended default for margin. Do NOT drop line count below 50000.

---

## §3 — D-11: Canary iteration count + loud failure message

### Recommendation
- **Probe:** UNGUARDED `MuonTrap.cmd("sh", ["-c", "yes | head -n 100000"], [into: "", stderr_to_stdout: true])`
  — never `Subprocess.run/3` (the canary must observe the RAW bug, not the shielded path).
- **Iterations:** **500** (higher than the stress test — the canary wants to *catch the bug
  reproducing*, so more rolls = more confidence the bug is still present; probabilistic by nature,
  which is exactly why it is advisory-only per D-12).
- **Tag:** `@tag :canary` + `@tag :av`, `async: false`.

### Detection logic + loud failure message

```elixir
# test/rindle/av/subprocess_epipe_canary_test.exs
defmodule Rindle.AV.SubprocessEpipeCanaryTest do
  use ExUnit.Case, async: false

  @moduletag :canary
  @moduletag :av

  @muontrap_issue "https://github.com/fhunleth/muontrap/issues/98"
  @iters 500

  # ADVISORY canary (D-11/D-12): probes the UNGUARDED MuonTrap.cmd/3 and asserts MuonTrap #98
  # STILL reproduces. When upstream fixes #98, the :epipe stops firing and this test fails LOUDLY,
  # signalling that the Rindle.AV.Subprocess run_isolated/5 shim can be removed. Probabilistic →
  # advisory only; it must never gate a PR.
  test "MuonTrap #98 :epipe still reproduces (remove the Subprocess shim when this fails)" do
    Process.flag(:trap_exit, true)

    reproduced? =
      Enum.reduce_while(1..@iters, false, fn _i, _acc ->
        try do
          _ = MuonTrap.cmd("sh", ["-c", "yes | head -n 100000"],
                into: "", stderr_to_stdout: true)
          # Also catch the async signal form if it landed in our mailbox.
          receive do
            {:EXIT, _port, :epipe} -> {:halt, true}
          after
            0 -> {:cont, false}
          end
        catch
          :exit, :epipe -> {:halt, true}
          :exit, {:epipe, _} -> {:halt, true}
        end
      end)

    assert reproduced?, """
    MuonTrap #98 NO LONGER reproduces across #{@iters} iterations.

    This is the canary firing: upstream may have FIXED the :epipe race.
      - Upstream issue: #{@muontrap_issue}
      - Installed muontrap version: #{Application.spec(:muontrap, :vsn)}

    If #98 is fixed in this version, REMOVE the absorption shim:
      - lib/rindle/av/subprocess.ex  (run_isolated/5 + the run/3 delegation)
      - this canary file: test/rindle/av/subprocess_epipe_canary_test.exs
      - the deterministic regression test: test/rindle/av/subprocess_epipe_test.exs
    and bump the :muontrap pin to the fixed version. See the NOTE block above run_isolated/5.
    """
  end
end
```

> The failure message satisfies D-11 verbatim: it points at (1) the shim file + function, (2) this
> canary file, (3) `Application.spec(:muontrap, :vsn)`, and (4) the #98 URL.

---

## §4 — D-12: Advisory lane reality check (LOAD-BEARING)

### Finding: a real Nightly lane EXISTS
`.github/workflows/nightly.yml` exists (`name: Nightly`, `schedule: cron '27 7 * * *'`). It is a
genuine advisory/scheduled lane, invisible to release gating (per its own header comments). Its
`compat-matrix` job runs the test suite via `mix coveralls` (line 116) with the **default**
`test_helper.exs` exclude list.

### Critical gap → the load-bearing fallback applies
Neither `nightly.yml` nor `ci.yml` runs `mix test --include canary`. The default exclude list in
`test/test_helper.exs` (line 28) is `[:integration, :minio, :contract, :adopter]` — `:canary` is
**NOT** excluded, which means **a bare `@tag :canary` test would gate by default on PRs**. That is
exactly the footgun D-12 warns against (a "bug-still-present" assertion must never gate PRs).

### Mechanism (planner MUST implement BOTH halves)

1. **Exclude `:canary` from the default suite (the load-bearing safety):** add `:canary` to the
   default `exclude_tags` list in `test/test_helper.exs`:
   ```elixir
   exclude_tags =
     if targeted_adopter_or_integration? do
       [:minio, :contract, :canary]
     else
       [:integration, :minio, :contract, :adopter, :canary]
     end
   ```
   This guarantees the canary can never run — and therefore never gate — in any PR/CI invocation
   that does not explicitly opt in. This is the non-negotiable correctness requirement of D-12.

2. **Route the canary to the Nightly lane (the advisory home):** add a dedicated step to
   `nightly.yml`'s `compat-matrix` (or a small new job) that opts the canary back in:
   ```yaml
   - name: Subprocess :epipe cleanup canary (advisory)
     continue-on-error: true   # advisory — a still-reproducing bug must never fail the lane either
     run: mix test test/rindle/av/subprocess_epipe_canary_test.exs --include canary
   ```
   `--include canary` overrides the `test_helper.exs` exclude for this one invocation. Use
   `continue-on-error: true` so the canary is purely informational in nightly (D-12: "probabilistic
   → advisory only"; it should surface via the Nightly Summary, never red the lane). When the canary
   eventually fails (upstream fixed #98), the loud message + a maintainer eyeball is the signal —
   not a gate.

> **Bottom line:** the nightly lane exists, so D-12's preferred routing is available. But the
> EXCLUDE-from-default half (step 1) is the load-bearing safety and is mandatory regardless. If the
> planner wants the absolute-minimum change, step 1 alone fully satisfies "must never gate PRs"
> (the canary simply never runs in CI until a human runs `--include canary` locally); step 2 is the
> recommended addition so it actually runs somewhere automatically.

---

## §5 — D-07: The `Logger.debug` string

**Exact one-line message** (emitted ONLY in the pre-reply `:DOWN/:epipe` retry branch; happy-path
drained-epipe stays SILENT — verified against the control flow in §1):

```elixir
require Logger
# ...
Logger.debug(
  "Rindle.AV.Subprocess: absorbed a pre-reply MuonTrap #98 :epipe exit; retrying the AV call once " <>
    "(see https://github.com/fhunleth/muontrap/issues/98)"
)
```

Why this wording: it gives a future maintainer debugging "why did this AV call run twice" the exact
breadcrumb (names the module, the #98 cause, and that a single retry happened) without adding any
public/telemetry surface (D-07). It fires only on the rare pre-reply death — the common case
(`{ref, result}` wins, worker drains the late epipe) logs nothing, keeping the hot path quiet.

Add `require Logger` at the top of `subprocess.ex` (currently absent — verified).

---

## §6 — D-15/D-16/D-17: TRUTH-01 grounding (verified against source)

### D-15 — invariant 13 rewrite is BYTE-ACCURATE against the C source ✅
Verified against `deps/muontrap/c_src/muontrap.c`:
- **stdin-EOF BEAM-death detection:** lines 633-636 — `if (fds[0].revents & POLLHUP) { /* Erlang
  signals that it's done by closing stdin. Exit immediately. */ return EXIT_FAILURE; }`. ✅ POSIX,
  platform-independent (Linux AND macOS dev). [VERIFIED: deps/muontrap/c_src/muontrap.c:633-636]
- **kill via POSIX `kill()`:** `procfile_killall` line 336 `kill(pid, sig);`; `cleanup_all_children`
  line 475 `kill_children(SIGKILL)`. ✅ POSIX. [VERIFIED: muontrap.c:336,475]
- **cgroup caps are Linux-only:** `move_pid_to_cgroups`/`procfile_killall` operate on
  `/sys/fs/cgroup` procfiles (`controller->procfile`, lines 304-307, 325-340); cgroups are a
  Linux-only kernel feature, and Rindle's `build_opts/2` gates cgroup opts on
  `:os.type() == {:unix, :linux}` (`subprocess.ex:34`). ✅ [VERIFIED: muontrap.c:301-341, subprocess.ex:34]
- **No Rambo:** confirmed not in `mix.lock` (research §8; FFmpex+Rambo absent). ✅
- **No native Windows:** the wrapper is POSIX (`poll`, `kill`, signal pipes, cgroup procfiles); no
  Windows path. ✅ Drop "Windows," do not re-assert it.

The exact NEW text in D-15 is factually correct. **No wording in D-15 is inaccurate against the C
source.** The planner should apply it verbatim, matching the OLD clause by text string (current text
at `PROJECT.md:456-459`):
```
13. Temp files for transcoding live under a single sweepable root
    (`Rindle.tmp/`); orphans are reaped by a scheduled `Rindle.Ops` worker.
    No transcode is allowed without an enforceable parent-death subprocess
    kill (MuonTrap on Linux; Rambo on macOS / Windows dev).
```
Replace the kill clause with D-15's text; **preserve the `Rindle.tmp/` + Ops-reaper sentence verbatim**.

### D-16 — Key-Decisions row edit confirmed ✅
`PROJECT.md:503` currently reads `...system FFmpeg subprocess (FFmpex + MuonTrap)...`. FFmpex is
**not** in `mix.lock`; argv is built in `build_args/3` (`subprocess.ex:53-77`, verified — includes
`-protocol_whitelist file,crypto,data`, `-timelimit`, `-t`, `-fs`) for invariant-8 validation. The
edit `(FFmpex + MuonTrap)` → `(MuonTrap runner; argv built in-house, not FFmpex)` is correct. Match
on the literal string `(FFmpex + MuonTrap)`. [VERIFIED: subprocess.ex:53-77, PROJECT.md:503]

### D-17 — scope to Tier A only ✅
Targets: `PROJECT.md:456-459` (invariant 13) and `PROJECT.md:503` (Key-Decisions row). Match on text
strings, not line numbers (PROJECT.md is large/often-edited — confirmed; e.g. invariant 13 is now at
456 not the ~459 estimate). PROJECT.md milestone-description lines 47/58-59 are accurate (they
already say "MuonTrap-only; no Rambo in mix.lock") — no change. Leave archived/historical artifacts
(`.planning/research/v1.4/*`, `milestones/v1.4-REQUIREMENTS.md`) INTACT. [VERIFIED: PROJECT.md:47,58-59]

---

## §7 — Shim correctness review (control-flow sanity vs port.ex)

Sanity-checked the D-01/D-04/D-05/D-06 flow against `deps/muontrap/lib/muontrap/port.ex` and Erlang
port semantics:

1. **Does `MuonTrap.cmd/3` inside the worker still hold the parent-death kill + cgroup caps
   (invariants 8-13)?** YES. `MuonTrap.cmd/3` opens the port from whatever process calls it (the
   worker), with the SAME opts Rindle passes (`build_opts/2` unchanged). The kill guarantee is the C
   wrapper's stdin-EOF detection (§6) — it fires when the BEAM (the OS process) dies, not when a
   specific BEAM *process* dies, so running from the throwaway worker is irrelevant to the kill
   guarantee. cgroup caps are argv/opts-driven and identical. ✅ Invariants preserved by construction.

2. **Worker links only the port; the `is_port` drain guard is sound.** `Port.open` (port.ex:29)
   links the port to the worker (the opener). The worker sets `trap_exit`, so a port `:epipe` arrives
   as `{:EXIT, port, :epipe}` (a message, not a kill). The `when is_port(port)` guard (D-04) is
   correct belt-and-suspenders — the only `{:EXIT, ...}` the worker can receive is from its port. ✅

3. **Parent uses a MONITOR, not a link → never traps anything.** `spawn_monitor` gives the parent a
   `:DOWN` regardless of the parent's `trap_exit` state (D-02). The parent never sets `trap_exit`, so
   the caller's flag is never mutated (the whole point of rejecting D-02's in-place variant). ✅

4. **`demonitor(mon, [:flush])` prevents `:DOWN` leak.** After `{ref, result}` wins, `[:flush]`
   removes any already-queued `:DOWN` from the parent mailbox → no stray monitor message. ✅

5. **`receive ... after 0` drain is sound and degradation-safe (EPIPE-05).** Post-upstream-fix, no
   `:epipe` ever fires: the worker's `after 0` times out instantly (drains nothing), `{ref, result}`
   always wins, `demonitor [:flush]` is a no-op → the shim collapses to a transparent pass-through
   with one negligible short-lived process. Harmless dead code if left in. ✅ (D-14 confirmed.)

6. **The landmine you flagged — does worker death kill the child prematurely before reply?** NO, and
   here's why it's safe: `MuonTrap.cmd/3` is **synchronous** — it runs its own `do_cmd/4` receive
   loop (port.ex:42-55) and only returns after `{:exit_status, status}` (the child has ALREADY
   exited) or `:timeout`. The `{ref, result}` send happens AFTER `MuonTrap.cmd/3` returns, i.e. after
   the child is already dead and the real status is captured. So in the happy path the worker has no
   live child to kill when it dies. The ONLY pre-reply death scenario is the `:epipe` itself (the ACK
   race fires on the LAST chunk, after data is folded into `acc` per port.ex:44-46) — and that's the
   D-05 single-retry branch. The retry re-runs from scratch (fresh child); no orphan, because the
   first run's child had already exited (that's what triggered the epipe). ✅ No premature-kill landmine.

7. **`:timeout` flows through unchanged.** `:timeout` is a MuonTrap *return value* (port.ex:51-53,
   `do_cmd` returns `{acc, :timeout}`), not an exit — so it arrives via `{ref, result}`, never via
   `:DOWN`. D-06 correct. ✅

**Verdict:** the locked control flow is sound against the live source. No landmines. The only
implementation nuance the planner must honor: `require Logger`, and prefer `@doc false def
run_isolated/5` over `defp` so the synthetic test can call it directly (§1).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Subprocess parent-death kill + cgroup caps | A custom port wrapper / `System.cmd` | Keep `MuonTrap.cmd/3` (unchanged opts) | MuonTrap uniquely satisfies invariant 13; replacing it forfeits the kill guarantee |
| Async exit isolation | `Task.async` / `Task.Supervisor` / GenServer | `spawn_monitor` + worker `trap_exit` (D-01/D-03) | Task links propagate; supervisor pulls a dep; GenServer is wrong altitude |
| Deterministic epipe injection | An OS-timing-based "hope it fires" test | Injectable `run_fun` seam (§1) | The race IS the OS timing; only direct signal injection is deterministic |
| Upstream-fix detection | Version-pinned tripwire (`>= 1.7.0` buggy) | Behavioral canary (D-10/D-11) | Bug spans 1.7.0/1.8.0/2.0.0-rc.0 — no version boundary to encode |

## Common Pitfalls

### Pitfall 1: Canary silently gating PRs
`:canary` is NOT in the default exclude list — a bare `@tag :canary` test runs (and can fail) on
every PR. **Must** add `:canary` to `test_helper.exs` exclude (§4 step 1). This is the #1 landmine.

### Pitfall 2: Using `defp` blocks the synthetic test from calling the seam cleanly
Use `@doc false def run_isolated/5` (mirrors existing `@doc false def build_opts`) so the test calls
it directly. `apply/3` on a `defp` works but is uglier and signals "I'm reaching into privates."

### Pitfall 3: Forgetting `require Logger`
`subprocess.ex` has no `require Logger` today. The D-07 `Logger.debug` needs it.

### Pitfall 4: Stress test under cgroups on CI/macOS
Pass `use_cgroups: false` explicitly. CI/macOS have no cgroup mount; without the flag the test
behaves differently across platforms.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Inline `MuonTrap.cmd/3` in caller (port linked to caller) | Port owned by throwaway trap_exit'd worker; parent monitors | This phase | `:epipe` can never kill the caller |
| PROJECT.md "Rambo on macOS/Windows" (invariant 13) | "MuonTrap on every platform; cgroups Linux-only; no Rambo" | This phase (TRUTH-01) | Docs match the real MuonTrap-only code path |

**Deprecated/outdated:** the "Rambo" mention in invariant 13 and "FFmpex" in the Key-Decisions row —
both stale relative to `mix.lock` (verified absent) and the real code path.

---

## Validation Architecture

> Nyquist validation enabled. This section is consumed by the orchestrator to generate VALIDATION.md.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.17/OTP 27 home cell; bundled with Elixir) |
| Config file | `test/test_helper.exs` (exclude list at line 24-29; MUST add `:canary`) |
| Quick run command | `mix test test/rindle/av/subprocess_epipe_test.exs --seed 0` |
| Full suite command | `mix test` (PR gate) / `mix coveralls` (CI + nightly) |
| Canary (advisory, opt-in) | `mix test test/rindle/av/subprocess_epipe_canary_test.exs --include canary` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | Lane | File Exists? |
|--------|----------|-----------|-------------------|------|-------------|
| EPIPE-01 | `:epipe` never kills caller; real `{output, status}` returned | deterministic synthetic (§1) | `mix test test/rindle/av/subprocess_epipe_test.exs --seed 0` | **merge-blocking** | ❌ Wave 0 |
| EPIPE-01 (pre-reply branch) | single-retry on pre-reply `:DOWN/:epipe`; Logger.debug emitted | deterministic synthetic (§1, 2nd test) | same file | **merge-blocking** | ❌ Wave 0 |
| EPIPE-02 | contract `{collectable, non_neg \| :timeout}` preserved; call sites unchanged | existing call-site tests + unmodified flaking tests | `mix test test/rindle/processor/ffmpeg_test.exs test/rindle/av/ffprobe_test.exs` | **merge-blocking** | ✅ exists (unmodified) |
| EPIPE-03 | argv/caps byte-equivalent; no shell | static (build_args/build_opts byte-frozen) + existing argv/security tests | `mix test test/rindle/security/` (+ grep diff guard) | **merge-blocking** | ✅ exists |
| EPIPE-04 | fails unpatched / passes patched; reproduces under high output | real-subprocess stress (§2) | `mix test test/rindle/av/subprocess_epipe_test.exs` | **merge-blocking** | ❌ Wave 0 |
| EPIPE-05 | forward-compatible no-op; no double-handling / leaked monitors | code comment (D-13) + demonitor/drain proven by synthetic test | covered by EPIPE-01 synthetic | **merge-blocking** | ❌ Wave 0 |
| EPIPE-09 (D-09) | two originally-flaking tests pass UNMODIFIED | regression (no edits to those files) | `mix test test/rindle/processor/ffmpeg_test.exs:32 test/rindle/ops/lifecycle_repair_test.exs:122` | **merge-blocking** | ✅ exists (must stay byte-identical) |
| (cleanup signal) | MuonTrap #98 still reproduces (remove-shim trigger) | behavioral canary (§3) | `mix test ...canary_test.exs --include canary` | **ADVISORY (nightly)** | ❌ Wave 0 |
| TRUTH-01 | invariant 13 / Key-Decisions prose corrected | doc assertion / grep | `grep -n "Rambo" .planning/PROJECT.md` returns 0 in invariant 13; `grep "FFmpex + MuonTrap"` returns 0 | **merge-blocking** (cheap grep) | ❌ Wave 0 (add doc-truth test or CI grep step) |

### Sampling Rate
- **Per task commit:** `mix test test/rindle/av/subprocess_epipe_test.exs --seed 0` (the new
  deterministic + stress assertions) — fast, deterministic feedback.
- **Per wave merge:** `mix test` (full default suite, which now excludes `:canary`) — includes the
  two unmodified flaking tests (EPIPE-09) and all argv/security tests (EPIPE-03).
- **Phase gate:** full suite green before `/gsd-verify-work`; canary run once via
  `--include canary` to confirm it currently reproduces (sanity that the canary works as written).

### Merge-blocking vs Advisory split
- **Merge-blocking (PR gate, `mix test`):** both `:regression` assertions (§1 synthetic + §2 stress),
  the two unmodified flaking tests (D-09), the argv/security tests, and the TRUTH-01 grep/doc check.
- **Advisory (Nightly lane, `--include canary`, `continue-on-error: true`):** the `:canary` cleanup
  signal. A "bug-still-present" assertion must never flake the PR gate (D-12).

### Wave 0 Gaps
- [ ] `test/rindle/av/subprocess_epipe_test.exs` — deterministic synthetic (§1) + real stress (§2); covers EPIPE-01/04/05
- [ ] `test/rindle/av/subprocess_epipe_canary_test.exs` — advisory canary (§3); covers the cleanup signal
- [ ] `test/test_helper.exs` — add `:canary` to both exclude branches (§4 step 1) — LOAD-BEARING
- [ ] `.github/workflows/nightly.yml` — add `--include canary` advisory step (§4 step 2)
- [ ] TRUTH-01 verification — either a `mix test` doc-assertion test or a CI grep step asserting
      `Rambo` absent from invariant 13 and `FFmpex + MuonTrap` absent from Key-Decisions

*(Framework install: none needed — ExUnit ships with Elixir; the home cell is already configured.)*

## Security Domain

> `security_enforcement` enabled. This phase is a signal-handling shim; the argv/security layer is
> byte-frozen, so the security surface is unchanged by construction.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | yes (unchanged) | `build_args/3` argv allowlist + `-protocol_whitelist file,crypto,data` (byte-frozen, invariant 8) |
| V12 / OS command | yes (unchanged) | argv-list invocation (no shell); MuonTrap parent-death kill + cgroup caps (invariants 9, 13) |
| V6 Cryptography | no | — |
| V2/V3/V4 Auth/Session/Access | no | library subprocess internals |

### Known Threat Patterns for Elixir subprocess execution
| Pattern | STRIDE | Standard Mitigation | Status this phase |
|---------|--------|---------------------|-------------------|
| Shell injection via args | Tampering | argv-list (no `sh -c` on user input); `Argv.validate` at call site | Unchanged (byte-frozen) |
| Resource exhaustion (runaway transcode) | DoS | `-timelimit`/`-t`/`-fs` caps + cgroup mem/cpu + timeout | Unchanged (byte-frozen) |
| Orphaned child after BEAM death | DoS | MuonTrap stdin-EOF kill (invariant 13) | Unchanged — shim only changes BEAM-side port ownership, not the C kill path |
| Async transport signal kills worker | DoS (the bug) | b1 shim absorbs `:epipe`; real status preserved | **Fixed this phase** |

> Note: the stress/canary tests use `sh -c "yes | head -n N"` with a STATIC, non-user-controlled
> command string — no injection surface introduced by the tests.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | 300 iters × 100000 lines reliably trips unpatched `run/3` on CI within ~30-45s | §2 | If too low, EPIPE-04 "fails unpatched" is non-deterministic → bump iters/lines (floor 200×50000 from research); if too slow, drop to 200 |
| A2 | 500 canary iters reliably reproduces #98 currently | §3 | If too low, canary false-fails (looks like upstream fixed it) → it's advisory, so low blast radius; bump iters |
| A3 | `nightly.yml compat-matrix` is the right home for the `--include canary` step | §4 | If maintainer prefers a separate job, trivial to relocate; step 1 (exclude) is the load-bearing half regardless |

**All other claims VERIFIED against live source** (subprocess.ex, port.ex, muontrap.c, PROJECT.md,
test_helper.exs, nightly.yml, ffmpeg.ex/ffprobe.ex/ffmpeg_test.exs/lifecycle_repair_test.exs).

## Open Questions

1. **TRUTH-01 enforcement: doc-assertion test vs CI grep step?**
   - What we know: a cheap grep (`Rambo` absent from invariant 13; `FFmpex + MuonTrap` absent from
     Key-Decisions) proves the edit landed and guards against regression.
   - What's unclear: whether the planner wants this as an ExUnit test (e.g. extend an existing
     docs-parity test like `test/install_smoke/docs_parity_test.exs`) or a CI shell step.
   - Recommendation: a small ExUnit assertion in the merge-blocking suite (reads `PROJECT.md`,
     asserts the strings) — keeps the guard in the same lane as the rest and is self-documenting.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `sh` / `yes` / `head` | stress + canary tests | ✓ (POSIX) | — | none needed (universal on Linux CI + macOS) |
| MuonTrap | the whole shim | ✓ | 1.7.0 (pinned `~> 1.7`, mix.lock) | — |
| ffmpeg/ffprobe | unmodified flaking tests (D-09) | ✓ on CI (install_ffmpeg.sh) | >= 6.0 | — (already provisioned in ci.yml/nightly.yml) |
| cgroups | NOT used by new tests (`use_cgroups: false`) | Linux-only | — | gated by `:os.type()`; tests bypass via flag |

**Missing dependencies with no fallback:** none.

## Sources

### Primary (HIGH confidence)
- `lib/rindle/av/subprocess.ex` (read directly — `run/3:11-16`, `build_opts/2:29-50`, `build_args/3:53-77`)
- `deps/muontrap/lib/muontrap/port.ex` (read directly — `do_cmd/4:42-55`, `report_bytes_handled/2:102-113`, `Port.open:29`)
- `deps/muontrap/c_src/muontrap.c` (read directly — stdin-EOF death:633-636, `kill()`:336/475, cgroup procfile:301-341)
- `lib/rindle/processor/ffmpeg.ex` + `lib/rindle/av/ffprobe.ex` (read — call sites match `{output, 0}`/`{output, status}` only)
- `test/test_helper.exs` (read — exclude list line 24-29)
- `.github/workflows/nightly.yml` (read — Nightly lane exists; `mix coveralls`:116; no `--include canary`)
- `.planning/PROJECT.md` (read — invariant 13:456-459, Key-Decisions:503, D-v1.21-01:536, milestone desc:47/58-59)
- `.planning/research/v1.21-SUBPROCESS-EPIPE.md` (locked milestone research, HIGH)
- `.planning/phases/109-subprocess-epipe-hardening/109-CONTEXT.md` (locked decisions D-01..D-17)

### Secondary (MEDIUM confidence)
- MuonTrap issue #98 (https://github.com/fhunleth/muontrap/issues/98) — referenced via research, not re-fetched this session

## Metadata

**Confidence breakdown:**
- Shim control flow (b1): HIGH — verified against port.ex + Erlang port semantics, no landmines
- Test injection seam (§1): HIGH — standard Elixir DI seam, deterministic by construction
- Iteration counts (§2/§3): MEDIUM — extrapolated from research's ~13k-line repro figure (A1/A2)
- Advisory lane (§4): HIGH — nightly.yml read directly; exclude-from-default is provably correct
- TRUTH-01 wording (§6): HIGH — byte-checked against C source + mix.lock

**Research date:** 2026-06-28
**Valid until:** 2026-07-28 (stable; only risk is MuonTrap #98 getting fixed upstream, which the canary detects)
