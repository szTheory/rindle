---
phase: 117-prefix-routing-architecture
reviewed: 2026-08-09T02:24:56Z
depth: standard
files_reviewed: 13
files_reviewed_list:
  - lib/rindle/schema.ex
  - lib/rindle/config.ex
  - lib/rindle/domain/media_asset.ex
  - lib/rindle/domain/media_attachment.ex
  - lib/rindle/domain/media_variant.ex
  - lib/rindle/domain/media_upload_session.ex
  - lib/rindle/domain/media_processing_run.ex
  - lib/rindle/domain/media_provider_asset.ex
  - test/rindle/config/config_test.exs
  - test/rindle/domain/media_schema_test.exs
  - test/rindle/schema_prefix_integration_test.exs
  - test/rindle/schema_prefix_contract_test.exs
  - test/support/schema_prefix_case.ex
findings:
  critical: 1
  warning: 0
  info: 0
  total: 1
status: issues_found
---

# Phase 117: Code Review Report

**Reviewed:** 2026-08-09T02:24:56Z
**Depth:** standard
**Files Reviewed:** 13
**Status:** issues_found

## Summary

The review covered the Phase 117 schema-prefix implementation, domain consumers, and its focused regression/integration support. The Plan 117-03 finalization guard rejects the specific `Module.put_attribute/3` mutation covered by its test, but the guard itself remains mutable by the consumer. This leaves the phase's claimed single routing authority bypassable.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Consumer code can remove the final-prefix guard before changing the prefix

**File:** `lib/rindle/schema.ex:25`

**Issue:** `use Rindle.Schema` registers its only enforcement mechanism in the consumer's mutable `:after_compile` module attribute. A consumer can call `Module.delete_attribute(__MODULE__, :after_compile)` after `use Rindle.Schema`, then set `:schema_prefix` to the alternate allowed prefix before `schema/2`. The module compiles and Ecto records the attacker-selected prefix because `Rindle.Schema.__after_compile__/2` is never run. This directly reopens the dynamic-metadata bypass that Plan 117-03 is intended to close.

Reproduced under `MIX_ENV=dev` with a generated consumer containing:

```elixir
use Rindle.Schema
Module.delete_attribute(__MODULE__, :after_compile)
Module.put_attribute(__MODULE__, :schema_prefix, "public")
schema "after_compile_bypass_probes" do
end
```

It compiled successfully and returned `"public"` from `module.__schema__(:prefix)` while `Rindle.Schema.prefix()` was `"rindle"`.

**Fix:** Do not rely solely on a removable consumer callback. Make the schema declaration boundary reassert the compiled prefix immediately before Ecto consumes it (for example, expose a `Rindle.Schema.schema/2` wrapper and exclude raw `Ecto.Schema.schema/2` from the consumer import), while retaining the finalization check as defense in depth. Extend the contract test with the reproduced callback-removal sequence and assert it cannot yield a schema whose metadata differs from `Rindle.Schema.prefix/0`; also reject direct raw Ecto schema declaration in the owned-schema source guard.

---

_Reviewed: 2026-08-09T02:24:56Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
