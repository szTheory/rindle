---
phase: 44-auth-hardening-dx-docs-telemetry-ci-proof
plan: 02
subsystem: observability
tags: [tus, telemetry, doctor, runtime-checks]
requires: []
provides:
  - "Tus resumable telemetry stays in the public resumable namespace with protocol tagging"
  - "Doctor exposes config-driven tus capability drift through doctor.tus_capability"
affects: []
tech-stack:
  added: []
  patterns:
    - "Capability drift stays config-driven through :tus_profiles instead of route introspection"
key-files:
  created: []
  modified:
    - lib/rindle/upload/resumable_telemetry.ex
    - test/rindle/contracts/telemetry_contract_test.exs
    - lib/rindle/ops/runtime_checks.ex
    - test/rindle/ops/runtime_checks_test.exs
patterns-established:
  - "Tus observability extends existing resumable public contracts rather than creating parallel namespaces"
requirements-completed: [TUS-12, TUS-13]
completed: 2026-05-24
---

# Phase 44 Plan 02 Summary

**Tus now proves itself through the existing public resumable telemetry family and the stable doctor drift surface, without inventing new public namespaces or magical router inspection.**

## Accomplishments

- Added explicit resumable `:start`, `:patch`, and `:stop` helper coverage with `protocol: :tus` and forbidden-metadata assertions.
- Kept the public allowlist low-cardinality and verified that forbidden keys like `session_uri`, `upload_key`, `headers`, and `body` never leak through telemetry.
- Locked the `doctor.tus_capability` report id and fix wording around `config :rindle, :tus_profiles, [...]` for both passing and failing profiles.

## Verification

- `mix test test/rindle/contracts/telemetry_contract_test.exs --include contract --trace`
- `mix test test/rindle/ops/runtime_checks_test.exs --trace`
