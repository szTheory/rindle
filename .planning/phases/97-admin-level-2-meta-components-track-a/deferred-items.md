# Phase 97 — Deferred Items

| Category | Item | Discovered | Status |
|----------|------|------------|--------|
| drift-gate | `priv/static/rindle_admin/rindle-admin.css` byte-equality with the regenerated `brandbook/tokens/rindle-admin.css` — `admin_design_system_validation_test.exs:246` (ADMIN-02) fails until the shipped copy is synced. **Deferred to Plan 97-04 by design** (97-01 PLAN success criteria + `files_modified` excludes `priv/`). Resolve via `node brandbook/src/sync-admin-css.mjs` in 97-04, which flows through the existing build → contrast → gallery-check → sync → empty-diff gate (D-97-05). | 97-01 (Task 2) | deferred → 97-04 |
