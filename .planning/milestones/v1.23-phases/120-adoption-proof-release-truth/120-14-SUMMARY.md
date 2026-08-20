---
phase: 120-adoption-proof-release-truth
plan: 14
subsystem: release-proof
tags: [release-please, github-actions, hex, provenance, immutable-evidence, 0.4.0]
requires:
  - phase: 120-adoption-proof-release-truth
    provides: explicit 0.4.0 Release-As intent and release-doc parity contract
provides:
  - immutable PR, merge, CI, protected-release, GitHub, and Hex receipt for rindle 0.4.0
  - separated tooling and frozen-source identities for the provenance-recovery release path
affects: [release-train, package-consumer, cohort-demo, public-artifact-proof]
tech-stack:
  added: []
  patterns: [PR-first release, exact-SHA CI binding, protected recovery ref, idempotent existing-release verification]
key-files:
  created:
    - .planning/phases/120-adoption-proof-release-truth/120-14-SUMMARY.md
  modified: []
key-decisions:
  - "Keep Release Please and the protected Release workflow as the only versioning and publish paths; no manual tag or Hex publish was used."
  - "Treat the repaired workflow tooling SHA separately from the frozen published source SHA, and require every release gate to identify the latter explicitly."
  - "Recover the public artifact proof idempotently after the harness repair because Hex 0.4.0 already exists; do not republish an existing release."
patterns-established:
  - "Release evidence records the immutable candidate head, merge source, CI run identity, protected workflow tooling head, recovery ref, and public artifact state separately."
requirements-completed: [PROOF-01, PROOF-02, DOCS-01]
coverage:
  - id: D1
    description: "rindle 0.4.0 is traceable from its reviewed Release Please source through exact-SHA CI and the protected Release gate."
    requirement: PROOF-01
    verification:
      - kind: integration
        ref: "GitHub Actions ci.yml run 32371768158, attempt 2, exact source 78349c1bc5d082b0c0c9fce6796806011fa89a33"
        status: pass
      - kind: other
        ref: "GitHub Actions Release run 32383632492, Validate Recovery Ref and Gate on Exact-SHA Green CI"
        status: pass
    human_judgment: false
  - id: D2
    description: "The public Hex 0.4.0 artifact passes fresh installed-package verification without a duplicate publish."
    requirement: PROOF-02
    verification:
      - kind: e2e
        ref: "GitHub Actions Release run 32383632492, Public Verify / Verify public Hex.pm artifact"
        status: pass
      - kind: other
        ref: "https://hex.pm/api/packages/rindle/releases/0.4.0"
        status: pass
    human_judgment: false
  - id: D3
    description: "Generated 0.4.0 notes and public release metadata agree after maintainer-authorized review."
    requirement: DOCS-01
    verification:
      - kind: integration
        ref: "GitHub Actions ci.yml pull_request run 32322762504 for Release Please head 0747eff064eede1e560b0fab502feb9197644337"
        status: pass
      - kind: manual_procedural
        ref: "Maintainer-reviewed Release Please PR #59 before normal protected merge"
        status: pass
    human_judgment: false
metrics:
  completed: 2026-08-20
  tasks: 1
  files: 1
status: complete
---

# Phase 120 Plan 14: Immutable 0.4.0 Release Evidence Summary

**rindle 0.4.0 was released from frozen source `78349c1…`, with exact-source CI, protected recovery binding, idempotent Hex handling, and a fresh public installed-artifact proof all recorded separately from later tooling repairs.**

## Accomplishments

- Landed the explicit 0.4.0 Release-As correction through the ordinary PR lane and recorded the independent FFmpeg CI repair that unblocked hosted package jobs.
- Regenerated Release Please PR #59 from the prohibited 0.3.3 state into the reviewed 0.4.0 candidate, then required green exact-head PR CI before its separately authorized normal merge.
- Bound the published source to `78349c1bc5d082b0c0c9fce6796806011fa89a33`, its exact green push CI, the protected Release gate, GitHub tag/release, and Hex 0.4.0.
- Repaired the public-artifact provenance harness in PR #62 without changing the published source, then ran a protected idempotent recovery with repaired tooling and the frozen old source. The recovery detected existing Hex 0.4.0, did not republish it, and passed fresh public artifact verification.

## Maintainer Authorizations

1. The maintainer explicitly selected the ordinary reviewed correction path for the 0.4.0 release intent: PR #60 was allowed to land only after its exact merge SHA had green main CI.
2. The maintainer explicitly authorized the reviewed Release Please candidate with: `APPROVE RELEASE PR #59 at 0747eff064eede1e560b0fab502feb9197644337: remove do-not-merge, merge normally, require exact merge-SHA green main CI, then permit the protected Release workflow to publish only with exact source binding and verify GitHub plus Hex 0.4.0.`

The subsequent provenance-harness repair, ordinary PR #62 merge, and recovery workflow dispatch were authorized only to restore public verification. Neither authorization permitted a manual tag, manual Hex publish, bypass/force merge, or publication of the stale 0.3.3 candidate.

## Immutable Release Chain

| Transition | Immutable evidence | Result |
| --- | --- | --- |
| Release-intent correction | [PR #60](https://github.com/szTheory/rindle/pull/60) advanced from original correction head `b12e1e073e3d8cb96c84ce257df6fca9e02905f3` to reviewed/rebased head `7e51494bd18529221116a828874aee07241aeb96`; normal merge `081f6e00e3ad65cfdf4e5302e22778d96b2883ef` | [main CI 32317856452 attempt 2](https://github.com/szTheory/rindle/actions/runs/32317856452) succeeded at `081f6e0…`, including Cohort, full package matrices, and CI Summary. |
| FFmpeg hosted-CI repair | [PR #61](https://github.com/szTheory/rindle/pull/61), head `20bf7032cfadb72635476f3b95649b3da4fb3c36`, normal merge `916ee0df0fd4eaec1151c502bf2f0a5f53a86406` | [main CI 32313611652 attempt 2](https://github.com/szTheory/rindle/actions/runs/32313611652) succeeded at `916ee0d…`. |
| Incorrect Release Please state | [PR #59](https://github.com/szTheory/rindle/pull/59) initially proposed 0.3.3 and remained guarded with `do-not-merge` | It was never merged or published. Release Please was required to regenerate it as 0.4.0 instead of manually editing generated version files. |
| Regenerated release candidate | PR #59 title `chore(main): release rindle 0.4.0`, head `0747eff064eede1e560b0fab502feb9197644337` | [PR CI 32322762504](https://github.com/szTheory/rindle/actions/runs/32322762504) succeeded at the exact head, with Quality, Integration, Contract, Proof, lean package proof, Adoption Unit/E2E Smoke, Adopter, and CI Summary. Generated `mix.exs`, manifest, and changelog values were aligned at 0.4.0; the staging marker was absent and breaking notes were retained once. |
| Final reviewed release merge | PR #59 normal merge `78349c1bc5d082b0c0c9fce6796806011fa89a33` (`RELEASE_SOURCE_SHA`) | [push-main CI 32371768158 attempt 2](https://github.com/szTheory/rindle/actions/runs/32371768158) succeeded exactly at `78349c1…`, including Proof, Cohort, lean package proof, every full package matrix cell, Adoption, and CI Summary. |
| Original protected Release | [Release 32375506139](https://github.com/szTheory/rindle/actions/runs/32375506139) from frozen source `78349c1…` | Publish completed and exposed the GitHub/Hex release, but its final Public Verify failed at the provenance-harness assertion. This was a real failed external proof, not accepted as success. |
| Provenance-harness repair | [PR #62](https://github.com/szTheory/rindle/pull/62), head `aeb26a026e4def06dd1260cb52483400f4460fc6` | [exact-head PR CI 32379398190 attempt 2](https://github.com/szTheory/rindle/actions/runs/32379398190) succeeded; normal merge/tooling SHA `0973f2433b14f307f44acc747ebe1a1d3101dc62`; [exact-main CI 32381217483](https://github.com/szTheory/rindle/actions/runs/32381217483) succeeded with all green main lanes, full package matrices, Cohort, Proof, Adoption, and CI Summary. |
| Idempotent protected recovery | [Release 32383632492](https://github.com/szTheory/rindle/actions/runs/32383632492), workflow tooling head `0973f243…`; frozen `recovery_ref`, gate `release_sha`, and consumed exact CI head all `78349c1…` | Validate Recovery Ref, Gate on Exact-SHA Green CI, preflight, version alignment, existing-release detection, and Idempotent publish summary succeeded. Dry-run/live publish were skipped because Hex 0.4.0 already existed. Public Verify—including fresh `Verify public Hex.pm artifact`—succeeded. |

## Source-Binding and Threat Evidence

The protected workflow deliberately ran current recovery tooling from `0973f2433b14f307f44acc747ebe1a1d3101dc62`, while all package-source authority remained frozen at `RELEASE_SOURCE_SHA` `78349c1bc5d082b0c0c9fce6796806011fa89a33`:

- The recovery dispatch supplied exact `recovery_ref=78349c1bc5d082b0c0c9fce6796806011fa89a33`.
- `Validate Recovery Ref` succeeded before publication-related jobs.
- `Gate on Exact-SHA Green CI` succeeded using [CI 32371768158 attempt 2](https://github.com/szTheory/rindle/actions/runs/32371768158), whose event is `push`, head SHA is exactly `78349c1…`, and conclusion is `success`.
- Current tooling checkout and immutable-source materialization both completed before release preflight. This prevents a later repair commit from being mislabeled as the published package source.
- The existing-release check succeeded; both `Dry run Hex publish` and `Publish to Hex.pm (live)` were skipped. Thus recovery verified rather than rewrote the public package.
- All evidence recorded here is public metadata, workflow IDs, commit IDs, and timestamps. No token, package key, connection string, or credential is stored.

## Public Artifact Evidence

- GitHub release: [rindle-v0.4.0](https://github.com/szTheory/rindle/releases/tag/rindle-v0.4.0), non-draft and non-prerelease, published `2026-08-20T13:40:56Z`, target commit `78349c1bc5d082b0c0c9fce6796806011fa89a33`.
- Git tag: `rindle-v0.4.0` resolves to `78349c1bc5d082b0c0c9fce6796806011fa89a33` via `git ls-remote --tags origin refs/tags/rindle-v0.4.0`.
- Hex package API: [rindle 0.4.0](https://hex.pm/api/packages/rindle/releases/0.4.0), inserted `2026-08-20T13:56:15.118019Z`, updated `2026-08-20T13:56:16.519567Z`.
- Hex package index: [rindle](https://hex.pm/api/packages/rindle) reported `latest_version: "0.4.0"` at verification time; package index updated `2026-08-20T13:56:16.520680Z`.

## Verification

- Release PR #59 exact-head CI, release-source exact-main CI, repaired-tooling exact-main CI, and recovery workflow were all independently queried by run ID and 40-character `headSha`.
- Recovery workflow [32383632492](https://github.com/szTheory/rindle/actions/runs/32383632492) completed `success`: Validate Recovery Ref, Gate on Exact-SHA Green CI, Publish to Hex, Public Verify, and Update RELEASE-TRAIN Baseline were successful; Release Please was expectedly skipped for `workflow_dispatch`.
- In recovery Publish to Hex, `Run release preflight`, `Verify version alignment`, `Check whether Hex.pm release already exists`, and `Idempotent publish summary` succeeded. `Dry run Hex publish` and `Publish to Hex.pm (live)` were skipped because idempotency found the existing release.
- In recovery Public Verify, `Wait for Hex.pm index (post-publish)`, `Verify public Hex.pm metadata`, `Verify HexDocs reachability`, and fresh `Verify public Hex.pm artifact` all succeeded.
- Independent post-workflow GitHub release/tag and Hex API queries returned the source, version, and timestamps above.

## Deviations from Plan

### Release Infrastructure Recovery

**1. [External CI availability] FFmpeg asset retrieval intermittently returned HTTP 403.**

- **Found during:** hosted main and PR CI after the release-intent correction.
- **Resolution:** ordinary PR #61 updated the supported FFmpeg asset resolution path; its exact merge CI was green before later release evidence relied on it.
- **Evidence:** [PR #61](https://github.com/szTheory/rindle/pull/61), [CI 32313611652 attempt 2](https://github.com/szTheory/rindle/actions/runs/32313611652).

**2. [Release candidate correction] Release Please initially generated 0.3.3 instead of the required breaking 0.4.0 candidate.**

- **Found during:** review of open PR #59.
- **Resolution:** kept `do-not-merge`; landed the explicit Release-As correction through PR #60; required Release Please regeneration, a 0.4.0-only diff, absent staging marker, and exact-head green CI before authorization to merge.
- **Evidence:** [PR #60](https://github.com/szTheory/rindle/pull/60), [PR #59](https://github.com/szTheory/rindle/pull/59), [CI 32322762504](https://github.com/szTheory/rindle/actions/runs/32322762504).

**3. [Public-proof harness defect] Original Release 32375506139 published the already-authorized 0.4.0 source but failed its final fresh artifact proof because network-mode provenance reported the unused local package path.**

- **Found during:** original Public Verify after the package was visible on Hex.
- **Resolution:** PR #62 added failing-first regression coverage and made the harness resolve network provenance from the fetched `deps/rindle` directory. The repair was merged normally, its exact PR/main CI was green, and recovery re-verified the old frozen package without republishing it.
- **Evidence:** [PR #62](https://github.com/szTheory/rindle/pull/62), [PR CI 32379398190 attempt 2](https://github.com/szTheory/rindle/actions/runs/32379398190), [main CI 32381217483](https://github.com/szTheory/rindle/actions/runs/32381217483), [recovery 32383632492](https://github.com/szTheory/rindle/actions/runs/32383632492).

These recoveries were required to satisfy the plan's fail-closed external evidence requirements. They did not broaden release authority, alter the published release source, or permit a second package publication.

## Issues Encountered

- The first protected Release was not accepted as a complete release receipt because Public Verify failed, even though GitHub/Hex publication had already occurred. The final receipt preserves that failure and shows the later idempotent verification path explicitly.
- No 0.3.3 state was merged or published. It was superseded by the generated 0.4.0 candidate before the second maintainer authorization.

## Files Created/Modified

- `.planning/phases/120-adoption-proof-release-truth/120-14-SUMMARY.md` — immutable Plan 120-14 release and public-artifact evidence receipt.

## Next Phase Readiness

The 0.4.0 release train is externally verified: GitHub and Hex agree on the frozen source and version, and the fresh public installed-artifact proof is green. No follow-up source, tag, publish, or recovery action is authorized or required by this plan.

## Known Stubs

None.

## Self-Check: PASSED

- This summary is present at the plan-required path and is the only file changed in the closeout worktree.
- It records the two maintainer authorizations, every requested PR/run/source identity, the original failed public proof, the idempotent recovery result, and independent GitHub/Hex evidence.
- It records public identifiers and timestamps only; no credential material is included.
