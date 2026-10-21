---
phase: 136-measured-quality-and-ci-ratchets
plan: 14
status: complete
requirements-completed: [MAINT-04, TYPE-03, COV-06, TEST-08, CI-15, DX-05]
---

# Plan 14: Retained output and CI hygiene repair

The original PR failed because the artifact ledger did not classify the Python collector and rejected committed `.log` evidence. Source repair 4fdd3fba5ef5bc73be52473bc72de03fe56926d4 classifies Python maintainer source, emits `.txt` command output, and verifies relocated legacy output while preserving the exact original receipt bytes and digest checks. All 31 relocated outputs match their original bytes, and all 38 existing JSON files retain their hashes. Junk and ignore rules remain unchanged. Existing originals, dangling symlinks, relocated symlinks, missing data and tampered bytes are not bypassed.

Genuine failing owner assertions are committed in 7c4722ad; the unchanged JUnit report passed RED_EVIDENCE_OK. The repaired owner/meta suite passed 65 tests; the complete artifact-ledger harness passed 58 cases including archive simulation. Repository Credo passed. An exact Python pathname initially triggered the live-residue guard; the namespace pattern for Python source fixed it without an allowlist change. Live CI Script Tests subsequently passed every previously failing hygiene step.

## Replacement subject measurements

The pin is 136-SUBJECT-HYGIENE.json, tree 02903fa7e28f22041a0562f29c34f86b6bb76ecc. One canonical run passed 1,698 tests and 3 doctests, zero failures, exact 5,206/6,329 = 82.2563% coverage. The local gate and exact receipt verifier passed. Fresh/restored Dialyzer passed in 55.331/3.047 seconds. Clean full bootstrap passed all six documented commands in 379.476 seconds, including mix ci in 331.833 seconds. Prior-phase regression passed 226 tests with zero failures in 110.329 seconds. The replacement fixed 25-seed experiment completed with all seeds green, followed by owner verification. Finite sampling does not prove every schedule safe; a reproducible isolation failure or source change is the recorded next trigger. No ad-hoc retry erased any result.

All immutable HYGIENE receipts, command artifacts and the original replacement JSONL are committed. Qualification generation and verification recomputed six complete requirements; CI-16 is blocked by missing live timing. Verification exit zero on that truthful blocked manifest is not a phase-completion result.

## Remaining CI gate

Initial workflow 39530200284 passed both Quality cells and all other applicable jobs until Proof exceeded its 15-minute ceiling during the Nightly harnesses. The adoption authority suite itself passed 40 tests with zero failures after 596 seconds. No timing sample sequence started. A single failed-job rerun was requested on the unchanged subject; the timeout and required context have not been relaxed. Plan 07 remains responsible for actual exact-ten timing and final qualification before phase/merge closure.

The user authorized squash merge after green CI. Authorization is recorded in 136-MERGE-AUTHORIZATION.json; no merge or release has occurred.
