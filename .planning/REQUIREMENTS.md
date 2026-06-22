# Requirements: Rindle — v1.20 CI/CD Performance

**Defined:** 2026-06-20
**Core Value:** Media, made durable.
**Milestone goal:** Cut PR CI feedback time and harden gate determinism/reliability — without
dropping real quality signal — via a measure → classify → restructure pass shipped as stepwise PRs.
**Source:** SEED-003 (authoritative 10-lens audit prompt) + `.planning/research/SUMMARY.md`.

> **Posture:** Non-feature / DX-infrastructure milestone — ZERO `lib/` public-API change. The
> "user" of these requirements is the contributor/maintainer; requirements are phrased as
> observable, testable CI/DX capabilities (matching v1.16/v1.17 hygiene-milestone convention).
> The dependency ordering below is **load-bearing** (research-unanimous): observability →
> cache/tooling → aggregate required check → lane split → reliability/security/DX. Reversing the
> required-check and lane-split steps forces a second branch-protection migration.
>
> Prior shipped milestones (v1.18, v1.19) are archived under `milestones/v1.18-REQUIREMENTS.md`
> and `milestones/v1.19-REQUIREMENTS.md`.

## v1.20 Requirements

### Observability & Baseline (OBS)

- [x] **OBS-01**: CI surfaces per-job and per-step timing plus cache hit/miss in the run summary
  (`$GITHUB_STEP_SUMMARY`), with no change to gate behavior.

- [x] **OBS-02**: CI surfaces `mix test --slowest 20`, a compile-time profile, `System.schedulers_online()`,
  and the ExUnit seed; JUnit and coverage artifacts are uploaded for inspection.

- [x] **OBS-03**: A committed baseline table (per-job avg + p95 + rerun/flake rate) and the *actual*
  current branch-protection required-check names are captured before any restructuring begins.

### Cache & Tooling Hygiene (CACHE)

- [x] **CACHE-01**: A `.github/actions/setup-elixir` composite action (plus a shared MinIO setup
  step) is the single source of truth for environment setup and cache keys across the jobs that
  duplicate that block today.

- [x] **CACHE-02**: Cache keys include OS+arch, OTP, Elixir, `MIX_ENV`, the `mix.lock` hash, and a
  version buster; deps, `_build`, and PLT caches are kept separate and never restored across
  incompatible dimensions.

- [x] **CACHE-03**: The Dialyzer PLT uses an `actions/cache` restore/save split that persists the
  built PLT even when analysis fails, with the PLT key hashing `mix.exs`/`.dialyzer_ignore.exs`.

- [x] **CACHE-04**: `mix deps.get --check-locked` and `mix deps.unlock --check-unused` gate
  lockfile drift so a stale or unused lock cannot pass via broad restore keys.

- [x] **CACHE-05**: Version-invariant lint (`format --check-formatted`, Credo, doctor) runs once on
  the primary pair instead of redundantly on every matrix cell; `.tool-versions` lands and the stray
  `setup-ffmpeg` action in `release.yml` is aligned to the repo's ffmpeg install path.

### Required-Check Topology (GATE)

- [x] **GATE-01**: A single stable `CI Summary` aggregate job (`needs:` all jobs, `if: always()`,
  treating `skipped` as pass) becomes the sole signal that represents overall CI status.

- [x] **GATE-02**: `scripts/setup_branch_protection.sh` (and the nightly re-assert workflow) is
  updated in the same change so branch protection requires only `CI Summary`; the fork-PR
  "pending forever" trap is closed and the `CI` workflow name/filename (release-train coupling via
  `release-please-automerge.yml` + `gate-ci-green`) is preserved.

### Lane Separation (LANE)

- [x] **LANE-01**: A fast PR lane with a `concurrency` group that cancels stale in-progress PR runs
  targets a representative gate at roughly ≤7 minutes; main and release lanes serialize and never
  cancel.

- [x] **LANE-02**: The `package-consumer` long pole is scoped by trigger — one representative `image`
  install-smoke on PR; the full 5-profile matrix + `release_preflight` + `hex.publish --dry-run` run
  on `push:main`/nightly/release, with the release full-verification gate provably intact.

- [x] **LANE-03**: A nightly lane carries the broad OTP×Elixir compatibility matrix, `gcs-soak`,
  `package-consumer-gcs-live`, and an owned Dialyzer lane off the PR critical path.

- [x] **LANE-04**: A documented keep / optimize / move-to-nightly / quarantine / delete (buckets A–E)
  test-value classification backs every lane placement, and coverage is moved off the PR critical
  path. Any trust/speed tradeoff is labeled explicitly (in CONTRIBUTING and the PR).

### Reliability, Security & DX Hardening (HARD)

- [x] **HARD-01**: An ExUnit async-safety static guard lands before any conversion; verified-safe
  modules are converted to `async: true`, and `--partitions` (with DB-per-partition + merged
  coverage) is adopted only where PR-1 measurement and runner cores justify it.

- [x] **HARD-02**: All third-party actions are pinned to immutable SHAs, `dependabot.yml`
  (`github-actions` + `mix`) lands, `{:mix_audit, "~> 2.1"}` is added to the audit lane, and each job
  declares least-privilege `permissions:`.

- [x] **HARD-03**: A single local `mix ci` alias mirrors the merge-blocking checks; `CONTRIBUTING.md`
  documents the lanes, the required check, and the local command; the README badge points at the
  meaningful (`CI Summary`) check.

- [x] **HARD-04**: A faithful Linux-Chromium local repro lands (pinned Playwright container +
  `scripts/ci/e2e_local.sh` + exact `@playwright/test` and font pins), and the divergent token-pair
  vs runtime contrast thresholds are reconciled to one shared constant.

## Future Requirements

Deferred to v1.20.x / a later infra slice. Tracked, not in this roadmap.

### Deferred (DEFER)

- **DEFER-01**: Dedicated flaky-quarantine lane with reproducible-seed logging — trigger: a test
  actually proves flaky in the new baseline.

- **DEFER-02**: Self-hosted or larger GitHub runners — only if post-partition core-starvation is
  measured, not assumed.

- **DEFER-03**: Property-based / exhaustive nightly test expansion.

## Out of Scope

Explicit exclusions (anti-features from research) — documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Auto-retry flaky tests as the "fix" | Hides nondeterminism; the seed forbids it — fix or quarantine instead |
| Deleting slow tests merely for being slow | Must classify (A–E) with evidence first; speed is not a deletion reason |
| Moving correctness-critical tests to schedule-only to fake a green PR | Trades gate trust for cosmetic speed |
| SaaS visual-regression gate (Percy/Chromatic) | Cost + external dependency; computed-style gate already covers it |
| Making Credo/Dialyzer merge-blocking | Reverses locked decision CI-04 (they stay advisory) |
| `pull_request_target` for fork secrets | Runs untrusted fork code with secrets; current fail-closed posture is correct |
| OS×OTP×Elixir×adapter×partition matrix explosion / dynamic-matrix cleverness | Rube-Goldberg CI; keep YAML boring and idiomatic |
| Presentation / metrics dashboards | Lowest north-star priority; observability lives in step summaries |
| Any `lib/` public-API or behavior change | This is a DX/infra milestone; zero runtime surface change |

## Traceability

Populated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| OBS-01 | Phase 103 | Complete |
| OBS-02 | Phase 103 | Complete |
| OBS-03 | Phase 103 | Complete |
| CACHE-01 | Phase 104 | Complete |
| CACHE-02 | Phase 104 | Complete |
| CACHE-03 | Phase 104 | Complete |
| CACHE-04 | Phase 104 | Complete |
| CACHE-05 | Phase 104 | Complete |
| GATE-01 | Phase 105 | Complete |
| GATE-02 | Phase 105 | Complete |
| LANE-01 | Phase 106 | Complete |
| LANE-02 | Phase 106 | Complete |
| LANE-03 | Phase 106 | Complete |
| LANE-04 | Phase 106 | Complete |
| HARD-01 | Phase 107 | Complete |
| HARD-02 | Phase 107 | Complete |
| HARD-03 | Phase 107 | Complete |
| HARD-04 | Phase 107 | Complete |

**Coverage:**

- v1.20 requirements: 18 total
- Mapped to phases: 18 ✓ (Phase 103: OBS-01..03; Phase 104: CACHE-01..05; Phase 105: GATE-01..02; Phase 106: LANE-01..04; Phase 107: HARD-01..04)
- Unmapped: 0

---
*Requirements defined: 2026-06-20*
*Last updated: 2026-06-20 — roadmap created; 18/18 requirements mapped to Phases 103–107 (v1.20 CI/CD Performance)*
