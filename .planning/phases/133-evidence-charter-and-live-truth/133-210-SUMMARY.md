---
phase: 133-evidence-charter-and-live-truth
plan: "210"
subsystem: planning-evidence
tags: [claude-code-runtime, tool-chain, plan-203-rebind]
status: complete
halted: false
qualification_credit: 0
requirements-completed: []
requirements_completed: []
requirements_pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
unresolved_edge_rows: 11
requires:
  - phase: 133-209
provides:
  - Claude Code chain adapter (background Bash launch, Read polls, one task-notification; harness output file authoritative)
  - Plan 203 collection and qualification code rebound to that chain, ready to freeze
affects: [133-203]
key-files:
  created:
    - scripts/maintainer/phase_133_claude_chain_210.mjs
    - scripts/maintainer/phase_133_claude_chain_210.test.mjs
    - .planning/phases/133-evidence-charter-and-live-truth/133-210-SUMMARY.md
  modified:
    - scripts/maintainer/phase_133_qualification_203.mjs
    - scripts/maintainer/phase_133_qualification_203_verify.mjs
    - scripts/maintainer/phase_133_local_supply_203.mjs
    - scripts/maintainer/phase_133_qualification_203.test.mjs
decisions:
  - "Claude Code has no machine-readable per-call approval record; chains record review {runtime: claude-code, kind: permission_mode, machine_verifiable: false}. The user's digest-bound Plan 203 literal remains the only qualification authority (T-133-562, accepted by the user)."
  - "The Codex-adapter-only `worktree-agent-` branch check in collect() is removed; validateBinding's linked-worktree proof remains."
completed: 2026-10-14
---

# Phase 133 Plan 210: Claude Code Chain for Plan 203

**Complete.** Plan 203 can now run its collection and qualification from Claude Code. It no longer needs Codex `exec_command`/`write_stdin` rows or the Codex approval review.

## What was built
- **`phase_133_claude_chain_210.mjs`:** a private, ordinal, no-clobber ledger. It is built on the unchanged Plan 191 capture (generic bytes only) and the Plan 193 binding.
  - **Call 0** is a `Bash` request `{command, description, run_in_background: true, dangerouslyDisableSandbox}`. Its exact launch text must name the task ID and an output file.
  - **Later calls** are `Read` polls of that same file, followed by exactly one `task-notification`. The notification's task ID, output file, status and exit code must agree with the launch.
  - **Output:** the harness-written output file is copied once into the ledger (`seal-output`). It must end with `\n[exited with code N]\n` matching the notification. Agent text never supplies output bytes.
  - **Budgets:** short is 600,000 ms and 41 calls; terminal is 22,200,000 ms and 800 calls. Each pair is limited to 4 MiB and the whole chain to 16 MiB.
  - **Output paths:** production accepts only `/private/tmp/claude-<uid>/<project>/<session>/tasks/<id>.output`. An injected output root is allowed only for fixture ledgers.
  - **Temp base:** the ledger records its temp base and fails closed if it changes. TMPDIR was checked and is identical with and without the sandbox.
- **Fresh harmless probe** (`probe`, 20 s hold). It authenticates only with at least one pending `Read` observed and the independent original bytes. There is one fresh-facts schema `{originals, proof_raw_sha256, summary_raw_sha256}`, consumed identically by `collect()` and `freshAuthentication`.
- **Plan 203 rebind:**
  - `collectionRequest` and `terminalRequest` are now Claude Code background `Bash` requests. Each command starts with `cd '<root>' && env 'GSD_WORKTREE_PATH=<root>' NODE_NO_WARNINGS=1`, and the request sets `dangerouslyDisableSandbox: true`, because the collector's own deny profile cannot nest inside the Claude Code sandbox.
  - Collection chains use the short budget and terminal chains the terminal budget.
  - The Codex terminal fork is removed, and the anchor slots stay null.
- **Inventory:** the two Plan 210 files are inserted before the verifier (`NEW_FILES.at(-1)` is still the verifier). `133-210-SUMMARY.md` is frozen with the subject, `IMPLEMENTATION_SUMMARIES` is `[201, 205, 206, 207, 210]`, and `SOURCE_FILES` has 95 entries.

## Gates
| Gate | Result |
|---|---|
| RED commit before implementation | `0cc2d157` (module missing) |
| `phase_133_claude_chain_210.test.mjs` | 19 pass, 0 fail |
| `phase_133_qualification_203.test.mjs` | 42 pass, 0 fail |
| `phase_133_tool_chain_195.test.mjs` | 25 pass, 0 fail |
| Plan 191/193/195/200 modules vs `51eab305` | unchanged |

## Deviations from Plan
- **Additional Codex coupling found during execution:** `collect()` required the current branch to start with `worktree-agent-` (the Codex adapter's worktree naming). That would have failed on `gsd/phase-133-execution` and burned the route. It is removed and the plan was amended (`014d8834`).
- **Pinned Node in bound commands (found during the Plan 203 pre-launch rehearsal):** bare `node` resolves through asdf and `.tool-versions` to 20.18.1 in this worktree, and Plan 203's collector requires the producer pin. That would have burned the route. `boundCommand` now emits `/Users/jon/.asdf/installs/nodejs/22.14.0/bin/node` (`PINNED_NODE`, tested equal to `PRODUCER_PIN.path`). The Plan 203 runtime-substitution test also mutated `pin.path` to `process.execPath`, which is a no-op under the pinned node that `authority_regression` uses. It now uses a distinct path, and the suite is 42/42 under both Node 20.18.1 and the exact pinned `--test-reporter=tap` argv (`50921a09` RED, `7565c7da` fix).
- **Launch cwd note (found by the first fresh probe, which consumed nothing):** a background `Bash` command that starts with `cd` returns a second line, `Session cwd remains <dir>; directory changes made by the backgrounded command do not apply to subsequent commands.`, so the single-line launch parser would have rejected the true original text of every bound command. The parser now accepts exactly that one optional note and rejects every other suffix. The spent probe nonce `4f14befb…` is abandoned, and a new probe runs on the re-frozen subject.
- **Notification ordinal:** the notification request is recorded as `{event: 'task-notification', task_id}`, since it is not a tool call.
- **Tests replaced:** the Codex chain tests in `phase_133_qualification_203.test.mjs` were replaced by Claude Code equivalents (poll of another file, foreground launch, wrong task, exit mismatch, dropped text, extra keys, ordinal/time/size bounds, 800-call bound).
- **Pair bound:** a `Read` request is fixed and small, so the 4 MiB pair bound is effectively enforced by the capture's own 4 MiB per-part limit, which is tested.

## Edges, requirements, credit
Nothing was collected, qualified or sent remotely. All five requirements stay Pending, all eleven edges stay unresolved, and qualification credit is 0. Plan 203's single route is unconsumed and no `133-203-*.json` receipt exists.

## Commits
- `014d8834` docs(133-210): drop Codex worktree-agent branch check from Plan 203 collect
- `0cc2d157` test(133-210): add failing Claude Code chain adapter tests
- `9206bf37` feat(133-210): add Claude Code chain adapter for Plan 203
- `4eaf68f0` feat(133-210): rebind Plan 203 to the Claude Code chain
- (this summary) docs(133-210): complete Claude Code chain plan
