---
phase: "133"
slug: "evidence-charter-and-live-truth"
status: open
verdict: OPEN_THREATS
subject_sha: 9bb10539a0bccd734a4921d6a0f4d072b478332e
census_sha256: df484acda67c5919427449344d749a4b5b73123a51d0cda9d774f6159bd8d484
threats_open: 1
threats_open_total: 26
asvs_level: 1
created: "2026-09-10"
revised: "2026-09-28"
---

# Phase 133 — Security

> Current Plan 55 audit: eight named high threats and fifteen recovered low findings retain their prior dispositions; two Plan 55 threats are closed and one remains open for the exact subject below. This audit gives no Phase 133 requirement credit; requirements remain pending.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Repository and tool outputs → evidence collectors | Detector, workflow, cache, and remote outputs are untrusted until bound to exact identities and validated. | Repository metadata, tool versions, workflow results, cache fingerprints |
| Generated package and active claims → derived authority | Prose or source-local output cannot impersonate built-package or live repository truth. | Package provenance, release version, CI topology, adoption claims |
| GitHub run and issue APIs → receipts and incident lifecycle | Remote state may be stale, partial, malformed, or from the wrong subject; only one bounded write path is allowed. | Run metadata, job logs, refs, issue inventory and mutations |
| Reviewed ledger → exact-subject receipts and later phases | Stable dispositions and volatile live facts must reconcile without SHA self-reference or identity substitution. | Candidate IDs, transitions, subject SHA, evidence receipts |

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-133-01 | Tampering | census validator | high | mitigate | Exact SHA/clean-state, taxonomy, bijection, digest, and mutation checks in `validate_evidence_census.exs` and `evidence_census_test.exs`. | closed |
| T-133-02 | Repudiation | candidate dispositions | medium | mitigate | Stable IDs plus required rationale, evidence, triggers, and substitution/transition tests. | closed |
| T-133-03 | Information disclosure | normalized receipt | medium | mitigate | Bounded allowlisted fields and repository-relative path enforcement; no raw environment payloads. | closed |
| T-133-04 | Denial of service | detector execution | low | accept | Collector uses bounded repository commands and adds no network or unbounded scanner. | closed — accepted |
| T-133-05 | Tampering | PLT cache identity | high | mitigate | Cache keys include exact resolved patch versions and input hashes with no prefix restore fallback. | closed |
| T-133-06 | Repudiation | stale recovery | high | mitigate | Exact old-PLT fingerprint and at most one rebuild, covered by mode/failure tests. | closed |
| T-133-07 | Information disclosure | run-log fingerprint | medium | mitigate | Normalized bounded provenance and URLs only; raw logs, secrets, and runner paths excluded. | closed |
| T-133-08 | Denial of service | fresh PLT build | low | accept | One explicit build is confined to scheduled/diagnostic Nightly, outside the PR path. | closed — accepted |
| T-133-09 | Tampering | aggregate JSON | high | mitigate | Exact schema/job-set/result validation with a 49-case false-green matrix. | closed |
| T-133-10 | Repudiation | secret-gated applicability | high | mitigate | Applicability, execution, result, and reason are independently typed and structurally tested. | closed |
| T-133-11 | Elevation of privilege | workflow expression/shell boundary | high | mitigate | Contexts cross quoted environment variables and are parsed as JSON, never evaluated as shell source. | closed |
| T-133-12 | Denial of service | collect-all evaluation | low | accept | The declared job set is fixed and small; complete diagnostics require only bounded iteration. | closed — accepted |
| T-133-13 | Spoofing | recovery identity | high | mitigate | Scheduled/default-branch/exact-main SHA and strict-verdict identity checks. | closed |
| T-133-14 | Tampering | issue selection/mutation | high | mitigate | Exact label/title, full cardinality, idempotent evidence markers, and fake-CLI argv/body tests. | closed |
| T-133-15 | Elevation of privilege | workflow token | high | mitigate | Default `contents: read`; only the lifecycle job receives local `issues: write`. | closed |
| T-133-16 | Repudiation | close transition | medium | mitigate | Recovery evidence and exact identifiers are supplied atomically with issue closure. | closed |
| T-133-17 | Tampering | authority derivation | high | mitigate | Version equality and parsed workflow topology with mutation fixtures. | closed |
| T-133-18 | Spoofing | package provenance | high | mitigate | Real built/unpacked report, exact source, and explicit no-repository/no-prebuilt fallback facts. | closed |
| T-133-19 | Repudiation | historical exemptions | medium | mitigate | Fixed archive boundary plus bounded, balanced markers with malformed-boundary tests. | closed |
| T-133-20 | Information disclosure | package/workflow model | low | accept | Model is limited to public topology/version booleans and repository-relative authority paths. | closed — accepted |
| T-133-21 | Repudiation | active claim reconciliation | high | mitigate | Classified derived-truth scan and mutation-tested active-surface anchors. | closed |
| T-133-22 | Spoofing | adoption/package proof | high | mitigate | Adoption gate invokes derived authority and real generated-consumer package authority. | closed |
| T-133-23 | Tampering | historical evidence | medium | mitigate | Historical spans are removed only in memory; archive and malformed-marker behavior is tested. | closed |
| T-133-24 | Elevation of privilege | live dispatch/incident boundary | high | mitigate | One diagnostic dispatch plus read-only inspection; incident snapshots must remain identical. | closed |
| T-133-25 | Spoofing | run selection | high | mitigate | Exact repository/workflow/event/ref/SHA/time boundary and first-attempt selection. | closed |
| T-133-26 | Tampering | evidence receipt | high | mitigate | Partial output deletion, canonical construction, exact validation, and 28-case collector matrix. | closed |
| T-133-27 | Elevation of privilege | GitHub adapter | high | mitigate | Adapter permits only the declared dispatch and read-only repo/ref/run/job/issue calls; mutation argv are rejected. | closed |
| T-133-28 | Repudiation | diagnostic nonmutation | medium | mitigate | Canonical exact-label incident snapshots are compared before and after and embedded in the receipt. | closed |
| T-133-29 | Spoofing | package claim validator | high | mitigate | Every receipt is normalized at the claim boundary; forged inline and CLI validation-marker regressions pass. | closed |
| T-133-30 | Tampering | package provenance paths | high | mitigate | Exact source, path existence, metadata, lifecycle, and no-fallback facts are rechecked after normalization. | closed |
| T-133-31 | Information disclosure | fixture error output | low | accept | Tests expose only generated temporary paths and no credentials or private remote data. | closed — accepted |
| T-133-32 | Tampering | persisted Nightly receipt | high | mitigate | Exact nested schemas plus canonical live reconstruction reject field, key, order, duplicate, and type mutations. | closed |
| T-133-33 | Spoofing | job and strict-verdict provenance | high | mitigate | Exact job identities and bounded job-scoped logs are the sole source of persisted job and verdict facts. | closed |
| T-133-34 | Repudiation | incident snapshots | high | mitigate | Exact-label incident state is freshly collected read-only and compared with both persisted snapshots. | closed |
| T-133-35 | Elevation of privilege | revalidation command surface | high | mitigate | Exact-subject worktrees and fixed repository-owned validators prevent receipt-controlled command selection. | closed |
| T-133-36 | Denial of service | remote/local revalidation | medium | mitigate | Positive bounded timeouts, finite API calls, and fixed local commands fail closed on lookup or execution failure. | closed |
| T-133-37 | Information disclosure | job/incident evidence | low | accept | Evidence is bounded to public job and incident metadata; no raw-log capture or capability expansion was added. | closed — accepted |
| T-133-38 | Spoofing | resolved toolchain parser | high | mitigate | Anchored numeric component parsing rejects 11.17, 1.170, and 127 near-matches. | closed |
| T-133-39 | Tampering | receipt Dialyzer versions | high | mitigate | Receipt versions reuse the anchored parser and must exactly match live logs and the PLT cache key. | closed |
| T-133-40 | Denial of service | malformed/ambiguous logs | medium | mitigate | Missing, ambiguous, malformed, and unsupported values fail deterministically without retries or broad capture. | closed |
| T-133-41 | Information disclosure | version diagnostics | low | accept | Toolchain versions and cache identities are non-secret bounded build metadata. | closed — accepted |
| T-133-53 | Spoofing | generated package authority | high | mitigate | Reconstruct the subject-owned helper closure and verify its execution against the authenticated generated package. | closed |
| T-133-74 | Denial of service | incident replay origin | high | mitigate | Bind replay to an authenticated durable epoch and reject expired or tampered replay evidence. | closed |
| T-133-85 | Denial of service | incident replay high-watermark | high | mitigate | Require event and artifact coverage through the captured high-watermark before mutation. | closed |
| T-133-91 | Spoofing | package lifecycle proof | high | mitigate | Execute repository-owned commands against the authenticated package and verify lifecycle results. | closed |
| T-133-105 | Repudiation | incident lifecycle receipt | high | mitigate | Verify append-only issue history and persisted evidence across later open/close transitions. | closed |
| T-133-39-03 | Elevation of privilege | production reconciliation gate | high | mitigate | Production mapping validates all Plan 38–56 mappings and the no-decision authorization boundary; production mutation suite verifies the exact caller-root and no-premature-credit paths. | closed |
| T-133-42-03 | Tampering | receipt destination publication | high | mitigate | Existing destinations are rejected before collection and publication uses same-directory no-clobber semantics; occupied/concurrent destination cases are covered. | closed |
| T-133-55-01 | Tampering | compatibility repairs | high | mitigate | Exact authenticated failure groups map to focused compile, fixture, stale-binding, and review-gate regressions; disclosure assertions and planning-path hygiene remain enforced. | closed |
| T-133-55-02 | Spoofing | census and independent reports | high | mitigate | Census A/B, inventory, REVIEW, VALIDATION, and this SECURITY report bind the same exact subject and census digest; all 15 inventory proofs and dispositions reconcile. | closed |
| T-133-55-03 | Elevation of privilege | phase reconciliation | high | mitigate | Production reconciliation requires an authenticated, passing Plan 55 qualification summary and keeps Plan 56 authorization separate; local gates remain blocked. | open — qualification blocked |
| T-133-102 | Information disclosure | documentation edit | low | mitigate | Current exact-subject executable proof: `T-133-102: Plan 26 documentation contains no credential canary`. | dispositioned |
| T-133-33-SC | Tampering | package installation | low | mitigate | Current exact-subject executable proof: `T-133-33-SC`. | dispositioned |
| T-133-34-05 | Information Disclosure | planning evidence | low | mitigate | Current exact-subject executable proof: `T-133-34-05: reconciliation diagnostics never echo raw planning canaries`. | dispositioned |
| T-133-34-SC | Tampering | package installation | low | mitigate | Current exact-subject executable proof: `T-133-34-SC`. | dispositioned |
| T-133-35-SC | Tampering | package installation | low | mitigate | Current exact-subject executable proof: `T-133-35-SC`. | dispositioned |
| T-133-36-05 | Information Disclosure | checkpoint display | low | mitigate | Current exact-subject executable proof: `T-133-36-05 and T-133-41-05: checkpoint records expose only safe public text`. | dispositioned |
| T-133-36-SC | Tampering | package installation | low | mitigate | Current exact-subject executable proof: `T-133-36-SC`. | dispositioned |
| T-133-37-SC | Tampering | package installation | low | mitigate | Current exact-subject executable proof: `T-133-37-SC`. | dispositioned |
| T-133-38-SC | Tampering | package supply chain | low | mitigate | Current exact-subject executable proof: `T-133-38-SC`. | dispositioned |
| T-133-39-SC | Tampering | package supply chain | low | mitigate | Current exact-subject executable proof: `T-133-39-SC`. | dispositioned |
| T-133-40-SC | Tampering | package supply chain | low | mitigate | Current exact-subject executable proof: `T-133-40-SC`. | dispositioned |
| T-133-41-05 | Information Disclosure | checkpoint display | low | mitigate | Current exact-subject executable proof: `T-133-36-05 and T-133-41-05: checkpoint records expose only safe public text`. | dispositioned |
| T-133-41-SC | Tampering | package supply chain | low | mitigate | Current exact-subject executable proof: `T-133-41-SC`. | dispositioned |
| T-133-42-SC | Tampering | package supply chain | low | mitigate | Current exact-subject executable proof: `T-133-42-SC`. | dispositioned |
| T-133-71 | Denial of service | bounded polling | low | mitigate | Current exact-subject executable proof: `zero exact matches poll until timeout without a receipt`. | dispositioned |

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-133-01 | T-133-04 | Existing detector commands are bounded and local; adding a network or generalized scanner would increase risk without improving Phase 133 evidence. | Phase 133 plan | 2026-09-09 |
| AR-133-02 | T-133-08 | A single fresh PLT build is necessary evidence and is isolated to scheduled/diagnostic Nightly. | Phase 133 plan | 2026-09-09 |
| AR-133-03 | T-133-12 | Complete evaluation over a fixed four-job set is bounded and preferable to incomplete diagnostics. | Phase 133 plan | 2026-09-09 |
| AR-133-04 | T-133-20 | Derived output contains only public repository facts and bounded relative paths, with no secrets or raw logs. | Phase 133 plan | 2026-09-09 |
| AR-133-05 | T-133-31 | Generated fixture paths contain no credentials or private remote data. | Phase 133 Plan 08 | 2026-09-10 |
| AR-133-06 | T-133-37 | Bounded public job and incident metadata is required for evidence reconstruction; no raw-log or write capability is added. | Phase 133 Plan 09 | 2026-09-10 |
| AR-133-07 | T-133-41 | Exact toolchain and cache identifiers are non-secret build metadata required to prevent identity substitution. | Phase 133 Plan 10 | 2026-09-10 |

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-10 | 28 | 28 | 0 | gsd-security-auditor |
| 2026-09-10 | 41 | 41 | 0 | gsd-security-auditor gap-closure audit |
| 2026-09-10 | 41 | 41 | 0 | execute-phase post-execution security gate |
| 2026-09-11 | 41 | 41 | 0 | execute-phase final gap-closure security gate |
| 2026-09-13 | 196 | 173 | 23 (8 blocking) | gsd-security-auditor Plans 38–42 audit |
| 2026-09-25 | 196 | 181 | 15 (0 blocking) | independent Plan 48 exact-subject security audit |

## Open Threats — Plans 38–42 Audit

| Threat ID | Category | Severity | Missing mitigation | Evidence |
|-----------|----------|----------|--------------------|----------|
| T-133-32 | Tampering | high | Enforce the exact nested receipt schema and canonical reconstruction at every authority entry point. | `validate_phase_133_reconciliation.exs` accepts a self-supplied digest and subject SHA. |
| T-133-53 | Spoofing | high | Independently reconstruct every package and adopter authority field. | `validate_live_truth.exs` trusts caller-selected roots, results, and execution environment. |
| T-133-74 | Denial of service | high | Bound replay to a durable immutable origin. | Expired artifacts make full historical replay impossible and permanently block the drainer. |
| T-133-85 | Denial of service | high | Preserve pre-gate immutable events through the captured high-watermark. | Normal artifact retention can permanently disable later replay. |
| T-133-91 | Spoofing | high | Execute repository-owned commands in an authenticated generated/package tree. | An unrelated trivial tree can satisfy the current package proof. |
| T-133-105 | Repudiation | high | Keep immutable incident evidence attributable across later open/close transitions. | Receipt verification queries only currently open issues and invalidates valid historical snapshots. |
| T-133-39-03 | Elevation of privilege | high | Make production reconciliation enforce all Plans 38–42 validation mappings and acceptance boundaries. | The production reconciler truncates before the closure addendum while a test-only parser checks it separately. |
| T-133-42-03 | Tampering | high | Refuse destination clobbering and gate atomic candidate promotion. | The collector deletes the requested destination before preflight and later overwrites it with `mv`. |

Fifteen additional low-severity or summary-control threats remain open below the configured `high` blocking threshold. They are recorded in the 2026-09-13 auditor result and must be dispositioned during the next gap-planning cycle; they are not silently accepted here.

## Prior Plan 48 Independent Security Audit (superseded)

**Audited subject:** `07beb46e6d438b3c41a2f2ac8dc9935a941600df`  
**Subject SHA:** 07beb46e6d438b3c41a2f2ac8dc9935a941600df  
**Census SHA-256:** c9144bbb66120b2e12efb72412a1bb268e31d5ab8a0ea02e21bc1e66402d806f  
**Verdict:** `OPEN_THREATS`  
**Evidence scope:** Subject commit exists, ledger digest matches, and `git diff SUBJECT..HEAD -- scripts lib test` is empty. The auditor inspected production code and regression tests but did not run tests.

| Threat ID | Severity | Result | Evidence |
|-----------|----------|--------|----------|
| T-133-32 | high | CLOSED | Exact receipt schema and live reconstruction in `scripts/ci/verify_nightly_run.sh`; terminal reconciliation invokes receipt verification in `scripts/maintainer/validate_phase_133_reconciliation.exs`; receipt mutation cases in `scripts/ci/test_verify_nightly_run.sh`. |
| T-133-53 | high | OPEN — blocking | `scripts/maintainer/validate_live_truth.exs` checks package bytes against the subject but loads mutable `test/install_smoke/support/generated_app_helper.ex` from the caller checkout and trusts its lifecycle result (CR-07). |
| T-133-74 | high | CLOSED | Authenticated checkpoint and replay-epoch expiry handling in `scripts/ci/manage_nightly_incident.sh`; checkpoint identity and digest checks plus expiry/tampering cases in `scripts/ci/test_nightly_incident.sh`. |
| T-133-85 | high | CLOSED | Cursor-to-high-watermark events/artifact coverage fails closed before mutation in `scripts/ci/manage_nightly_incident.sh`; missing and expired artifact cases in `scripts/ci/test_nightly_incident.sh`. |
| T-133-91 | high | OPEN — blocking | The caller-worktree helper can claim lifecycle success without proving repository-owned commands ran against the authenticated package; helper-tampering regression is absent from `test/install_smoke/live_truth_parity_test.exs` (CR-07). |
| T-133-105 | high | CLOSED | Receipt verification checks all issue states and persisted issue bodies/comments in `scripts/ci/verify_nightly_run.sh`; lifecycle history cases in `scripts/ci/test_verify_nightly_run.sh`. |
| T-133-39-03 | high | CLOSED | Production reconciliation compares the Plans 38–49 validation mapping and mutations exercise production validation in `scripts/maintainer/validate_phase_133_reconciliation.exs` and `test/install_smoke/phase_133_reconciliation_test.exs`. |
| T-133-42-03 | high | CLOSED | Existing destinations are rejected before collection and final publication uses same-directory hard-link no-clobber semantics in `scripts/ci/verify_nightly_run.sh`; occupied/concurrent destination cases in `scripts/ci/test_verify_nightly_run.sh`. |
| Prior lower-severity/summary-control findings (aggregate count 15; item identities unavailable) | unranked — fail-closed as critical | OPEN — escalation | The earlier audit report only records the aggregate count. Repository and prior SECURITY.md history contain no authoritative IDs, individual severities, mitigations, or evidence. `T-133-OTHER-01..15` in `test/install_smoke/phase_133_review_gate_test.exs` are synthetic test fixtures and are not accepted as threat identities. No individual disposition can be made without the missing inventory. |

**Machine-readable verdict:** `verdict: OPEN_THREATS`; `subject_sha: 07beb46e6d438b3c41a2f2ac8dc9935a941600df`; `census_sha256: c9144bbb66120b2e12efb72412a1bb268e31d5ab8a0ea02e21bc1e66402d806f`; `named_threats_closed: 6`; `named_threats_open_blocking: [T-133-53, T-133-91]`; `prior_findings_open_fail_closed: 15`; `threats_open: 17`.

The item-level inventory for the prior fifteen findings must be recovered before they can be individually mitigated or accepted. This report grants no requirement credit.

## Prior Sign-Off (superseded)

- [ ] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [ ] `threats_open: 0` confirmed
- [ ] `status: verified` set in frontmatter

**Approval:** blocked 2026-09-25 pending the T-133-53/T-133-91 mitigations and recovery of the authoritative inventory for fifteen aggregate open findings

## Current Independent Security Audit

**Auditor:** independent `gsd-security-auditor` workflow  
**Subject SHA:** `96848c9a34bb2a5f5d3eb2b599c8ae3bc20d0b20`  
**Census SHA-256:** `ff671b6ce2f0806df52281a02d336333513d562aa165d21fd9e4327a362d9ea5`  
**Verdict:** `OPEN_THREATS` — 8 of 23 findings closed; 15 low findings remain open below the `high` blocking threshold.  
**Threats open at blocking threshold:** 0.

### Closed — named high threats

| Threat ID | Severity | Evidence | Disposition |
|-----------|----------|----------|-------------|
| T-133-32 | high | Exact receipt shape and subject/ref/run checks followed by canonical live verification in `scripts/maintainer/validate_phase_133_reconciliation.exs:1652-1705` and `scripts/ci/verify_nightly_run.sh:315-398,482-524`; mutation cases in `scripts/ci/test_verify_nightly_run.sh`. | closed |
| T-133-53 | high | Subject-owned helper closure is reconstructed and checked in `scripts/maintainer/validate_live_truth.exs:632-743,752-858`; caller-helper tampering regression in `test/install_smoke/live_truth_parity_test.exs:737-861`. | closed |
| T-133-74 | high | Authenticated checkpoint, event and chain digests, issue snapshot, and bounded replay origin in `scripts/ci/manage_nightly_incident.sh:142-175,244-353,497-534`; expiry and tampering cases in `scripts/ci/test_nightly_incident.sh:537-543`. | closed |
| T-133-85 | high | Replay requires run/artifact coverage through the high-watermark and fails on expired evidence within the active epoch in `scripts/ci/manage_nightly_incident.sh:177-240`; coverage and expiry cases in `scripts/ci/test_nightly_incident.sh:537-543`. | closed |
| T-133-91 | high | Verifier executes the subject-owned helper closure against the reconstructed package and checks lifecycle results in `scripts/maintainer/validate_live_truth.exs:648-743,764-858`; caller-helper tampering regression in `test/install_smoke/live_truth_parity_test.exs:828-861`. | closed |
| T-133-105 | high | Receipt validation checks incident history while allowing append-only changes in `scripts/ci/verify_nightly_run.sh:482-524`; lifecycle-history cases in `scripts/ci/test_verify_nightly_run.sh:792-798`. | closed |
| T-133-39-03 | high | Production reconciliation derives and compares mappings through Plans 50–52 in `scripts/maintainer/validate_phase_133_reconciliation.exs:594-617,635-652,696-724,1023-1072`; production mutation cases in `test/install_smoke/phase_133_reconciliation_test.exs:653-695`. The subject-bound Nyquist verdict records successful mutation suites. | closed |
| T-133-42-03 | high | Collector rejects an existing destination and publishes with a no-clobber hard link in `scripts/ci/verify_nightly_run.sh:558-565,619-623`; occupied and concurrent destination cases in `scripts/ci/test_verify_nightly_run.sh:534-598`. | closed |

### Recovered low findings — open, non-blocking

The fifteen findings are genuinely recovered as individually identified historical findings. Their source commit, blob, line, row text, and row digest all match, and each ID appears in the authenticated original auditor response as open below threshold. They are **not** superseded by a complete re-audit: no current exact-ID Accepted Risks Log entry or current mitigation proof exists. Their historical `accept` labels do not constitute current approval.

| Threat ID | Severity | Historical source row | Current disposition | Status |
|-----------|----------|-----------------------|---------------------|--------|
| T-133-71 | low | `133-18-PLAN.md:157` | accepted-risk entry absent | OPEN — non-blocking |
| T-133-102 | low | `133-26-PLAN.md:185` | accepted-risk entry absent | OPEN — non-blocking |
| T-133-33-SC | low | `133-33-PLAN.md:170` | accepted-risk entry absent | OPEN — non-blocking |
| T-133-34-05 | low | `133-34-PLAN.md:191` | accepted-risk entry absent | OPEN — non-blocking |
| T-133-34-SC | low | `133-34-PLAN.md:192` | accepted-risk entry absent | OPEN — non-blocking |
| T-133-35-SC | low | `133-35-PLAN.md:192` | accepted-risk entry absent | OPEN — non-blocking |
| T-133-36-05 | low | `133-36-PLAN.md:142` | accepted-risk entry absent | OPEN — non-blocking |
| T-133-36-SC | low | `133-36-PLAN.md:143` | accepted-risk entry absent | OPEN — non-blocking |
| T-133-37-SC | low | `133-37-PLAN.md:252` | accepted-risk entry absent | OPEN — non-blocking |
| T-133-38-SC | low | `133-38-PLAN.md:199` | accepted-risk entry absent | OPEN — non-blocking |
| T-133-39-SC | low | `133-39-PLAN.md:198` | accepted-risk entry absent | OPEN — non-blocking |
| T-133-40-SC | low | `133-40-PLAN.md:208` | accepted-risk entry absent | OPEN — non-blocking |
| T-133-41-05 | low | `133-41-PLAN.md:157` | accepted-risk entry absent | OPEN — non-blocking |
| T-133-41-SC | low | `133-41-PLAN.md:158` | accepted-risk entry absent | OPEN — non-blocking |
| T-133-42-SC | low | `133-42-PLAN.md:231` | accepted-risk entry absent | OPEN — non-blocking |

**Historical digest caveat:** inventory `report_sha256` is `706bd2bf5b1162907ab60a7cf910f40a5242cc203190f5578f098dd4647a9a65`; it matches neither the committed report file SHA-256 `f004b5310be7cd432a09fbcd252d2dac6781f739a9104f19de044f8a17e5a8a7` nor the authenticated response text SHA-256 `58c303…`. The raw-record SHA-256, record identity, report parent binding, itemized response, and source-row hashes independently support recovery. The mismatched report digest is not treated as proof.

### Unregistered flags

**WARNING:** `133-17-SUMMARY.md:174-178` records `threat_flag: credential-scope`: the read-only workflow token enters the FFmpeg installer process. No explicit threat-ID mapping for this handoff was found.

### Current sign-off

- [x] All eight named high threats closed for the exact subject.
- [x] Fifteen recovered findings are itemized; all remain open and non-blocking.
- [ ] All findings closed or accepted as current risks.
- [ ] `status: verified` set in frontmatter.
- [x] `threats_open: 0` at the configured `high` blocking threshold.

**Approval:** blocked. The one-time Plan 48 authorization gate cannot pass while any recovered inventory item remains open; no current accepted-risk approval is inferred from historical plan labels. The exact subject's independent review and production-path validation pass, but all five Phase 133 requirements remain pending.


## Prior Independent Security Audit — Plan 48 subject (superseded)

**Auditor:** independent `gsd-security-auditor` workflow  
**Phase:** 133 — evidence-charter-and-live-truth  
**Subject SHA:** `68b1c82390b506da343116f49b943f05442692b0`  
**Census SHA-256:** `5e7ebad94c35c9dd195571b536888e81132e8817237235d02cd12e551cbd144a`  
**Inventory SHA-256:** `6d36bda1e25c5d7121b8f3b486f8ef7419a47789772306cfd2239f85a91dae45`  
**ASVS Level:** 1  
**Block threshold:** high  
**Verdict:** `SECURED` — all eight named high threats and all fifteen recovered low findings have current exact-subject executable evidence. **Threats closed:** 23/23. **Blocking open threats:** 0. This audit grants no requirement credit; EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 remain pending.

### Named high threat verification

| Threat ID | Severity | Disposition | Current executable evidence |
|-----------|----------|-------------|-----------------------------|
| T-133-32 | high | mitigate — closed | `bash scripts/ci/test_verify_nightly_run.sh` — 168 passed, 0 failed; exact receipt identity, canonical reconstruction, and mutation cases. |
| T-133-53 | high | mitigate — closed | `MIX_ENV=test mix test test/install_smoke/live_truth_parity_test.exs --seed 0` — 38 tests, 0 failures, 1 excluded; subject-owned package helper closure and tampering regression. |
| T-133-74 | high | mitigate — closed | `bash scripts/ci/test_nightly_incident.sh` — 26 passed, 0 failed; authenticated replay checkpoint, expiry, and tampering cases. |
| T-133-85 | high | mitigate — closed | `bash scripts/ci/test_nightly_incident.sh` — 26 passed, 0 failed; event and artifact coverage through the high-watermark. |
| T-133-91 | high | mitigate — closed | `MIX_ENV=test mix test test/install_smoke/live_truth_parity_test.exs --seed 0` — 38 tests, 0 failures, 1 excluded; authenticated-package lifecycle and helper-tampering regression. |
| T-133-105 | high | mitigate — closed | `bash scripts/ci/test_verify_nightly_run.sh` — 168 passed, 0 failed; append-only incident history and persisted lifecycle checks. |
| T-133-39-03 | high | mitigate — closed | `MIX_ENV=test mix test test/install_smoke/phase_133_reconciliation_test.exs test/install_smoke/phase_133_completed_validation_test.exs --seed 0` — 52 tests, 0 failures; production reconciler also passed: 46 completed, 5 halted, 1 pending plans; 51/52 summarized; 76 validation records. |
| T-133-42-03 | high | mitigate — closed | `bash scripts/ci/test_verify_nightly_run.sh` — 168 passed, 0 failed; occupied and concurrent destination publication cases. |

### Recovered item-level finding verification

All fifteen historical IDs retain their source-row identities and were independently checked against the exact subject. The production inventory validator passed the complete inventory, source and proof hashes, isolated application BEAM path check, and every distinct proof command in a clean detached checkout:

`MIX_ENV=test mix run --no-start --no-deps-check --no-compile scripts/maintainer/validate_phase_133_threat_inventory.exs --root . --security-report .planning/phases/133-evidence-charter-and-live-truth/133-SECURITY.md` → `phase 133 threat inventory valid: 15 exact-ID findings have current executable disposition proofs` (exit 0).

| Threat ID | Severity | Disposition | Executable proof |
|-----------|----------|-------------|------------------|
| T-133-102 | low | mitigate — dispositioned | `MIX_ENV=test mix test test/install_smoke/phase_133_security_disclosure_test.exs --seed 0` — passed in isolated validator; direct run 2 tests, 0 failures. |
| T-133-33-SC | low | mitigate — dispositioned | `scripts/ci/test_phase_133_package_manager_guards.sh` — passed: shell 168/0; ExUnit 129 tests, 0 failures, 1 excluded. |
| T-133-34-05 | low | mitigate — dispositioned | `MIX_ENV=test mix test test/install_smoke/phase_133_reconciliation_test.exs --only disclosure_canary --seed 0` — passed; direct run 35 tests, 0 failures, 34 excluded. Proof file SHA-256: `34800321a7d71d4b6f774d17b1ff865f102e895d250f1307422330971e4925ad`. |
| T-133-34-SC | low | mitigate — dispositioned | `scripts/ci/test_phase_133_package_manager_guards.sh` — passed: shell 168/0; ExUnit 129/0, 1 excluded. |
| T-133-35-SC | low | mitigate — dispositioned | `scripts/ci/test_phase_133_package_manager_guards.sh` — passed: shell 168/0; ExUnit 129/0, 1 excluded. |
| T-133-36-05 | low | mitigate — dispositioned | `MIX_ENV=test mix test test/install_smoke/phase_133_security_disclosure_test.exs --seed 0` — passed in isolated validator; direct run 2 tests, 0 failures. |
| T-133-36-SC | low | mitigate — dispositioned | `scripts/ci/test_phase_133_package_manager_guards.sh` — passed: shell 168/0; ExUnit 129/0, 1 excluded. |
| T-133-37-SC | low | mitigate — dispositioned | `scripts/ci/test_phase_133_package_manager_guards.sh` — passed: shell 168/0; ExUnit 129/0, 1 excluded. |
| T-133-38-SC | low | mitigate — dispositioned | `scripts/ci/test_phase_133_package_manager_guards.sh` — passed: shell 168/0; ExUnit 129/0, 1 excluded. |
| T-133-39-SC | low | mitigate — dispositioned | `scripts/ci/test_phase_133_package_manager_guards.sh` — passed: shell 168/0; ExUnit 129/0, 1 excluded. |
| T-133-40-SC | low | mitigate — dispositioned | `scripts/ci/test_phase_133_package_manager_guards.sh` — passed: shell 168/0; ExUnit 129/0, 1 excluded. |
| T-133-41-05 | low | mitigate — dispositioned | `MIX_ENV=test mix test test/install_smoke/phase_133_security_disclosure_test.exs --seed 0` — passed in isolated validator; direct run 2 tests, 0 failures. |
| T-133-41-SC | low | mitigate — dispositioned | `scripts/ci/test_phase_133_package_manager_guards.sh` — passed: shell 168/0; ExUnit 129/0, 1 excluded. |
| T-133-42-SC | low | mitigate — dispositioned | `scripts/ci/test_phase_133_package_manager_guards.sh` — passed: shell 168/0; ExUnit 129/0, 1 excluded. |
| T-133-71 | low | mitigate — dispositioned | `bash scripts/ci/test_verify_nightly_run.sh` — passed in isolated validator and direct run: 168 passed, 0 failed. |

## Historical Attachment Provenance

The historical attachment discrepancy remains unresolved: the claimed report SHA-256 is `706bd2bf5b1162907ab60a7cf910f40a5242cc203190f5578f098dd4647a9a65`, while the committed report blob SHA-256 is `f004b5310be7cd432a09fbcd252d2dac6781f739a9104f19de044f8a17e5a8a7`; the claimed digest also differs from the authenticated response text digest. The current item-level re-audit supersedes the aggregate attachment for present item dispositions only; it does not repair or erase the historical mismatch.

### Unregistered flags

**WARNING:** `133-17-SUMMARY.md:174-178` records `threat_flag: credential-scope`: the read-only workflow token enters the repository-owned FFmpeg installer process. Current source still forwards `GITHUB_TOKEN` to GitHub release metadata requests in `scripts/ci/install_ffmpeg.sh`; no explicit threat-ID mapping for that handoff is present. This remains an unregistered warning; no threat ID or acceptance is inferred.

**threats_open:** 0

**Requirement state:** EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 remain pending. No authorization, remote publication, or requirement credit is inferred.

## Current Independent Security Audit — Plan 55 subject

**Auditor:** independent `gsd-security-auditor` workflow
**Phase:** 133 — evidence-charter-and-live-truth
**Subject SHA:** `9bb10539a0bccd734a4921d6a0f4d072b478332e`
**Census SHA-256:** `df484acda67c5919427449344d749a4b5b73123a51d0cda9d774f6159bd8d484`
**Inventory SHA-256:** `3d8bdf58656239b4d0783398e11ff3fc8a212fc4764ba9fdf94ef616951e4521`
**Independent census receipt SHA-256:** `bee4299a382df8969700915b60748e37af4b80db6675370e8e217820d93704f5` (both detached worktree receipts)
**Verdict:** `OPEN_THREATS` — two of three Plan 55 findings are closed; one remains open. **Threats closed:** 25/26. **Open threats:** 1. This audit grants no requirement credit; EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 remain pending.

### Plan 55 threat-model verification

| Threat ID | Severity | Disposition | Exact-subject evidence |
|-----------|----------|-------------|------------------------|
| T-133-55-01 | high | mitigate — closed | The authenticated Plan 49 compatibility repair adds the pinned Elixir version and `MIX_ENV=test` to the affected harness. Assertions remain intact; focused canonical and locally available supported-cell suites pass. |
| T-133-55-02 | high | mitigate — closed | Both detached census receipts validate and match. All 15 inventory rows, REVIEW, VALIDATION, and SECURITY bind the exact subject and census digest. The report dispositions match the 15 inventory IDs. |
| T-133-55-03 | high | mitigate — open | No passing Plan 55 qualification summary and final reconciliation exist. `mix ci` fails on baseline formatting, and the sole coverage command exited 2 with 20 failures. No requirement credit or remote mutation is permitted. |

### Current disposition

- [x] The eight existing named high threats and fifteen recovered historical findings retain their recorded dispositions.
- [x] T-133-55-01 is closed by the observed compatibility repairs and passing focused suites.
- [x] T-133-55-02 is closed by the independently checked, matching census and source-bound report set.
- [ ] T-133-55-03 remains open because local qualification is blocked; Plan 56 remains a separate authorization boundary.
- [x] Phase 133 requirements remain pending; this report grants no acceptance credit.

**Qualification blockers:** `mix ci` failed `--check-formatted` on baseline-unchanged `test/install_smoke/nightly_policy_test.exs`. The one `mix coveralls.multiple --type local --type json` invocation exited 2 after 1,679 tests, 20 failures, 87 excluded, 4 skipped, at 82.1% coverage. A later `mix test --failed --seed 514296` reran the 20 failures and passed 20/20, but does not change the coverage command's exit status. No second coverage invocation was made.

**Approval:** not secured for local Plan 55 qualification. Plan 56 remains the separate authorization and remote-attempt boundary.

## Plan 64 ASVS L1 Security

source_sha: 98fe9a231f76d46e37eee4341c066307c8ba631d
source_tree: 2ac4ecb482523d0b023995096553390c4cec9a76
report_sha256: 7ac578c42750d02a7600804eb70c3e0e47b9fff45b5a470c42ec4d87284e6bd7
exit_code: 0
command: read-only ASVS L1 audit of Plan 133-64 diff be004386fc041e63e58f2ca83a44a8870fb6b7b6..98fe9a231f76d46e37eee4341c066307c8ba631d plus fresh JOSE report and exact-source replay
scope: Plan 133-64 declared threats T-133-64-01 through T-133-64-05; final reconciler, JOSE probe, focused tests, and report; no requirement credit
verdict: SECURED
high_findings: 0

**Phase:** 133 — evidence-charter-and-live-truth  
**Threats Closed:** 5/5  
**ASVS Level:** 1  
**Block threshold:** high

### Threat Verification

| Threat ID | Category | Severity | Disposition | Evidence |
|-----------|----------|----------|-------------|----------|
| T-133-64-01 | Spoofing | high | mitigate — CLOSED | `scripts/maintainer/test_phase_133_jose_structure.sh:31-37,113-120,204-258` pins an exact local commit, creates two clean detached worktrees at its SHA/tree, exercises the negative missing-include control and repaired compile/extract control; `scripts/maintainer/validate_phase_133_reconciliation.exs:2938-3045` binds report digest, SHA/tree, expected control outcomes, exact header paths/types/readability/containment, and source/staged hashes. The supplied production probe and exact-source replay both exited 0. |
| T-133-64-02 | Tampering | high | mitigate — CLOSED | `scripts/maintainer/validate_phase_133_reconciliation.exs:3055-3148` requires one uniquely headed final authority section, exact historical prefix bytes, section digest, matching source SHA/tree/report digest, zero exit, scope, verdict, and zero finding count for REVIEW, SECURITY, and Nyquist. Stale section digest mutation is covered at `test/install_smoke/phase_133_reconciliation_test.exs:1050-1063`. |
| T-133-64-03 | Elevation of privilege | high | mitigate — CLOSED | `scripts/maintainer/validate_phase_133_reconciliation.exs:2635-2656,2734-2748,2750-2916` constrains Plan 63 prerequisite identity, blocks Plans 56/60/61, requires zero credit/no remote handoff, and requires committed source range/current clean source. Production fixture bypass is rejected in option parsing at `:309-318`; regression coverage is at `test/install_smoke/phase_133_reconciliation_test.exs:1077-1084`. |
| T-133-64-04 | Repudiation | high | mitigate — CLOSED | `scripts/maintainer/validate_phase_133_reconciliation.exs:2635-2660` checks immutable Plan 62 summary/report hashes, prior receipt identity, and Plan 62 halted state before Plan 64 acceptance; Plan 64 metadata also binds Plan 63 source and receipt (`:2840-2889`). |
| T-133-64-05 | Information disclosure | medium | mitigate — CLOSED | `scripts/maintainer/test_phase_133_jose_structure.sh:123-155,221-229` records bounded diagnostic lines, truncates each to 400 characters, strips the disposable worktree path, and writes only sanitized control JSON (`:260-291`); raw logs remain in the private temporary directory and are removed by cleanup (`:99-109`). |

### Unregistered Flags

No Plan 64 summary exists at audit time, so no Plan 64 `## Threat Flags` section is available to assess. No additional unregistered attack surface was identified in the four-file source diff.

This scoped audit closes the five Plan 64 threats only. It does not resolve the pre-existing phase-level open threat or grant EVID-01, EVID-02, EVID-03, EVID-04, or TRUTH-08 credit; all five requirements remain pending.

**threats_open:** 0

## Plan 64 ASVS L1 Security — Final Source
source_sha: 8477de3f6db7c83c59ccd8b8a74e3fc80af597d0
source_tree: 3b4f43cec232bc3cc57fcc4a9bd3aa6cc4f241fc
report_sha256: 9a67545fcf642ddf3f03d76d58104ed81e147fec29a031cf71b1b9618bd3f8a4
exit_code: 0
command: independent read-only ASVS L1 audit of Plan 133-64 final committed diff and source-bound JOSE report
scope: T-133-64-01 through T-133-64-05; reconciler, JOSE probe, regression tests, report; no requirement credit
verdict: SECURED
high_findings: 0

**Phase:** 133 — evidence-charter-and-live-truth
**Threats Closed:** 5/5
**ASVS Level:** 1
**Block threshold:** high

### Threat Verification

| Threat ID | Category | Severity | Disposition | Evidence |
|---|---|---|---|---|
| T-133-64-01 | Spoofing | high | mitigate — CLOSED | Exact-subject JOSE probe/replay and report-bound header path, file type, readability, containment, and hash checks. |
| T-133-64-02 | Tampering | high | mitigate — CLOSED | Authority sections bind source, tree, report digest, verdict and counts; duplicate keys are rejected and the digest-recomputed mutation is covered for all three authority types. |
| T-133-64-03 | Elevation of privilege | high | mitigate — CLOSED | Production and fixture modes are separated; blocked plans, premature requirement credit, and handoff fields are rejected. |
| T-133-64-04 | Repudiation | high | mitigate — CLOSED | Plan 62 evidence and prior receipt identities remain bound; Plan 63 prerequisite and final committed source range are validated. |
| T-133-64-05 | Information disclosure | medium | mitigate — CLOSED | Diagnostics are bounded and sanitized, temporary worktree logs are cleaned up, and the persisted report contains no transient root path. |

No additional high issue remains in the declared Plan 64 scope. This audit does not resolve the pre-existing phase-level open threat or grant requirement credit. EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 remain pending.

**threats_open:** 0


## Plan 64 ASVS L1 Security — Revalidated Source
source_sha: e5be998a2045588bc70939ca961dd665918afef8
source_tree: 86d4dadb2a3ce223f9988e471ff93f369c90fae1
report_sha256: 9b13d3059896d754591020078489b36cfdc3389e0733b4f5c10495d957252e1e
exit_code: 0
command: independent read-only ASVS L1 audit of Plan 133-64 revalidated committed source and source-bound JOSE report
scope: T-133-64-01 through T-133-64-05; reconciler, JOSE probe, regressions, and report; no requirement credit
verdict: SECURED
high_findings: 0

**Phase:** 133 — evidence-charter-and-live-truth
**Threats Closed:** 5/5
**ASVS Level:** 1
**Block threshold:** high

### Threat Verification

| Threat ID | Category | Severity | Disposition | Evidence |
|---|---|---|---|---|
| T-133-64-01 | Spoofing | high | mitigate — CLOSED | Exact-subject JOSE probe/replay and report-bound header path, type, readability, containment, and hash checks. |
| T-133-64-02 | Tampering | high | mitigate — CLOSED | Authority sections bind source, tree, report digest, verdict and counts; duplicate keys are rejected and the digest-recomputed mutation is covered for all three authority types. |
| T-133-64-03 | Elevation of privilege | high | mitigate — CLOSED | Production and fixture modes are separated; blocked plans, premature requirement credit, and handoff fields are rejected. |
| T-133-64-04 | Repudiation | high | mitigate — CLOSED | Plan 62 evidence and prior receipt identities remain bound; Plan 63 prerequisite and final committed source range are validated. |
| T-133-64-05 | Information disclosure | medium | mitigate — CLOSED | Diagnostics are bounded and sanitized, temporary worktree logs are cleaned up, and the persisted report contains no transient root path. |

No additional high issue remains in the declared Plan 64 scope. This audit does not resolve the pre-existing phase-level open threat or grant requirement credit. EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 remain pending.

**threats_open:** 0

## Plan 64 ASVS L1 Security — Qualified Source
source_sha: 321fc8409c825101bf6080348a7205f680cc7ffe
source_tree: 5e047ec4ce7502c7f9773b77d497c36ea9cd5144
report_sha256: d13415a68edcc85abcc4ef2d6a54f092112520c27fb93b880a6f36462654a3bf
exit_code: 0
command: independent read-only ASVS L1 audit of Plan 133-64 qualified committed source and source-bound JOSE report
scope: T-133-64-01 through T-133-64-05; reconciler, JOSE probe, authority fixture and regression tests, report; no requirement credit
verdict: SECURED
high_findings: 0

**Phase:** 133 — evidence-charter-and-live-truth
**Threats Closed:** 5/5
**ASVS Level:** 1
**Block threshold:** high

### Threat Verification

| Threat ID | Category | Severity | Disposition | Evidence |
|---|---|---|---|---|
| T-133-64-01 | Spoofing | high | mitigate — CLOSED | The probe pins the full subject commit/tree, runs two clean detached negative/repaired controls, and cleans them. Reconciliation binds committed source and report identity, expected controls, exact header paths/types/readability/containment, and matching hashes. |
| T-133-64-02 | Tampering | high | mitigate — CLOSED | Reconciliation requires one qualified heading, exact historical prefix, section digest and matching source/tree/report/exit/scope/verdict/count values; duplicate field keys are rejected. Regression mutates all three authority sections with conflicting fields and recomputed digests, then requires rejection. |
| T-133-64-03 | Elevation of privilege | high | mitigate — CLOSED | Production and fixture inputs are separated; committed source/range is required; blocked-plan, zero-credit, and no-handoff boundaries are enforced. |
| T-133-64-04 | Repudiation | high | mitigate — CLOSED | Plan 62 summary/report/receipt and Plan 63 prerequisite identities remain bound to final committed source lineage. |
| T-133-64-05 | Information disclosure | medium | mitigate — CLOSED | Diagnostics are bounded and sanitized, transient paths normalized, temporary logs and worktrees removed, and report fields contain no temporary root path. |

No additional high issue remains in the declared Plan 64 scope. This audit does not resolve the pre-existing phase-level open threat or grant EVID-01, EVID-02, EVID-03, EVID-04, or TRUTH-08 credit; all remain pending.

**threats_open:** 0
