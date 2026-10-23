# Phase 139: Exact-Head Readiness Closure - Research

**Researched:** 2026-10-22
**Domain:** Exact-subject release evidence, GitHub Actions and remote state
**Confidence:** MEDIUM

**2026-10-22 prerequisite reconciliation:** This research captured prospective Phase 134–138
interfaces before they landed. The authoritative execution worktree now has passed
verifications and committed summaries for all five phases. Before executing any Phase
139 plan, run `bash .planning/phases/139-exact-head-readiness-closure/139-preflight.sh`.
The delivered package/recovery authority is `scripts/maintainer/built_package_twin.py`
with `twin_receipt.py` and `twin_cleanup.py`; retain `inputs.json`, `receipt.json`,
and `package.tar` together. `archive_identity` provides separate
`package_tar_sha256`, `package_metadata_sha256`, and `package_tree_sha256`.
The supported cell is Elixir 1.17.3-otp-27, OTP 27.3.4.15, Node 20.18.1.
Phase 139 also owns the public Doctor versioned-host migration-ledger correction
specified in `.planning/todos/pending/2026-10-21-doctor-versioned-host-migration-ledger.md`.
The original Phase 136 numeric speed result is blocked historical evidence; its
exact-ten target was explicitly deferred unfinished with zero acceptance credit
to SEED-261021-918 and is not a READY gate. Historical source SHA receipts are
not exact-current-head qualification. These current facts override prospective
path/availability assumptions below, while the seven evidence mechanisms remain.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
## Implementation Decisions

### Revision and verdict authority
- **D-01:** Qualify the final post-merge `main` SHA after all intended tracked implementation,
  workflow, documentation, and planning changes have landed through the existing PR train. A PR-head
  pass is preparation, not proof for a different merge commit.
- **D-02:** Resolve `refs/heads/main` from the authoritative remote before qualification and again
  immediately before the terminal verdict. Both must equal the declared subject. Any advancement,
  including a documentation-only commit, invalidates the claim of current-head readiness; old proof
  remains historical evidence for its original SHA.
- **D-03:** Store the terminal manifest and its receipts outside the tested source tree. Do not commit
  a manifest into the revision it claims to certify, hash the manifest into itself, or silently exempt
  closure/checkmark commits from exact-head binding. Later archival pointers must explicitly describe
  the earlier subject; they do not certify their own commit.
- **D-04:** Distinguish `ready` from `not_ready`, with machine-readable reasons for failed, unavailable,
  incomplete, stale, or changed evidence. Missing proof never means passing proof. Record the verdict's
  observation interval; it is not an indefinitely valid assertion about a moving branch or service.

### Qualification and evidence contract
- **D-05:** Use a fresh isolated checkout of the subject, with exact resolved supported toolchains and
  detector/configuration inputs. Derive supported pairs and gate ownership from the committed policy;
  do not widen support or allow a newer local toolchain to substitute. Separate incompatible build
  outputs by toolchain. Verify initial cleanliness and final state after owned cleanup.
- **D-06:** Enumerate the required evidence set explicitly: formatting, compilation, reviewed Credo,
  supported Dialyzer including applicable fresh/restored-PLT proof, Doctor, exact accepted coverage
  floor, security, documentation/contracts, built package, generated consumer, twin/recovery matrix,
  release/adoption truth, and strict repository hygiene. Every required gate has actual execution
  evidence, source/tool/input identity, command outcome, and a verifiable receipt. Neither declared
  commands nor a green aggregate alone establish this set.
- **D-07:** Reuse upstream schemas, collectors, and pure validators where their contracts fit, and
  requalify on the closing subject. A receipt from an earlier SHA cannot become exact-head proof by
  relabeling it. Static proof can be reused for identical subject, toolchain, inputs, and proof policy;
  mutable remote facts must be reobserved at closure.
- **D-08:** Bind built-package, generated-consumer, and twin evidence to the actual tested artifact
  bytes and unpacked payload using explicitly named digest kinds. Preserve no-checkout-fallback and
  no-prebuilt-BEAM guarantees. A metadata-file digest is not an archive digest; normalize the existing
  helper's ambiguous `package_sha256` field at the evidence boundary rather than overstating it.
- **D-09:** Give the manifest a versioned schema, finite required proof IDs, receipt paths and byte
  digests, subject/repository identity, package identity, tool/input identity, applicability decisions,
  outcomes, cleanup/residue results, and adoption-proof class. Reject duplicate IDs, missing required
  entries, malformed or unknown trust-bearing states, digest mismatch, wrong subject/package,
  incomplete attempts, and explanations that do not satisfy an executable policy.
- **D-10:** Persist failed outcomes for diagnosis. A crash before terminal finalization, command failure,
  timeout, or cleanup failure cannot leave a passing manifest. Inventory tracked, untracked, ignored,
  generated, database, job, object, provider, multipart, and temporary-resource residue as applicable.
  Require observed cleanup results and absence of unapproved residue, not just a cleanup call returning
  `:ok`. Explicitly inventoried tool caches/evidence outputs are distinguishable from unexplained junk;
  cleanup is confined to resources owned by this run.

### CI, Nightly, and protection
- **D-11:** Require the complete successful `ci.yml` / `CI` execution for `event=push`, branch `main`,
  and the exact subject, including applicable main-only jobs. Preserve `CI Summary` as the sole
  required PR context; its success alone cannot replace full main/release proof.
- **D-12:** Prefer and require a qualifying real scheduled Nightly on the closing subject for this
  phase's final closure path, exercising the existing scheduled incident policy without inventing an
  incident. Dispatch remains useful diagnostic/rehearsal evidence and never substitutes for scheduled
  incident recovery. READY-02 alone does not specify an event; choosing the scheduled path avoids
  ambiguity with upstream EVID-04 at the acknowledged cost of waiting for the next eligible run.
- **D-13:** Bind workflow identity, repository, event, branch, SHA, run ID, attempt, and complete expected
  job set. Discover runs without success-only filtering and select the newest eligible execution
  deterministically. A later failure, pending run, or changed attempt cannot be hidden behind an older
  green result. Require a complete successful selected attempt; do not silently splice partial reruns.
  Recheck attempt and terminal status after job collection.
- **D-14:** Keep applicability event-specific. PR's intentional skips do not define Nightly or readiness
  policy. Required work may not be skipped/neutral/cancelled-as-green. Optional live-provider work can
  be explicitly `not_run` only under the existing machine-checked applicability rule; it grants no live
  provider claim and cannot exempt required deterministic proof.
- **D-15:** Compare the committed topology with effective live protection: classic branch protection
  plus applicable active repository/organization rulesets. Normalize legacy and structured required
  checks, preserve app/integration bindings and enforcement/bypass facts, and reject incompatible
  drift. The effective required-context set stays exactly `CI Summary`, supplied by the intended
  workflow/provider. Informational diffs are not acceptance evidence; inaccessible protection is an
  evidence gap, not an empty set.
- **D-16:** Preserve `ci.yml`, workflow `CI`, exact-SHA release coupling, fork safety, and the accepted
  <=480-second median / <=600-second p95 PR envelope. Put cheap deterministic validator regressions
  in the existing script-test seam; run full closure and privileged read-only remote checks outside
  the PR critical path. Do not widen routine CI proof or add recurring cloud work without measured need.

### Current remote and advisory truth
- **D-17:** Revalidate Phase 134's disposition ledger against a fresh complete read-only inventory;
  do not repeat all triage or require inbox zero. New items, changed decision inputs, expired exceptions,
  or undispositioned blockers yield `not_ready` with the owning phase/item and next action.
- **D-18:** Collect issues, distinct PRs and their exact heads/checks/statuses, relevant repository
  security advisories, Dependabot alerts, Hex audit findings/database identity, and protection as
  separate sources. Follow all pagination and reject truncation. Account for the issues endpoint
  containing PRs, check history versus default latest views, and separate legacy commit statuses.
  Revisit previously tracked items absent from the open inventory to establish their disposition.
- **D-19:** Record each source's query/API policy, coverage/visibility, observation interval, completion,
  and response identity. Authentication, authorization, private-resource 404, rate limiting, partial
  pagination, timeout, and malformed responses must remain distinct from a successfully observed empty
  inventory. An empty Dependabot inventory cannot replace Hex audit evidence or prove unpublished
  advisory visibility. Use authorized existing connectors/credentials; never copy tokens or broaden
  permissions automatically.
- **D-20:** Collect and revalidate remote state within the same bounded closure invocation. Compare
  complete normalized inventories and relevant mutable decision inputs; use conditional requests only
  with the exact retained representation and request context. Changed main, PR head/check attempt,
  advisory, exception, or protection invalidates affected proof. Do not invent a universal 24-hour TTL
  or treat `updated_at` as a version for every related resource. Record that GitHub provides no
  cross-endpoint atomic snapshot guarantee; a later consumer must refresh current facts again.
- **D-21:** Keep request retries and total collection time bounded and failures explicit. Preserve
  private security content in an appropriately restricted evidence location; public receipts retain
  redacted coverage, identity and disposition proof without publishing sensitive details. A redacted
  receipt must derive from actual collection, not human acceptance.

### Maintainer experience, retention, and claim boundaries
- **D-22:** Provide one documented maintainer entry point with collection, offline read-only validation,
  and bounded read-only remote refresh responsibilities. Use existing shell orchestration and Elixir
  scripts/Jason for pure policy where suitable. Keep this outside the shipped public API, runtime
  supervision, Ecto schema, Plug routes, and Admin UI. Prefer explicit options, stable proof IDs,
  concise failure reasons, nonzero failure exits, and the next existing repair command.
- **D-23:** Retain one portable redacted bundle using the existing pinned artifact mechanism, unique
  source/run/attempt identity, explicit retention, no overwrite, and error on missing files. Default
  closeout retention to 30 days subject to repository limits; keep a byte-verified local copy for
  longer historical inspection. A separate locator records artifact/run identity, subject, manifest
  digest, archive digest and expiry. Transport identifiers do not go back into the already uploaded
  manifest. Expired/deleted/inaccessible remote bytes cannot earn current acceptance from a URL alone.
- **D-24:** Verify bundle bytes directly and fail on digest mismatch; a download action warning is
  insufficient. Hashes establish byte identity, not signing, independent authenticity, or SLSA
  compliance. Do not add a signing/provenance service or generic per-attempt authorization protocol.
- **D-25:** Stamp twin evidence as maintainer-operated synthetic evidence. Executable release/adoption
  parity must leave PILOT-01 and PILOT-02 open and reject independent-adopter or 1.0 authority derived
  from synthetic receipts. Preserve Release Please ownership of version/release intent; readiness
  grants no publish, merge, issue mutation, protection mutation, or forced version bump.

### the agent's Discretion
- Exact filenames, internal helper boundaries, JSON representation, compact failure vocabulary, and
  sensible bounded deadlines measured during implementation.
- The narrow mechanism for retaining portable historical bytes and presenting their locator, within
  existing repository access and retention policy. A material recurring cost/security boundary change
  requires a scoped decision; otherwise reuse existing infrastructure.
- No routine maintainer choices remain unresolved. Reinspect upstream implementations at planning
  time against the execution worktree. Phases 134–138 now have tracked validators and passed verifications.

### Deferred Ideas (OUT OF SCOPE)
## Deferred Ideas

- Initial remote triage/security resolution, repository cleanup, quality ratchets, twin infrastructure,
  and recovery scenarios remain owned by earlier phases; do not duplicate them under closure.
- Independent Phoenix pilot/1.0, new providers, public API/schema changes, Admin UI, broad onboarding
  redesign, signing services, permanent webhook mirrors, and a general evidence platform are outside scope.
- Return to the demand-gated sustaining posture after v1.26; this discussion creates no next milestone.
- No matching pending todos were found. No high-blast-radius decision requires escalation now.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| READY-01 | One isolated exact-head checkout passes supported toolchains, formatting, compilation, Credo, Dialyzer, Doctor, coverage, security, docs, package, generated-consumer, twin, and repository-hygiene gates. | Isolated qualification, finite proof inventory, tool/input identity, archive and payload digest binding. |
| READY-02 | Current exact-head main CI and Nightly are green and branch-protection requirements match the tested workflow topology. | Full push-main and real scheduled attempt verification, effective protection comparison. |
| READY-03 | Every open remote item and advisory has a current evidence-backed disposition, with no undispositioned release blocker. | Complete paginated inventory, Phase 134 ledger revalidation, security visibility, two observations. |
| READY-04 | One fail-closed readiness manifest rejects missing, stale, partial, skipped-as-green, foreign-SHA, unclean, or unexplained evidence. | Versioned receipt graph, pure validator, unsuccessful attempt persistence, residue proof and adversarial fixtures. |
| READY-05 | Milestone closure leaves the named independent Phoenix pilot requirement open and makes no real-adopter or 1.0 claim. | Executable adoption parity from authoritative release/planning state; synthetic evidence class. |
</phase_requirements>

## Summary

[VERIFIED: .planning/phases/138-lifecycle-failure-and-recovery-matrix/138-VERIFICATION.md; .planning/phases/139-exact-head-readiness-closure/139-preflight.sh] Phase 139 is the terminal evidence join after passed Phase 138. The preflight checks the committed upstream chain, current Phase 138 covered digest, retained matrix verifier, and zero-credit CI timing deferral. It establishes implementation prerequisites, not READY acceptance.

[VERIFIED: config/ci_required_checks.json:1-11; .github/workflows/ci.yml:1441-1465; .github/workflows/nightly.yml:19-22,499-545] The committed topology distinguishes PR's sole required `CI Summary` from full push-main CI and scheduled Nightly. [VERIFIED: scripts/ci/verify_nightly_run.sh:97-129,156-179,325-346] The current Nightly verifier is for `workflow_dispatch` and `run_attempt == 1`; its policy cannot be relabeled as scheduled closure proof. [VERIFIED: test/install_smoke/support/generated_app_helper.ex:358-378] The current helper names a metadata-file hash `package_sha256` and separately records `unpacked_tree_sha256`. These boundaries set the highest risk in the closing validator.

**Primary recommendation:** Build one outside-checkout, versioned evidence bundle from a fresh exact `main` SHA; validate local receipts, complete remote attempts and inventories, protection, artifact bytes, residue, and adoption claims in one pure fail-closed policy before issuing a terminal verdict. [VERIFIED: .planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md:15-29,38-130]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Local qualification and manifest policy | Maintainer tooling | Isolated checkout | Shell orchestration invokes existing Elixir/Jason validators; no shipped runtime owner. [VERIFIED: .planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md:109-115] |
| CI/Nightly and protection acquisition | GitHub API / Actions | Maintainer tooling | Remote runs, attempts, and effective rules are mutable service facts. [CITED: https://docs.github.com/en/rest/actions/workflow-runs] |
| Package and twin identity | Built artifact / generated consumer | Maintainer tooling | Archive and unpacked payload need separate byte identities. [VERIFIED: test/install_smoke/support/generated_app_helper.ex:358-378] |
| Inbox, advisory and disposition truth | GitHub/Hex APIs | Maintainer tooling | Private visibility and pagination live at each source boundary. [CITED: https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api] |
| Retained proof | Restricted local storage / GitHub artifact | Maintainer tooling | Manifest stays outside its subject; locator binds uploaded bundle. [VERIFIED: .planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md:25-27,116-123] |

## Project Constraints (from AGENTS.md)

- Keep Codex runtime model routing consistent with intentional project-level override changes; this phase changes no routing. Preserve worktree isolation and fail-closed adapter behavior. [VERIFIED: AGENTS.md:3-17]
- Keep edits focused; follow RUNNING.md and release-publish gates. Update PROJECT.md only for intentional scope or shipped-claim changes. [VERIFIED: AGENTS.md:19-24]
- Close active requirements through executable tests/probes/collectors, never human UAT. Run `./scripts/maintainer/automation_first_contract.sh` after changing active planning artifacts. [VERIFIED: AGENTS.md:25-30]
- Preserve green-main PR-first release train, its merge-blocking lanes and demand-gated posture; run `./scripts/maintainer/repo_hygiene_check.sh` before release prep. [VERIFIED: AGENTS.md:35-44]

## Standard Stack

| Component | Existing authority and version | Use |
|-----------|--------------------------------|-----|
| Bash + Git + `gh` + `jq` | Repository shell seams; local git 2.41.0, gh 2.101.0, jq 1.7.1 observed 2026-10-22. [VERIFIED: scripts/ci/verify_nightly_run.sh:97-153; scripts/ci/check_required_checks.sh:25-48; environment probe 2026-10-22] | Bounded command orchestration, REST acquisition, pagination, raw receipt transport. |
| Elixir script + existing Jason | `evidence_census.exs` and `validate_evidence_census.exs` already split collection and pure validation. [VERIFIED: scripts/maintainer/evidence_census.exs:197-215; scripts/maintainer/validate_evidence_census.exs:97-107] | New narrow pure readiness schema/policy validation, with no public application code. |
| GitHub Actions API and pinned artifact action | Run, attempt-job, branch-rule and artifact contracts. [CITED: https://docs.github.com/en/rest/actions/workflow-runs] [CITED: https://docs.github.com/en/rest/actions/workflow-jobs#list-jobs-for-a-workflow-run-attempt] [CITED: https://docs.github.com/en/rest/repos/rules#get-rules-for-a-branch] [CITED: https://github.com/actions/upload-artifact/tree/v4] | Complete read-only remote proof and portable redacted retention. |

**Installation:** No new external package recommended. Reuse committed Mix/Hex dependencies and pinned Actions. [VERIFIED: .planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md:109-123] Package legitimacy gate is inapplicable unless execution introduces a dependency, which would require fresh official-source and registry verification. [ASSUMED]

## Architecture Patterns

```text
authoritative remote main ref → immutable subject checkout → local gate executions
                                           ↓                       ↓
                           package archive/payload → consumer/twin receipts
                                           ↓                       ↓
GitHub CI + scheduled Nightly + protection + complete remote inbox/security
                                           ↓
                              normalized source receipts
                                           ↓
                              pure manifest validator
                                  ↙             ↘
                         ready + locator      not_ready + reason/repair
```
[VERIFIED: .planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md:15-130]

1. **Execution preflight:** Run `139-preflight.sh`; it checks Phase 133–138 reports/summaries, recomputes the immediate Phase 138 covered digest, and independently verifies retained Phase 138 matrix inputs/receipt. At closing qualification, run the same contracts on the new exact subject. [VERIFIED: .planning/phases/139-exact-head-readiness-closure/139-preflight.sh]
2. **Observation/decision split:** Acquire each remote source to a private raw receipt with request identity, pages, status, interval and completeness; normalize into a redacted portable receipt. Run a pure offline validator over all bytes and digests, then reobserve mutable sources and main before terminal verdict. GitHub pagination uses Link headers. [VERIFIED: scripts/maintainer/evidence_census.exs:197-215,239-250] [CITED: https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api]
3. **Attempt integrity:** List all eligible runs without success filtering; choose newest by deterministic run ordering, bind current attempt, collect all pages of jobs for that attempt, and re-read attempt/status after collection. Scheduled Nightly must include scheduled incident jobs; dispatch skip expectations in current verifier are event-specific. [VERIFIED: scripts/ci/verify_nightly_run.sh:97-129,156-179] [VERIFIED: .github/workflows/nightly.yml:538-545] [CITED: https://docs.github.com/en/rest/actions/workflow-jobs#list-jobs-for-a-workflow-run-attempt]
4. **Finite proof registry:** Derive IDs and applicability from the committed gate policy and upstream receipt schemas. Reject missing/duplicate/unknown trust-bearing IDs, stale SHA/input/tool identity, partial outcomes and unexplained exemptions. On every run, persist a nonpassing attempt record before command execution, then atomically finalize after all cleanup and remote rechecks. [VERIFIED: .planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md:38-65]
5. **Two-layer artifact identity:** Hash actual package archive bytes, unpacked payload bytes, and consumer/twin referenced bytes under explicit digest-kind fields. Preserve helper's metadata digest under its true label during normalization; never interpret it as the archive. [VERIFIED: test/install_smoke/support/generated_app_helper.ex:358-378]
6. **Effective protection:** Compare committed `"file": "ci.yml"`, `"name": "CI"`, `"job_id": "ci-summary"`, and `"contexts": ["CI Summary"]` against classic protection's legacy and structured checks plus applicable active rules, with integration binding and bypass/enforcement facts. [VERIFIED: config/ci_required_checks.json:1-11] [CITED: https://docs.github.com/en/rest/repos/rules#get-rules-for-a-branch] [CITED: https://docs.github.com/en/rest/branches/branch-protection#get-status-checks-protection]

### Recommended project structure

Keep new collector/orchestrator, pure policy module/script, fixture tests and maintainer instructions beside existing `scripts/maintainer` and `scripts/ci` seams. Use delivered upstream paths named in the reconciliation above. The scoped Doctor correction lives in the existing runtime-check modules. [VERIFIED: .planning/PROJECT.md; .planning/phases/139-exact-head-readiness-closure/139-preflight.sh]

## Don't Hand-Roll

### Remote source coverage contract

| Source | Required collection and comparison |
|--------|------------------------------------|
| Issues and PRs | Traverse both the issue and pull-request views for the target repository; GitHub's issues response includes PRs, identified by `pull_request`, so deduplicate by stable identity and separately fetch PR head/check details. Revisit ledger items that disappeared from the open set. [CITED: https://docs.github.com/en/rest/issues/issues#list-repository-issues] [CITED: https://docs.github.com/en/rest/pulls/pulls#list-pull-requests] |
| PR checks and legacy statuses | For each exact PR head, collect complete check-run history and commit statuses as distinct feeds, then apply the committed latest-attempt/check policy. A default latest view alone cannot demonstrate absence of a later failed attempt. [CITED: https://docs.github.com/en/rest/checks/runs#list-check-runs-for-a-git-reference] [CITED: https://docs.github.com/en/rest/commits/statuses#list-commit-statuses-for-a-reference] [VERIFIED: .planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md:87-105] |
| Security | Collect repository advisories, Dependabot alerts, and Hex audit with separate permission, query, database/input, page-completion and redaction records. Never infer one source from another. [CITED: https://docs.github.com/en/rest/security-advisories/repository-advisories#list-repository-security-advisories] [CITED: https://docs.github.com/en/rest/dependabot/alerts#list-dependabot-alerts-for-a-repository] [VERIFIED: .planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md:87-105] |
| Protection | Read classic branch protection and the active rules for `main`; compare normalized required checks, app bindings, enforcement and bypass facts. [CITED: https://docs.github.com/en/rest/branches/branch-protection#get-status-checks-protection] [CITED: https://docs.github.com/en/rest/repos/rules#get-rules-for-a-branch] |
| CI/Nightly and artifacts | Traverse workflow run and attempt-job pages; re-read attempt after collection. Retain run/attempt/artifact IDs and independently hash retrieved bundle bytes. [CITED: https://docs.github.com/en/rest/actions/workflow-runs] [CITED: https://docs.github.com/en/rest/actions/workflow-jobs#list-jobs-for-a-workflow-run-attempt] [CITED: https://docs.github.com/en/rest/actions/artifacts] |

Each source needs an observed interval and a completion flag. A failed lookup records no observed inventory; a `304` conditional response requires the exact retained representation and request context. GitHub does not offer this collector a cross-endpoint atomic snapshot, so reobserve mutable decision inputs before finalizing. [VERIFIED: .planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md:87-105] [CITED: https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api#use-conditional-requests]

| Problem | Use instead | Why |
|---------|-------------|-----|
| JSON syntax/canonical decoding | Existing Jason and `jq` seams | Their behavior is already exercised in maintainer scripts. [VERIFIED: scripts/maintainer/evidence_census.exs:197-215; scripts/ci/eval_nightly_summary.sh:30-98] |
| GitHub page traversal | REST Link-header contract and bounded reusable fetch helper | One-page `--limit` commands can truncate inventories. [CITED: https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api] [VERIFIED: scripts/ci/verify_nightly_run.sh:97-109] |
| New PR required context | Existing `CI Summary` topology | `ci-summary` already gates script tests transitively; full closure belongs off PR critical path. [VERIFIED: .github/workflows/ci.yml:1425-1465] |
| Independent adoption attestation | Keep PILOT-01/02 as future executable gates | Maintainer synthetic evidence cannot establish a named external adopter. [VERIFIED: .planning/REQUIREMENTS.md:66-77] |
| Signature/SLSA service | Byte hash and pinned artifact transport | User locked byte identity scope without signing claim. [VERIFIED: .planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md:116-123] |

## Common Pitfalls

- **A newer local toolchain passes a narrower gate:** resolve versions from committed supported-cell policy; record actual Elixir/OTP and isolate build outputs. Current shell shims fail to resolve Erlang locally, so execution environment needs explicit provision before qualification. [VERIFIED: .github/workflows/ci.yml:46-55; .github/workflows/nightly.yml:47-60; environment probe 2026-10-22]
- **Dispatch Nightly marked scheduled:** existing verifier asserts `"workflow_dispatch"` and attempt `1`; scheduled incident jobs have distinct applicability. Add scheduled-specific fixtures and source acquisition, reusing pure policy only where equivalent. [VERIFIED: scripts/ci/verify_nightly_run.sh:325-346; .github/workflows/nightly.yml:538-545]
- **Green summary masks incomplete main run:** current `eval_ci_summary.sh` accepts `"success"` or `"skipped"` for its PR aggregation; full main run needs every applicable job and complete successful selected attempt. [VERIFIED: scripts/ci/eval_ci_summary.sh:16-59; .github/workflows/ci.yml:1441-1453]
- **Hygiene warning mistaken for acceptance:** local check currently executes `git fetch ... || true`; CI mode omits local worktree checks; use the upstream strict replacement or add closure-specific hard validation, including ignored/untracked and post-cleanup state. [VERIFIED: scripts/maintainer/repo_hygiene_check.sh:189-228]
- **Protection diff mistaken for enforcement:** current helper reads `.contexts[]` and tolerates `diff ... || true`; require both check representations and effective rulesets in a separate accepting validator. [VERIFIED: scripts/ci/check_required_checks.sh:42-62] [CITED: https://docs.github.com/en/rest/repos/rules#get-rules-for-a-branch]
- **Remote empty list mistaken for complete visibility:** distinguish 200 empty from permission error, private-resource 404, timeout, rate-limit response, or missing pages. Dependabot and repository advisories have separate permissions and coverage. [CITED: https://docs.github.com/en/rest/dependabot/alerts#list-dependabot-alerts-for-a-repository] [CITED: https://docs.github.com/en/rest/security-advisories/repository-advisories#list-repository-security-advisories]
- **Cleanup call mistaken for clean state:** `File.rm_rf(workspace_root)` result is discarded before `:ok`; require observed absence and owned-resource inventory after attempted cleanup. [VERIFIED: test/install_smoke/support/generated_app/workspace.ex:13-19]
- **Upload URL mistaken for durable bytes:** compare downloaded archive bytes and local retained copy against locator digest; expiration/inaccessibility leaves history, not current acceptance. [CITED: https://docs.github.com/en/actions/tutorials/store-and-share-data#validating-artifacts] [VERIFIED: .planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md:116-123]

## Code Examples

Existing policy identity, quoted verbatim: `"file": "ci.yml"`, `"name": "CI"`, `"job_id": "ci-summary"`, `"contexts": ["CI Summary"]`. [VERIFIED: config/ci_required_checks.json:3-10]

Existing Nightly applicability vocabulary, quoted verbatim: `"always"`, `"upstream-repository-and-required-secrets"`, `"not-upstream-repository"`, `"required-secrets-unavailable"`, `"passed"`, `"not-run"`. [VERIFIED: scripts/ci/eval_nightly_summary.sh:36-83]

Existing package digest implementation, quoted verbatim:
```elixir
package_sha256: file_sha256!(Path.join(package_root, "hex_metadata.config")),
unpacked_tree_sha256: package_tree_sha256,
```
[VERIFIED: test/install_smoke/support/generated_app_helper.ex:358-367]

Existing census receipt identity pattern, quoted verbatim:
```elixir
"source_sha" => options.source_sha,
"dirty" => dirty?,
"toolchain" => %{
  "elixir" => System.version(),
  "otp" => :erlang.system_info(:otp_release) |> List.to_string()
},
"inputs" => inputs,
```
[VERIFIED: scripts/maintainer/evidence_census.exs:203-211]

## Validation Architecture

| Property | Value |
|----------|-------|
| Framework | Existing Bash/jq script fixtures and ExUnit/Mix script tests. [VERIFIED: .github/workflows/ci.yml:1425-1439; test/install_smoke/evidence_census_test.exs] |
| Quick run | `bash scripts/ci/test_nightly_summary_gate.sh`; add Phase 139 pure-validator fixtures to `ci-script-tests` and run their focused command. [VERIFIED: .github/workflows/ci.yml:1425-1439] |
| Full suite | `mix ci` plus main CI/Nightly live verification and isolated qualification, off PR critical path. [VERIFIED: RUNNING.md:109-191; .planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md:76-101] |

| Requirement | Automated proof | Wave 0 gap |
|-------------|-----------------|------------|
| READY-01 | Wrong supported pair, stale tool/input, failed command, package archive/payload mismatch, dirty initial/final checkout, residue and failed cleanup fixtures; real generated consumer/twin execution. | New offline manifest/receipt fixtures and exact-head orchestrator. |
| READY-02 | Wrong event/SHA/branch/repository; newer failed/pending run; changed attempt; missing/duplicate/partial job pages; scheduled incident applicability; protection contexts/app/bypass drift. | New run/protection source normalizer and mock API fixtures. |
| READY-03 | Open item without disposition, absent tracked item, changed PR head/check, new advisory, unauthorized/404/truncated security page, separate Hex audit identity. | Phase 134 contract adapters and source-complete fixtures once delivered. |
| READY-04 | Duplicate/missing/unknown proof IDs, forged success, digest corruption, crash-before-finalization, stale remote and incomplete cleanup. | Versioned schema and pure validator with failing examples. |
| READY-05 | Synthetic-to-independent inflation, PILOT checkbox/1.0 claim, changed release truth. | Executable parity fixtures against authoritative planning/release data. |

[VERIFIED: .planning/REQUIREMENTS.md:66-77; .planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md:137-145] Per task, run focused deterministic fixtures; per wave, run script tests and relevant existing Mix suite; terminal phase gate must collect the actual remote and isolated evidence, not human UAT. [VERIFIED: AGENTS.md:25-30; .planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md:76-101]

## Security Domain

| ASVS category | Applies | Control |
|---------------|---------|---------|
| V2 Authentication | yes, remote collection | Existing authorized `gh`/connector credential; preserve source-specific auth failure. [CITED: https://docs.github.com/en/rest/dependabot/alerts#list-dependabot-alerts-for-a-repository] |
| V3 Session Management | no shipped session | Maintainer CLI scope only. [VERIFIED: .planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md:109-115] |
| V4 Access Control | yes, private advisory receipt and protection visibility | Restrict raw evidence location; public bundle redacts security content while retaining coverage/digest proof. [CITED: https://docs.github.com/en/rest/security-advisories/repository-advisories#list-repository-security-advisories] |
| V5 Input Validation | yes | Strict Jason schema, bounded source pages, exact subject/repository, duplicate ID rejection. [VERIFIED: scripts/maintainer/validate_evidence_census.exs:97-107,151-166] |
| V6 Cryptography | yes, integrity only | Existing `:crypto.hash(:sha256, bytes)`; no authenticity or signature claim. [VERIFIED: scripts/maintainer/evidence_census.exs:239-250] |

Known threats: forged receipt (tampering) → rehash raw receipt and validate source identity; truncated API response (information integrity) → complete pagination and response-status proof; token leakage (information disclosure) → private raw receipt and redacted bundle; malicious path in manifest (path traversal) → confined resolved receipt paths. [VERIFIED: .planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md:42-65,100-123]

## Environment Availability

| Dependency | Available in current shell | Limitation / execution gate |
|------------|----------------------------|-----------------------------|
| Git 2.41.0, gh 2.101.0, jq 1.7.1 | yes | Remote API authorization and effective protection/security visibility were not exercised here. [VERIFIED: environment probe 2026-10-22] |
| Mix/Elixir via asdf | shims present | Both reported `No version is set for command erl`; exact supported pairs must be provisioned at execution. [VERIFIED: environment probe 2026-10-22] |
| Docker 29.5.2, PostgreSQL readiness, FFmpeg 8.0.1 | available | Does not prove full MinIO/provider or supported CI cell readiness. [VERIFIED: environment probe 2026-10-22] |
| Real scheduled Nightly on closing subject | future observation | Execution must await the next eligible scheduled run and reject substitute dispatch proof. [VERIFIED: .planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md:68-78] |

## Open Questions and Execution Preflight

1. **Upstream receipt contracts:** Phases 134, 135, 137 and 138 have no completed contracts in the current checkout; Phase 136 is planned but blocked. At execution, discover actual tracked validators/receipts and require terminal executable qualification before adapting the Phase 139 manifest. [VERIFIED: .planning/ROADMAP.md:512-538; .planning/STATE.md:25-53; repository file inventory 2026-10-22]
2. **Authorized private source visibility:** Run read-only scope/reachability probes for advisories, Dependabot, protection and artifacts; distinguish absent authorization from empty inventory. No token material belongs in a bundle. [CITED: https://docs.github.com/en/rest/dependabot/alerts#list-dependabot-alerts-for-a-repository] [CITED: https://docs.github.com/en/rest/security-advisories/repository-advisories#list-repository-security-advisories]
3. **Historical local retention mechanism:** Choose an existing restricted location and document ownership, cleanup, and retrieval; keep the default 30-day remote closeout retention within repository settings. [VERIFIED: .planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md:116-123]

## Assumptions Log

| # | Claim | Risk if wrong |
|---|-------|---------------|
| A1 | [ASSUMED] No new package is necessary after future upstream contracts land. | If a new dependency becomes necessary, perform official-source and registry legitimacy checks before planning install. |

## Sources

**Primary repository truth:** `AGENTS.md`, `RUNNING.md`, `.planning/CONTEXT/REQUIREMENTS/ROADMAP/STATE/PROJECT`, committed CI policy/workflows, maintainer validators, generated-consumer support, and script tests as cited inline. [VERIFIED: repository reads 2026-10-22]

**Official GitHub references:** [Workflow runs](https://docs.github.com/en/rest/actions/workflow-runs), [attempt jobs](https://docs.github.com/en/rest/actions/workflow-jobs#list-jobs-for-a-workflow-run-attempt), [active branch rules](https://docs.github.com/en/rest/repos/rules#get-rules-for-a-branch), [branch protection](https://docs.github.com/en/rest/branches/branch-protection#get-status-checks-protection), [pagination](https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api), [Dependabot alerts](https://docs.github.com/en/rest/dependabot/alerts#list-dependabot-alerts-for-a-repository), [repository advisories](https://docs.github.com/en/rest/security-advisories/repository-advisories#list-repository-security-advisories), [conditional requests](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api#use-conditional-requests), [artifact validation](https://docs.github.com/en/actions/tutorials/store-and-share-data#validating-artifacts). [CITED: https://docs.github.com/en/rest/actions/workflow-runs]

**Confidence:** HIGH for existing repository seams, delivered upstream validators and locked phase contract; MEDIUM for live GitHub API integration until authorized source probes. **Researched:** 2026-10-22; reconciled after Phase 138 verification. **Review freshness:** refresh mutable GitHub API facts and exact-subject contracts at execution. [VERIFIED: .planning/phases/139-exact-head-readiness-closure/139-preflight.sh]
