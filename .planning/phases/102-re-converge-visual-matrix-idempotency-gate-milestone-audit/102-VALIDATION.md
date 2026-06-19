---
phase: 102
slug: re-converge-visual-matrix-idempotency-gate-milestone-audit
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-19
---

# Phase 102 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Playwright `@playwright/test@1.60.0` for browser matrix; ExUnit/Mix for Cohort contract checks; Node scripts for static token/contrast/idempotency gates |
| **Config file** | `examples/adoption_demo/playwright.config.js`; `examples/adoption_demo/mix.exs`; `.github/workflows/ci.yml` |
| **Quick run command** | `node --check examples/adoption_demo/e2e/support/admin-polish.js examples/adoption_demo/e2e/admin-screenshots.spec.js examples/adoption_demo/e2e/cohort-pages.spec.js examples/adoption_demo/e2e/cohort-styleguide.spec.js` |
| **Targeted command** | `cd examples/adoption_demo && npx playwright test e2e/admin-screenshots.spec.js e2e/cohort-pages.spec.js e2e/cohort-styleguide.spec.js` |
| **Contract command** | `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` |
| **Static command** | `node brandbook/src/cohort-contrast.mjs` |
| **Full suite command** | `bash scripts/ci/adoption_demo_e2e.sh` |
| **Adoption-demo completion command** | `cd examples/adoption_demo && mix precommit` |
| **Estimated runtime** | quick: <10s; targeted/static/contract: minutes; full wrapper: CI-scale |

---

## Sampling Rate

- **After every task commit:** Run the quick JS syntax command plus the narrow command for the touched surface.
- **After every plan wave:** Run the targeted Playwright matrix specs, `cohort_migration_contract_test.exs`, and `cohort-contrast.mjs`.
- **Before `$gsd-verify-work`:** Full `scripts/ci/adoption_demo_e2e.sh`, adoption-demo `mix precommit`, brandbook double-run diff proof, traceability docs, and milestone audit evidence must be green/current.
- **Max feedback latency:** Use quick syntax/static/contract checks before expensive browser wrapper runs; do not batch more than two implementation tasks without an automated proof command.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 102-01-T1 | 102-01 | 1 | VIS-01, VIS-02 | T-102-01, T-102-04 | Admin root assertions stay explicit and strict-locator safe | source + Playwright | `node --check examples/adoption_demo/e2e/support/admin.js examples/adoption_demo/e2e/admin-screenshots.spec.js && (cd examples/adoption_demo && npx playwright test e2e/admin-screenshots.spec.js --grep "captures admin-screenshots light and dark matrix")` | yes | mapped |
| 102-01-T2 | 102-01 | 1 | VIS-01, VIS-02 | T-102-02 | Admin 24-state matrix and Phase 98 backstops cannot be removed to make the lane green | source assertion | `node -e "const fs=require('fs');const s=fs.readFileSync('examples/adoption_demo/e2e/admin-screenshots.spec.js','utf8');for (const token of ['toHaveLength(24)','assertTwoPaneBand','assertStackedCard','assertReducedMotion','assertDialogInert','assertFocusVisibleVsPointer']) { if (!s.includes(token)) throw new Error('missing '+token); }"` | yes | mapped |
| 102-02-T1 | 102-02 | 1 | VIS-01, VIS-02 | T-102-03 | Focus assertions use explicit admin defaults or caller-supplied Cohort focus contract | source + module export | `node --check examples/adoption_demo/e2e/support/admin-polish.js && node -e "const mod=require('./examples/adoption_demo/e2e/support/admin-polish.js'); for (const k of ['assertAdminPolish','DEFAULT_ROOT','DEFAULT_INTERACTIVE_SELECTORS']) { if (!(k in mod)) throw new Error('missing '+k); }"` | yes | mapped |
| 102-02-T2 | 102-02 | 1 | VIS-01, VIS-02 | T-102-02, T-102-04 | Generic checks are root-scoped and admin-only backstops are opt-in for non-admin callers | source assertion | `node --check examples/adoption_demo/e2e/support/admin-polish.js examples/adoption_demo/e2e/admin-screenshots.spec.js examples/adoption_demo/e2e/cohort-pages.spec.js examples/adoption_demo/e2e/cohort-styleguide.spec.js && node -e "const fs=require('fs');const s=fs.readFileSync('examples/adoption_demo/e2e/support/admin-polish.js','utf8');if(!s.includes('assertTwoPaneBand')||!s.includes('assertDialogInert')) throw new Error('admin backstops missing'); if(!s.includes('focusContract')) throw new Error('focus contract option missing');"` | yes | mapped |
| 102-03-T1 | 102-03 | 1 | VIS-01, VIS-02 | T-102-03 | Theme query input is allowlisted without atom creation | ExUnit | `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` | yes | mapped |
| 102-03-T2 | 102-03 | 1 | VIS-01, VIS-02 | T-102-03, T-102-05 | Dashboard, ops, and account erasure dark routes render explicit Cohort root state | ExUnit + static | `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs && node ../../brandbook/src/cohort-contrast.mjs` | yes | mapped |
| 102-04-T1 | 102-04 | 2 | VIS-01, VIS-02 | T-102-03, T-102-04 | Member and lesson dark routes preserve seeded route contracts | ExUnit | `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` | yes | mapped |
| 102-04-T2 | 102-04 | 2 | VIS-01, VIS-02 | T-102-03, T-102-04 | Post and media dark routes preserve detail IDs, testids, and variant contracts | ExUnit + static | `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs && node ../../brandbook/src/cohort-contrast.mjs` | yes | mapped |
| 102-05-T1 | 102-05 | 3 | VIS-01, VIS-02 | T-102-02 | Cohort visual offenders and helper crashes fail the Playwright test | source syntax | `node --check examples/adoption_demo/e2e/support/admin-polish.js examples/adoption_demo/e2e/cohort-pages.spec.js` | yes | mapped |
| 102-05-T2 | 102-05 | 3 | VIS-01, VIS-02 | T-102-03, T-102-04 | Cohort matrix covers locked routes, themes, and viewports with rendered dark assertions | Playwright | `node --check examples/adoption_demo/e2e/cohort-pages.spec.js && (cd examples/adoption_demo && npx playwright test e2e/cohort-pages.spec.js)` | yes | mapped |
| 102-05-T3 | 102-05 | 3 | VIS-01, VIS-02, VIS-03, VIS-04 | T-102-02, T-102-06 | Styleguide hard-fails on computed-style defects while screenshots remain non-blocking | Playwright + source assertion | `node --check examples/adoption_demo/e2e/cohort-styleguide.spec.js examples/adoption_demo/e2e/admin-screenshots.spec.js && (cd examples/adoption_demo && npx playwright test e2e/admin-screenshots.spec.js e2e/cohort-pages.spec.js e2e/cohort-styleguide.spec.js) && node -e "const fs=require('fs');const s=fs.readFileSync('examples/adoption_demo/e2e/admin-screenshots.spec.js','utf8');if(!s.includes('toHaveLength(24)')) throw new Error('admin matrix count changed');"` | yes | mapped |
| 102-06-T1 | 102-06 | 4 | VIS-01, VIS-02 | T-102-02, T-102-06 | Full adoption-demo proof and Phoenix local completion gate must be green before VIS closure | full gate + precommit | `bash scripts/ci/adoption_demo_e2e.sh && (cd examples/adoption_demo && mix precommit) && (cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs) && node brandbook/src/cohort-contrast.mjs` | yes | mapped |
| 102-06-T2 | 102-06 | 4 | VIS-02 | T-102-05 | Existing generated admin gates are idempotent and Cohort CSS remains hand-authored | idempotency | `node brandbook/src/tokens-build.mjs && node brandbook/src/admin-css-build.mjs && node brandbook/src/admin-contrast.mjs && node brandbook/src/admin-gallery-check.mjs && node brandbook/src/sync-admin-css.mjs && node brandbook/src/cohort-contrast.mjs && git diff --exit-code` | yes | mapped |
| 102-06-T3 | 102-06 | 4 | VIS-01, VIS-02, VIS-03, VIS-04 | T-102-07 | Milestone claims match exact verification evidence and optional artifacts are labeled non-blocking | docs assertion | `test -f .planning/milestones/v1.19-MILESTONE-AUDIT.md && node -e "const fs=require('fs');const req=fs.readFileSync('.planning/REQUIREMENTS.md','utf8');for (const id of ['VIS-01','VIS-02','VIS-03','VIS-04']) { const row=req.match(new RegExp('\\\\*\\\\*'+id+'\\\\*\\\\*[\\\\s\\\\S]{0,220}')); if(!row || !/\\[x\\]|Complete/.test(row[0])) throw new Error('VIS not complete: '+id); } const audit=fs.readFileSync('.planning/milestones/v1.19-MILESTONE-AUDIT.md','utf8'); for (const token of ['adoption_demo_e2e.sh','git diff --exit-code','non-blocking']) { if(!audit.includes(token)) throw new Error('audit missing '+token); }"` | yes | mapped |

*Status: mapped means the planning validation row has a concrete plan, wave, and automated command; execution results are recorded in plan summaries.*

---

## Planning Coverage Requirements

- [x] `102-01` maps strict admin root locator disambiguation to automated source and Playwright checks.
- [x] `102-02` maps explicit focus contract and surface/admin-backstop scoping to automated JS/source checks.
- [x] `102-03` and `102-04` map rendered light/dark route support for all non-upload migrated pages to ExUnit and static checks.
- [x] `102-05` maps the hard-fail Cohort light/dark/mobile matrix and styleguide promotion to automated Playwright checks.
- [x] `102-06` maps traceability, roadmap, state, v1.19 milestone audit evidence, full wrapper, idempotency proof, and adoption-demo `mix precommit` completion check.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| v1.19 milestone audit truthfulness | VIS-04 | Requires comparing command evidence, traceability claims, and release-train posture | Review `.planning/milestones/v1.19-MILESTONE-AUDIT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, and `.planning/STATE.md` after all commands pass. |
| Optional pixel/gallery artifact classification | VIS-03, VIS-04 | Non-blocking status is a documentation and CI-topology assertion, not only a runtime behavior | Confirm `.github/workflows/ci.yml` and Playwright specs do not make screenshots the VIS-01 blocker; audit docs must label them non-blocking if present. |

---

## Validation Sign-Off

- [x] All tasks have automated verify commands mapped to concrete plan IDs.
- [x] Sampling continuity: no 3 consecutive implementation tasks lack automated verify coverage.
- [x] Planning coverage maps all missing readiness references to `102-01` through `102-06`.
- [x] No watch-mode flags.
- [x] Full wrapper, adoption-demo `mix precommit`, and idempotency proof are mapped before closure.
- [x] `nyquist_compliant: true` set in frontmatter after planner maps tasks to concrete plan IDs.

**Approval:** planning validation map complete; execution evidence remains pending until plan summaries are produced.
