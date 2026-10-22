---
created: 2026-10-21T23:00:00Z
title: Make public Doctor inspect the versioned host migration ledger correctly
area: runtime-diagnostics
files:
  - lib/rindle/ops/runtime_checks.ex
  - lib/mix/tasks/rindle.doctor.ex
---

## Problem

The supported external host installs Oban.Migration and Rindle.Migration.up(version: 1)
from one host-owned migration. Public Doctor confirms the rindle catalog and public
Oban ownership as ready, but compares that host ledger against the legacy package
migration files and reports all legacy migrations pending plus the host wrapper
unresolved. Reproduced twice in the built-package twin; private diagnostic outputs
remain at /private/tmp/rindle-twin-137-package and -package-final.

## Bounded follow-up

Add executable coverage for a normal versioned adopter-owned migration path, then
align Doctor migration-ledger inspection with host ownership without running legacy
package migrations or weakening actual readiness checks. Preserve existing upgrade
and legacy diagnostics. Do not fold into the recovery matrix without normal scope
selection. The twin uses independent catalog/version/live-I/O checks and explicitly
claims no Doctor pass. See 137-02-SUMMARY.md and its narrowly amended plan.
