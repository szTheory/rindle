---
phase: 12-public-verification-and-release-operations
verified: 2026-04-28T22:14:51Z
status: gaps_found
score: 7/9 must-haves verified
overrides_applied: 0
gaps:
  - truth: "Maintainers have clear first-publish, future-release, and rollback/revert instructions tied to the actual shipped workflow"
    status: partial
    reason: "The runbook documents first-publish steps and rollback/revert details, but it does not yet describe a repeatable routine release flow for subsequent versions."
    artifacts:
      - path: "guides/release_publish.md"
        issue: "The guide is scoped to the first public release (`0.1.0`) and post-publish follow-up; it lacks explicit ongoing release instructions beyond bumping back to the next `-dev` version."
    missing:
      - "Add a clear routine-release procedure for releases after `0.1.0`."
      - "Tie that routine flow to the shipped workflow and maintainer commands already used for publish/preflight."
---

# Phase 12: Public Verification and Release Operations Verification Report

**Phase Goal:** Rindle's first public release is proved from the outside in and the maintainer runbook is strong enough to make future releases routine
**Verified:** 2026-04-28T22:14:51Z
**Status:** gaps_found
**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A fresh consumer path can resolve the published Rindle version from Hex.pm and complete the canonical install flow | ? UNCERTAIN | `scripts/public_smoke.sh` exports `RINDLE_INSTALL_SMOKE_NETWORK_VERSION` and runs the generated-app smoke test; `GeneratedAppHelper.prove_package_install!/0` switches to `{:rindle, "~> #{network_version}"}`, retries `mix deps.get`, compiles, migrates, boots, and runs the lifecycle smoke test at [scripts/public_smoke.sh](/Users/jon/projects/rindle/scripts/public_smoke.sh:7), [generated_app_helper.ex](/Users/jon/projects/rindle/test/install_smoke/support/generated_app_helper.ex:13), and [generated_app_helper.ex](/Users/jon/projects/rindle/test/install_smoke/support/generated_app_helper.ex:49). A live published Hex.pm artifact was not available to exercise during this verification pass. |
| 2 | Maintainers have clear first-publish, future-release, and rollback/revert instructions tied to the actual shipped workflow | ✗ FAILED | The runbook covers first-publish setup, preflight, and rollback/revert, but it remains first-release-specific (`0.1.0`) and does not spell out a routine subsequent-release flow at [release_publish.md](/Users/jon/projects/rindle/guides/release_publish.md:10), [release_publish.md](/Users/jon/projects/rindle/guides/release_publish.md:35), [release_publish.md](/Users/jon/projects/rindle/guides/release_publish.md:89), and [release_publish.md](/Users/jon/projects/rindle/guides/release_publish.md:99). |
| 3 | The public release path no longer depends on repo-local package shortcuts for confidence | ✓ VERIFIED | Network mode replaces the local `path:` dependency with a version requirement and skips unpacking the local package; the smoke assertions also reject `deps/rindle` fallback at [generated_app_helper.ex](/Users/jon/projects/rindle/test/install_smoke/support/generated_app_helper.ex:28), [generated_app_helper.ex](/Users/jon/projects/rindle/test/install_smoke/support/generated_app_helper.ex:133), and [generated_app_smoke_test.exs](/Users/jon/projects/rindle/test/install_smoke/generated_app_smoke_test.exs:25). |
| 4 | Consumer verification fetches Rindle from public Hex.pm registry via standard network resolution | ✓ VERIFIED | Network mode is keyed off `RINDLE_INSTALL_SMOKE_NETWORK_VERSION`; when present it injects `{:rindle, "~> #{network_version}"}` into the generated app and runs `mix deps.get` instead of `mix hex.build --unpack` at [public_smoke.sh](/Users/jon/projects/rindle/scripts/public_smoke.sh:11), [generated_app_helper.ex](/Users/jon/projects/rindle/test/install_smoke/support/generated_app_helper.ex:14), and [generated_app_helper.ex](/Users/jon/projects/rindle/test/install_smoke/support/generated_app_helper.ex:133). |
| 5 | Verification handles Hex.pm indexing delay by polling | ✓ VERIFIED | `GeneratedAppHelper.prove_package_install!/0` retries `mix deps.get` up to 30 times with 10-second sleeps before failing at [generated_app_helper.ex](/Users/jon/projects/rindle/test/install_smoke/support/generated_app_helper.ex:35). |
| 6 | Verification runs in a pristine environment without `HEX_API_KEY` | ✓ VERIFIED | The release workflow runs the public verification step with `HEX_API_KEY: ""` immediately after publish at [release.yml](/Users/jon/projects/rindle/.github/workflows/release.yml:118). |
| 7 | Maintainer runbook contains manual rollback procedures | ✓ VERIFIED | The guide explicitly states rollback/revert is manual and documents `mix hex.revert rindle VERSION` at [release_publish.md](/Users/jon/projects/rindle/guides/release_publish.md:99). |
| 8 | Runbook specifies 1-hour revert window | ✓ VERIFIED | The rollback section states a 1-hour revert window at [release_publish.md](/Users/jon/projects/rindle/guides/release_publish.md:109). |
| 9 | Runbook specifies 24-hour revert window for first release | ✓ VERIFIED | The rollback section states a 24-hour window for the first `0.1.0` release at [release_publish.md](/Users/jon/projects/rindle/guides/release_publish.md:111). |

**Score:** 7/9 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `scripts/public_smoke.sh` | Public artifact smoke test runner | ✓ VERIFIED | Exists, is executable (`755`), derives the project version with `mix run`, exports `RINDLE_INSTALL_SMOKE_NETWORK_VERSION`, and runs the generated-app smoke test at [public_smoke.sh](/Users/jon/projects/rindle/scripts/public_smoke.sh:1). |
| `test/install_smoke/support/generated_app_helper.ex` | Network-aware package generation helper | ✓ VERIFIED | Exists, is substantive, toggles local-vs-network install mode, performs bounded polling, and drives compile/migrate/boot/smoke execution at [generated_app_helper.ex](/Users/jon/projects/rindle/test/install_smoke/support/generated_app_helper.ex:13). |
| `guides/release_publish.md` | Release operations documentation | ⚠️ PARTIAL | Exists and is substantive, but it does not fully satisfy the roadmap/requirement expectation for future routine release guidance at [release_publish.md](/Users/jon/projects/rindle/guides/release_publish.md:1). |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `scripts/public_smoke.sh` | `test/install_smoke/support/generated_app_helper.ex` | `RINDLE_INSTALL_SMOKE_NETWORK_VERSION` environment variable | ✓ WIRED | Indirect chain verified: the script exports the env var, `generated_app_smoke_test.exs` invokes `GeneratedAppHelper.prove_package_install!/0`, and the helper reads that env var to enable network mode at [public_smoke.sh](/Users/jon/projects/rindle/scripts/public_smoke.sh:11), [generated_app_smoke_test.exs](/Users/jon/projects/rindle/test/install_smoke/generated_app_smoke_test.exs:10), and [generated_app_helper.ex](/Users/jon/projects/rindle/test/install_smoke/support/generated_app_helper.ex:14). |
| `.github/workflows/release.yml` | `scripts/public_smoke.sh` | `Verify public Hex.pm artifact` release step | ✓ WIRED | The workflow executes the script immediately after `mix hex.publish --yes` and clears `HEX_API_KEY` for that step at [release.yml](/Users/jon/projects/rindle/.github/workflows/release.yml:108). |
| `guides/release_publish.md` | shipped release docs path | package metadata review checklist | ✓ WIRED | The runbook explicitly requires the packaged docs to include `guides/release_publish.md`, tying the guide to shipped artifacts at [release_publish.md](/Users/jon/projects/rindle/guides/release_publish.md:54). |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `scripts/public_smoke.sh` | `VERSION` | `Mix.Project.config()[:version]` via `mix run --no-start` | Yes - command returned `0.1.0-dev` during verification | ✓ FLOWING |
| `test/install_smoke/support/generated_app_helper.ex` | `network_version` | `System.get_env("RINDLE_INSTALL_SMOKE_NETWORK_VERSION")` | Yes - drives the install mode branch, dependency injection string, and retry loop | ✓ FLOWING |
| `test/install_smoke/support/generated_app_helper.ex` | `migration_report` / `smoke_result` | Generated app migration runner JSON and smoke test output | Yes - report fields back the outer test assertions for migration path and lifecycle proof | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Public smoke script is syntactically valid | `bash -n scripts/public_smoke.sh` | exit 0 | ✓ PASS |
| Public smoke script is executable | `[ -x scripts/public_smoke.sh ]` | true | ✓ PASS |
| Script can resolve the current package version | `mix run --no-start -e 'IO.write(Mix.Project.config()[:version])'` | `0.1.0-dev` | ✓ PASS |
| Release workflow includes credential-free public verification step | `grep -n "Verify public Hex.pm artifact\\|HEX_API_KEY: \\\"\\\"\\|run: bash scripts/public_smoke.sh" .github/workflows/release.yml` | matched lines 118, 120, 121 | ✓ PASS |
| Freshly published Hex.pm artifact can be resolved live | `bash scripts/public_smoke.sh` after a real publish | not run in this verification pass | ? SKIP |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| `RELEASE-08` | `12-01-PLAN.md` | Maintainer can verify a freshly published Rindle version by resolving it from `Hex.pm` in a fresh consumer flow instead of only from a local package path | ? NEEDS HUMAN | The codebase now supports and wires a network-mode smoke flow through release CI, but this pass did not execute against an actually published Hex.pm version. Evidence at [release.yml](/Users/jon/projects/rindle/.github/workflows/release.yml:118), [public_smoke.sh](/Users/jon/projects/rindle/scripts/public_smoke.sh:7), and [generated_app_helper.ex](/Users/jon/projects/rindle/test/install_smoke/support/generated_app_helper.ex:35). |
| `RELEASE-09` | `12-02-PLAN.md` | Maintainer-facing docs describe the first-publish flow, future routine release flow, and the immediate rollback/revert path for a bad release | ✗ BLOCKED | First-publish and rollback/revert content exists, but a routine post-`0.1.0` release path is not explicitly documented in [release_publish.md](/Users/jon/projects/rindle/guides/release_publish.md:10). |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| None | - | No blocking stub markers, placeholder handlers, or empty-return implementations found in the phase files scanned from the summaries | - | No blocker from anti-pattern scan |

### Human Verification Required

### 1. Live Hex Consumer Proof

**Test:** Trigger the real release workflow after a publish, or run `bash scripts/public_smoke.sh` against an already-published version with Postgres and MinIO available.
**Expected:** The generated consumer app resolves `rindle` from Hex.pm, `mix deps.get` succeeds within the retry window, compile/boot succeed, and the lifecycle smoke test passes without any repo-local fallback.
**Why human:** This depends on a real published Hex.pm artifact, registry indexing timing, and external services that are not reproducible from static code inspection alone.

### Gaps Summary

Phase 12 is only partially achieved. The public-verification implementation is present and wired end to end through the release workflow, and the rollback/revert documentation required by Plan 12-02 is present with the correct timing constraints. The remaining blocker is broader roadmap/requirement coverage: `guides/release_publish.md` is still written as a first-release runbook and does not yet document a clear routine future release flow after `0.1.0`.

Once that documentation gap is closed, one live external verification is still needed to prove `RELEASE-08` against an actual published Hex.pm version.

---

_Verified: 2026-04-28T22:14:51Z_  
_Verifier: Claude (gsd-verifier)_
