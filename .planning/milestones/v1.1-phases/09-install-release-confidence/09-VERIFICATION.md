---
phase: 09-install-release-confidence
verified: 2026-04-28T17:12:25Z
status: passed
score: 6/6 must-haves verified
overrides_applied: 0
---

# Phase 9: Install & Release Confidence Verification Report

**Phase Goal:** prove the built package from a fresh adopter perspective so installability is validated outside the repo-local checkout assumptions.
**Verified:** 2026-04-28T17:12:25Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A fresh Phoenix app installs Rindle from the built artifact without repo-local dependency assumptions. | ✓ VERIFIED | [test/install_smoke/generated_app_smoke_test.exs](test/install_smoke/generated_app_smoke_test.exs) asserts generated app root/package root exist, `deps/rindle` is absent, and compile/boot succeed at lines 16-24. The helper builds or reuses an unpacked Hex artifact, generates `mix phx.new`, patches the app to depend on `{:rindle, path: package_root}`, then runs `mix deps.get` and `mix compile` at [test/install_smoke/support/generated_app_helper.ex](test/install_smoke/support/generated_app_helper.ex) lines 13-49, 68-127. `bash scripts/install_smoke.sh` passed on 2026-04-28 with `2 tests, 0 failures`. |
| 2 | The fresh-app smoke path runs explicit host-app and packaged Rindle migrations, then completes the canonical presigned PUT upload-to-delivery flow. | ✓ VERIFIED | The top-level smoke test asserts host migration execution, `Application.app_dir/2` resolution, and lifecycle proof at [test/install_smoke/generated_app_smoke_test.exs](test/install_smoke/generated_app_smoke_test.exs) lines 26-34. The generated migration runner explicitly applies both host and library paths via `Ecto.Migrator.run/4` and writes a report at [test/install_smoke/support/generated_app_helper.ex](test/install_smoke/support/generated_app_helper.ex) lines 248-287. The generated in-app test executes `Broker.initiate_session`, `Broker.sign_url`, real HTTP PUT, `Broker.verify_completion`, `PromoteAsset`, `ProcessVariant`, and `Rindle.Delivery.url` at lines 297-380. |
| 3 | The package-consumer proof stays narrow to the canonical adopter path: adopter-owned Repo, default Oban, explicit host plus Rindle migrations, presigned PUT, verify/promote, and signed delivery. | ✓ VERIFIED | The helper injects adopter-owned Repo and default Oban config at [test/install_smoke/support/generated_app_helper.ex](test/install_smoke/support/generated_app_helper.ex) lines 129-205 and boot-checks both repos at lines 390-401. The generated smoke test asserts Repo/Oban ownership and excludes `deps/rindle` at lines 321-326, then only proves the presigned PUT path at lines 328-363. No multipart flow is included in the smoke harness or runner. |
| 4 | CI validates installability from the built package before merge. | ✓ VERIFIED | `.github/workflows/ci.yml` defines a dedicated `package-consumer` job at [ci.yml](.github/workflows/ci.yml) lines 242-330. It provisions Postgres and MinIO, installs `libvips`, and runs `bash scripts/install_smoke.sh` as the single smoke command at line 330. |
| 5 | Release reuses the same consumer smoke helper while retaining deeper tarball inspection and dry-run publish posture. | ✓ VERIFIED | `.github/workflows/release.yml` builds the package, asserts required/prohibited tarball contents, runs the shared smoke helper against the unpacked artifact, and keeps `mix hex.publish package --dry-run --yes` as an additional gate at [release.yml](.github/workflows/release.yml) lines 109-156. |
| 6 | README and getting-started docs match the proven adopter path, including Repo ownership, default Oban expectations, explicit migration setup, and capability-honest presigned PUT-first guidance. | ✓ VERIFIED | README covers quickstart handoff, Repo ownership, default Oban, explicit `Application.app_dir/2` migrations, and presigned PUT-first guidance at [README.md](README.md) lines 9-117. The deep guide mirrors that path at [guides/getting_started.md](guides/getting_started.md) lines 7-210. The executable parity gate in [test/install_smoke/docs_parity_test.exs](test/install_smoke/docs_parity_test.exs) lines 15-60 passed locally via `mix test test/install_smoke/docs_parity_test.exs`. |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `test/install_smoke/generated_app_smoke_test.exs` | Fresh-app smoke proof for canonical package-consumer lifecycle | ✓ VERIFIED | Exists, substantive, and calls `GeneratedAppHelper.prove_package_install!/0` in `setup_all`; asserts no `deps/rindle`, explicit migration resolution, and lifecycle success. |
| `test/install_smoke/support/generated_app_helper.ex` | Shared consumer-app generation, config injection, migration-path resolution, and lifecycle assertions | ✓ VERIFIED | Exists, substantive, and drives the full flow: package build/reuse, `mix phx.new`, app patching, compile, DB create, migration runner, boot check, and generated in-app smoke test. |
| `scripts/install_smoke.sh` | Reusable local/CI/release entrypoint | ✓ VERIFIED | Exists, substantive, and performs strict artifact validation with `set -euo pipefail`, `mix hex.build --unpack`, `RINDLE_INSTALL_SMOKE_PACKAGE_ROOT`, and targeted smoke invocation. |
| `.github/workflows/ci.yml` | Narrow built-artifact consumer smoke job in PR CI | ✓ VERIFIED | Contains dedicated `package-consumer` job with Postgres/MinIO provisioning and shared smoke invocation. |
| `.github/workflows/release.yml` | Shared-helper release verification plus tarball and dry-run gates | ✓ VERIFIED | Contains package build, tarball assertions, shared smoke invocation with unpacked artifact handoff, and dry-run publish. |
| `README.md` | Layered quickstart entrypoint | ✓ VERIFIED | Covers dependency install, Repo/Oban ownership, explicit migrations, presigned PUT first-run flow, and guide handoff. |
| `guides/getting_started.md` | Canonical deep adopter guide aligned to smoke path | ✓ VERIFIED | Covers adopter-owned Repo, default Oban, explicit migration runner snippet, profile setup, lifecycle flow, and multipart as advanced. |
| `test/install_smoke/docs_parity_test.exs` | Executable docs drift gate | ✓ VERIFIED | Exists, substantive, reads README and guide directly, and asserts lifecycle/setup/capability wording. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `scripts/install_smoke.sh` | `test/install_smoke/generated_app_smoke_test.exs` | Shared smoke runner invocation | ✓ WIRED | The script exports `RINDLE_INSTALL_SMOKE_PACKAGE_ROOT` and runs `mix test test/install_smoke/generated_app_smoke_test.exs --include minio` at lines 26-28. |
| `test/install_smoke/generated_app_smoke_test.exs` | `test/install_smoke/support/generated_app_helper.ex` | Shared helper execution | ✓ WIRED | `setup_all` calls `GeneratedAppHelper.prove_package_install!()` at lines 10-13. |
| `test/install_smoke/support/generated_app_helper.ex` | `Application.app_dir(:rindle, "priv/repo/migrations")` | Explicit library migration path resolution | ✓ WIRED | The generated migration runner resolves the packaged migration path and fails loudly if missing at lines 255-263, then migrates both host and library paths at lines 265-269. |
| `test/install_smoke/support/generated_app_helper.ex` | `Rindle.Upload.Broker` and `Rindle.Delivery` | Canonical public API lifecycle assertions | ✓ WIRED | The generated in-app test exercises `Broker.initiate_session`, `Broker.sign_url`, `Broker.verify_completion`, promotion/variant jobs, and `Rindle.Delivery.url` at lines 334-363. |
| `.github/workflows/ci.yml` | `scripts/install_smoke.sh` | Shared PR consumer smoke invocation | ✓ WIRED | `package-consumer` runs `bash scripts/install_smoke.sh` at line 330. |
| `.github/workflows/release.yml` | `scripts/install_smoke.sh` | Shared release consumer smoke invocation | ✓ WIRED | Release exports `RINDLE_INSTALL_SMOKE_PACKAGE_ROOT=$(echo "$GITHUB_WORKSPACE"/rindle-*)` and runs `bash scripts/install_smoke.sh` at lines 132-138. |
| `README.md` | `guides/getting_started.md` | Explicit quickstart-to-deep-guide handoff | ✓ WIRED | README links the guide in the intro and Next Reads at lines 9-10 and 109-117. |
| `test/install_smoke/docs_parity_test.exs` | `README.md` and `guides/getting_started.md` | Drift-proof assertions for canonical lifecycle and setup language | ✓ WIRED | The parity test reads both markdown files in `setup_all` and asserts lifecycle/setup/capability strings across both docs at lines 7-60. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `test/install_smoke/generated_app_smoke_test.exs` | `report` | `GeneratedAppHelper.prove_package_install!/0` return map | Yes | ✓ FLOWING |
| `test/install_smoke/support/generated_app_helper.ex` | `migration_report` | Generated app runs `priv/install_smoke/migrate.exs`, which queries the DB and writes `tmp/install_smoke_migration_report.json` | Yes | ✓ FLOWING |
| `test/install_smoke/support/generated_app_helper.ex` | `smoke_result` | Generated app runs `mix test test/rindle_install_smoke_test.exs`, whose assertions hit Broker, Repo, MinIO PUT, Oban jobs, and Delivery | Yes | ✓ FLOWING |
| `test/install_smoke/docs_parity_test.exs` | `readme`, `guide` | Direct `File.read!/1` of public markdown files | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Docs parity contract passes | `mix test test/install_smoke/docs_parity_test.exs` | `3 tests, 0 failures` | ✓ PASS |
| Built-artifact consumer smoke passes from shared runner | `bash scripts/install_smoke.sh` | Built `rindle-0.1.0-dev`, generated fresh app, finished with `2 tests, 0 failures` | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| `RELEASE-01` | `09-01-PLAN.md` | A fresh Phoenix adopter can install Rindle from the built package and complete the canonical upload-to-delivery path | ✓ SATISFIED | Smoke runner passed end to end; helper and generated test prove built-artifact install, explicit migrations, presigned PUT, verification, promotion, variants, and delivery. |
| `RELEASE-02` | `09-02-PLAN.md` | CI includes a package-consumer smoke path that validates installability from the built artifact rather than only from the repo source | ✓ SATISFIED | `package-consumer` job in CI runs the shared smoke helper after provisioning dependencies; release reuses the same helper. |
| `RELEASE-03` | `09-03-PLAN.md` | README and getting-started guidance match the canonical adopter path, including Repo ownership and upload capability constraints | ✓ SATISFIED | README and guide content match; parity gate passed locally. |

All Phase 9 requirement IDs declared in PLAN frontmatter are present in `.planning/REQUIREMENTS.md`. No orphaned Phase 9 requirement IDs were found.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `.planning/REQUIREMENTS.md` | 45-49, 94-96 | Traceability metadata still marks `RELEASE-01/02/03` as pending | ℹ️ Info | Planning metadata lags the verified implementation, but the code and executable checks satisfy the phase contract. |
| `.planning/ROADMAP.md` | 99-128 | Phase 9 plans/progress still marked pending | ℹ️ Info | Roadmap bookkeeping has not been updated to reflect completed implementation; not a goal blocker. |

### Gaps Summary

No blocking gaps found. The built-artifact install proof, workflow reuse, and docs parity checks are all present and executable in the current codebase. The only drift is project-planning metadata still showing Phase 9 and `RELEASE-*` as pending.

---

_Verified: 2026-04-28T17:12:25Z_
_Verifier: Claude (gsd-verifier)_
