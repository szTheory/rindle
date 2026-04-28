---
phase: 10-publish-readiness
verified: 2026-04-28T20:05:32Z
status: verified
score: 6/6 must-haves verified
overrides_applied: 0
automation_replaced_human_uat: true
---

# Phase 10: Publish Readiness Verification Report

**Phase Goal:** the repo is explicitly ready for a first public `Hex.pm` publish, and maintainers can inspect exactly what will ship before any live upload happens
**Verified:** 2026-04-28T20:05:32Z
**Status:** verified
**Re-verification:** Yes — manual-UAT-only gaps replaced with executable automation

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Package metadata, publish ownership expectations, and release versioning are documented explicitly instead of being implicit maintainer memory. | ✓ VERIFIED | [guides/release_publish.md](/Users/jon/projects/rindle/guides/release_publish.md:3) documents the `0.1.0` sequence, auth check, owner model, and post-publish follow-up at lines 3-97. |
| 2 | Maintainers have an explicit package-metadata review checklist before any live publish wiring exists. | ✓ VERIFIED | [guides/release_publish.md](/Users/jon/projects/rindle/guides/release_publish.md:54) requires `mix hex.build --unpack`, `hex_metadata.config`, package name, version, `MIT`, GitHub links, and `guides/release_publish.md` review. |
| 3 | The release guide is included in generated docs and linked from maintainer-facing docs without contaminating adopter onboarding docs. | ✓ VERIFIED | [mix.exs](/Users/jon/projects/rindle/mix.exs:100) includes `"guides/release_publish.md"` in `docs().extras`; [guides/operations.md](/Users/jon/projects/rindle/guides/operations.md:140) cross-links it; [test/install_smoke/release_docs_parity_test.exs](/Users/jon/projects/rindle/test/install_smoke/release_docs_parity_test.exs:44) refutes `HEX_API_KEY`, `mix hex.user`, and `mix hex.owner` in README/getting started; [scripts/assert_release_docs_html.sh](/Users/jon/projects/rindle/scripts/assert_release_docs_html.sh:1) asserts the generated HTML/sidebar wiring and adopter-doc boundary after `mix docs`; both probes passed. |
| 4 | The repo has an executable docs gate that fails when maintainer release guidance drifts away from the first-publish contract. | ✓ VERIFIED | [test/install_smoke/release_docs_parity_test.exs](/Users/jon/projects/rindle/test/install_smoke/release_docs_parity_test.exs:21) asserts the versioning, owner/auth, and metadata-review contract directly from source docs; targeted test passed. |
| 5 | Maintainers can run one preflight path that proves the shipped tarball metadata/files, package-consumer smoke path, and generated docs health before live publish is wired. | ✓ VERIFIED | [scripts/release_preflight.sh](/Users/jon/projects/rindle/scripts/release_preflight.sh:1) now pins `MIX_ENV` per stage and runs package build, metadata gate, release-doc gate, generated-app smoke, docs build, and generated-doc HTML assertions in order; [test/install_smoke/package_metadata_test.exs](/Users/jon/projects/rindle/test/install_smoke/package_metadata_test.exs:54) verifies that ordering; the full command passed locally against Postgres and MinIO on 2026-04-28. |
| 6 | The release workflow and normal PR CI both enforce the shared preflight without broadening publish credentials to a live Hex publish secret. | ✓ VERIFIED | [.github/workflows/release.yml](/Users/jon/projects/rindle/.github/workflows/release.yml:109) invokes `bash scripts/release_preflight.sh`; [.github/workflows/ci.yml](/Users/jon/projects/rindle/.github/workflows/ci.yml:242) now runs the same preflight in the service-backed package-consumer lane before merge; lines 98-107 in `release.yml` still use a dry-run placeholder instead of a real secret; line 122 keeps `mix hex.publish package --dry-run --yes`. |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `mix.exs` | ExDoc extras wiring for release guide | ✓ VERIFIED | Exists, substantive, and wired via `docs().extras` at [mix.exs](/Users/jon/projects/rindle/mix.exs:96). |
| `guides/release_publish.md` | First-publish maintainer runbook | ✓ VERIFIED | Exists, substantive, and linked from docs/tests; see [guides/release_publish.md](/Users/jon/projects/rindle/guides/release_publish.md:1). |
| `guides/operations.md` | Maintainer-facing cross-link to runbook | ✓ VERIFIED | Exists, substantive, and cross-links the release guide at [guides/operations.md](/Users/jon/projects/rindle/guides/operations.md:140). |
| `test/install_smoke/release_docs_parity_test.exs` | Release-doc parity gate | ✓ VERIFIED | Exists, substantive assertions, and runnable; passed under `mix test`. |
| `test/install_smoke/package_metadata_test.exs` | Tarball metadata/content assertions | ✓ VERIFIED | Exists, builds a fresh artifact, inspects `hex_metadata.config`, and verifies preflight ordering at [test/install_smoke/package_metadata_test.exs](/Users/jon/projects/rindle/test/install_smoke/package_metadata_test.exs:15). |
| `scripts/release_preflight.sh` | Single preflight command | ✓ VERIFIED | Exists, substantive, and invoked by workflow at [scripts/release_preflight.sh](/Users/jon/projects/rindle/scripts/release_preflight.sh:10). |
| `scripts/assert_release_docs_html.sh` | Generated HexDocs navigation and adopter-boundary assertion | ✓ VERIFIED | Exists, substantive, and fails if `Release Publishing` disappears from generated docs or maintainer Hex owner/auth strings leak into generated adopter docs. |
| `.github/workflows/ci.yml` | Shift-left service-backed preflight in PR CI | ✓ VERIFIED | Exists, substantive, and runs `bash scripts/release_preflight.sh` in the package-consumer lane before merge. |
| `.github/workflows/release.yml` | Workflow wiring for shared preflight | ✓ VERIFIED | Exists, substantive, and runs the shared preflight before optional dry-run publish at [.github/workflows/release.yml](/Users/jon/projects/rindle/.github/workflows/release.yml:109). |
| `lib/rindle/live_view.ex` | Warning-clean docs wording | ✓ VERIFIED | Exists, substantive, and `mix docs --warnings-as-errors` now succeeds. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `guides/release_publish.md` | `mix.exs` | Maintainer checklist step that compares source package metadata with unpacked shipped metadata | ✓ WIRED | Checklist requires `mix hex.build --unpack` and `hex_metadata.config` comparison at [guides/release_publish.md](/Users/jon/projects/rindle/guides/release_publish.md:54). |
| `mix.exs` | `guides/release_publish.md` | `docs().extras` | ✓ WIRED | `"guides/release_publish.md"` present in [mix.exs](/Users/jon/projects/rindle/mix.exs:100). |
| `guides/operations.md` | `guides/release_publish.md` | Maintainer cross-link | ✓ WIRED | Cross-link present at [guides/operations.md](/Users/jon/projects/rindle/guides/operations.md:142). |
| `test/install_smoke/release_docs_parity_test.exs` | `guides/release_publish.md` | Markdown content assertions | ✓ WIRED | Assertions read the guide directly at [test/install_smoke/release_docs_parity_test.exs](/Users/jon/projects/rindle/test/install_smoke/release_docs_parity_test.exs:10). |
| `scripts/release_preflight.sh` | `test/install_smoke/package_metadata_test.exs` | Preflight metadata gate | ✓ WIRED | Script invokes the metadata test at [scripts/release_preflight.sh](/Users/jon/projects/rindle/scripts/release_preflight.sh:14). |
| `scripts/release_preflight.sh` | `mix docs --warnings-as-errors` | Explicit docs gate | ✓ WIRED | Script invokes docs gate at [scripts/release_preflight.sh](/Users/jon/projects/rindle/scripts/release_preflight.sh:17). |
| `scripts/release_preflight.sh` | `scripts/assert_release_docs_html.sh` | Generated-doc navigation and boundary gate | ✓ WIRED | Script invokes the HTML assertion at [scripts/release_preflight.sh](/Users/jon/projects/rindle/scripts/release_preflight.sh:18). |
| `.github/workflows/ci.yml` | `scripts/release_preflight.sh` | Shift-left PR preflight invocation | ✓ WIRED | CI invokes it in the package-consumer lane at [.github/workflows/ci.yml](/Users/jon/projects/rindle/.github/workflows/ci.yml:330). |
| `.github/workflows/release.yml` | `scripts/release_preflight.sh` | Shared release preflight invocation | ✓ WIRED | Workflow invokes it at [.github/workflows/release.yml](/Users/jon/projects/rindle/.github/workflows/release.yml:112). |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `test/install_smoke/release_docs_parity_test.exs` | `release_guide`, `operations`, `readme`, `getting_started` | `File.read!` of repo docs in `setup_all` | Yes — assertions evaluate actual source docs, not fixtures | ✓ FLOWING |
| `test/install_smoke/package_metadata_test.exs` | `metadata`, `package_root` | Fresh `mix hex.build --unpack --output ...` plus `File.read!(hex_metadata.config)` | Yes — assertions inspect newly built package output and file presence | ✓ FLOWING |
| `scripts/release_preflight.sh` | `PACKAGE_ROOT` | `mix run --no-start` derives current app/version before `mix hex.build --unpack` | Yes — preflight points at current package artifact path | ✓ FLOWING |
| `scripts/assert_release_docs_html.sh` | `RELEASE_DOC`, `SIDEBAR_FILE`, adopter HTML docs | Generated `doc/*.html` and `doc/dist/sidebar_items-*.js` | Yes — assertions inspect built HexDocs output, not source markdown only | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Release-doc contract gate passes | `mix test test/install_smoke/release_docs_parity_test.exs` | `4 tests, 0 failures` | ✓ PASS |
| Package metadata/tarball gate passes | `mix test test/install_smoke/package_metadata_test.exs` | `4 tests, 0 failures` | ✓ PASS |
| Docs build plus generated HTML assertions pass | `mix docs --warnings-as-errors && bash scripts/assert_release_docs_html.sh` | Docs generated successfully and HTML assertions returned 0 | ✓ PASS |
| Full shared preflight completes end-to-end | `bash scripts/release_preflight.sh` with local Postgres/MinIO env contract | Package build, both ExUnit gates, generated-app MinIO smoke, docs build, and HTML assertions all passed | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| `RELEASE-04` | `10-01-PLAN.md` | Maintainer can prepare first public `Hex.pm` publish with explicit package metadata, owner/auth setup, and documented versioning/release checklist | ✓ SATISFIED | [guides/release_publish.md](/Users/jon/projects/rindle/guides/release_publish.md:8), [guides/operations.md](/Users/jon/projects/rindle/guides/operations.md:140), [mix.exs](/Users/jon/projects/rindle/mix.exs:100), and [test/install_smoke/release_docs_parity_test.exs](/Users/jon/projects/rindle/test/install_smoke/release_docs_parity_test.exs:21). |
| `RELEASE-05` | `10-02-PLAN.md` | Maintainer can inspect the exact package tarball and docs build output before any live publish occurs | ✓ SATISFIED | [test/install_smoke/package_metadata_test.exs](/Users/jon/projects/rindle/test/install_smoke/package_metadata_test.exs:31), [scripts/release_preflight.sh](/Users/jon/projects/rindle/scripts/release_preflight.sh:10), [.github/workflows/release.yml](/Users/jon/projects/rindle/.github/workflows/release.yml:109), and successful `mix docs --warnings-as-errors`. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| None | - | No blocker stub patterns, placeholder implementations, or orphaned Phase 10 artifacts found in verified files. | - | No automated blockers identified. |

### Automation Replaced Manual UAT

The two remaining manual checks are now executable:

1. The same shared `scripts/release_preflight.sh` path runs in both PR CI and the protected release workflow, so service-backed package build plus generated-app smoke no longer depend on a one-off manual trigger.
2. Generated HexDocs navigation and adopter-doc contamination are now asserted by [scripts/assert_release_docs_html.sh](/Users/jon/projects/rindle/scripts/assert_release_docs_html.sh:1) against built HTML, not left to visual inspection.

### Gaps Summary

No code, wiring, or remaining human-UAT gaps were found for the Phase 10 must-haves. Automated evidence now covers the previously manual release-lane and generated-doc checks.

---

_Verified: 2026-04-28T20:05:32Z_
_Verifier: Claude (gsd-verifier)_
