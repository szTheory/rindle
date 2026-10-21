## Summary

The configured coverage gate allowed 69% while accepted coverage was 82.1343%, and maintainer evidence could become detached from its source. This change enforces removal-only Credo complexity with behavior proof, exact-count coverage with a conservative 82.2% local gate, narrow Dialyzer suppressions, and immutable source/runtime-bound measurements. CI consumers verify pinned FFmpeg, MinIO client and Playwright inputs; parsed mutation tests cover job timeouts, fork safety, the sole CI Summary context and exact-SHA release gating. Contributors receive a tested clean-bootstrap command map.

The frozen candidate is `4fdd3fba5ef5bc73be52473bc72de03fe56926d4`. Retained command output now uses `.txt` artifacts, keeping repository junk rules intact. All 31 historical outputs were relocated byte-for-byte; existing receipts retain their original bytes and hashes, and the verifier checks relocated legacy output without bypassing symlink or digest checks. Python maintainer source belongs to the existing maintainer artifact class.

## Linked Issue

Phase 136 — Measured Quality and CI Ratchets.

## Validation

- Supported measurement host: Elixir 1.17.3 / OTP 27.3.4.15 / Node 20.18.1.
- Repair owner and whole-tree guard suite: 65 tests, zero failures.
- Artifact-ledger shell harness: 58 passed, zero failed, including archive simulation and live repository partition.
- Repository Credo gate passed; all 31 output relocations and 38 unchanged receipt JSON hashes verified.
- Replacement canonical run: 1,698 tests and 3 doctests, zero failures; exact 5,206/6,329 = 82.2563% coverage. Local gate and source-bound receipt verification passed.
- Live CI Script Tests passed, including artifact-ledger validation, archive simulation and repository hygiene.
- Fresh/restored Dialyzer passed in 55.331/3.047 seconds. Clean full bootstrap passed all six commands in 379.476 seconds; mix ci passed in 331.833 seconds.
- Prior-phase regression passed 226 tests with zero failures; the replacement fixed 25-seed experiment completed with every seed green and its receipt verified.
- Source-bound qualification recomputes six complete authorities. CI-16 remains blocked: initial Proof reached its 15-minute job limit during passing Nightly harness assertions. A single failed-job rerun is underway on unchanged source. Exactly ten authenticated timing samples remain pending, with median ≤ 480 seconds and p95 ≤ 600 seconds required.
- The earlier source completed its 25-seed matrix, but its measurements are retained as historical evidence and receive no replacement-source qualification credit.

## Checklist

- [x] `mix ci` is green locally or in CI on the replacement source.
- [x] Docs are updated when behavior, setup, or contributor workflow changes.
- [x] Docs-only changes do not alter `lib/` behavior.
- [x] Security reports are routed through GitHub advisories, not public issues.
