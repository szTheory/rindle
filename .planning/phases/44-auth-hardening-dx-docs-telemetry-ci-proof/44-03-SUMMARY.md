---
phase: 44-auth-hardening-dx-docs-telemetry-ci-proof
plan: 03
subsystem: docs
tags: [tus, docs, generated-app, ci, minio]
requires:
  - phase: 44-auth-hardening-dx-docs-telemetry-ci-proof
    plan: 01
    provides: "client-version-correct tus recovery guidance"
provides:
  - "Canonical tus guide with parser/CORS/no-silent-downgrade/bearer-credential language"
  - "Generated-app tus proof parity assertions against the guide"
  - "Merge-blocking CI tus package-consumer lane preserved"
affects: []
tech-stack:
  added: []
  patterns:
    - "Published setup guides are parity-checked by executable package-consumer tests"
key-files:
  created: []
  modified:
    - guides/resumable_uploads.md
    - test/install_smoke/generated_app_smoke_test.exs
    - test/install_smoke/support/generated_app_helper.ex
    - .github/workflows/ci.yml
patterns-established:
  - "Docs and generated-app smoke tests lock the same operational strings to prevent drift"
requirements-completed: [TUS-14]
completed: 2026-05-24
---

# Phase 44 Plan 03 Summary

**The tus adopter guide is now version-correct and executable as contract: it documents the exact parser/CORS/security posture, distinguishes `tus-js-client` from modern `@uppy/tus`, and the generated-app smoke lane asserts that parity directly.**

## Accomplishments

- Rewrote the guide so `removeFingerprintOnSuccess: true` appears only in the `tus-js-client` path and modern `@uppy/tus` is documented as automatic for resume and cleanup.
- Preserved the real MinIO-backed tus package-consumer proof, including the pinned `tus-js-client@4.3.1`, interrupted upload, resume, and downstream asset assertions.
- Added smoke-test parity assertions that read `guides/resumable_uploads.md` and lock the required parser, CORS, no-silent-downgrade, bearer-token, client-split, and sticky-session language.

## Verification

- `mix test test/install_smoke/generated_app_smoke_test.exs --trace`
- `rg -n "Plug\\.Parsers|application/offset\\+octet-stream|Upload-Offset|Location|Upload-Length|Tus-Resumable|Upload-Expires|no-silent-downgrade|bearer credential|sticky-session|single-node|@uppy/tus|tus-js-client" guides/resumable_uploads.md`
- `rg -n "guides/resumable_uploads\\.md|Plug\\.Parsers|application/offset\\+octet-stream|Upload-Offset|Location|Upload-Length|Tus-Resumable|Upload-Expires|no-silent-downgrade|bearer credential|sticky-session|single-node" test/install_smoke/generated_app_smoke_test.exs`
