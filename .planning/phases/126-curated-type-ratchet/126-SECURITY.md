---
phase: 126
slug: curated-type-ratchet
status: verified
threats_open: 0
asvs_level: 1
created: 2026-08-23
---

# Phase 126 — Security

> ASVS L1 verification of the threat registers authored across Plans 126-01 through 126-10.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Ignore policy → Dialyzer | The curated baseline must not admit a new or broadened suppression. | Exact path/discriminator tuples |
| Local/PR head → GitHub authorities | CI and Nightly receipts must identify the code actually proposed for merge. | Commit SHA, run/job identities, conclusions |
| Type precision → runtime behavior | Analyzer-driven edits must preserve migration, storage, TUS, Mux, worker, Admin, telemetry, and error contracts. | Public terms, tagged errors, opaque state, lifecycle transitions |
| GitHub receipt → issue state | Issue #76 may close only after its exact-head acceptance predicate is terminal. | Public URLs, conclusions, annotation count |

## Threat Register

Repeated plan-local threat IDs are grouped below by control family; the audit covered all 43 plan-register entries.

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| 01–10: policy integrity | Tampering | `.dialyzer_ignore.exs` and policy test | high | mitigate | Literal 35-tuple approved universe, live-subset enforcement, and invalid new-string/atom/duplicate/broad fixtures; 35 focused tests pass. | closed |
| 01–10: authority provenance | Spoofing / Repudiation | PR and Nightly receipts | high | mitigate | Final PR head `a75de25…` matches successful CI Summary `97230425075` and Nightly `32654467509`; Dialyzer `97230968773` and Summary `97231330661` pass with zero annotations. | closed |
| 01/09/10: topology integrity | Tampering | Nightly/cache/release topology | high | mitigate | Topology/cache policy tests pass; no workflow, dependency, lockfile, release-policy, or script change is in scope. | closed |
| 02: migration boundary | Tampering / Elevation of privilege | Migration dispatcher and host fixture | high | mitigate | Focused migration ownership/refusal/rollback proof plus SAFE-01; retained reports are exact supported analyzer noise. | closed |
| 03–04: operational boundaries | Tampering / Repudiation | Batch task, Admin actions, runtime checks/status, HTML, ProcessVariant | high | mitigate | Focused result/output/telemetry/error tests and SAFE-01 preserve observable behavior. | closed |
| 05–06: storage boundaries | Tampering / Denial of service | GCS, Local, and S3 streams | high | mitigate | Bounded stream, cleanup, concatenation, public endpoint, and tagged-error tests; exact retained filters only. | closed |
| 07: opaque TUS boundary | Tampering / Information disclosure | TUS creation and stream state | high | mitigate | Opaque-safe tagged checksum state, protocol tests, Local-TUS tests, SAFE-01, and zero supported annotations. | closed |
| 07–08: provider/lifecycle boundary | Tampering / Repudiation | Mux, Broker, PromoteAsset, public facade | high | mitigate | Explicit tagged transitions/errors, focused worker/facade tests, and SAFE-01. | closed |
| 09–10: issue disposition | Repudiation / Elevation of privilege | GitHub issue #76 | high | mitigate | Issue was reopened after final-head authority, received the exact receipt, then closed at `2026-08-23T17:41:49Z`. | closed |
| 10: receipt disclosure | Information disclosure | Public issue comment | medium | mitigate | Receipt contains only public SHA/run/job links, toolchain, outcomes, and annotation count. | closed |
| 01–10: dependency scan scope | Tampering | Dependency/package surface | low | accept | Phase changes no dependencies or package-install behavior; full CI and topology tests cover the unchanged surface. | closed |

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-126-01 | 01–10: dependency scan scope | No dependency or package-install surface changed; introducing a new dependency scan would be unrelated scope. Existing full CI and locked topology remain authoritative. | Project maintainer policy | 2026-08-23 |

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-23 | 43 | 43 | 0 | GSD security auditor, ASVS L1 |
| 2026-08-23 | 1 re-audited | 1 | 0 | GSD security auditor after exact-head issue reclose |

## Sign-Off

- [x] All threats have a disposition.
- [x] Accepted risks documented in Accepted Risks Log.
- [x] `threats_open: 0` confirmed.
- [x] `status: verified` set in frontmatter.

**Approval:** verified 2026-08-23
