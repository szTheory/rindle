---
phase: 114
slug: oss-trust-governance
status: verified
threats_open: 0
asvs_level: 1
created: 2026-07-01
---

# Phase 114 - Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Security researcher to disclosure channel | A researcher with a vulnerability must reach the maintainer privately. `SECURITY.md` and GitHub Private Vulnerability Reporting are the routing artifacts. | Vulnerability details and reproduction material |
| Newcomer to issue/PR intake | An untrusted contributor's first interaction; templates shape reports and steer security reports away from public issues. | Issue text, feature proposals, PR metadata |
| Maintainer build config to hex.pm package page | Static package metadata in `mix.exs` is serialized into the published tarball and rendered on the public Hex package page. | Public package links and owner-derived maintainer signal |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-114-01 | Information Disclosure | `SECURITY.md` disclosure section | mitigate | Reporters are routed to GitHub Private Vulnerability Reporting / Security Advisories only; `SECURITY.md` has no email or public-issue disclosure path. Verified by `governance_files_test.exs` and no-email grep. | closed |
| T-114-02 | Information Disclosure | `CODE_OF_CONDUCT.md` enforcement contact | mitigate | Enforcement contact is GitHub-routed through advisories or maintainer `@szTheory`; no personal email is exposed. Verified by contact/no-email grep. | closed |
| T-114-03 | Tampering / Repudiation | Public issue intake | mitigate | `.github/ISSUE_TEMPLATE/config.yml` sets `blank_issues_enabled: false` and routes security reports to `https://github.com/szTheory/rindle/security/advisories/new`. | closed |
| T-114-04 | Denial of Service (process) | Existing `release-train-drift.md` template | mitigate | Existing maintainer issue template was preserved; hash verified as `744d52c47e569642413c728a636ae3fdd062ae1951dab7999cd27f9b054df028`. | closed |
| T-114-05 | Spoofing / Information Disclosure | `package.links` targets | mitigate | Package links point only to first-party canonical URLs: GitHub, Changelog on the repo `main` branch, and HexDocs. Verified in `mix.exs` and package metadata smoke test. | closed |
| T-114-06 | Tampering | Meta-test to `mix.exs` coupling | mitigate | `package_metadata_test.exs` asserts the generated metadata entries and release verifier wiring, preventing a red or stale package metadata lane. | closed |
| T-114-07 | Spoofing | Hex owner signal | mitigate | `scripts/verify_hex_package_metadata.sh` verifies the public Hex API exposes `sztheory` in `owners[]` after publish instead of relying on unsupported local maintainer keys. | closed |

No npm, pip, cargo, or other package-manager installs were introduced in this phase; no supply-chain threat was opened.

---

## Accepted Risks Log

No accepted risks.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-07-01 | 7 | 7 | 0 | Codex |

Verification evidence:

- `mix test test/install_smoke/governance_files_test.exs` - 3 tests, 0 failures.
- `mix test test/install_smoke/package_metadata_test.exs` - 16 tests, 0 failures.
- `SECURITY.md` advisory/no-email grep - pass.
- `CODE_OF_CONDUCT.md` GitHub-routed/no-email grep - pass.
- `.github/ISSUE_TEMPLATE/config.yml` blank-issues-disabled and advisory-link grep - pass.
- `.github/ISSUE_TEMPLATE/release-train-drift.md` SHA-256 - `744d52c47e569642413c728a636ae3fdd062ae1951dab7999cd27f9b054df028`.
- User confirmed GitHub Private Vulnerability Reporting is enabled and the `Report a vulnerability` link renders at `/szTheory/rindle/security/advisories/new`.

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-07-01
