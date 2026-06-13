---
status: complete
phase: 91-cohort-demo-evolution
source: [91-VERIFICATION.md]
started: 2026-06-12T21:50:18Z
updated: 2026-06-13T00:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Logo Rendering
expected: A distinct new logo (not the Phoenix firebird) renders correctly in the top left header, and text says 'Cohort · Rindle demo'.
result: pass
evidence: |
  Served /images/logo.svg is a custom green mortarboard mark (fill #059669/#047857/#10B981),
  not the Phoenix firebird (no "phoenix"/"firebird" tokens in the SVG). In-page header text
  renders "Cohort · Rindle demo". Verified at http://localhost:4102 (HTTP 200).
note: |
  Cosmetic-only: the browser TAB <title> still uses the default Phoenix suffix
  ("Cohort · Phoenix Framework"). The in-page top-left header is correct. Non-blocking.

### 2. Admin Console Lifecycle Display
expected: Edge cases like `quarantined`, `degraded` assets, and failed upload sessions display gracefully in the admin UI without causing 500 errors.
result: pass
evidence: |
  /admin/rindle, /admin/rindle/assets, /admin/rindle/upload-sessions all return HTTP 200 (no 500s).
  Assets list renders lifecycle states: quarantined (3), degraded (2), processing (4), ready (15).
  Upload sessions render: failed (1), expired (1), aborted (1), completed (5).

## Summary

total: 2
passed: 2
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none]

## Notes

The demo was unreachable at verification time due to a cross-phase break, fixed during this run:
- Multi-project port contention (a native MinIO held :9000) blocked the bundled MinIO; `scripts/demo/up.sh`
  now auto-picks free loopback ports, so the stack comes up cleanly.
- Phase-93's `allow_unauthenticated?: true` prod guard caused the prod-built demo image to fail to compile.
  Resolved by building the demo as a dev/preview env (the library sanctions `allow_unauthenticated?` for
  local previews; the prod guard is left fully intact). See docker/Dockerfile.cohort-demo and the demo router.
- Stale Elixir pin (1.17.3) vs dev toolchain (1.19/OTP28); image bumped to match.
