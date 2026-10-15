---
phase: 133-evidence-charter-and-live-truth
plan: "135"
subsystem: provenance
tags: [hex, offline, authorization, runtime, cache, first-red]
requires:
  - phase: "133-133"
    provides: Pinned and production-verified Hex v2.5.1 source retrieval.
provides:
  - Independent exact authorization and consumed one-shot build marker.
  - Verified terminal halt with successful build and failed proof-write transcripts.
affects: ["133-134", "133-136", "133-129"]
actuals:
  tokens: 38853
  tasks: 2
  commits: 6
plan_head_before: 9ed62ec3f74a12619deedd6157bcf3434d9a499a
plan_head_after: dbeea541055579e48dd4763545eff692ddfce777
tech-stack:
  added: []
  patterns:
    - Fresh literal permission binds exact source, runtime, destination and commands.
    - Exclusive started marker precedes effects; first red prevents later children.
key-files:
  created:
    - scripts/maintainer/phase_133_hex_build.mjs
    - test/install_smoke/phase_133_hex_build_test.mjs
    - .planning/phases/133-evidence-charter-and-live-truth/133-135-RED.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-135-BUILD-PREFLIGHT.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-135-BUILD-AUTHORIZATION.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-135-BUILD-STARTED.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-135-COMPATIBILITY.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-135-SUMMARY.md
  modified:
    - scripts/maintainer/phase_133_registry_compat.exs
    - test/install_smoke/phase_133_registry_compat_test.exs
key-decisions:
  - Preserve the first proof-write failure as terminal zero-credit history; no retry.
  - Keep Plan 134 blocked because signed-fixture, durable cache and restart proof failed.
  - Retain the original read-only clone, isolated build destination and transcripts.
requirements-completed: []
requirements-pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
coverage:
  - id: D1
    description: Independent literal authorization verified immediately before consumption.
    verification:
      - kind: other
        ref: node scripts/maintainer/phase_133_hex_build.mjs verify-authorization --preflight .planning/phases/133-evidence-charter-and-live-truth/133-135-BUILD-PREFLIGHT.json --authorization .planning/phases/133-evidence-charter-and-live-truth/133-135-BUILD-AUTHORIZATION.json
        status: pass
    human_judgment: false
  - id: D2
    description: Verified false-compatibility receipt with exact first-red command and zero credit.
    verification:
      - kind: other
        ref: node scripts/maintainer/phase_133_hex_build.mjs verify-halted --report .planning/phases/133-evidence-charter-and-live-truth/133-135-COMPATIBILITY.json
        status: pass
      - kind: unit
        ref: ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 elixir test/install_smoke/phase_133_registry_compat_test.exs
        status: pass
    human_judgment: false
duration: 21min
completed: 2026-10-09
status: halted
tasks_executed: 3
task_3_status: terminal-first-red
checkpoint:
  type: decision
  gate: blocking-human
  task: 2
  status: authorized-and-consumed
  preflight_sha256: 57ffe57fcdc4cf22d4b2908ae3a69ca8c7d7529eb192b1a80ff4a91d61e68354
build_count: 1
mix_child_count: 1
proof_write_count: 1
proof_read_count: 0
mux_request_count: 0
network_request_count: 0
qualification_credit: 0
unresolved_edge_rows: 11
---

# Phase 133 Plan 135: One-Shot Hex Build and Offline Cache Proof — Terminal Summary

**Pinned Hex v2.5.1 built successfully on Elixir 1.17.3 / OTP 27.3.4.15, but proof-write exited 1 in `Hex.State.ssl_version/0`; compatibility remains false and the one authorized attempt is consumed.**

Tasks 1 and 2 are complete. Task 3 executed once and reached its first-red stop before signed-fixture, durable-cache or restarted-readback proof. This summary closes out the verified halt; it does not claim supported cache compatibility or successful completion of Task 3. Plan 134 remains blocked. The prior unanswered-checkpoint text is superseded by the actual authorization and terminal receipts.

## Performance

- **Original work started:** 2026-10-08T23:28:23Z.
- **Original checkpoint:** 2026-10-08T23:41:17Z; prior executor reported 15 minutes.
- **Fresh authorization recorded:** 2026-10-09T00:02:54.907Z.
- **Task 3 execution timer started:** 2026-10-09T00:07:48.722Z.
- **Terminal summary prepared:** 2026-10-09T00:12:51.204Z.
- **Duration:** approximately 21 minutes of reported execution across segments (6 minutes for Task 3 and close-out); excludes checkpoint waiting and continuation context reads.
- **Tasks:** 2/3 successful; all three executed, with Task 3 terminally halted.
- **Files:** 9 task artifacts plus SUMMARY across the plan. This continuation added BUILD-STARTED and COMPATIBILITY and updated SUMMARY only.
- **Actuals:** 38,853 estimated tokens from 155,409 realized diff characters / 4, rounded up, excluding SUMMARY as in the prior measurement. Six commits measured from the persisted ledger through the terminal evidence commit; final summary commit is outside that measurement.

## Accomplishments

- Preserved Task 1's independent gate and frozen tuple. The fresh Task 2 answer passed production authorization verification immediately before the one approved invocation; this also rechecked source retrieval, all 221 source files, runtime hashes, committed inputs, history and destination absence.
- Preserved complete terminal evidence: BUILD-STARTED preceded effects, build exited 0 with 132 BEAM/application inventory entries, and proof-write exited 1. The gate published false compatibility and never ran proof-read. Production `verify-halted` returned `COMPATIBILITY_OK halted`.

## Task Commits

All prior and continuation commits are on this preserved branch:

- `7c05e5956cb7cc093400393e9bcc8b63ddbf11a1` — test(133-135): assert independent offline Hex build authorization gate.
- `9c08ab1577bbb1ce6ef6d50d6fcd4dea5b87d389` — feat(133-135): gate one offline Hex build and restarted cache proof.
- `79008dad36b8187be080dced3ef0a6dc846885bf` — chore(133-135): freeze exact source runtime and offline build tuple.
- `7a4bc155124d649eaa8232403310492c5ed32604` — docs(133-135): record blocking build-authorization checkpoint.
- `b1582a07818ae75b8be3458c3a1e8e31add53652` — decision(133-135): record exact build authorization.
- `dbeea541055579e48dd4763545eff692ddfce777` — chore(133-135): preserve first-red offline cache proof halt.

The final metadata commit contains this SUMMARY and is reported in the executor return. Continuation commits use the GSD helper with normal hooks, without force staging or hook bypass. STATE.md and ROADMAP.md remain unchanged for the orchestrator.

## Exact Tuple and Durable Identity

- **Source:** `https://github.com/hexpm/hex.git`; commit `a43131c26aeca06064959297d737991163f5ac5d`; tree `778c9a1387d22da9ea8830d1f02b84c9f7402c7d`.
- **Read-only clone:** `/private/tmp/rindle-phase133-hex-v2.5.1-a43131c26aeca06064959297d737991163f5ac5d`.
- **Retained build destination:** `/private/tmp/rindle-phase133-hex-v2.5.1-a43131c26aeca06064959297d737991163f5ac5d-build-p135`.
- **Runtime:** Elixir `1.17.3-otp-27`, Erlang/OTP `27.3.4.15`; nine runtime file hashes remain frozen.
- **Literal answer:** `Authorize once: 57ffe57fcdc4cf22d4b2908ae3a69ca8c7d7529eb192b1a80ff4a91d61e68354`.
- **Preflight self-digest:** `57ffe57fcdc4cf22d4b2908ae3a69ca8c7d7529eb192b1a80ff4a91d61e68354`.
- **Preflight file SHA-256:** `19ff6c09824f8a672dfa544457d2d988fd3bedafef57e470152715c7d0172132`.
- **Authorization file SHA-256:** `8f555434e29f6a346d534962d8f8c127c2de6f9a4f1c9771e19818dc2044b2e9`.
- **Authorization canonical-object digest bound by runner:** `d4fae55a25734d6ebc7307e866e33a41b094ad10a607de6dc0bf487cdb9e801f`.
- **Started-marker file SHA-256:** `c30171bb612a43b9f99bf6704724af6e7202555cdec0b40eb1655283a503987c`.
- **Terminal report self-digest:** `6bbaf39c52adaafff1cf1567174cb36d1bab2d27e81a5877de9a882f7715e808`.
- **Terminal report file SHA-256:** `ebb58d4635ecffbcf48f3e9aff45c3aa2deb998b4369ebc20286a0d85056ef93`.
- **Built registry-server BEAM SHA-256:** `fe062d7e1a8f0994e7a6dc8554b36243240fac87063133a44eca92db3c7ddffc`.
- **132-entry inventory SHA-256:** `6b9a2d31134d7109a2d3aa2e09da771ee47276814662ccdef63d7d1d30b65d0f`, over `JSON.stringify(report.beam_files)`.

The exact environments and three approved argv arrays remain in preflight and authorization. The original source and all 221 copied source files retain pinned digests. Source receipts, canonical Nightly, census, validation, requirements and barred SHA `87572a019636ba1367c0c7245ae5cb89d0ea1909` remain unchanged.

## Task 3 Execution and First Red

The authorized production invocation was `node scripts/maintainer/phase_133_hex_build.mjs build-once`. It exited 1:

`[phase-133-hex-build] first red (proof-write): proof-write child failed; attempt consumed`

| Stage | Exit | Result |
|---|---:|---|
| build | 0 | Compiled 1 .xrl, 28 .erl and 83 .ex files; generated Hex; 132 inventory entries. |
| proof-write | 1 | MatchError in Hex.State.ssl_version/0 during Hex.State initialization. |
| proof-read | not run | Prevented by first-red gate. |

Build argv, executed only by the gate from the isolated source directory:

```text
["/Users/jon/.asdf/installs/elixir/1.17.3-otp-27/bin/elixir", "/Users/jon/.asdf/installs/elixir/1.17.3-otp-27/bin/mix", "compile", "--no-deps-check"]
```

Failed proof argv, executed only by the gate from the isolated destination:

```text
["/Users/jon/.asdf/installs/elixir/1.17.3-otp-27/bin/elixir", "-pa", "/private/tmp/rindle-phase133-hex-v2.5.1-a43131c26aeca06064959297d737991163f5ac5d-build-p135/_build/lib/hex/ebin", "/Users/jon/projects/rindle/.claude/worktrees/agent-p135-wave3/scripts/maintainer/phase_133_registry_compat.exs", "proof-write", "--preflight", "/Users/jon/projects/rindle/.claude/worktrees/agent-p135-wave3/.planning/phases/133-evidence-charter-and-live-truth/133-135-BUILD-PREFLIGHT.json"]
```

Exact proof-write stderr is preserved in COMPATIBILITY.json, SHA-256 `62551c9d869ece7ddab581056d3b890b4dde8dfb5cbe5ef23e369083eeb30020`:

```text
** (EXIT from #PID<0.92.0>) an exception was raised:
    ** (MatchError) no match of right hand side value: :undefined
        (hex 2.5.1) lib/hex/state.ex:402: Hex.State.ssl_version/0
        (hex 2.5.1) lib/hex/state.ex:198: Hex.State.init/1
        (elixir 1.17.3) lib/agent/server.ex:8: Agent.Server.init/1
        (stdlib 6.2.2.4) gen_server.erl:2229: :gen_server.init_it/2
        (stdlib 6.2.2.4) gen_server.erl:2184: :gen_server.init_it/6
        (stdlib 6.2.2.4) proc_lib.erl:329: :proc_lib.init_p_do_apply/3
```

Fixture, public key and cache files are absent; `proofs` is empty. Signature/origin controls, checksum readbacks, persistence and restart were not proved. No build or proof retry occurred. No network client, dependency/package retrieval, global installation, mux request, qualification or Plan 134 preflight ran. Five requirements remain Pending, eleven edge rows unresolved, qualification credit zero.

## Checks Run

### Prior completed work

The committed checkpoint records Task 1's RED evidence accepted as `RED_EVIDENCE_OK`, full Node gate suite 10/10, production `PREFLIGHT_OK` for the exact digest, standalone tests 5/5 and source regressions 3/3. The orchestrator subsequently recorded and verified fresh Task 2 authorization.

### Current continuation

- First-action assertions passed at exact HEAD `b1582a07818ae75b8be3458c3a1e8e31add53652`, branch `worktree-agent-p135-wave3`, with clean status.
- Production authorization verification immediately before effects returned `AUTHORIZATION_OK 57ffe57fcdc4cf22d4b2908ae3a69ca8c7d7529eb192b1a80ff4a91d61e68354`.
- One real build/proof attempt: build exit 0, proof-write exit 1, no proof-read. Compatibility acceptance failed and was preserved without repair or retry.
- Exported terminal snapshot verification passed: marker-byte binding, exact child sequence/exits, false compatibility and zero credit.
- `ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 elixir test/install_smoke/phase_133_registry_compat_test.exs` passed 5/5. This standalone command invokes neither Mix nor real proof entry points.
- After committing receipts, production `verify-halted --report .../133-135-COMPATIBILITY.json` returned `COMPATIBILITY_OK halted`. It reverified source/preflight, authorization, runtime, committed inputs, history, transcript digests and actual BEAM outputs. Positive compatibility is not claimed; the terminal-halt verifier applies to this false report.
- Copied-fixture regression command `node --test --test-name-pattern='^(?!production CLI rejects changed evidence paths before any build child$)' test/install_smoke/phase_133_hex_build_test.mjs` exited 1: **9 passed, 1 failed, 0 skipped**. The attempted exclusion did not exclude the pre-build CLI test. Its invalid-argument command was rejected at parsing as expected, but line 152 then failed `true !== false` because BUILD-STARTED now exists. No additional build/proof child ran. The suite is not green after consumption; neither tests nor runner were changed, and it was not retried.
- Explicit preservation checks passed for source clone/copy, preflight, authorization, source reports, STATE, ROADMAP, config, Nightly, census, validation and requirements. Fixture/key/cache absence was checked.
- `TMPDIR="$PWD/tmp" ./scripts/maintainer/automation_first_contract.sh` passed after receipt changes. Worktree-local temporary storage preserves the write boundary. `git diff --check` passed.
- GSD evaluation-scope resolved six branch-local commits. No new stubs, TODO/FIXME placeholders, skipped-test declarations or additional threat surface were introduced.

Pre-build `verify-preflight` and `verify-authorization` require an absent destination and attempt. Their successful pre-consumption results are retained; deleting consumed evidence to rerun them is prohibited. The terminal verifier is the current authority.

## Decisions Made

- Applied first-red/no-retry without changing frozen source, runtime, runner, tuple or permission.
- Retained the locally signed hexpm-origin fixture design as unproved. Such a local fixture would only prove protocol/cache behavior, never upstream mux provenance or supply credit.
- Kept `status: halted`, empty `requirements-completed` and zero credit. Compilation and unit fixtures do not establish real cache compatibility.

## Deviations from Plan

- **Prior segment — containment:** The checkpoint recorded one initial contract invocation using default temporary storage, followed by correction to worktree-local TMPDIR. Every continuation contract invocation uses worktree-local temporary storage.
- **Verification sequencing:** The production verifier requires a completely clean worktree. Generated receipts passed the exported snapshot validator and automation contract, then were committed before production `verify-halted`. No condition was weakened.
- **Post-attempt regression selection:** The attempted Node exclusion unexpectedly ran the pre-build CLI case. Its `build-once --authorization copied-clone-permission.json` entry was rejected before source collection, marker creation or child execution. This extra rejected CLI entry exceeded the intended strict single-entry verification scope, while the actual authorized build/proof count remained one. Its marker-absence assertion failed; no retry or repair followed.
- **Git metadata:** Normal GSD commits required sandbox escalation for shared worktree Git metadata. No orchestrator working files, other branch refs, hook settings or ignore rules were changed.

No production code changed during this continuation. The proof failure remains unresolved.

## Issues Encountered

The committed initialization path raised `MatchError` on `:undefined` in `Hex.State.ssl_version/0`. The exact stack, command, exit and transcripts are durable. No alternate startup, repaired runner, second proof or build retry was attempted. One existing regression test additionally assumes absence of the production started marker, a pre-build condition that is now correctly false.

The worktree lacks `.codex/gsd-core/bin/gsd-tools.cjs`; installed `/Users/jon/.codex/gsd-core/bin/gsd-tools.cjs` supplied queries and commit helper. Existing model-routing bake warnings did not cause configuration changes.

## User Setup Required

None for terminal close-out. Fresh authorization was received, verified and consumed; it cannot authorize another attempt.

## Next Phase Readiness

Plan 134 and dependent plans remain blocked. Preserve the worktree, source clone, build destination, authorization, marker and terminal receipt. Any successor repair/build/proof requires its own approved scope and authorization. The phase orchestrator owns STATE.md and ROADMAP.md updates after the wave merge. Five requirements remain Pending and eleven edge rows unresolved.

## Self-Check: PASSED

All eight created files exist; all six prior/task commits are ancestors of HEAD and resolved by GSD evaluation-scope. Terminal snapshot and production halt verification passed. Frozen input and authority preservation checks passed. The final summary explicitly retains failed compatibility acceptance, the 9/10 post-attempt regression result, blocked Plan 134, five Pending requirements and eleven unresolved edges. This self-check validates the terminal record only; it does not establish cache compatibility or Task 3 success.
