---
phase: 133-evidence-charter-and-live-truth
plan: "152"
completed: 2026-10-10
status: halted
qualification_credit: 0
qualification_attempt_count: 1
network_request_count: 0
unresolved_edge_rows: 11
first_red_stage: dependencies
first_red_exit_code: 1
preflight_sha256: 93e66c30f6b65ebc063624519a8779914a14f47bce346e5ebdbfc744888ff5ef
supply_sha256: e25d14934179896d150d14bbc51c3d36793af79fbb397e785f5bae5c3489b55c
authorization_sha256: b4dab21134ab114400f45c8b9e409a74a3b92c5df7409a725459af8f629fc490
attempt_sha256: a40389ea3d54222a84e8016c8df05a66a685ecaacd52e6b60dc1a9053aff376d
local_gates_sha256: 89f46c5b5d7f638b73a1f710e92bb887db8a00294aa3aa5f8c89016a5e473195
---

# Phase 133 Plan 152: Durable Supply Qualification First Red

The exact Plan 152 authorization was recorded and independently verified. Its sole guarded qualification attempt passed all seven Plan 152 Node authority tests, then stopped at `mix deps.get --check-locked` with exit 1: Hex offline mode reported that the registry entry for `myxql` was not cached. The runner stopped immediately. JOSE, CI, coverage and any diagnostic Mix child were not started. Post-cleanup `verify-halted` passed for the frozen source and terminal receipts.

Plan 152 therefore remains a zero-credit halt. All five requirements remain Pending, eleven evidence edges remain unresolved, and no census or remote mutation is authorized. The complete 67-archive package set, supported Hex build and cache passed their supply verifier, but that inventory covered the 67 locked package names only. `myxql` has no row in `133-152-SUPPLY.json`'s registry inventory; `mix.lock` references it as an optional dependency of both `ecto_sql` and `oban`. This mismatch explains the observed first red and shows the next supply check must cover dependency metadata referenced by locked packages, including optional dependencies.

## Consumed Qualification Tuple

Source `e7b6b8fc63d71454aebd58ab484352786f5f42dd`, tree `f91900468377ffa085730845b53531e3fc883dbf`. Elixir 1.17.3 / OTP 27.3.4.15, authenticated Hex 2.5.1, Node 22.14.0. The exact command was:

```bash
PATH=/Users/jon/.asdf/installs/nodejs/22.14.0/bin:$PATH ERL_FLAGS='+S 2:2' bash scripts/maintainer/phase_133_local_gates.sh --subject e7b6b8fc63d71454aebd58ab484352786f5f42dd --plan 133-152 --offline-cache .planning/phases/133-evidence-charter-and-live-truth/133-152-SUPPLY.json --output .planning/phases/133-evidence-charter-and-live-truth/133-152-LOCAL-GATES.json
```

The macOS guard permitted its control child (exit 0) and denied loopback with `EPERM` (exit 77). The Node authority suite ran once with seven tests and zero failures. The dependency child ran once and returned exit 1. No HTTP requests occurred, and no retry was made.

## Next Readiness

Plan 152's one-shot gate is consumed. Preserve its frozen source and receipts. A successor must first add complete registry metadata for all lock-referenced package dependencies, including optional dependencies such as `myxql`, and a preflight assertion that rejects an incomplete set before presenting another qualification decision. Any later qualification requires a distinct source, its own verified supply, and a new exact authorization. Plan 121 remains blocked.
