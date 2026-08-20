---
phase: 118
slug: isolated-migration-safe-upgrade
status: verified
threats_open: 0
asvs_level: 1
created: 2026-08-20
updated: 2026-08-20
---

# Phase 118 — Security

> Per-phase security contract for the isolated migration and safe-upgrade implementation.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Host migration options to Rindle DDL | Adopter configuration selects one of the supported persisted layouts. | Fixed `public` or `rindle` schema identifier |
| Rindle helper to host database | Library-owned DDL may affect only the seven Rindle-owned relations. | Schema-qualified PostgreSQL DDL |
| Database catalog to mutation decision | Existing layout, ownership, and privileges determine whether relocation may begin. | Catalog metadata and privilege results |
| Concurrent host traffic to DDL locks | Application traffic may contend with relocation locks during a maintenance window. | Transaction and lock state |
| Reversal request to persisted state | Reverse relocation is allowed only from a complete, unchanged layout. | Relation, marker, and ownership state |
| Documentation to operator action | Copy-pasteable migration code triggers persisted database changes. | Public helper calls and operational instructions |
| Test seam to production classifier | Test-only privilege controls must not become a public bypass. | Process-local boolean override |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation and evidence | Status |
|-----------|----------|-----------|----------|-------------|-------------------------|--------|
| T-118-01 | Tampering / Elevation | `Migration.Options` to V1 DDL | high | mitigate | Prefixes are restricted in `lib/rindle/migration/options.ex`; identifiers are quoted in `lib/rindle/migration/v1.ex`. | closed |
| T-118-02 | Tampering | V1 ownership list | high | mitigate | `V1.owned_relations/0` defines the seven owned relations; fast migration tests exclude `oban_jobs` and `schema_migrations`. | closed |
| T-118-03 | Denial of Service | Repeated fresh migration | medium | mitigate | Schema and relation creation are idempotent; the live migration suite proves a second invocation succeeds. | closed |
| T-118-SC | Tampering | Package installs | high | mitigate | Phase 118 introduced no `mix.exs` or `mix.lock` changes. | closed |
| T-118-04 | Tampering | Catalog preflight and destination provisioning | critical | mitigate | `lib/rindle/migration/v1.ex` classifies all required state before mutation; live tests cover refusal without DDL. | closed |
| T-118-05 | Elevation of Privilege | Dynamic identifiers | high | mitigate | The public API admits only pinned directions and versions; DDL uses fixed, quoted relation and schema names without `search_path`. | closed |
| T-118-06 | Tampering / Information Disclosure | Host relations | high | mitigate | Live tests snapshot and preserve `oban_jobs` and `schema_migrations` across relocation. | closed |
| T-118-07 | Repudiation | Bounded failures | medium | mitigate | Refusals report the observed classification and one corrective action before mutation. | closed |
| T-118-08 | Denial of Service | ALTER lock acquisition | high | mitigate | Only SQLSTATE `55P03` is translated; contention tests prove bounded failure with no timeout leak or partial move. | closed |
| T-118-09 | Tampering | Destination creation and mid-move failure | critical | mitigate | Provisioning and fixed ALTER operations remain in the host transaction; injected failures prove rollback. | closed |
| T-118-10 | Tampering | Reverse move | critical | mitigate | Reverse relocation repeats the full preflight and refuses mixed or changed state; guarded reverse tests pass. | closed |
| T-118-11 | Elevation of Privilege | Privilege assumptions | high | mitigate | Catalog checks require relation ownership and target creation privileges; disposable restricted-role tests exercise both denial paths. | closed |
| T-118-12 | Repudiation | Upgrade runbook | high | mitigate | `guides/upgrading.md` documents maintenance, timeout, deployment, verification, and rollback constraints; docs-parity tests enforce them. | closed |
| T-118-13 | Tampering | Copy-pasteable identifiers and API | high | mitigate | Documentation uses pinned directional helpers and fixed schemas; parity tests reject generic movers and `search_path` guidance. | closed |
| T-118-14 | Elevation / Ownership | Host infrastructure wording | high | mitigate | README and operator guides identify `oban_jobs` and `schema_migrations` as host-owned and untouched. | closed |
| T-118-15 | Information Disclosure | Error and documentation catalog details | low | accept | Fixed relation and schema names are intentional public API facts; no credentials or arbitrary catalog contents are exposed. | closed |
| T-118-G05-01 | Denial of Service | Documented Ecto callback | high | mitigate | The exact documented callback runs through `Ecto.Migrator`; parity tests reject nested directional callbacks. | closed |
| T-118-G05-02 | Tampering | Forward and reverse migration | high | mitigate | Tests compare the moved set to `V1.owned_relations/0` and preserve host relation snapshots in both directions. | closed |
| T-118-G05-03 | Repudiation | Operational guide | medium | mitigate | Docs-parity tests bind maintenance, deployment, and verification ordering to the executable guide contract. | closed |
| T-118-G05-SC | Tampering | Package installs | high | mitigate | Phase 118 introduced no dependency-file changes. | closed |
| T-118-G06-01 | Denial of Service | ALTER TABLE lock acquisition | high | mitigate | Lock translation is limited to SQLSTATE `55P03`; the synchronized contention test runs in the disposable PostgreSQL CI lane. | closed |
| T-118-G06-02 | Tampering / Elevation | Privilege preflight | high | mitigate | Real-role tests prove database-CREATE and target-schema-CREATE denial occurs before DDL or relocation. | closed |
| T-118-G06-03 | Tampering | Internal test override | high | mitigate | The override is private, process-scoped, boolean-only, cleared after each test, and absent from public options. | closed |
| T-118-G06-04 | Information Disclosure | Operator error | low | accept | Guidance names the required privilege and corrective action but contains no credentials, SQL values, or host-specific identifiers. | closed |
| T-118-G06-SC | Tampering | Package installs | high | mitigate | Phase 118 introduced no dependency-file changes. | closed |

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-118-01 | T-118-15 | Fixed schema and relation names are public contract details required for safe operator verification; disclosure adds no secret or host-specific data. | Maintainer | 2026-08-20 |
| AR-118-02 | T-118-G06-04 | Bounded privilege guidance is necessary to remediate a refused migration and reveals no credentials, values, or host-specific identifiers. | Maintainer | 2026-08-20 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-20 | 25 | 25 | 0 | GSD security auditor with maintainer risk acceptance |

The source-level regression command `mix test test/rindle/migration_fast_test.exs test/install_smoke/docs_parity_test.exs --seed 0` passed with 39 tests and 0 failures during this audit. No `## Threat Flags` entries were present in the six Phase 118 summaries.

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-20
