---
phase: 136-measured-quality-and-ci-ratchets
plan: 12
status: complete
subsystem: testing
requirements-completed: [COV-06, CI-15]
key-files:
  created: [test/rindle/processor/av/output_probe_test.exs, .planning/phases/136-measured-quality-and-ci-ratchets/136-SUBJECT-REMEDIATED.json, .planning/phases/136-measured-quality-and-ci-ratchets/136-COVERAGE-EVIDENCE-REMEDIATED.json]
coverage:
  - id: repository-integration-guards
    description: Existing whole-tree async safety and exact residue owners, plus waveform postconditions
    verification:
      - kind: unit
        ref: mix test test/async_safety_guard_test.exs test/install_smoke/live_residue_scan_test.exs test/rindle/processor/av/output_probe_test.exs --seed 0
        status: pass
    human_judgment: false
  - id: replacement-canonical
    description: Distinct immutable SHA owns one supported local+JSON run and exact count receipt
    verification:
      - kind: probe
        ref: mix run scripts/maintainer/verify_coverage_floor.exs -- --verify-only --subject-file .planning/phases/136-measured-quality-and-ci-ratchets/136-SUBJECT-REMEDIATED.json --receipt .planning/phases/136-measured-quality-and-ci-ratchets/136-COVERAGE-EVIDENCE-REMEDIATED.json
        status: pass
    human_judgment: false
completed: 2026-10-20
---

# Phase136 Plan12: Repaired Candidate and Exact Coverage

The original first-red attempt is complete and immutable. Its subject, receipt and two raw evidence files remain byte-identical to2b9cecd4. This separately planned candidate fixes the exposed repository integration failures without changing product code, coverage skips, runtime files or packages.

Four file-mutating fixture modules now run synchronously. Existing primitive detection remains unchanged. The repository residue owner regenerated exact shards; new executable/schema identifiers, confined evidence paths and pinned upstream images received reviewed policy/fixture explanations. One incidental helper docstring reference was removed. No scanner exclusion was broadened, and no pending-removal entries remain.

Two test-only waveform characterizations verify requested length, mismatch error payloads, missing file propagation and malformed JSON rejection. This adds real output-validation coverage while retaining the same6329relevant lines. The initial focused meta RED was34tests/3failures and accepted as RED_EVIDENCE_OK. After repair, actual meta owners and waveform tests passed36/36; live Credo and automation-first passed.

## Commits and exact measurement

- RED/explicit gap plan2dad05b2; source repair002b8582.
- New subject002b85822b4df4ecd48814cd28ba46d1cf7b24f6, treed85051a28d3d56262ae5000395711b450b0cf2bc.
- Exactly one canonical invocation on this candidate, actual exit0:3doctests,1693tests,0failures,87excluded,4skipped,279.0seconds.
- Accepted host Elixir1.17.3/OTP27.3.4.15/Node20.18.1. Local gate82.2 passes. Same-run JSON has5206covered/6329relevant =82.25628061305103percent, above exact82.1343floor.
- ArtifactSHA256b16f63af3c67bedd9a54e29bef6126737f11f531a7f222047b80d0a931f73e88; raw JSON and local output are retained inside the immutable receipt.
- The prescribed mix-run verify-only command returns complete without a suite. Source projection returns complete; original-evidence byte comparison passes.

## Readiness

All executable source is now frozen at the replacement subject. Plans09/07 explicitly use136-SUBJECT-REMEDIATED.json; qualification generation must pass --coverage136-COVERAGE-EVIDENCE-REMEDIATED.json. Later commits may contain planning evidence only. Remaining real collectors and live timing have not run, so no overall qualification or remote publication is claimed. All seven requirement statuses remain Pending until their final authorities are recomputed.

## Self-Check: PASSED
