---
phase: 111
slug: regression-locks
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-28
---

# Phase 111 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
>
> Note: this phase's deliverables ARE validation artifacts (merge-blocking
> meta-tests). Each lock is itself a pure string/AST scan over a shipped
> artifact. "Validating the validators" here means: each meta-test must
> RED on the regression it guards and GREEN on current `main` — and must
> not vacuously pass on an empty glob. See `111-RESEARCH.md` §Validation
> Architecture for the per-lock regression/anti-vacuous matrix.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (`mix test` / `mix coveralls`) |
| **Config file** | `test/test_helper.exs`, `mix.exs` (no new config) |
| **Quick run command** | `mix test test/<new_meta_test>.exs` |
| **Full suite command** | `mix test` (merge-blocking `quality` lane) |
| **Estimated runtime** | ~1–3 s per meta-test (pure file scans, `async: true`) |

LOCK-02 is a CI `run:` step (no ExUnit test) — exercised by the
`package-consumer` lane on every PR; verified by reading `ci.yml`.

---

## Sampling Rate

- **After every task commit:** Run `mix test test/<file_touched>.exs`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite green; LOCK meta-tests each
  proven to RED against a deliberately-mutated artifact, then GREEN.
- **Max feedback latency:** ~10 s (full suite is fast; no browser in these locks)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| {planner fills} | — | — | LOCK-01 | — | phx.new probe+self-install stays, precedes smoke | meta-test (scan) | `mix test test/install_smoke/...` | ❌ W0 | ⬜ pending |
| {planner fills} | — | — | LOCK-02 | — | phx.new archive purged before package-consumer smoke | CI step (read ci.yml) | n/a (CI) | ❌ W0 | ⬜ pending |
| {planner fills} | — | — | LOCK-03 | — | single `focusVisibly` helper exported + consumed by all sites | refactor (sites call helper) | `mix test test/focus_visible_modality_guard_test.exs` | ❌ W0 | ⬜ pending |
| {planner fills} | — | — | LOCK-04 | — | Tab-first at every focusVisible site; no raw call outside helper | meta-test (scan) | `mix test test/focus_visible_modality_guard_test.exs` | ❌ W0 | ⬜ pending |
| {planner fills} | — | — | LOCK-05 | — | no `test/**/*.exs` reads a `.planning/` path | meta-test (glob) | `mix test test/planning_path_hygiene_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- ExUnit infrastructure already exists (`test/install_smoke/` family,
  `test/async_safety_guard_test.exs`) — no framework install needed.
- New meta-test files are themselves the Wave deliverables; they have no
  upstream stub dependency (each scans a shipped artifact directly).

*Existing infrastructure covers all phase requirements — no Wave 0 install.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Cold-runner self-install path actually exercised | LOCK-02 | Lives in CI `package-consumer` lane, not ExUnit | Confirm `ci.yml` purge step precedes the smoke; observe a PR run takes the self-install path |

*All ExUnit-expressible behaviors (LOCK-01/03/04/05) have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Each meta-test proven RED-against-regression, GREEN-on-main (anti-theater)
- [ ] Anti-vacuous guard present where a glob can match zero files (`assert files != []`)
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
