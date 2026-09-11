---
phase: "133"
slug: "evidence-charter-and-live-truth"
status: verified
threats_open: 0
asvs_level: 1
created: "2026-09-10"
---

# Phase 133 — Security

> Verified Phase 133 threat register. All planned threats are closed; accepted risks are bounded, low severity, and documented below.

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

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-09-10
