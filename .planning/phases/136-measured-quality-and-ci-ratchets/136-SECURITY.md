---
phase: "136"
slug: "measured-quality-and-ci-ratchets"
status: verified
threats_open: 0
threats_total: 22
asvs_level: 1
register_authored_at_plan_time: true
method: inline-L1-mitigation-audit
source_sha: 4fdd3fba5ef5bc73be52473bc72de03fe56926d4
created: "2026-10-20"
---

# Phase136 — Security

The configured L1 audit verifies the20unique declared threats, deduplicating the repeated supply-chain row. Every required mitigation is present and has a named executable owner; the prior supported canonical and the replacement focused65test regression provide behavior evidence; replacement measurement acceptance remains pending. This is an inline source/behavior-evidence audit, not an independent reviewer. No new risk is accepted by this audit and no measured requirement is closed by it.

## Trust Boundaries

| Boundary | Data crossing |
|---|---|
| Frozen Git source to measurement owner | Exact SHA/tree, clean projection and supported runtime |
| External tool bytes to extraction/execution | Reviewed archive/binary/OCI digests |
| Child processes to immutable receipts | Bounded sanitized output, exits, argv and digests |
| GitHub API to timing/qualification | Exact published PR head, sole required context and complete eligible population |

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation evidence | Status |
|---|---|---|---|---|---|---|
| T-136-01 | Tampering | credo_quality_normalize.exs | medium | mitigate | `scripts/maintainer/credo_quality_normalize.exs`; executable proof `test/install_smoke/credo_policy_test.exs` (green current canonical/focused suites). | closed |
| T-136-02 | Tampering | .dialyzer_ignore.exs | medium | mitigate | `test/install_smoke/dialyzer_ignore_policy_test.exs`; executable proof `test/install_smoke/dialyzer_ignore_policy_test.exs` (green current canonical/focused suites). | closed |
| T-136-03 | Repudiation | fresh/restored receipt | medium | mitigate | `scripts/ci/run_nightly_dialyzer.sh`; executable proof `scripts/ci/test_nightly_dialyzer.sh` (green current canonical/focused suites). | closed |
| T-136-04 | Tampering | verify_coverage_floor.exs | medium | mitigate | `scripts/maintainer/phase136_evidence.py`; executable proof `test/install_smoke/coverage_floor_policy_test.exs` (green current canonical/focused suites). | closed |
| T-136-05 | Information disclosure | async receipt | medium | mitigate | `scripts/maintainer/verify_async_isolation_receipt.sh`; executable proof `test/install_smoke/async_isolation_evidence_runner_test.exs` (green current canonical/focused suites). | closed |
| T-136-06 | Repudiation | async receipt | medium | mitigate | `scripts/maintainer/async_isolation_evidence.sh`; executable proof `test/install_smoke/async_isolation_evidence_runner_test.exs` (green current canonical/focused suites). | closed |
| T-136-07 | Tampering | FFmpeg/MinIO inputs | high | mitigate | `scripts/ci/install_ffmpeg.sh`; executable proof `test/install_smoke/ci_cache_hygiene_test.exs` (green current canonical/focused suites). | closed |
| T-136-08 | Elevation of privilege | ci.yml PR jobs | high | mitigate | `test/install_smoke/quality_signal_policy_test.exs`; executable proof `test/install_smoke/ci_lane_split_test.exs` (green current canonical/focused suites). | closed |
| T-136-09 | Denial of service | process-heavy jobs | medium | mitigate | `.github/workflows/ci.yml`; executable proof `test/install_smoke/quality_signal_policy_test.exs` (green current canonical/focused suites). | closed |
| T-136-10 | Repudiation | CI Summary/release gate | high | mitigate | `test/install_smoke/quality_signal_policy_test.exs`; executable proof `test/install_smoke/quality_signal_policy_test.exs` (green current canonical/focused suites). | closed |
| T-136-11 | Tampering | bootstrap command map | medium | mitigate | `scripts/maintainer/verify_contributor_bootstrap.sh`; executable proof `test/install_smoke/contributor_bootstrap_test.exs` (green current canonical/focused suites). | closed |
| T-136-12 | Repudiation | timing receipt | high | mitigate | `scripts/ci/collect_pr_timing_receipt.sh`; executable proof `test/install_smoke/ci_timing_automation_test.exs` (green current canonical/focused suites). | closed |
| T-136-13 | Tampering | qualification manifest | medium | mitigate | `scripts/maintainer/phase136_evidence.py`; executable proof `test/install_smoke/phase136_qualification_test.exs` (green current canonical/focused suites). | closed |
| T-136-14 | Spoofing | current-subject preflight | high | mitigate | `scripts/ci/collect_pr_timing_receipt.sh`; executable proof `test/install_smoke/ci_timing_automation_test.exs` (green current canonical/focused suites). | closed |
| T-136-15 | Repudiation | timing controller state | medium | mitigate | `scripts/ci/collect_pr_timing_receipt.sh`; executable proof `test/install_smoke/ci_timing_automation_test.exs` (green current canonical/focused suites). | closed |
| T-136-16 | Tampering | phase136_measure.sh | high | mitigate | `scripts/maintainer/phase136_evidence.py`; executable proof `test/install_smoke/phase136_measure_test.exs` (green current canonical/focused suites). | closed |
| T-136-17 | Repudiation | verify_phase136_qualification.sh | high | mitigate | `scripts/maintainer/phase136_evidence.py`; executable proof `test/install_smoke/phase136_qualification_test.exs` (green current canonical/focused suites). | closed |
| T-136-18 | Repudiation | final measurement receipts | medium | mitigate | `scripts/maintainer/phase136_evidence.py`; executable proof `test/install_smoke/phase136_measure_test.exs` (green current canonical/focused suites). | closed |
| T-136-19 | Tampering | subject pin and coverage receipt | high | mitigate | `scripts/maintainer/phase136_evidence.py`; executable proof `test/install_smoke/coverage_floor_policy_test.exs` (green current canonical/focused suites). | closed |
| T-136-20 | Denial of service | Proof harness concurrency | medium | mitigate | Fixed four-child bound, unchanged timeout; parsed-YAML overlap test in `quality_signal_policy_test.exs`; green PR/main Proof. | closed |
| T-136-21 | Tampering | Required CI result | high | mitigate | Wait-all/fail-any parsed-YAML tests cover each failing child; green PR/main CI Summary. | closed |
| T-136-SC | Tampering | package installs | high | mitigate | Existing locked dependencies/tooling rehydrated; no manifest/lock/runtime-file change; pinned consumed FFmpeg/mc/OCI inputs audited. | closed |

## Supplemental Gap Controls

Plans12/13 retain prior first-red evidence, run file-mutating fixtures synchronously, account for exact residue literals, preserve timed-out command argv/exit124/output digest, kill owned process groups and retain a1200second overall bootstrap deadline with600seconds for full mix ci. Real3second timeout and receipt-consumer tests prove open outcomes cannot be relabeled green. Unit-only accepted probes make fixture logic portable; the production measurement runtime guard remains strict.

## Accepted Risks Log

No newly accepted risks. Disposable Postgres16-alpine patch tracking is the existing explicit Plan05/workflow policy exception, not a newly granted exemption. Existing locked dependencies and documented Mix/Hex tooling were rehydrated; no package manifest, lock or runtime hint changed.

## Limits

Closing a mitigation means the control exists and its behavioral verification is present. Final bootstrap/async receipts and live exact-ten PR timing remain separate acceptance authorities; missing live evidence cannot receive green credit. No PR publication or trigger-label mutation occurred.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|---|---|---|---|---|
| 2026-10-20 | 20 | 20 | 0 | Inline L1 audit, declared register plus executable owner evidence |

## Sign-Off

- [x] All20threats have a disposition and verified mitigation.
- [x] No new accepted risk or weakened source/runtime/provenance check.
- [x] threats_open:0 at the configured high threshold; all declared threats are closed.
- [x] status:verified records this source audit, without phase qualification credit.

## Hygiene repair audit

The replacement source preserves all twenty declared threat mitigations. Legacy command-output relocation crosses the existing local-artifact boundary, with the same fixed-name allowlist, output-size and exact digest checks. Fallback cannot bypass an existing original or dangling symlink. New owner tests execute tamper, missing-output and both original/relocated symlink rejection. The 31 original outputs retain their exact bytes and all 38 receipt JSON files retain their original hashes. No junk/ignore rule, package, toolchain or security exception was broadened. This remains an inline L1 audit with zero open threats, without granting pending measurement credit.

## Parallel harness delta (2026-10-21)

Inline self-review of the three-file repair confirms a fixed four-child bound, isolated fixtures, wait-all behavior and fail-any propagation. The parsed workflow body passes 39 focused policy/topology tests, including an overlap barrier and each of four failure positions. Actual harness execution passed sequentially in 94.292 seconds and concurrently in 66.352 seconds. The job timeout, required context, permissions, dependencies and assertion set are unchanged. No new security finding; Plan15 threats T-136-20 and T-136-21 have executable mitigation. The distinct original Plan05 threats T-136-09 and T-136-10 retain their existing mitigations. Numeric timing acceptance is explicitly deferred unfinished under 136-SPEED-DEFERRAL.json; this audit provides no speed acceptance credit.

## Threat identity repair (2026-10-21)

Plan15 originally reused Plan05 identifiers. Its two distinct threats are now T-136-20 and T-136-21, following the previous highest ID19. The register now contains22 unique threats including SC, all closed; the original20-threat audit remains historical. No source or acceptance claim changed.
