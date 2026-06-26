---
phase: 94
slug: foundation-token-pipeline-ci-gate-new-token-categories
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-14
---

# Phase 94 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Node `.mjs` generators + `git diff --exit-code` (idempotency anchor); Playwright (admin-polish/gallery-check); `mix test` (Elixir CSS-parity assertion) |
| **Config file** | `e2e/playwright.config.js`; `.github/workflows/ci.yml` (new `brandbook-tokens` job) |
| **Quick run command** | `node brandbook/src/tokens-build.mjs && node brandbook/src/admin-css-build.mjs && git diff --exit-code` |
| **Full suite command** | `brandbook-tokens` CI job: regen → contrast → gallery-check → sync → `git diff --exit-code` |
| **Estimated runtime** | ~60–120 seconds (incl. Playwright chromium) |

---

## Sampling Rate

- **After every task commit:** Run quick command (regen + `git diff --exit-code`)
- **After every plan wave:** Run the full `brandbook-tokens` job locally
- **Before `/gsd:verify-work`:** Full gate must be green (empty diff)
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| {N}-01-01 | 01 | 1 | PIPE-01 | — | N/A | integration | `git diff --exit-code` after regen | ❌ W0 (new CI job) | ⬜ pending |

*Planner fills the remaining rows. Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `.github/workflows/ci.yml` — new `brandbook-tokens` job (the primary validator for PIPE-01)
- [ ] Regenerate + commit pre-existing stale `tokens.css` / CSS artifacts so the gate goes red→green

*Existing `.mjs` generator + contrast + gallery-check infrastructure covers the rest.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Token *values* (clamp tuples, dark-status hexes) look correct | VIS-01 | Visual/aesthetic judgment deferred to `/gsd:ui-phase 94` | Out of Phase 94 scope — shape only |

*All Phase 94 wiring behaviors have automated verification via the CI gate.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
