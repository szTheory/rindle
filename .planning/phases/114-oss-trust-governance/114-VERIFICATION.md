---
phase: 114-oss-trust-governance
verified: 2026-06-30T15:26:28Z
status: human_needed
next_action: "Enable GitHub Private Vulnerability Reporting in repo Settings, confirm the Report a vulnerability button renders, then rerun verification."
next_command: "/gsd-verify-work 114"
score: "9/9 must-haves verified"
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Enable GitHub Private Vulnerability Reporting and confirm the Security tab exposes Report a vulnerability."
    expected: "The repository Security tab shows the private Report a vulnerability path for GitHub Security Advisories."
    why_human: "This is a GitHub repository setting outside the codebase; the repo tree can only verify SECURITY.md and issue-template routing."
---

# Phase 114: OSS Trust & Governance Verification Report

**Phase Goal:** Close the OSS governance/trust gap so a newcomer or security researcher lands on a project that signals it is maintained, safe to report to, and welcoming to contribute to, and so hex.pm surfaces conventional package links and owner-derived maintainer signal.
**Verified:** 2026-06-30T15:26:28Z
**Status:** human_needed
**Re-verification:** No, initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | The repo has a SECURITY.md with a vulnerability-disclosure policy appropriate for untrusted uploads, MIME sniffing, signed delivery, and webhook HMAC verification. | VERIFIED | `SECURITY.md` has Supported Versions, GitHub Security Advisories reporting, no public issue path, no email disclosure channel, and What to Report bullets for upload validation, MIME/content sniffing, malware scan hooks, signed URLs, webhook HMAC/replay, and media subprocess handling. |
| 2 | The repo has a CODE_OF_CONDUCT.md. | VERIFIED | `CODE_OF_CONDUCT.md` is Contributor Covenant 2.1 and routes enforcement through Security advisories or GitHub maintainer `@szTheory`. |
| 3 | Newcomers opening issues or PRs are guided by issue templates and a PR template. | VERIFIED | `.github/ISSUE_TEMPLATE/bug_report.yml`, `feature_proposal.yml`, `config.yml`, and `.github/PULL_REQUEST_TEMPLATE.md` exist; forms point to CONTRIBUTING, config disables blank issues, and PR template includes summary, linked issue, and checklist. |
| 4 | Blank issues are disabled and the security contact link routes to GitHub advisories. | VERIFIED | `.github/ISSUE_TEMPLATE/config.yml` has `blank_issues_enabled: false` and `https://github.com/szTheory/rindle/security/advisories/new`. |
| 5 | The existing release-train-drift template remains present. | VERIFIED | `.github/ISSUE_TEMPLATE/release-train-drift.md` exists with SHA-256 `744d52c47e569642413c728a636ae3fdd062ae1951dab7999cd27f9b054df028`. |
| 6 | Governance smoke coverage asserts governance files, release-train template preservation, and no email in SECURITY.md. | VERIFIED | `test/install_smoke/governance_files_test.exs` checks the six governance files, release-train-drift presence, advisory routing, and absence of email; targeted test passed. |
| 7 | package.links exposes GitHub, Changelog, and Docs without adding governance files to the Hex tarball. | VERIFIED | `mix.exs` `package/0` links map contains GitHub, Changelog via `#{@source_url}/blob/main/CHANGELOG.md`, and Docs via `https://hexdocs.pm/rindle`; `files:` remains `lib priv/repo/migrations priv/static/rindle_admin mix.exs README.md RUNNING.md CHANGELOG.md LICENSE guides`. |
| 8 | Release public verification checks Hex API owner-derived maintainer signal for `sztheory`. | VERIFIED | `scripts/verify_hex_package_metadata.sh` fetches `https://hex.pm/api/packages/${PACKAGE}` and validates `owners[].username` contains `sztheory`; `.github/workflows/release.yml` runs it after Hex indexing. A read-only live package API check also returned `owners: sztheory`. |
| 9 | package_metadata_test passes with robust link assertions and release-verifier wiring assertions. | VERIFIED | `test/install_smoke/package_metadata_test.exs` compactly asserts individual GitHub/Changelog/Docs metadata tuples, prohibits `.github`/`test` paths from the unpacked artifact, and asserts release workflow plus Hex metadata verifier wiring; targeted test passed. |

**Score:** 9/9 truths verified, 0 behavior-unverified.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `SECURITY.md` | Advisory-only vulnerability policy | VERIFIED | Exists; no email match; no public issue path; covers Rindle threat surface. |
| `CODE_OF_CONDUCT.md` | Contributor Covenant 2.1 with GitHub-routed contact | VERIFIED | Exists; references Contributor Covenant 2.1 and `@szTheory`. |
| `.github/ISSUE_TEMPLATE/bug_report.yml` | Structured bug form | VERIFIED | Exists with required What happened and Rindle version fields. |
| `.github/ISSUE_TEMPLATE/feature_proposal.yml` | Structured feature form | VERIFIED | Exists with required problem statement and proposed approach. |
| `.github/ISSUE_TEMPLATE/config.yml` | Blank issues disabled plus security contact link | VERIFIED | `blank_issues_enabled: false`; security advisory URL present. |
| `.github/PULL_REQUEST_TEMPLATE.md` | Populated PR body | VERIFIED | Summary, linked issue, checklist, and CONTRIBUTING pointer present. |
| `test/install_smoke/governance_files_test.exs` | Governance presence and SECURITY.md route guard | VERIFIED | 31 lines, substantive assertions, passed. |
| `mix.exs` | Three-entry package links map, no unsupported maintainers key | VERIFIED | GitHub/Changelog/Docs present; `rg maintainer:` found no `maintainers:` key. |
| `test/install_smoke/package_metadata_test.exs` | Robust metadata and release wiring assertions | VERIFIED | 16-test file passed; asserts links, release workflow, script API checks, and prohibited package paths. |
| `scripts/verify_hex_package_metadata.sh` | Public Hex metadata verifier | VERIFIED | Fetches package and release API JSON, checks package links, owners, release version, and publisher; `bash -n` passed. |
| `.github/workflows/release.yml` | Public verification wiring | VERIFIED | `public_verify` waits for Hex indexing, runs `bash scripts/verify_hex_package_metadata.sh "$VERSION"`, then HexDocs and public artifact smoke. |
| `guides/release_publish.md` | Maintainer runbook updates | VERIFIED | Documents package metadata review, public metadata verifier, owner-derived maintainer signal, and routine release step order. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `.github/ISSUE_TEMPLATE/config.yml` | GitHub Security Advisories | `contact_links.url` | WIRED | Routes to `https://github.com/szTheory/rindle/security/advisories/new`. |
| `SECURITY.md` | GitHub Private Vulnerability Reporting | Reporting a Vulnerability section | WIRED | Directs reporters to Security tab / Report a vulnerability; no email or public issue disclosure path. |
| Issue forms and PR template | `CONTRIBUTING.md` | Markdown links | WIRED | Bug, feature, and PR templates point contributors to CONTRIBUTING. |
| `mix.exs` | `package_metadata_test.exs` | Generated Hex metadata tuple assertions | WIRED | Test asserts GitHub, Changelog, and Docs entries after metadata whitespace compaction. |
| `.github/workflows/release.yml` | `scripts/verify_hex_package_metadata.sh` | Public Verify step | WIRED | Runs `bash scripts/verify_hex_package_metadata.sh "$VERSION"` immediately after Hex indexing. |
| `scripts/verify_hex_package_metadata.sh` | Hex package and release APIs | `curl` package/release endpoints plus Python JSON checks | WIRED | Checks package `meta.links`, `owners[]`, release version, package releases list, and publisher username. |
| `guides/release_publish.md` | Release workflow metadata verifier | Runbook command list and routine release checklist | WIRED | Documents `Verify public Hex.pm metadata` and `bash scripts/verify_hex_package_metadata.sh "$VERSION"`. |

### Data-Flow Trace

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| `scripts/verify_hex_package_metadata.sh` | `package_data`, `release_data`, `owners`, `links` | `curl` to `https://hex.pm/api/packages/${PACKAGE}` and `/releases/${VERSION}` | Yes, public Hex API JSON parsed by Python | FLOWING |
| `.github/workflows/release.yml` | `VERSION` | `needs.publish.outputs.release_version` after publish | Yes, passes release version into public metadata verifier | FLOWING |
| Static governance files/templates | n/a | GitHub-discoverable repo paths | n/a | N/A, static docs/config |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Governance files and SECURITY.md disclosure guard pass | `MIX_ENV=test mix test test/install_smoke/governance_files_test.exs` | 3 tests, 0 failures | PASS |
| Package links, prohibited paths, and release verifier wiring pass | `MIX_ENV=test mix test test/install_smoke/package_metadata_test.exs` | 16 tests, 0 failures | PASS |
| Release docs parity remains green | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs` | 20 tests, 0 failures | PASS |
| Hex metadata verifier is syntactically valid shell | `bash -n scripts/verify_hex_package_metadata.sh` | exit 0 | PASS |
| Merge-blocking local CI lane remains green | `mix ci` | 3 doctests, 1223 tests, 0 failures, 4 skipped, 77 excluded | PASS |
| Code review status is clean | Read `.planning/phases/114-oss-trust-governance/114-REVIEW.md` | status clean, findings total 0 | PASS |
| Live Hex package owner-derived signal exists | Read-only public API check for `https://hex.pm/api/packages/rindle` | package `rindle`, owners `sztheory`; current public links keys `GitHub` | PASS for owner signal; link update will be enforced after next publish |

### Probe Execution

| Probe | Command | Result | Status |
|---|---|---|---|
| None discovered | `find scripts -path '*/tests/probe-*.sh' -type f` and phase artifact grep | No probe scripts or phase probe declarations | SKIPPED |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| TRUST-01 | 114-01 | SECURITY.md with vulnerability disclosure policy for untrusted uploads, MIME sniffing, signed delivery, webhook HMAC | SATISFIED, human setting remains | `SECURITY.md` content verified, no email disclosure path, advisory routing present, governance test passed. Manual GitHub Private Vulnerability Reporting setting remains. |
| TRUST-02 | 114-01 | CODE_OF_CONDUCT.md | SATISFIED | `CODE_OF_CONDUCT.md` exists as Contributor Covenant 2.1 with GitHub-routed enforcement contact. |
| TRUST-03 | 114-01 | Issue templates and PR template guide contributor intake | SATISFIED | Bug and feature issue forms, config, and PR template exist; blank issues disabled; security contact link routes to advisories; release-train-drift template preserved. |
| META-01 | 114-02 | Hex package.links exposes Changelog and Docs alongside GitHub | SATISFIED | `mix.exs` three-entry links map and package metadata smoke test verify generated metadata. Governance files were not added to `files:`. |
| META-02 | 114-02 | Hex.pm owner/maintainer signal for `sztheory` verified from public Hex API during release public verification | SATISFIED | `scripts/verify_hex_package_metadata.sh` checks `owners[]`; release workflow runs it after publish; package metadata test asserts script/workflow wiring; live package API currently reports owner `sztheory`. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| `test/install_smoke/package_metadata_test.exs` | 270 | `dryrun-placeholder` literal | INFO | Expected test assertion for CI dry-run secret placeholder, not a product stub. |
| `scripts/verify_hex_package_metadata.sh` | 18-19 | `mktemp ... XXXXXX` templates | INFO | Expected safe temporary-file templates, not placeholders. |
| `.github/workflows/release.yml` | 415 | `dryrun-placeholder` guard | INFO | Expected release safety guard rejecting placeholder Hex API key. |

No `TBD`, `FIXME`, or `XXX` markers were found in phase files. No blocker anti-patterns were found.

### Human Verification Required

#### 1. GitHub Private Vulnerability Reporting Setting

**Test:** In the GitHub repository settings, enable Private Vulnerability Reporting under Settings -> Code security -> Private vulnerability reporting, then open the repository Security tab.

**Expected:** The Security tab shows the private Report a vulnerability path, routing reporters into GitHub Security Advisories rather than public issues or email.

**Why human:** This is an external GitHub repository setting. The codebase verifies the policy file and issue-template contact link, but cannot prove the GitHub-hosted button renders.

### Gaps Summary

No codebase gaps found. All in-repo governance, package metadata, release workflow, tests, and runbook requirements are verified. Overall status is `human_needed` only because the GitHub Private Vulnerability Reporting setting must be enabled and confirmed outside the repository.

---

_Verified: 2026-06-30T15:26:28Z_
_Verifier: the agent (gsd-verifier)_
