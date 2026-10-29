---
phase: "139"
slug: exact-head-readiness-closure
status: verified
threats_open: 0
asvs_level: 1
register_authored_at_plan_time: true
created: "2026-10-29"
evidence_scope: historical
---

# Phase139 security verification

The plan-time STRIDE register was checked at configured L1 depth against implementation, negative fixtures and the retained actual execution graph. This is a mitigation audit for the historical accepted source, not an unbounded vulnerability scan. Repeated T-139-SC rows describe one shared supply-chain boundary.

## Trust boundaries

Remote GitHub/security/registry facts enter authenticated bounded collectors; untrusted paths/bytes enter the finite graph validator and retention reader; isolated child processes cross an owned-cleanup boundary; synthetic evidence crosses the adoption/claim boundary. Raw security responses remain restricted; only prepared portable evidence is published.

| Threat | Severity | Mitigation evidence | Status |
|---|---|---|---|
| T-139-01 | high | `validate_exact_head_readiness.exs`: finite proof registry, object hashes and exact identity; corrupt/missing/foreign graph fixtures in `test_exact_head_readiness.sh` | closed |
| T-139-02 | high | `exact_head_readiness.py`, `readiness_process.py`: exact gate/argv/input identity, process ownership, bounded cleanup and changed-byte/foreign-user negatives | closed |
| T-139-03 | high | `collect_readiness_runs.py`, `readiness_workflow.exs`, `readiness_nightly.exs`: newest exact attempt, complete topology, authentic scheduled health, effective protection;64 collector fixtures | closed |
| T-139-04 | high | `collect_readiness_remote.py`: complete per-source pagination and two equal bounded observations; incomplete/changed/disposition negatives | closed |
| T-139-05 | high | `readiness_closure.py` and validator: refresh envelope binds original manifest and new receipt bytes; scalar verdict cannot replace failed receipt | closed |
| T-139-06 | high | `readiness_retention.py`: separate producer sidecar, transport/archive/manifest hashes and atomic durable publication; wrong attempt and digest negatives | closed |
| T-139-07 | high | `readiness_github.py` and remote collector: authenticated endpoint-specific private visibility, complete pages; private404/auth failure remain unavailable | closed |
| T-139-08 | high | Collector restricted directories and retention public-object scan reject private/token canaries and credential patterns; portable graph excludes restricted raw payloads | closed |
| T-139-09 | high | `readiness-retention.yml` uploads prepared archive/sidecar only; `scan_public` rejects secret/canary bytes before upload | closed |
| T-139-10 | medium | Authenticated workflow ID/path, repository, completed run/attempt and unique artifact names; foreign workflow/title/repository and ambiguous artifact negatives | closed |
| T-139-11 | high | `readiness_subject.py`, acceptance and retention bind admitted protected-main candidate separately from producer head; ancestry/control/authentication rechecks and substitution negatives | closed |
| T-139-12 | high | `stored_bytes` and original validator independently re-read archive/sidecar/manifest/refresh graph; metadata parity and advanced-head claim reject unqualified current readiness | closed |
| T-139-13 | medium | Doctor host-ledger/catalog/version inspection rejects down/unknown/error/missing marker while preserving legacy/Oban failures; Doctor regressions and actual generated-consumer probe | closed |
| T-139-SC | high | No new dependency introduced by acceptance. Root/demo signed registry/advisory audits and lock-bound package gates ran; newly disclosed demo Bandit issue repaired through PR217 before accepted source | closed |

## Execution evidence and limits

Accepted historical source `48407bac7691c459395760b06f7714bbb6c3545b`, interval `2026-10-29T11:22:36.801043Z`–`2026-10-29T15:56:53.252718Z`, terminal-verdict `/Users/jon/Library/Application Support/Rindle/readiness/accept-v3-48407bac-renewed-20261029/terminal-verdict.json`. Normal owner exited0; original-source stored-byte and claim validation passed. All eight terminal references and complete retained graph were independently checked. Actual producer40864930767/1 is separate from the accepted subject.

No accepted risk was used to close an open mitigation. Credentials were replaced by the maintainer in GitHub; no token value was collected or committed. Later CI scheduling and temporary-cron cleanup change controls and receive ordinary CI validation, not inherited current readiness. Independent pilot, publication and deferred CI-16 remain outside this result.

## Security audit

2026-10-29:14 distinct registered threats,14 closed,0 open; configured ASVS L1, high blocking threshold. Inline mitigation audit by the executing maintainer agent; no independent penetration-test claim.
