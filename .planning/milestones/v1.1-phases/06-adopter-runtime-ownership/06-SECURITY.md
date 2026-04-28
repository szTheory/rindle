---
phase: 6
slug: adopter-runtime-ownership
status: verified
threats_open: 0
asvs_level: 1
created: 2026-04-28
---

# Phase 6 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| public API -> runtime Repo | Consumer-facing facade calls resolve and use the configured Repo for asset, attachment, and upload persistence. | Asset IDs, owner IDs, attachment slots, upload metadata |
| public API -> background job enqueue | Attach, detach, upload, and broker completion enqueue follow-up work after state transitions. | Asset IDs, profile names, lifecycle job args |
| broker -> storage adapter | Untrusted upload completion is checked against storage before session and asset promotion. | Upload keys, object metadata |
| guides -> adopter implementation | Copy-paste setup and troubleshooting docs influence runtime Repo and Oban ownership choices. | Repo config, Oban scope, operational queries |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-06-01-01 | T | `lib/rindle.ex` transaction path | mitigate | `Rindle.Config.repo/0` is the single seam and facade flows transact via the resolved Repo, including transaction callback reads and purge enqueue operations. | closed |
| T-06-01-02 | R | facade docs/examples | mitigate | Public examples were rewritten to require adopter-owned Repo config instead of implying `Rindle.Repo` ownership. | closed |
| T-06-01-03 | D | attach/detach purge callback | accept | Phase 6 intentionally keeps default `Oban` ownership semantics; named-instance routing is documented as out of scope rather than implied. | closed |
| T-06-02-01 | T | `lib/rindle/upload/broker.ex` | mitigate | Broker reads, writes, and verify-completion transactions use the resolved Repo end to end, including promotion enqueue after verification. | closed |
| T-06-02-02 | R | canonical adopter proof | mitigate | Canonical adopter tests override `:rindle, :repo`, run on adopter-only sandbox ownership, and assert lifecycle reads through `Rindle.Adopter.CanonicalApp.Repo`. | closed |
| T-06-02-03 | D | Oban ownership expectations | mitigate | Tests and docs prove default `Oban` compatibility only and explicitly defer named-instance support. | closed |
| T-06-03-01 | T | guide snippets | mitigate | Adopter-facing docs now teach `config :rindle, :repo, MyApp.Repo` and remove runtime `Rindle.Repo` guidance. | closed |
| T-06-03-02 | R | Oban ownership wording | mitigate | Background-processing guidance now states the exact delivered boundary: adopter-owned default `Oban` path only. | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-06-01 | T-06-01-03 | Phase 6 corrects Repo ownership without introducing named-instance Oban routing; the remaining scope is explicit and documented as default-`Oban` only. | Phase 6 plan scope | 2026-04-28 |

*Accepted risks do not resurface in future audit runs.*

---

## Verification Evidence

- `lib/rindle/config.ex` exposes `Rindle.Config.repo/0` as the runtime Repo seam, with fallback to `Rindle.Repo` for the in-repo harness.
- `lib/rindle.ex` resolves the configured Repo for `attach/4`, `detach/3`, and `upload/3`, and keeps purge enqueue inside Repo-owned transaction paths.
- `lib/rindle/upload/broker.ex` uses the configured Repo for session and asset persistence and enqueues promotion after verify-completion through the same transaction boundary.
- `lib/rindle/workers/promote_asset.ex`, `lib/rindle/workers/process_variant.ex`, and `lib/rindle/workers/purge_storage.ex` resolve persistence through `Rindle.Config.repo/0`, closing the follow-up worker leak found during Plan 06-02.
- `test/adopter/canonical_app/lifecycle_test.exs` proves the full direct-upload lifecycle, attach/detach flow, and job enqueue assertions under `Rindle.Adopter.CanonicalApp.Repo`.
- `test/rindle/upload/lifecycle_integration_test.exs` includes a dedicated adopter-repo `Rindle.upload/3` proof that promotes and processes variants through the adopter Repo.
- `guides/getting_started.md`, `guides/troubleshooting.md`, and `guides/background_processing.md` now describe adopter-owned Repo setup and default-`Oban` scope honestly.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-04-28 | 8 | 8 | 0 | Codex |

---

## Security Audit 2026-04-28

| Metric | Count |
|--------|-------|
| Threats found | 8 |
| Closed | 8 |
| Open | 0 |

Verification run:

- `mix test test/rindle/config/config_test.exs test/rindle/upload/broker_test.exs test/adopter/canonical_app/lifecycle_test.exs test/rindle/upload/lifecycle_integration_test.exs`
- Result: `19 tests, 0 failures`

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-04-28
