---
phase: "137"
slug: "built-package-twin-foundation"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-21"
---

# Phase 137 — Validation Strategy

## Test Infrastructure

Existing ExUnit, Jason, shell probes and Docker Compose; no new dependency.
Config: mix.exs, test/test_helper.exs and the new external host's ordinary config.
Quick planning check: `./scripts/maintainer/automation_first_contract.sh`.
Execution quick/full commands and test paths are finalized with the plans below.
Runtime estimates are unmeasured; measure the first real run.

## Sampling Rate

Run the owning task's focused automated check before each task commit. At each
wave boundary run all available twin contract tests; before phase verification
run the real isolated tracer plus independent receipt verification and existing
CI/public-surface regression checks appropriate to the touched files.
Every stage uses a finite deadline; no watch loops or rerun-until-green.

## Per-Task Verification Map

The planner must replace this paragraph with concrete task IDs, requirement and
unique threat references, commands and pending-creation/available path status.
No execution or acceptance credit has been recorded.

## Wave 0 Requirements

Owning implementation tasks create new test files before their verify commands
run. Existing ExUnit and shell infrastructure supplies the framework. Plans must
record all new test paths and dependency order without a separate scaffolding wave.

## Manual-Only Verifications

All phase behaviors have automated verification. Credential or irreversible-action
authorization, if later needed, cannot close a TWIN requirement.

## Validation Sign-Off

- [ ] Every task has a runnable automated command and stated failure direction
- [ ] No three consecutive tasks lack an automated verification
- [ ] Every new command target has an owning creation task
- [ ] Real package/Oban/restart/cleanup tracer is required for acceptance
- [ ] No watch-mode commands or invented timing evidence
- [ ] All checks pass during execution before Nyquist compliance is claimed

Approval: pending automated execution.
