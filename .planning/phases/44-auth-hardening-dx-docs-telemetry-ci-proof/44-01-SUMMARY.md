---
phase: 44-auth-hardening-dx-docs-telemetry-ci-proof
plan: 01
subsystem: auth
tags: [tus, webhook, error-contract, resume-authorizer, polish-02]
requires: []
provides:
  - "Webhook fallback body reads capped to 1 MiB with oversized partials rejected"
  - "Tus session-not-found guidance split correctly between tus-js-client and modern @uppy/tus"
  - "Explicit POLISH-02 audit covering WR-01..06 and IN-01..07"
affects:
  - phase: 44-auth-hardening-dx-docs-telemetry-ci-proof
    plan: 03
    note: "Guide and generated-app parity now depend on the corrected client guidance."
tech-stack:
  added: []
  patterns:
    - "Trust-boundary fallback paths use the same size ceilings as primary paths"
    - "Public fix copy distinguishes client-specific resume behavior instead of widening error atoms"
key-files:
  created:
    - .planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-POLISH-02-AUDIT.md
  modified:
    - lib/rindle/delivery/webhook_plug.ex
    - test/rindle/delivery/webhook_plug_test.exs
    - lib/rindle/error.ex
    - test/rindle/error_test.exs
patterns-established:
  - "Phase audit artifacts enumerate every prior review finding explicitly rather than collapsing them into blanket closure statements"
requirements-completed: [TUS-10, TUS-11, POLISH-02]
completed: 2026-05-24
---

# Phase 44 Plan 01 Summary

**The auth and trust-boundary contract is now explicit: webhook fallback reads cannot exceed the 1 MiB ceiling, tus repair copy is client-version-correct, and the full Phase 35 advisory set is dispositioned in a durable POLISH-02 audit.**

## Accomplishments

- Capped the fallback webhook body read at `1_048_576` bytes and reject `{:more, ...}` so the misconfigured-path behavior matches the documented ceiling.
- Updated the `:tus_session_not_found` repair text to keep `removeFingerprintOnSuccess: true` specific to `tus-js-client` and state that modern `@uppy/tus` resumes and cleans up automatically.
- Wrote the explicit POLISH-02 audit artifact covering WR-01..WR-06 and IN-01..IN-07 with per-item rationale and file references.

## Verification

- `mix test test/rindle/delivery/webhook_plug_test.exs --trace`
- `mix test test/rindle/error_test.exs test/rindle/upload/tus_plug_test.exs --trace`
- `rg -n "^## WR-0[1-6]|^## IN-0[1-7]" .planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-POLISH-02-AUDIT.md`

## Deviations From Plan

- No new resume-authorizer test edits were required in this run because the existing Phase 44 tus tests already covered the locked auth and token-failure contract.
