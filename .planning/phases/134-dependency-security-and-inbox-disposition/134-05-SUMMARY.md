---
phase: 134-dependency-security-and-inbox-disposition
plan: 05
subsystem: deps
tags: [dependabot, mix.lock, landings, advisories]
status: complete

requires:
  - phase: 134-04
    provides: landing loop, dep_landing_evidence.sh, offline validator
provides:
  - ".planning/INBOX-LEDGER.json: landings[] for #123, #113, #129, #109, #105, #112 (all evidence exit 0 on their own main push run)"
affects: [134-06]

requirements-completed: []
requirements-advanced: [DEPS-01, SEC-09, INBOX-02]
---

# Plan 134-05 Summary: batch B landings

All merges were user-run squash merges pinned with `--match-head-commit` (D-134-05). Each landing record comes from
`dep_landing_evidence.sh` on the merge SHA's own main push run, verdict `pass`, gates supported_toolchain,
public_contract and package_consumer all `pass`.

| Entry | PR | Squash SHA | Main run | Lock delta | Notes |
|-------|----|------------|----------|------------|-------|
| image (carried from 04) | #123 | f05f52ce | 38834034396 | color, image, vix | first own-run landing record |
| actions (carried from 04) | #113 | 346754fe | 38836352011 | none (workflows only) | |
| B5 demo-advisories | #129 | be7ac7e2 | 38838770800 (attempt 2) | decimal, hpax, lazy_html, mint (demo lock) | attempt 1 red only in Package Consumer Full mux: ffmpeg subprocess timeout in the generated app, which never reads the demo lock |
| B3 ex_aws | #109 | 588dd259 | 38841683010 (attempt 2) | ex_aws | Dependabot-rebased; delta shrank to ex_aws (req/mint already on main); attempt 1 red only at mux-lane `deps.get` (Hex registry `:timeout`) |
| B1 ecto_sql | #105 | b5e66259 | 38844854765 | ecto, ecto_sql | |
| B4 dev-dependencies | #112 | f5ae9442 | 38847763013 | credo, dialyxir, earmark_parser, erlex, ex_doc, ex_machina, lazy_html, makeup, mox | Dependabot-rebased after #105; no decimal, ecto or ecto_sql |

B2 (req) landed in 04 as #122 (supersedes #108); see its item rationale.

## Deviations

- Order: #109 landed before #105 because it was green first; B3's only precondition (req on main) held.
- cowlib (#128) closed: every fixed cowlib release (2.20.0, 2.21.0) uses the OTP 27 `maybe` expression and fails to
  compile on the supported OTP 26 lane. The three root cowlib advisories are carried as a dated exception
  (expires 2027-01-15); cowlib is test-only via bypass.
- Two main runs needed a single failed-job rerun for infrastructure flakes unrelated to the landed lock (see table).

## Audits after #112 (origin/main f5ae9442)

- Root `mix hex.audit`: cowlib 2.19.0 EEF-CVE-2026-43971 / 43966 / 43969 only (ledger exception).
- Demo `mix hex.audit`: bandit 1.12.5 EEF-CVE-2026-105659 (HIGH) / 105660 (MEDIUM) only. Both are fixed in bandit
  1.13.0; the demo bump is PR #130 (Plan 06).
