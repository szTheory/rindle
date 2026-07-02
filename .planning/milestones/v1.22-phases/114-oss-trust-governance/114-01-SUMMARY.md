---
phase: 114-oss-trust-governance
plan: 01
subsystem: governance
tags: [security-policy, code-of-conduct, github-issue-forms, contributor-intake, install-smoke]

requires:
  - phase: 113-evaluation-baseline-release-hygiene
    provides: v1.22 trust-hardening context and release-train hygiene baseline
provides:
  - GitHub-routed vulnerability disclosure policy with no email disclosure path
  - Contributor Covenant 2.1 code of conduct with GitHub-routed enforcement contact
  - Structured GitHub issue forms, disabled blank issues, security contact link, and PR template
  - Install-smoke governance presence test covering TRUST-01/02/03
affects: [phase-114, github-community-health, contributor-intake, security-disclosure]

tech-stack:
  added: []
  patterns:
    - "Repo-only governance files stay outside the Hex package file list"
    - "GitHub Private Vulnerability Reporting is the locked security disclosure channel"
    - "GitHub issue forms coexist with the existing release-train-drift markdown template"

key-files:
  created:
    - SECURITY.md
    - CODE_OF_CONDUCT.md
    - .github/ISSUE_TEMPLATE/bug_report.yml
    - .github/ISSUE_TEMPLATE/feature_proposal.yml
    - .github/ISSUE_TEMPLATE/config.yml
    - .github/PULL_REQUEST_TEMPLATE.md
    - test/install_smoke/governance_files_test.exs
  modified: []

key-decisions:
  - "Kept governance artifacts repo-only and did not touch mix.exs or package metadata scope."
  - "Used GitHub Security Advisories / Private Vulnerability Reporting as the only vulnerability disclosure route."
  - "Preserved .github/ISSUE_TEMPLATE/release-train-drift.md byte-identically while adding issue forms beside it."

patterns-established:
  - "Governance smoke tests assert repo-facing community health files without adding them to Hex package required paths."
  - "SECURITY.md should describe Rindle's real upload, MIME, signed-delivery, webhook, and subprocess threat surfaces."

requirements-completed: [TRUST-01, TRUST-02, TRUST-03]

duration: 4 min
completed: 2026-06-30
status: complete
---

# Phase 114 Plan 01: OSS Trust Governance Summary

**GitHub-routed OSS governance intake with security policy, Contributor Covenant, structured issue forms, PR template, and install-smoke coverage**

## Performance

- **Duration:** 4 min
- **Started:** 2026-06-30T14:43:52Z
- **Completed:** 2026-06-30T14:48:35Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Added `SECURITY.md` with a Supported Versions table, GitHub Security Advisories reporting path, Private Vulnerability Reporting operational note, and Rindle-specific threat-surface guidance.
- Added `CODE_OF_CONDUCT.md` using Contributor Covenant 2.1 with GitHub-routed enforcement contact text.
- Added GitHub issue forms, issue-template config, and PR template while preserving the existing release-train drift issue template.
- Added `test/install_smoke/governance_files_test.exs`, which locks the governance files, release-train template preservation, and no-email security policy route.

## Task Commits

Each task was committed atomically:

1. **Task 1: Wave 0 governance-presence meta-test** - `dd76be3` (test)
2. **Task 2: SECURITY.md + CODE_OF_CONDUCT.md** - `a2564db` (docs)
3. **Task 3: Issue forms + config.yml + PR template** - `a96c140` (docs)

## Files Created/Modified

- `SECURITY.md` - Security policy with latest-0.x support policy and advisory-only vulnerability reporting.
- `CODE_OF_CONDUCT.md` - Contributor Covenant 2.1 with GitHub-routed enforcement contact.
- `.github/ISSUE_TEMPLATE/bug_report.yml` - Structured bug report issue form.
- `.github/ISSUE_TEMPLATE/feature_proposal.yml` - Structured feature proposal issue form.
- `.github/ISSUE_TEMPLATE/config.yml` - Disables blank issues and routes security reports to GitHub advisories.
- `.github/PULL_REQUEST_TEMPLATE.md` - PR body template with summary, linked issue, and CI/docs checklist.
- `test/install_smoke/governance_files_test.exs` - ExUnit smoke coverage for governance file presence, preserved release-train drift template, and SECURITY.md disclosure constraints.

## Verification

- `mix test test/install_smoke/governance_files_test.exs` - PASS, 3 tests all passing.
- `mix ci` - PASS, 1222 tests and 3 doctests all passing, 4 skipped.
- `shasum -a 256 .github/ISSUE_TEMPLATE/release-train-drift.md` - unchanged at `744d52c47e569642413c728a636ae3fdd062ae1951dab7999cd27f9b054df028`.
- `SECURITY.md` advisory/no-email check - PASS.

## Decisions Made

- Kept governance artifacts repo-only; no `mix.exs` package `files:` changes were made.
- Used GitHub Security Advisories / Private Vulnerability Reporting as the only vulnerability disclosure path.
- Added GitHub issue forms beside the existing `release-train-drift.md` template rather than converting or moving the maintainer template.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None blocking. `mix ci` emitted an expired Hex auth-session notice and existing dependency advisory output while still exiting successfully; no out-of-scope dependency changes were made.

## User Setup Required

External repository settings require manual configuration:

- Enable Private Vulnerability Reporting in GitHub: repository Settings -> Code security -> Private vulnerability reporting -> Enable.

## Next Phase Readiness

Ready for `114-02-PLAN.md`. This plan intentionally did not touch `mix.exs` or `test/install_smoke/package_metadata_test.exs`; those remain scoped to the Hex metadata plan.

## Self-Check: PASSED

- Created files exist on disk: PASS.
- Task commits exist in git history: `dd76be3`, `a2564db`, `a96c140`.
- Plan verification commands passed: targeted governance smoke test and `mix ci`.

---
*Phase: 114-oss-trust-governance*
*Completed: 2026-06-30*
