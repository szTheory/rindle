---
phase: 09
slug: install-release-confidence
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-28
revised: 2026-04-28
---

# Phase 09 — Validation Strategy

> Validation contract for package-consumer install proof, CI smoke coverage, and onboarding-doc parity.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit plus targeted workflow/docs contract checks |
| **Config file** | `mix.exs`, `test/test_helper.exs`, `config/test.exs`, GitHub Actions workflows |
| **Quick run command** | `mix test test/install_smoke/generated_app_smoke_test.exs --include minio` |
| **Full phase command** | `mix test test/install_smoke/generated_app_smoke_test.exs --include minio && mix test test/install_smoke/docs_parity_test.exs && mix test test/adopter/canonical_app/lifecycle_test.exs --include minio` |
| **Estimated runtime** | ~2-5 minutes once the generated-app smoke provisions its consumer app and backing services |

---

## Sampling Rate

- **After every task commit:** run the task-local verification command from the map below.
- **After every plan wave:** run generated-app smoke plus any touched docs parity or workflow checks.
- **Before `$gsd-verify-work`:** run the full phase command and confirm the package-consumer CI lane is wired in `.github/workflows/ci.yml`.
- **Max feedback latency:** keep non-release feedback under ~5 minutes; heavier release checks can run separately in the release workflow.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirements | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|--------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 09-01-01 | 01 | 1 | RELEASE-01 | T-09-01, T-09-02 | generated Phoenix app installs Rindle from the built artifact, runs host and library migrations explicitly, and completes presigned PUT upload verification through public APIs | integration / smoke | `mix test test/install_smoke/generated_app_smoke_test.exs --include minio` | ❌ Wave 0 | ⬜ pending |
| 09-01-02 | 01 | 1 | RELEASE-01 | T-09-02 | shared smoke helpers resolve package paths, migration paths, and runtime setup without repo-local `deps/rindle` assumptions | integration support / contract | `mix test test/install_smoke/generated_app_smoke_test.exs --include minio` | ❌ Wave 0 | ⬜ pending |
| 09-02-01 | 02 | 1 | RELEASE-02 | T-09-03 | PR CI builds and unpacks the package artifact, generates a consumer app, and runs the same narrow smoke lane from the built artifact | CI contract | `rg -n \"hex.build --unpack|install_smoke|generated_app_smoke|phx.new\" .github/workflows/ci.yml .github/workflows/release.yml` | ❌ Wave 0 | ⬜ pending |
| 09-03-01 | 03 | 2 | RELEASE-03 | T-09-04, T-09-05 | README quickstart and getting-started guide describe the same proven first-run path, including Repo ownership, default Oban expectations, explicit library migration setup, and multipart as advanced | docs parity / contract | `mix test test/install_smoke/docs_parity_test.exs` | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ partial*

### Coverage of Phase Requirements

| Requirement | Covered By | Status |
|-------------|------------|--------|
| RELEASE-01 | 09-01-01, 09-01-02 | ✅ planned |
| RELEASE-02 | 09-02-01 | ✅ planned |
| RELEASE-03 | 09-03-01 | ✅ planned |

---

## Wave 0 Requirements

- [x] `test/install_smoke/` test namespace reserved for generated-app smoke and docs parity.
- [x] Shared helper surface planned for package path resolution, migration-path resolution, config injection, and smoke assertions.
- [x] `.github/workflows/ci.yml` must gain a built-artifact consumer smoke lane.
- [x] `.github/workflows/release.yml` must reuse the same smoke helper or script entrypoint so PR and release checks cannot drift silently.
- [x] README / guide parity must be enforced by an executable contract test.

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V4 Access Control | yes | keep signed/private delivery defaults intact in smoke and docs; do not imply public delivery shortcuts |
| V5 Input Validation | yes | smoke must still pass through Rindle's existing verification and validation path after the presigned PUT |
| V6 Cryptography | yes | reuse storage-provider signed URLs only; do not hand-roll signing in helpers or docs |
| V8 Data Protection | yes | migration/runtime setup must avoid leaking secrets into committed helper fragments or docs |

### Known Threat Patterns for This Stack

| Threat ID | Pattern | STRIDE | Standard Mitigation |
|-----------|---------|--------|---------------------|
| T-09-01 | Smoke proves only compile/install but not the real upload-to-delivery lifecycle | Tampering | require a real presigned PUT plus verify/promote/delivery assertions in the generated-app smoke |
| T-09-02 | Consumer smoke hardcodes repo-local assumptions like `deps/rindle` | Denial of Service | resolve package migrations via `Application.app_dir(:rindle, \"priv/repo/migrations\")` and run explicit multi-path migrations |
| T-09-03 | PR and release workflows prove different install paths | Repudiation | centralize the consumer-smoke helper or script so both workflows reuse the same setup and assertions |
| T-09-04 | README teaches a path that has not been proven from the built artifact | Tampering | enforce docs parity against the generated-app smoke contract |
| T-09-05 | Docs omit adopter-owned Repo or default Oban requirements, causing hidden runtime failures | Availability | make Repo, Oban, and capability constraints explicit in quickstart and guide parity checks |

---

## Validation Sign-Off

- [x] All planned tasks have automated verification coverage.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing verification seams called out by research.
- [x] No watch-mode flags.
- [x] Feedback latency target is defined.
- [x] `nyquist_compliant: true` set in frontmatter.
- [x] `wave_0_complete: true` set in frontmatter.

**Approval:** revised 2026-04-28
