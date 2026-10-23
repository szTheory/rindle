# Phase 139: Exact-Head Readiness Closure - Discussion Log (Assumptions Mode)

> This log preserves the original pre-execution discussion. Phase 133–138 completion,
> the explicit Phase 136 numeric-speed deferral, and the Phase 139 Doctor assignment
> are reconciled in `139-CONTEXT.md` and the eight current plans.

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md; this log preserves the analysis and rejected alternatives.

**Date:** 2026-10-22
**Phase:** 139-exact-head-readiness-closure
**Mode:** assumptions; user-delegated research and decide-by-default synthesis
**Areas analyzed:** revision authority, qualification/cleanup, CI/Nightly/protection, remote/security
completeness, evidence retention, maintainer experience, adoption truth.

## User Direction and Workflow Adaptation

The user invoked `$gsd-discuss-phase 139`, then explicitly requested research using subagents,
consideration of all relevant tradeoffs to diminishing returns, and one cohesive recommendation set
so routine decisions would not require their arbitration. Project PROJECT.md/METHODOLOGY.md independently
require research-first, decide-by-default discussion. The configured discuss mode is `assumptions`.

The generic confirmation interview was therefore superseded by this explicit delegation. Decisions
are agent-selected under that direction, not individually user-confirmed assumptions. No `--auto`
lifecycle was requested or started; planning/execution did not auto-advance.

No context or plans previously existed for Phase 139; no matching pending todos were found. Current
STATE.md identifies Phase 133 as active with pending requirements. Phase 139 discussion is preparation
ahead of execution, consistent with the already recorded Phase 136 planning posture. It grants zero
requirement credit and preserves the active executor/session continuity.

## Research Performed

1. A routed `gsd-assumptions-analyzer` inspected repository requirements, prior Phase 133 decisions,
   methodology, relevant prompt framing, evidence research, workflows, scripts, and tests. Resolver
   supplied `gpt-6.1-sol` / `xhigh`; this did not change project routing configuration.
2. Three independent research agents investigated official documentation and repository seams:
   GitHub run/protection authority; complete current remote/security inventory; manifest retention
   and idiomatic maintainer experience. Agents performed no edits or remote mutations.
3. Parent synthesis reconciled the recommendations and checked key local seams. Research stopped
   when the streams agreed on the boundaries and no material unresolved decision remained. General
   media architecture and UI exploration were not expanded because they do not resolve READY-01–05.

## Assumptions Analyzed

| Assumption | Initial confidence | Evidence / consequence |
|---|---|---|
| Final authority is post-merge main, with detached evidence | Likely | ROADMAP/PROJECT and release exact-SHA coupling; branch-only proof misses merge changes and in-tree final receipts create a SHA cycle. |
| Fresh isolated qualification needs initial/final cleanliness and real cleanup proof | Confident | Research PITFALLS, RUNNING, hygiene and workspace helpers; otherwise stale output or retained resources survive a green exit. |
| Full exact-main CI/Nightly and effective protection need explicit verification | Confident | CI topology, strict Nightly evaluator, required-check config; green summary/informational diff can miss main-only work or ruleset drift. |
| Revalidate Phase 134 ledger using complete current source coverage | Likely | READY-03 and Phase 134 ownership; old snapshots can omit new blockers or invalidated dispositions. |
| Synthetic proof leaves PILOT-01/02 open | Confident | REQUIREMENTS/PROJECT and live-truth validator; broader claims would erase the independence requirement. |

## Alternatives and Tradeoffs

| Decision | Chosen approach and benefit | Cost / rejected alternative |
|---|---|---|
| Revision | Final merged main SHA; proves deployed repository topology | Branch proof is faster but cannot certify the merge commit. A later docs commit needs fresh qualification. |
| Manifest storage | Detached bundle with compact separate locator; no self-reference | Explicit retention/availability management; committing final receipts into their own subject cannot work. |
| Nightly event | Real scheduled exact-main run for final closure; covers existing scheduled incident policy | Can wait for cron and become stale if main advances. Dispatch can prove compute for READY-02 alone, but cannot replace scheduled recovery under EVID-04. |
| Run selection | Newest eligible run, full selected attempt, exact identity/job set | More checks than selecting a green URL; do not cherry-pick an old success or combine partial reruns. |
| Protection | Effective classic + active ruleset rules with provider identity | Needs sufficient read visibility; legacy contexts-only diff is cheaper and incomplete. |
| Remote freshness | Complete acquisition plus final revalidation in one bounded invocation | Extra read requests; fixed TTL or updated-at-only deltas cannot establish complete current membership. |
| Inbox | Revalidate evidence-backed dispositions; retained/deferred items may remain open | Requires ledger joins; inbox zero is a misleading simpler count. |
| Security | Separate advisories, Dependabot and Hex audit source identities | Visibility must be established; empty public/Dependabot results do not prove unpublished or Hex coverage. |
| Tooling | Existing scripts/Jason, pure validator, one documented maintainer entry | Some orchestration remains shell; a public Mix API, evidence database, or service adds unjustified product surface. |
| Cleanup | Owned-resource cleanup outcome plus observed residue | More than calling an existing helper; force-cleaning unrelated work is unacceptable. |
| Retention | Existing artifact mechanism, 30-day default within repository policy, portable local copy | Bounded availability; permanent signed platform is unnecessary and creates new trust/cost obligations. |
| Recurring CI | Cheap policy regressions in existing seam; full closure outside PR path | Closure takes longer than a PR check; avoids degrading the accepted feedback envelope. |

## Repository Footguns Applied to Recommendations

- `scripts/ci/check_required_checks.sh` reads legacy contexts and intentionally ignores diff failure.
  Keep it diagnostic or reuse an upstream strict replacement; do not treat its zero exit as protection proof.
- `scripts/maintainer/repo_hygiene_check.sh` suppresses fetch failure, reads latest branch CI without SHA,
  skips clean-tree checks in `--ci`, and can succeed with WARN. READY-01/02/04 require stronger binding.
- `test/install_smoke/support/generated_app_helper.ex` names the metadata-file digest `package_sha256`;
  the unpacked tree is separately hashed. An evidence consumer must distinguish these from archive bytes.
- `test/install_smoke/support/generated_app/workspace.ex` ignores `File.rm_rf`'s outcome. Readiness needs
  observed cleanup success and residue inventory, not a nominal `:ok`.
- Earlier phases may repair these seams before Phase 139. The future planner must inspect their final
  implementations rather than independently redo those repairs or hard-code today's missing artifacts.

## External Research Applied

- GitHub schedules use default-branch history and can be delayed/dropped; actual returned SHA/event,
  not requested branch or cron time, establish provenance. Reruns retain original SHA/ref.
  [Events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule),
  [reruns](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs).
- Workflow discovery and job collection have pagination, attempt identity and filter semantics. Keep
  complete expected jobs and reject mixed attempts.
  [Runs](https://docs.github.com/en/rest/actions/workflow-runs),
  [jobs](https://docs.github.com/en/rest/actions/workflow-jobs#list-jobs-for-a-workflow-run-attempt).
- Classic required checks expose structured provider bindings; applicable active rules can include
  organization rulesets. Their read permissions differ.
  [Protection](https://docs.github.com/en/rest/branches/branch-protection#get-status-checks-protection),
  [branch rules](https://docs.github.com/en/rest/repos/rules#get-rules-for-a-branch).
- Issues include PRs; checks and legacy statuses are separate; latest-only defaults and endpoint caps
  require deliberate complete collection. Follow Link pagination, not just a large page size.
  [Issues](https://docs.github.com/en/rest/issues/issues#list-repository-issues),
  [checks](https://docs.github.com/en/rest/checks/runs#list-check-runs-for-a-git-reference),
  [statuses](https://docs.github.com/en/rest/commits/statuses#list-commit-statuses-for-a-reference),
  [pagination](https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api).
- ETags refresh a specific representation; no reviewed source guarantees atomic consistency across
  endpoints. Same-invocation acquisition/revalidation is a practical recommendation, not an atomicity claim.
  [Conditional requests](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api#use-conditional-requests).
- Unpublished advisory visibility requires adequate role/access, and Dependabot is distinct from Hex
  audit evidence. Inaccessible scopes cannot be interpreted as empty.
  [Advisories](https://docs.github.com/en/rest/security-advisories/repository-advisories#list-repository-security-advisories),
  [alerts](https://docs.github.com/en/rest/dependabot/alerts#list-dependabot-alerts-for-a-repository),
  [ecosystems](https://docs.github.com/en/code-security/reference/supply-chain-security/dependency-graph-supported-package-ecosystems).
- Artifact immutability is scoped to the artifact ID, not permanent availability. Retention expires;
  replacement has a different identity. Download digest warnings need stricter explicit validation.
  [Upload action](https://github.com/actions/upload-artifact/tree/v4),
  [artifact API](https://docs.github.com/en/rest/actions/artifacts),
  [digest validation](https://docs.github.com/en/actions/tutorials/store-and-share-data#validating-artifacts).
- Mix tasks run once per VM unless reenabled and have startup/environment semantics. Existing scripts
  with explicit policy are adequate; no new adopter-facing task is warranted.
  [Mix.Task](https://hexdocs.pm/mix/Mix.Task.html).
- Borrow immutable-subject/digest vocabulary without claiming a new attestation standard or signing.
  [in-toto subjects](https://github.com/in-toto/attestation/blob/main/spec/v1/statement.md),
  [SLSA provenance](https://slsa.dev/spec/v1.2/provenance).

These sources informed design only. No current live repository protection, advisories, permissions,
CI results, Nightly success, or inventory completeness was asserted or certified in this session.

## Methodology Applied

- **Repo truth:** active Phase 133 state outranks outdated prompt roadmap snapshots; ahead-of-execution
  discussion does not update requirement status or displace the executor's handoff.
- **Adopter/JTBD:** serve maintainers deciding readiness, contributors reproducing failure, security
  reviewers checking coverage, and adopters reading truthful support claims.
- **Idiomatic Elixir / least surprise:** explicit composable boundaries and pure policy around existing
  tools; no runtime config, schema, Plug, Phoenix, or API expansion for an internal closure job.
- **Automation first:** every READY requirement closes through executable evidence and negative fixtures;
  credentials/irreversible-action authority remains separate from behavioral acceptance.
- **Performance / SRE:** bounded collection, preserved failure outcomes, scoped cleanup, immutable static
  inputs, and no new privileged remote work on the PR critical path.
- **Security / accessibility / UX:** sufficient read visibility, redacted portable receipts, text state
  rather than color-only output, and actionable diagnostics; visual/UI redesign is not applicable.
- **Diminishing returns:** stop at the finite five-requirement closure and return to demand-gated posture.

## Corrections and Remaining Decisions

No per-item user corrections were requested under the explicit research/decide-by-default delegation.
The synthesis makes the scheduled final path and 30-day retention default explicit design choices,
not requirements imposed by GitHub. No unresolved high-blast-radius choice remains.

Upstream artifact paths and supported implementation details must be re-read when planning and again
before execution. There is no authorization here to resume historical attempts, dispatch Nightly,
change protection, close issues, publish, or merge.
