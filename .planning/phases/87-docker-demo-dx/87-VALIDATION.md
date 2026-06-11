---
phase: 87
slug: docker-demo-dx
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-11
---

# Phase 87 - Validation Strategy

Per-phase validation contract for Docker demo DX execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | Static shell checks, Docker Compose render checks, docs drift checks, targeted source assertions |
| Config file | `docker/compose.cohort-demo.yml`, `mix.exs`, `examples/adoption_demo/mix.exs`, `examples/adoption_demo/playwright.config.js` |
| Quick run command | `bash -n scripts/demo/up.sh scripts/demo/down.sh scripts/demo/reset.sh docker/cohort-demo-entrypoint.sh && shellcheck scripts/demo/up.sh scripts/demo/down.sh scripts/demo/reset.sh docker/cohort-demo-entrypoint.sh && COHORT_DEMO_PORT=4212 COHORT_MINIO_PORT=9200 COHORT_MINIO_CONSOLE_PORT=9201 COMPOSE_PROJECT_NAME=rindle-cohort-check docker compose -f docker/compose.cohort-demo.yml config >/tmp/rindle-compose-config.yml` |
| Full suite command | `mix test` from repo root if Elixir runtime behavior changes beyond env wiring; otherwise static Phase 87 gates are sufficient |
| Estimated runtime | ~20-90 seconds for static gates; full Docker startup is optional and environment-dependent |

## Sampling Rate

- **After every task commit:** Run the quick shell and Compose render command above.
- **After every plan wave:** Run `scripts/maintainer/check_adoption_proof_matrix.sh` plus rendered compose assertions for loopback-bound env ports.
- **Before `$gsd-verify-work`:** Static gates must be green; run optional full Docker startup only if execution risk warrants it.
- **Max feedback latency:** 90 seconds for static gates.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 87-01-01 | 01 | 1 | DX-01 | T-87-01 | Published app and MinIO ports bind to loopback and derive from env defaults | static integration | `COHORT_DEMO_PORT=4212 COHORT_MINIO_PORT=9200 COHORT_MINIO_CONSOLE_PORT=9201 COMPOSE_PROJECT_NAME=rindle-cohort-check docker compose -f docker/compose.cohort-demo.yml config` with assertions on rendered ports and project-scoped names | yes | pending |
| 87-01-02 | 01 | 1 | DX-01 | T-87-02 | Port override guidance avoids process killing and avoids public MinIO exposure | docs/static | `rg -F 'COHORT_DEMO_PORT' examples/adoption_demo/README.md examples/adoption_demo/docs/adoption-proof-matrix.md && scripts/maintainer/check_adoption_proof_matrix.sh` | yes | pending |
| 87-02-01 | 02 | 1 | DX-02 | - | Dependency manifests are copied before source, and `mix deps.get` runs before full repo copy | static Dockerfile | `awk` or equivalent source assertion on `docker/Dockerfile.cohort-demo` line ordering | yes | pending |
| 87-02-02 | 02 | 1 | DX-02 | - | Routine source, style, and template edits do not re-fetch Hex dependencies | optional Docker smoke | Build once, touch a non-dependency source/template file, rebuild, and inspect output for cached dependency layer if practical | yes | pending |
| 87-03-01 | 03 | 1 | DX-03 | T-87-03 | Launch URL map is generated from the same env defaults used by Compose | shell output | Prefer a no-start print/helper test for `app`, `admin console`, and `MinIO console` labels and env-derived URLs | partial | pending |

## Wave 0 Requirements

- [ ] Add a deterministic wrapper URL-output check if `scripts/demo/up.sh` remains an immediate `exec docker compose ... up --build`.
- [ ] Add a Dockerfile line-order assertion if the plan needs automated proof for DX-02 beyond code review.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full Docker preview startup | DX-01, DX-02, DX-03 | Startup cost and local Docker state can exceed the static planning gate's risk budget | Run `COMPOSE_PROJECT_NAME=rindle-cohort-check COHORT_DEMO_PORT=4212 COHORT_MINIO_PORT=9200 COHORT_MINIO_CONSOLE_PORT=9201 ./scripts/demo/up.sh`, confirm the printed URL map, then clean up with matching `COMPOSE_PROJECT_NAME ./scripts/demo/down.sh` |

## Validation Sign-Off

- [ ] All tasks have automated verification or an explicit Wave 0 dependency.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing deterministic checks.
- [ ] No watch-mode flags are used in verification commands.
- [ ] Feedback latency is under 90 seconds for static gates.
- [ ] Set `nyquist_compliant: true` after plans assign concrete task IDs and validation coverage is complete.

**Approval:** pending
