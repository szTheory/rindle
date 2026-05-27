# Phase 72: Mix Batch Failure Proof - Context

**Gathered:** 2026-05-27 (assumptions mode + parallel research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 72 closes the v1.15 **operator proof** gap (PROOF-06): prove that `mix rindle.batch_owner_erasure` drives the real mid-batch failure path — partial report on stdout, `batch_owner_failed` error message, exit code 1.

**In scope:**
- One integration test in `test/rindle/batch_owner_erasure_task_test.exs` (ROADMAP success criterion 4 names this file).
- Test exercises `Mix.Tasks.Rindle.BatchOwnerErasure.run/1` with `--execute`, two owners, and mid-batch transaction failure.
- Assertions on shell output ordering and error copy; optional DB assertions for belt-and-suspenders.

**Out of scope (explicit):**
- Production code changes (mix task, facade, `OwnerErasure`, error messages) unless test reveals a real bug.
- Extracting `Rindle.Ops.BatchOwnerErasure` runner module or `--simulate-failure` prod flags.
- Separate `*_operator_proof_test.exs` file or PROOF-06 API matrix duplication.
- `fail_after: 1` (empty partial report) CLI test — already covered at API layer (PROOF-05).
- `--format json` partial-failure path — same control flow as text; success JSON already tested.
- `guides/operations.md` edits (TRUTH-04 is Phase 74).
- Nyquist validation on phases 68–70 (VAL-01 is Phase 73).

</domain>

<decisions>
## Implementation Decisions

Research sources: parallel subagent trade studies, `prompts/gsd-rindle-elixir-oss-dna.md` (layered proof, adopter truth, footgun ledger), `prompts/gsd-rindle-research-index.md`, v1.14 milestone audit, Phase 71 CONTEXT pattern, existing PROOF-05 and task-test conventions.

### Scope and surface (test-only)

- **D-01:** **Test-only phase.** Add exactly **one** new test to `test/rindle/batch_owner_erasure_task_test.exs`. No new modules, no mix-task refactor, no public API changes.
- **D-02:** **Reject** extracting a testable runner (`Rindle.Ops.*`) — batch mix task is a thin wrapper over the facade (v1.14 audit D-pattern); doctor/runtime_status extract because domain logic lives outside the task; batch erasure does not.
- **D-03:** **Reject** a separate operator-proof file — splits one scenario across two files, duplicates setup, diverges from ROADMAP file criterion; `owner_erasure_batch_proof_test.exs` is reserved for hermetic API matrices (PROOF-05), not CLI branches.

### Failure injection

- **D-04:** Use **`Rindle.Test.CountingFailingTxnRepo.with_counting_repo(2, fn -> ... end)`** wrapping `Task.run/1` — same harness as PROOF-05 (`test/rindle/owner_erasure_batch_proof_test.exs`).
- **D-05:** **Reject** Mox on `OwnerErasure` — no behaviour seam; would test CLI branching without real txn partial-commit semantics.
- **D-06:** **Reject** production `--simulate-failure` flags — test hooks in shipped CLI violate least surprise and OSS DNA (“lock failure modes in tests,” not runtime simulation switches).
- **D-07:** Keep file **`async: false`** whenever swapping `:repo` via `Application.put_env`; always use `with_counting_repo/2` (restore in `after`), never bare `put_env`.

### Scenario shape

- **D-08:** Test uses **`--execute`** (or `--no-dry-run`) with a **two-owner** JSON owners file and **`fail_after: 2`** — “owner 1 commits, owner 2 fails” (true mid-batch operator case per ROADMAP and `guides/user_flows.md` rerun story).
- **D-09:** **Reject** dry-run + mocked facade — preview path never calls `repo.transaction/1` (`lib/rindle/internal/owner_erasure.ex`); cannot trigger `CountingFailingTxnRepo`.
- **D-10:** **Do not** add a second test for `fail_after: 1` (empty `partial_report`) in this phase — PROOF-05 already locks API semantics; low operator signal on CLI.
- **D-11:** **Defer** `--format json` on failure path — same `print_report/3` branch; success-path JSON already covered in task tests.

### Shell assertions and contracts

- **D-12:** Use established harness: `Mix.shell(Mix.Shell.Process)` in setup, **`catch_exit(...) == {:shutdown, 1}`**, ordered **`assert_received {:mix_shell, :info | :error, ...}`** — match `batch_owner_erasure_task_test.exs` and `runtime_status_task_test.exs` patterns.
- **D-13:** Assert **partial text report before error**: info lines include `"Batch owner erasure report:"`, **no** `"[DRY RUN]"`, `"owners:"` with count **1**, `"attachments_to_detach"`; at least one info line with completed owner `#{owner_type}:#{owner1.id}`.
- **D-14:** Assert **error line** substrings aligned with `lib/rindle/error.ex` `batch_owner_failed` clause (copy contract also in `owner_erasure_batch_error_test.exs`): `"Batch owner erasure stopped because owner"`, failing **owner2** ref, `"1 owner(s) completed successfully"`, `"partial_report"`, `"Completed owners remain committed"`.
- **D-15:** **Reject** `ExUnit.CaptureIO` for this test — repo convention is `Mix.Shell.Process` for Mix tasks; `CaptureIO` is for non-shell paths (e.g. doctor `run_checks/2`, sweep logs).
- **D-16:** **Reject** subprocess `System.cmd("mix", ...)` — in-process `Task.run/1` with `@requirements ["app.start"]` is sufficient hermetic operator proof per OSS DNA.
- **D-17:** Optional **DB assertions** inside the same test (`refute Repo.get` on owner1 attachment, `assert Repo.get` on owner2) — **Claude's discretion**; PROOF-05 already proves DB at API layer; include if planner wants belt-and-suspenders without duplicating a third file.

### Test organization

- **D-18:** Group the new test under **`describe "PROOF-06: partial failure"`** (or equivalent) for audit traceability — filename stays `batch_owner_erasure_task_test.exs` per ROADMAP.

### Claude's Discretion

- Exact `assert_received` sequencing for intermediate info lines (purge/retained counts, owner list line).
- Whether to include D-17 DB assertions.
- Minor fixture storage_key path strings.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` — Phase 72 goal and four success criteria
- `.planning/REQUIREMENTS.md` — PROOF-06
- `.planning/PROJECT.md` — v1.15 maintenance charter, decision contract, support-truth boundary
- `.planning/milestones/v1.14-MILESTONE-AUDIT.md` — Operator `batch_owner_failed` E2E gap (flow 8/8)
- `.planning/RETROSPECTIVE.md` — Operator partial-failure lesson

### Prompts / methodology
- `prompts/gsd-rindle-elixir-oss-dna.md` — Layered proof, adopter truth, footgun ledger, verification posture
- `prompts/gsd-rindle-research-index.md` — OSS prior-art index
- `.planning/METHODOLOGY.md` — Repo-Truth Evidence Ladder, Adopter-First Done

### Implementation (source of truth)
- `lib/mix/tasks/rindle.batch_owner_erasure.ex` — `batch_owner_failed` branch (lines 105–108), exit codes in moduledoc
- `lib/rindle/error.ex` — `batch_owner_failed` message clause (~342–352)
- `lib/rindle/internal/owner_erasure.ex` — preview vs execute txn boundaries
- `lib/rindle/config.ex` — `repo/0` env seam

### Tests (patterns to extend, not duplicate)
- `test/rindle/batch_owner_erasure_task_test.exs` — Target file for PROOF-06
- `test/rindle/owner_erasure_batch_proof_test.exs` — PROOF-05 partial failure (`CountingFailingTxnRepo`)
- `test/support/counting_failing_txn_repo.ex` — Failure injection harness
- `test/support/owner_erasure_batch_fixtures.ex` — Shared fixtures
- `test/rindle/owner_erasure_batch_error_test.exs` — Error copy contract
- `test/rindle/runtime_status_task_test.exs` — Mix shell + `catch_exit` reference

### Operator narrative
- `guides/user_flows.md` — Batch partial failure, `partial_report`, rerun semantics
- `guides/operations.md` — Thin pointer to mix task (no Phase 72 doc change required)

### Prior phase pattern
- `.planning/phases/71-ci-proof-honesty/71-CONTEXT.md` — Assumptions-mode maintenance phase shape

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CountingFailingTxnRepo.with_counting_repo/2` — Proven for `fail_after: 2` mid-batch failure.
- `OwnerErasureBatchFixtures` — `User`, `insert_asset/1`, `insert_attachment/3`, `@owner_type` from `user_module/0`.
- `write_owners_file!/1` / `write_owners_file_content!/1` — Private helpers in task test module.
- `Mix.Shell.Process` + `catch_exit` — All six existing task tests.

### Established Patterns
- **Proof layering:** API matrix in `*_proof_test.exs`; CLI behavior in `*_task_test.exs` (v1.14 D-12).
- **Configurable repo:** `Application.put_env(:rindle, :repo, ...)` via `Config.repo/0` — same as tus/adopter repo swaps and `FailingTransactionRepo` in broker tests.
- **Thin mix tasks:** Parse → facade → print → exit; no `Rindle.Ops` extraction unless domain logic warrants it.

### Integration Points
- Mix task → `Rindle.erase_batch_owner_erasure/2` → `run_batch_owner_erasure/3` → `OwnerErasure.execute/2` → `repo.transaction/1`.
- `docs_parity_test.exs` already asserts guide vocabulary includes `batch_owner_failed` / `partial_report` — no Phase 72 change required for TRUTH.

</code_context>

<specifics>
## Specific Ideas

- Maintainer requested full trade-study synthesis (subagents + prompts) with one coherent recommendation set — no menu of equal options.
- Lessons applied: **Oban/Ecto/Phoenix** thin mix tasks tested via in-process `Task.run`; **Active Storage / Shrine**-style operator CLIs need exit-code + partial-output proof, not only library unit tests; **footgun avoided:** prod simulation flags, runner extraction that stops testing real mix wiring, async tests with global `:repo` swap.

</specifics>

<deferred>
## Deferred Ideas

- CLI test for first-owner failure (`fail_after: 1`, empty partial report) — API covered; add only if operator runbooks demand it.
- `--format json` partial-failure test — defer until scripted ops needs machine-readable partial output.
- `Rindle.Ops.BatchOwnerErasure` extraction — only if mix task grows non-trivial orchestration beyond facade I/O.
- `guides/operations.md` PROOF-06 callout — Phase 74 TRUTH scope if desired.

</deferred>

---

*Phase: 72-mix-batch-failure-proof*
*Context gathered: 2026-05-27*
