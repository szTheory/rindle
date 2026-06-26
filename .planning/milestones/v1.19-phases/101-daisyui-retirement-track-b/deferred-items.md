# Phase 101 Deferred Items

## Out-of-Scope Backstop Failure: Admin E2E Root Selector Strictness

- **Found during:** 101-04 Task 2 (`bash scripts/ci/adoption_demo_e2e.sh`)
- **Command result:** Full wrapper reached Playwright and ended with 30 passed, 1 skipped, 15 failed.
- **Scope classification:** Out of scope for Phase 101 Plan 04. The failures are admin-console specs, not Cohort page or upload behavior specs.
- **Observed failure shape:** `locator('[data-rindle-admin-root]')` resolves to both `.rindle-admin-shell` and `.rindle-admin-page`, causing Playwright strict-mode failures in admin helper calls such as `expectAdminShell/2` and `selectAdminTheme/2`.
- **Phase 101 status:** Cohort backstops passed independently after `default.css` deletion: `cohort-pages.spec.js` passed 15/15 and the six upload behavior specs passed 6/6.
- **Recommended follow-up:** Fix the admin Playwright helper or admin root marker ownership in the admin-console track. Do not address it in Phase 101's Cohort daisyUI retirement plan.
