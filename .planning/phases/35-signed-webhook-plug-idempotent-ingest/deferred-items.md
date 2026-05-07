# Phase 35 — Deferred Items

Out-of-scope discoveries surfaced during execution but not addressed.

## From Plan 35-03 execution (2026-05-07)

### Pre-existing `mix format --check-formatted` violations

`mix format --check-formatted` reports unrelated formatting drift in
production source files that were NOT touched by Plan 35-03:

- `lib/rindle/ops/lifecycle_repair.ex`
- `lib/rindle/processor/av/video.ex`
- (and likely more — exit 1 across the run)

These are pre-existing on `main` (commit 1768567 base) and were not
introduced by Plan 35-03. Per execute-plan scope boundary, leaving these
to a future cleanup pass (`mix format` repo-wide) or v1.7 polish.

Plan 35-03's own added/modified files (`test/support/mux_webhook_fixtures.ex`,
`test/rindle/test/mux_webhook_fixtures_test.exs`,
`test/rindle/streaming/provider/mux/mux_test.exs`, and the 5 fixture JSONs)
all pass `mix format --check-formatted` cleanly.
