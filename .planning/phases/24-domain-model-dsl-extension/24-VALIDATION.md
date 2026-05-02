---
phase: 24
slug: domain-model-dsl-extension
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-02
---

# Phase 24 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.15+/Erlang 26+, Hex `mix.exs`) |
| **Config file** | `config/test.exs`, `test/test_helper.exs` |
| **Quick run command** | `mix test --include focus --exclude integration` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~120 seconds (full suite incl. MinIO lifecycle test) |

---

## Sampling Rate

- **After every task commit:** Run `mix test path/to/touched_test.exs`
- **After every plan wave:** Run `mix test` (full suite)
- **Before `/gsd-verify-work`:** Full suite must be green; `mix compile --warnings-as-errors` clean
- **Max feedback latency:** 30 seconds for per-task; 120 seconds for full suite

---

## Per-Task Verification Map

> Populated by the planner after PLAN.md tasks are written. Each task row will be derived from PLAN frontmatter `verification_criteria` + RESEARCH.md `## Validation Architecture` section.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| _TBD by planner_ | | | | | | | | | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/rindle/backward_compat/v13_digest_snapshot_test.exs` — captures v1.3 `:thumb` recipe digest BEFORE any validator edits (D-23, load-bearing for D-14)
- [ ] `test/rindle/profile/per_kind_validator_test.exs` — stubs for AV-02-04 (NimbleOptions per-kind dispatch)
- [ ] `test/rindle/probe/probe_behaviour_test.exs` — stubs for AV-02-05 (probe behaviour contract)
- [ ] `test/rindle/av/metadata_sanitizer_test.exs` — stubs for AV-02-10 (1024-byte truncation, control-char strip)

*Existing ExUnit infrastructure covers all phase requirements; no framework install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| End-to-end MinIO lifecycle for video upload | AV-02-09 | Requires running MinIO container + sample MP4 fixture | `docker compose up minio && mix test test/adopter/canonical_app/lifecycle_test.exs --include integration` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s per task
- [ ] `nyquist_compliant: true` set in frontmatter once planner populates verification map

**Approval:** pending
