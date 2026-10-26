---
status: passed
verification_mode: inline
scope: implementation-fixtures
covered_files: [".github/workflows/readiness-retention.yml", ".planning/quick/261025-nfr-implement-immutable-snapshot-readiness-a/261025-nfr-PLAN.md", ".planning/quick/261025-nfr-implement-immutable-snapshot-readiness-a/261025-nfr-SUMMARY.md", "RUNNING.md", "guides/readiness_evidence.md", "scripts/ci/readiness_fixture.exs", "scripts/ci/test_readiness_fixtures.sh", "scripts/ci/test_readiness_snapshot.py", "scripts/ci/test_readiness_snapshot.sh", "scripts/maintainer/collect_readiness_remote.py", "scripts/maintainer/collect_readiness_runs.py", "scripts/maintainer/exact_head_readiness.py", "scripts/maintainer/readiness_acceptance.py", "scripts/maintainer/readiness_adoption.py", "scripts/maintainer/readiness_closure.py", "scripts/maintainer/readiness_retention.py", "scripts/maintainer/readiness_subject.py", "scripts/maintainer/validate_exact_head_readiness.exs"]
covered_digest: "v3:sha256:464390c018c6b41b5f39089b3696a7e8201ed8913c3a69bcccd67afe724e42e4"
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
