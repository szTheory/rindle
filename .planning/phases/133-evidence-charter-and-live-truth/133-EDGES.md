---
phase: 133-evidence-charter-and-live-truth
type: edge-mapping
decision: D-133-R5
rows: 11
---

# Phase 133 Edge Rows → Tests

Each of the eleven spec-less edge rows maps to named, passing test cases (D-133-R5).
The rows come from the FLAGGED assumptions in Plans 01–05. No row is not-applicable.
All files below ship on the landing branch. The four shell harnesses run in the
merge-blocking `Proof` job (`Run Nightly evidence harnesses`), and the ExUnit files run
in the merge-blocking Quality lane (`mix test`).

Two cases were added in Plan 211 because the behavior had no named test. Both pass on
the landing branch and go red when the guarded code is mutated:
- the EVID-01 adjacency case, which fails when the duplicate rule ignores observation IDs;
- the TRUTH-08 unclassified case, which fails when an unknown claim type is accepted.

| Row | Definition (source plan) | Test file :: case | Result |
|---|---|---|---|
| EVID-01 boundary | Zero, one and many observations or candidates; every count or set boundary that breaks exact taxonomy or assignment coverage is rejected (133-01) | `test/install_smoke/evidence_census_test.exs` :: "EVID-01: zero-cardinality and imprecise count boundaries fail closed"; "EVID-01: taxonomy and observation assignment mutations fail closed" | pass |
| EVID-01 adjacency | Equal normalized observations collapse only as duplicates, while candidates that share a detector or file stay separate (133-01) | `test/install_smoke/evidence_census_test.exs` :: "EVID-01: adjacent observations sharing a detector and file stay separate candidates" (added); "EVID-01: taxonomy and observation assignment mutations fail closed" (identical observations → "normalized observations contain duplicates") | pass |
| EVID-01 empty | Null, empty, absent-dimension and absent-candidate inputs fail unless the taxonomy states a justified inapplicability (133-01) | `test/install_smoke/evidence_census_test.exs` :: "EVID-01: zero-cardinality and imprecise count boundaries fail closed"; "EVID-01: inapplicability requires an allowlisted dimension and exact bounded reason" | pass |
| EVID-01 ordering | Canonical serialization sorts taxonomy, detectors, observations and candidates, so equal inputs give byte-stable output (133-01) | `test/install_smoke/evidence_census_test.exs` :: "EVID-01: registry, candidates, and transitions serialize canonically"; "EVID-01: unchanged inputs produce byte-stable canonical receipts" | pass |
| EVID-01 precision | Counts are integers and digests exact; no float, line number or timestamp enters candidate identity (133-01) | `test/install_smoke/evidence_census_test.exs` :: "EVID-01: zero-cardinality and imprecise count boundaries fail closed" (count 1.5 rejected); "EVID-01: volatile evidence attributes do not replace reviewer-owned candidate identity" | pass |
| EVID-02 unclassified | Exact numeric-component boundaries for the sole supported Elixir 1.17 / OTP 27 cell, near matches rejected, and no unclassified Dialyzer outcome treated as green (133-02, 133-08) | `scripts/ci/test_verify_nightly_run.sh` :: "unsupported_elixir_11_17 fails closed"; "unsupported_elixir_1_170 fails closed"; "unsupported_otp_127 fails closed"; "resolved Elixir 11.17 near-match fails closed"; "resolved Elixir 1.170 near-match fails closed"; "resolved OTP 127 near-match fails closed". `scripts/ci/test_nightly_dialyzer.sh` :: "unknown analysis failure stays red without rebuild"; "genuine warning stays red without rebuild" | pass |
| EVID-03 boundary | The accepted state space is exact; any failed, cancelled, skipped, missing, extra, unknown or malformed state is red (133-03) | `scripts/ci/test_nightly_summary_gate.sh` :: "applicable failure is red"; "applicable cancelled is red"; "applicable skipped is red"; "missing declared job is red"; "unexpected observed job is red"; "malformed needs is red". `scripts/ci/test_verify_nightly_run.sh` :: "verify-scheduled rejects a verdict that disagrees with Nightly Summary" | pass |
| EVID-03 precision | Job sets and booleans are exact JSON values; shell truthiness, partial names or summary text never decide the verdict (133-03) | `scripts/ci/test_nightly_summary_gate.sh` :: "always job requires applicable boolean true (\"true\")"; "always job requires applicable boolean true (1)"; "non-string observed result is red". `scripts/ci/test_verify_nightly_run.sh` :: "verify-scheduled rejects a gating need that disagrees with job conclusions" | pass |
| EVID-04 idempotency | Re-running for the same run appends no duplicate evidence, and a completed close is a no-op (133-04) | `scripts/ci/test_nightly_incident.sh` :: "same complete log replay is mutation-idempotent"; "repeated green with no incident is an unmarked no-op"; "genesis adopts the legacy open incident and closes it citing the green run: re-run on the same run is mutation-idempotent" | pass |
| EVID-04 concurrency | More than one open incident, or a conflicting transition, fails with no mutation rather than picking a winner (133-04) | `scripts/ci/test_nightly_incident.sh` :: "simultaneous open incidents fail closed"; "stale mutation preimage restarts full replay"; "concurrent issue-history advancement invalidates checkpoint"; "genesis with duplicate legacy open incidents fails closed" | pass |
| TRUTH-08 unclassified | Any claim the derived model cannot classify fails rather than being treated as prose (133-05, 133-08) | `test/install_smoke/live_truth_parity_test.exs` :: "TRUTH-08: claims the derived model cannot classify fail instead of passing as prose" (added); "package receipt producer rejects caller-authored command result maps" | pass |
