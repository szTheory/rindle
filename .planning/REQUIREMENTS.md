# Requirements: Rindle v1.23 Postgres Schema Isolation

**Defined:** 2026-08-08
**Core Value:** Media, made durable.

## v1.23 Requirements

### Prefix Contract

- [x] **PREFIX-01**: A fresh Rindle install defaults all Rindle-owned domain state to the Postgres
  `rindle` schema without callers manually adding query prefixes.

- [x] **PREFIX-02**: An adopter can explicitly retain a legacy `public` install through one documented,
  coherent prefix configuration and migration pairing.

- [x] **PREFIX-03**: Every normal Rindle data path—including facade calls, background work, Ecto.Multi
  steps, and loaded/new schema structs—uses the configured Rindle prefix rather than silently falling
  back to `public`.

### Migration & Upgrade

- [x] **MIGRATE-01**: The versioned Rindle migration provisions the selected schema before creating
  Rindle-owned tables and marker state, and remains idempotent for a fresh install.

- [x] **MIGRATE-02**: A populated legacy `public` install can follow a documented, host-owned upgrade
  migration that moves exactly the six Rindle tables and `rindle_migration_versions` to `rindle`,
  preserving data and relational integrity.

- [x] **MIGRATE-03**: Mixed, incomplete, or permission-inadequate schema states fail with bounded,
  actionable guidance; the move's maintenance-window and rollback limits are documented honestly.

### Ownership & Operations

- [x] **BOUNDARY-01**: Rindle never creates, moves, drops, or prefixes host-owned `oban_jobs` or the
  host `schema_migrations` ledger; Oban's prefix remains independently configured and defaults to
  `public`.

- [x] **BOUNDARY-02**: Prefix-sensitive raw SQL, catalog checks, and Oban-binding queries use validated,
  safely quoted/bound identifiers and resolve their respective Rindle or Oban schemas correctly.

- [x] **OPS-01**: `mix rindle.doctor` and `mix rindle.runtime_status` report the expected Rindle and
  Oban prefixes separately and diagnose migration/runtime-prefix mismatch without raw database errors.

### Adoption Proof & Release Truth

- [x] **PROOF-01**: Automated isolation proof verifies fresh default installs, explicit public
  compatibility, a populated public-to-rindle upgrade, runtime routing, and the public Oban boundary.

- [x] **PROOF-02**: Packed-artifact generated-app smoke and the Cohort adoption demo provision and run
  end-to-end with Rindle in `rindle` and Oban in `public`.

- [ ] **DOCS-01**: README, getting-started, upgrade, migration API docs, docs-parity tests, and the
  0.4.0 release notes agree on the breaking default, compatibility escape hatch, upgrade order,
  permissions, downtime expectations, and Oban ownership.

## Future Requirements

- **LIFE-06**: Force-delete still-shared assets only with a compliance/legal charter.
- **STREAM-10**: Second streaming provider only for a named adopter and selected provider.
- **TRANS-01**: Signed dynamic image transforms only with explicit product pull.
- **PRIV-01**: Explicit original EXIF/GPS stripping only with explicit privacy-product pull.

## Out of Scope

| Feature | Reason |
|---|---|
| Changing or managing Oban's schema | Oban is host-owned infrastructure; coupling it to Rindle's tables violates the v1.22 ownership boundary. |
| `search_path`-based routing | It makes resolution implicit and expands the trusted-namespace/security surface. |
| Per-tenant or arbitrary schema management | This is a library default/compatibility migration, not a multitenancy platform. |
| Copy/dual-write migration | `ALTER TABLE ... SET SCHEMA` is the narrow data-preserving route; dual writes add unnecessary cutover risk. |
| Force-delete, second provider, transforms, EXIF stripping | Separate demand-gated or long-tail product work. |

## Traceability

| Requirement | Phase | Status |
|---|---|---|
| PREFIX-01 | Phase 117 | Complete |
| PREFIX-02 | Phase 117 | Complete |
| PREFIX-03 | Phase 117 | Complete |
| MIGRATE-01 | Phase 118 | Complete |
| MIGRATE-02 | Phase 118 | Complete |
| MIGRATE-03 | Phase 118 | Complete |
| BOUNDARY-01 | Phase 119 | Complete |
| BOUNDARY-02 | Phase 119 | Complete |
| OPS-01 | Phase 119 | Complete |
| PROOF-01 | Phase 120 | Complete |
| PROOF-02 | Phase 120 | Complete |
| DOCS-01 | Phase 120 | Pending |

**Coverage:**

- v1.23 requirements: 12 total
- Mapped to phases: 12 ✓
- Unmapped: 0

---
*Requirements defined: 2026-08-08 after v1.23 schema-isolation research synthesis. Last updated: 2026-08-08 — mapped 12/12 requirements to Phases 117–120.*
