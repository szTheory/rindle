# Inbox Triage

Superseded on 2026-10-15 by [`.planning/INBOX-LEDGER.json`](INBOX-LEDGER.json), the machine-checked
disposition ledger (schema `rindle-inbox-ledger-v1`).

- Dispositions, advisory records, source records and landing records live only in the ledger.
- `scripts/maintainer/collect_inbox.sh` collects a fresh read-only inventory of open issues, PRs and
  advisory sources; `scripts/maintainer/validate_inbox_ledger.sh --inventory FILE --ledger
  .planning/INBOX-LEDGER.json` accepts the ledger only when every open item has exactly one
  disposition and every advisory finding is accounted for.
- `validate_inbox_ledger.sh --offline` checks shape only and runs in the merge-blocking
  `ci-script-tests` job; live and clock-dependent validation runs from a maintainer machine.
- The 2026-08-28 triage table is kept in git history.

## 2026-10-26 scoped PR review

This dated review explains the executable ledger's dispositions; the ledger remains
the sole disposition authority. The maintainer authorized triage and protected
squash merges after green CI. PR189's earlier acceptance hold remains in effect.
The five scoped PRs were reviewed against the actual Rindle default PR template,
CONTRIBUTING.md and release/readiness ownership. The GSD upstream typed templates,
approval labels and changeset convention are absent here and impose no new gate.
Bot release/dependency bodies identify their changes; no artificial missing-issue
or template gate replaces the repository's actual CI and policy requirements.

| PR | Review and executable disposition | Evidence / next gate |
|---|---|---|
| [180](https://github.com/szTheory/rindle/pull/180) | Merged by the existing guarded squash owner asa1be5625 after full green CI40366144902 on refreshed heada53c1421; publication was already complete. | Publish/public_verify jobs in40220786199 passed; the aggregate failed only at the later baseline owner. Exact release CI40220783864 passed. Old PR CI40224357301 hit the240-second harness budget; refreshed a53c1421 includes current main's subsequent harness improvements. |
| [185](https://github.com/szTheory/rindle/pull/185) | Retain Release Please's0.4.14 intent with `do-not-merge`. | Three expected version/changelog files; CI40263479602 failed Script Tests. No release/publication dispatch is authorized by this triage. Reconsider after validated139 acceptance and fresh CI. |
| [187](https://github.com/szTheory/rindle/pull/187) | Retain the dependency candidate for a bounded compatibility repair. | CI40320385984 failed both Elixir1.15/OTP26 compilation paths: cowlib2.21 uses syntax rejected by OTP26; phoenix_template1.1 also requires Elixir~>1.16. The seven-package delta is broader than its LiveView-only title. Require compatible locked transitive versions and exact-head CI; do not widen support. |
| [188](https://github.com/szTheory/rindle/pull/188) | Retain and `do-not-merge` during snapshot acceptance. | setup-beam1.24.1 changes both ci.yml and producer readiness-retention.yml (CONTROL_PATHS). CI40320421560 failed both Quality cells on exact residue allowance/regeneration drift. Repair narrowly after acceptance or explicitly replace the candidate and scheduled proof. |
| [189](https://github.com/szTheory/rindle/pull/189) | Retain draft with `do-not-merge`, despite green CI. | CI40354516652 and CI Summary passed on8699c2c5. Validator semantic-pin change modifies CONTROL_PATHS. Merge requires successful validated139 acceptance or an explicit owner candidate replacement with compatible actual scheduled proof. |

Old PR144 is actually closed/unmerged and replaced by187. Its terminal record is
reconciled from a fresh individual lookup; retained145/146 heads remain unchanged.
No debt, requirement, exception or original failed receipt is cleared by triage.
The readiness subject stays968113aa2bb73bc5180fbba59a0da5b4a13e6d60. A ledger-only
main advance preserves compatible control bytes and does not reset its existing
scheduled proof. Fresh complete live collection is still required after landing;
this table, PR approvals and green implementation fixtures grant no READY credit.

PR180 merged at2026-10-26T17:23:26Z asa1be562599c770789bce313812b938b90c2b78e4. Main push CI must finish green before the next merge.
