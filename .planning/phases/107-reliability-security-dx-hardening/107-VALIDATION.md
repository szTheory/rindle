---
phase: 107
slug: reliability-security-dx-hardening
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-22
---

# Phase 107 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) + Node assert-based gates (`brandbook/src/*.mjs`) + Playwright (demo E2E) |
| **Config file** | `test/test_helper.exs`, `config/test.exs`, `examples/adoption_demo/playwright.config.js` |
| **Quick run command** | `mix compile --warnings-as-errors && mix format --check-formatted && mix test` |
| **Full suite command** | `mix test --include integration --include minio --include contract --include adopter` (needs MinIO/Postgres) |
| **Estimated runtime** | ~140 seconds (default-tag suite) |

---

## Sampling Rate

- **After every task commit:** Run `mix compile --warnings-as-errors && mix format --check-formatted && mix test`
- **After every plan wave:** Run `mix ci` (once it exists) + the contrast gates (`node brandbook/src/admin-contrast.mjs`, `node brandbook/src/contrast.mjs`)
- **Before `/gsd-verify-work`:** Full default suite green + `mix deps.audit` clean + contrast-gate pass counts unchanged
- **Max feedback latency:** ~140 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| async-safety guard | 01 | 0 | HARD-01 | — | async-marked modules use no unsafe primitive | unit (meta) | `mix test test/async_safety_guard_test.exs` | ❌ W0 (the guard IS the new test) | ⬜ pending |
| async conversion | 01 | 1 | HARD-01 | — | converted modules still pass under concurrency | unit | `mix test` (full default suite green) | ✅ | ⬜ pending |
| SHA pins | 02 | 1 | HARD-02 | T-tamper (mutable-tag hijack) | every `uses:` is a 40-hex SHA | static | `! grep -rE 'uses: [^@]+@v[0-9]' .github/workflows .github/actions` | ❌ W0 (optional lint guard) | ⬜ pending |
| mix_audit | 02 | 1 | HARD-02 | T-tamper (vuln transitive dep) | advisory scan runs clean | advisory | `mix deps.audit` | ✅ (after dep added) | ⬜ pending |
| least-privilege permissions | 02 | 1 | HARD-02 | T-infodisc (broad token) | each job declares scoped `permissions:` | static review | `grep -A2 'permissions:' .github/workflows/*.yml` | ✅ | ⬜ pending |
| mix ci alias | 03 | 1 | HARD-03 | — | `mix ci` reproduces the PR verdict | smoke | `mix ci` exits 0 locally | ❌ W0 (alias is new) | ⬜ pending |
| contrast constant | 04 | 0 | HARD-04 | — | contrast gates unchanged after extraction | unit | `mix test test/brandbook/admin_design_system_validation_test.exs` + `node brandbook/src/admin-contrast.mjs` | ✅ | ⬜ pending |
| Playwright container repro | 04 | 1 | HARD-04 | — | E2E runs against the pinned container | e2e | `bash scripts/ci/e2e_local.sh` | ❌ W0 (script is new) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/async_safety_guard_test.exs` — the AST meta-test (HARD-01, D-02 — lands FIRST, before any conversion)
- [ ] `mix.exs` `aliases/0` `ci:` entry (HARD-03)
- [ ] `.github/dependabot.yml` (HARD-02)
- [ ] `brandbook/src/contrast-constants.mjs` (HARD-04 — `WCAG_AA_NORMAL = 4.5`)
- [ ] `scripts/ci/e2e_local.sh` (HARD-04)
- [ ] (optional) SHA-pin lint script to keep pins from regressing (HARD-02)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| dependabot actually opens grouped weekly PRs | HARD-02 | Requires GitHub-side scheduler over time | Observe `.github/dependabot.yml` is valid (GitHub parses it; check repo Insights → Dependency graph → Dependabot tab) post-merge |
| README badge visually reflects `CI Summary` gate | HARD-03 | Rendered badge is a GitHub-hosted SVG | Confirm `README.md` badge URL = `ci.yml/badge.svg?branch=main` and docs state it reflects the `CI Summary` gate |
| `e2e_local.sh` produces byte-identical browser env to CI | HARD-04 | Requires Docker locally | Run `bash scripts/ci/e2e_local.sh` with Docker available; confirm same image tag as `ci.yml` E2E lane |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 140s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
