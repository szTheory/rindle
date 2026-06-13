---
phase: 92
slug: e2e-screenshot-driven-polish-loop
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-13
---

# Phase 92 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Playwright (`@playwright/test`) plus targeted ExUnit for admin LiveViews |
| **Config file** | `examples/adoption_demo/playwright.config.js` |
| **Quick run command** | `cd examples/adoption_demo && npx playwright test e2e/admin-console.spec.js` |
| **Full suite command** | `bash scripts/ci/adoption_demo_e2e.sh` |
| **Estimated runtime** | ~5-15 minutes for full adoption demo lane |

---

## Sampling Rate

- **After every task commit:** Run the targeted Playwright or ExUnit command named in the task.
- **After every plan wave:** Run `bash scripts/maintainer/check_adoption_proof_matrix.sh` plus the relevant admin Playwright specs.
- **Before `$gsd-verify-work`:** `bash scripts/ci/adoption_demo_e2e.sh` must pass.
- **Max feedback latency:** Targeted specs should give feedback in under 120 seconds; the full lane is acceptable only at plan/phase gates.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 92-01-01 | 01 | 1 | E2E-01 | T-92-01 | No raw provider/session secrets in console assertions | Playwright helper/source | `cd examples/adoption_demo && npx playwright test e2e/admin-console.spec.js` | ❌ W0 | ⬜ pending |
| 92-01-02 | 01 | 1 | E2E-01 | T-92-02 | Destructive flows require collateral preview and exact typed confirmation | Playwright E2E | `cd examples/adoption_demo && npx playwright test e2e/admin-actions.spec.js` | ❌ W0 | ⬜ pending |
| 92-02-01 | 02 | 2 | E2E-02 | T-92-03 | Screenshots contain no raw secret tokens and are generated from live app state | Playwright screenshot | `cd examples/adoption_demo && npx playwright test e2e/admin-screenshots.spec.js` | ❌ W0 | ⬜ pending |
| 92-02-02 | 02 | 2 | E2E-02 | — | Expected screenshot count exists for light and dark route matrix | Playwright/source | `cd examples/adoption_demo && npx playwright test e2e/admin-screenshots.spec.js` | ❌ W0 | ⬜ pending |
| 92-03-01 | 03 | 3 | E2E-01, E2E-02 | — | Merge-blocking proof matrix names new browser proof files | shell/proof | `bash scripts/maintainer/check_adoption_proof_matrix.sh` | ✅ | ⬜ pending |
| 92-03-02 | 03 | 3 | E2E-01, E2E-02 | — | Full packaged adoption demo lane remains green | CI wrapper | `bash scripts/ci/adoption_demo_e2e.sh` | ✅ | ⬜ pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `examples/adoption_demo/e2e/support/admin.js` — shared admin console helpers.
- [ ] `examples/adoption_demo/e2e/admin-console.spec.js` — surface, boundary, detail, theme happy/error coverage.
- [ ] `examples/adoption_demo/e2e/admin-actions.spec.js` — destructive and non-destructive action flows.
- [ ] `examples/adoption_demo/e2e/admin-screenshots.spec.js` — live app screenshot matrix with expected-file assertions.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Visual polish judgment after screenshots | E2E-02 | Automated capture proves coverage; final visual taste may require human review of generated PNGs. | Inspect `examples/adoption_demo/test-results/admin-screenshots/` after the screenshot spec. File follow-up fixes for overlap, clipped text, contrast, horizontal scroll, or unstable dimensions. |

Automated gates remain required even when human screenshot review is performed.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s for targeted specs
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
