# Phase 107 — Deferred / Out-of-Scope Discoveries

## 107-01 (HARD-01) — Async-safety guard surfaced pre-existing violations — RESOLVED-IN-PLAN

The async-safety AST guard (`test/async_safety_guard_test.exs`, Task 1) flagged **4
pre-existing `async: true` modules** outside the plan's declared `files_modified`. The
orchestrator APPROVED an in-plan scope expansion (Option A) — these fixes are test-only and
squarely within the reliability-hardening intent of HARD-01. All 4 are now RESOLVED:

| Module | Disposition | Fix applied |
|---|---|---|
| `test/rindle/profile/profile_test.exs` | GENUINE race (`Application.put_env :signed_url_ttl_seconds`, read by `lib/rindle/config.ex`, shared with delivery_test) | Flipped module to `async: false` + explanatory comment |
| `test/rindle/streaming/provider/mux/http_cancel_upload_test.exs` | GENUINE race (`Application.put_env :rindle, Rindle.Streaming.Provider.Mux`, read globally) | Flipped module to `async: false` + explanatory comment |
| `test/rindle/storage/local_test.exs` | SAFE (every `File.write!` targets a per-test-unique tmp root; guard can't bridge `setup`-return `opts` var) | Kept `async: true`; added justified `@async_safety_allow [:file_mutation]` + comment |
| `test/install_smoke/package_metadata_test.exs` | SAFE (`File.rm_rf` on unique per-build tmp root from `build_package!()`) | Kept `async: true`; added justified `@async_safety_allow [:file_mutation]` + comment |

The guard logic itself was NOT weakened — the detector still fires on these primitives; the
two SAFE modules opt out explicitly via the documented escape hatch, and the two GENUINE
races were removed from the `async: true` set. The guard is GREEN against the full tree.

Note: each `@async_safety_allow` module carries a tiny `def __async_safety_allow__/0`
referencing the attribute, so `mix compile --warnings-as-errors` does not trip on an
"attribute set but never used" warning (the guard reads the attribute from the source AST,
not at runtime).

## 107-01 — Out-of-scope pre-existing test failure (NOT introduced by this plan)

`test/install_smoke/release_docs_parity_test.exs:319` (`operations guide stays a thin
adopter index and maintainer proof lives in RUNNING`) fails with
`assert running =~ "Package Consumer Proof Matrix"`. This failure is PRE-EXISTING and
unrelated to the async work: it was confirmed to fail identically with all 107-01 changes
stashed/reverted, and is stable across `--seed` values (not an async-ordering flake). It
stems from the parked `.planning`/docs archive-cleanup working-tree state, not from any
test-concurrency change. Per scope-boundary rules (only auto-fix issues DIRECTLY caused by
the current task), it is left untouched here and deferred to whoever owns the docs/archive
cleanup change set.
