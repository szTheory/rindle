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
