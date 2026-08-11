---
phase: 120-adoption-proof-release-truth
verified: 2026-08-10T21:35:38Z
status: gaps_found
score: 0/4 must-haves verified
behavior_unverified: 2
overrides_applied: 0
gaps:
  - truth: "Automated proof covers fresh installs, explicit public compatibility, populated public-to-rindle upgrades, runtime routing, and the untouched public Oban boundary."
    status: failed
    reason: "The populated-upgrade report accepts lost migration-marker contents, foreign-key constraints, required indexes, and changes to public.oban_jobs; the authoritative compatibility/upgrade image gates have not completed."
    artifacts:
      - path: "test/install_smoke/support/generated_app_helper.ex"
        issue: "seeded_marker? checks only table existence; foreign_key_preserved? checks a join; index_preserved? accepts any index; rindle_created_oban_jobs is forced false after the host Oban migration."
      - path: "test/install_smoke/generated_app_smoke_test.exs"
        issue: "Repository assertions accept the non-proving report booleans as release evidence."
    missing:
      - "Catalog assertions for the V1 marker value, required FK and named indexes."
      - "An Oban catalog snapshot before and after the Rindle migration, asserted unchanged."
      - "A completed packed image run for explicit-public compatibility and populated upgrade."
  - truth: "README, getting-started, migration API docs, docs-parity tests, and the 0.4.0 release notes agree on the breaking default, escape hatch, order of operations, permissions, downtime, and Oban ownership."
    status: failed
    reason: "All public-compatibility snippets teach a down migration without prefix: public, which defaults to rindle and cannot roll back the public installation it created. Docs parity locks this unsafe fixture rather than detecting it."
    artifacts:
      - path: "test/install_smoke/support/generated_app_helper.ex"
        issue: "rindle_migration_source(\"public\") emits Rindle.Migration.down(version: 1)."
      - path: "README.md"
        issue: "InstallPublicRindle uses the same incorrect unprefixed down call."
      - path: "guides/getting_started.md"
        issue: "InstallPublicRindle uses the same incorrect unprefixed down call."
      - path: "lib/rindle/migration.ex"
        issue: "The public API moduledoc uses the same incorrect unprefixed down call."
    missing:
      - "Use Rindle.Migration.down(version: 1, prefix: \"public\") for the explicit-public path and assert both up and down snippets in parity tests."
behavior_unverified_items:
  - truth: "A packed-artifact generated Phoenix application and the Cohort adoption demo provision and run with Rindle in rindle and Oban in public."
    test: "Run the image-profile public-compatibility and isolation-upgrade generated-app tests, then bash scripts/ci/cohort_demo_smoke.sh, from the exact release SHA."
    expected: "Each clean consumer/demo boots, persists through its compiled route, keeps all fixed Rindle relations only in rindle where applicable, and preserves public.oban_jobs and public.schema_migrations."
    why_human: "These are package-build/Docker/Postgres integration transitions. This verification did not start external services, and 120-02 records the two image gates as interrupted/unknown."
  - truth: "Release verification demonstrates that packaged artifacts—not only the repository checkout—honor the documented isolation contract."
    test: "Inspect the exact-SHA GitHub Actions run named by guides/release_publish.md and confirm Package Consumer Proof Matrix, adoption-demo/Cohort, proof/docs parity, and packaged release gates are green."
    expected: "The release SHA, rather than a checkout-only local run, has green packaged-artifact evidence for all required proof paths."
    why_human: "Exact-SHA CI outcome is external state and is not represented by a checked-in passing artifact."
---

# Phase 120: Adoption Proof & Release Truth Verification Report

**Phase Goal:** Adopters and maintainers can verify the breaking 0.4.0 schema contract end-to-end from packaged installation through upgrade, demo operation, and documentation.
**Verified:** 2026-08-10T21:35:38Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Automated proof covers fresh install, explicit public compatibility, populated upgrade, runtime routing, and untouched public Oban. | ✗ FAILED | Upgrade proof fields in `GeneratedAppHelper` are false positives: table/join/any-index checks do not prove preservation, and `rindle_created_oban_jobs` is always false once the required host Oban migration has run. |
| 2 | Packed generated app and Cohort demo provision and run with Rindle in `rindle` and Oban in `public`. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Source wiring exists, but the two Phase 120 packed compatibility/upgrade image tests were recorded as interrupted/unknown and this verification did not launch Docker/Postgres/package builds. |
| 3 | Docs and release surfaces agree on default, escape hatch, operations, and ownership. | ✗ FAILED | README, Getting Started, API moduledoc, generated fixture, and parity test all repeat an unsafe public-compatibility rollback (`down(version: 1)`), which defaults to `rindle`. |
| 4 | Packaged artifacts—not only checkout—demonstrate the documented isolation contract. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Release guide and CI wiring name the needed gates, but their exact-SHA outcome is external and the incomplete image gates cannot establish it. |

**Score:** 0/4 truths verified (2 present, behavior-unverified)

### Plan Must-Have Coverage

| Plan | Must-have result | Evidence |
| --- | --- | --- |
| 120-01 | ⚠️ PARTIAL | Default host-migration/package/persistence wiring is substantive, but only its fast source contract was rerun; no new packed-image execution was used as verification evidence. |
| 120-02 | ✗ FAILED | Separate public/default roots and directional helper are wired, but the public rollback is wrong and the populated-upgrade/Oban predicates are non-proving. |
| 120-03 | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Checked-in Cohort migrations, aliases, contract test, and cold-start script are wired; the Docker runtime transition was not exercised. |
| 120-04 | ✗ FAILED | Docs parity connects all public surfaces to the generated fixture, but that fixture contains the wrong public rollback. |
| 120-05 | ✓ VERIFIED | Upgrade/troubleshooting parity passed and source contains the required ordered maintenance, lock, verification, guarded-reversal, and ownership language. |
| 120-06 | ⚠️ PARTIAL | Release text/parity and exact-SHA gate wiring are present, but the prescribed docs-link command failed on unrelated pre-existing references and no exact-SHA external result was available. |

## Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `test/install_smoke/support/generated_app_helper.ex` | Packed default/public/upgrade evidence | ✗ STUBBED PROOF | Substantive and invoked, but upgrade/Oban report values do not measure their asserted invariants. |
| `test/install_smoke/generated_app_smoke_test.exs` | Repository policy assertions | ⚠️ PARTIAL | Fast contracts pass but only assert the weak report keys/source fragments; image compatibility/upgrade assertions consume those false-positive values. |
| `examples/adoption_demo/priv/repo/migrations/20260809000000_install_rindle.exs` | Host-owned default Rindle migration | ✓ VERIFIED | Normal Ecto migration calls `Rindle.Migration.up(version: 1)` separately from `AddOban`. |
| `examples/adoption_demo/test/rindle_migration_contract_test.exs` | Demo ownership/persistence contract | ✓ VERIFIED (source/test) | Checks fixed relations, public Oban/ledger, and a facade write/read; runtime Docker proof remains human verification. |
| `examples/adoption_demo/mix.exs` / `scripts/ci/cohort_demo_smoke.sh` | Normal migration and cold-start proof | ✓ VERIFIED (wiring) | `ecto.setup`/test use `ecto.migrate`; shell script checks seven relations and public host tables. |
| `README.md`, `guides/getting_started.md`, `lib/rindle/migration.ex` | Fresh-install migration contract | ✗ FAILED | Explicit-public `down/1` omits the required public prefix. |
| `guides/upgrading.md`, `guides/troubleshooting.md` | Honest populated-upgrade guidance | ✓ VERIFIED | Targeted docs parity passed and the guide specifies backup/quiescence, timeout, deploy, doctor/runtime status, guarded reversal/restore. |
| `CHANGELOG.md`, `guides/release_publish.md`, `test/install_smoke/release_docs_parity_test.exs` | Staged release truth and signoff | ✓ VERIFIED (source/parity) | Targeted release parity passed; actual exact-SHA CI remains unverified. |

## Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Generated smoke test | `GeneratedAppHelper` | `prove_package_install!(:image)` report | ✓ WIRED | Setup/report call is present. |
| Generated host migrations | `Rindle.Migration` / `Oban.Migration` | Separate host files | ⚠️ PARTIAL | `up` calls are separate and wired; public `down` targets the wrong schema. |
| Populated-upgrade host migration | `move_public_to_rindle(version: 1)` | lock timeout then pinned helper | ✓ WIRED | Generated source contains `SET LOCAL lock_timeout = '5s'` followed by the version-pinned call. |
| Cohort aliases/CI | Host migrations | `ecto.migrate` / adoption-demo-unit | ✓ WIRED | `examples/adoption_demo/mix.exs` and `.github/workflows/ci.yml` use normal migration flow. |
| Docs parity | Generated migration fixtures | Extracted source snippets | ✗ FAILED | Wiring is active but locks the unsafe public rollback into all docs. |
| Release guide | CI and upgrading guide | Live job names / deep link | ✓ WIRED | `Package Consumer Proof Matrix` and upgrading deep link are present. |

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Generated default report | `persistence_lifecycle` | Generated app lifecycle JSON | Real generated-app output when image gate runs | ⚠️ Not re-executed here |
| Generated upgrade report | `seeded_marker`, FK/index, Oban ownership | PostgreSQL queries in generated migration runner | No — predicates can pass after the claimed invariant is lost | ✗ HOLLOW |
| Cohort smoke | schema table checks | Docker Compose PostgreSQL queries | Script queries real catalog, but was not executed here | ⚠️ Not re-executed here |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Fast default report contract | `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_fast_contract --seed 0` | 4 tests, 0 failures | ✓ PASS (shape only) |
| Fast public topology contract | `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_compat_contract --seed 0` | 1 test, 0 failures | ✓ PASS (does not exercise rollback) |
| Fast populated-upgrade contract | `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_upgrade_contract --seed 0` | 1 test, 0 failures | ✓ PASS (does not validate constraints/indexes/marker contents) |
| Documentation/release parity | `mix test test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs --seed 0` | 56 tests, 0 failures | ✓ PASS (parity preserves the same bad public down call) |
| Docs link checker | `bash scripts/maintainer/check_docs_links.sh` | Failed with 45 existing planning-artifact references outside Phase 120 | ℹ️ BASELINE FAILURE |
| Cohort script syntax | `bash -n scripts/ci/cohort_demo_smoke.sh` | Exit 0 | ✓ PASS |

## Probe Execution

No Phase 120 probe scripts were declared or found. The relevant package and Cohort checks are integration gates, not conventional `probe-*.sh` files.

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| PROOF-01 | 120-01, 120-02, 120-06 | Automated default/public/upgrade/runtime/Oban proof | ✗ BLOCKED | Upgrade integrity and Oban-ownership assertions are non-proving; image upgrade/public integrations remain unrun. |
| PROOF-02 | 120-01, 120-03, 120-06 | Packed generated app and Cohort demo end-to-end | ? NEEDS HUMAN | Source and CI wiring exist, but clean packaged/Docker execution was not verified and Phase 120 summary records interrupted package paths. |
| DOCS-01 | 120-04, 120-05, 120-06 | Contract-consistent adopter/API/upgrade/release docs | ✗ BLOCKED | Public compatibility rollback guidance is demonstrably wrong across all named migration surfaces. |

No orphaned Phase 120 requirements were found. No later milestone phase exists to defer these gaps to.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `test/install_smoke/support/generated_app_helper.ex` | 1249 | Public install with default-schema rollback | 🛑 BLOCKER | Leaves public installation intact or drops unrelated default Rindle schema. |
| `test/install_smoke/support/generated_app_helper.ex` | 1319-1330 | Existence/join/any-index reported as preservation | 🛑 BLOCKER | Upgrade proof passes after loss of integrity guarantees. |
| `test/install_smoke/support/generated_app_helper.ex` | 1338 | Logically forced false Oban-ownership flag | 🛑 BLOCKER | Cannot detect Rindle creating or modifying `public.oban_jobs`. |
| `test/install_smoke/docs_parity_test.exs` | 204-290 | Parity compares unsafe fixture into public docs | 🛑 BLOCKER | Tests make incorrect release documentation look verified. |

## Gaps Summary

Phase 120 is not achieved. The existing evidence harness has a valid structure—host migrations, package roots, separate compile-time consumers, Cohort wiring, documentation surfaces, and release gating—but it cannot establish the release-critical facts it claims. Correct the explicit-public rollback, replace the upgrade and Oban report predicates with catalog/content snapshots, add regression tests that fail for each removed invariant, then run the packed public/upgrade and Cohort gates on the release SHA.

_Verified: 2026-08-10T21:35:38Z_
_Verifier: the agent (gsd-verifier)_
