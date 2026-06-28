# Phase 109: Subprocess `:epipe` hardening - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-28
**Phase:** 109-subprocess-epipe-hardening
**Areas discussed:** Regression test strategy, Retry policy, TRUTH-01 wording, Forward-compat/cleanup signal, Shim shape

---

## Regression test strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Synthetic + light stress | Deterministic injected-signal test + small fast real-subprocess stress check; both `@tag :regression`, merge-blocking | ✓ |
| Real-subprocess stress only | Research's high-volume loop as-is; "deterministic" only in practice; slower per PR | |
| Synthetic deterministic only | Injected-signal unit test only; no real subprocess path exercised | |

**User's choice:** Synthetic + light stress (recommended).
**Notes:** Synthetic sub-test owns determinism/fast-feedback; the bounded real-subprocess
stress sub-test owns the EPIPE-04 "fails unpatched, passes patched" property. See D-08/D-09.

---

## Retry policy (pre-reply `:DOWN/:epipe`)

| Option | Description | Selected |
|--------|-------------|----------|
| Bounded single retry | Explicit counter, one retry then re-raise; removes the snippet's unbounded recursion | ✓ |
| Absorb-only, no retry | Drop the retry; `exit(reason)` on any pre-reply death | |
| Unbounded retry (as written) | Research snippet verbatim; latent infinite loop | |

**User's choice:** Bounded single retry (recommended).
**Notes:** Worker traps exits, so the branch is rare; the retry is belt-and-suspenders with an
explicit `retries_left` counter. All non-`:epipe`/exhausted reasons re-raise. See D-05/D-06.

---

## TRUTH-01 wording, Forward-compat/cleanup signal, Shim shape

| Option (multi-select) | Description | Selected |
|--------|-------------|----------|
| TRUTH-01 wording | Exact correction of invariant 13's stale Rambo clause | ✓ |
| Forward-compat / cleanup signal | No-op degradation + #98 comment + removal trigger | ✓ |
| Shim shape confirm | spawn_monitor worker vs in-place trap_exit | ✓ |

**User's choice:** All three — with an explicit request to research each deeply via subagents
(idiomatic Elixir/OTP, peer-lib + cross-language lessons, footguns, DX, design pillars,
coherence with project DNA/`prompts/`), and one-shot a coherent locked set of recommendations.

**Notes / research outcomes:**
- **Shim shape:** `spawn_monitor` + `trap_exit`'d worker confirmed (canonical OTP "own the
  port from a dedicated process" pattern). In-place trap_exit **disqualified** — would mutate
  the caller's `trap_exit` flag (library must not) and cause mailbox cross-contamination for
  GenServer/Oban-worker callers. `Task.async` rejected (links → propagates). Observability:
  `Logger.debug` only in the retry branch, no telemetry, happy-path silent. See D-01..D-07.
- **Forward-compat/cleanup:** **Version tripwire rejected** — critical finding that #98 is
  present in muontrap 1.7.0 / 1.8.0 / 2.0.0-rc.0 (no fixed version exists), so a version pin
  would false-alarm on the next benign bump. Replaced with a **behavioral canary** that
  probes unguarded `MuonTrap.cmd/3` and fails loudly when the bug stops reproducing
  (advisory/nightly lane, `@tag :canary`). No-op degradation proven; double-handling-safe.
  See D-10..D-14.
- **TRUTH-01:** Exact corrected invariant-13 text locked (MuonTrap sole runner all platforms;
  parent-death kill Linux+macOS; cgroup caps Linux-only; no Rambo; drop "Windows"). Same-pass
  fix for the stale `FFmpex + MuonTrap` decision row. Scope to Tier A (PROJECT.md only); leave
  historical archives intact. See D-15..D-17.

---

## Claude's Discretion

- Exact internal injection seam for the deterministic synthetic regression test.
- Precise iteration counts for the stress and canary tests; the `Logger.debug` message string.

## Deferred Ideas

- File/track upstream MuonTrap #98 (optional, non-blocking).
- Remove the shim + canary once #98 ships and the pin is bumped (future cleanup phase).
- Async-isolation hardening → Phase 110; regression-lock meta-tests → Phase 111.
