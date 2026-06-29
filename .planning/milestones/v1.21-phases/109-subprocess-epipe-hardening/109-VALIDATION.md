---
phase: 109
slug: subprocess-epipe-hardening
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-28
---

# Phase 109 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `109-RESEARCH.md` § Validation Architecture (approach LOCKED to Option b1).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (bundled with Elixir; home cell 1.17 / OTP 27) |
| **Config file** | `test/test_helper.exs` (exclude list ~line 24-29; MUST add `:canary`) |
| **Quick run command** | `mix test test/rindle/av/subprocess_epipe_test.exs --seed 0` |
| **Full suite command** | `mix test` (PR gate) / `mix coveralls` (CI + nightly) |
| **Estimated runtime** | ~30-45s for the stress assertion; <1s for the synthetic |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/rindle/av/subprocess_epipe_test.exs --seed 0` (new deterministic + stress assertions — fast, deterministic feedback)
- **After every plan wave:** Run `mix test` (full default suite; now excludes `:canary`; includes the two unmodified flaking tests + argv/security tests)
- **Before `/gsd-verify-work`:** Full suite must be green; canary run once via `--include canary` to confirm it currently reproduces
- **Max feedback latency:** ~45 seconds

---

## Per-Task Verification Map

> Task IDs are assigned by the planner; this maps each requirement to its validation. Lane column marks the merge-blocking vs advisory split (D-12).

| Requirement | Wave | Behavior | Test Type | Automated Command | Lane | File Exists |
|-------------|------|----------|-----------|-------------------|------|-------------|
| EPIPE-01 | post-Wave 0 | `:epipe` never kills caller; real `{output, status}` returned | deterministic synthetic | `mix test test/rindle/av/subprocess_epipe_test.exs --seed 0` | merge-blocking | ❌ W0 |
| EPIPE-01 (pre-reply) | post-Wave 0 | single-retry on pre-reply `:DOWN/:epipe`; `Logger.debug` emitted | deterministic synthetic (2nd test) | same file | merge-blocking | ❌ W0 |
| EPIPE-02 | n/a | contract `{collectable, non_neg \| :timeout}` preserved; call sites unchanged | existing call-site + unmodified flaking tests | `mix test test/rindle/processor/ffmpeg_test.exs test/rindle/av/ffprobe_test.exs` | merge-blocking | ✅ |
| EPIPE-03 | n/a | argv/caps byte-equivalent; no shell | static byte-freeze + existing argv/security tests | `mix test test/rindle/security/` | merge-blocking | ✅ |
| EPIPE-04 | post-Wave 0 | fails unpatched / passes patched; reproduces under high output | real-subprocess stress | `mix test test/rindle/av/subprocess_epipe_test.exs` | merge-blocking | ❌ W0 |
| EPIPE-05 | post-Wave 0 | forward-compatible no-op; no double-handling / leaked monitors | code comment (D-13) + demonitor/drain proven by synthetic | covered by EPIPE-01 synthetic | merge-blocking | ❌ W0 |
| D-09 | n/a | two originally-flaking tests pass UNMODIFIED | regression (no edits to those files) | `mix test test/rindle/processor/ffmpeg_test.exs:32 test/rindle/ops/lifecycle_repair_test.exs:122` | merge-blocking | ✅ (byte-identical) |
| cleanup signal | post-Wave 0 | MuonTrap #98 still reproduces (remove-shim trigger) | behavioral canary | `mix test test/rindle/av/subprocess_epipe_canary_test.exs --include canary` | **ADVISORY (nightly)** | ❌ W0 |
| TRUTH-01 | post-Wave 0 | invariant 13 / Key-Decisions prose corrected | CI grep step (`quality` lane) — NOT ExUnit, avoids Phase 111 LOCK-05 collision | asserts `Rambo` absent from invariant 13 + `FFmpex + MuonTrap` absent from Key-Decisions | merge-blocking | ❌ W0 |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/rindle/av/subprocess_epipe_test.exs` — deterministic synthetic (RESEARCH §1) + real stress (§2); covers EPIPE-01/04/05
- [ ] `test/rindle/av/subprocess_epipe_canary_test.exs` — advisory canary (§3); cleanup signal
- [ ] `test/test_helper.exs` — add `:canary` to both exclude branches (§4 step 1) — **LOAD-BEARING** (a bare `@tag :canary` would otherwise gate PRs)
- [ ] TRUTH-01 CI grep step in the merge-blocking `quality` lane — asserts the corrected prose landed and guards regression (NOT an ExUnit test reading `.planning/` — would collide with Phase 111 LOCK-05)

*ExUnit ships with Elixir — no framework install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| — | — | — | All phase behaviors have automated verification. |

*All phase behaviors have automated verification (the canary is automated but routed to the advisory nightly lane).*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 45s (stress test ~30-45s — watch CI p95; drop to 200-iter floor if it regresses)
- [x] `:canary` excluded from default `mix test` (PR gate safety, D-12)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-06-28 (gsd-plan-checker Dim 8 PASS)
