---
status: partial
phase: 10-publish-readiness
source:
  - 10-VERIFICATION.md
started: 2026-04-28T19:46:31Z
updated: 2026-04-28T19:46:31Z
---

## Current Test

awaiting human testing

## Tests

### 1. Trigger the GitHub Actions release job from a tag or workflow_dispatch run
expected: The `Run release preflight` step completes with the provisioned Postgres/MinIO services, then the dry-run publish step remains non-live.
result: pending

### 2. Inspect generated HexDocs navigation for the maintainer guide
expected: `Release Publishing` appears in generated docs as a maintainer-facing guide and adopter-facing docs still omit Hex owner/auth instructions.
result: pending

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
