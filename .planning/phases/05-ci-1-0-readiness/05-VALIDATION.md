---
phase: 5
slug: ci-1-0-readiness
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-26
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit 1.18 + excoveralls 0.18 (to be added) |
| **Config file** | `mix.exs` (test_coverage), `coveralls.json` (Wave 0 creates) |
| **Quick run command** | `mix test --exclude integration --exclude minio --exclude adopter` |
| **Full suite command** | `mix coveralls` (quality lane) + `mix test --only contract` (contract lane) + `mix test --only adopter` (adopter lane) |
| **Estimated runtime** | ~120 seconds (quality) + ~30 seconds (contract) + ~180 seconds (adopter) |

---

## Sampling Rate

- **After every task commit:** Run quick command
- **After every plan wave:** Run the relevant lane command (quality / contract / adopter / release-dryrun)
- **Before `/gsd-verify-work`:** Full suite (all lanes) must be green
- **Max feedback latency:** 180 seconds (adopter lane is the longest single command)

---

## Per-Task Verification Map

*Populated by gsd-planner per task during planning. Initial scaffold below — planner will replace with the canonical map after PLAN.md files are written.*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 5-01-01 | 01 | 1 | TEL-01..08 | — | Telemetry events fire at locked sites with required metadata | unit + contract | `mix test test/rindle/telemetry/` | ❌ W0 | ⬜ pending |
| 5-02-01 | 02 | 1 | CI-06 | — | Contract test asserts allowlist + required metadata keys | contract | `mix test --only contract` | ❌ W0 | ⬜ pending |
| 5-03-01 | 03 | 2 | CI-01..05 | — | Quality lane gates format/warnings/coverage/credo/dialyzer | CI integration | `gh workflow run ci.yml` (or local: `mix coveralls && mix credo --strict && mix dialyzer`) | ✅ (extends existing) | ⬜ pending |
| 5-04-01 | 04 | 2 | CI-08 | — | Adopter lane runs full lifecycle against MinIO + Postgres | integration | `mix test --only adopter` | ❌ W0 | ⬜ pending |
| 5-05-01 | 05 | 3 | CI-09 | — | Release lane dry-runs hex publish + asserts package contents | CI integration | `mix hex.publish --dry-run && mix hex.build` | ❌ W0 | ⬜ pending |
| 5-06-01 | 06 | 3 | DOC-01..08 | — | Guides build cleanly via `mix docs`; getting-started snippet matches adopter lane code path | docs build + manual review | `mix docs && grep -r "Rindle.attach" guides/getting_started.md` | ❌ W0 | ⬜ pending |

---

## Wave 0 Requirements

- [ ] `coveralls.json` — root config with `minimum_coverage: 80` and conventional exclusions
- [ ] `mix.exs` — add `:excoveralls` to deps (test only) and `test_coverage: [tool: ExCoveralls]` to project/0
- [ ] `test/rindle/telemetry/contract_test.exs` — contract lane file (`@moduledoc` + `@tag :contract`)
- [ ] `test/adopter/canonical_app/` — adopter fixture skeleton (adopter Repo, supervisor, schema)
- [ ] `test/test_helper.exs` — ensure `:contract` and `:adopter` tags are recognized in ExUnit configuration
- [ ] `guides/` — directory exists with placeholder files for DOC-01..07 (planner may create stubs in Wave 0 or Wave 3)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Getting-started guide is copy-pasteable in a fresh Phoenix app | DOC-01 / Success Criterion 5.5 | Requires bootstrapping a Phoenix app outside this repo | After `mix docs` succeeds, copy snippet from `guides/getting_started.md` into a fresh `mix phx.new demo` project; run upload → variant → delivery; verify zero gaps |
| State diagrams render correctly in published HexDocs | DOC-02 | Mermaid CDN renders client-side; CI cannot screenshot | Run `mix docs`, open `doc/core_concepts.html` in a browser, confirm asset/variant/upload-session diagrams render |
| Hex publish dry-run actually rejects metadata regressions | CI-09 / D-11 | Dry-run output is human-readable; assertion needs eyeballing once before lane is trusted | Manually omit `package: [files: ...]` entry, run `mix hex.publish --dry-run`, confirm release lane fails |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
