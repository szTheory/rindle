---
phase: 87
slug: docker-demo-dx
status: approved
nyquist_compliant: true
wave_0_complete: true
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
| 87-01-01 | 01 | 1 | DX-01 | T-87-01, T-87-02, T-87-04 | Published app and MinIO ports bind to loopback, derive from env defaults, namespace by `COMPOSE_PROJECT_NAME`, and keep browser-facing MinIO on the selected host API port | static integration | Plan 87-01 Task 1 renders `docker compose -f docker/compose.cohort-demo.yml config` with `COHORT_DEMO_PORT=4212`, `COHORT_MINIO_PORT=9200`, `COHORT_MINIO_CONSOLE_PORT=9201`, and `COMPOSE_PROJECT_NAME=rindle-cohort-check`, then asserts project name, loopback host bindings, published/target ports, project-scoped volume names, and `RINDLE_MINIO_URL` | yes | covered |
| 87-01-02 | 01 | 1 | DX-03 | T-87-03 | Launch URL map is generated from the same env defaults used by Compose without starting Docker in the deterministic check | shell output | Plan 87-01 Task 2 runs `bash -n`, `shellcheck`, and `COHORT_DEMO_PORT=4212 COHORT_MINIO_CONSOLE_PORT=9201 scripts/demo/up.sh --print-urls` with exact assertions for `app`, `admin console`, `MinIO console`, and their URLs | yes | covered |
| 87-02-01 | 02 | 1 | DX-02 | T-87-05 | Dependency manifests are copied before source, and `mix deps.get` runs before full repo copy | static Dockerfile | Plan 87-02 Task 1 uses `awk` line-order assertions on `docker/Dockerfile.cohort-demo` for root/demo manifest copies, `mix deps.get`, `COPY . /app`, `mix assets.vendor`, and `mix compile` | yes | covered |
| 87-02-02 | 02 | 1 | DX-02 | T-87-06 | Docker preview remains a simple preview image and does not expand into release-build, split-image, Traefik, reverse-proxy, or production topology | static Dockerfile and shell lint | Plan 87-02 Task 2 asserts `EXPOSE 4102`, `ENTRYPOINT ["/entrypoint.sh"]`, rejects out-of-scope topology terms with `rg`, and runs `bash -n` plus `shellcheck` on `docker/cohort-demo-entrypoint.sh` | yes | covered |
| 87-03-01 | 03 | 2 | DX-01, DX-02, DX-03 | T-87-07, T-87-08, T-87-10 | README quick-try docs describe preview-only launch output, env override controls, cache expectations, and conflict recovery without process killing or public MinIO guidance | docs/static | Plan 87-03 Task 1 uses `rg` assertions for preview framing, `./scripts/demo/up.sh`, URL labels, override env vars, and forbidden wording in `examples/adoption_demo/README.md` | yes | covered |
| 87-03-02 | 03 | 2 | DX-01, DX-02, DX-03 | T-87-07, T-87-09 | Proof matrix remains honest and drift-checked after compose/script/Dockerfile/docs changes | docs/static | Plan 87-03 Task 2 uses `rg` assertions for compose/script/env contract, rejects production/public/release-build claims, and runs `scripts/maintainer/check_adoption_proof_matrix.sh` | yes | covered |

## Wave 0 Requirements

- [x] Deterministic wrapper URL-output check is covered by Plan 87-01 Task 2 through `scripts/demo/up.sh --print-urls` plus exact label/URL assertions.
- [x] Dockerfile line-order proof is covered by Plan 87-02 Task 1 through source-order assertions around dependency manifests, `mix deps.get`, full source copy, asset vendoring, and compile.
- [x] Docs/proof drift checks are covered by Plan 87-03 Tasks 1 and 2 through `rg` assertions and `scripts/maintainer/check_adoption_proof_matrix.sh`.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full Docker preview startup | DX-01, DX-02, DX-03 | Startup cost and local Docker state can exceed the static planning gate's risk budget | Run `COMPOSE_PROJECT_NAME=rindle-cohort-check COHORT_DEMO_PORT=4212 COHORT_MINIO_PORT=9200 COHORT_MINIO_CONSOLE_PORT=9201 ./scripts/demo/up.sh`, confirm the printed URL map, then clean up with matching `COMPOSE_PROJECT_NAME ./scripts/demo/down.sh` |

## Validation Sign-Off

- [x] All tasks have automated verification; no task now depends on an unresolved Wave 0 scaffold.
- [x] Sampling continuity: no 3 consecutive tasks without automated verification.
- [x] Wave 0 deterministic checks are closed by Plan 87-01 Task 2, Plan 87-02 Task 1, and Plan 87-03 Tasks 1-2.
- [x] No watch-mode flags are used in verification commands.
- [x] Feedback latency is under 90 seconds for static gates.
- [x] `nyquist_compliant: true` and `wave_0_complete: true` are consistent with the concrete plan checks.

**Approval:** approved 2026-06-11 for static-first Phase 87 execution gates. Full Docker startup remains optional/manual after the deterministic gates pass.
