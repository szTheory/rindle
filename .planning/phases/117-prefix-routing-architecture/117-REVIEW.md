---
phase: 117-prefix-routing-architecture
reviewed: 2026-08-09T01:47:46Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - lib/rindle/schema.ex
  - lib/rindle/config.ex
  - lib/rindle/domain/media_asset.ex
  - lib/rindle/domain/media_attachment.ex
  - lib/rindle/domain/media_variant.ex
  - lib/rindle/domain/media_upload_session.ex
  - lib/rindle/domain/media_processing_run.ex
  - lib/rindle/domain/media_provider_asset.ex
  - test/support/schema_prefix_case.ex
  - test/rindle/schema_prefix_integration_test.exs
  - test/rindle/schema_prefix_contract_test.exs
findings:
  critical: 0
  warning: 1
  info: 0
  total: 1
status: issues_found
---

# Phase 117: Code Review Report

**Reviewed:** 2026-08-09T01:47:46Z
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

The shared macro, all six converted schemas, prefix-aware integration path, and contract tests were reviewed in context. The focused prefix tests pass, but the implementation does not actually make `Rindle.Schema` the sole prefix authority: a consumer can overwrite the module attribute after `use Rindle.Schema` and before `schema/2`. The current AST contract test does not detect that supported Elixir form.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: The shared schema prefix can be silently overridden

**File:** `lib/rindle/schema.ex:22-24`, `test/rindle/schema_prefix_contract_test.exs:53-57`

**Issue:** `Rindle.Schema` assigns an ordinary `@schema_prefix` attribute. A domain module can subsequently call `Module.put_attribute(__MODULE__, :schema_prefix, "public")` (or assign the attribute through macro expansion) before its `schema` block, and Ecto will route that table to the replacement schema. The AST test only rejects literal `@schema_prefix` nodes, so it passes despite this bypass. In the test build, compiling a module that uses `Rindle.Schema` and then calls `Module.put_attribute(..., "rindle")` produces `{ "public", "rindle" }` for `{Rindle.Schema.prefix(), schema.__schema__(:prefix)}`. This defeats PREFIX-01's single routing authority and can cause individual domain tables to read or write a different schema.

**Fix:** Make the macro verify the final Ecto schema prefix after the consumer compiles, and add a regression test that attempts this override. For example, register an `@after_compile` callback from `Rindle.Schema` which raises unless `module.__schema__(:prefix) == Rindle.Schema.prefix()`. Keep the source-level contract test as a supplemental guard, but also reject dynamic `Module.put_attribute/3` (or test the after-compile enforcement directly).

---

_Reviewed: 2026-08-09T01:47:46Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
