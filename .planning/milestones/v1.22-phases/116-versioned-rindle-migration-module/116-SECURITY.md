---
phase: 116
slug: versioned-rindle-migration-module
status: verified
threats_open: 0
asvs_level: 1
block_on: high
register_authored_at_plan_time: true
created: 2026-07-01
---

# Phase 116 - Security

Per-phase security contract: threat register, accepted risks, and audit trail.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Host migration keyword options -> Rindle DDL | Host-controlled migration options select version and prefix for Rindle-owned DDL. | `:version`, `:prefix` |
| Rindle DDL -> Postgres schema | Migration helpers create, alter, index, and drop database objects. | Table, index, reference, marker DDL |
| Host-owned Oban -> Rindle diagnostics | Rindle observes `oban_jobs` readiness without owning or mutating Oban state. | Read-only catalog/readiness state |
| Docs/generated app -> adopter database | Copyable Markdown snippets and generated smoke migrations become real host migrations. | Migration commands and code snippets |
| Phase verification -> release train | Focused tests, smoke, CI, workflow diffs, and schema-push checks justify closure. | Verification evidence |

## Threat Register

| Threat ID | Category | Severity | Component | Disposition | Status | Evidence |
|-----------|----------|----------|-----------|-------------|--------|----------|
| T-116-01 | Tampering | medium | Rindle.Migration options | mitigate | closed | `test/rindle/migration_test.exs:96` asserts `ArgumentError` for unknown options, invalid versions, and non-string prefixes; `lib/rindle/migration/options.ex:31` validates through NimbleOptions and re-raises `ArgumentError`. |
| T-116-02 | Tampering / Denial of Service | high | Rindle.Migration.down/1 | mitigate | closed | `test/rindle/migration_test.exs:71` proves `down/1` drops only Rindle-owned tables and leaves `oban_jobs`; `lib/rindle/migration/v1.ex:33` drops only the explicit Rindle table list plus marker. |
| T-116-03 | Tampering | medium | legacy migration package files | mitigate | closed | `test/install_smoke/package_metadata_test.exs:108` requires the historical Oban migration filename to ship; `priv/repo/migrations/20260424205942_create_oban_tables.exs:4` keeps it as a compatibility stub. |
| T-116-04 | Information Disclosure | low | public docs boundary | mitigate | closed | `test/rindle/api_surface_boundary_test.exs:85` checks hidden helper modules; `test/rindle/api_surface_boundary_test.exs:177` checks public `Rindle.Migration.up/1` and `down/1`; helper modules have `@moduledoc false` at `lib/rindle/migration/options.ex:2` and `lib/rindle/migration/v1.ex:2`. |
| T-116-05 | Tampering | medium | doctor migration-health model | mitigate | closed | `test/rindle/ops/runtime_checks_test.exs:263` covers fresh marker/catalog readiness; `test/rindle/ops/runtime_checks_test.exs:287` covers healthy legacy installs; `lib/rindle/ops/runtime_checks.ex:457` evaluates marker/catalog/legacy readiness. |
| T-116-06 | Tampering | medium | legacy repair copy | mitigate | closed | `test/rindle/ops/runtime_checks_test.exs:327` and `test/rindle/doctor_test.exs:165` require warning-only legacy drift and refute `delete`/`replay`; implementation copy at `lib/rindle/ops/runtime_checks.ex:429` says to keep legacy history. |
| T-116-07 | Information Disclosure / Repudiation | medium | runtime status setup failures | mitigate | closed | `test/rindle/ops/runtime_status_test.exs:48` and `:57` assert bounded `setup_incomplete` errors; `lib/rindle/ops/runtime_status.ex:68` returns structured setup errors before report queries; task copy is bounded at `lib/mix/tasks/rindle.runtime_status.ex:68`. |
| T-116-08 | Tampering / Denial of Service | high | host-owned oban_jobs boundary | mitigate | closed | `test/rindle/ops/runtime_checks_test.exs:352` and `test/rindle/doctor_test.exs:188` require host-owned `Oban.Migration` guidance; `lib/rindle/ops/runtime_checks.ex:501` treats `oban_jobs` as host readiness. |
| T-116-09 | Tampering | medium | docs snippets | mitigate | closed | `test/install_smoke/docs_parity_test.exs:140` requires pinned `Rindle.Migration` snippets and rejects greenfield package-path replay; README evidence at `README.md:114` and `README.md:130`. |
| T-116-10 | Tampering / Denial of Service | high | generated-app migrations | mitigate | closed | `test/install_smoke/support/generated_app_helper.ex:964` writes host-owned Oban migration separately from `test/install_smoke/support/generated_app_helper.ex:984` Rindle migration; report fields at `:1038` are asserted by `test/install_smoke/generated_app_smoke_test.exs:33`. |
| T-116-11 | Tampering | medium | legacy compatibility copy | mitigate | closed | Fresh install proof rejects package-path resolver at `test/install_smoke/generated_app_smoke_test.exs:38`; legacy upgrade proof remains scoped at `test/install_smoke/support/generated_app_helper.ex:1068` and `test/install_smoke/generated_app_smoke_test.exs:358`. |
| T-116-12 | Information Disclosure | low | docs styling/extensions | accept | closed | Accepted risk documented below. Evidence: `116-06-SUMMARY.md:142` says docs-only changes introduced no endpoints/auth/file/schema runtime changes; changed docs are Markdown files only. |
| T-116-13 | Tampering | medium | Rindle.Migration.Options | mitigate | closed | `lib/rindle/migration/options.ex:6` defines only `:version` and `:prefix`; `:8` limits version to supported versions; `:13` requires string prefix; `test/rindle/migration_test.exs:96` covers invalid input. |
| T-116-14 | Tampering | high | prefix-aware DDL | mitigate | closed | `lib/rindle/migration/v1.ex:18` receives selected prefix; table/index/reference operations pass `prefix` at `:68`, `:99`, `:109`, `:157`, and marker DDL at `:302`; default `public` is in `lib/rindle/migration/options.ex:14`. |
| T-116-15 | Tampering / Denial of Service | high | destructive rollback | mitigate | closed | `lib/rindle/migration/v1.ex:33` drops only explicit Rindle-owned tables and marker in dependency order; `test/rindle/migration_test.exs:71` verifies `oban_jobs` survives rollback. |
| T-116-16 | Tampering | high | bundled Oban migration | mitigate | closed | Legacy file is a no-op compatibility stub at `priv/repo/migrations/20260424205942_create_oban_tables.exs:4`; `rg -n "Oban\\.Migration|oban_jobs" lib/rindle/migration/v1.ex priv/repo/migrations/20260424205942_create_oban_tables.exs` returned no matches. |
| T-116-17 | Tampering | high | prefix-aware catalog checks | mitigate | closed | Doctor catalog checks use `Config.rindle_prefix/0` and `Config.oban_prefix/0` at `lib/rindle/ops/runtime_checks.ex:667` and `:717`; runtime status uses the same at `lib/rindle/ops/runtime_status.ex:100` and `:125`; tests cover non-public prefixes at `test/rindle/ops/runtime_status_test.exs:88`. |
| T-116-18 | Tampering | medium | legacy drift guidance | mitigate | closed | Implementation downgrades healthy legacy drift to warning/history-only at `lib/rindle/ops/runtime_checks.ex:393` and `:429`; tests refute delete/replay guidance at `test/rindle/ops/runtime_checks_test.exs:327` and `test/rindle/doctor_test.exs:165`. |
| T-116-19 | Information Disclosure / Repudiation | medium | runtime-status DB errors | mitigate | closed | Setup preflight returns `{:setup_incomplete, :rindle_schema}` / `{:setup_incomplete, :oban_jobs}` at `lib/rindle/ops/runtime_status.ex:81`; CLI renders bounded operator copy at `lib/mix/tasks/rindle.runtime_status.ex:68`; tests at `test/rindle/ops/runtime_status_test.exs:48`. |
| T-116-20 | Tampering / Denial of Service | high | host-owned oban_jobs | mitigate | closed | Runtime status observes readiness with information_schema at `lib/rindle/ops/runtime_status.ex:125`; report queries read Oban prefix via `oban_all/1` at `:510`; docs/task copy directs setup to `Oban.Migration` at `lib/mix/tasks/rindle.runtime_status.ex:73`. |
| T-116-21 | Tampering | medium | README/getting-started snippets | mitigate | closed | Docs parity requires pinned version, default public schema, host-owned Oban, `mix ecto.migrate`, and doctor at `test/install_smoke/docs_parity_test.exs:151`; README has the snippet at `README.md:108`; Getting Started at `guides/getting_started.md:126`. |
| T-116-22 | Tampering | high | rollback copy | mitigate | closed | README rollback copy marks `down/1` destructive, backup-required, and Rindle-owned-only at `README.md:130`; Getting Started mirrors at `guides/getting_started.md:151`; Upgrade guide mirrors at `guides/upgrading.md:71`. |
| T-116-23 | Tampering | medium | legacy upgrade guidance | mitigate | closed | Upgrade guide says existing legacy migrations stay in place and must not be deleted/replayed at `guides/upgrading.md:75`; README and Getting Started carry matching upgrade notes at `README.md:134` and `guides/getting_started.md:155`. |
| T-116-24 | Tampering / Denial of Service | high | generated-app proof | mitigate | closed | Generated helper runs host marker, host Oban, then Rindle migrations from host path at `test/install_smoke/support/generated_app_helper.ex:1026`; smoke asserts `host_oban_migration_ran?`, `rindle_migration_ran?`, and `rindle_created_oban_jobs? == false` at `test/install_smoke/generated_app_smoke_test.exs:33`. |
| T-116-25 | Tampering | high | CI/release workflows | mitigate | closed | `git diff --name-only 8ecf83833b36d889443ce1a57213a8529d780f26..HEAD -- .github/workflows/ci.yml .github/workflows/release.yml .github/workflows/release-please-automerge.yml` returned no output; `116-07-SUMMARY.md:91` records workflow invariant checks. |
| T-116-26 | Repudiation | medium | verification evidence | mitigate | closed | `116-07-SUMMARY.md:86` records focused suite, generated-app smoke, `mix ci`, workflow diff, schema-push check, and key-link grep outcomes with pass results. |
| T-116-27 | Tampering | medium | schema-push gate | mitigate | closed | Configured ORM schema trigger command returned no matches; `116-07-SUMMARY.md:93` records no configured schema-push path matched Phase 116 changed files. |
| T-116-28 | Denial of Service | low | generated smoke environment | accept with evidence | closed | Accepted risk documented below. Final evidence: `116-07-SUMMARY.md:88` focused suite passed, `:89` generated image smoke passed, and `:90` `mix ci` passed with no environment block. |
| T-116-SC | Tampering | low | package installs | accept | closed | Accepted risk documented below. `git diff --name-only 8ecf83833b36d889443ce1a57213a8529d780f26..HEAD | rg '(^mix\\.exs$|^mix\\.lock$|package(-lock)?\\.json$|pnpm-lock\\.yaml$|yarn\\.lock$|bun\\.lockb?$|Cargo\\.(toml|lock)$|requirements.*\\.txt$|pyproject\\.toml$|Pipfile(\\.lock)?$|Gemfile(\\.lock)?$)'` returned no matches. |

Status: open | closed

Disposition: mitigate (implementation required) | accept (documented risk) | transfer (third-party)

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date | Evidence |
|---------|------------|-----------|-------------|------|----------|
| AR-116-12 | T-116-12 | Phase 116 changed portable Markdown docs, not browser UI or custom docs rendering. The residual styling/extension disclosure risk is outside this phase's implemented surface. | Phase 116 plan-time threat register | 2026-07-01 | `116-06-SUMMARY.md:142`; changed-file set contains Markdown docs and Elixir/test files, no docs renderer or browser UI assets. |
| AR-116-28 | T-116-28 | Local generated-smoke environment failures are accepted only with exact evidence and CI proof requirement. In this run, the risk did not remain open because generated-app smoke and `mix ci` passed. | Phase 116 plan-time threat register | 2026-07-01 | `116-07-SUMMARY.md:88` through `:90`. |
| AR-116-SC | T-116-SC | No package-manager install task was planned; Phase 116 used existing locked dependencies and did not change package-manager manifests. | Phase 116 plan-time threat register | 2026-07-01 | Package-manifest diff grep returned no matches. |

## Summary Threat Flags

No unregistered flags.

| Summary | Threat Flag Result | Mapping |
|---------|--------------------|---------|
| 116-01 | None; tests only. | No new attack surface. |
| 116-02 | None; tests only. | No new attack surface. |
| 116-03 | None; tests and generated-app fixtures only. | Covered by T-116-09 through T-116-11 and T-116-24. |
| 116-04 | Planned migration DDL trust boundary only. | Covered by T-116-13 through T-116-16. |
| 116-05 | Planned Postgres catalog reads and read-only `oban_jobs` boundary only. | Covered by T-116-17 through T-116-20. |
| 116-06 | None; documentation only. | Covered by T-116-21 through T-116-23 and accepted risk T-116-12. |
| 116-07 | None; verification only. | Covered by T-116-25 through T-116-28. |

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Blocking Open | Run By |
|------------|---------------|--------|------|---------------|--------|
| 2026-07-01 | 29 | 29 | 0 | 0 | gsd-security-auditor |

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

Approval: verified 2026-07-01
