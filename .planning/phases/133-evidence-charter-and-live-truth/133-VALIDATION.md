---
phase: "133"
slug: "evidence-charter-and-live-truth"
status: validated
nyquist_compliant: true
wave_0_complete: true
created: "2026-09-09"
revised: "2026-09-10"
---

# Phase 133 — Validation Strategy

> Executed per-task validation contract. Every Wave 0 artifact exists, every implementation task has executable behavioral coverage, and the exact-subject live receipt has been independently revalidated. The human publication checkpoint supplied authorization only and received no acceptance credit.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit plus repository-native Bash truth-table scripts |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `bash scripts/ci/test_nightly_summary_gate.sh && bash scripts/ci/test_nightly_dialyzer.sh && bash scripts/ci/test_nightly_incident.sh && bash scripts/ci/test_verify_nightly_run.sh` |
| **Full suite command** | `mix ci && bash scripts/maintainer/refactor_contract.sh && ./scripts/maintainer/automation_first_contract.sh` |
| **Clean-subject gate** | Detached-worktree census receipt plus `./scripts/maintainer/repo_hygiene_check.sh` at the ledger-recorded committed SHA |
| **Estimated runtime** | ~180 seconds excluding the bounded live supported-cell Nightly run |

## Sampling Rate

- After every task commit: run the task's focused Bash or ExUnit contract.
- After every plan wave: run all Phase 133 focused contracts affected by that wave and related existing policy tests.
- Before live dispatch: validate the final ledger and repository hygiene in an isolated detached worktree at its committed subject SHA.
- Final live gate: automated remote-ref/SHA preflight, first-attempt diagnostic Nightly collection, and receipt revalidation; human publication authorization is never acceptance evidence.
- Any listed failure direction halts the task; no human observation can convert red or missing evidence to green.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Test Type | Automated Command | Failure Direction | File State |
|---------|------|------|-------------|------------|-----------|-------------------|------------------|------------|
| 133-01-01 | 01 | 1 | EVID-01 | T-133-01 | tracer contract | `mix test test/install_smoke/evidence_census_test.exs` | Halt on nonzero or zero tests; validator/schema tracer remains red. | W0 create-first |
| 133-01-02 | 01 | 1 | EVID-01 | T-133-01/T-133-02 | mutation contract | `mix test test/install_smoke/evidence_census_test.exs` | Halt on nonzero, zero tests, unstable serialization, identity substitution, or missing transition rejection. | W0 create-first |
| 133-02-01 | 02 | 1 | EVID-02 | T-133-05/T-133-07 | shell/unit | `bash scripts/ci/test_nightly_dialyzer.sh` | Halt on nonzero, any FAIL row, or zero cases; do not modify the workflow. | W0 create-first |
| 133-02-02 | 02 | 1 | EVID-02 | T-133-05/T-133-06 | shell + structural | `bash scripts/ci/test_nightly_dialyzer.sh && mix test test/install_smoke/ci_cache_hygiene_test.exs test/install_smoke/dialyzer_ignore_policy_test.exs` | Halt on nonzero, zero cases/tests, major-only cache identity, one-mode topology, or suppression drift. | partial existing |
| 133-03-01 | 03 | 2 | EVID-03 | T-133-09/T-133-10 | truth table | `bash scripts/ci/test_nightly_summary_gate.sh` | Halt on nonzero, any FAIL row, zero cases, or a false-green state. | W0 create-first |
| 133-03-02 | 03 | 2 | EVID-03 | T-133-09/T-133-11 | shell + parsed topology | `bash scripts/ci/test_nightly_summary_gate.sh && mix test test/install_smoke/nightly_policy_test.exs test/install_smoke/quality_signal_policy_test.exs test/install_smoke/ci_lane_split_test.exs` | Halt on nonzero, zero cases/tests, masked verdict, or CI identity/topology drift. | partial existing |
| 133-04-01 | 04 | 3 | EVID-04 | T-133-13/T-133-14 | fake-GitHub adapter | `bash scripts/ci/test_nightly_incident.sh` | Halt on nonzero, any FAIL row, zero cases, duplicate selection, or unauthorized mutation. | W0 create-first |
| 133-04-02 | 04 | 3 | EVID-04 | T-133-13/T-133-15/T-133-16 | shell + parsed topology | `bash scripts/ci/test_nightly_incident.sh && mix test test/install_smoke/nightly_policy_test.exs test/install_smoke/quality_signal_policy_test.exs test/install_smoke/ci_lane_split_test.exs` | Halt on nonzero, zero cases/tests, dispatch mutation, stale-main closure, or permission/topology drift. | partial existing |
| 133-05-01 | 05 | 4 | TRUTH-08 | T-133-17/T-133-19 | derived-authority contract | `mix test test/install_smoke/live_truth_parity_test.exs --only derived_authority` | Halt on nonzero, zero tests, authority mismatch, malformed marker, or stale active claim. | W0 create-first |
| 133-05-02 | 05 | 4 | TRUTH-08 | T-133-18 | built-package contract | `mix test test/install_smoke/live_truth_parity_test.exs --only package_authority && mix test test/install_smoke/package_metadata_test.exs test/install_smoke/generated_app_smoke_test.exs` | Halt on nonzero, zero tests, missing unpacked provenance, or repository/prebuilt fallback. | partial existing |
| 133-06-01 | 06 | 5 | TRUTH-08 | T-133-21/T-133-22/T-133-23 | parity + adoption gate | `mix test test/install_smoke/live_truth_parity_test.exs --only derived_authority && bash scripts/maintainer/check_adoption_proof_matrix.sh` | Halt on nonzero, zero tests, unmarked contradiction, or prose-only package proof. | partial existing |
| 133-06-02 | 06 | 5 | EVID-01–04, TRUTH-08 | T-133-21–T-133-24 | full local + detached authority | Execute all four `<automated>` commands in Plan 06 Task 2 in order. | Halt on the first nonzero/zero-case result; preserve caller changes and keep the ledger unfrozen if detached SHA, hygiene, census, or transition validation fails. | W0 + existing |
| 133-07-01 | 07 | 6 | EVID-02–04 | T-133-25–T-133-28 | fake-GitHub collector | `bash scripts/ci/test_verify_nightly_run.sh` | Halt on nonzero, any FAIL row, zero cases, wrong-head acceptance, partial receipt, or forbidden mutation. | W0 create-first |
| 133-07-02 | 07 | 6 | authorization only | T-133-27 | blocking-human decision | No automated acceptance command; choose `publish` or stop. | `stop` halts with live evidence incomplete; `publish` only authorizes Task 3 and supplies no acceptance credit. | N/A checkpoint |
| 133-07-03 | 07 | 6 | EVID-01–04, TRUTH-08 | T-133-25–T-133-28 | remote preflight + receipt | Execute Plan 07 Task 3's exact `git ls-remote`, `preflight`, and `verify-receipt` command. | Halt on auth/API/timeout, remote SHA mismatch, rerun/partial/red evidence, or changed incident snapshot; do not accept publication itself as proof. | W0 + live output |

*Execution result: all 14 automated implementation tasks are ✅ green. Task 133-07-02 remains authorization-only and is intentionally excluded from acceptance credit.*

## Wave 0 Requirements

- [x] `test/install_smoke/evidence_census_test.exs` — schema, exact-head, deduplication, disposition, stable-ID transition, and mutation fixtures.
- [x] `scripts/ci/test_nightly_dialyzer.sh` — fresh, restored, stale, corrupt, build-failure, and genuine-warning fixtures.
- [x] `scripts/ci/test_nightly_summary_gate.sh` — complete result/applicability truth table.
- [x] `scripts/ci/test_nightly_incident.sh` — scheduled-only fake-`gh` lifecycle tests.
- [x] `test/install_smoke/nightly_policy_test.exs` — parsed topology, permissions, and verdict/lifecycle wiring.
- [x] `test/install_smoke/live_truth_parity_test.exs` — version, lane, package-proof, and exact historical-marker fixtures.
- [x] `scripts/ci/test_verify_nightly_run.sh` — remote preflight, exact-run, partial-state, and nonmutation fixtures.

## Manual-Only Verifications

None. The sole human checkpoint authorizes a reversible publication action; it does not verify behavior or satisfy a requirement.

## Validation Sign-Off

- [x] Every implementation task has an automated command and explicit failure direction.
- [x] All actual waves and all 14 implementation tasks are mapped; the added authorization checkpoint is mapped separately.
- [x] Sampling continuity has no unverified implementation-task gap.
- [x] Wave 0 creation ownership is explicit for every missing test artifact.
- [x] No watch-mode flags or vacuous human acceptance.
- [x] Clean-worktree authority is isolated from the user's unrelated `.planning/config.json` edit.
- [x] Every Wave 0 artifact exists and ran non-vacuously; `wave_0_complete: true` reflects executed state.

## Post-Execution Audit Trail

Audited 2026-09-10 from the shared worktree without modifying implementation files. The pre-existing `.planning/config.json` edit and untracked `.planning/milestone.lock` / `.planning/state.json` were preserved.

| Scope | Executed command/evidence | Result |
|-------|---------------------------|--------|
| Strict Nightly verdict | `bash scripts/ci/test_nightly_summary_gate.sh` | ✅ 49 passed, 0 failed |
| Fresh/restored Dialyzer policy | `bash scripts/ci/test_nightly_dialyzer.sh` | ✅ 24 passed, 0 failed |
| Rolling incident lifecycle | `bash scripts/ci/test_nightly_incident.sh` | ✅ 22 passed, 0 failed |
| Exact-run collector mutations | `bash scripts/ci/test_verify_nightly_run.sh` | ✅ 28 passed, 0 failed |
| Phase-focused ExUnit contracts | `mix test test/install_smoke/evidence_census_test.exs test/install_smoke/nightly_policy_test.exs test/install_smoke/live_truth_parity_test.exs test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs test/install_smoke/generated_app_smoke_test.exs` | ✅ 84 tests, 0 failures, 17 excluded on documented diagnostic Elixir 1.19.5 / OTP 28.4.1 |
| Derived truth + real package authority | `bash scripts/maintainer/check_adoption_proof_matrix.sh` | ✅ 6 derived-authority tests and 4 package-authority tests passed after repository-owned MinIO bootstrap |
| Exact remote subject and receipt | Plan 07 Task 3 `git ls-remote` + `preflight` + `verify-receipt` command | ✅ ref `phase-133-evidence-4f83e153eb7e` equals subject `4f83e153eb7e19f3e1e3ca43b40eefdfee87a4d2`; run `34432289094`, attempt 1 accepted |
| Census ledger | `133-EVIDENCE-CENSUS.json` plus collector/validator evidence recorded by Plans 06–07 | ✅ 12 taxonomy dimensions, 12 candidates, 8 explicit transitions, same subject SHA |
| Full preservation gates | Plan 07 execution receipts in `133-07-SUMMARY.md` | ✅ `mix ci` (1,460 tests, 0 failures), 97 contract tests, automation-first contract, and clean detached hygiene |

The first package-authority audit attempt failed because local MinIO was not running. This was an environment prerequisite, not an implementation failure; `scripts/ensure_minio.sh` established the repository-owned service and the unchanged behavioral test then passed. Supported Elixir 1.17 / OTP 27 acceptance comes from the exact live Nightly receipt, not the newer local diagnostic toolchain.

**Approval:** validation executed and audited; Phase 133 is Nyquist-compliant with no uncovered implementation requirement.

## Gap-Closure Validation Addendum (Plans 08–10)

The completed sign-off and post-execution audit above are retained as historical evidence for executed Plans 01–07. Plans 08–10 closed the three adversarial authority gaps, and the five implementation tasks below now receive green credit from non-vacuous automated execution in Waves 7–9.

| Task ID | Plan | Wave | Requirement | Threat Ref | Test Type | Automated Command | Failure Direction | File State |
|---------|------|------|-------------|------------|-----------|-------------------|------------------|------------|
| 133-08-01 | 08 | 7 | TRUTH-08 | T-133-29/T-133-30/T-133-31 | derived package-authority regression | `mix test test/install_smoke/live_truth_parity_test.exs --only package_authority` | Halt on nonzero, zero tests, or acceptance of the forged `validated` receipt. | ✅ focused adversarial test passed |
| 133-09-01 | 09 | 8 | EVID-03, EVID-04 | T-133-32/T-133-33/T-133-36/T-133-37 | fake-GitHub canonical mutation matrix | `bash scripts/ci/test_verify_nightly_run.sh` | Halt on nonzero, any `FAIL` case, zero passed cases, or acceptance of any remote-field mutation. | ✅ 84-case matrix passed |
| 133-09-02 | 09 | 8 | EVID-01, EVID-04, TRUTH-08 | T-133-32/T-133-34/T-133-35/T-133-36/T-133-37 | incident/local-authority mutation matrix | `bash scripts/ci/test_verify_nightly_run.sh` | Halt on nonzero, any `FAIL` case, zero passed cases, acceptance of a local/incident mutation, or emission of a mutating `gh` call. | ✅ 84-case matrix passed |
| 133-10-01 | 10 | 9 | EVID-02 | T-133-38/T-133-40/T-133-41 | setup-beam boundary fixtures | `bash scripts/ci/test_verify_nightly_run.sh` | Halt on nonzero, any `FAIL` case, zero passed cases, or acceptance of 11.17, 1.170, or 127 log evidence. | ✅ 84-case matrix passed |
| 133-10-02 | 10 | 9 | EVID-02 | T-133-38/T-133-39/T-133-40/T-133-41 | receipt boundary mutation matrix | `bash scripts/ci/test_verify_nightly_run.sh` | Halt on nonzero, any `FAIL` case, zero passed cases, or verification of any receipt-only near-match mutation. | ✅ 84-case matrix passed |

### Gap-Closure Sign-Off

- [x] All five gap-closure implementation tasks ran their exact automated commands non-vacuously.
- [x] Wave 7 rejects caller-forged package authority while retaining real generated-consumer provenance.
- [x] Wave 8 rejects every remote, incident, and local-authority mutation and emits no forbidden mutation command.
- [x] Wave 9 rejects all named toolchain near-matches in both collection and receipt revalidation.
- [x] The refreshed Nyquist audit covers 5/5 requirements and 19/19 automated implementation tasks; human authorization or observation supplies no acceptance credit.

## Validation Audit 2026-09-10 (Gap Closure)

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 5 |
| Escalated | 0 |
## Pending Gap-Closure Validation Addendum (Plans 11–17)

Plans 01–10 remain the immutable historical 19/19 green record above. The records below describe unexecuted Plans 11–17 only; every runnable command/failure pair stays pending, and the Plan 17 authorization checkpoint carries no acceptance credit.

<pending-validation key="133-11-01:1">
<automated>
mix test test/install_smoke/phase_133_reconciliation_test.exs
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, the valid isolated fixture fails, any historical-byte/pair-cardinality/exact-text/roadmap/premature-green negative fixture passes, or a failure lacks its bounded diagnostic
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-11-01:2">
<automated>
MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/validate_phase_133_reconciliation.exs --root .
</automated>
<fails_when>
non-zero exit, any production input is missing/untracked/malformed, the historical prefix differs by one byte from its recorded committed preimage, a task or plan-level verification pair has a duplicate/missing/extra or inexact mapping, Plans 11-17 are not all pending without green credit, or ROADMAP does not retain Plans 01-10 and individually list unchecked Plans 11-17 at 10/17 executed
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-11-01:3">
<automated>
./scripts/maintainer/automation_first_contract.sh
</automated>
<fails_when>
non-zero exit, any active implementation task lacks executable evidence or a concrete failure direction, a pending task receives green credit, or human authorization is counted as acceptance
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-11-02:1">
<automated>
bash scripts/ci/test_nightly_dialyzer.sh
</automated>
<fails_when>
non-zero exit, any FAIL line, zero passed cases, or the approved fresh/restored reset case does not remove and rebuild only its PLT child
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-11-03:1">
<automated>
bash scripts/ci/test_nightly_dialyzer.sh &amp;&amp; shellcheck -S warning scripts/ci/run_nightly_dialyzer.sh scripts/ci/test_nightly_dialyzer.sh
</automated>
<fails_when>
non-zero exit, any FAIL line, zero passed cases, any escape sentinel is removed, fake Mix runs for a rejected path, or ShellCheck reports warning-or-higher findings
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-12-01:1">
<automated>
bash scripts/ci/test_verify_nightly_run.sh
</automated>
<fails_when>
non-zero exit, any FAIL line, zero passed cases, old-runs-first aborts before the later exact run, or a nonmatching run ID reaches watch/view
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-12-02:1">
<automated>
bash scripts/ci/test_verify_nightly_run.sh &amp;&amp; shellcheck -S warning scripts/ci/verify_nightly_run.sh scripts/ci/test_verify_nightly_run.sh
</automated>
<fails_when>
non-zero exit, any FAIL line, zero passed cases, duplicate matches reach watch/view, timeout leaves a receipt, repeated verification emits mutation argv, or ShellCheck reports warning-or-higher findings
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-13-01:1">
<automated>
mix test test/install_smoke/evidence_census_test.exs
</automated>
<fails_when>
non-zero exit, the ExUnit summary reports zero tests, a mixed-applicability detector mutation validates, or an unallowlisted/empty-reason inapplicability validates
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-13-02:1">
<automated>
mix test test/install_smoke/evidence_census_test.exs &amp;&amp; ./scripts/maintainer/automation_first_contract.sh
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, any traversal/symlink mutation validates, canonical aliases produce distinct candidate identity, or the automation-first contract reports an active requirement without executable evidence
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-14-01:1">
<automated>
mix test test/install_smoke/live_truth_parity_test.exs --only package_authority
</automated>
<fails_when>
non-zero exit, zero selected tests, the happy path uses the arbitrary-directory fixture, any digest/source/argv/result is accepted without independent recomputation, or a repository/prebuilt fallback passes
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-14-02:1">
<automated>
mix test test/install_smoke/live_truth_parity_test.exs --only package_authority &amp;&amp; ./scripts/maintainer/check_adoption_proof_matrix.sh
</automated>
<fails_when>
non-zero exit, zero package-authority tests, any caller name/kind/authorization mutation passes, synthetic evidence authorizes 1.0, or the active adoption matrix contradicts derived authority
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-15-01:1">
<automated>
mix test test/install_smoke/live_truth_parity_test.exs --only derived_authority
</automated>
<fails_when>
non-zero exit, zero selected tests, comment-only/dead/duplicate/mismatched fixtures derive true, or the real parsed release workflow does not derive exact-SHA coupling
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-15-02:1">
<automated>
mix test test/install_smoke/live_truth_parity_test.exs --only derived_authority &amp;&amp; bash scripts/setup_branch_protection.sh --print-expected-json | jq -e '.required_status_checks.contexts == ["CI Summary"]' &amp;&amp; shellcheck -S warning scripts/setup_branch_protection.sh
</automated>
<fails_when>
non-zero exit, zero derived-authority tests, expected JSON contains zero/multiple/wrong contexts, any fixture passes on inert source text, or ShellCheck reports warning-or-higher findings
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-16-01:1">
<automated>
bash scripts/ci/test_verify_nightly_run.sh
</automated>
<fails_when>
non-zero exit, any FAIL line, zero passed cases, local authority contains status-only objects, ledger bytes come from project_root, or regenerated detailed authority differs without rejection
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-16-02:1">
<automated>
bash scripts/ci/test_verify_nightly_run.sh &amp;&amp; shellcheck -S warning scripts/ci/verify_nightly_run.sh scripts/ci/test_verify_nightly_run.sh
</automated>
<fails_when>
non-zero exit, any FAIL line, zero passed cases, any local-authority mutation verifies, caller-worktree bytes affect verdict, mutation argv is emitted, partial receipt remains, or ShellCheck reports warning-or-higher findings
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-17-01:1">
<automated>
subject_sha="$(jq -er '.subject_sha' .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json)" &amp;&amp; temp_root="$(mktemp -d "${TMPDIR:-/tmp}/phase133-ledger-check.XXXXXX")" &amp;&amp; trap 'git worktree remove --force "$temp_root/subject" &gt;/dev/null 2&gt;&amp;1 || true; rm -rf -- "$temp_root"' EXIT &amp;&amp; git worktree add --detach "$temp_root/subject" "$subject_sha" &gt;/dev/null &amp;&amp; MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/evidence_census.exs --root "$temp_root/subject" --ledger .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json --output "$temp_root/receipt.json" --source-sha "$subject_sha" &amp;&amp; MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/validate_evidence_census.exs --root "$temp_root/subject" --ledger .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json --receipt "$temp_root/receipt.json"
</automated>
<fails_when>
non-zero exit, invalid/missing subject SHA, dirty or unmaterializable subject, incomplete taxonomy/detector/candidate/disposition/transition authority, escaped observation, or nondeterministic receipt
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-17-02:1">
<automated>
subject_sha="$(jq -er '.subject_sha' .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json)" &amp;&amp; git cat-file -e "${subject_sha}^{commit}" &amp;&amp; test -z "$(git status --porcelain --untracked-files=no -- . ':!.planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json' ':!.planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json')"
</automated>
<fails_when>
non-zero exit, ledger subject is not an existing commit, or tracked source outside the two evidence artifacts is dirty
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>authorization-only</acceptance-credit>
</pending-validation>

<pending-validation key="133-17-03:1">
<automated>
bash scripts/ci/test_nightly_dialyzer.sh &amp;&amp; bash scripts/ci/test_nightly_summary_gate.sh &amp;&amp; bash scripts/ci/test_nightly_incident.sh &amp;&amp; bash scripts/ci/test_verify_nightly_run.sh &amp;&amp; mix test test/install_smoke/evidence_census_test.exs test/install_smoke/nightly_policy_test.exs test/install_smoke/live_truth_parity_test.exs test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs test/install_smoke/generated_app_smoke_test.exs &amp;&amp; bash scripts/maintainer/check_adoption_proof_matrix.sh
</automated>
<fails_when>
non-zero exit, any Bash FAIL row, zero shell cases or ExUnit tests, or any census, Dialyzer, Nightly verdict, incident, receipt, live-truth, release, package, generated-consumer, or adoption authority check fails
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-17-03:2">
<automated>
mix ci
</automated>
<fails_when>
non-zero exit, compilation/format/Credo/Doctor/quality-signal failure, zero default-suite tests, any test failure, or incomplete repository CI output
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-17-03:3">
<automated>
bash scripts/maintainer/refactor_contract.sh
</automated>
<fails_when>
non-zero exit, zero contract tests, any public API/schema/telemetry/error/release contract failure, or the script reports an incomplete required command
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-17-03:4">
<automated>
receipt=.planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json &amp;&amp; subject_sha="$(jq -er '.subject_sha' "$receipt")" &amp;&amp; remote_ref="phase-133-evidence-$(printf '%s' "$subject_sha" | cut -c1-12)" &amp;&amp; test "$(git ls-remote --exit-code origin "refs/heads/$remote_ref" | awk 'NR == 1 {print $1}')" = "$subject_sha" &amp;&amp; bash scripts/ci/verify_nightly_run.sh preflight --repo szTheory/rindle --workflow nightly.yml --ref "$remote_ref" --expected-sha "$subject_sha" &amp;&amp; bash scripts/ci/verify_nightly_run.sh verify-receipt --repo szTheory/rindle --workflow nightly.yml --ref "$remote_ref" --expected-sha "$subject_sha" --receipt "$receipt"
</automated>
<fails_when>
non-zero exit, auth/API/timeout error, remote ref mismatch, non-first or ambiguous run, incomplete/non-green job or Dialyzer evidence, incident drift, mutable/mismatched ledger authority, package/release truth failure, or stale/foreign receipt
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-17-03:5">
<automated>
./scripts/maintainer/automation_first_contract.sh
</automated>
<fails_when>
non-zero exit, any active implementation task lacks executable evidence or a concrete failure direction, any pending Plan 11-17 task is credited green before execution, or human authorization is counted as acceptance
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-17-plan-verification:1">
<automated>
bash scripts/ci/test_nightly_dialyzer.sh &amp;&amp; bash scripts/ci/test_nightly_summary_gate.sh &amp;&amp; bash scripts/ci/test_nightly_incident.sh &amp;&amp; bash scripts/ci/test_verify_nightly_run.sh &amp;&amp; mix test test/install_smoke/evidence_census_test.exs test/install_smoke/nightly_policy_test.exs test/install_smoke/live_truth_parity_test.exs test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs test/install_smoke/generated_app_smoke_test.exs &amp;&amp; bash scripts/maintainer/check_adoption_proof_matrix.sh
</automated>
<fails_when>
non-zero exit, any Bash FAIL row, zero shell cases or ExUnit tests, or any focused authority check fails
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-17-plan-verification:2">
<automated>
mix ci
</automated>
<fails_when>
non-zero exit, any repository CI stage/test fails, zero tests, or required CI output is incomplete
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-17-plan-verification:3">
<automated>
bash scripts/maintainer/refactor_contract.sh
</automated>
<fails_when>
non-zero exit, zero contract tests, any preservation contract fails, or a required command is incomplete
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-17-plan-verification:4">
<automated>
receipt=.planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json &amp;&amp; subject_sha="$(jq -er '.subject_sha' "$receipt")" &amp;&amp; remote_ref="phase-133-evidence-$(printf '%s' "$subject_sha" | cut -c1-12)" &amp;&amp; test "$(git ls-remote --exit-code origin "refs/heads/$remote_ref" | awk 'NR == 1 {print $1}')" = "$subject_sha" &amp;&amp; bash scripts/ci/verify_nightly_run.sh preflight --repo szTheory/rindle --workflow nightly.yml --ref "$remote_ref" --expected-sha "$subject_sha" &amp;&amp; bash scripts/ci/verify_nightly_run.sh verify-receipt --repo szTheory/rindle --workflow nightly.yml --ref "$remote_ref" --expected-sha "$subject_sha" --receipt "$receipt"
</automated>
<fails_when>
non-zero exit, remote identity mismatch, incomplete/non-green exact-run authority, incident drift, mutable local authority, or stale/foreign receipt
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-17-plan-verification:5">
<automated>
./scripts/maintainer/automation_first_contract.sh
</automated>
<fails_when>
non-zero exit, missing executable validation/failure direction, premature green credit, or human-only acceptance
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

## Post-Execution Nyquist Audit — Plans 11–17

Audited 2026-09-10 after all seven gap-closure plans completed. The pending-validation addendum above is the immutable pre-execution snapshot required by Plan 11; it is retained as historical transition evidence and does not describe the current execution state.

Current executable evidence supports all 27 mapped command/failure pairs. The production reconciliation command for `133-11-01:2` now validates the active `17/17 plans executed; 0 pending gap closure` roadmap state and requires all 17 summaries to remain `status: complete`. Its fixture overrides continue to validate the immutable `10/17` pre-execution snapshot and byte-exact pending addendum without treating those historical records as current state.

| Plan | Requirement(s) | Current executable evidence | Result |
|------|----------------|-----------------------------|--------|
| 11 | EVID-02, TRUTH-08 | 34-case PLT safety matrix; ShellCheck; 19-test isolated reconciliation suite; completed-state production reconciliation; automation-first contract | ✅ green |
| 12 | EVID-02, EVID-04 | 109-case exact-run selector/receipt matrix; ShellCheck | ✅ green |
| 13 | EVID-01 | 15-test census authority/containment suite; automation-first contract | ✅ green |
| 14 | TRUTH-08 | 4 package-authority tests using the real generated consumer; adoption-proof gate | ✅ green |
| 15 | TRUTH-08, EVID-03 | 12 derived-authority tests; structured `CI Summary` policy projection; ShellCheck | ✅ green |
| 16 | EVID-01, EVID-02, TRUTH-08 | 109-case immutable local-authority matrix; ShellCheck | ✅ green |
| 17 | EVID-01–04, TRUTH-08 | Detached census validation; 113 focused ExUnit tests; focused Bash gates; `mix ci` (1,490 tests, 0 failures, 4 skipped); 97 refactor-contract tests; exact receipt verification for subject `08d2f4f55fb2f59319a371de56606b2e925e6d54`, run `34550391882`, attempt 1; automation-first contract | ✅ green; publication approval received no acceptance credit |

### Current Audit Verdict

- **Resolved mappings:** 27/27
- **Escalated mappings:** 0/27
- **Classification:** READY FOR RE-AUDIT — active roadmap truth matches the completed plan set.
- **Remediation evidence:** the completed-state regression rejects any nonzero pending count, while the original 19-test fixture and pending addendum retain the historical pre-execution contract unchanged.

The appended post-execution audit is the authoritative current status; the earlier pre-execution addendum remains historical transition evidence only.

## Definitive Re-Audit 2026-09-10

Re-audited after the targeted completed-state reconciliation fix without modifying implementation files. The immutable historical prefix and pre-execution pending addendum remain byte-preserved; the current production path is evaluated separately as completed state.

| Scope | Current execution result |
|-------|--------------------------|
| Completed-state reconciliation | `mix test test/install_smoke/phase_133_reconciliation_test.exs test/install_smoke/phase_133_completed_validation_test.exs` — 20 tests, 0 failures |
| Production reconciliation | `MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/validate_phase_133_reconciliation.exs --root .` — 17 completed, 0 pending plans, 27 historical verification pairs |
| Planning-path integration | Focused reconciliation plus `test/planning_path_hygiene_test.exs` — 21 tests, 0 failures after routing the completed-state regression through the validator CLI |
| Dialyzer safety | 34 cases, 0 failures; ShellCheck passed |
| Exact-run and local-authority mutation matrix | 109 cases, 0 failures; ShellCheck passed |
| Strict Nightly verdict and incident lifecycle | 49 + 22 cases, 0 failures |
| Census and truth authority | 15 census tests, 12 derived-authority tests, 4 real package-authority tests; adoption and `CI Summary` policy projections passed |
| Focused Phase 133 aggregate | 94 tests, 0 failures, 17 excluded |
| Detached exact-subject census | Subject `08d2f4f55fb2f59319a371de56606b2e925e6d54` validated from a detached worktree |
| Remote exact-subject receipt | Ref SHA matched; run `34550391882`, attempt 1 revalidated successfully |
| Repository gates | `mix ci` — 1,491 tests, 0 failures, 4 skipped; `refactor_contract.sh` — 97 tests, 0 failures; automation-first contract passed |

### Definitive Verdict

- **Resolved mappings:** 27/27
- **Escalated mappings:** 0/27
- **Classification:** NYQUIST-COMPLIANT
- The Plan 17 publication decision remains authorization-only and receives no acceptance credit.
- The first repository-gate attempt exposed a test-only planning-path hygiene violation. The regression now asserts the production validator's exact CLI result; the unchanged requirement and full repository gate both pass.
## Pending Gap-Closure Validation Addendum (Plans 18–22)

Plans 01–17 remain immutable historical validation. The records below preserve the planned verification pairs for Plans 18–22 after execution; every pair remains pending evidence history, and the Plan 22 checkpoint carries authorization-only acceptance credit.

<pending-validation key="133-18-01:1">
<automated>
bash scripts/ci/test_verify_nightly_run.sh
</automated>
<fails_when>
non-zero exit, any `FAIL` row, or the suite reports zero cases
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-18-02:1">
<automated>
bash scripts/ci/test_verify_nightly_run.sh &amp;&amp; shellcheck -S warning scripts/ci/verify_nightly_run.sh scripts/ci/test_verify_nightly_run.sh
</automated>
<fails_when>
non-zero exit, any `FAIL` row, zero cases, or a ShellCheck warning-or-higher diagnostic
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-19-01:1">
<automated>
mix test test/install_smoke/nightly_policy_test.exs
</automated>
<fails_when>
non-zero exit, the ExUnit summary reports zero tests, the producer can mutate issues, a scheduled verdict is not uploaded before concurrency, or the drainer group depends on run identity
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-19-02:1">
<automated>
bash scripts/ci/test_nightly_incident.sh &amp;&amp; shellcheck -S warning scripts/ci/eval_nightly_incident.sh scripts/ci/manage_nightly_incident.sh scripts/ci/test_nightly_incident.sh
</automated>
<fails_when>
non-zero exit, any `FAIL` row, zero cases, the three-overlap case loses or duplicates B, a no-op green writes an acknowledgement, stale preimage advances replay, or ShellCheck reports a warning-or-higher diagnostic
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-20-01:1">
<automated>
mix test test/install_smoke/evidence_census_test.exs
</automated>
<fails_when>
non-zero exit, or the ExUnit summary reports zero tests
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-20-02:1">
<automated>
mix test test/install_smoke/evidence_census_test.exs &amp;&amp; mix format --check-formatted scripts/maintainer/evidence_census.exs scripts/maintainer/validate_evidence_census.exs test/install_smoke/evidence_census_test.exs
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, or any file is not canonically formatted
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-21-01:1">
<automated>
mix test test/install_smoke/live_truth_parity_test.exs test/install_smoke/generated_app_smoke_test.exs
</automated>
<fails_when>
non-zero exit, or the ExUnit summary reports zero tests
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-21-02:1">
<automated>
mix test test/install_smoke/live_truth_parity_test.exs --only package_authority
</automated>
<fails_when>
non-zero exit, or the ExUnit summary reports zero tests
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-21-02:2">
<automated>
mix format --check-formatted test/install_smoke/support/generated_app_helper.ex scripts/maintainer/validate_live_truth.exs test/install_smoke/live_truth_parity_test.exs
</automated>
<fails_when>
non-zero exit or any changed Elixir file is not canonically formatted
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-21-03:1">
<automated>
mix test test/install_smoke/phase_133_reconciliation_test.exs test/install_smoke/phase_133_completed_validation_test.exs
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, any one of the 16 Wave 15 subsets or the execution-complete fixture fails, a named roadmap/summary/addendum/history mutation is accepted, or fixture-only 10/17 historical validation regresses
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-21-03:2">
<automated>
MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/validate_phase_133_reconciliation.exs --root .
</automated>
<fails_when>
non-zero exit, reported completed count does not equal the current summary-backed checked subset from 17 through 21, Phase detail and Progress counts/status disagree, Plan 22 is early, any Plan 18-22 input/mapping is missing or inexact, or Plans 01-17 history differs
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-21-03:3">
<automated>
./scripts/maintainer/automation_first_contract.sh
</automated>
<fails_when>
non-zero exit, any Plan 18-22 implementation task lacks executable evidence with a concrete failure direction, pending work receives green credit, or authorization is counted as acceptance
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-22-01:1">
<automated>
subject_sha="$(jq -er '.subject_sha' .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json)" &amp;&amp; temp_root="$(mktemp -d "${TMPDIR:-/tmp}/phase133-final-ledger.XXXXXX")" &amp;&amp; trap 'status=$?; cleanup_status=0; if [ -e "$temp_root/subject/.git" ] &amp;&amp; ! git worktree remove --force "$temp_root/subject" &gt;/dev/null 2&gt;&amp;1; then cleanup_status=1; fi; if ! rm -rf -- "$temp_root"; then cleanup_status=1; fi; if [ "$status" -ne 0 ]; then exit "$status"; fi; exit "$cleanup_status"' EXIT &amp;&amp; git worktree add --detach "$temp_root/subject" "$subject_sha" &gt;/dev/null &amp;&amp; MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/evidence_census.exs --root "$temp_root/subject" --ledger .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json --output "$temp_root/receipt.json" --source-sha "$subject_sha" &amp;&amp; MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/validate_evidence_census.exs --root "$temp_root/subject" --ledger .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json --receipt "$temp_root/receipt.json"
</automated>
<fails_when>
non-zero exit, the EXIT trap is absent before worktree registration, cleanup leaves a registered worktree/residue, escaped or missing detector input, foreign/dirty subject, incomplete taxonomy/candidate/disposition/transition authority, or nondeterministic receipt
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-22-02:1">
<automated>
subject_sha="$(jq -er '.subject_sha' .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json)" &amp;&amp; git cat-file -e "${subject_sha}^{commit}" &amp;&amp; remote_ref="phase-133-evidence-${subject_sha:0:12}" &amp;&amp; remote_existing="$(git ls-remote origin "refs/heads/$remote_ref")" &amp;&amp; test -z "$remote_existing"
</automated>
<fails_when>
non-zero exit, invalid ledger subject, or the supposedly unique remote ref already exists
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>authorization-only</acceptance-credit>
</pending-validation>

<pending-validation key="133-22-03:1">
<automated>
bash scripts/ci/test_verify_nightly_run.sh &amp;&amp; bash scripts/ci/test_nightly_incident.sh &amp;&amp; bash scripts/ci/test_nightly_summary_gate.sh &amp;&amp; bash scripts/ci/test_nightly_dialyzer.sh &amp;&amp; mix test test/install_smoke/evidence_census_test.exs test/install_smoke/nightly_policy_test.exs test/install_smoke/live_truth_parity_test.exs test/install_smoke/generated_app_smoke_test.exs test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs
</automated>
<fails_when>
non-zero exit, any Bash `FAIL` row, zero shell cases or ExUnit tests, or any dispatch, overlap, provenance, package-version, lifecycle, Nightly, release, or adoption mutation case fails
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-22-03:2">
<automated>
mix ci &amp;&amp; bash scripts/maintainer/refactor_contract.sh
</automated>
<fails_when>
non-zero exit, zero required tests, incomplete command output, or any public API/schema/telemetry/error/release preservation failure
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-22-03:3">
<automated>
MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/validate_phase_133_reconciliation.exs --root .
</automated>
<fails_when>
non-zero exit, output does not report exactly 21 completed and 1 pending before this summary exists, Plans 18-21 lack matching checked rows/complete summaries, Plan 22 is checked or summarized, Phase detail and Progress counts/status disagree, or a pending mapping/history byte is inexact
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-22-03:4">
<automated>
receipt=.planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json &amp;&amp; subject_sha="$(jq -er '.subject_sha' "$receipt")" &amp;&amp; remote_ref="phase-133-evidence-${subject_sha:0:12}" &amp;&amp; remote_line="$(git ls-remote --exit-code origin "refs/heads/$remote_ref")" &amp;&amp; remote_sha="${remote_line%%[[:space:]]*}" &amp;&amp; test "$remote_sha" = "$subject_sha" &amp;&amp; bash scripts/ci/verify_nightly_run.sh preflight --repo szTheory/rindle --workflow nightly.yml --ref "$remote_ref" --expected-sha "$subject_sha" &amp;&amp; bash scripts/ci/verify_nightly_run.sh verify-receipt --repo szTheory/rindle --workflow nightly.yml --ref "$remote_ref" --expected-sha "$subject_sha" --receipt "$receipt"
</automated>
<fails_when>
non-zero exit, auth/API/timeout error, remote ref mismatch, ambiguous or non-owned run, incident drift, escaped census input, stale package version, duplicated lifecycle evidence, mutable authority, or foreign receipt
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-22-03:5">
<automated>
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/phase133-final-hygiene.XXXXXX")" &amp;&amp; trap 'status=$?; cleanup_status=0; if [ -e "$temp_root/subject/.git" ] &amp;&amp; ! git worktree remove --force "$temp_root/subject" &gt;/dev/null 2&gt;&amp;1; then cleanup_status=1; fi; if ! rm -rf -- "$temp_root"; then cleanup_status=1; fi; if [ "$status" -ne 0 ]; then exit "$status"; fi; exit "$cleanup_status"' EXIT &amp;&amp; subject_sha="$(jq -er '.subject_sha' .planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json)" &amp;&amp; git worktree add --detach "$temp_root/subject" "$subject_sha" &gt;/dev/null &amp;&amp; (cd "$temp_root/subject" &amp;&amp; ./scripts/maintainer/repo_hygiene_check.sh) &amp;&amp; git worktree remove --force "$temp_root/subject" &gt;/dev/null &amp;&amp; rm -rf -- "$temp_root" &amp;&amp; trap - EXIT &amp;&amp; ./scripts/maintainer/automation_first_contract.sh
</automated>
<fails_when>
non-zero exit, the EXIT trap is absent before worktree registration, detached subject cannot materialize, cleanup leaves a registered worktree/residue, repository hygiene reports residue, or an active requirement is credited without executable evidence and a concrete failure direction
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-22-plan-verification:1">
<automated>
mix test test/install_smoke/phase_133_reconciliation_test.exs test/install_smoke/phase_133_completed_validation_test.exs &amp;&amp; MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/validate_phase_133_reconciliation.exs --root .
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, output does not report exactly 21 completed and 1 pending, Plan 22 already has a summary/checkbox, either roadmap count surface is not 21/22 `In Progress`, or Plans 01-17 historical bytes/mappings changed
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-22-post-summary:1">
<automated>
mix test test/install_smoke/phase_133_reconciliation_test.exs test/install_smoke/phase_133_completed_validation_test.exs &amp;&amp; MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/validate_phase_133_reconciliation.exs --root . --expect-execution-complete
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, output does not report exactly 22 completed and 0 pending, any Plan 18-22 summary is absent/non-complete, any plan checkbox is wrong, Phase detail and top Progress counts differ from 22/22, Progress is not `In Progress` with an empty completion date before verification, or Plans 01-17 historical bytes/mappings changed
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

## Validation Audit 2026-09-11 (Plans 18–22)

The pending-validation blocks above are retained byte-for-byte as historical pre-execution evidence. This audit records their definitive post-execution disposition without granting acceptance credit to the human publication checkpoint.

| Metric | Count |
|--------|-------|
| Gaps found | 21 |
| Resolved mappings | 21 |
| Escalated | 0 |
| Automated acceptance mappings | 20 |
| Authorization-only mappings | 1 |

**Classification:** NYQUIST-COMPLIANT

| Evidence | Result |
|----------|--------|
| Dispatch ownership | 130/130 passed |
| Incident replay | 15/15 passed |
| Strict Nightly summary | 49/49 passed |
| Dialyzer policy | 34/34 passed |
| Focused ExUnit | 130 tests, 0 failures |
| Final reconciliation | 22 completed, 0 pending |
| ShellCheck, format, automation-first | Passed |

- All 48/48 implementation tasks across 22 plans and all 5/5 phase requirements have non-vacuous automated coverage.
- Plans 18–22 account for 12/12 tasks and all 21 pending-validation mappings: 20 automated acceptance mappings are green; `133-22-02:1` remains authorization-only and receives zero acceptance credit.
- `133-21-03:2`, `133-22-03:3`, and `133-22-plan-verification:1` are pre-summary historical transition probes. Their committed summaries preserve the executed pre-summary evidence; they are not reinterpreted as current-state 22/22 checks.
- `133-22-post-summary:1` is the current-state execution-complete gate and passed at exactly 22/22.
- No new tests or implementation changes were required by this audit.
## Pending Gap-Closure Validation Addendum (Plans 23–27)

Plans 01–22 remain immutable historical validation. The records below preserve the planned verification pairs for Plans 23–27; every pair remains pending evidence history, and the Plan 27 publication checkpoint carries authorization-only acceptance credit.

<pending-validation key="133-23-01:1">
<automated>
bash scripts/ci/test_nightly_incident.sh
</automated>
<fails_when>
non-zero exit, zero passed cases, any `FAIL` row, red SHA A is absent from the replay, green SHA B does not close the incident, a mismatched event/run SHA mutates an issue, or the second replay performs a mutation
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-23-01:2">
<automated>
shellcheck -S warning scripts/ci/manage_nightly_incident.sh scripts/ci/test_nightly_incident.sh
</automated>
<fails_when>
non-zero exit or either live incident script has a shellcheck warning
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-23-02:1">
<automated>
mix test test/install_smoke/nightly_policy_test.exs &amp;&amp; test ! -e scripts/ci/eval_nightly_incident.sh
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, the retired evaluator still exists, the workflow does not call the replay manager exactly once, or more than one incident policy can authorize issue mutation
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-23-plan-verification:1">
<automated>
bash scripts/ci/test_nightly_incident.sh &amp;&amp; mix test test/install_smoke/nightly_policy_test.exs &amp;&amp; shellcheck -S warning scripts/ci/manage_nightly_incident.sh scripts/ci/test_nightly_incident.sh &amp;&amp; test ! -e scripts/ci/eval_nightly_incident.sh
</automated>
<fails_when>
non-zero exit, any Bash `FAIL` row, zero test cases, cross-SHA history is lost, a mismatched SHA reaches mutation, or the retired evaluator remains
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-24-01:1">
<automated>
mix test test/install_smoke/live_truth_parity_test.exs --only package_authority
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, a digest-consistent forged result validates, package proof returns without independent execution, a failed/missing command proves lifecycle, or maintainer evidence authorizes independent adoption/1.0
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-24-01:2">
<automated>
mix test test/install_smoke/generated_app_smoke_test.exs --only minio
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, the materialized package consumer cannot compile/boot/run lifecycle, or repository/package fallback protections regress
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-24-02:1">
<automated>
mix test test/install_smoke/live_truth_parity_test.exs --only package_authority
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, malformed receipt JSON escapes as an uncontrolled exception, a receipt without a consuming claim succeeds, multiple claims consume one receipt, or normalization is skipped
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-24-03:1">
<automated>
mix test test/install_smoke/live_truth_parity_test.exs --only package_authority &amp;&amp; mix test test/install_smoke/generated_app_smoke_test.exs
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, an unknown resolver is accepted, repeated unknown inputs increase atom count, or a supported resolver stops mapping to its established atom
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-24-03:2">
<automated>
mix format --check-formatted test/install_smoke/support/generated_app_helper.ex scripts/maintainer/validate_live_truth.exs test/install_smoke/live_truth_parity_test.exs
</automated>
<fails_when>
non-zero exit or any changed Elixir file is not canonically formatted
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-24-plan-verification:1">
<automated>
mix test test/install_smoke/live_truth_parity_test.exs --only package_authority &amp;&amp; mix test test/install_smoke/generated_app_smoke_test.exs &amp;&amp; mix format --check-formatted test/install_smoke/support/generated_app_helper.ex scripts/maintainer/validate_live_truth.exs test/install_smoke/live_truth_parity_test.exs
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, forged results or an unconsumed receipt validate, generated package execution regresses, unknown resolver input allocates atoms, or formatting differs
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-25-01:1">
<automated>
mix test test/install_smoke/phase_133_completed_validation_test.exs test/install_smoke/phase_133_reconciliation_test.exs
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, halted frontmatter plus body/code-block text is counted complete, malformed or duplicate frontmatter is accepted, or any genuine completed Plan 01-22 summary is rejected
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-25-02:1">
<automated>
mix test test/install_smoke/phase_133_reconciliation_test.exs test/install_smoke/phase_133_completed_validation_test.exs
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, any one of the 16 subsets fails, an inconsistent summary/checkbox/count state passes, Plan 27 completes early, or prior validation history changes
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-25-02:2">
<automated>
MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/validate_phase_133_reconciliation.exs --root .
</automated>
<fails_when>
non-zero exit, reported completed count differs from the current summary-backed subset between 22 and 26, Plan 27 is not pending, either roadmap count surface disagrees, or a Plan 23-27 mapping is missing/inexact
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-25-02:3">
<automated>
./scripts/maintainer/automation_first_contract.sh
</automated>
<fails_when>
non-zero exit, any implementation task lacks executable evidence plus a concrete failure direction, pending work receives green credit, or the publication checkpoint satisfies a requirement
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-25-plan-verification:1">
<automated>
mix test test/install_smoke/phase_133_reconciliation_test.exs test/install_smoke/phase_133_completed_validation_test.exs &amp;&amp; MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/validate_phase_133_reconciliation.exs --root . &amp;&amp; ./scripts/maintainer/automation_first_contract.sh
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, body text impersonates completion, current roadmap/summary facts disagree, prior history changes, pending mappings drift, or automation-first validation fails
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-26-01:1">
<automated>
mix test test/install_smoke/live_truth_parity_test.exs --only derived_authority
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, documentation calls strict Nightly gating broadly advisory, names Plan 07 as live authority, omits the current receipt/verifier relationship, or disagrees with parsed Nightly semantics
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-26-02:1">
<automated>
mix test test/install_smoke/live_truth_parity_test.exs --only derived_authority
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, RUNNING names the removed array as authority, the structured policy is missing/malformed, either consumer is disconnected, or documented/derived context differs from `CI Summary`
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-26-02:2">
<automated>
mix format --check-formatted test/install_smoke/live_truth_parity_test.exs
</automated>
<fails_when>
non-zero exit or the changed ExUnit file is not canonically formatted
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-26-plan-verification:1">
<automated>
mix test test/install_smoke/live_truth_parity_test.exs --only derived_authority &amp;&amp; mix format --check-formatted test/install_smoke/live_truth_parity_test.exs
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, any stale authority meaning is accepted, policy consumers disagree, or formatting differs
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-27-01:1">
<automated>
subject_sha="$(jq -er '.subject_sha' .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json)" &amp;&amp; temp_root="$(mktemp -d "${TMPDIR:-/tmp}/phase133-gap-ledger.XXXXXX")" &amp;&amp; trap 'status=$?; cleanup_status=0; if [ -e "$temp_root/subject/.git" ] &amp;&amp; ! git worktree remove --force "$temp_root/subject" &gt;/dev/null 2&gt;&amp;1; then cleanup_status=1; fi; if ! rm -rf -- "$temp_root"; then cleanup_status=1; fi; if [ "$status" -ne 0 ]; then exit "$status"; fi; exit "$cleanup_status"' EXIT &amp;&amp; git worktree add --detach "$temp_root/subject" "$subject_sha" &gt;/dev/null &amp;&amp; MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/evidence_census.exs --root "$temp_root/subject" --ledger .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json --output "$temp_root/receipt.json" --source-sha "$subject_sha" &amp;&amp; MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/validate_evidence_census.exs --root "$temp_root/subject" --ledger .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json --receipt "$temp_root/receipt.json"
</automated>
<fails_when>
non-zero exit, cleanup residue, foreign/dirty subject, escaped or missing input, duplicate/missing candidate, invalid disposition/transition, or nondeterministic receipt
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-27-02:1">
<automated>
subject_sha="$(jq -er '.subject_sha' .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json)" &amp;&amp; git cat-file -e "${subject_sha}^{commit}" &amp;&amp; remote_ref="phase-133-evidence-${subject_sha:0:12}" &amp;&amp; remote_existing="$(git ls-remote origin "refs/heads/$remote_ref")" &amp;&amp; test -z "$remote_existing"
</automated>
<fails_when>
non-zero exit, invalid ledger subject, or the supposedly unique remote ref already exists
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>authorization-only</acceptance-credit>
</pending-validation>

<pending-validation key="133-27-03:1">
<automated>
bash scripts/ci/test_verify_nightly_run.sh &amp;&amp; bash scripts/ci/test_nightly_incident.sh &amp;&amp; bash scripts/ci/test_nightly_summary_gate.sh &amp;&amp; bash scripts/ci/test_nightly_dialyzer.sh &amp;&amp; mix test test/install_smoke/evidence_census_test.exs test/install_smoke/nightly_policy_test.exs test/install_smoke/live_truth_parity_test.exs test/install_smoke/generated_app_smoke_test.exs test/install_smoke/phase_133_reconciliation_test.exs test/install_smoke/phase_133_completed_validation_test.exs test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs
</automated>
<fails_when>
non-zero exit, any Bash `FAIL` row, zero tests, cross-SHA history loss, forged package result acceptance, receipt/frontmatter/guidance mutation acceptance, resolver atom growth, or any closed authority regression
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-27-03:2">
<automated>
mix ci &amp;&amp; bash scripts/maintainer/refactor_contract.sh
</automated>
<fails_when>
non-zero exit, zero required tests, incomplete output, or public API/schema/telemetry/error/release preservation failure
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-27-03:3">
<automated>
MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/validate_phase_133_reconciliation.exs --root .
</automated>
<fails_when>
non-zero exit, output does not report exactly 26 completed and 1 pending, Plans 23-26 summaries/checkboxes disagree, Plan 27 is checked or summarized, either count surface differs from 26/27, or validation history/mappings drift
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-27-03:4">
<automated>
receipt=.planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json &amp;&amp; subject_sha="$(jq -er '.subject_sha' "$receipt")" &amp;&amp; remote_ref="phase-133-evidence-${subject_sha:0:12}" &amp;&amp; remote_line="$(git ls-remote --exit-code origin "refs/heads/$remote_ref")" &amp;&amp; remote_sha="${remote_line%%[[:space:]]*}" &amp;&amp; test "$remote_sha" = "$subject_sha" &amp;&amp; bash scripts/ci/verify_nightly_run.sh preflight --repo szTheory/rindle --workflow nightly.yml --ref "$remote_ref" --expected-sha "$subject_sha" &amp;&amp; bash scripts/ci/verify_nightly_run.sh verify-receipt --repo szTheory/rindle --workflow nightly.yml --ref "$remote_ref" --expected-sha "$subject_sha" --receipt "$receipt"
</automated>
<fails_when>
non-zero exit, auth/API/timeout error, remote mismatch, ambiguous/non-owned run, non-first attempt, declared job/verdict/PLT failure, incident drift, local-authority mismatch, or foreign/stale receipt
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-27-03:5">
<automated>
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/phase133-gap-hygiene.XXXXXX")" &amp;&amp; trap 'status=$?; cleanup_status=0; if [ -e "$temp_root/subject/.git" ] &amp;&amp; ! git worktree remove --force "$temp_root/subject" &gt;/dev/null 2&gt;&amp;1; then cleanup_status=1; fi; if ! rm -rf -- "$temp_root"; then cleanup_status=1; fi; if [ "$status" -ne 0 ]; then exit "$status"; fi; exit "$cleanup_status"' EXIT &amp;&amp; subject_sha="$(jq -er '.subject_sha' .planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json)" &amp;&amp; git worktree add --detach "$temp_root/subject" "$subject_sha" &gt;/dev/null &amp;&amp; (cd "$temp_root/subject" &amp;&amp; ./scripts/maintainer/repo_hygiene_check.sh) &amp;&amp; git worktree remove --force "$temp_root/subject" &gt;/dev/null &amp;&amp; rm -rf -- "$temp_root" &amp;&amp; trap - EXIT &amp;&amp; ./scripts/maintainer/automation_first_contract.sh
</automated>
<fails_when>
non-zero exit, detached subject cannot materialize, cleanup leaves worktree/residue, hygiene reports residue, or any active requirement lacks executable evidence and a concrete failure direction
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-27-plan-verification:1">
<automated>
bash scripts/ci/test_nightly_incident.sh &amp;&amp; mix test test/install_smoke/nightly_policy_test.exs test/install_smoke/live_truth_parity_test.exs test/install_smoke/phase_133_reconciliation_test.exs test/install_smoke/phase_133_completed_validation_test.exs &amp;&amp; MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/validate_phase_133_reconciliation.exs --root .
</automated>
<fails_when>
non-zero exit, zero tests, any gap regression fails, output does not report 26 completed and 1 pending, roadmap/summary facts disagree, or prior validation history changes
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-27-post-summary:1">
<automated>
mix test test/install_smoke/phase_133_reconciliation_test.exs test/install_smoke/phase_133_completed_validation_test.exs &amp;&amp; MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/validate_phase_133_reconciliation.exs --root . --expect-execution-complete
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, output does not report exactly 27 completed and 0 pending, any Plan 23-27 summary is absent/non-complete, a checkbox is wrong, detail/Progress counts differ from 27/27, Progress is not `In Progress` with blank date before verification, or prior history changes
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>
## Gap-Repair Validation Addendum (Plans 28–32)

Plans 01–27 remain immutable validation history. Plan 133-27 stays halted on its exact failed run, attempt, subject, and ref with no acceptance credit. The records below preserve every automated command/failure pair for repair Plans 133-28 through 133-32 in source order; their execution state remains separate from this ownership ledger.

<pending-validation key="133-27-halted-history:1">
<automated>
mix test test/install_smoke/phase_133_completed_validation_test.exs --seed 0 # immutable run 34661043059 attempt 1 subject 0f8189ddeed7e7a52b5c7464f17b70ab44596c33 ref phase-133-evidence-0f8189ddeed7
</automated>
<fails_when>
non-zero exit, zero ExUnit tests, Plan 133-27 is complete or checked, or its exact immutable run, attempt, subject, or ref differs
</fails_when>
<state>halted — immutable failed evidence</state>
<acceptance-credit>failure-history-only</acceptance-credit>
</pending-validation>

<pending-validation key="133-28-01:1">
<automated>
MIX_ENV=test mix test test/install_smoke/live_truth_parity_test.exs --only package_authority --seed 0
</automated>
<fails_when>
Non-zero exit, the ExUnit summary reports zero tests, either named package-authority regression fails, or forged command results are accepted.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-28-01:2">
<automated>
mix format --check-formatted test/install_smoke/live_truth_parity_test.exs
</automated>
<fails_when>
The generated package or consumer excludes a supported 1.15–1.18 fixture, either named remote regression still raises `package command failed: boot`, forged command results are accepted, or formatting fails.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-28-02:1">
<automated>
MIX_ENV=test mix test test/install_smoke/live_truth_parity_test.exs --only package_authority --seed 0
</automated>
<fails_when>
Non-zero exit, the ExUnit summary reports zero tests, the compile-before-boot attribution regression fails, or a malformed command result passes.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-28-02:2">
<automated>
mix test test/install_smoke/live_truth_parity_test.exs --seed 0
</automated>
<fails_when>
Non-zero exit, the ExUnit summary reports zero tests, or any live-truth parity regression fails.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-28-02:3">
<automated>
mix format --check-formatted scripts/maintainer/validate_live_truth.exs test/install_smoke/live_truth_parity_test.exs
</automated>
<fails_when>
A later boot result masks an earlier compile failure, any malformed or failed result passes, either formerly failing package-evidence case fails, or the focused authority suite is not green.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-29-01:1">
<automated>
mix test test/install_smoke/phase_133_reconciliation_test.exs --seed 0
</automated>
<fails_when>
Non-zero exit, the ExUnit summary reports zero tests, the bounded two-line compatibility case fails, or any duplicate/missing/error-record negative fixture passes.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-29-01:2">
<automated>
mix format --check-formatted test/install_smoke/phase_133_reconciliation_test.exs
</automated>
<fails_when>
The deterministic two-line fixture fails, a duplicate/missing success record passes, a validator error or nonzero exit passes, output bounds are absent, or the real nested-process test is removed.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-29-02:1">
<automated>
mix test test/install_smoke/phase_133_reconciliation_test.exs test/install_smoke/phase_133_completed_validation_test.exs --seed 0
</automated>
<fails_when>
Non-zero exit, the ExUnit summary reports zero tests, a legal repair state fails, or a dependency-invalid or Plan-27-as-complete fixture passes.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-29-02:2">
<automated>
elixir scripts/maintainer/validate_phase_133_reconciliation.exs
</automated>
<fails_when>
Non-zero exit, the canonical reconciliation success record is absent, or output reports incorrect complete, halted, pending, checkbox, or dependency totals.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-29-02:3">
<automated>
./scripts/maintainer/automation_first_contract.sh
</automated>
<fails_when>
Non-zero exit, or output reports a missing automated owner, missing concrete failure direction, pending-plan green credit, or human approval used as acceptance.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-29-02:4">
<automated>
mix format --check-formatted scripts/maintainer/validate_phase_133_reconciliation.exs test/install_smoke/phase_133_reconciliation_test.exs test/install_smoke/phase_133_completed_validation_test.exs
</automated>
<fails_when>
Plan 27 is semantically counted complete or checked, GSD summary counts differ from 27/32 initially or 32/32 terminally, a dependency-invalid repair state passes, a legal intermediate state fails, the terminal state differs from 31 completed/1 halted/0 pending, an earlier validation addendum changes, any new criterion lacks an automated owner, or formatting fails.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-30-01:1">
<automated>
mix test test/install_smoke/evidence_census_test.exs --seed 0
</automated>
<fails_when>
Non-zero exit, the ExUnit summary reports zero tests, or any exact-subject, candidate-identity, disposition, transition, or repeatability regression fails.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-30-01:2">
<automated>
MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/validate_evidence_census.exs --root . --census .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json
</automated>
<fails_when>
Non-zero exit, the validator success record is absent, or output reports a missing/foreign subject, detector input, disposition, transition, or deterministic digest.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-30-01:3">
<automated>
subject_sha="$(jq -er '.subject_sha' .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json)" &amp;&amp; git cat-file -e "$subject_sha^{commit}" &amp;&amp; test "$subject_sha" != 0f8189ddeed7e7a52b5c7464f17b70ab44596c33 &amp;&amp; test "$subject_sha" != 1470cf8cb0f111d0b233efbf77ee69e92f25fd68
</automated>
<fails_when>
The census subject is either prior subject, a detector input escapes the detached checkout, candidate IDs or dispositions drift without explicit transitions, repeated generation differs, validation fails, or any file besides the census is staged for this task.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-30-02:1">
<automated>
mix test test/install_smoke/live_truth_parity_test.exs --only package_authority --seed 0 &amp;&amp; mix test test/install_smoke/phase_133_reconciliation_test.exs test/install_smoke/phase_133_completed_validation_test.exs --seed 0
</automated>
<fails_when>
Non-zero exit, either ExUnit summary reports zero tests, or any lower-bound package, two-line reconciliation, halted-plan, or dependency-state regression fails.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-30-02:2">
<automated>
bash scripts/ci/test_verify_nightly_run.sh &amp;&amp; bash scripts/ci/test_nightly_incident.sh &amp;&amp; bash scripts/ci/test_nightly_summary_gate.sh &amp;&amp; bash scripts/ci/test_nightly_dialyzer.sh &amp;&amp; mix test test/install_smoke/evidence_census_test.exs test/install_smoke/nightly_policy_test.exs test/install_smoke/live_truth_parity_test.exs test/install_smoke/generated_app_smoke_test.exs test/install_smoke/phase_133_reconciliation_test.exs test/install_smoke/phase_133_completed_validation_test.exs test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs
</automated>
<fails_when>
Non-zero exit, any shell fixture prints a `FAIL` case or zero-case summary, the ExUnit summary reports zero tests, or any Phase 133 authority regression fails.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-30-02:3">
<automated>
mix ci &amp;&amp; bash scripts/maintainer/refactor_contract.sh &amp;&amp; MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/validate_phase_133_reconciliation.exs --root . &amp;&amp; ./scripts/maintainer/automation_first_contract.sh
</automated>
<fails_when>
Non-zero exit, refactor or automation output reports a contract violation, or the canonical reconciliation success record is absent.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-30-02:4">
<automated>
failed_line="$(git ls-remote --exit-code origin refs/heads/phase-133-evidence-0f8189ddeed7)" &amp;&amp; test "${failed_line%%[[:space:]]*}" = 0f8189ddeed7e7a52b5c7464f17b70ab44596c33 &amp;&amp; test "$(gh run view 34661043059 --json attempt,conclusion,headSha --jq '[.attempt,.conclusion,.headSha] | @tsv')" = $'1\tfailure\t0f8189ddeed7e7a52b5c7464f17b70ab44596c33' &amp;&amp; test "$(jq -r '[.subject_sha,(.run_id|tostring)] | @tsv' .planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json)" = $'1470cf8cb0f111d0b233efbf77ee69e92f25fd68\t34638437301'
</automated>
<fails_when>
Non-zero exit, the failed ref is missing or has a different SHA, the run tuple differs from attempt-one failure at the exact subject, or the canonical receipt tuple differs from the prior valid subject/run.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-30-02:5">
<automated>
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/phase133-repair-hygiene.XXXXXX")" &amp;&amp; trap 'status=$?; cleanup_status=0; if [ -e "$temp_root/subject/.git" ] &amp;&amp; ! git worktree remove --force "$temp_root/subject" &gt;/dev/null 2&gt;&amp;1; then cleanup_status=1; fi; if ! rm -rf -- "$temp_root"; then cleanup_status=1; fi; if [ "$status" -ne 0 ]; then exit "$status"; fi; exit "$cleanup_status"' EXIT &amp;&amp; subject_sha="$(jq -er '.subject_sha' .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json)" &amp;&amp; git worktree add --detach "$temp_root/subject" "$subject_sha" &gt;/dev/null &amp;&amp; (cd "$temp_root/subject" &amp;&amp; ./scripts/maintainer/repo_hygiene_check.sh) &amp;&amp; git worktree remove --force "$temp_root/subject" &gt;/dev/null &amp;&amp; rm -rf -- "$temp_root" &amp;&amp; trap - EXIT
</automated>
<fails_when>
Any focused/full/refactor/reconciliation/automation/hygiene command is nonzero, a temporary worktree or residue remains, the prior receipt changes or fails verification, or the failed ref/run identity or conclusion changes.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-31-01:1">
<automated>
subject_sha="$(jq -er '.subject_sha' .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json)" &amp;&amp; git cat-file -e "${subject_sha}^{commit}" &amp;&amp; test "$subject_sha" != 0f8189ddeed7e7a52b5c7464f17b70ab44596c33 &amp;&amp; test "$subject_sha" != 1470cf8cb0f111d0b233efbf77ee69e92f25fd68 &amp;&amp; remote_ref="phase-133-evidence-${subject_sha:0:12}" &amp;&amp; test -z "$(git ls-remote origin "refs/heads/$remote_ref")"
</automated>
<fails_when>
Non-zero exit, the census SHA is missing or not a commit, it equals either prior subject, or the derived remote ref lookup returns any matching ref.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>authorization-only</acceptance-credit>
</pending-validation>

<pending-validation key="133-31-01:2">
<automated>
failed_line="$(git ls-remote --exit-code origin refs/heads/phase-133-evidence-0f8189ddeed7)" &amp;&amp; test "${failed_line%%[[:space:]]*}" = 0f8189ddeed7e7a52b5c7464f17b70ab44596c33 &amp;&amp; test "$(gh run view 34661043059 --json attempt,conclusion,headSha,headBranch --jq '[.attempt,.conclusion,.headSha,.headBranch] | @tsv')" = $'1\tfailure\t0f8189ddeed7e7a52b5c7464f17b70ab44596c33\tphase-133-evidence-0f8189ddeed7'
</automated>
<fails_when>
Non-zero exit, the failed ref is missing or has a different SHA, or the run tuple differs from attempt one, failure, the exact head SHA, and the immutable failed branch.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>authorization-only</acceptance-credit>
</pending-validation>

<pending-validation key="133-31-01:3">
<automated>
receipt=.planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json &amp;&amp; test "$(jq -r '[.subject_sha,(.run_id|tostring)] | @tsv' "$receipt")" = $'1470cf8cb0f111d0b233efbf77ee69e92f25fd68\t34638437301' &amp;&amp; bash scripts/ci/verify_nightly_run.sh verify-receipt --repo szTheory/rindle --workflow nightly.yml --ref phase-133-evidence-1470cf8cb0f1 --expected-sha 1470cf8cb0f111d0b233efbf77ee69e92f25fd68 --receipt "$receipt"
</automated>
<fails_when>
The repair subject is invalid or reused, the derived ref exists, the failed ref/run differs, the prior receipt does not verify exactly, the proposed SHA/ref is not displayed, or the response is not exactly `publish` or `stop`.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>authorization-only</acceptance-credit>
</pending-validation>

<pending-validation key="133-32-01:1">
<automated>
candidate=/tmp/rindle-phase133-32-nightly-candidate.json &amp;&amp; subject_sha="$(jq -er '.subject_sha' .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json)" &amp;&amp; remote_ref="phase-133-evidence-${subject_sha:0:12}" &amp;&amp; remote_line="$(git ls-remote --exit-code origin "refs/heads/$remote_ref")" &amp;&amp; test "${remote_line%%[[:space:]]*}" = "$subject_sha" &amp;&amp; test "$(jq -r '[.subject_sha,.remote_ref,(.run_id|tostring),(.run_attempt|tostring),.conclusion,.strict_verdict.verdict] | @tsv' "$candidate")" = "$subject_sha"$'\t'"$remote_ref"$'\t'"$(jq -r '.run_id' "$candidate")"$'\t1\tsuccess\tgreen' &amp;&amp; bash scripts/ci/verify_nightly_run.sh verify-receipt --repo szTheory/rindle --workflow nightly.yml --ref "$remote_ref" --expected-sha "$subject_sha" --receipt "$candidate"
</automated>
<fails_when>
Non-zero exit, the remote ref is missing or points elsewhere, the candidate tuple differs from the exact subject/ref with attempt-one success and strict green, or candidate receipt verification rejects it.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-32-01:2">
<automated>
failed_line="$(git ls-remote --exit-code origin refs/heads/phase-133-evidence-0f8189ddeed7)" &amp;&amp; test "${failed_line%%[[:space:]]*}" = 0f8189ddeed7e7a52b5c7464f17b70ab44596c33 &amp;&amp; test "$(gh run view 34661043059 --json attempt,conclusion,headSha,headBranch --jq '[.attempt,.conclusion,.headSha,.headBranch] | @tsv')" = $'1\tfailure\t0f8189ddeed7e7a52b5c7464f17b70ab44596c33\tphase-133-evidence-0f8189ddeed7'
</automated>
<fails_when>
The exact authorization no longer matches, the ref or candidate existed before action, push uses force or a moving branch, run selection is not a one-ID set difference, the run is not attempt one/strict green/exact ref/SHA, any declared job or evidence field is missing, old failed evidence changes, or any retry/cancel/delete path is invoked.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-32-02:1">
<automated>
bash scripts/ci/test_verify_nightly_run.sh &amp;&amp; bash scripts/ci/test_nightly_incident.sh &amp;&amp; bash scripts/ci/test_nightly_summary_gate.sh &amp;&amp; bash scripts/ci/test_nightly_dialyzer.sh &amp;&amp; mix test test/install_smoke/evidence_census_test.exs test/install_smoke/nightly_policy_test.exs test/install_smoke/live_truth_parity_test.exs test/install_smoke/generated_app_smoke_test.exs test/install_smoke/phase_133_reconciliation_test.exs test/install_smoke/phase_133_completed_validation_test.exs test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs --seed 0
</automated>
<fails_when>
Non-zero exit, any shell fixture prints a `FAIL` case or zero-case summary, the ExUnit summary reports zero tests, or any exact-subject Phase 133 authority regression fails.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-32-02:2">
<automated>
mix ci &amp;&amp; bash scripts/maintainer/refactor_contract.sh &amp;&amp; MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/validate_phase_133_reconciliation.exs --root . &amp;&amp; ./scripts/maintainer/automation_first_contract.sh
</automated>
<fails_when>
Non-zero exit, refactor or automation output reports a contract violation, or normal-mode reconciliation omits its canonical success record or reports totals other than 30 complete, one halted, and one pending.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-32-02:3">
<automated>
receipt=.planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json &amp;&amp; subject_sha="$(jq -er '.subject_sha' "$receipt")" &amp;&amp; test "$subject_sha" = "$(jq -er '.subject_sha' .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json)" &amp;&amp; remote_ref="phase-133-evidence-${subject_sha:0:12}" &amp;&amp; remote_line="$(git ls-remote --exit-code origin "refs/heads/$remote_ref")" &amp;&amp; test "${remote_line%%[[:space:]]*}" = "$subject_sha" &amp;&amp; bash scripts/ci/verify_nightly_run.sh verify-receipt --repo szTheory/rindle --workflow nightly.yml --ref "$remote_ref" --expected-sha "$subject_sha" --receipt "$receipt" &amp;&amp; test ! -e /tmp/rindle-phase133-32-nightly-candidate.json
</automated>
<fails_when>
Non-zero exit, canonical and census subjects differ, the remote ref is missing or points elsewhere, receipt verification rejects the exact subject/ref/run, or the transient candidate still exists.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>

<pending-validation key="133-32-02:4">
<automated>
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/phase133-final-hygiene.XXXXXX")" &amp;&amp; trap 'status=$?; cleanup_status=0; if [ -e "$temp_root/subject/.git" ] &amp;&amp; ! git worktree remove --force "$temp_root/subject" &gt;/dev/null 2&gt;&amp;1; then cleanup_status=1; fi; if ! rm -rf -- "$temp_root"; then cleanup_status=1; fi; if [ "$status" -ne 0 ]; then exit "$status"; fi; exit "$cleanup_status"' EXIT &amp;&amp; subject_sha="$(jq -er '.subject_sha' .planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json)" &amp;&amp; git worktree add --detach "$temp_root/subject" "$subject_sha" &gt;/dev/null &amp;&amp; (cd "$temp_root/subject" &amp;&amp; ./scripts/maintainer/repo_hygiene_check.sh) &amp;&amp; git worktree remove --force "$temp_root/subject" &gt;/dev/null &amp;&amp; rm -rf -- "$temp_root" &amp;&amp; trap - EXIT
</automated>
<fails_when>
Any remote/local/full/refactor/reconciliation/automation/hygiene authority fails, candidate and census subjects differ, receipt verification fails, detached cleanup leaves residue, the prior receipt is replaced before all checks pass, unrelated files are committed, or any remote mutation occurs in this task.
</fails_when>
<state>pending — not executed</state>
<acceptance-credit>pending</acceptance-credit>
</pending-validation>
