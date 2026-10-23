## Summary

The configured coverage gate allowed 69% while accepted coverage was 82.1343%, and maintainer evidence could become detached from its source. This change enforces removal-only Credo complexity with behavior proof, exact-count coverage with a conservative 82.2% local gate, narrow Dialyzer suppressions, and immutable source/runtime-bound measurements. CI consumers verify pinned FFmpeg, MinIO client and Playwright inputs; parsed mutation tests cover job timeouts, fork safety, the sole CI Summary context and exact-SHA release gating. Contributors receive a tested clean-bootstrap command map.

The frozen candidate is `e2d3b5c759e38c79744a1ef9bade8b6f2d92a2f9`. Retained command output now uses `.txt` artifacts, keeping repository junk rules intact. All 31 historical outputs were relocated byte-for-byte; existing receipts retain their original bytes and hashes, and the verifier checks relocated legacy output without bypassing symlink or digest checks. Python maintainer source belongs to the existing maintainer artifact class.

The Proof lane hit its existing 15-minute ceiling twice while sequential Nightly harness assertions were passing. Four isolated harnesses now overlap within the same job; it waits for every child and fails if any fails. The timeout, assertions, job dependencies and required context are unchanged.

## Linked Issue

Phase 136 — Measured Quality and CI Ratchets.

## Validation

- Supported measurement host: Elixir 1.17.3 / OTP 27.3.4.15 / Node 20.18.1.
- Final repair owner/meta/topology suite: 104 tests, zero failures; focused policy/topology suite: 39 tests, zero failures. Tests execute the parsed YAML body and cover overlap plus each failing harness.
- Actual Nightly harness comparison: sequential 94.292 seconds, parallel 66.352 seconds (29.6% less local wall time for this step). This is not a claim about full live CI duration.
- Artifact-ledger shell harness: 58 passed, zero failed, including archive simulation and live repository partition.
- Repository Credo gate passed; all 31 output relocations and 38 unchanged receipt JSON hashes verified.
- Earlier frozen source `4fdd3fba` canonical run: 1,698 tests and 3 doctests, zero failures; exact 5,206/6,329 = 82.2563% coverage. Local gate and source-bound receipt verification passed.
- Live CI Script Tests passed, including artifact-ledger validation, archive simulation and repository hygiene.
- Fresh/restored Dialyzer passed in 55.331/3.047 seconds. Clean full bootstrap passed all six commands in 379.476 seconds; mix ci passed in 331.833 seconds.
- Prior-phase regression passed 226 tests with zero failures; the replacement fixed 25-seed experiment completed with every seed green and its receipt verified.
- Earlier-source qualification has six complete authorities and blocked CI-16 timing. All measurements remain bound to their original source; they are not relabeled for the final harness repair.
- Explicit maintainer decision: defer the ten-run ≤8-minute median / ≤10-minute p95 target unfinished to SEED-261021-918. It receives no speed acceptance credit and is no longer a merge gate. Required GitHub CI must be green on this exact head before the authorized squash merge.
- The earlier source completed its 25-seed matrix, but its measurements are retained as historical evidence and receive no replacement-source qualification credit.

## Checklist

- [ ] Required GitHub CI is green on the final repair head (pending live run).
- [x] Docs are updated when behavior, setup, or contributor workflow changes.
- [x] Docs-only changes do not alter `lib/` behavior.
- [x] Security reports are routed through GitHub advisories, not public issues.
