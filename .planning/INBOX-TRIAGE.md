# Inbox Triage — 2026-08-28

Repository posture: **demand-gated pause**. This pass classifies the live inbox against the
green-main release train; it does not authorize a feature milestone.

## Pull requests

| PR | Classification | Evidence | Disposition |
|---|---|---|---|
| [#93](https://github.com/szTheory/rindle/pull/93) Actions maintenance | Ready after refresh | Latest head has a green `CI Summary`; branch is behind `main`. The change only advances the already-pinned `actions/checkout` and `erlef/setup-beam` revisions. | Rebase after the baseline PR lands, require a fresh green `CI Summary`, then merge. |
| [#95](https://github.com/szTheory/rindle/pull/95) MuonTrap 2.0 | Incompatible as proposed | Rindle passes v1-only `cgroup_controllers` and `cgroup_sets`; MuonTrap 2 replaces them with a v2 `cgroup` map. CI disables cgroups, so the green run does not exercise the breaking path. | Close with an explanatory comment. Re-open as a separately chartered cgroup-v2 migration only if demanded. |
| [#98](https://github.com/szTheory/rindle/pull/98) mixed dependency group | Invalid batch | A group named `dev-dependencies` contains five runtime dependencies, including behavior-bearing Image, Oban, and ExAws upgrades. Its only failing lane is the existing automation-contract pipe race fixed by this baseline branch. | Close as superseded by the corrected Dependabot grouping; let runtime updates return as individual PRs. |

## Issues

| Issue | Classification | Evidence | Disposition |
|---|---|---|---|
| [#88](https://github.com/szTheory/rindle/issues/88) Nightly CI failure | Actionable, fix in flight | The latest Nightly failure is the unreachable GCS CORS decode branch reported by Dialyzer. The baseline branch removes that branch and focused GCS tests pass. | Keep open until the baseline PR merges and an exact-head Nightly run is green; allow the Nightly reporter to close/update it. |
| [#42](https://github.com/szTheory/rindle/issues/42) rare async-isolation race | Valid, evidence-gated | The last finite matrix stopped after one run because of an unrelated automation-contract pipe failure, so it did not produce the evidence required to close or broaden the issue. | Keep open at its narrowed boundary. Re-run only when a bounded reliability signal authorizes it; do not turn it into a speculative milestone. |

## Repository follow-through

- `.github/dependabot.yml` now limits the Mix group to `dependency-type: development`, with a
  regression test locking the policy.
- The missing `dependencies` and `ci` labels should be created so Dependabot can apply the labels
  already declared in repository configuration.
- No roadmap candidate is promoted. LIFE-06 and STREAM-10 remain signal-gated; the JTBD anchor is
  refreshed to the post-v1.25 / Hex 0.4.5 baseline.
