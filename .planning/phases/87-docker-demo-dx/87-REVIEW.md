---
phase: 87-docker-demo-dx
status: clean
reviewer: inline-codex
depth: standard
files_reviewed: 5
findings:
  critical: 0
  warning: 0
  info: 0
  total: 0
created: 2026-06-11
---

# Phase 87 Code Review

## Scope

Reviewed the source and documentation files changed by Phase 87:

- `docker/compose.cohort-demo.yml`
- `docker/Dockerfile.cohort-demo`
- `scripts/demo/up.sh`
- `examples/adoption_demo/README.md`
- `examples/adoption_demo/docs/adoption-proof-matrix.md`

The normal `gsd-code-reviewer` delegation path was not used because this Codex session only allows subagents when the user explicitly requests delegation. The review was performed inline and this artifact follows the expected REVIEW.md contract.

## Findings

No issues found.

## Review Notes

- Compose interpolation renders the expected project name, loopback host bindings, published ports, target ports, project-scoped volumes, and browser-facing `RINDLE_MINIO_URL`.
- `scripts/demo/up.sh` uses quoted defaults, exports the same env vars Compose consumes, preserves argument passthrough, and exits before Docker when `--print-urls` is the first argument.
- Dockerfile ordering places Mix dependency manifests and `mix deps.get` before the full source copy, while keeping asset vendoring, compile, `EXPOSE 4102`, and the entrypoint after source copy.
- README and proof matrix wording stays preview-only, avoids process-killing and compose-file-edit guidance, and keeps local Docker preview optional/not CI-blocking.
- The `RINDLE_MINIO_URL` endpoint is shared by presigned URL generation and server-side ExAws requests. A container reachability check confirmed that, in the local Docker setup, `host.docker.internal` can reach a host port bound on `127.0.0.1`, matching the Phase 87 loopback contract.

## Verification Evidence

- `bash -n scripts/demo/up.sh scripts/demo/down.sh scripts/demo/reset.sh docker/cohort-demo-entrypoint.sh`
- `shellcheck scripts/demo/up.sh scripts/demo/down.sh scripts/demo/reset.sh docker/cohort-demo-entrypoint.sh`
- Rendered `docker compose -f docker/compose.cohort-demo.yml config` with Phase 87 override ports and `COMPOSE_PROJECT_NAME=rindle-cohort-check`
- Dockerfile source-order assertions for dependency manifests, `mix deps.get`, full source copy, asset vendoring, and compile
- `scripts/maintainer/check_adoption_proof_matrix.sh`
- Container-to-host loopback reachability check using `adoption_demo-web:latest` and `host.docker.internal`
