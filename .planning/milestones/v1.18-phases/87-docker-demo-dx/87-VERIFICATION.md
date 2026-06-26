---
phase: 87-docker-demo-dx
verified: 2026-06-11T18:29:21Z
status: passed
score: 14/14
requirements_verified:
  - DX-01
  - DX-02
  - DX-03
overrides_applied: 0
human_verification: []
gaps: []
---

# Phase 87: Docker & Demo DX Verification Report

**Phase Goal:** Make the Cohort Docker demo stack port-conflict resistant, cache-friendly,
self-reporting at launch, and accurately documented for later v1.18 UI iteration.
**Verified:** 2026-06-11T18:29:21Z
**Status:** passed
**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | `COMPOSE_PROJECT_NAME` overrides the default Compose project name for sibling-stack namespacing. | VERIFIED | Rendered config with `COMPOSE_PROJECT_NAME=rindle-cohort-check` produced `name: rindle-cohort-check` and project-scoped resource names. |
| 2 | Cohort app host port is env-driven, loopback-bound, and keeps container port 4102. | VERIFIED | `docker/compose.cohort-demo.yml` publishes `127.0.0.1:${COHORT_DEMO_PORT:-4102}:4102`; rendered config showed published `4212` and target `4102`. |
| 3 | MinIO API host port is env-driven, loopback-bound, and keeps container port 9000. | VERIFIED | Compose publishes `127.0.0.1:${COHORT_MINIO_PORT:-9000}:9000`; rendered config showed published `9200` and target `9000`. |
| 4 | MinIO console host port is env-driven, loopback-bound, and keeps container port 9001. | VERIFIED | Compose publishes `127.0.0.1:${COHORT_MINIO_CONSOLE_PORT:-9001}:9001`; rendered config showed published `9201` and target `9001`. |
| 5 | Browser-facing MinIO URL uses the selected host MinIO API port while service setup stays on internal MinIO. | VERIFIED | Rendered config set `RINDLE_MINIO_URL: http://host.docker.internal:9200`; `minio-init` still uses `mc alias set local http://minio:9000`. A container reachability check confirmed `host.docker.internal` can reach a host loopback-bound port in this Docker setup. |
| 6 | `scripts/demo/up.sh` remains the primary copy-paste Docker preview entry point. | VERIFIED | README and proof matrix point users to `./scripts/demo/up.sh`; normal wrapper execution still ends in `docker compose -f "${repo_root}/docker/compose.cohort-demo.yml" up --build "$@"`. |
| 7 | Launch output prints exact labels and env-derived URLs for app, admin console, and MinIO console. | VERIFIED | `COHORT_DEMO_PORT=4212 COHORT_MINIO_CONSOLE_PORT=9201 scripts/demo/up.sh --print-urls` printed `app`, `admin console`, `MinIO console`, and the expected URLs. |
| 8 | Dockerfile copies dependency manifests and runs `mix deps.get` before full source copy. | VERIFIED | Source-order assertion proved root/demo Mix manifest copies precede `mix deps.get`, and `mix deps.get` precedes `COPY . /app`. |
| 9 | Dockerfile runs asset vendoring and compile after full source copy. | VERIFIED | Source-order assertion proved `COPY . /app` precedes `mix assets.vendor` and `mix compile`. |
| 10 | Docker preview remains a simple preview image, not a topology redesign. | VERIFIED | `EXPOSE 4102` and `ENTRYPOINT ["/entrypoint.sh"]` remain; forbidden release/split-image/reverse-proxy/topology terms are absent from the Dockerfile. |
| 11 | Docker quick-try docs describe preview-only launch output and env overrides. | VERIFIED | README includes `Preview only`, `./scripts/demo/up.sh`, the three URL labels, `COHORT_DEMO_PORT`, `COHORT_MINIO_PORT`, `COHORT_MINIO_CONSOLE_PORT`, and `COMPOSE_PROJECT_NAME`. |
| 12 | Port-conflict guidance is command-first and avoids process-killing or compose-file editing. | VERIFIED | README forbidden wording check passed for process-killing, `lsof`, compose-file editing, public MinIO, and production-deployment guidance. |
| 13 | Proof matrix describes the optional local Docker preview truthfully and remains drift-checked. | VERIFIED | Proof matrix references Compose, `scripts/demo/up.sh`, env-driven loopback ports, `COMPOSE_PROJECT_NAME`, `MinIO console`, and `check_adoption_proof_matrix.sh`; drift script passed. |
| 14 | Phase 87 does not claim admin console implementation or full Docker startup as mandatory proof. | VERIFIED | Docs describe the admin URL as launch output only and keep the local Docker preview optional/not CI-blocking; static gates are the required autonomous proof path. |

**Score:** 14/14 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `docker/compose.cohort-demo.yml` | Env-driven loopback host bindings, stable internal ports, browser-facing MinIO URL | VERIFIED | Rendered Compose config with override env passed all assertions. |
| `scripts/demo/up.sh` | Primary launch wrapper with deterministic URL map and `--print-urls` | VERIFIED | Shell syntax, shellcheck, exact label/URL output, and passthrough contract verified. |
| `docker/Dockerfile.cohort-demo` | Dependency-cache-friendly ordering without preview topology expansion | VERIFIED | Source-order and preview-boundary checks passed. |
| `examples/adoption_demo/README.md` | Docker quick-try docs and conflict-recovery guidance | VERIFIED | Required labels/env vars present; forbidden guidance absent. |
| `examples/adoption_demo/docs/adoption-proof-matrix.md` | Honest optional local preview proof row and drift-check references | VERIFIED | Required references present; drift script passed. |
| `.planning/phases/87-docker-demo-dx/87-REVIEW.md` | Required phase code review artifact | VERIFIED | Status `clean`, 0 findings. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `scripts/demo/up.sh` | `docker/compose.cohort-demo.yml` | Shared `COHORT_DEMO_PORT`, `COHORT_MINIO_PORT`, and `COHORT_MINIO_CONSOLE_PORT` defaults | VERIFIED | Wrapper exports the same vars Compose interpolates. |
| `docker/compose.cohort-demo.yml` | `examples/adoption_demo/config/runtime.exs` | `RINDLE_MINIO_URL` env consumed by runtime config | VERIFIED | Runtime config reads `RINDLE_MINIO_URL`; rendered Compose config supplies the selected host API port. |
| `examples/adoption_demo/README.md` | `scripts/demo/up.sh` | Documented launch command and URL map labels | VERIFIED | README names `./scripts/demo/up.sh`, `app`, `admin console`, and `MinIO console`. |
| `examples/adoption_demo/docs/adoption-proof-matrix.md` | `scripts/maintainer/check_adoption_proof_matrix.sh` | Proof matrix drift gate | VERIFIED | Matrix references the script and the script exited 0. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Shell syntax | `bash -n scripts/demo/up.sh scripts/demo/down.sh scripts/demo/reset.sh docker/cohort-demo-entrypoint.sh` | Exited 0 | PASS |
| Shell lint | `shellcheck scripts/demo/up.sh scripts/demo/down.sh scripts/demo/reset.sh docker/cohort-demo-entrypoint.sh` | Exited 0 | PASS |
| Compose render | `COHORT_DEMO_PORT=4212 COHORT_MINIO_PORT=9200 COHORT_MINIO_CONSOLE_PORT=9201 COMPOSE_PROJECT_NAME=rindle-cohort-check docker compose -f docker/compose.cohort-demo.yml config` | Rendered expected project name, loopback bindings, published ports, and MinIO URL | PASS |
| Launch URL output | `COHORT_DEMO_PORT=4212 COHORT_MINIO_CONSOLE_PORT=9201 scripts/demo/up.sh --print-urls` | Printed exact labels and URLs | PASS |
| Dockerfile ordering | `awk` source-order assertion from `87-02-PLAN.md` | Dependency fetch before source copy; build steps after source copy | PASS |
| Proof matrix drift | `scripts/maintainer/check_adoption_proof_matrix.sh` | `check_adoption_proof_matrix: OK` | PASS |
| Prior phase regression | `mix test test/rindle/api_surface_boundary_test.exs` | 17 tests, 0 failures | PASS |
| Schema drift | `gsd-sdk query verify.schema-drift 87` | `drift_detected: false` | PASS |
| Codebase drift | `gsd-sdk query verify.codebase-drift` | Skipped: `no-structure-md`, non-blocking | PASS |
| Code review | `.planning/phases/87-docker-demo-dx/87-REVIEW.md` | Status `clean`, 0 findings | PASS |
| Container host-loopback reachability | Host `nc` bound to `127.0.0.1:19287`; container `curl http://host.docker.internal:19287` | Returned `ok` | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| DX-01 | `87-01-PLAN.md`, `87-03-PLAN.md` | Compose stack is port-conflict-free alongside sibling projects through project namespacing, env-driven ports, sane defaults, and conflict guidance. | SATISFIED | Compose render proves env-driven loopback ports and `COMPOSE_PROJECT_NAME`; README documents env override conflict recovery. |
| DX-02 | `87-02-PLAN.md`, `87-03-PLAN.md` | Dockerfile layer caching fixed and dev iteration supports style/template changes without rebuilding deps. | SATISFIED | Dockerfile source-order proof passed; README documents cache expectation. |
| DX-03 | `87-01-PLAN.md`, `87-03-PLAN.md` | Launch prints a copy-pasteable URL map for app, admin console, and MinIO console. | SATISFIED | `scripts/demo/up.sh --print-urls` exact-output check passed; docs describe the same labels. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| None | - | - | - | No blocking anti-patterns found. |

### Human Verification Required

None. Full Docker preview startup remains an optional manual smoke per `87-VALIDATION.md`;
all required Phase 87 gates are programmatically verified.

### Gaps Summary

No gaps found. Phase 87 satisfies DX-01, DX-02, and DX-03 through implemented Compose,
shell, Dockerfile, documentation, review, and static verification artifacts.

---

_Verified: 2026-06-11T18:29:21Z_
_Verifier: inline Codex execution of the gsd-verifier contract_
