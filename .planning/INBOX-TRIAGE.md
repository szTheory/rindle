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
That review preserved the then-selected968113aa snapshot. A ledger-only
main advance preserves compatible control bytes. The subsequent Bandit security
repair below requires a repaired candidate and its own actual scheduled proof.
Fresh complete live collection is still required after landing;
this table, PR approvals and green implementation fixtures grant no READY credit.

PR180 merged at2026-10-26T17:23:26Z asa1be562599c770789bce313812b938b90c2b78e4. Main push CI must finish green before the next merge.

PR190's own ledger row specifies a conditional post-landing state (`closed`,
`merged: true`). It is not a current merge receipt: the live validator must reject
that row while190 is open. Only a fresh individual lookup after its protected
landing can satisfy it. This avoids embedding the commit's own SHA into itself
and adds no policy exemption or approval-based readiness credit.


## 2026-10-26 Bandit security and readiness prerequisite repair

The maintainer requested prerequisite repair before resuming 139-07.
Protected [PR #191](https://github.com/szTheory/rindle/pull/191) changed only the
adoption demo's Bandit lock tuple from 1.13.1 to 1.14.0. All transitive tuples,
the root lock, manifests and 17 readiness control files are unchanged. Its full
PR CI 40388240821 passed before squash `30ca1aeb4a6a02234729dc724f97065d102b36c9`.
First-attempt push-main CI 40390405720 then passed 22 jobs, with the expected
Mux soak skip. The production dependency landing collector returned `pass` on
that exact merge, attributed only Bandit, and passed the supported-toolchain,
public-contract and package-consumer gates. The ledger binds the actual run and
baseline 40371876552; the historical twin literal grants no new credit.

A fresh production signed-registry audit of the repaired 49-package demo lock
reports no advisory or retired package. The 11 new Bandit advisory records name
the vulnerable 1.13.1 lock and fixed 1.14.0 release and are resolved against this
repaired source. A negative control using the retained old inventory still
rejects all 11 resolved declarations against `968113aa`. No old receipt changed
and no Bandit exception or ignore was added. All older exceptions and landing
records remain intact. Native demo precommit and final tests each pass 44 tests.

Retain rolling [release-drift issue #186](https://github.com/szTheory/rindle/issues/186)
with the existing `observe-retained-issue-v1` policy. The current drift query
finds open Release Please PR #185, which remains intentionally held. The ordinary
drift workflow owns eventual issue closure; an absent issue requires a fresh
individual completed-issue lookup. This grants no resolution, credential,
publication or READY credit and preserves the original incident run 40288396231.

The immutable `968113aa` candidate contains the vulnerable lock and stays historical.
Select a repaired actual-main snapshot after this prerequisite train, recheck
its complete live sources, and obtain its own real scheduled Nightly. Manual
feedback or a scheduled receipt on the older subject cannot supply that proof.
Keep PR #189 draft and unmerged until successful validated Phase 139 acceptance.
READY-01–05, independent pilots, deferred numeric speed, and historical verification
debt stay unchanged. This repair creates no 139-07-SUMMARY or acceptance producer.
