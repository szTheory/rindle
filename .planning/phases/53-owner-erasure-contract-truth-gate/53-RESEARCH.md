# Phase 53: owner-erasure-contract-truth-gate - Research

**Researched:** 2026-05-26
**Mode:** phase planning
**Confidence:** HIGH

## Planning Question

What needs to be frozen in Phase 53 so Phase 54 can implement owner/account
erasure without reopening public-contract ambiguity?

## Recommendation

Phase 53 should stay contract-first. The narrowest useful wedge is:

1. Freeze the public facade names as `Rindle.preview_owner_erasure/2` and
   `Rindle.erase_owner/2`.
2. Freeze one stable report vocabulary shared by preview and execute:
   `attachments_to_detach`, `assets_to_purge`, and
   `retained_shared_assets`.
3. Freeze the shared-asset rule as "retain if any surviving attachment remains"
   and the execute truth as "detach transactionally, enqueue purge
   asynchronously."
4. Freeze support truth so active docs stop teaching `detach/3` loops plus
   `cleanup_orphans` as the long-term account-deletion surface.

Phase 53 should not ship destructive execution, force-delete policy, admin UI,
or bulk orchestration. Those either belong to Phase 54 implementation or remain
deferred beyond `v1.10`.

## Why This Split Works

- It matches the roadmap ordering: contract now, execute wiring next, proof and
  broader guidance after that.
- It avoids shipping a public function that advertises behavior the repo cannot
  execute yet.
- It gives downstream implementation and proof phases exact names, report keys,
  and non-goals to inherit.

## Required Contract Truths

### Public API naming

- Use `Rindle.preview_owner_erasure/2` for the read-only report path.
- Use `Rindle.erase_owner/2` for the destructive path once Phase 54 lands.
- Keep `detach/3` slot-scoped and `cleanup_orphans` maintenance-only.

### Report shape

The public contract should freeze these user-facing buckets:

- `attachments_to_detach`
- `assets_to_purge`
- `retained_shared_assets`

Each bucket should expose both a count and a list so the later proof/docs work
can stay auditable without extra ad hoc queries.

### Shared-asset rule

- An asset is purge-eligible only when removing the target owner's attachment
  rows leaves zero surviving attachments.
- If any attachment survives, the asset is retained and reported explicitly.
- Re-runs should be stable no-op/report results, not failures.

### Execute truth

- DB detach work happens first.
- Storage deletion remains async through the existing purge lane.
- Public wording must say "purge enqueued" rather than "storage deleted now."

## Codebase Analogs To Reuse

- `lib/rindle.ex` already carries the public-facade and typedoc posture.
- `lib/rindle/ops/upload_maintenance.ex` already demonstrates a dry-run/live
  report contract with explicit counters.
- `test/rindle/api_surface_boundary_test.exs` is the existing doc-boundary
  freeze harness for public API claims.
- `test/install_smoke/docs_parity_test.exs` is the existing active-doc parity
  harness for support-truth wording.
- `guides/user_flows.md` is the highest-leverage public guide currently naming
  the manual workaround.

## Landmines

1. Adding public function exports that callers can invoke before the execute
   lane exists.
2. Using vague bucket names like "skipped" or "affected_assets" that hide the
   retained-shared-asset rule.
3. Recommending `cleanup_orphans` for account deletion after the contract has
   been narrowed.
4. Implying force-delete or bulk-compliance behavior that the milestone
   explicitly defers.

## Validation Architecture

Phase 53 is mostly contract/docs work, so verification should stay cheap and
targeted:

- Code-facing contract freeze:
  `mix test test/rindle/api_surface_boundary_test.exs`
- Active-doc truth freeze:
  `mix test test/install_smoke/docs_parity_test.exs`
- Full phase confidence:
  `mix test`

Map the plan tasks so each contract/doc change has a direct ExUnit assertion.
Do not rely on prose review alone.

## Proposed Plan Shape

- Plan 01: Freeze the code-facing contract in `lib/rindle.ex` docs/types and
  guard it with API-boundary tests.
- Plan 02: Freeze active guide wording around account deletion and guard it
  with docs-parity tests.

## Sources

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/phases/53-owner-erasure-contract-truth-gate/53-CONTEXT.md`
- `lib/rindle.ex`
- `lib/rindle/ops/upload_maintenance.ex`
- `test/rindle/api_surface_boundary_test.exs`
- `test/install_smoke/docs_parity_test.exs`
- `guides/user_flows.md`
