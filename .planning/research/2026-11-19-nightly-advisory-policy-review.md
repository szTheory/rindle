# Nightly’s role in development readiness

**Decision:** Keep the scheduled Nightly workflow as a strict, self-reporting operations and compatibility signal. Make it advisory for ordinary development, branch protection, release readiness, general candidate readiness, and new DevOps certifications. A red or stale Nightly should trigger triage through its own summary and incident path; it should not stop unrelated work or readiness collection. A concrete defect may be gated under its own severity policy, regardless of how it was found. Keep exact-source CI, effective branch protection, current remote dispositions and adoption parity as machine-enforced readiness gates.

## Why

- The repository already separates `.github/workflows/nightly.yml` from `.github/workflows/ci.yml`. Its checked-in required-check contract names `CI Summary`; effective remote branch protection remains a separate exact-state gate. The snapshot wait came from READY-02 and its mandatory Nightly qualification plus scheduled-incident-health proofs, not GitHub branch protection. A second pass found the exact-head v1 collector also required a scheduled Nightly. Forward exact-head v2 and snapshot v4 remove Nightly from general readiness; v1/v3 keep their historical meanings.
- Nightly covers slower compatibility and provider-dependent checks, plus its own incident reporting. Those checks can detect drift that PR CI should not depend on, so deleting the workflow would discard useful signal. Making every Nightly job `continue-on-error` would hide the workflow’s own failure signal without fixing the readiness dependency.
- GitHub documents that scheduled workflows run on the latest default-branch commit, and that schedule events can be delayed or dropped under load. A schedule is therefore a poor prerequisite for a particular captured candidate and a poor clock for ordinary developer progress. [GitHub schedule event](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule)
- GitHub documents that required status checks block protected-branch merges when they are configured as required. The repository’s current required-check contract names `CI Summary`, so removing Nightly from general readiness does not weaken GitHub’s configured merge gate. [GitHub protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches#require-status-checks-before-merging), [GitHub status checks](https://docs.github.com/en/pull-requests/reference/status-checks)

## Stakeholder review

| Lens | Finding | Recommendation |
|---|---|---|
| Developer experience | A calendar-triggered result can block work even when the required CI has already passed. | Never make scheduled Nightly the only next development action. |
| CI/release engineering | Nightly has valuable slow and external-provider coverage; merging it into CI could also couple it to release automation. | Keep the workflow separate, preserve its strict summary and incident handling, and keep its status out of required checks. |
| Security/quality | A failing Nightly should remain visible; masking job failures would reduce diagnostic value. | Keep failures red inside Nightly and advisory outside it. Gate concrete defects by severity, not by Nightly status. Keep exact-SHA CI, branch protection, and security checks fail-closed. |
| Evidence integrity | Candidate qualification and scheduled operational health are distinct claims. | General readiness binds to its candidate’s CI and protection state. Do not infer candidate readiness from Nightly, and do not require Nightly freshness for it. |
| Product/maintainer operations | Current Nightly jobs detect compatibility and provider drift and can drive incident follow-up. | Retain Nightly for those signals; revisit or remove it only if measured signal-to-maintenance value becomes poor. |

## Alternatives considered

1. **Keep Nightly required for readiness.** Rejected: makes progress depend on a schedule GitHub says can be delayed or dropped, and duplicates a policy gate not present in branch protection.
2. **Delete Nightly.** Rejected for now: it provides distinct slow compatibility, external-provider, and incident-lifecycle coverage. Preserve the signal while removing its authority to block ordinary work.
3. **Mark Nightly jobs non-failing.** Rejected: it hides actionable failures and does not fix the collector’s readiness dependency.
4. **Collect Nightly as optional readiness metadata.** Deferred: optional data can be added later if a clear user needs a unified dashboard. It is not needed to establish readiness and risks reintroducing a fail-open/closed ambiguity into the acceptance collector.

## Scope of the policy change

Create new policy versions for forward exact-head and snapshot acceptance. Keep exact-head v1 and snapshot v3 meanings attached to their historical receipts; do not rewrite or revalidate prior acceptance under new definitions. In exact-head v2 and snapshot v4, Nightly qualification, scheduled incident health, and scheduled Nightly are not required proofs. Report Nightly health through the Nightly workflow and its incident channel. Update READY-02, collectors, validators, policy fixtures, operator guidance, and durable agent instructions together. A passing fixture is implementation evidence only; it grants no READY credit.

## Implementation and regression evidence

The forward policy is implemented as versioned acceptance contracts:

- Exact-head v2 is the forward current-main policy; [the run collector](../../scripts/maintainer/collect_readiness_runs.py) and [acceptance controller](../../scripts/maintainer/readiness_acceptance.py) keep v1 available for historical receipts.
- Snapshot v4 is the forward fixed-candidate policy; [the subject policy](../../scripts/maintainer/readiness_subject.py), acceptance controller, and [closure validator](../../scripts/maintainer/readiness_closure.py) keep v3 available for historical receipts.
- Regressions cover both new defaults, historical policy compatibility, Nightly omission, and a default exact-head remote collection that does not read `nightly.yml`: [run policy](../../scripts/ci/test_readiness_runs.sh), [snapshot policy](../../scripts/ci/test_readiness_snapshot.py), [closure](../../scripts/ci/test_exact_head_closure.sh), [validator](../../scripts/ci/test_exact_head_readiness.sh), [acceptance](../../scripts/ci/test_readiness_acceptance.sh), and [remote collector](../../scripts/ci/test_readiness_remote.sh).
- Fixture passes establish contract behavior only. They do not close READY requirements or grant live readiness credit. The remote acceptance path retains its exact-source CI, protection, local qualification, current remote disposition, and adoption-parity requirements.

The operator policy lives in [VERIFICATION-POLICY.md](../VERIFICATION-POLICY.md), [DEVELOPMENT-TRAIN.md](../DEVELOPMENT-TRAIN.md), [RUNNING.md](../../RUNNING.md), and [readiness_evidence.md](../../guides/readiness_evidence.md). Root [AGENTS.md](../../AGENTS.md) and [planning AGENTS.md](../AGENTS.md) point future sessions to the policy and rationale.

## Sources

- Repository branch protection allowlist: [`config/ci_required_checks.json`](../../config/ci_required_checks.json)
- Separate PR/main and scheduled workflows: [`ci.yml`](../../.github/workflows/ci.yml), [`nightly.yml`](../../.github/workflows/nightly.yml)
- Current readiness requirement and policy: [`REQUIREMENTS.md`](../REQUIREMENTS.md), [`VERIFICATION-POLICY.md`](../VERIFICATION-POLICY.md)
- GitHub’s primary docs: [schedule events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule), [protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches#require-status-checks-before-merging), and [status checks](https://docs.github.com/en/pull-requests/reference/status-checks)
