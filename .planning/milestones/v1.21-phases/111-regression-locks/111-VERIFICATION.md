---
phase: 111-regression-locks
verified: 2026-06-28T00:00:00Z
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 111: Regression locks Verification Report

**Phase Goal:** The already-fixed 2026-06-26 cluster gets durable, merge-blocking, shipped-artifact-only locks so it cannot silently regress — asserting SHIPPED artifacts only, never `.planning/` paths.
**Verified:** 2026-06-28
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Roadmap Success Criteria = LOCK-01..05)

| # | Truth (LOCK) | Status | Evidence |
| --- | --- | --- | --- |
| 1 | LOCK-01: merge-blocking meta-test asserts `install_smoke.sh` keeps the `phx.new` probe + self-install before the smoke | ✓ VERIFIED | `test/install_smoke/install_smoke_preflight_test.exs` asserts `mix phx.new --version` (script L31), `mix archive.install hex phx_new --force` (script L33), AND order: install_idx < `generated_app_smoke_test.exs` idx (script L33 < L56/59). `:binary.match` raises if a token is deleted — loud, not vacuous. `async: true`, no exclude tag → default suite. Passes (live). |
| 2 | LOCK-02: `package-consumer` CI step purges `phx.new` archive before the smoke so cold-cache path runs every PR | ✓ VERIFIED | `ci.yml:654` `mix archive.uninstall phx_new --force \|\| true` in the lean `package-consumer:` job (L541), positioned BEFORE the smoke `bash scripts/install_smoke.sh image` (L659-660). NOT in off-PR `package-consumer-full` (L686). |
| 3 | LOCK-03: Tab-first modality helper deduped into one exported function consumed by both harnesses | ✓ VERIFIED | `focusVisibly(page, locator)` defined `admin-polish.js:124`, exported L1125; 3 former sites now call it (admin L452, L945; gallery L177); gallery destructures it from existing `adoptionRequire` import (L25). Raw call-form count: admin=1, gallery=0. `node --check` clean on both. |
| 4 | LOCK-04: merge-blocking meta-test asserts Tab-first modality at every focusVisible site (post-dedupe, shared helper) | ✓ VERIFIED | `test/focus_visible_modality_guard_test.exs` dual-assert: (a) Tab idx < focus call-form idx inside helper (`keyboard.press("Tab")` L125 < `focus({focusVisible:true})` L129); (b) call-form count == 1 in admin, == 0 in gallery. Anti-vacuous `assert files != []`. Call-form regex avoids comment-noise. Simulated 4th-copy regression → count 2 → assertion fails (proven). `async:true`, no tag. |
| 5 | LOCK-05: merge-blocking meta-test fails if any `test/**/*.exs` reads a `.planning/` path | ✓ VERIFIED | `test/planning_path_hygiene_test.exs` globs `test/**/*.exs`, anti-vacuous `assert files != []` (L44), regex (read-call + planning-token on same line) assembled at runtime to avoid self-flagging. `async:true`, no tag. Currently green. |

**Score:** 5/5 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `test/install_smoke/install_smoke_preflight_test.exs` | LOCK-01 guard | ✓ VERIFIED | 51 lines, substantive, in default suite |
| `test/planning_path_hygiene_test.exs` | LOCK-05 guard | ✓ VERIFIED | 85 lines, anti-vacuous glob |
| `test/focus_visible_modality_guard_test.exs` | LOCK-04 guard | ✓ VERIFIED | 142 lines, dual-assert, anti-vacuous |
| `.github/workflows/ci.yml` (purge step) | LOCK-02 cold-path | ✓ VERIFIED | +8 lines only; lean job; before smoke |
| `examples/adoption_demo/e2e/support/admin-polish.js` | LOCK-03 helper owner | ✓ VERIFIED | `focusVisibly` defined+exported; 1 call-form |
| `brandbook/src/admin-gallery-check.mjs` | LOCK-03 consumer | ✓ VERIFIED | imports+calls `focusVisibly`; 0 call-form |

### Key Link Verification

| From | To | Via | Status |
| --- | --- | --- | --- |
| LOCK-01 test | `scripts/install_smoke.sh` | `File.read!` of shipped script, never `.planning/` | WIRED |
| LOCK-02 purge | smoke step | positioned ~L654 before L659 in `package-consumer` | WIRED |
| gallery | `focusVisibly` | existing `adoptionRequire(...admin-polish.js)` import | WIRED |
| LOCK-04 test | both harnesses | reads `examples/` + `brandbook/` shipped paths only | WIRED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| 3 new meta-tests pass live | `mix test` on the 3 files | 4 tests, 0 failures | ✓ PASS |
| JS files parse | `node --check` (both) | OK | ✓ PASS |
| LOCK-04 anti-vacuous | simulate 4th raw copy → count | 1 → 2 (would fail `==1`) | ✓ PASS |

### Hard Invariants

| Invariant | Status | Evidence |
| --- | --- | --- |
| `name: CI` unchanged | ✓ HELD | ci.yml L1 `name: CI`; diff touches only L645-658 |
| ci.yml filename unchanged | ✓ HELD | `.github/workflows/ci.yml` (no rename in diff) |
| `CI Summary` sole required check, needs block byte-unchanged | ✓ HELD | ci.yml diff = ONLY the 8-line purge step; ci-summary block untouched |
| Meta-tests assert SHIPPED artifacts only, never `.planning/` | ✓ HELD | No read-call reads `.planning/` in any new test; only moduledoc prose mentions |
| Zero `lib/` change (no semver impact) | ✓ HELD | `git diff ff8a9ae..HEAD` source files = ci.yml, brandbook/, examples/, test/ only — no `lib/` |

### Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
| --- | --- | --- | --- |
| LOCK-01 | 111-01 | ✓ SATISFIED | install_smoke_preflight_test.exs |
| LOCK-02 | 111-02 | ✓ SATISFIED | ci.yml purge step |
| LOCK-03 | 111-03 | ✓ SATISFIED | focusVisibly dedupe |
| LOCK-04 | 111-04 | ✓ SATISFIED | focus_visible_modality_guard_test.exs |
| LOCK-05 | 111-01 | ✓ SATISFIED | planning_path_hygiene_test.exs |

No orphaned requirements — all 5 LOCK reqs mapped to Phase 111 in REQUIREMENTS.md are claimed by plans.

### Anti-Patterns Found

None. No `TBD`/`FIXME`/`XXX` markers in phase-modified source. The empty `POLISH_EXEMPTIONS` allowlist (admin-polish.js L137) ships intentionally empty (documented). The `|| true` on the purge step is intended cold-runner idempotence, not a stub.

### Gaps Summary

No gaps. All five LOCK requirements map to concrete shipped artifacts that exist, are substantive, are wired into the merge-blocking lanes (quality lane via untagged default-suite tests; package-consumer lane via the cold-path purge), and red-gate non-vacuously (anti-vacuous `assert files != []` guards present; LOCK-04 count regression simulated and proven to fail). The ci.yml hard invariants held byte-for-byte (only the 8-line purge step was added). Zero `lib/` change → no semver impact. No new meta-test reads a `.planning/` path.

---

_Verified: 2026-06-28_
_Verifier: Claude (gsd-verifier)_
