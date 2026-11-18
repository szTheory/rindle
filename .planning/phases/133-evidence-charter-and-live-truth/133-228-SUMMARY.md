---
phase: 133-evidence-charter-and-live-truth
plan: "228"
status: completed
completed: 2026-11-16
---

# Plan 228 Execution Summary

## Outcome

FFmpeg installer steps no longer receive `GITHUB_TOKEN` or `GH_TOKEN` across CI, Nightly, release, and readiness-retention. The readiness-retention setup keeps the installer in a separate token-free step and scopes GitHub credentials to the API steps that need them. The YAML-parsed regression covers all four workflows, inherited workflow/job/step environments, both token names, multiline commands, and preserved API token consumers.

The exact Plan 228 implementation source is committed on the named worktree branch:

- Subject: `cfa2f0f81a55c627395d4ab73331b3dfebfd03d3`
- Subject tree: `341ec46cbdba4dd17f7c4c7e55a123a6b1fbd6da`
- Branch: `worktree-agent-p228-credential-scope`
- Base: `80ff0766eddee9c0b4d0ace6f966c07e5876530d`
- Source files: the four workflow files, `ci_cache_hygiene_test.exs`, `phase_133_reconciliation_test.exs`, and `validate_phase_133_reconciliation.exs`

source_subject: cfa2f0f81a55c627395d4ab73331b3dfebfd03d3
source_tree: 341ec46cbdba4dd17f7c4c7e55a123a6b1fbd6da
source_branch: worktree-agent-p228-credential-scope
base_sha: 80ff0766eddee9c0b4d0ace6f966c07e5876530d

The subject includes the tested Plan 229 frozen-proof check, one-shot recorder, exact two-member archive writer/validator, whole-phase audit gate, candidate gate, and installed-byte gate. No proof recorder or frozen-source preflight was invoked in Plan 228.

## Verification

- `git diff --check` and `mix format --check-formatted` passed.
- The tagged `plan229_security` selection ran 4 tests with 0 failures.
- The focused workflow and reconciler suite passed: 56 tests, 0 failures.
- The package-manager guard passed all ten checks.
- The local fake-GitHub Nightly verifier matrix passed: 217 cases, 0 failures. This is deterministic local evidence, not a scheduled Nightly run.
- `automation_first_contract.sh` passed. Its output identified the Phase 139 active planning scope.

### TDD Red Evidence

The three classifier-accepted, assertion-specific red runs were captured before their corresponding fixes. Each exited 2 because its target assertion failed; none recorded proof or changed `133-SECURITY.md`.

| Evidence | Target and observed red assertion | Record SHA-256 |
| --- | --- | --- |
| `133-228-TDD-RED-1.json` | CI installer token assertion: “At least one parsed CI installer step still maps a GitHub token.” | `c108c7723f42984da532d33ce9f21ff657644218d4d0891b1e525a5c02d46195` |
| `133-228-TDD-RED-2.json` | Four-workflow credential assertion: installer credentials remained and readiness API consumers lacked step-scoped mappings. | `17a9f95e9687e8b538d022111d400887d8d05114292f764cec5b43cc429ed513` |
| `133-228-TDD-RED-3.json` | Plan 229 validator test: “The frozen proof command set API is not yet implemented.” | `8a32609b26b7c1161fdca0cf8c57e0dce5d6ef32d443c8245fdfe16551367749` |

The three temporary JSON records are summarized here and are not part of the source commit. Their JUnit reports were captured in each record before later green runs replaced the local report file.

## Execution Notes and Handoff

The GSD executor process failed to launch because its Codex arguments combined unsupported `--sandbox` and `--approve-for-me` flags. Work continued manually in the same isolated worktree; no second worker or main-worktree edit was made.

`133-SECURITY.md` remains the approved `OPEN_THREATS` preimage at SHA-256 `d8467201e105ca243e6284ada351ebdba7e3ad870e9a3d5382476f07df4f6843`. Plan 228 created no canonical archive, audit, or candidate and grants no requirement, CI-16, or remote credit. Plan 229 owns the read-only frozen-source preflight, its one source-bound proof attempt, the independent whole-phase audit, and any later SECURITY disposition.

---
*Phase: 133-evidence-charter-and-live-truth*
*Plan: 228*
