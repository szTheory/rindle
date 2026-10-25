---
quick_id: 261025-grp
status: passed
verified: 2026-10-25
mode: inline
---

Goal verified for the bounded compatibility fix, not overall project readiness.

| Must-have | Executable evidence | Result |
|---|---|---|
| Valid old/new cache identity | Real Hex 2.6.0 writer/reader plus verified legacy ETS regression | Passed |
| Reject missing/corrupt/unsupported inputs | 7 persisted-cache seam regressions | Passed |
| Preserve online/TLS/signature, lock and retirement gates | 68 validator/cache and 69 remote fixtures, both reviewed versions | Passed |
| Preserve broader readiness/security acceptance | All eight readiness suites: 317 tests, 74s, exit 0 | Passed |
| Use isolated pinned fixture tooling | Fresh prepare_readiness_fixture_runtime.sh run; 68-test repeat | Passed |
| Exercise actual supported runtime | Elixir 1.17.3 / OTP 27.3.4.15; live Hex 2.6.0 root/demo audit snapshots | Passed |
| Exercise complete read-only collector | Current-main invocation stops at pull_undispositioned, requirements_credit false | Gate correctly refuses |
| Maintain repository policy | automation_first_contract.sh, formatting, shell syntax and git diff --check | Passed |

The root audit's advisory exit remains 1; demo exit remains 0. The remote collector refuses unresolved dispositions before reaching its live Hex stage. Separate actual root/demo audits prove the fixed live snapshot seam. Local probes use the modified helper against main's immutable lock bytes; they are diagnostic evidence, not final-subject qualification. Required GitHub CI remains the PR merge authority.

Inline plan check (iteration 1): requirement coverage, three-task scope, file links, executable acceptance and security invariants passed. GSD verify-command path probe reported zero blockers/warnings. User explicitly requested inline execution; no agents or delegated worktrees used.

Reviewed official source semantics:
- https://github.com/hexpm/hex/blob/v2.5.1/lib/hex/registry/server.ex (verified ETS persistence)
- https://github.com/hexpm/hex/blob/v2.6.0/lib/hex/registry/server.ex (native header/CRC, read_cache/1 and write_cache/2)
