---
phase: 136-measured-quality-and-ci-ratchets
plan: 06
status: complete
subsystem: documentation
tags: [bootstrap, contributor, verification]
requires:
  - phase: 136-05
    provides: Current input and CI policy
provides:
  - Executable clean supported bootstrap with private homes and bounded cleanup
  - Focused/full/nightly/measurement/release command map
affects: [136-final-bootstrap-evidence]
tech-stack:
  added: []
  patterns: [documentation-driven ordered commands, clean detached copies]
key-files:
  created: [scripts/maintainer/verify_contributor_bootstrap.sh, test/install_smoke/contributor_bootstrap_test.exs]
  modified: [CONTRIBUTING.md, RUNNING.md]
key-decisions:
  - Preserve .tool-versions; explicitly select accepted Elixir/OTP patch and actual CI Node 20.
  - Parse and execute the documented bootstrap commands through a reviewed argv allowlist without shell evaluation.
  - Full mode executes mix ci after focused bootstrap; fixtures grant no final DX-05 credit.
requirements-completed: [DX-05]
coverage:
  - id: contributor-bootstrap
    description: Clean detached bootstrap and full PR command path with refusal and cleanup controls
    verification:
      - kind: unit
        ref: mix test test/install_smoke/contributor_bootstrap_test.exs --seed 0
        status: pass
    human_judgment: false
duration: 10min
completed: 2026-10-20
---

# Phase 136 Plan 06: Tested Contributor Bootstrap

Contributors have an ordered supported setup and copyable lane map independent of workflow archaeology. The probe parses the documented argv, checks exact accepted Elixir 1.17.3 / OTP 27.3.4.15 and CI Node 20, rejects dirty/foreign source, creates a private no-hardlink detached clone, installs existing tools/locked dependencies, and executes focused tests plus optional mix ci.

## Accomplishments

- Private Mix/Hex homes and clean build/deps directories prevent shared scratch artifacts from standing in for a clean checkout.
- Twenty-minute overall, five-minute per-command and four-MiB output bounds; callers may only reduce the overall deadline. Timeout kills the owned child process group and removes the disposable copy.
- New receipts only, exact SHA/tree/runtime, argv/exit/output digests and explicit complete/open/blocked outcomes with next triggers.
- Ten contributor map entries cover complexity, CI policy, fresh/restored type analysis, one canonical coverage command, safe async matrix declaration, separate finite experiment, full mix ci and release-only hygiene. Tests invoke Mix help or safe owner validation and bind Node to parsed current CI setup.

## Task Commits

1. RED d98c2915; GREEN d391e2b1 — clean focused path.
2. RED af2dee04; GREEN 9be9befe — full verification, command map and failure/timeout coverage.

## Verification

- Supported local Elixir/OTP and installed Node 20.18.1: 6 tests, 0 failures (7.9 seconds).
- Includes focused/full order, wrong Elixir/OTP/Node refusal before Mix, dirty source, first failed command, immutable receipt reuse, executable command owners and actual timeout cleanup.
- Both preserved JUnit RED reports returned RED_EVIDENCE_OK.
- Live Credo, Bash syntax and whitespace passed.
- All bootstrap installation/compile/test activity in this plan used explicit fake-command fixtures. Real supported clean execution is Plan 09; DX-05 remains Pending.

## Deviations

Current PATH selects Node 26 despite the repo hint. Installed Node 20.18.1 was selected explicitly for CI parity; no runtime installation, project package addition or .tool-versions edit. Probe timeout override is reduce-only and exists to exercise finite cleanup without waiting twenty minutes in fixtures.

## Issues Encountered

None outstanding for implementation.

## Next Phase Readiness

Wave 2 complete. Plan 10 can wrap this probe's --run --full and --receipt contract inside the frozen-source collector.

## Self-Check: PASSED
