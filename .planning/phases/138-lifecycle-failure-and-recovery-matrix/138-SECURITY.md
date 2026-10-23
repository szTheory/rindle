---
phase: "138"
slug: lifecycle-failure-and-recovery-matrix
status: verified
threats_open: 0
asvs_level: 1
register_authored_at_plan_time: true
created: "2026-10-22"
---

# Phase 138 — Security

Plan-time threat register verified at L1 against implementation, executable controls and the real package matrix. Six plan registers contain 16 distinct threats; repeated supply-chain identity is consolidated. No risk is accepted or transferred to manufacture closure.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|---|---|---|
| HTTP clients and provider fixture to packaged host | Shipped tus and raw-body signature validation | Offsets, signed events, identifiers |
| Workers to PostgreSQL and S3 | Durable decisions, external effects and abrupt death | Lifecycle rows, job history, object bytes |
| Runner to independent verifier | Exact retained inputs/archive and typed observations | Private raw captures; allowlisted receipt |
| Audit to infrastructure disposal | Stop writers and bind exact ownership before mutation | Docker descriptors, labels, mounts and resource users |

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|---|---|---|---|---|---|---|
| T-138-01 | Tampering | tus offset | high | mitigate | twin_receipt.py:validate_tus_clients; twin_tracer_contract_test.exs and real tus-resume case: authoritative HEAD, 409 and unchanged offset/checksum. | closed |
| T-138-02 | Repudiation | case receipt | high | mitigate | twin_receipt.py:validate_inputs/verify_tus_case; runner archive rehash and retained-input comparison; receipt mutation controls. | closed |
| T-138-03 | Tampering | purge absence | high | mitigate | twin_receipt.py:verify_purge_case; real independent MinIO deletion plus authoritative HEAD; purge_storage_test.exs rejects denied/unknown. | closed |
| T-138-04 | Repudiation | Oban attempts | medium | mitigate | Real purge case retains same durable job at retryable attempt 1 and completed attempt 2; exact IDs/error history audited. | closed |
| T-138-05 | Tampering | worker input fault | medium | mitigate | Twin.Storage.download delegates S3 before exact run/source/temp-path corruption; twin_fault_test.exs and AV source checksum controls. | closed |
| T-138-06 | Information disclosure | AV diagnostics | high | mitigate | Runner private command files (0600)/directories (0700), bounded decode output and closed AV receipt; export-canary checks. | closed |
| T-138-07 | Spoofing | webhook ingress | high | mitigate | Twin.Web mounts shipped WebhookPlug/body reader; signed SDK ingress with real invalid-signature HTTP 400 control. | closed |
| T-138-08 | Tampering | event order | high | mitigate | Provider writers lock FOR UPDATE and compare current accepted event/snapshot before writes; independent committed-writer/precision/rollback tests. | closed |
| T-138-09 | Information disclosure | provider effects | high | mitigate | Success effects emitted after own transaction commit; webhook exception metadata fixed and raw profile removed; real receipt/log/telemetry/PubSub canary controls. | closed |
| T-138-10 | Spoofing | runtime replacement | high | mitigate | verify_promotion_restart_case requires old container exit 137, distinct new container/boot and the same job/archive; real package trace. | closed |
| T-138-11 | Tampering | promotion barrier | medium | mitigate | Paused/quiescent queue plus two unchanged committed available attempt-zero reads precede SIGKILL; restart mutation controls. | closed |
| T-138-12 | Tampering | cleanup cut | high | mitigate | Exact-key post-delete/pre-row storage barrier; confirmed maintenance BEAM death, retained expired row and two ordinary same-resource reruns. | closed |
| T-138-13 | Repudiation | matrix receipt | high | mitigate | Closed schema-3 exact six-case verifier, retained archive rehash, distinct bound inputs, complete audit shape and omitted/swapped/secret mutations. | closed |
| T-138-14 | Information disclosure | evidence exports | high | mitigate | Closed finite typed receipt/status fields; private raw captures; runtime export-canary checks and mutation controls across channels. | closed |
| T-138-15 | Denial of service | infrastructure janitor | high | mitigate | twin_cleanup.py descriptor/build/label/mount/liveness/foreign-user preflight, all-child preflight, per-child recheck, no force/prune; active real refusal and repeated cleanup. | closed |
| T-138-SC | Tampering | package installs | high | mitigate | Root mix.lock unchanged; existing locked Mux 3.2.2 activated only in fixture host; one fresh archive and uncached dependency-origin proof. | closed |

## Accepted Risks Log

No accepted risks.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|---|---|---|---|---|
| 2026-10-22 | 16 | 16 | 0 | Codex inline L1 verification |

## Evidence and Scope

The full matrix at `/private/tmp/rindle-138-matrix-verified` passes its separate retained-input verifier. Every case has a stopped-writer audit and exact finite resource/job/fixture inventory before disposal. Repeated cleanup passes; the actual active-matrix cleanup control refuses without mutation. Final `mix ci` exits zero: 3 doctests, 1748 tests, zero failures. Source subject is c4cf0742a043dd1f8fb8cd44ca29acad7ea083cc; subsequent changes are planning records only.

The authored register, zero open findings and configured ASVS level 1 satisfy secure-phase's L1 short-circuit branch; no deeper auditor is required. This verifies the planned mitigations, not a new security certification. Doctor migration-ledger/readiness work remains Phase 139 and independent-pilot credit remains false.

## Sign-Off

- [x] All threats have an implemented mitigate disposition.
- [x] Accepted risks log contains none.
- [x] threats_open: 0 confirmed.
- [x] status: verified set.

**Approval:** verified 2026-10-22.
