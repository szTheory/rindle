---
quick_id: 261025-nfr
status: complete
execution: inline
subsystem: readiness-acceptance
tags: [snapshot, evidence, ci]
key-files:
  - scripts/maintainer/readiness_subject.py
  - scripts/maintainer/readiness_acceptance.py
  - scripts/ci/test_readiness_snapshot.py
live_readiness_acceptance: pending
---
# Immutable snapshot acceptance implementation

Implemented opt-in `--snapshot --subject FULL_SHA` with rindle-snapshot-v2 policy.
Candidate admission authenticates protected-main ancestry, actual push-main provenance
and matching executing controller/policy bytes. Local qualification, collectors,
closure and refresh keep that candidate fixed while main advances. Fresh current-main
ledger, inventories, protection and authoritative adoption/release inputs remain required.

Retention admits with trusted main code before candidate checkout and separately binds
producer-head and evidence-subject SHA in v2 sidecar/locator. Terminal and claim inspection
keep snapshot readiness historical; no current-head, independent-pilot or publication
credit transfers. Legacy current-main mode and all failure/evidence gates remain distinct.

345 readiness fixtures passed in105s (240s budget);27 new moving-main scenarios exercise
actual validator, closure, refresh, retrieval and terminal joins. All318 original cases
and8 CI group-runner cases pass. Formatting/syntax, workflow lint, automation contract
and hygiene checks passed (one unavailable Hex-index warning). Detailed verification,
source hashes, logs and resolved review findings are retained in this directory.

The user selected All clear after invoking --full. Research, planning, code review and
verification ran inline, honoring the active execution boundary. All source owners form
one atomic feature commit because partial propagation would yield mixed identity policies.
No new dependency, new milestone, live acceptance, credential change, merge or publication.

Source implementation commit:e285e9d0. READY-01–05 and139-07 remain open; this quick task
closes only implementation. Next: ordinary protected PR delivery, then select a candidate
containing this policy with actual full CI and scheduled Nightly proof. Main need not freeze.
