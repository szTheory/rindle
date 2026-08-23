---
phase: 122-live-truth-compile-clarity
fixed_at: 2026-08-23T00:28:34Z
review_path: .planning/phases/122-live-truth-compile-clarity/122-REVIEW.md
iteration: 4
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 122: Code Review Fix Report

**Fixed at:** 2026-08-23T00:28:34Z  
**Source review:** `.planning/phases/122-live-truth-compile-clarity/122-REVIEW.md`  
**Iterations:** 4

**Summary:**

- Findings in scope: 6
- Fixed: 6
- Skipped: 0

## Fixed Issues

### WR-01: The R2 row contradicts the shipped S3 tus capability

**Files modified:** `guides/storage_capabilities.md`, `test/install_smoke/phoenix_tus_truth_parity_test.exs`  
**Commit:** `0d838a2`

**Applied fix:** Added `:tus_upload` to the R2 S3-adapter capability claim and stated
that it supplies server-mediated tus only, not GCS provider-direct resumable
sessions. The shipped-doc parity test now locks the R2 and server-mediated boundary.

### WR-02: The new tus documentation lock is an incidental source snapshot, not a behavior-backed parity check

**Files modified:** `test/install_smoke/phoenix_tus_truth_parity_test.exs`  
**Commit:** `2c27839`

**Applied fix:** Replaced storage-source file reads and atom substring checks with
runtime assertions against Local, S3, and GCS adapter capability functions, while
retaining the adopter-facing documentation boundary assertions.

---

_Fixed: 2026-08-23T00:10:05Z_  
_Fixer: the agent (gsd-code-fixer)_  
_Iteration: 1_

## Verification Follow-up

### JSON normalization remains clean after a fresh compile

**Files modified:** `scripts/maintainer/credo_quality.sh`, `test/install_smoke/credo_policy_test.exs`  
**Commit:** `6d9d543`

**Applied fix:** Both normalizer invocations now use `mix run --no-compile --no-start`,
so compilation output cannot be redirected into JSON. The policy test locks that exact
flag order for issue and baseline normalization without relaxing JSON validation.

**Verification:** `mix test test/install_smoke/credo_policy_test.exs`, `mix credo_quality`,
and `mix ci` passed on the shared checkout.

### Capability and rendered-navigation truth

**Files modified:** `guides/storage_capabilities.md`, `test/brandbook/admin_design_system_validation_test.exs`  
**Commit:** `f4be8b3`

**Applied fix:** Added the shipped GCS `:concatenate` capability to the canonical
vocabulary, matrix, and adapter-honesty section while retaining its provider-direct
resumability boundary. The Admin navigation lock now extracts exactly the rendered
`[data-rindle-admin-nav-item]` nodes with LazyHTML before asserting labels and order.

**Verification:** `mix format`, the focused rendered-navigation test, and focused
GCS and documentation tests passed. The whole Admin integration file could not run
in the isolated worktree because its gallery check needs the untracked Playwright
module from the shared adoption-demo dependency install. The shared checkout's
`mix ci` passed after the fix.

### GCS adapter capability documentation

**Files modified:** `lib/rindle/storage/gcs.ex`  
**Commit:** `fdfd702`

**Applied fix:** Updated the GCS adapter moduledoc to list `:concatenate` with its
current GCS compose rationale, matching `capabilities/0` and the canonical storage
capability guide without changing runtime behavior.

**Verification:** `mix format` and focused GCS, storage-adapter, and documentation
tests passed (54 tests, 1 expected skip).
