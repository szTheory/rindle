---
phase: 120-adoption-proof-release-truth
verified: 2026-08-20T16:10:00Z
status: passed
score: 4/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 0/4
  gaps_closed:
    - "Automated proof covers fresh installs, explicit public compatibility, populated public-to-rindle upgrades, runtime routing, and the untouched public Oban boundary."
    - "README, getting-started, migration API docs, docs-parity tests, and the 0.4.0 release notes agree on the breaking default, escape hatch, order of operations, permissions, downtime, and Oban ownership."
  gaps_remaining: []
  regressions: []
---

# Phase 120: Adoption Proof & Release Truth Verification Report

**Phase Goal:** Adopters and maintainers can verify the breaking 0.4.0 schema contract end-to-end from packaged installation through upgrade, demo operation, and documentation.
**Verified:** 2026-08-20T16:10:00Z
**Status:** passed
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Automated proof covers fresh `rindle` installs, explicit `public` compatibility, populated public-to-`rindle` upgrades, runtime routing, and the untouched public Oban boundary. | ✓ VERIFIED | `GeneratedAppHelper` runs separate generated roots and uses schema-qualified catalog reports. `isolation_upgrade_catalog_preserved?/1` requires marker `[1]`, the named FK, all three named indexes, and exact non-empty before/after `public.oban_jobs` snapshots. Eight damaged-report regressions passed locally; exact-source CI run 32371768158 succeeded for `78349c1…`, including Proof, package matrix, and Cohort. |
| 2 | A packed-artifact generated Phoenix application and the Cohort adoption demo provision and run with Rindle in `rindle` and Oban in `public`. | ✓ VERIFIED | The generated-app image scenarios are wired to `prove_public_compatibility_install!/0` and `prove_isolation_upgrade_install!/0`; Cohort uses checked-in host migrations and `scripts/ci/cohort_demo_smoke.sh`. The exact-source CI run 32371768158 has successful package-consumer image/full-matrix and Cohort Demo Smoke jobs. |
| 3 | README, getting-started, migration API docs, upgrading guide, docs-parity tests, and 0.4.0 release notes agree on the breaking default, escape hatch, order of operations, permissions, downtime, and Oban ownership. | ✓ VERIFIED | README, Getting Started, and `Rindle.Migration` all show `down(version: 1, prefix: "public")` for public compatibility. Docs parity (57 tests) extracts and compares both callbacks. Upgrading/troubleshooting/CHANGELOG name maintenance-window ordering, lock/privilege requirements, guarded reversal, and public Oban/ledger ownership. |
| 4 | Release verification demonstrates that packaged artifacts—not only the repository checkout—honor the documented isolation contract. | ✓ VERIFIED | Push CI 32371768158 attempt 2 is successful with `head_sha=78349c1bc5d082b0c0c9fce6796806011fa89a33`. Protected recovery 32383632492 passed Validate Recovery Ref, Gate on Exact-SHA Green CI, idempotent existing-Hex detection, and fresh Public Verify. GitHub tag/release and Hex both expose `0.4.0`. |

**Score:** 4/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `test/install_smoke/support/generated_app_helper.ex` | Packed default/public/upgrade reports and exact catalog evidence | ✓ VERIFIED | Substantive and invoked. The generated runner obtains PostgreSQL marker/FK/index facts and full `public.oban_jobs` snapshots; report policy rejects lost or mutated invariants. |
| `test/install_smoke/generated_app_smoke_test.exs` | Repository-side policy and integration assertions | ✓ VERIFIED | Contains fast topology, public compatibility, and upgrade-contract regressions plus profile-gated packed scenario modules. |
| `examples/adoption_demo/priv/repo/migrations/20260809000000_install_rindle.exs` and `scripts/ci/cohort_demo_smoke.sh` | Host-owned Cohort migration and cold-start proof | ✓ VERIFIED | Migration invokes default `Rindle.Migration.up(version: 1)` separately from host Oban setup; CI runs the cold-start script successfully on the immutable release source. |
| `README.md`, `guides/getting_started.md`, `guides/upgrading.md`, `guides/troubleshooting.md`, `lib/rindle/migration.ex`, `CHANGELOG.md` | Operationally consistent 0.4.0 adopter contract | ✓ VERIFIED | Public surfaces and executable parity agree; default, compatibility, upgrade, rollback, permissions, downtime, and host-ownership boundaries are all represented. |
| `guides/release_publish.md`, `.github/workflows/ci.yml`, `.github/workflows/release.yml` | Exact-SHA package/release gates | ✓ VERIFIED | Workflow wiring requires release-source CI and materializes its immutable tree separately from recovery tooling. Live run/job results confirm it executed successfully. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Generated smoke tests | `GeneratedAppHelper` | `prove_package_install!`, separate public/upgrade scenario functions | ✓ WIRED | Scenario modules call the helper and consume real generated reports; CI exercised package scenarios on the release source. |
| Generated host migrations | `Rindle.Migration` / `Oban.Migration` | Separate host migration files | ✓ WIRED | Fixture source creates separate host Oban and Rindle files; default and explicit-public up/down directions are asserted. |
| Upgrade migration runner | PostgreSQL catalogs | parameterized `pg_class`, `pg_namespace`, `pg_attribute`, `pg_constraint`, and `pg_index` queries | ✓ WIRED | Runner captures exact marker/FK/index facts and before/after snapshots; the report predicate is equality-based rather than a forced boolean. |
| Documentation parity | Generated public fixture and migration API/docs | extracts both public `up` and `down` calls | ✓ WIRED | `docs_parity_test.exs` asserts `prefix: "public"` in each public direction and passed. |
| Exact release source | CI/Release/Public package | source SHA gate, recovery binding, public verification | ✓ WIRED | CI 32371768158 is bound to `78349c1…`; recovery workflow gates that SHA despite tooling at `0973f24…`, then Public Verify succeeds. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Generated upgrade report | marker, FK, indexes, Oban snapshots | Generated consumer PostgreSQL catalog queries | Yes — packed exact-source CI passed the generated scenarios; local policy tests mutate every asserted loss class. | ✓ FLOWING |
| Generated persistence report | lifecycle IDs/read-back | Generated app facade lifecycle and repository read-back | Yes — consumed by package-proof assertions in successful exact-source package CI. | ✓ FLOWING |
| Cohort smoke | schema/host relation results | Docker Compose PostgreSQL checks and HTTP boot path | Yes — Cohort Demo Smoke completed successfully in exact-source CI. | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Fast package/report contracts | `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_fast_contract --seed 0` | 15 tests, 0 failures | ✓ PASS |
| Explicit-public topology | `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_compat_contract --seed 0` | 1 test, 0 failures | ✓ PASS |
| Upgrade integrity regressions | `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_upgrade_contract --seed 0` | 8 tests, 0 failures | ✓ PASS |
| Docs and release parity | `mix test test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs --seed 0` | 57 tests, 0 failures | ✓ PASS |
| Broader closeout regression | Orchestrator-provided targeted prior-phase suite after the closeout-doc commit | 232 tests, 0 failures (4 excluded) | ✓ PASS (independent orchestration receipt) |
| Exact packaged/demo behavior | GitHub Actions CI 32371768158 attempt 2 | success at `78349c1…`; Proof, package consumer matrices, Cohort, Adoption, CI Summary green | ✓ PASS |
| Public released artifact | GitHub Actions Release 32383632492 | success; fresh `Verify public Hex.pm artifact` green after idempotent existing-release detection | ✓ PASS |

### Probe Execution

No Phase 120 `probe-*.sh` scripts were declared or found. The runnable release evidence is supplied by the named generated-app, Cohort, CI, and protected-Release gates above.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- |
| PROOF-01 | 120-01, 02, 07, 08–14 | Automated default/public/upgrade/runtime/Oban proof | ✓ SATISFIED | Exact catalog and snapshot checks replace the earlier hollow predicates; packed exact-source CI proves the runnable paths. |
| PROOF-02 | 120-01, 03, 09, 11–14 | Packed generated app and Cohort demo end-to-end | ✓ SATISFIED | Generated package scenarios and Cohort host-migration/cold-start path are wired and green in CI 32371768158. Public artifact verification later passed in recovery run 32383632492. |
| DOCS-01 | 120-04–06, 08–14 | Contract-consistent adopter/API/upgrade/release docs | ✓ SATISFIED | Cross-surface parity passed; public rollback is safe in both directions; current 0.4.0 notes and release metadata are live. |

No orphaned Phase 120 requirements were found. There is no later milestone phase to which a gap could be deferred.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `test/install_smoke/release_docs_parity_test.exs` | 48–69 | Manifest-aware test accepts only the temporary `0.3.2` or released `0.4.0` states | ⚠️ Warning | The reviewed future-maintenance issue will reject a later legitimate release version until this test is generalized. It does not contradict or weaken the verified 0.4.0 contract, so it is not a Phase 120 goal blocker. |

No unreferenced `TBD`, `FIXME`, or `XXX` markers were found in the Phase 120 implementation surfaces.

### Gaps Summary

The prior blockers are closed. The explicit-public rollback now targets `public`; populated-upgrade proof uses exact content/catalog invariants; and the former synthetic Oban predicate is replaced with a non-empty, exact before/after catalog snapshot. The release chain is independently checkable: exact source `78349c1…` has successful CI, the protected recovery binds back to that source while recording later tooling SHA `0973f24…`, and public GitHub/Hex `0.4.0` state is live. The release-parity literal-version warning is future maintenance, not a missing fact required to prove the released 0.4.0 contract.

---

_Verified: 2026-08-20T16:10:00Z_
_Verifier: the agent (gsd-verifier)_
