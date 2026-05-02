---
status: complete
phase: 21-verify-02-hexdocs-reachability-probe
source:
  - .planning/phases/21-verify-02-hexdocs-reachability-probe/21-01-SUMMARY.md
started: 2026-05-02T01:30:51Z
updated: 2026-05-02T01:36:46Z
---

## Current Test

[testing complete]

## Tests

### 1. Release Workflow HexDocs Probe
expected: In `.github/workflows/release.yml`, the `public_verify` job includes a `Verify HexDocs reachability` step between the Hex.pm index wait and the public package smoke step. The probe follows redirects against `https://hexdocs.pm/rindle/$VERSION`, retries on a 15-second interval for up to 5 minutes, and fails with clear terminal messaging if the docs never become reachable.
result: pass

### 2. Release Runbook Parity
expected: In `guides/release_publish.md`, the routine release sequence and workflow contract explicitly include the `Verify HexDocs reachability` step with the same ordering and retry expectations as the shipped workflow.
result: pass

### 3. Install-Smoke Contract Coverage
expected: The install-smoke suite fails if the HexDocs probe step name, literal versioned URL, placement in `public_verify`, or bounded retry semantics drift from the documented release contract.
result: pass

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
