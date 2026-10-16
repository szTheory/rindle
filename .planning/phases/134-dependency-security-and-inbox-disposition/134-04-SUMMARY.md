---
phase: 134-dependency-security-and-inbox-disposition
plan: 04
subsystem: deps
tags: [dependabot, mix.lock, landings, advisories, tooling]
status: complete

requires:
  - phase: 134-03
    provides: inbox collector, ledger validator, dep_landing_evidence.sh
provides:
  - "Phase 134 tooling on main (#121): collect_inbox.sh, validate_inbox_ledger.sh, dep_landing_evidence.sh"
  - ".planning/INBOX-LEDGER.json: terminal items for batch A (#121, #122, #124, #125, #128, #120) and the A4/A5 replacement by #122"
affects: [134-05, 134-06]

requirements-completed: []
requirements-advanced: [DEPS-01, SEC-09, INBOX-02]
---

# Plan 134-04 Summary: batch A landings

Merges were user-run squash merges (D-134-05). Batch A did not go as queued: a third-party release broke main right
after the tooling PR, two queue entries were replaced by a Dependabot PR, and cowlib could not land at all.

| Entry | PR | Squash SHA | Outcome |
|-------|----|------------|---------|
| A1 tooling | #121 | 9de67304 | Own main run 38790714484 red in the Package Consumer Full tus lane on both attempts. Cause: Bandit 1.13.0 (released 2026-10-15T18:36Z, resolved unpinned by the generated smoke app) raises when a response uses the conn from before `read_body`. No landings[] record; the first green main run containing #121 is 38803539002. |
| incident fix | #124 | 40e9cbf3 | `fix:` threading the post-`read_body` conn through tus PATCH and the webhook fallback; main run 38803539002 green including Package Consumer Full tus. Cut release 0.4.8 (#125), which is expected for a `fix:` and is not a dependency landing. |
| A2 actions | #113 | 346754fe | Landed after #121's SHA-literal test decoupling; landing record written in 05 from its own run 38836352011. |
| A3 cowlib | #128 | closed | Every fixed cowlib release (2.20.0, 2.21.0) uses the OTP 27 `maybe` expression and fails to compile on the supported OTP 26 lane. The three cowlib advisories are carried as a dated exception (expires 2027-01-15); cowlib is test-only via bypass. |
| A4 mint, A5 decimal | #122 | da637439 | Replaced by Dependabot's req 0.7.5 PR, whose delta already carried mint 1.11.0 and decimal 3.2.0 (group req, decimal, finch, hpax, mint). Its own main run 38809962966 went red only at the hex-baseline hygiene BLOCK (the 0.4.8 publish race, todo 2026-10-15-hygiene-baseline-publish-race), so there is no landings[] record; descendant run 38828155392 on dc75ab83 (no mix.exs, mix.lock or lib/ change since) passes all three gates in baseline mode. |
| external gate | #120 | ae08818a | Branch-protection guard that looks past head commits which skipped CI; user-merged outside the queue. |

Root `mix hex.audit` after #122 reports no mint or decimal advisory ids; the ledger marks them resolved. The demo
lock's mint and decimal advisories landed in 05 (#129).

## Deviations

- A1 needed an out-of-queue incident fix (#124) and a release (#125) before any further landing could be credited.
  D-134-08 ("no release PR after a landing") still held for every dependency landing.
- A4 and A5 were never opened as maintainer lock-only PRs; #122 subsumed them.
- A3 ended as a close plus a dated exception instead of a landing.
- Ledger commits were landed by planning PR #127.
