---
status: complete
phase: 10-publish-readiness
source:
  - 10-VERIFICATION.md
  - 10-HUMAN-UAT.md
started: 2026-04-28T19:54:10Z
updated: 2026-04-28T20:05:32Z
---

## Current Test

[testing complete]

## Tests

### 1. Trigger the GitHub Actions release job from a tag or workflow_dispatch run
expected: The `Run release preflight` step completes with the provisioned Postgres/MinIO services, then the dry-run publish step remains non-live.
result: pass

### 2. Inspect generated HexDocs navigation for the maintainer guide
expected: `Release Publishing` appears in generated docs as a maintainer-facing guide and adopter-facing docs still omit Hex owner/auth instructions.
result: pass

## Summary

total: 2
passed: 2
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

## Notes

Manual UAT was replaced by executable automation on 2026-04-28:
- `.github/workflows/ci.yml` now runs `bash scripts/release_preflight.sh` in the service-backed package-consumer lane before merge.
- `scripts/assert_release_docs_html.sh` now verifies generated HexDocs navigation and the generated adopter-doc boundary after `mix docs`.
