# Phase 109: Subprocess `:epipe` hardening - Context

**Gathered:** 2026-06-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Harden `Rindle.AV.Subprocess.run/3` so a MuonTrap issue #98 broken-pipe (`:epipe`) async
exit signal can **never** kill its caller — making every AV invocation deterministic in
tests AND in adopter Oban workers — while preserving the exact `{output, status}` contract
and keeping security invariants 8–13 byte-equivalent at the argv layer. Plus correct
PROJECT.md security-invariant 13's stale "Rambo on macOS/Windows dev" prose (TRUTH-01).

**Approach is research-locked to Option b1** (`.planning/research/v1.21-SUBPROCESS-EPIPE.md`,
HIGH confidence). This phase clarifies the *HOW* the research/requirements left open; it does
NOT revisit *whether* to fix at the subprocess seam (locked) or *whether* to touch `lib/`
(authorized via D-v1.21-01).

**In scope:** the `run/3` signal-handling shim; a deterministic + light-stress regression
test; a cleanup-signal canary; the TRUTH-01 docs correction.
**Out of scope:** changing `build_args/3` / `build_opts/2`; adding Rambo/exile/any new dep;
bumping MuonTrap (no fix exists); any public-API / return-shape / error-vocab / telemetry
change; the async-isolation work (Phase 110) and regression-lock meta-tests (Phase 111).

</domain>

<decisions>
## Implementation Decisions

All four discussion areas were researched one-shot via parallel subagents (OTP/shim shape;
forward-compat/cleanup; TRUTH-01 wording). Recommendations below are LOCKED and mutually
coherent. UI/UX/graphic-design lenses are N/A (backend library internals); the "UX" here is
**library DX** — the adopter's Oban worker simply stops dying and the called function is
byte-identical, plus a clean future-maintainer removal path.

### Shim shape — `run_isolated/3` (user-confirmed; research-confirmed HIGH)
- **D-01:** Use the **`spawn_monitor` + `trap_exit`'d worker** shape. `run/3` delegates to a
  new private `run_isolated/4` that `spawn_monitor`s a closure which sets
  `Process.flag(:trap_exit, true)`, runs `MuonTrap.cmd/3`, `send`s `{ref, result}` to the
  parent, then non-blockingly drains a late `{:EXIT, port, _}` (`receive ... after 0`). The
  parent selective-`receive`s either `{ref, result}` (the real `{output, status}`) →
  `Process.demonitor(mon, [:flush])` → return; or a `{:DOWN, ...}`.
- **D-02:** **Reject the in-place `trap_exit` region** (no-extra-process variant). It is
  disqualifying *not* for vague fragility but because absorbing the signal in-place requires
  permanently mutating the **caller's** `trap_exit` flag (a library must never do this), and
  if the caller is already a trapping process (GenServer / certain Oban runners) it creates
  **mailbox cross-contamination** between the port's `:epipe` and the host's legitimate
  `{:EXIT, …}` supervision signals — undistinguishable in the general case. The throwaway
  worker scopes the `trap_exit` mutation to a process that dies in ~one AV call; the parent
  uses a **monitor** (not a link), and `:DOWN` delivers the reason **regardless of the
  parent's `trap_exit`** state, so the parent never traps anything.
- **D-03:** Reject `Task.async` (links AND monitors → a pre-reply worker `exit(:epipe)`
  propagates to the caller via the link, defeating the purpose) and `Task.Supervisor.
  async_nolink` (pulls a supervisor dependency into the AV hot path for a 25-line shim;
  it's "spawn_monitor with extra steps"). Reject a GenServer port-owner (wrong altitude).
- **D-04:** Tighten the worker's inner drain to `{:EXIT, port, _} when is_port(port)` (the
  worker links only the port, so this is belt-and-suspenders against any non-port `{:EXIT,…}`).
- **`build_args/3` and `build_opts/2` are byte-untouched** — invariants 8–13 preserved by
  construction; MuonTrap is still the runner with identical opts (kill guarantee + caps hold).

### Retry policy — bounded SINGLE retry (user-confirmed)
- **D-05:** The defensive `{:DOWN, ^mon, :process, ^pid, :epipe}` branch (pre-reply death;
  rare because the worker traps) retries `run_isolated` **exactly once** via an **explicit
  `retries_left` counter** (`run_isolated(cmd, args, opts, 1)` initial), then falls through.
  **NOT** the research snippet's unbounded recursion (latent infinite loop).
- **D-06:** All other `{:DOWN, ..., reason}` (genuine crash, OR `:epipe` after the retry is
  exhausted) → `exit(reason)` — real failures are **never masked**. The `:timeout` and
  normal-exit paths flow through `{ref, result}` unchanged (`:timeout` is a MuonTrap *return
  value*, not an exit). Non-zero ffmpeg exit codes and clean `-t`/`-fs`/`-timelimit`
  early-exits (invariant 9) are the real `status` and pass through untouched (EPIPE-03).

### Observability of the absorbed signal
- **D-07:** **No telemetry** for the absorbed `:epipe` — adding a `[:rindle, :av, …]` event
  would turn an adopter-invisible shim into a semver-relevant public contract surface
  (contradicts D-v1.21-01 "adopter-invisible, ships as `fix:`"; collides with invariant-14
  telemetry-metadata policy). The happy-path drained-epipe is **silent** (the work
  succeeded — logging every benign terminal epipe is hot-path noise). Emit a single
  `Logger.debug/1` citing #98 **only** in the rare pre-reply `:DOWN/:epipe` retry branch, so
  a future maintainer debugging "why did this AV call run twice" has a breadcrumb.

### Regression test — deterministic synthetic + light real-subprocess stress (user-confirmed)
- **D-08:** Ship **two complementary** `@tag :regression` assertions in
  `test/rindle/av/subprocess_epipe_test.exs`, both in the **default merge-blocking** suite
  (`:regression` and `:av` are NOT in `test_helper.exs`'s exclude list → they gate by default,
  matching the milestone's regression-lock + shift-left intent):
  - **(a) Deterministic synthetic assertion** — exercises the absorption path of the new
    seam directly (inject/simulate a terminal `{:EXIT, port, :epipe}` against `run_isolated`
    and assert the caller survives + gets the real `{output, status}`). 100% deterministic,
    fast feedback. *Researcher to finalize the exact injection mechanism* (e.g. a controlled
    test seam) so it stays deterministic without an OS race.
  - **(b) Bounded real-subprocess stress** — `Subprocess.run` against a chatty child
    (`sh -c "yes | head -n 50000"`, `use_cgroups: false`), bounded iterations high enough to
    reliably trigger #98 unpatched (#98 reproduces reliably ~13k+ lines). **This sub-test
    owns the EPIPE-04 "fails unpatched, passes patched" property** (the synthetic one proves
    determinism of the new code path). Keep it cheap (`sh`/`yes`, not ffmpeg) and fast.
  - `Process.flag(:trap_exit, true)` in the test body; `refute_received {:EXIT, _, :epipe}`.
- **D-09:** The two originally-flaking tests (`test/rindle/processor/ffmpeg_test.exs:32`,
  `test/rindle/ops/lifecycle_repair_test.exs:122`) MUST pass **unmodified** — no per-test
  `:epipe`/`trap_exit` wrappers (EPIPE-04). b1 makes them pass without touching them.

### Cleanup signal — behavioral canary, NOT a version tripwire (research-corrected)
- **D-10:** **Reject a version-pinned tripwire.** Critical finding: MuonTrap #98 is OPEN and
  the bug is present in **1.7.0 (pinned), 1.8.0, AND 2.0.0-rc.0** — there is no "fixed
  version" boundary to encode. A `>= 1.7.0`-is-buggy assertion would **false-alarm on the
  very next benign 1.8 bump**, get muted, and train maintainers to ignore it (the classic
  workaround-rot footgun).
- **D-11:** Ship a **behavioral canary** in `test/rindle/av/subprocess_epipe_canary_test.exs`
  that probes the **UNGUARDED `MuonTrap.cmd/3`** (never `Subprocess.run/3`) with a chatty
  child across many iterations and asserts the `:epipe` **still reproduces**. When upstream
  fixes #98, the bug stops reproducing → the canary **fails loudly** with a message pointing
  at the shim + this file + `Application.spec(:muontrap, :vsn)`. It binds the removal signal
  to the *actual upstream behavior change*, not a version proxy.
- **D-12:** The canary is **probabilistic → advisory only**. Tag it `:canary` (+ `:av`) and
  keep it OUT of the merge-blocking PR gate (route to the nightly/advisory lane; a
  "bug-still-present" assertion must never flake the gate). The deterministic *regression*
  test (D-08) is merge-blocking; the *cleanup canary* is advisory. Two tests, two purposes,
  two lanes. **Planner: verify the nightly/advisory lane exists; if not, exclude `:canary`
  via tag so it cannot gate PRs.**

### Code comment & double-handling safety
- **D-13:** Place a `# NOTE (EPIPE-07, MuonTrap #98):` comment block above `run_isolated`
  (matching the repo's `# NOTE (<REQ-ID>, <citation>):` + `# See: <url>` convention) that:
  cites the issue URL + OPEN status + affected versions (1.7.0/1.8.0/2.0.0-rc.0), summarizes
  the ACK-after-reader-close race in ~2 lines, states the **removal condition** ("#98 fixed
  AND muontrap pin bumped to the fixed version"), names the canary as the live signal, and
  couples them ("do NOT delete the canary without deleting this shim").
- **D-14:** **No-op degradation is provable & double-handling-safe** (EPIPE-05): post-fix the
  `receive ... after 0` drains nothing (times out instantly), `{ref, result}` always wins,
  `demonitor [:flush]` prevents monitor/`:DOWN` leaks → the shim collapses to a transparent
  pass-through with one negligible short-lived process; leaving it in place if forgotten is
  harmless dead code, never a correctness/reliability regression. Add a one-line CHANGELOG
  `fix:` note (doubles as adopter discoverability). Ships `fix:` → Hex **0.3.2**.

### TRUTH-01 — invariant 13 docs correction (research-locked exact wording)
- **D-15:** Replace PROJECT.md invariant 13's kill-mechanism clause. **Ground truth (verified
  against `deps/muontrap` C source + README):** MuonTrap is the sole subprocess runner on all
  platforms; its POSIX C wrapper detects BEAM death via **stdin EOF** and kills via POSIX
  `kill()` → the **parent-death kill holds on Linux AND macOS**; **cgroup resource caps are
  Linux-only** (gated by `:os.type() == {:unix, :linux}` in `build_opts/2`). There is **no
  Rambo dep** and **no native MuonTrap Windows support** → drop "Windows," do not re-assert it.

  Exact NEW text (preserve the `Rindle.tmp/` + Ops-reaper sentence verbatim):
  ```
  13. Temp files for transcoding live under a single sweepable root
      (`Rindle.tmp/`); orphans are reaped by a scheduled `Rindle.Ops` worker.
      No transcode is allowed without an enforceable parent-death subprocess
      kill. MuonTrap is the sole subprocess runner on every platform
      (`Rindle.AV.Subprocess.run/3` → `MuonTrap.cmd/3`); its POSIX port wrapper
      kills the child when the BEAM dies on both Linux and macOS dev. cgroup
      resource caps (memory / CPU) are Linux-only and gated on
      `:os.type() == {:unix, :linux}`; on macOS the kill guarantee holds without
      cgroup caps. There is no Rambo dependency.
  ```
- **D-16:** Same-class staleness fix in the **same pass**: PROJECT.md Key-Decisions row
  (~line 503) `(FFmpex + MuonTrap)` → `(MuonTrap runner; argv built in-house, not FFmpex)` —
  FFmpex is not in `mix.lock`; argv is built in `build_args/3` for invariant-8 validation.
- **D-17:** **Scope the TRUTH-01 edit to Tier A only** (PROJECT.md lines ~459 and ~503).
  Leave the historical/archived artifacts (`.planning/research/v1.4/*`,
  `milestones/v1.4-REQUIREMENTS.md`, etc.) **intact** — rewriting point-in-time records would
  falsify history. Match on text strings, not line numbers (PROJECT.md is large/often-edited).
  PROJECT.md lines 58–59 (milestone's own description of the TRUTH-01 work) are accurate —
  no change.

### Claude's Discretion
- Exact internal injection seam for the deterministic synthetic test (D-08a), the precise
  iteration counts for D-08b / D-11, and the `Logger.debug` message string — left to
  researcher/planner within the locked constraints above.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Locked research & requirements (read first)
- `.planning/research/v1.21-SUBPROCESS-EPIPE.md` — the full root-cause + LOCKED Option-b1
  recommendation (HIGH). §2 mechanism, §3 candidate code, §4 idiomatic OTP, §5 peer-lib
  table, §8 requirement-ready bullets + the deterministic repro sketch.
- `.planning/REQUIREMENTS.md` — EPIPE-01..05 (lines 24–28), TRUTH-01 (line 61).
- `.planning/ROADMAP.md` §"Phase 109" (lines 98–135) — goal, success criteria, invariants.

### Source being changed / referenced
- `lib/rindle/av/subprocess.ex` — `run/3` (the seam); `build_args/3` + `build_opts/2` (MUST
  stay byte-untouched; platform gating at the `:os.type()` branch).
- `lib/rindle/processor/ffmpeg.ex` + `lib/rindle/av/ffprobe.ex` — call sites matching
  `{output, 0}` / `{output, status}`; MUST remain unchanged (EPIPE-02).
- `deps/muontrap/lib/muontrap/port.ex` — `do_cmd/4` (selective receive), `report_bytes_handled/2`
  (the ACK write), `rescue ArgumentError` (catches only the synchronous failure mode);
  `Port.open` links the port to the caller (no `:nolink`).
- `deps/muontrap/c_src/muontrap.c` — POSIX wrapper: stdin-EOF BEAM-death detection (~:634),
  `kill()` (~:336/:475), `procfile_killall` cgroup path (~:325) — basis for the TRUTH-01
  platform-accuracy wording.

### Truth-fix targets & project DNA
- `.planning/PROJECT.md` — invariant 13 (~line 456–459, the TRUTH-01 primary target),
  Key-Decisions row (~line 503), security invariants 8–13, decision D-v1.21-01 (~line 536,
  authorizes this `lib/` touch).
- `prompts/gsd-rindle-elixir-oss-dna.md` — project engineering DNA / design pillars; the shim,
  comment convention, canary, and observability call are all coherence-checked against it.
- Upstream: https://github.com/fhunleth/muontrap/issues/98 (OPEN as of 2026-06; present in
  1.7.0 / 1.8.0 / 2.0.0-rc.0).
- Existing repo conventions to mirror: `# NOTE (<REQ>, <cite>):` comments (e.g.
  `lib/rindle/domain/asset_fsm.ex:9`), behavioral tripwire tests
  (`test/.../api_surface_boundary_test.exs`), runtime version introspection
  (`Application.spec(:_, :vsn)`, `lib/rindle.ex:147`; `Version.compare` in probe.ex).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle.AV.Subprocess.run/3` is the **single chokepoint** all AV flows route through
  (`ProcessVariant`, `PromoteAsset`, waveform, output-probe) — fixing it here fixes every
  path at once (and protects adopter Oban workers, not just tests).
- `test/test_helper.exs` exclude list = `[:integration, :minio, :contract, :adopter]` (plus
  `:adopter` dropped for targeted runs). `:regression`, `:av`, `:canary` are **not excluded**
  → a bare `@tag :regression`/`:av` test gates by default. The canary must be explicitly
  excluded from the PR gate (D-12).
- Repo already has behavioral-tripwire precedent (`api_surface_boundary_test.exs`) and
  `Application.spec/2` version introspection — the canary reuses both patterns.

### Established Patterns
- `# NOTE (<REQ-ID>, <citation>):` + `# See: <url>` comment convention — D-13 follows it.
- Out-of-process AV with parent-death kill + Linux cgroup caps (invariant 13) — the shim must
  preserve this exactly (MuonTrap stays the runner with identical opts).
- Merge-blocking vs advisory/nightly lane split (DNA pillar 2) — regression test gates,
  canary is advisory.

### Integration Points
- New private `run_isolated/4` sits between `run/3` and `MuonTrap.cmd/3`; nothing else moves.
- `release-please`: a single `fix:` commit → patch bump to 0.3.2, auto-published on green main.

</code_context>

<specifics>
## Specific Ideas

- User explicitly requested deep one-shot subagent research per area (idiomatic Elixir/OTP,
  peer-lib + cross-language lessons, footguns, DX, design pillars, coherence) → done; the
  three research outputs back D-01..D-17.
- Cross-language north star for the shim (Ruby `Errno::EPIPE` / Python `BrokenPipeError` /
  Node `EPIPE` / Go `EPIPE`): "a write that loses its reader **after** the work is done is
  benign — swallow it." b1 is the BEAM-idiomatic encoding; narrow the swallow to exactly
  `:epipe`, re-raise every other reason.

</specifics>

<deferred>
## Deferred Ideas

- File/track an upstream fix for MuonTrap #98 (optional, out-of-band; not blocking this phase).
- Eventual removal of the shim + canary once #98 ships upstream and the pin is bumped —
  governed by D-13's removal condition; belongs to a future cleanup, not this phase.
- Async-isolation hardening (`Config.repo/0` `$callers` override) → Phase 110.
- Durable shipped-artifact regression-lock meta-tests → Phase 111.

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 109-subprocess-epipe-hardening*
*Context gathered: 2026-06-28*
