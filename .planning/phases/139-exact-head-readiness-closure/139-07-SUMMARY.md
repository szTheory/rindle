---
phase: 139-exact-head-readiness-closure
plan: "07"
subsystem: readiness-acceptance
tags: [historical-readiness, retained-evidence, snapshot-v3]
requires:
  - phase: 139-06
    provides: Producer retention and terminal acceptance controller
provides:
  - Actual execution-mode historical readiness with independently verified retained bytes
affects: [milestone-audit]
actuals:
  tasks: 2
  commits: 0
tech-stack:
  added: []
  patterns: [immutable source, separately owned producer, historical claim inspection]
key-files:
  created: []
  modified: []
requirements-completed: [READY-01, READY-02, READY-03, READY-04, READY-05]
accepted_subject_sha: "48407bac7691c459395760b06f7714bbb6c3545b"
observation_interval:
  started_at: "2026-10-29T11:22:36.801043Z"
  completed_at: "2026-10-29T15:56:53.252718Z"
evidence_scope: historical
terminal_verdict: "/Users/jon/Library/Application Support/Rindle/readiness/accept-v3-48407bac-renewed-20261029/terminal-verdict.json"
coverage:
  - id: admitted-subject
    description: Clean protected-main snapshot admission and exact source qualification
    verification:
      - kind: integration
        ref: /private/tmp/rindle-v3-subject-48407bac-20261029/subject.json
        status: pass
    human_judgment: false
  - id: terminal-historical-acceptance
    description: Normal controller exit0, execution ready, independently checked retained graph and historical-only claim
    verification:
      - kind: integration
        ref: /Users/jon/Library/Application Support/Rindle/readiness/accept-v3-48407bac-renewed-20261029/terminal-verdict.json
        status: pass
      - kind: integration
        ref: /Users/jon/Library/Application Support/Rindle/readiness/accept-v3-48407bac-renewed-20261029-owner/exit.json
        status: pass
      - kind: integration
        ref: /private/tmp/rindle-source11-original-claim-20261029-final/claim-status.json
        status: pass
    human_judgment: false
duration: 274min
completed: 2026-10-29
status: complete
---

# Retained historical readiness acceptance

Actual automated acceptance returned `ready` for historical subject `48407bac7691c459395760b06f7714bbb6c3545b`, interval `2026-10-29T11:22:36.801043Z`–`2026-10-29T15:56:53.252718Z`. The terminal-verdict path above and `durable/locator.json` bind the retained producer archive, separate sidecar, original manifest and refreshed receipt graph. This summary grants historical completion only. Current-head readiness requires its own appropriate new qualification; this snapshot's `claim-status` always reports `historical_ready` and `current_readiness=false`.

## Accomplishments

- Source admission recorded 85 tracked phase inputs and 20 controller identities. Source main CI `40853899390/1` completed all 23 jobs; its single on-demand Nightly qualification `40857260942/1` completed all 11 jobs, including declared event-inapplicable skips. Independent real scheduled incident health and effective protection were separately authenticated by the execution collectors.
- The unchanged normal controller was observed by its direct parent from invocation through exit0 at `2026-10-29T15:56:53.646079Z`. Producer `40864930767/1`, workflow394245927, job123417184417, request `6c56f529e04e6aa0e9d794fe3ea60328`, succeeded. Its producer head `b2a60c51687293df5498920cc2bddb4e25349251` is distinct from the accepted evidence subject.
- Archive12910053433 and sidecar12911325484 were retrieved into restricted durable maintainer storage. Independent original-source validation re-read all eight terminal references and the receipt graph, compared archive manifest bytes, and verified the observer script identity. Fresh original-source `claim-status` exited0 with `historical_ready` and no current-readiness credit.
- The controller's host refresh independently re-observed complete CI, scheduled-health, security, inbox, branch-protection and authoritative adoption facts, preserving the original manifest and validating a subject-bound refresh envelope.

## Retained byte identities

| Object | SHA256 |
|---|---|
| Terminal verdict | `3a4a2c03b49474bd6118d65386b223ade7555738731469ce8180defb5da9b9c5` |
| Gzip archive | `8737a63f9e0ac931383e77fb841620692cf447814577984c76ad59d714758f91` |
| Original manifest | `78dacc1381ba6fe3f02c90199d6bb31982886f984a7e33a00436397421b5ca61` |
| Separate producer sidecar | `34c5a6915168e4c584a768d7b0f1c5e131f67603362ca38974027e96e7a30b28` |
| Locator | `78dda6ae33a3462ed4384828cedb3d058ac19275ae5f45e624473178123ce4ba` |
| Refresh envelope | `63e4f3d10e3f85f664740737fb8cfc382ac7a7242e159187b2bc524336c0f246` |

These are retained file hashes, distinct from GitHub's artifact ZIP transport digests. Durable originals and failed attempts remain immutable; tracked metadata contains paths and hashes rather than private raw inventories.

## Task commits and deviations

Both planned tasks produce external evidence, with no source commit. Acceptance followed the user-approved immutable snapshot-v3 amendment; later metadata changes cannot inherit current-head readiness. Prerequisite repairs were delivered through protected PRs215–218. A prior normal Source11 invocation failed credential binding and exited1; it remains separately retained at `accept-v3-48407bac-20261029` and grants no credit. After the maintainer replaced the encrypted read-only token, fresh prerequisites and a distinct owned invocation passed. Token contents were never collected in chat or repository files.

The approved temporary recovery cron is removed separately through normal protected CI maintenance after this retained result. CI efficiency investigation is separate evidence: the scheduling model and rejected Census pilot grant no READY or deferred numeric-speed credit.

## Preserved limits

The named independent Phoenix pilot remains open. Synthetic twin proof does not establish real adoption, 1.0 or publication authority. CI-16 remains deferred unfinished with zero credit and its original receipt unchanged. PR185/188 holds and PR189's draft/unmerged/no-auto posture remain. No new acceptance or repeated capture is needed to archive this historical result.

## Threat Flags

No unresolved acceptance threat flag. Remote facts, archive paths, byte references, run/attempt/workflow identity, authoritative adoption and later-head claim scope were validated by executable checks. This records the bounded observed result rather than an indefinite security guarantee.
