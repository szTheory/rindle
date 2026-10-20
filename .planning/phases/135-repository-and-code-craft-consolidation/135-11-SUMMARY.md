---
phase: 135-repository-and-code-craft-consolidation
plan: 11
subsystem: residue gate, artifact ledger CI step, evidence collector, contributor docs
status: complete
tags: [residue, ledger, evidence, collector, CRAFT-03, CRAFT-04, CRAFT-05, CRAFT-06, HYGIENE-03]
requires: ["135-01", "135-02", "135-03", "135-04", "135-05", "135-06", "135-07", "135-08", "135-09", "135-10", "135-12", "135-13"]
provides:
  - "live residue test asserting zero pending-removal across all seven shards"
  - "ci-script-tests offline ledger step with --require-settled"
  - "readability_changes.json pr fields set to squash PR 152"
  - "scripts/maintainer/collect_phase_gate_evidence.sh (rindle-phase-gate-evidence-v1, gh api -X GET only)"
  - "scripts/ci/test_collect_phase_gate_evidence.sh (21-case fake-gh harness, merge-blocking in ci-script-tests)"
  - "RUNNING.md Repository craft gates section and CONTRIBUTING.md change-to-proof rows"
affects: ["Phase 135 VERIFICATION (credit comes from the collector verdict and archive simulations below)"]
tech-stack:
  added: []
  patterns: ["single gh_get helper is the only GitHub access path", "fake gh exits 97 on anything but api -X GET", "evidence verdict from executable collector, never from merges"]
key-files:
  created:
    - scripts/maintainer/collect_phase_gate_evidence.sh
    - scripts/ci/test_collect_phase_gate_evidence.sh
  modified:
    - test/install_smoke/live_residue_scan_test.exs
    - .github/workflows/ci.yml
    - scripts/maintainer/readability_changes.json
    - RUNNING.md
    - CONTRIBUTING.md
    - .planning/phases/135-repository-and-code-craft-consolidation/deferred-items.md
decisions:
  - "The collector output adds a top-level causes array (SHA-prefixed per-SHA causes plus hygiene) next to the contract keys so a fail verdict names its cause in the document, not only on stderr"
  - "--hygiene-exit accepts 0-999 without leading zeros so the value is valid JSON for --argjson"
  - "Docs describe the retained receipt directory by ledger class and REJECT message, not by phase number, so the new text carries no planning-era identifiers"
metrics:
  duration: "~45 min"
  completed: 2026-10-20
actuals:
  tokens: 8300
  tasks: 3
  commits: 2
commits: 2
plan_head_before: c3fe2a888a57b2f727ee0198bf11234ded8965af
plan_head_after: 910ee4e680c7130cef50a08a15252e475092a3df
---

# Phase 135 Plan 11: Zero pending residue and phase gate evidence collector Summary

The residue gate now requires zero `pending-removal` entries in every shard, and the CI ledger step rejects any class still marked `delete`. Each readability trace entry records PR 152. A read-only collector gives the requirement verdict. Run over all 12 Phase 135 squash SHAs on main, with a clean-main `--release-prep --with-mix-ci` log, it returns **verdict pass**. Archive simulation A, which archives the Phase 134 and 135 directories, stays green. Archive simulation B, which archives the Phase 133 directory, fails with exactly the one retained-receipt REJECT line.

## Tasks

| Task | Name | Commit | Result |
|------|------|--------|--------|
| 1 (tracer) | Zero-pending flip, settled ledger step, trace PR numbers | 61acf9ac | The live test runs `--check --require-no-pending all`. The new planted case (a pending entry for `examples/planted.exs`) exits 1 with `pending-removal entry remains in examples_docs`. 3 test files: 59 tests, 0 failures. Ledger `--require-settled`: ok (2891 files, 46 classes). Trace `--offline`: ok. Tracer gate: verify re-run green before expanding |
| 2 | Collector, fake-gh harness, ci-script-tests step, command map | 910ee4e6 | Harness: 21 passed, 0 failed under both bash 5 and /bin/bash 3.2. shellcheck is clean. Residue scan: ok (626 files, 180 hits, 158 entries). docs_parity + nightly_policy + ci_lane_split + live_residue: 94 tests, 0 failures. `check_docs_links.sh`: OK |
| 3 | Exact-head evidence | docs commit (SUMMARY) | See Evidence below |

## Evidence (Task 3)

Requirement credit for CRAFT-03, CRAFT-04, CRAFT-05, CRAFT-06 and HYGIENE-03 comes from the collector verdict and the two archive simulations below. A merge, an approval or a hand-copied CI conclusion is never credit (D-135-12).

### Archive simulation A (amended D-135-02)

Commands, run in a scratch `git clone --no-local` of the closure head 910ee4e6:

```
mkdir -p .planning/milestones/v1.26-phases
git mv .planning/phases/134-dependency-security-and-inbox-disposition .planning/milestones/v1.26-phases/
git mv .planning/phases/135-repository-and-code-craft-consolidation .planning/milestones/v1.26-phases/
git commit -qm sim            # local scratch commit 496789fe
bash scripts/ci/test_<each>.sh
bash scripts/maintainer/validate_artifact_ledger.sh --offline --require-settled --ledger scripts/maintainer/artifact_ledger.json
mix run --no-start scripts/maintainer/scan_live_residue.exs --check --require-no-pending all
mix test test/install_smoke test/planning_path_hygiene_test.exs
```

| Check | Result |
|-------|--------|
| test_ci_summary_gate.sh | passed 6, failed 0 |
| test_collect_inbox.sh | 70 passed, 0 failed |
| test_collect_phase_gate_evidence.sh | 21 passed, 0 failed |
| test_craft_contract_tools.sh | 52 passed, 0 failed |
| test_dep_landing_evidence.sh | 58 passed, 0 failed |
| test_e2e_specs_scoping.sh | passed 5, failed 0 |
| test_nightly_dialyzer.sh | passed 34, failed 0 |
| test_nightly_incident.sh | passed 36, failed 0 |
| test_nightly_summary_gate.sh | passed 49, failed 0 |
| test_repo_hygiene_check.sh | 37 passed, 0 failed |
| test_setup_branch_protection.sh | 6 passed, 0 failed |
| test_validate_artifact_ledger.sh | 58 passed, 0 failed |
| test_validate_inbox_ledger.sh | 72 passed, 0 failed |
| test_verify_nightly_run.sh | passed 187, failed 0 |
| test_compat_115_26.sh | exit 2. This is a Docker toolchain repro and does not depend on the archive; see Deviations |
| Ledger `--require-settled` | `validate_artifact_ledger: ok (offline, 2893 files, 46 classes)`, no REJECT |
| Residue `--require-no-pending all` | `live residue scan: ok (626 files, 180 hits, 158 allowlist entries)` |
| `mix test test/install_smoke test/planning_path_hygiene_test.exs` | **365 tests, 0 failures, 17 excluded** |

### Archive simulation B (amended D-135-02, D-135-03)

In a second scratch clone, only `.planning/phases/133-evidence-charter-and-live-truth` was moved, with `git mv`, under `.planning/milestones/v1.26-phases/`. The move was committed locally as 2b2d2bd0. Then `bash scripts/maintainer/validate_artifact_ledger.sh --offline --ledger scripts/maintainer/artifact_ledger.json` exited **1**. Its entire output was this one REJECT line:

```
REJECT: retained receipt: .planning/phases/133-evidence-charter-and-live-truth must not be archived (verify_nightly_run.sh census identity)
```

### Clean-main release-prep hygiene

The run was `git clone --quiet --branch main https://github.com/szTheory/rindle.git <scratch>/cleanmain` at c3fe2a88, then `mix deps.get`, then `bash scripts/maintainer/repo_hygiene_check.sh --release-prep --with-mix-ci`, with output saved to a scratch log. Exit status: **0**. Report tail:

```
[PASS] latest CI: latest main CI run succeeded
[PASS] artifact ledger: validate_artifact_ledger: ok (offline, 2891 files, 46 classes)
[PASS] tracked junk: no tracked junk or ignored files
[PASS] generated drift: 3 generator(s) rerun; drift paths unchanged
[PASS] mix ci: full alias completed with every completion sentinel
[PASS] post-verification residue: no new path outside the verification ignored roots
Summary: 18 PASS, 0 WARN, 0 BLOCK
Result: safe to start release prep
```

### Collector verdict over every Phase 135 squash SHA

SHA file (one per merged plan PR, matched to each plan's Delivery subject): 135-01 #143 7fec8297, 135-02 #147 d19bd41f, 135-04 #148 d8bf703d, 135-03 #149 c23f287e, 135-12 #150 7e2447cb, 135-06 #152 f5de8ffc, 135-07 #151 ddfb734b, 135-08 #153 05bff2dc, 135-05 #154 838ccf1a, 135-09 #155 30a59ef5, 135-13 #156 1e03234c, 135-10 #157 c3fe2a88.

Command, run from the worktree root (read-only, every gh call is `gh api -X GET`):

```
bash scripts/maintainer/collect_phase_gate_evidence.sh --repo szTheory/rindle \
  --shas-file <scratch>/phase135_shas.txt --hygiene-log <scratch>/hygiene_release_prep.log \
  --hygiene-exit 0 --nightly-after 30a59ef52b32cbf34ea4bd4af00aa01953f8c355
```

Exit 0, `collect_phase_gate_evidence: verdict pass`. Full JSON:

```json
{
  "causes": [],
  "hygiene": {
    "exit": 0,
    "ok": true,
    "result_line": "Result: safe to start release prep"
  },
  "nightly_followup": {
    "conclusion": null,
    "head_sha": null,
    "run_id": null,
    "status": "pending"
  },
  "repo": "szTheory/rindle",
  "schema": "rindle-phase-gate-evidence-v1",
  "shas": [
    {
      "causes": [],
      "ci_push": {
        "conclusion": "success",
        "run_id": 39304553783
      },
      "ci_summary": {
        "conclusion": "success"
      },
      "ok": true,
      "sha": "7fec8297c9ed2c569743f37921be6283673f87e0",
      "subject": "test: add live residue scanner with removal-only allowlist (#143)"
    },
    {
      "causes": [],
      "ci_push": {
        "conclusion": "success",
        "run_id": 39309652221
      },
      "ci_summary": {
        "conclusion": "success"
      },
      "ok": true,
      "sha": "d19bd41fe8a1792d7103faadb0ceafc76bb0275a",
      "subject": "test: add readability trace, craft boundary and public surface gates (#147)"
    },
    {
      "causes": [],
      "ci_push": {
        "conclusion": "success",
        "run_id": 39317500370
      },
      "ci_summary": {
        "conclusion": "success"
      },
      "ok": true,
      "sha": "d8bf703db1b5ffcf683f17ca242fef12ee26921f",
      "subject": "refactor: replace planning-era provenance comments in lib and config (#148)"
    },
    {
      "causes": [],
      "ci_push": {
        "conclusion": "success",
        "run_id": 39320509915
      },
      "ci_summary": {
        "conclusion": "success"
      },
      "ok": true,
      "sha": "c23f287ec1bd16c028f90f6f3e1779e4fab6bddc",
      "subject": "ci: add artifact ledger with partition validator and package-set check (#149)"
    },
    {
      "causes": [],
      "ci_push": {
        "conclusion": "success",
        "run_id": 39325940760
      },
      "ci_summary": {
        "conclusion": "success"
      },
      "ok": true,
      "sha": "7e2447cb16222208d7e40850057fa650f47be721",
      "subject": "test: replace planning-era identifiers in runtime and provider unit tests with behavior names (#150)"
    },
    {
      "causes": [],
      "ci_push": {
        "conclusion": "success",
        "run_id": 39329128835
      },
      "ci_summary": {
        "conclusion": "success"
      },
      "ok": true,
      "sha": "f5de8ffce150411807167795776763726a2d2e16",
      "subject": "refactor: flatten nesting in five ops and tus modules from the complexity baseline (#152)"
    },
    {
      "causes": [],
      "ci_push": {
        "conclusion": "success",
        "run_id": 39332326101
      },
      "ci_summary": {
        "conclusion": "success"
      },
      "ok": true,
      "sha": "ddfb734b0f6d4ab743721da653ab96fd80c2cc0f",
      "subject": "test: replace planning-era identifiers in core unit tests with behavior names (#151)"
    },
    {
      "causes": [],
      "ci_push": {
        "conclusion": "success",
        "run_id": 39336179127
      },
      "ci_summary": {
        "conclusion": "success"
      },
      "ok": true,
      "sha": "05bff2dcf5dc84b4cd532880d982ac2269537224",
      "subject": "test: replace planning-era identifiers in examples, adopter tests and docs (#153)"
    },
    {
      "causes": [],
      "ci_push": {
        "conclusion": "success",
        "run_id": 39343154216
      },
      "ci_summary": {
        "conclusion": "success"
      },
      "ok": true,
      "sha": "838ccf1ac234cf591a289111eb2eaf16666c9fe9",
      "subject": "ci: make repo hygiene fail honestly on fetch, branch, junk, drift, mix ci and residue (#154)"
    },
    {
      "causes": [],
      "ci_push": {
        "conclusion": "success",
        "run_id": 39349565623
      },
      "ci_summary": {
        "conclusion": "success"
      },
      "ok": true,
      "sha": "30a59ef52b32cbf34ea4bd4af00aa01953f8c355",
      "subject": "ci: replace planning-era identifiers in ci scripts and brandbook generators (#155)"
    },
    {
      "causes": [],
      "ci_push": {
        "conclusion": "success",
        "run_id": 39355788093
      },
      "ci_summary": {
        "conclusion": "success"
      },
      "ok": true,
      "sha": "1e03234c5e7ca361122f397668747865f8a57835",
      "subject": "ci: replace planning-era identifiers in workflows and maintainer scripts (#156)"
    },
    {
      "causes": [],
      "ci_push": {
        "conclusion": "success",
        "run_id": 39360585413
      },
      "ci_summary": {
        "conclusion": "success"
      },
      "ok": true,
      "sha": "c3fe2a888a57b2f727ee0198bf11234ded8965af",
      "subject": "test: rename requirement-id policy tests to behavior names and fix mojibake (#157)"
    }
  ],
  "verdict": "pass"
}
```

`nightly_followup.status` is **pending**, and this field is **non-blocking**. The newest scheduled Nightly runs are 39218639562 on e76adde8, and 39108080256 and 39014057417 on 4b7b8e33. All three concluded failure, and none is on a descendant of 30a59ef5 yet. The scheduled Nightly is a follow-up only. It never changes the verdict.

### Release tag check

`git fetch origin --tags` then `git tag --contains 7fec8297c9ed2c569743f37921be6283673f87e0` printed nothing. No release tag contains any Phase 135 commit.

### Other verification on the closure head

- `bash scripts/maintainer/validate_readability_trace.sh --offline --trace ... --baseline ...`: ok (offline)
- `bash scripts/maintainer/validate_readability_trace.sh --base origin/main --trace ... --baseline ...` exits 1 with 5 `anchor not in base` REJECTs. This is by design. `--base` checks that each removed identity existed in the base's baseline, and on origin/main those five identities are already gone because PR 152 removed them. Against the refactor's own base, `--base 7e2447cb`, the result is `ok (base)`.
- `test_craft_contract_tools.sh` 52/0, `test_repo_hygiene_check.sh` 37/0, `test_validate_artifact_ledger.sh` 58/0
- `validate_artifact_ledger.sh --offline`: ok (2893 files, 46 classes); new files are covered by existing classes
- `repo_hygiene_check.sh --ci`: 10 PASS, 1 WARN (the Hex.pm index could not be read from the sandbox), 0 BLOCK, exit 0
- `mix test test/install_smoke`: 363 tests, 0 failures, 17 excluded
- `check_docs_links.sh`: OK; `automation_first_contract.sh`: passed

## Deviations from Plan

### Auto-fixed Issues

None. Nothing needed a code fix outside the plan.

### Scope notes

1. **`scripts/ci/test_compat_115_26.sh` in the simulation A loop.** The plan's "every `scripts/ci/test_*.sh`" glob also picks up this Docker repro. It runs `mix coveralls` in `hexpm/elixir:1.15.8` against a throwaway Postgres and is not in any CI job. It exits 2 with the same 4 environment failures in both runs: archived (simulation A) and unarchived (a fresh clone of the same head). The failures are `Rindle.DoctorTest` and three `ProcessVariantTest` AV cases. The plain image has no FFmpeg, and none of these tests reads `.planning`. Archiving does not cause this failure. It is logged in deferred-items.md.
2. **Readability trace `--base origin/main`.** This fails by design after PR 152, as described above. The correct base for that check is the refactor's parent, and with that base it passes.
3. **Worktree commit-guard namespace.** The orchestrator told the executor to commit on `test/135-11-phase-gate`, a faithful PR branch, not an `agent-*` branch. Commits followed that instruction.

## Known Stubs

None.

## Threat Flags

None. The collector is the only new surface. It uses only `gh api -X GET`, validates `--repo`, SHAs and run ids before they reach a request path, and passes every value to jq through `--arg` or `--argjson`. The threat model covers it as T-135-28 and T-135-34.

## Post-merge (orchestrator)

- Add the closure squash SHA of this PR to the SHA file. Re-run the collector and the clean-main `--release-prep --with-mix-ci` run on that SHA. The verdict must stay pass.
- Record the Nightly follow-up once a scheduled run lands on a descendant of 30a59ef5. It is non-blocking, but the last three scheduled runs failed.
- The phase record goes in the separate `docs(135):` PR: VERIFICATION, REQUIREMENTS status for CRAFT-03..06 and HYGIENE-03, and the SUMMARYs.

## Self-Check: PASSED

- FOUND: scripts/maintainer/collect_phase_gate_evidence.sh, scripts/ci/test_collect_phase_gate_evidence.sh
- FOUND: 61acf9ac, 910ee4e6 (ancestors of HEAD)
