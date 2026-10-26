---
status: passed
verification_mode: inline
scope: implementation-fixtures
covered_files: [".github/workflows/readiness-retention.yml", ".planning/quick/261025-nfr-implement-immutable-snapshot-readiness-a/261025-nfr-PLAN.md", ".planning/quick/261025-nfr-implement-immutable-snapshot-readiness-a/261025-nfr-SUMMARY.md", "RUNNING.md", "guides/readiness_evidence.md", "scripts/ci/readiness_fixture.exs", "scripts/ci/readiness_validator_fixture.exs", "scripts/ci/readiness_validator_fixture.py", "scripts/ci/test_exact_head_closure.sh", "scripts/ci/test_readiness_fixtures.sh", "scripts/ci/test_readiness_snapshot.py", "scripts/ci/test_readiness_snapshot.sh", "scripts/maintainer/collect_readiness_remote.py", "scripts/maintainer/collect_readiness_runs.py", "scripts/maintainer/exact_head_readiness.py", "scripts/maintainer/readiness_acceptance.py", "scripts/maintainer/readiness_adoption.py", "scripts/maintainer/readiness_closure.py", "scripts/maintainer/readiness_retention.py", "scripts/maintainer/readiness_subject.py", "scripts/maintainer/validate_exact_head_readiness.exs"]
covered_digest: "v3:sha256:7bb3fb3d426bf12efb29e88e1f0abaaaffb3dca90bc95109b74d7c5070c38770"
---
# Quick261025-nfr verification

Goal: immutable previously-main snapshot acceptance while main advances, preserving
scheduled-event proof and fresh mutable-source checks. This report covers implementation,
not actual live READY acceptance, private-source visibility or protected PR delivery.

| Contract | Fresh executable evidence |
|---|---|
| Admit actual protected-main snapshot; reject arbitrary PR/fork/old policy | identity negatives and actual immutable validator cases in test_readiness_snapshot.sh |
| Main advances during collection and refresh | actual Closure close/refresh, same immutable subject, original bytes unchanged |
| Producer SHA differs from evidence subject | actual prepare/retrieve with API/ZIP fixtures and substitution rejection |
| Terminal joins archive, refresh and validator | actual Acceptance.run and claim_status; fixture_ready only; no current credit |
| Fresh mutable authority | current ledger initialization, current authority byte collection, drift rejection, byte-bound validator replay |
| Latest attempts, scheduled proof, source visibility, cleanup | unchanged legacy rejection suites plus new cleanup and mixed-policy cases |

`bash scripts/ci/test_readiness_fixtures.sh`:345 tests,0 failures,105s under the
unchanged240s budget. This includes27 new snapshot tests and all318 original cases.
`bash scripts/ci/test_script_test_groups.sh`:8 tests,0 failures.
Actionlint passed for readiness-retention.yml; Python syntax, Elixir formatting,
Bash syntax and git diff whitespace checks passed. Automation-first contract passed.
Repo hygiene --ci:10 PASS,1 WARN (Hex.pm index unavailable),0 BLOCK.
Source hashes and local verification commit/tree are in verification.json; full
fixture/group/hygiene output is retained beside this report. Review was inline.

READY-01–05 remain Pending. No actual producer dispatch, native final qualification,
credential change, merge or publication occurred. Ordinary PR CI still owns delivery.

## CI timing repair

CI40237130793 exhausted the unchanged240s group deadline; both Quality cells passed.
The actual-validator worker is restricted to closure/snapshot test fixtures and
reloads every graph. All345 original readiness cases remain; four worker-safety
cases bring the total to349. All three actual script groups pass locally at
92.299s/49.847s/117.015s; readiness itself takes100s under the same240s bound.
Fresh CLI parity (32 closure and27 snapshot cases) compares exact verdict bytes
and exit codes. Seed139 order shuffle and A/bad-B/A state isolation pass; malformed
request, dead-worker and deadline cases stay nonpassing. The worker inherits the
suite process group so the outer deadline also disposes it between requests.
Production CLI/process lifecycle tests still run externally.

One sequential local pair is24.552s fresh versus17.253s batched for32 closure
cases. This establishes a local benefit, not GitHub wall-time or p95 acceptance.
Source commit, raw checks and hashes are in `ci-timing-repair/verification.json`;
the initial report is preserved there byte-for-byte as `initial-verification.txt`.
The old verification.json remains historical. GitHub CI on the new head remains
required before protected delivery. No retry of the unchanged timeout, timeout
increase, merge, live readiness acceptance or requirement closure occurred.

## Current-main integration review — quick261025-v8q

The original report above is historical; its exact bytes are retained in
`main-integration-review/previous-verification.txt`. Merging delivered main08872439
changed RUNNING.md and the approved CI guard, so the old fingerprint was stale.
Fresh verification covers the integrated source; no snapshot policy logic changed.

All349 readiness cases pass in127s. The actual three script groups pass in
126.801s/81.813s/146.622s under unchanged240s. Fresh CLI parity passes32 closure
and27 snapshot cases;29 lane/async cases pass. Residue scan has zero pending
entries; hygiene reports10PASS/1Hex-indexWARN/0BLOCK. Retention actionlint,
changed Python/Bash syntax and five changed Elixir formatting checks pass.

The canonical covered-input fingerprint was recomputed after these checks.
Source/evidence hashes and raw logs are retained in main-integration-review/.
Final pushed-head native CI is still required before protected delivery. Historical
fixture receipts are unchanged; no live READY, scheduled-proof or phase acceptance
credit. The separate delivery-review task owns final CI/feedback observation.
