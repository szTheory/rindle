---
phase: 104-cache-tooling-hygiene
plan: 01
subsystem: ci-cd
status: complete
tags: [ci, github-actions, composite-action, cache, tooling, dx]
requires: []
provides:
  - "setup-elixir composite action (uses: ./.github/actions/setup-elixir)"
  - "setup-minio composite action (uses: ./.github/actions/setup-minio)"
  - ".tool-versions repo-root local-dev toolchain pins"
affects:
  - "Phase 104 adoption plans (Wave 2-4) that migrate ci.yml/release.yml jobs onto these composites"
tech-stack:
  added: []
  patterns:
    - "GitHub composite action (runs.using: composite) as DRY setup source of truth (CACHE-01)"
    - "Resolved-version cache keys via setup-beam step outputs, not coarse matrix values (CACHE-02/D-05)"
    - "cache-prefix-parameterized namespace for separate deps trees (D-06)"
key-files:
  created:
    - .github/actions/setup-elixir/action.yml
    - .github/actions/setup-minio/action.yml
    - .tool-versions
  modified: []
decisions:
  - "setup-elixir final input names: elixir-version, otp-version, mix-env, cache-prefix, install-deps (D-01)"
  - "setup-elixir outputs: deps-cache-hit, build-cache-hit (D-01) — adoption plans wire these into the OBS-01 summary"
  - "cache-prefix default literal is 'default' (yields deps/build namespace); 'no-optional' yields deps-no-optional/build-no-optional (D-06)"
  - "setup-minio input: cors-allow-origin (default empty) gates -e MINIO_API_CORS_ALLOW_ORIGIN for the adoption-demo-e2e caller (D-02)"
  - ".tool-versions patches pinned-for-confirmation (asdf list-all unavailable in sandbox), not asdf-resolved"
metrics:
  duration: 1 min
  completed: 2026-06-21
---

# Phase 104 Plan 01: Cache & Tooling Hygiene Foundation Summary

Two greenfield GitHub composite actions (`setup-elixir`, `setup-minio`) plus a repo-root `.tool-versions`, landed in isolation with zero change to any workflow file — the foundation all Wave 2-4 adoption plans `uses:`.

## What Was Built

### Task 1 — `setup-elixir` composite (CACHE-01 + CACHE-02 key schema)
`.github/actions/setup-elixir/action.yml`, `runs.using: composite`. Step order: `erlef/setup-beam@v1` (id `beam`) → compute cache namespaces → deps `actions/cache@v4` (id `deps_cache`) → `_build` `actions/cache@v4` (id `build_cache`) → guarded `mix deps.get`. No compile step (D-01).

- **Inputs (5, D-01):** `elixir-version` (required), `otp-version` (required), `mix-env` (default `test`), `cache-prefix` (default `default`), `install-deps` (default `true`). Each carries a `description`.
- **Outputs (D-01):** `deps-cache-hit` ← `steps.deps_cache.outputs.cache-hit`, `build-cache-hit` ← `steps.build_cache.outputs.cache-hit`. Adoption plans wire these into the Phase-103 OBS-01 `$GITHUB_STEP_SUMMARY` table (which currently reads `steps.deps-cache`/`steps.build-cache`).
- **CACHE-02 key (D-05):** `<ns>-v1-${runner.os}-${runner.arch}-otp${steps.beam.outputs.otp-version}-elixir${steps.beam.outputs.elixir-version}-${inputs.mix-env}-${hashFiles('mix.lock')}`; `restore-keys` truncate at the mix-env segment so fallback crosses mix.lock hashes only, never toolchains. Repo-root `hashFiles('mix.lock')`, NOT `**/mix.lock` (D-09).
- **Namespace (D-06):** a `Compute cache namespaces` bash step maps `cache-prefix=default` → `deps`/`build` and any other value → `deps-<prefix>`/`build-<prefix>` (so `no-optional` → `deps-no-optional`/`build-no-optional`). No hardcoded single namespace.
- **MIX_ENV (D-09):** `inputs.mix-env` is the explicit key segment (default `test`, never empty) and is also set as `env: MIX_ENV` on the `mix deps.get` step.

### Task 2 — `setup-minio` composite (CACHE-01 / D-02)
`.github/actions/setup-minio/action.yml`, `runs.using: composite`. Three steps copied byte-for-byte from the `integration` job trio: **Start MinIO** (`docker run -d --name rindle-minio … minio/minio server /data --console-address ":9001"` + 30-iteration `/minio/health/ready` wait loop), **Install MinIO client** (`curl … mc -o mc; chmod +x; sudo mv`), **Create MinIO bucket** (`mc alias set local …; mc mb --ignore-existing local/rindle-test`).

- **Input:** `cors-allow-origin` (default empty). When non-empty, injects `-e MINIO_API_CORS_ALLOW_ORIGIN='<value>'` into the docker run via a GitHub-expression conditional, so the `adoption-demo-e2e` caller passes `*` and the four other callers reproduce today's no-CORS behavior unchanged.
- No job env (MinIO connection vars) and no secret/label `if:` gate baked in — those stay at the caller (D-02). Bucket name `rindle-test` and `minioadmin` credentials kept inline (constant across all callers).

### Task 3 — `.tool-versions` (CACHE-05 / D-13)
Repo-root `.tool-versions` (asdf format, three lines):
```
elixir 1.17.3-otp-27
erlang 27.2
nodejs 20.18.1
```
Local-dev-only — **no** `setup-beam` `version-file:` wiring added anywhere; CI's inline `1.17`/`27` matrix stays authoritative (D-13).

**Patch resolution method: PINNED-FOR-CONFIRMATION, not asdf-resolved.** `asdf` is installed in the execution sandbox but `asdf list-all elixir|erlang|nodejs` returned empty (plugin registry/network unavailable). Per D-13's documented fallback, patches were pinned to the latest known versions (`elixir 1.17.3-otp-27`, `erlang 27.2`, `nodejs 20.18.1`). **The exact patch strings must be confirmed against the next CI run's resolved `setup-beam` output for `1.17`/`27`** and corrected if they diverge.

## Deviations from Plan

**1. [Rule 1 - Bug] setup-minio description reworded to avoid tripping the D-02 grep guard**
- **Found during:** Task 2 verification.
- **Issue:** The task's automated check asserts `grep -c 'RINDLE_MINIO_' == 0` (guards against baking job env into the composite). The composite bakes none, but an explanatory comment originally wrote the literal `RINDLE_MINIO_*`, which the grep counted (returned 1, verification failed).
- **Fix:** Reworded the comment to "MinIO connection env" — semantically identical, no baked env, grep now returns 0.
- **Files modified:** `.github/actions/setup-minio/action.yml`
- **Commit:** `a1d96c7` (caught and fixed pre-commit; the committed file passes).

No other deviations — the three artifacts were built as specified.

## Prohibitions Held (D-15 / D-16)

Verified by construction and grep across the plan's commit range (`131fae7^..384f889`):

- **No workflow file modified** — only `.github/actions/setup-elixir/action.yml`, `.github/actions/setup-minio/action.yml`, `.tool-versions` changed. No `ci.yml`/`release.yml` touch → `name: CI`, filename, and required-check NAMEs untouched (D-04/D-15).
- **No reusable workflows** — `grep -L 'workflow_call:'` lists both composites (neither declares it) (D-16).
- **No `CI Summary` aggregate, no concurrency block, no lane/trigger split** (Phase 105/106 boundary) — zero `concurrency:` in the new files.
- **No third-party action SHA-pin, no `mix ci` alias** (Phase 107 boundary) — `grep mix ci` over `.github/actions/` = 0; composites reference in-repo `uses: ./…` paths only.
- **No `version-file:` wiring** anywhere (`grep -rl version-file .github/workflows .github/actions` = 0) (D-13).

## Input/Output Contract (for adoption plans to cite exactly)

**`uses: ./.github/actions/setup-elixir`**
| Input | Required | Default | Purpose |
|-------|----------|---------|---------|
| `elixir-version` | yes | — | setup-beam elixir-version |
| `otp-version` | yes | — | setup-beam otp-version |
| `mix-env` | no | `test` | MIX_ENV key segment + deps.get env |
| `cache-prefix` | no | `default` | namespace selector (`no-optional` for optional-deps job) |
| `install-deps` | no | `true` | run `mix deps.get` (set `false` for job-specific fetch) |

Outputs: `deps-cache-hit`, `build-cache-hit`.

**`uses: ./.github/actions/setup-minio`**
| Input | Required | Default | Purpose |
|-------|----------|---------|---------|
| `cors-allow-origin` | no | `""` | when set, injects `-e MINIO_API_CORS_ALLOW_ORIGIN=<value>` (pass `*` for adoption-demo-e2e) |

No outputs.

## Verification Results

- Task 1: composite YAML parses, `runs.using: composite`, has `outputs`, references `erlef/setup-beam@v1` + `runner.arch`, zero `**/mix.lock`, zero `mix compile` → PASS.
- Task 2: composite YAML parses, has `minio/minio` + `mc mb --ignore-existing local/rindle-test` + `minio/health/ready`, zero `RINDLE_MINIO_` → PASS.
- Task 3: `.tool-versions` has `elixir 1.17`/`otp-27`/`erlang 27`/`nodejs 20` lines, zero `version-file` across workflows+actions → PASS.

## Known Stubs

None. All three artifacts are complete and self-contained; they have no data source to wire (config/infra files).

## Commits

| Task | Commit | Type | Files |
|------|--------|------|-------|
| 1 | `131fae7` | feat | `.github/actions/setup-elixir/action.yml` |
| 2 | `a1d96c7` | feat | `.github/actions/setup-minio/action.yml` |
| 3 | `384f889` | chore | `.tool-versions` |

## Self-Check: PASSED

All 3 created files exist on disk; all 3 task commits (`131fae7`, `a1d96c7`, `384f889`) are present in git history.
