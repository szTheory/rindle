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
