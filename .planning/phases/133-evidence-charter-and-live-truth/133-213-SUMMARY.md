---
phase: 133-evidence-charter-and-live-truth
plan: "213"
subsystem: ci-evidence
tags: [scheduled-nightly, live-evidence, closure, rescope]
status: complete
halted: false
requirements-completed: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
requirements_pending: []
requires:
  - phase: 133-212
provides:
  - "133-NIGHTLY-SCHEDULED-RECEIPTS.json: verify-scheduled receipt for scheduled Nightly run 38699984093"
  - "133-213-CENSUS-LEDGER.json and 133-213-CENSUS-RECEIPT.json: census regenerated and validated at the receipt SHA"
  - "133-213-predicates.sh: the five per-requirement predicates as one re-runnable script"
affects: [REQUIREMENTS]
key-decisions:
  - "The qualifying-run rule was amended at user direction. A later main commit qualifies when every manifest-file change since the merge SHA is under test/ and landed through a green-CI PR. #117 (version-agnostic parity tests) was the only such change."
  - "The scheduled receipt goes in a new file instead of being appended to 133-NIGHTLY-EVIDENCE.json. That file uses the older receipt schema, and retired execution-branch tools still read it."
  - "The census ledger was re-subjected to the receipt SHA as a separate file (133-213-CENSUS-LEDGER.json). The checkout at the receipt SHA stayed clean, so the census receipt is authoritative, not diagnostic."
---

# Plan 213 Summary: per-requirement closure on main's live evidence

## Result

All five requirements passed their own automated predicates and are marked Complete in REQUIREMENTS.md. The only inputs were GitHub Actions on main, read only. There was no dispatch, no rerun, no push and no merge in this plan.

## Qualifying run

| Field | Value |
|---|---|
| Run | [38699984093](https://github.com/szTheory/rindle/actions/runs/38699984093) |
| Event / attempt | schedule / 1 |
| Head SHA | `3858267b4837d04367f1d26b1ee74651e507ea77` (main) |
| Conclusion / verdict | success / green |

**Why it qualifies.** The Plan 212 merge SHA is `ecd4d5a0`. Between it and `3858267b`, the only commit touching a manifest file is `98c049be` (#117). That commit changed only `test/install_smoke/live_truth_parity_test.exs`, and #117's CI Summary was SUCCESS. The other commits are the 0.4.7 release (`46e4dbc3`) and the RELEASE-TRAIN baseline (`3858267b`), and neither touches a manifest file.

**Receipt.** `verify-scheduled --run-id 38699984093` exited 0 twice, and the two receipts were byte-identical.
- Gating needs: compat-matrix, dialyzer, gcs-soak and package-consumer-gcs-live all report success.
- The verdict artifact records both GCS lanes as `not-run`, reason `required-secrets-unavailable`, under the bounded upstream-and-secrets rule. They are not counted as passed.

## Predicates

Command, with a clean checkout of `3858267b` as `CENSUS_ROOT`:

```
bash .planning/phases/133-evidence-charter-and-live-truth/133-213-predicates.sh
```

It printed `PASS` for all five IDs and exited 0.

| ID | Predicate | Evidence |
|---|---|---|
| EVID-01 | The census is regenerated at the receipt SHA (collector exit 0, clean tree), and `validate_evidence_census.exs` accepts it. | "evidence census valid for 3858267b…" |
| EVID-02 | The Dialyzer job in the receipt is `success`. In push run 38667117452 on `ecd4d5a0`, Proof's "Run Nightly evidence harnesses" step, which includes `test_nightly_dialyzer.sh`, is `success`. | receipt `.jobs`, push run job steps |
| EVID-03 | The verdict artifact says `green`, and Nightly Summary is `success`. Each of the four artifact gating results equals the aggregated job conclusions and `gating_needs`. The push run's "Nightly Summary gate logic" and Proof harness steps are `success`. | receipt, push run job steps |
| EVID-04 | The receipt is green. Incident #88 (adopted at genesis) was closed at 2026-10-15T07:45:06Z by a comment carrying `nightly-mutation:close:38699984093:1`. No labelled or title-matching incident is open. | `gh issue view 88`, `gh issue list` |
| TRUTH-08 | Push run 38667117452 on `ecd4d5a0` concluded `success`. All seven merge-blocking jobs are `success`: Quality ×2, Integration, Proof, Package Consumer Proof Matrix, Adopter and CI Summary. Proof's "Run adoption proof matrix drift gate" step, which runs the `live_truth_parity_test` derived and package-authority proofs, is `success`. | push run jobs |

**Negative checks.** The predicates were run against tampered receipts, and each flipped to `FAIL` as expected:
- Dialyzer conclusion set to `failure`: EVID-02 and EVID-03 failed.
- `gating_needs.gcs-soak` set to `failure`: EVID-03 failed.

With the real receipt restored, the script exits 0 again.

## Notes

- **Earlier failure-path observation.** On 2026-10-14, run 38529530511 updated #88 with a failure comment. That was under the pre-landing workflow. EVID-04's predicate for a green receipt does not depend on it.
- **Known debt carried from 133-211:**
  - The Nightly scripts hard-code phase-133 `.planning` paths, so they need re-pointing when the phase is archived.
  - The GCS live lanes need upstream secrets to be applicable.
