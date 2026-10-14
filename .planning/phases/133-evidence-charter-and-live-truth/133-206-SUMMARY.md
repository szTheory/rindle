---
phase: 133-evidence-charter-and-live-truth
plan: "206"
status: complete
subsystem: tooling
tags: [reconciliation, plan-203, current-admission, writer, paired-verifier, gap-closure]
requires:
  - phase: 133-205
    provides: Fully green focused reconciliation file baseline (128 tests)
  - phase: 133-202
    provides: Halt evidence that the writer and current admission hardcoded Plan 170 (commits e277fdb4/0709e1b5, untouched)
provides:
  - Plan 203 current-authority admission (plan121_paths p203 keys, plan203_qualification_gate/3, invoke_plan203_qualification_verifier/2)
  - "@plan203_verifier_keys: the single committed list of paired-verifier result keys consumed by admission (Plan 207 mirrors it)"
  - Public Rindle.ValidatePhase133Reconciliation.plan123_authority_keys/0 shared by validator and writer
  - Writer new_journal/3 bound to exact plan123_authority_keys/0 set equality with spent p126/p166/p168/p170 rejection
  - plan203_fixture!/0 disposable green chain, paired verifier shim with mode file, migrated negatives
affects: [133-207, 133-209, 133-121, 133-122, 133-123]
requirements-completed: []
requirements_completed: []
requirements_pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
unresolved_edge_rows: 11
qualification_credit: 0
production_writer_modified: true
production_validator_modified: true
canonical_receipt_raw_sha256: 1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4
baseline_test_count: 129
final_test_count: 131
final_failures: 0
tasks_completed: 2
tasks_total: 2
plan_head_before: 4cd12a1b4719ca7fd42bdcb89fb86dd0560269c3
plan_head_after: e3aa7e90a9a71e7a4b2a013ecdf2c18fff570754
commits: 3
actuals:
  tokens: 18650
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns: [Task-bounded Port subprocess with output cap, verifier result bound to independently recomputed receipt digests, single shared authority key list]
key-files:
  created: [.planning/phases/133-evidence-charter-and-live-truth/133-206-SUMMARY.md]
  modified:
    - scripts/maintainer/validate_phase_133_reconciliation.exs
    - scripts/maintainer/phase_133_plan118_commit.exs
    - test/install_smoke/phase_133_reconciliation_test.exs
decisions:
  - "Plan 203 is the only current authority for admission and the writer. Plan 126 is reachable only through validate_historical126. Plan 166/168/170 identities are spent and rejected."
  - "plan123_authority_keys/0 is the exact 22-key set that current admission actually emits. That is the 15 keys named in the plan interface plus the seven frozen census/review/security/inventory/validation artifact digests, which the Plan 121 authority map has always carried."
  - "The paired verifier's exit status is never trusted on its own. Its single JSON line must match status, branch, fixture_only, credit, source and 14 digests, each recomputed from the receipt bytes."
  - "Preparation status `ready` and outcome `attempt_count` follow the real Plan 203 schema (phase_133_qualification_203.mjs), not the plan's paraphrase."
metrics:
  completed: 2026-10-14
  duration: "~60 min"
---

# Phase 133 Plan 206: Plan 203 Admission and Writer Migration Summary

Current Plan 121 admission and the Plan 123 writer now accept only the Plan 203 exact-source qualification identity. Admission calls the published paired verifier with `verify-qualification --preparation <abs> --observation <abs>`, bounded to 120 s and 1 MiB. It then requires the verifier's JSON digests to equal digests it recomputes from the receipt bytes. The writer admits a candidate only if its authority keys exactly equal `plan123_authority_keys/0`. A disposable Plan 203 green chain now runs through Plan 121, Plan 122 (preflight/candidate), Plan 123 (preterminal and terminal) and reaches the writer's journal reservation, then recovers byte-exact. This reverses the Plan 202 blocker. Fixture green grants no credit: all five IDs stay Pending and qualification credit is 0.

## What changed

**Validator (`validate_phase_133_reconciliation.exs`)**
- `plan121_paths/0` (current mode) drops the six p170 entries and adds the eight Plan 203 receipts: `p203_preparation`, `p203_collection_observation`, `p203_qualification_authorization`, `p203_qualification_attempt`, `p203_consumption` (the `.started` sentinel), `p203_local_gates`, `p203_outcome`, `p203_terminal_observation`.
- `plan121_authority_map/2` adds `p203_supply_sha256` and `p203_producer_sha256`, taken from the preparation's `supply_sha256`/`producer_sha256` (via `plan203_authority_extras/3`).
- `validate_plan121_current_authority/3` reads its source from the Plan 203 preparation and calls `plan203_qualification_gate/3`. Its error strings now name Plan 203.
- `plan203_qualification_gate/3`:
  - Keeps the Plan 155 supply/route checks (96/96 and the two pinned report digests).
  - Requires all eight receipts to carry plan 133-203 and schema 1, the exact source sha/tree, zero credit, all five IDs Pending, the 11 edge rows and `fixture_only: false`.
  - Checks the full preparation → authorization → consumption → marker → outcome binding chain. LOCAL-GATES must equal OUTCOME, and the outcome must be `locally_qualified` with `attempt_count` 1 and `first_red` null.
  - Then invokes the verifier.
- `invoke_plan203_qualification_verifier/2`:
  - Runs `node <root>/scripts/maintainer/phase_133_qualification_203_verify.mjs` with the paired absolute arguments through a `Port` inside `Task.async`.
  - Enforces `Task.yield/Task.shutdown` at 120_000 ms and a 1_048_576-byte stdout cap. On timeout or cap overflow it kills the OS process.
  - In-process callers can only shorten the time bound, never lengthen it.
- `plan203_verifier_result/5`:
  - Requires exactly one JSON object containing every key in `@plan203_verifier_keys`.
  - Requires `status: verified_locally_qualified`, `branch: locally_qualified`, `fixture_only === false`, `qualification_credit === 0`, and the source sha/tree.
  - Checks preparation/authorization/gates/outcome report digests, preparation/authorization/consumption/gates/outcome/observation raw digests, supply/producer, and also `attempt_marker_sha256` and `collection_observation_sha256`, all against values recomputed locally.
- `@plan203_verifier_keys` holds the 19 consumed keys verbatim from the plan interface. `def plan123_authority_keys/0` is public.
- Removed `plan170_supply_and_gates/3` and `invoke_plan170_qualification_verifier/1`. `validate_plan121_legacy_authority` and `validate_historical126` are untouched.

**Writer (`phase_133_plan118_commit.exs`)**
- Removed `@fresh_authorities`. `new_journal/3` now requires `Enum.sort(Map.keys(authorities)) == Rindle.ValidatePhase133Reconciliation.plan123_authority_keys()` and every value to be 64 lowercase hex.
- The spent-prefix list adds `p166_`, `p168_`, `p170_`; `p126_` was already there. The new error reads: "Plan 123 requires exact source, Plan 155 report/artifact digests, the exact Plan 203 qualification digest set, and Plan 121 authority; spent Plan 126/166/168/170 keys are rejected".
- `transact/3` ordering, journal format, terminal proof binding, recovery and rollback are unchanged.

**Tests (`phase_133_reconciliation_test.exs`)**
- `plan203_fixture!/0` builds the chain on `plan168_fixture!/0` with real-schema receipts (sealed through `redigest_report!`).
- `plan203_verifier_shim/0`:
  - Exits 2 unless argv is exactly the paired absolute-path form under the fixture root.
  - Records its argv to `plan203-verifier-invoked`, recomputes digests from the receipt bytes and prints one JSON line.
  - Takes a `plan203-verifier-mode` file that drives the status/fixture_only/credit/exit1/timeout/oversize/nonjson/twojson/source_tree/digest:/missing: variants.
- `mutate_receipt!/4` helper: mutate a receipt, reseal it, refresh the authority, and return a restore function. `refresh_authority!/1` adds the p203 extras.
- `:plan206_admission` tracer: green chain through 121 → 122 (:preflight, :candidate) → 123 (:preterminal). The shim argv is asserted exactly. `plan123_authority_keys/0` equals the sorted keys of the fixture's Plan 122 authority map. The writer reaches `{:interrupted, :journal_created}`, the journal's authorities equal the candidate's and include every key, and `recover/1` restores REQUIREMENTS bytes with all five IDs Pending. A second fixture passes 123 `:terminal`. On the actual checkout, `validate_plan121_authority(@repo_root)` returns `{:error, _}`.
- `:plan206_negative`:
  - A complete Plan 170 chain is rejected at 121/122/123 and by the writer.
  - Plan 203 receipt mutations (14 single mutations, first-red, shim removed) are rejected.
  - 30 untrusted verifier modes are rejected at 121, 122 (:preflight, :candidate) and 123 (:preterminal), each with its specific reason asserted. They are: 4 non-green statuses, fixture_only, credit, exit 1, timeout, oversize, non-JSON, two JSON, wrong source tree, 14 same-length digest substitutions, and 2 missing keys.
  - Rehashed wrong-source-tree receipts and missing marker/consumption/gates/outcome/terminal observation are rejected.
  - A red verifier stops before census input.
- The Plan 202 diagnostic (`:plan202_writer_boundary`) is replaced by "Plan 206 writer reserves the Plan 203 digest set and rejects the spent Plan 170 set before reservation". A further `:plan206_writer` test covers missing, extra, spent (p126/p166/p168/p170, both substituted and added) and malformed (63-char, uppercase, null) keys. All are rejected before the journal, with original bytes kept, all five IDs Pending, and canonical raw SHA `1cc60754…`.
- `Phase133Plan123TransactionTest.fixture!/0` builds its candidate from `plan123_authority_keys/0`. The p170 key mutations moved to p203, and the expected messages now name Plan 203.
- `plan170_fixture!/0` stays, only to build the complete Plan 170 chain for the rejection test.

## Verification

- RED (commit 2fa2c56f, unchanged production code, `--only plan206_admission`): 1 failure. `validate_plan121_authority` returned `{:error, "Plan 114 input is missing or has unsafe ancestry"}` because the current route still demanded the absent `133-170-PREFLIGHT.json` (the Plan 170 hardcoding).
- GREEN Task 1 (`--only plan206_admission`): 1 test, 0 failures. Acceptance greps:
  - `@fresh_authorities` in the writer: 0
  - `plan123_authority_keys` in the writer: 1
  - `phase_133_qualification_170.mjs` in the validator: 0
  - `--preparation` in the validator: 1
- Task 2 verify chain, run with the supported toolchain (27.3.4.15 / 1.17.3-otp-27):
  - Full focused file `--seed 0`: **131 tests, 0 failures**, no skips (844.9 s). An earlier full run had one ExUnit 180 s timeout in the unrelated async `Phase133Reconciliation42Test` "Plans 43-54 map" CLI test. That module passed alone (5 tests, 0 failures, 96 s), and the complete rerun was green.
  - `mix format --check-formatted` on the three files: pass.
  - `node --test --test-reporter=tap scripts/maintainer/phase_133_qualification_203.test.mjs` (existing Plan 201 suite, regression only): tests 40, pass 40, fail 0, skipped 0.
  - Inherited working-tree `test/planning_path_hygiene_test.exs` (read, not edited): 2 tests, 0 failures.
  - `./scripts/maintainer/automation_first_contract.sh`: see Self-Check.
- `grep -c plan202_writer_boundary` on the test file: 0. No orphan verifier processes remained after the timeout/oversize negatives.
- Canonical receipt: `shasum -a 256 133-NIGHTLY-EVIDENCE.json` = `1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4` (unchanged).
- `git diff --name-only 4cd12a1b..HEAD` lists only the three code/test files, plus this SUMMARY once committed.
- Inherited dirt: the sha256 of all 11 inherited paths (10 modified plus untracked `.planning/milestone.lock`) matches the values captured at plan start. None were staged or modified.
- Nothing ran against live sources: no Plan 203 producer, collector, guard, qualification, authorization or remote command. Every test uses a disposable tmp root.

## Deviations from Plan

**1. [Rule 1 - Plan inconsistency] `plan123_authority_keys/0` is 22 keys, not the 15 listed in the interface block.**
- **Found during:** Task 1.
- **Issue:** The authority map that current admission emits (Plan 121 authority → Plan 122 preflight/candidate `authorities`) has always included `census_a_sha256`, `census_b_sha256`, `census_sha256`, `review_sha256`, `security_sha256`, `inventory_sha256` and `validation_sha256`, because those come from `plan121_legacy_paths/0`. `validation_sha256` is also what the Plan 123 terminal append check binds. With the 15-key list, exact set equality would reject every real candidate, so the tracer could never reserve a journal. That contradicts the plan's own must-haves: exact equality, journal reservation for the real candidate, and the tracer assertion that the list equals the fixture's Plan 122 authority-map keys.
- **Fix:** The list is the 15 interface keys plus those 7 artifact digests, sorted. It is stricter than the old subset check, contains no spent prefix, and is still the single list shared by validator and writer.
- **Commit:** f70d03a4.

**2. [Rule 1 - Schema fidelity] Receipt field names follow the real Plan 203 producer.** The preparation status is `ready` (the plan said `preparation_only`, which is the verifier's collection *branch*/status name). Outcome/gates use `attempt_count: 1` (the plan said `attempts`). The attempt marker keeps `attempts: 1`, as in `phase_133_qualification_203.mjs`.

**3. [Rule 2 - Hardening] Extra checks beyond the listed set.** The verifier result must also bind `branch == locally_qualified`, `attempt_marker_sha256` (raw marker bytes) and `collection_observation_sha256` (raw collection observation bytes), and must contain every `@plan203_verifier_keys` key. Admission also requires `fixture_only: false` on every receipt.

**4. [Test-only knob] Timeout tests.** The 120 s bound is fixed in production. An in-process `Process` key `{Rindle.ValidatePhase133Reconciliation, :plan203_verifier_timeout_ms}` can only lower it (`min/2`). The CLI never sets it. The timeout negative uses 1 s against a shim that sleeps 5 s.

**5. Commit shape.** RED tracer (test), GREEN production plus formatting (feat), and Task 2 migration (test) are separate commits. No STATE/ROADMAP/state.json/REQUIREMENTS updates were made, per the orchestrator constraint (Plan 209 owns the inherited files). `roadmap.update-plan-progress` was not run.

## Requirements, edges and credit

- EVID-01, EVID-02, EVID-03, EVID-04 and TRUTH-08 all stay **Pending**. No requirement credit was granted.
- All **11** flagged edge rows stay unresolved: EVID-01 boundary/adjacency/empty/ordering/precision; EVID-02 unclassified; EVID-03 boundary/precision; EVID-04 idempotency/concurrency; TRUTH-08 unclassified. Fixture coverage is not edge acceptance.
- **qualification_credit: 0.** The census, remote decision and terminal journal still require independently verified exact-source local green from a real Plan 203 run (D-01/D-04/D-08/D-11/D-15/D-17).

## Threat Flags

None. The only new surface is the bounded local `node` subprocess named in the plan's threat register (T-133-544/546).

## Commits

- 2fa2c56f test(133-206): add failing Plan 203 chain tracer through admission and writer
- f70d03a4 feat(133-206): admit the Plan 203 chain through current authority and the writer
- e3aa7e90 test(133-206): migrate current-route and writer tests to the Plan 203 contract
- (this SUMMARY) docs(133-206): complete Plan 203 admission and writer migration plan

## Self-Check: PASSED

- FOUND: scripts/maintainer/validate_phase_133_reconciliation.exs, scripts/maintainer/phase_133_plan118_commit.exs, test/install_smoke/phase_133_reconciliation_test.exs, this SUMMARY
- FOUND commits (ancestors of HEAD): 2fa2c56f, f70d03a4, e3aa7e90
- `./scripts/maintainer/automation_first_contract.sh`: passed (CONTRACT_OK) after writing this SUMMARY
- Inherited 11 paths: sha256 match plan-start capture (`shasum -c` all OK)
- Canonical receipt raw SHA: 1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4
