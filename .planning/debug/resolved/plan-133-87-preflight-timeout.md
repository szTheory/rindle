---
status: resolved
trigger: >-
  Plan 133-87 preflight timeout: diagnose and fix the 60-second ExUnit timeout in test rejects drift in immutable halted Plan 55 identity and report digests, at assert_invalid/3. Keep Plan 87 halted, do not invoke phase_133_local_gates.sh or reuse SHA 87572a019636ba1367c0c7245ae5cb89d0ea1909 for qualification, and preserve all five requirements as pending.
created: 2026-10-05
updated: 2026-10-05
---

# Debug Session: Plan 133-87 preflight timeout

## Symptoms

- **Expected:** The Plan 133-87 focused preflight test rejects drift in the immutable halted Plan 55 identity and report digests, returns promptly, and allows diagnosis of the failure without qualifying Plan 87.
- **Actual:** The focused ExUnit run hit the 60-second `ExUnit.TimeoutError` in `test rejects drift in immutable halted Plan 55 identity and report digests` at `test/install_smoke/phase_133_reconciliation_test.exs:1489`, through nested helper `assert_invalid/3` at line 4104. The suite was interrupted before its aggregate summary or exit status.
- **Error:** `ExUnit.TimeoutError` after 60 seconds; no terminal ExUnit summary was produced.
- **Timeline:** Recorded during the Plan 87 preflight. The subsequent full-suite attempt also exited with a shutdown and no terminal summary; treat it as incomplete, not green.
- **Reproduction:** The recorded focused invocation was `ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 MIX_ENV=test mix test test/install_smoke/phase_133_reconciliation_test.exs --seed 0`.

## Constraints

- Keep Plan 87 halted and all five requirements pending.
- Do not invoke `phase_133_local_gates.sh`.
- Do not reuse SHA `87572a019636ba1367c0c7245ae5cb89d0ea1909` for qualification.
- Do not treat the interrupted full-suite run as passing evidence.

## Current Focus

- **hypothesis:** Confirmed: the immutable Plan 55 drift test exceeded its default 60-second ExUnit timeout because its serialized mutation matrix repeatedly starts the complete Mix validator; the baseline test runtime was 51 seconds.
- **test:** Raised only this test's timeout to 120 seconds and reran the line-filtered focused test command.
- **expecting:** The focused command completes with zero failures while keeping Plan 55 halted and all five requirements pending.
- **next_action:** Session archived after user accepted the focused regression result and directed resolution; Plan 87 remains halted and no qualification lane was run.

## Resolution

- **root_cause:** The test exceeded ExUnit's default 60-second per-test timeout due to its serialized matrix of 14 validator subprocess runs; the individual test measured 51,072.8 ms before the fix, leaving insufficient headroom for runtime variation.
- **fix:** Added an explicit 120,000 ms timeout to the one high-cost test; assertions and validator behavior are unchanged.
- **verification:** Focused location-filtered ExUnit run exited 0: 80 discovered, 78 excluded, 0 failures, 32.7 seconds total. Plan 55 summary remains `status: halted`, `qualification: blocked`, and `requirements-completed: []`; EVID-01 through EVID-04 and TRUTH-08 remain unchecked. Full suite and qualification were not run.
- **files_changed:** `test/install_smoke/phase_133_reconciliation_test.exs`
- **oracle_type:** specified (original test timeout symptom and focused ExUnit command exit status)
- **guardrail_verdict:** accepted (focused test passes; exact target timeout now 120 seconds; no validator or requirement-state changes)

## Prevention

- **Blameless causal branches:**
  - **Code:** The test's serialized negative-case matrix launches 14 fresh validator subprocesses. That execution shape makes it a long-running integration test even though each individual validator invocation succeeds.
  - **Environment:** Machine and filesystem contention can add enough variance to push the roughly 51-second baseline beyond ExUnit's default 60-second deadline.
  - **AND-gate:** Both the high subprocess count and runtime variance can contribute; either may be enough on a sufficiently slow run, so the guard gives this specific test adequate headroom.
- **Why not caught:** No gate existed for setting a timeout budget proportional to this test's known worst-case runtime; the default timeout only reported the overrun after it occurred.
- **Recurrence guard:** The test-local `@tag timeout: 120_000` on `test/install_smoke/phase_133_reconciliation_test.exs` gives this matrix headroom. The focused location-filtered run passed after the change.

reasoning_checkpoint:
  hypothesis: "The Plan 55 drift test intermittently times out because it performs 14 full validator subprocess invocations and each invocation builds a completed-57 fixture; the test's default ExUnit timeout is 60 seconds while the isolated test itself takes about 51 seconds."
  confirming_evidence:
    - "ExUnit trace measured the target test at 51072.8ms on the exact location-filtered run."
    - "The test enumerates 14 mutations and calls assert_invalid/2 for each, which invokes System.cmd('mix', ['run', ...]) anew."
  falsification_test: "After an explicit 120-second timeout is applied, rerun this exact test and verify it completes with zero failures; if it still stops around 60 seconds, the timeout diagnosis is wrong."
  fix_rationale: "A targeted timeout annotation gives the already-intended exhaustive negative cases enough budget while preserving all assertions and production behavior."
  blind_spots: "Timing may vary with machine load; this run establishes current cost but does not measure worst-case slow environments or the full suite."
  candidate_causes:
    - "code: the test executes 14 separate full-validator subprocesses and repeatedly materializes Git-backed fixture trees."
    - "environment: scheduler or filesystem contention can push an approximately 51-second isolated test past ExUnit's default 60-second timeout."
  and_gate: "yes — timeout occurs when the expensive serialized test path and enough runtime contention jointly exceed the default per-test deadline."

## Evidence

- **timestamp:** 2026-10-05
  **checked:** Ran `mix test test/install_smoke/phase_133_reconciliation_test.exs:1489 --seed 0` with the recorded Erlang/Elixir versions.
  **found:** Location filter completed with exit 0 in 57.20 seconds total (ExUnit reported 50.9 seconds), 80 tests discovered, 78 excluded, 0 failures. Two dots were emitted, so the line filter selected two cases.
  **implication:** The exact filtered run currently passes but runs close to the reported 60-second timeout. A slower full-file run can plausibly exceed the per-test timeout; this supports accumulated work as a lead, not yet a confirmed root cause.

- **timestamp:** 2026-10-05
  **checked:** Re-ran the target line with `--trace` to measure the individual test rather than its location-filtered group.
  **found:** The exact target test alone took 51,072.8 ms. The source lists 14 independent summary mutations, each passed through `assert_invalid/2` and a fresh `mix run` validator subprocess.
  **implication:** The test is intrinsically close to ExUnit's default 60-second timeout before accounting for runtime variance. The timeout is test-budget configuration, not a validator hang; a test-local timeout adjustment addresses the cause without relaxing validation assertions.

- **timestamp:** 2026-10-05
  **checked:** Reran `mix test test/install_smoke/phase_133_reconciliation_test.exs:1489 --seed 0` after the test-local timeout adjustment.
  **found:** Exit 0; 80 tests discovered, 78 excluded, 0 failures, reported runtime 32.7 seconds.
  **implication:** The focused test path is green after the timeout adjustment. This is regression evidence only and does not qualify Plan 87.
