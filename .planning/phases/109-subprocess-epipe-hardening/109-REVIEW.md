---
phase: 109-subprocess-epipe-hardening
reviewed: 2026-06-28T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - .github/workflows/ci.yml
  - .github/workflows/nightly.yml
  - lib/rindle/av/subprocess.ex
  - test/rindle/av/subprocess_epipe_canary_test.exs
  - test/rindle/av/subprocess_epipe_test.exs
  - test/test_helper.exs
findings:
  critical: 0
  warning: 5
  info: 3
  total: 8
status: issues_found
---

# Phase 109: Code Review Report

**Reviewed:** 2026-06-28
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

The phase adds an `:epipe`-absorption shim to `Rindle.AV.Subprocess.run/3`: the real
`MuonTrap.cmd/3` is run inside a `spawn_monitor`'d, `trap_exit`'d throwaway worker so that
MuonTrap #98's async `{:EXIT, port, :epipe}` (delivered to the port owner) is trapped by the
worker and cannot kill the inline caller. The parent monitors (never traps), drains the worker's
`{ref, result}` reply, retries once on a pre-reply `:epipe` death, and re-raises every other death
via `exit(reason)`.

**The core concurrency design is sound and the locked invariants hold:**
- `build_args/3` / `build_opts/2` are **byte-unchanged** (verified against `HEAD~8`; the only
  delta in `run/3` is the delegation to `run_isolated/5`).
- **No shell**: `cmd`/`args` flow straight to `MuonTrap.cmd/3`; no interpolation, no `System.cmd`
  with `shell: true`. The `-protocol_whitelist` and 4-cap args are preserved.
- The port is owned by the worker, not the parent, so `{:EXIT, port, :epipe}` can never reach the
  (non-trapping) parent. The worker traps it, so it can never kill the worker either.
- Retry is bounded (`retries_left` decrements; `run/3` seeds `1`) — no infinite-loop path.
- Monitor cleanup is correct: success path `demonitor(mon, [:flush])` clears the trailing
  `:normal` DOWN; the retry/raise paths consume the DOWN that already auto-cleared the monitor. No
  monitor leak per call, and the 300× stress test shows no accumulation.

The findings below are robustness, failure-shape, and observability concerns — none rises to a
correctness BLOCKER, but several are real behavior changes worth fixing before this ships as the
sole subprocess path on every platform.

## Warnings

### WR-01: Unlinked worker orphans the OS subprocess if the caller dies mid-run

**File:** `lib/rindle/av/subprocess.ex:39-50`
**Issue:** The worker is started with `spawn_monitor` (one-directional: parent watches worker) and
is **not linked**. If the calling process dies while the worker is blocked inside `MuonTrap.cmd/3`
(e.g. an Oban job hits its execution timeout and is killed, or a supervisor shuts the caller down),
the worker is orphaned. It keeps running the OS subprocess to completion, then `send(parent, ...)`
to a dead pid is silently dropped, and the worker exits. Until the child exits (bounded only by the
MuonTrap `:timeout` / cgroup caps, which default to `600_000` ms = 10 min wall), an ffmpeg/ffprobe
process leaks past the death of the work that requested it. The pre-shim code ran MuonTrap inline,
so caller death tore the port (and via MuonTrap's `:monitor`/`cmd` wrapper, the child) down
promptly. The shim widens that teardown window.
**Fix:** Link the worker to the parent and have it trap the parent's exit so it can stop the port:
```elixir
{pid, mon} =
  spawn_monitor(fn ->
    Process.flag(:trap_exit, true)
    Process.link(parent)               # now bidirectional; parent death reaches the worker
    result = run_fun.(cmd, args, muon_opts)
    send(parent, {ref, result})
    receive do
      {:EXIT, port, _reason} when is_port(port) -> :ok
      {:EXIT, ^parent, _reason} -> :ok  # caller died — fall through and let the worker exit
    after
      0 -> :ok
    end
  end)
```
Note the parent must NOT trap exit (it doesn't), so the link cannot turn a worker crash into a
trapped message on the parent — the existing `:DOWN` monitor still drives parent behavior. If full
linking is judged too invasive, at minimum document the orphan window in the NOTE block so the
600_000 ms default `:timeout` is understood as the orphan bound.

### WR-02: A `MuonTrap.cmd/3` exception is rewritten from `raise` into `exit/1`, changing the failure shape

**File:** `lib/rindle/av/subprocess.ex:65-66`
**Issue:** If `run_fun` (i.e. `MuonTrap.cmd/3`) raises an exception rather than returning
`{output, status}`, that becomes the worker's exit reason `{exception, stacktrace}`, and the parent
re-emits it via `exit(reason)`. The original `raise`/exception is thus converted into an `exit`:
the same crash now propagates as `{:EXIT, ...}`/`exit` instead of the original `ArgumentError`/
`RuntimeError`. Any caller with a `rescue` clause expecting the exception type would no longer
catch it (it would need a `catch :exit, _` instead). The reverse problem also exists: an
intentional `exit(:some_reason)` deeper in MuonTrap is faithfully re-emitted, but an exception is
not. Today's AV callers (`ffprobe.ex`, `processor/av/*.ex`, `waveform.ex`) only `case`/`with` on
`{output, status}` and do not `rescue`, so this is latent rather than active — but it is a real
behavior change versus the inline pre-shim code, which surfaced the native exception/stacktrace.
**Fix:** Preserve the original kind when the worker died from a raised exception:
```elixir
{:DOWN, ^mon, :process, ^pid, {exception, stacktrace}}
when is_exception(exception) and is_list(stacktrace) ->
  reraise(exception, stacktrace)

{:DOWN, ^mon, :process, ^pid, reason} ->
  exit(reason)
```
At minimum, document in the NOTE block that all non-`:epipe` worker exits are surfaced as `exit`,
not as the original exception.

### WR-03: The #98 absorption breadcrumb is logged at `:debug` and is invisible in production

**File:** `lib/rindle/av/subprocess.ex:58-61`
**Issue:** The retry breadcrumb is emitted at `Logger.debug`. Production/default Logger level is
`:info` or higher (the repo's own `config/test.exs:54` sets `:warning`), so the message is
**silently dropped** in every real deployment. The regression test only observes it because it
explicitly calls `Logger.put_module_level(Rindle.AV.Subprocess, :debug)`
(`subprocess_epipe_test.exs:59`). The result: when this workaround for a known-open upstream bug
fires in production — absorbing an `:epipe` death and **re-running a potentially expensive ffmpeg
job** — operators get zero signal. For a shim whose whole reason to exist is a transport-layer
fault, the absorption event is operationally interesting and should be visible.
**Fix:** Emit at `:warning` (or at least `:info`) so the absorption/retry is visible at default
log levels:
```elixir
Logger.warning(
  "Rindle.AV.Subprocess: absorbed a pre-reply MuonTrap #98 :epipe exit; retrying the AV call once " <>
    "(see https://github.com/fhunleth/muontrap/issues/98)"
)
```
If `:debug` is a deliberate noise-control choice, the test's `put_module_level` masks the
production reality — the rationale should be stated in the NOTE block.

### WR-04: Post-reply `:epipe` drain has a delivery race; it works by accident, not by the drain

**File:** `lib/rindle/av/subprocess.ex:44-49`
**Issue:** The comment frames the worker's `receive ... after 0` as the mechanism that prevents a
late `{:EXIT, port, :epipe}` from escaping. But the async port-exit signal is delivered by the
runtime and is not guaranteed to be in the worker's mailbox at the instant `after 0` runs. When the
signal lands after the drain, the drain finds nothing and the worker exits `:normal`; the
straggler `{:EXIT, port, :epipe}` is then discarded with the dead worker's mailbox. So correctness
actually rests on "the worker dies and takes its mailbox with it," **not** on the drain — the drain
is a best-effort no-op in the racy case. This is fine in outcome but the code/comment imply a
guarantee the `after 0` does not provide, which is a maintenance trap (a future reader may "fix"
the drain into a blocking `receive` and deadlock the happy path when no `:epipe` ever arrives).
**Fix:** Either drop the drain entirely (the worker dying is what absorbs the straggler) or correct
the comment to state that the drain is opportunistic and that the real absorption guarantee is the
worker's death scoping the port-exit signal. Do **not** convert `after 0` to a blocking receive.

### WR-05: `default_use_cgroups?/0` and the `:use_cgroups` `put_new` run redundantly across `run/3` and `build_opts/2`

**File:** `lib/rindle/av/subprocess.ex:13-16, 81-82`
**Issue:** `run/3` does `Keyword.put_new(opts, :use_cgroups, default_use_cgroups?())` (line 14) and
then `build_opts(opts)` (line 15), but `build_opts/2` independently does the same
`Keyword.put_new(opts, :use_cgroups, default_use_cgroups?())` (line 82). `default_use_cgroups?/0`
reads `System.get_env` and `Application.get_env` each time. Because `put_new` is idempotent the
result is correct, but the env/config is read twice per call and the intent (who owns the default?)
is muddied. This is pre-existing structure that the phase carried forward, but the new `run/3`
delegation makes the double-resolution more visible.
**Fix:** Resolve `:use_cgroups` once. Either drop the `put_new`/`default_use_cgroups?()` from
`run/3` (let `build_opts/2` own it) or drop it from `build_opts/2` for the `run/3` path. Keep
`build_args`/`build_opts` byte-identical if that is a locked invariant — in which case remove the
redundant line 14 from `run/3` instead.

## Info

### IN-01: `run_isolated/5` is a public, `@doc false` test seam reachable by any caller

**File:** `lib/rindle/av/subprocess.ex:34-35`
**Issue:** `run_isolated/5` is `def` (public), only marked `@doc false`. The `run_fun` seam means an
external caller could invoke it with an arbitrary 0/3-arity function — including one that bypasses
the `build_args`/`build_opts` cap enforcement (note `run_isolated` itself does NOT call
`build_args`/`build_opts`; `run/3` does that before delegating). The contract comment says "`run/3`
never passes it, so the public contract is byte-identical," which is true for `run/3`, but the
function is still part of the module's callable surface. Low risk in a single-repo library, but it
is an un-capped execution entrypoint.
**Fix:** Consider making the seam a private function with a test-only injection (e.g. an
`Application.get_env`-driven `run_fun`, or `@compile`-guarded), or document explicitly that
`run_isolated/5` assumes its `args`/`muon_opts` are already cap-enforced by `run/3` and must not be
called directly with untrusted input.

### IN-02: Synthetic test #1 reuses a live, foreign port as the fake `:epipe` source

**File:** `test/rindle/av/subprocess_epipe_test.exs:18-28`
**Issue:** Test #1 grabs `Port.list() |> hd` (or opens `true`) and fabricates
`{:EXIT, fake_port, :epipe}` into the worker mailbox. Reusing whatever port happens to be first in
`Port.list()` couples the test to ambient runtime state; if that port belongs to another subsystem
the fabricated `:EXIT` message is harmless only because it is sent to `self()` (the worker), not the
real owner — but it is a fragile choice. The assertion that matters
(`refute_received {:EXIT, _, :epipe}` and the `{"OK", 0}` return) does validate the absorption.
**Fix:** Always open a dedicated throwaway port for the test
(`:erlang.open_port({:spawn, "true"}, [:binary])`) and close it in `on_exit`, rather than borrowing
an arbitrary live port from `Port.list()`.

### IN-03: Canary `@iters 500` and stress `1..300` magic counts are undocumented tuning knobs

**File:** `test/rindle/av/subprocess_epipe_canary_test.exs:8`, `test/rindle/av/subprocess_epipe_test.exs:94`
**Issue:** The iteration counts (`@iters 500` for the canary, `1..300` for the real-subprocess
stress) are the probabilistic detection budget for a race window. They are magic numbers with no
stated basis for "why 500 / why 300" — too low risks a flaky false-negative (canary fails to
reproduce #98 and fires the loud removal assertion spuriously); too high inflates nightly/CI time.
The canary is advisory (`continue-on-error`, nightly-only) so a spurious miss is low-blast-radius,
but the rationale should be captured.
**Fix:** Add a one-line comment near each count citing the observed reproduction rate / the chosen
confidence margin, so a future tuner knows the floor below which the canary goes flaky.

---

_Reviewed: 2026-06-28_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
