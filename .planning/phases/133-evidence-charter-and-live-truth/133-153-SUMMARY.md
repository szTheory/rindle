---
phase: 133-evidence-charter-and-live-truth
plan: "153"
subsystem: infra
tags: [restart, durable, signed-registry, offline]
requires:
  - phase: 133-151
    provides: immutable original signed batch and lock provenance
  - phase: 133-152
    provides: verified qualification preparation and measured transient-input loss
provides:
  - Durable supported Hex source/build and authenticated registry records for all 67 locked packages
  - Exclusive source/package start markers and per-child restart-safe evidence
  - Fresh qualification consumers requiring complete durable supply
requirements-completed: []
requirements_pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
coverage:
  - id: D1
    description: Native signature/origin/both-lock-hash verification and complete all-package offline readback.
    verification:
      - kind: other
        ref: "node scripts/maintainer/phase_133_durable_inputs_153.mjs verify-supply"
        status: pass
    human_judgment: false
status: complete
completed: 2026-10-10
completed_at: 2026-10-10T20:05:14.483646+00:00
qualification_credit: 0
qualification_attempt_count: 0
network_request_count: 67
source_fetch_count: 1
build_count: 1
unresolved_edge_rows: 11
first_red: null
preflight_sha256: b8c5f4ee99030d8c8832a3254e3707e5b5255555d158aa81fca9ae09a6d7a42c
marker_sha256: 0241221a760c4b3356963166f6595aec18e1c1641c80ea5ad88741ed33c0eccd
retrieval_sha256: 88cf4847f5fb397eb6ea336aa9b684b7159aa0bd20a74f2ef29190244eab1275
supply_sha256: e26601365905b7d041ce296b00df764fbc4b865121bb0d4478b12c2e64f47266
---

# Plan 153 Durable Restart Recovery

The user's restart/continue instruction triggered a separately identified recovery of public build inputs. No consumed Plan 129/150/151 literal or command was replayed. One exclusive recovery marker preceded the exact pinned public Hex Git fetch. Source SHA/tree were verified, then compilation succeeded under actual OS network denial in private homes. Exactly 67 TLS GETs succeeded, each signature/origin/both locked checksums verified, persisted through Hex and read in a distinct denied-network OS process before the next GET. All 134 request/read children exited zero. Independent production `verify-supply` passed after cleanup, verifying official source, all 132 compiled Hex files, all signed objects, another 67 offline reads and the complete all-67 cache inventory. Qualification, census, global installs, remote mutation and requirement acceptance remain zero.

Producer `/Users/jon/projects/rindle/.claude/worktrees/p153-durable-inputs`, branch `worktree-agent-p153-durable-inputs`, GSD base `ba199b3131b9bfe29aeca624f4ded31f4c5aa5f6`. RED `f86358b8` passed machine classifier `RED_EVIDENCE_OK`: four intended API assertions expected functions and observed undefined, without setup/import/fixture failures. Initial implementation `482ffd1c`, runtime-path repair `a04ea397`, final source `0c7a7404df470daf3c9df92bb096fe960ea19def`, tree `f0112bb87f7d3a127d3983e0afe40b7b34031661`. Verified preflight checkpoint `5c2ab23f` preceded the sole recovery invocation (tool session 4558). Native guard control exits 0/77, denied loopback witness EPERM/EACCES, pinned Node 22.14.0, Elixir 1.17.3/OTP 27.3.4.15. Every build/read child used `(version 1) (allow default) (deny network*)`. Only the bound public source/package clients used the recorded narrow HTTPS/DNS profile with TLS verification, no redirects or retry.

Durable inputs `/Users/jon/projects/rindle/.claude/inputs/phase133/registry-153-0c7a7404df470daf` are outside `/tmp` and build cleanup roots. Cache `/Users/jon/projects/rindle/.claude/inputs/phase133/registry-153-0c7a7404df470daf/registry/cache.ets` SHA-256 `ce12a6cb28821645a8e078429cbf5e4eb509de8d240792cba728e8ac56a29b94`. Hex source commit `a43131c26aeca06064959297d737991163f5ac5d`, tree `778c9a1387d22da9ea8830d1f02b84c9f7402c7d`, build `/Users/jon/projects/rindle/.claude/inputs/phase133/registry-153-0c7a7404df470daf/hex-build/lib/hex/ebin` (132 files). All 67 signed objects, source-fetch/build records, package markers, input descriptors and request/read records remain private and durable. The supply receipt binds every object/file hash. All 67 package archives, matching Vix and clean pinned Lexbor remain at `/Users/jon/projects/rindle/.claude/inputs/phase133/restart-local-20261010/hex` and sibling native/source directories, reauthenticated against lock and original native metadata.

Original Plan 151 supply digest `09815ff49d79d844ec0386bedf0ac65cc7cd35bc2c41e762b597c6aa7bc6be2b` and Plan 150 supply digest `8b6f252791e5c032dd2d9f659d230cb2467c3046ecdf1f1ead710321afae5737` remain immutable historical provenance. Their original temporary physical inputs disappeared after host restart; this recovery does not claim those vanished bytes available or rewrite their successful receipts. Original producer roots and terminal Plan 129 remain unchanged. Current qualification now requires this fresh durable producer and its complete-summary/source binding, plus the original immutable receipt bindings.

## Verification

25 new/historical Node regressions pass, including durable path refusal, marker-first order, first red/no retry, signed origin/key/lock substitution, fresh versus consumed authority, cache coverage, source edits/reverted commits, changed session-path tails with identical pinned binaries, and initialized private homes. Independent live native supply verification passes. Plan 152 preparation at base `ba199b31` already passed the full fake runner, pinned reconciliation (117 tests, zero failures, 746.1 seconds), and native complete/missing-key ETS fixtures; its Elixir and runner files are unchanged by this recovery. Automation-first and source syntax pass.

| Log under `_build/phase133-plan153-evidence` | Raw SHA-256 |
|---|---|
| red.json | `9a3d7c8b0a138f1df5c3fa8200b4a3bf618b383be495736b0105c4646aba3a13` |
| unit-green.tap | `34b8aa1ab1a3b46f1646c4c0e2efb09869c0bcc1dc2b61142618adde161eaabb` |
| preflight.log | `2612667ac463d2cc57bc7682521cd968a7158efe494bc01a654f5562b396f9d7` |
| verify-preflight.log | `ce399ddfe01cca4d400c334e2150e3be4f0da13609ec67e28e0eaac658bb6ea0` |
| recovery.log | `bdacc6f60e960b73b11330259ac737b77110fcc73d6181cd9b0c9dd6f6890d4f` |
| verify-supply.log | `27b814ccf7d2730e1a602e4a7995f074f7481e35870ea88298ccf0c1bb246526` |
| post-recovery-tests.tap | `b2dbd58a0ff1c80cd37efbf2236cd84834d34508e3534b0312a78eeae9801089` |
| post-recovery-automation.log | `9e2fa70638bf496dbf4c27cf5d9c594d14f28411b7081882ccceb94ea9e9bf01` |

## Deviations and Continuation

Two preliminary zero-effect checks failed before publication, markers or fetches. An inherited runtime comparison included stale session PATH entries; the fix compares every supported identity/binary digest while measuring and binding the current path. A setup-order bug accessed cache metadata before initialization; private cache metadata now precedes guard controls. Both regressions pass and repairs were committed before the final source freeze. Their raw logs are retained; no successful preflight was re-frozen and no recovery invocation retried. The GSD create command's comma-separated advisory scope was parsed as one path; only that advisory array was normalized to the declared plan paths, preserving the adapter-created worktree identity/path/base.

Create a distinct GSD Plan 152 executor from this closeout, freeze its clean source only after the full durable supply exists, publish and independently verify complete offline preflight/supply and zero-fetch retrieval, then surface its separate exact qualification decision. No Plan 152 authorization or attempt exists. All five requirements Pending, eleven unresolved edges, zero qualification/requirement credit. Plans 121–123 remain blocked on independently verified green qualification. Primary unrelated dirt is preserved; no merge, push or release occurred.
