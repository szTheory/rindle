---
phase: 104
slug: cache-tooling-hygiene
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-22
reconstructed: 2026-06-22
---

# Phase 104 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> **Reconstructed retroactively** (State B) during the v1.20 milestone audit — the phase
> shipped & verified (`104-VERIFICATION.md`, 24/24) without a VALIDATION.md. This document
> records the now-committed automated regression coverage for every CACHE requirement.

This is a CI/CD-infrastructure phase: deliverables are GitHub Actions workflows + composite
actions, not application code. Per-requirement coverage is provided by a committed ExUnit
file-content parity test (the repo's established `test/install_smoke/*_parity_test.exs`
pattern) that reads the live `.github/**` files and asserts the cache-hygiene invariants —
so any future drift (e.g. a composite reverted to inline setup, a cache key losing a
dimension, the PLT split collapsing) fails the merge-blocking gate.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | none — uses the repo's existing `test/` tree + `mix test` |
| **Quick run command** | `mix test test/install_smoke/ci_cache_hygiene_test.exs` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | ~0.02s (parity test) / ~10s (full `mix ci` gate) |

---

## Sampling Rate

- **After every task commit:** `mix test test/install_smoke/ci_cache_hygiene_test.exs`
- **After every plan wave:** `mix ci`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~10 seconds (full `mix ci`)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 104-01 | 01 | 1 | CACHE-01 | setup-elixir + setup-minio composites are the single source of truth (`using: composite`; adopted ×10 / ×6 in ci.yml, ×2 in release.yml) | parity | `mix test test/install_smoke/ci_cache_hygiene_test.exs` | ✅ | ✅ green |
| 104-01/03 | 01,03 | 1,3 | CACHE-02 | cache key carries os/arch + resolved otp/elixir + mix-env + `hashFiles('mix.lock')` + `-v1-` buster; bans `**/mix.lock` | parity | `mix test test/install_smoke/ci_cache_hygiene_test.exs` | ✅ | ✅ green |
| 104-02 | 02 | 2 | CACHE-03 | PLT restore/save split (now in `nightly.yml`, moved by Phase 106); key hashes `mix.exs`+`.dialyzer_ignore.exs` not mix.lock; save guarded `cache-hit != 'true'`, not `if: always()`; absent from ci.yml | parity | `mix test test/install_smoke/ci_cache_hygiene_test.exs` | ✅ | ✅ green |
| 104-02 | 02 | 2 | CACHE-04 | `mix deps.get --check-locked` + `mix deps.unlock --check-unused` gate lockfile drift | behavioral | `mix ci` (also CI `quality` job, every build) | ✅ | ✅ green |
| 104-01/02/04 | 01,02,04 | 1,2,4 | CACHE-05 | `.tool-versions` pins primary pair; release.yml has zero `FedericoCarboni/setup-ffmpeg` → `install_ffmpeg.sh`; lint guarded by `if: matrix.lint` with a `lint: true` include | parity | `mix test test/install_smoke/ci_cache_hygiene_test.exs` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure (`mix test` / `mix ci`) covers all phase requirements. The single
new file `test/install_smoke/ci_cache_hygiene_test.exs` (11 tests) was added retroactively
during the audit; it runs in the default suite (no exclude tag — matching the sibling
`release_docs_parity_test.exs`).

---

## Manual-Only Verifications

All phase behaviors have automated verification.

(Note: the *runtime* effect of cache keys — actual GitHub Actions cache hit/miss across
runs — is observable only on GitHub and is surfaced by the Phase 103 OBS-01 step summary; it
is not a per-PR regression target. The *correctness* of the key schema and composite wiring,
which is what could silently regress in a diff, is fully covered by the parity test above.)

---

## Validation Sign-Off

- [x] All tasks have automated verify or existing-infrastructure coverage
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (1 new parity test added)
- [x] No watch-mode flags
- [x] Feedback latency < 11s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-06-22 (retroactive reconstruction during v1.20 milestone audit)

---

## Validation Audit 2026-06-22

| Metric | Count |
|--------|-------|
| Gaps found | 4 (CACHE-01, CACHE-02, CACHE-03, CACHE-05) |
| Resolved | 4 (new `ci_cache_hygiene_test.exs`, 11 tests) |
| Already covered | 1 (CACHE-04 — lockfile gates run in `mix ci` + CI quality) |
| Escalated | 0 |
