# Phase 70: Proof & adopter guidance - Context

**Gathered:** 2026-05-27 (assumptions mode, research-validated)
**Status:** Ready for planning

<domain>
## Phase Boundary

Prove batch owner-erasure behavior (PROOF-05) and document adopter/operator
expectations in guides + docs parity (TRUTH-03). Phase 70 closes v1.14 — it does
not add batch API, orchestration, or operator CLI capabilities (Phases 67–69).

Out of scope: force-delete policy, admin LiveView erasure UI, scheduler/cron
jobs, changes to single-owner erasure semantics, canonical-app batch mirror,
new install_smoke CLI matrix beyond existing task tests.

</domain>

<decisions>
## Implementation Decisions

### Hermetic proof layout (PROOF-05)
- **D-01:** Leave `test/rindle/owner_erasure_batch_test.exs` unchanged as the
  frozen Phase 68 happy-path baseline (preview, execute, idempotent rerun, dedupe).
- **D-02:** Add `test/rindle/owner_erasure_batch_proof_test.exs` for Phase 70
  PROOF-05 gap scenarios only, using `describe "PROOF-05: …"` blocks.
- **D-03:** Extract shared fixtures to `test/support/owner_erasure_batch_fixtures.ex`
  (`Rindle.Test.OwnerErasureBatchFixtures`) — consumed by batch_test, proof_test,
  and `batch_owner_erasure_task_test.exs`.
- **D-04:** Do **not** add batch owner-erasure tests to
  `test/adopter/canonical_app/lifecycle_test.exs`; keep canonical single-owner
  erasure test as the adopter-facing account-deletion proof.

### PROOF-05 scenarios (proof file only — gaps)
- **D-05:** Add batch **shared-asset** integration tests (two owners, one shared
  asset): preview and execute assert aggregate `retained_shared_assets` and purge
  behavior match v1.10 single-owner semantics (`owner_erasure_test.exs` fixtures).
- **D-06:** Add **partial-failure DB integration**: owner1 `execute` commits,
  owner2 fails; assert `{:error, {:batch_owner_failed, detail}}`,
  `detail.partial_report.owners` contains only owner1, owner1 attachment gone,
  owner2 attachment still present.
- **D-07:** Add **first-owner failure** case: `partial_report.owners == []` when
  the first per-owner transaction fails (documents Phase 68 D-08).
- **D-08:** Do **not** re-test preview aggregation, dedupe, empty/over-limit, or
  idempotent rerun in the proof file — already covered by Phase 68 tests.

### Partial-failure test mechanism
- **D-09:** Prove partial failure via `Application.put_env(:rindle, :repo, …)`
  counting repo wrapper (same seam as `OwnerErasure` via `Config.repo/0`),
  following `test/rindle/upload/broker_test.exs` `FailingTransactionRepo` +
  `put_env` + `on_exit` precedent.
- **D-10:** Ship `test/support/counting_failing_txn_repo.ex` (or equivalent) that
  delegates reads/writes to `Rindle.Repo` and fails the Nth `transaction/1` with
  Ecto-shaped `{:error, :plan, reason, %{}}` — **not** Mox on storage, invalid
  UUID fixtures, or mocking `OwnerErasure`.
- **D-11:** Do **not** block Phase 70 on rescuing planner cast errors inside
  `OwnerErasure.execute/2` for invalid `owner_id` — that is optional API
  hardening for a future phase.

### CLI proof
- **D-12:** No new install_smoke CLI matrix; `test/rindle/batch_owner_erasure_task_test.exs`
  remains sufficient for OPS-02 (dry-run default, execute, owners-file, partial
  report before exit 1).

### Support truth — guides (TRUTH-03)
- **D-13:** Primary batch narrative lives in `guides/user_flows.md` Story 5:
  keep single-owner flow first; add **“Batch owner erasure”** subsection (~15–25
  lines) with API, one 2-owner example, `mix rindle.batch_owner_erasure` +
  pointer to `mix help`, sequential per-owner transactions, dedupe, `max_owners`,
  `batch_owner_failed` + `partial_report`, idempotent rerun.
- **D-14:** Replace stale “bulk orchestration remains deferred” with: batch API +
  mix task **shipped**; **admin UI, force-delete (still-shared assets), and
  scheduler/cron erasure jobs** remain deferred.
- **D-15:** Adopter-facing docs use **batch** terminology (matches API names);
  reserve “bulk” for planning/milestone names only.
- **D-16:** Extend `guides/operations.md` owner-erasure blurb only (~8–12 lines):
  batch API + `mix rindle.batch_owner_erasure` + links to `user_flows.md` and mix
  `@moduledoc` — no JSON schema, flag table, or repair-verb row.
- **D-17:** Add one forward sentence in `guides/getting_started.md` pointing batch
  orchestration to `user_flows.md` (thin pointer; no deep batch content).

### Docs parity tests (TRUTH-03)
- **D-18:** Extend `test/install_smoke/docs_parity_test.exs` only — do **not**
  add `batch_owner_erasure_docs_parity_test.exs` (streaming cancel parity is a
  separate guide file; batch extends existing owner-erasure truth).
- **D-19:** Update `"user flows guide freezes the canonical owner-erasure support
  truth"`: remove required `"bulk orchestration"` snippet; add batch API, mix
  task, batch semantics snippets; refute deferred bulk-orchestration wording.
- **D-20:** Add test `"user flows and operations document batch erasure without
  duplicating mix task contract"`: assert batch vocabulary in user_flows;
  operations has thin pointer; **refute** `--owners-file` and `owner_type` in
  operations.md.
- **D-21:** Extend thin-pointer parity test so getting_started references batch
  via link to `user_flows.md`.

### Verification command (planner reference)
- **D-22:** Phase verification runs:
  `mix test test/rindle/owner_erasure_batch_test.exs
  test/rindle/owner_erasure_batch_proof_test.exs
  test/rindle/owner_erasure_batch_boundary_test.exs
  test/rindle/owner_erasure_batch_error_test.exs
  test/rindle/owner_erasure_batch_contract_test.exs
  test/rindle/owner_erasure_test.exs
  test/rindle/batch_owner_erasure_task_test.exs
  test/install_smoke/docs_parity_test.exs`

### Claude's Discretion
- Exact `describe` / test names inside `owner_erasure_batch_proof_test.exs`
- Whether counting repo lives in `test/support/counting_failing_txn_repo.ex` or
  is scoped inside the proof test module initially
- Story 5 subsection heading wording and optional “Find your job” table row
- Exact parity snippet strings (prefer stable phrases over full paragraphs)
- Whether `getting_started.md` needs more than one sentence for batch pointer

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` — Phase 70 goal, success criteria, PROOF-05 / TRUTH-03
- `.planning/REQUIREMENTS.md` — PROOF-05, TRUTH-03 acceptance criteria
- `.planning/PROJECT.md` — v1.14 closure, adopter-first proof posture
- `.planning/phases/68-batch-erasure-implementation/68-CONTEXT.md` — batch semantics, partial-failure tuple
- `.planning/phases/68-batch-erasure-implementation/68-VERIFICATION.md` — deferred partial-failure DB gap
- `.planning/phases/69-operator-mix-task/69-CONTEXT.md` — D-14 guide deferral, mix task contract

### Shipped implementation (proof targets)
- `lib/rindle.ex` — batch API `@moduledoc`, `run_batch_owner_erasure/3`
- `lib/rindle/internal/owner_erasure.ex` — per-owner `preview/2`, `execute/2`
- `lib/mix/tasks/rindle.batch_owner_erasure.ex` — operator CLI `@moduledoc`
- `lib/rindle/error.ex` — `batch_owner_failed` message

### Existing tests (extend, do not replace)
- `test/rindle/owner_erasure_batch_test.exs` — Phase 68 baseline (frozen)
- `test/rindle/owner_erasure_test.exs` — shared-asset single-owner fixtures
- `test/rindle/owner_erasure_batch_error_test.exs` — operator error copy (unit)
- `test/rindle/batch_owner_erasure_task_test.exs` — CLI contract
- `test/adopter/canonical_app/lifecycle_test.exs` — single-owner canonical proof only
- `test/install_smoke/docs_parity_test.exs` — TRUTH-03 parity home
- `test/rindle/upload/broker_test.exs` — `FailingTransactionRepo` + `put_env` precedent

### Guides (TRUTH-03 edit targets)
- `guides/user_flows.md` — Story 5 owner erasure + new batch subsection
- `guides/operations.md` — thin index (D-18)
- `guides/getting_started.md` — thin forward link

### Project DNA / research
- `prompts/gsd-rindle-elixir-oss-dna.md` — CI as contract surface, docs-contract gates, layered proof
- `prompts/phoenix-media-uploads-lib-deep-research.md` — purge-not-in-transaction footgun

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `owner_erasure_batch_test.exs` — `TestProfile`, `User`, `insert_asset/insert_attachment` (extract to support module)
- `owner_erasure_test.exs` — shared vs orphan asset fixture patterns for batch shared-asset proof
- `broker_test.exs` — `FailingTransactionRepo` + `Application.put_env(:rindle, :repo, …)` pattern
- `batch_owner_erasure_task_test.exs` — `Mix.Shell.Process`, owners JSON file helpers
- `docs_parity_test.exs` — owner-erasure snippet freeze (~lines 251–304)

### Established Patterns
- Split batch concerns: integration (`batch_test`), boundary, contract, error (unit)
- PROOF phases add gap-fill files, not rewrite verified Phase N baselines
- Guides: `user_flows.md` canonical story; `operations.md` thin cross-link (D-18)
- Parity tests freeze vocabulary phrases, not full `@moduledoc` duplication
- v1.13 cancel: hermetic matrix in `test/rindle/`, dedicated docs parity for separate guide

### Integration Points
- New: `test/support/owner_erasure_batch_fixtures.ex`
- New: `test/support/counting_failing_txn_repo.ex` (or equivalent)
- New: `test/rindle/owner_erasure_batch_proof_test.exs`
- Edit: `guides/user_flows.md`, `guides/operations.md`, `guides/getting_started.md`
- Edit: `test/install_smoke/docs_parity_test.exs`

</code_context>

<specifics>
## Specific Ideas

- Partial-failure proof must assert real DB attachment state, not only
  `Error.message/1` (68-VERIFICATION advisory)
- Parity flip for `"bulk orchestration"` must land in the **same PR** as guide
  prose — test currently requires the stale deferral phrase
- Batch docs should warn: execute may commit early owners; inspect
  `partial_report` and rerun idempotently
- `mix test test/rindle/owner_erasure_batch*` is the single batch proof command

</specifics>

<deferred>
## Deferred Ideas

- Rescue invalid `owner_id` cast errors in `OwnerErasure.execute/2` as `{:error, _}`
- Canonical-app batch smoke (preview-only or full mirror)
- Separate `batch_owner_erasure_docs_parity_test.exs`
- README batch section (ROADMAP criterion 2 names guides only)
- Force-delete, admin UI, scheduler/cron — remain v1.15+ / host-app concerns

</deferred>

---

*Phase: 70-proof-adopter-guidance*
*Context gathered: 2026-05-27*
