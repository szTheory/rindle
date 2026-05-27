# Phase 75: Merge-Blocking Proof Lanes - Patterns

## CI job template

Copy **`contract`** job skeleton for Postgres + Elixir 1.17/27 single-version jobs:

- `needs: quality`
- `services.postgres` block (lines ~246–259 in `ci.yml`)
- Cache keys: `deps-${{ runner.os }}-1.17-27-...`
- **Omit:** MinIO, libvips, FFmpeg (proof tests do not need them)

## Phase 71 policy (preserve)

- `quality` step-level `continue-on-error` for credo, doctor, coveralls, dialyzer — **unchanged**
- New blocking surface = **job-level** `proof`, not advisory steps inside `quality`

## Docs parity extension pattern

From Phase 71 (`71-01-PLAN.md`): extend `test "running guide publishes the CI lane severity matrix"`
or add sibling test with token asserts for new job name — do not assert full prose paragraphs.

## Comment style

Match Phase 71 inline comments: `# Phase 75 (CI-03): ... See RUNNING.md ## CI lane severity`
