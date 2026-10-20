---
phase: 136-measured-quality-and-ci-ratchets
plan: 13
status: complete
subsystem: testing
requirements-completed: [DX-05, COV-06, TYPE-03]
key-files:
  created: [.planning/phases/136-measured-quality-and-ci-ratchets/136-SUBJECT-FINAL.json, .planning/phases/136-measured-quality-and-ci-ratchets/136-COVERAGE-EVIDENCE-FINAL.json]
  modified: [scripts/maintainer/verify_contributor_bootstrap.sh, RUNNING.md, test/install_smoke/contributor_bootstrap_test.exs, test/install_smoke/phase136_measure_test.exs, test/install_smoke/coverage_floor_policy_test.exs]
coverage:
  - id: terminal-timeout-receipts
    description: Real bounded child timeout is retained and consumed as first-red without false success
    verification:
      - kind: unit
        ref: mix test test/install_smoke/contributor_bootstrap_test.exs test/install_smoke/phase136_measure_test.exs test/install_smoke/coverage_floor_policy_test.exs --seed 0
        status: pass
    human_judgment: false
  - id: final-canonical
    description: One committed final SHA owns exact count and local success on the supported runtime
    verification:
      - kind: probe
        ref: mix run scripts/maintainer/verify_coverage_floor.exs -- --verify-only --subject-file .planning/phases/136-measured-quality-and-ci-ratchets/136-SUBJECT-FINAL.json --receipt .planning/phases/136-measured-quality-and-ci-ratchets/136-COVERAGE-EVIDENCE-FINAL.json
        status: pass
    human_judgment: false
completed: 2026-10-20
---

# Phase136 Plan13: Bounded Bootstrap and Final Source

The real002b8582 clean-bootstrap attempt timed out after343.89seconds while full mix ci exceeded its300second command cap. Its setup commands all passed, but timeout discarded the running command record, causing verify-bootstrap to reject the partial history. The immutable old receipt and artifacts are committed eb30a02d without credit.

The corrected owner terminates its child group, retains bounded output/digest/duration, appends the exact timed-out argv with exit124 and failure_reason, then reports open. Output-limit failures similarly retain terminal exit125. Full mix ci alone has600seconds, setup/focused commands remain300, and execution still clamps every command to the reduce-only1200second overall deadline. No runtime, package, product implementation or coverage skip changed.

Pre-freeze review also found coverage logic fixtures depended on the host being the supported measurement cell. Disposable fixtures now explicitly supply accepted probes; a synthetic foreign-host regression passes, and an unsupported fixture owner is still rejected. Production runtime checking remains unchanged. This is fixture portability proof, not a claim that the actual older CI cell ran locally.

## Tests and commits

- Timeout/budget RED1df4ebe7; portable-fixture REDda8b5c87. Both preserved JUnit failures returned RED_EVIDENCE_OK.
- Source GREEN4dc73fa9. Combined owner, consumer, qualification, portable coverage and actual whole-tree meta owners passed60/60 in70.3seconds; live Credo, whitespace and automation-first passed.
- Controlled3second timeout demonstrates child/checkout cleanup, terminal command identity and consumer acceptance as open; a handwritten green outcome is rejected.

## Final source and single measurement

- Subject4dc73fa91c60ae870c7289a151d9d53460140906, tree7914e96ccfe3420a453f81e34066c88912691602.
- Exactly one canonical local+JSON invocation on this subject, exit0:3doctests,1695tests,zero failures,87excluded,4skipped,338.4seconds.
- Supported actual Elixir1.17.3/OTP27.3.4.15/Node20.18.1. Local minimum82.2 passed. Exact JSON5206/6329=82.25628061305103percent passes82.1343floor.
- Raw artifactSHA256a9357899e8c2ad8615921485dd55ec033b193487a7c3ea101095e16f51a4f6a1. Receipt retains raw JSON and local output. Prescribed verify-only and source-projection commands both returned complete without a suite.
- Earlier remediated coverage and timed-out bootstrap receipts are byte-identical to their committed historical versions. No prior target was overwritten.

## Readiness

Source is frozen at FINAL. Plan09 must recollect Dialyzer and bootstrap into136-DIALYZER-EVIDENCE-FINAL.json and136-BOOTSTRAP-EVIDENCE-FINAL.json, then run the still-unrun25seed experiment. Qualification generation must explicitly select FINAL pin, coverage, Dialyzer and bootstrap paths; default legacy files name older subjects and must not receive credit. Live PR timing requires a published exact-SHA PR or separately authorized publication. All seven requirement statuses remain Pending until the final qualification recomputes their actual authorities. No remote publication occurred.

## Self-Check: PASSED
