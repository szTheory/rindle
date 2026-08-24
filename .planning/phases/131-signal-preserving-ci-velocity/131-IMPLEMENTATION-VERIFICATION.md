# v1.25 Implementation Verification

**Verified:** 2026-08-24

**Tree:** `codex/v1.25-maintainer-craft` through `a07eaff` plus planning receipts

**Verdict:** local implementation complete; ten-run PR timing receipt remains external and open

## Measured ratchets

| Signal | Before | Verified result |
|--------|--------|-----------------|
| Strict Credo advisories | 143 | 130; no finding in the new IntegrationChecks owners |
| Curated complexity inventory | 35 weighted occurrences / 31 identities | 31 occurrences / 27 identities |
| Owned IntegrationChecks complexity | 3 cyclomatic + 1 nesting | 0 |
| Coverage | 82.13% | 82.1343% (5,149 / 6,269 relevant lines) |
| Runtime-check suite ownership | one mixed core/GCS file plus streaming | 39 original tests preserved across core and GCS; streaming remains focused |
| Upload-maintenance suite ownership | one 1,179-line file / 44 tests | three behavioral suites plus shared case / 44 tests |
| Non-Admin production history markers | broad phase/plan narration | one reviewed frozen `Rindle.Error` compatibility literal; Admin excluded |
| Runtime graph | cycles of length 12, 5, 3, and 2 | same four cycles; compile-connected SAFE-01 graph remains acyclic |

## Verification receipts

- `mix compile --warnings-as-errors` — pass.
- Focused runtime checks — 55 tests, 0 failures.
- Focused upload maintenance — 44 tests, 0 failures.
- Installer and CI policy — 35 tests, 0 failures.
- `mix quality_signals` — pass; 93 contract tests, 0 failures.
- `bash scripts/maintainer/refactor_contract.sh` — pass; no compile-connected cycles and 93
  contract tests, 0 failures.
- Required coverage command `mix coveralls.multiple --type local --type json` — 1,383 tests,
  0 failures, 4 skipped; 82.1343% exact JSON coverage.
- Integration proof — upload lifecycle 8/8; MinIO storage 13 tests, 0 failures, 1 intentional skip.
- Packed image consumer `bash scripts/install_smoke.sh image` — package build/unpack, generated
  Phoenix app, migration, boot, lifecycle, and report proof; 21 tests, 0 failures.
- Phoenix installer helper — local version 1.8.9; executable cold-install/reuse/mismatch tests pass.
- Shell syntax, YAML parsing, and `git diff --check` — pass.

## Preservation review

No public function, schema/migration behavior, telemetry event/metadata, dependency set, required-check
name, release proof breadth, or Admin surface changed. The exact public error message containing the
historical `Phase 34` text remains byte-for-byte because the contract suite freezes it; it is the sole
reviewed non-Admin production exception.

Required image proof remains in `CI Summary` and retains the same built-package assertions. Its job now
starts independently, omits Node and FFmpeg for the image-only profile, and reads the already compiled
test project for version alignment. Full video/tus/Mux/GCS proof remains on main/release.

## Open closure gate

CI-14 cannot be established from local execution. Record ten comparable non-cancelled PR runs in
`../132-measured-closure/132-CI-TIMING-RECEIPT.md`; require <=8 minutes median and <=10 minutes p95.
The milestone remains active until that receipt is complete.
