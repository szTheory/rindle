---
status: complete
phase: 91-cohort-demo-evolution
source: [91-01-SUMMARY.md, 91-02-SUMMARY.md, 91-03-SUMMARY.md]
scope: net-new (logo + lifecycle display already passed in 91-HUMAN-UAT.md)
resolution: automated — all checkpoints discharged by integration/e2e tests in merge-blocking CI (0 human verification required)
started: 2026-06-14T18:19:39Z
updated: 2026-06-14T18:43:06Z
---

## Current Test

[testing complete]

## Tests

### 1. Cold Start Smoke Test
expected: Boot the Cohort demo from scratch; the stack comes up without errors, seeds complete, and the homepage loads with live data.
result: pass
evidence: |
  Automated on both boot paths, replacing human verification:
  - Native boot: e2e/smoke.spec.js asserts http://localhost:4102/ serves the
    launchpad (brand mark + "What do you want to do?" + seeded minioadmin creds)
    after the e2e job's cold ecto.drop→create→migrate→seed. Passed against the
    live server.
  - Docker-compose boot (the path that broke twice — prod-guard compile fail,
    stale Elixir pin): scripts/ci/cohort_demo_smoke.sh + the merge-blocking
    `Cohort Demo Smoke` CI lane build the demo image, boot the full stack, and
    assert / , /admin/rindle , /admin/rindle/assets all return 200 with seeded
    rows. The entrypoint runs seeds under `set -e` before phx.server, so a seed
    failure means no server. Ran locally end-to-end (exit 0, clean teardown).

### 2. Admin Console Mounted at /admin/rindle
expected: /admin/rindle loads the Rindle Admin Console; the assets and upload-sessions sub-pages are reachable.
result: pass
evidence: |
  test/adoption_demo_web/admin_mount_test.exs — asserts every top-level admin
  surface (/admin/rindle, /assets, /upload-sessions, /variants-jobs,
  /runtime-doctor, /actions) returns 200 and renders the admin shell, plus a
  router drift guard that fails if any surface is unmounted. Runs in the
  merge-blocking `Adoption Demo Unit` CI lane. 2/2 cases pass.

### 3. README Admin Walkthrough Accuracy
expected: The README "Admin Console Walkthrough" matches the running demo — URL, seed command, and click-around items.
result: pass
evidence: |
  test/readme_walkthrough_test.exs — docs-parity gate asserting the README
  documents /admin/rindle, the `mix run priv/repo/seeds.exs` seed command, and
  the click-around items (Assets, Audio, Document, Upload Sessions, quarantined,
  degraded), AND that the documented /admin/rindle URL actually resolves to the
  admin shell. Merge-blocking `Adoption Demo Unit` lane. 2/2 cases pass.

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none]

## Notes

This phase's UAT was converted to automated integration/e2e tests so it requires
**0 human verification** going forward (shift-left). The two checkpoints previously
verified by hand in 91-HUMAN-UAT.md are now also automated:

- "Logo Rendering" → test/adoption_demo_web/brand_test.exs (mortarboard mark, not
  Phoenix firebird; "Cohort · Rindle demo" wordmark + page-title default; locks in
  the tab-title fix the HUMAN-UAT flagged as cosmetic).
- "Admin Lifecycle Display" → test/adoption_demo_web/admin_lifecycle_display_test.exs
  (quarantined/degraded assets + failed/expired sessions render with no error state)
  and the strengthened e2e/admin-console.spec.js lifecycle-render assertion
  (full-stack, in the `Adoption Demo E2E` lane).

All new gates are merge-blocking (see RUNNING.md CI lane matrix and
scripts/setup_branch_protection.sh): `Adoption Demo Unit`, `Adoption Demo E2E`,
`Cohort Demo Smoke`.
