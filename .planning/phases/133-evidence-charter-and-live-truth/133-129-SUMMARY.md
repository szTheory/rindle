---
phase: 133-evidence-charter-and-live-truth
plan: "129"
subsystem: infra
tags: [offline, qualification, first-red, incomplete-registry]
requires:
  - phase: 133-136
    provides: committed fresh qualification guards
  - phase: 133-150
    provides: signed mux record and preserved private cache
provides:
  - Exact consumed one-shot qualification authority and independently verified terminal halt
  - Complete read-only registry inventory proving thirteen missing locked records
affects: [133-121, 133-122, 133-123]
key-decisions:
  - "Never retry the consumed exact-source attempt or promote its red result."
  - "Require every locked registry record in a successor readiness gate, independently of archive coverage."
requirements-completed: []
requirements_pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
coverage:
  - id: D1
    description: Source-bound first-red result passes production halted verification after cleanup.
    verification:
      - kind: other
        ref: "node scripts/maintainer/phase_133_recovery.mjs verify-halted --plan 133-129 --manifest .planning/phases/133-evidence-charter-and-live-truth/133-129-SUPPLY.json --report .planning/phases/133-evidence-charter-and-live-truth/133-129-PREFLIGHT.json --local-gates .planning/phases/133-evidence-charter-and-live-truth/133-129-LOCAL-GATES.json"
        status: pass
    human_judgment: false
completed: 2026-10-10
completed_at: 2026-10-10T18:24:48Z
status: halted
qualification_credit: 0
qualification_attempt_count: 1
network_request_count: 0
unresolved_edge_rows: 11
first_red_stage: dependencies
first_red_exit_code: 1
preflight_sha256: 0c7f528ddae56eb053b1fd5c631eb2063721dd1059df5929f93150b8f8bc6ce8
supply_sha256: 00915080f601b1e207089a9e287c686d8f7230b5325ad3faaf2ec630f2dba75d
authorization_sha256: 728691b766c887f3d6c7ddc13f5d20436182669976edf2839de3dc1f337823ff
local_gates_sha256: 2d2118150cc118290a67f62b1c312156dbaf28a3ddc85651dea71f2c4a907063
missing_registry_package_count: 13
---

# Phase 133 Plan 129: Verified Dependency First Red

The user's exact fresh authorization was committed `28debdce`. The sole frozen runner invocation passed seven guarded Node authority tests, then `mix deps.get --check-locked` exited 1. JOSE, CI, diagnostic Mix lookup and coverage were not started. The disposable worktree was removed; production `verify-halted` passed after cleanup, reauthenticating source and original supply. Plan 121 remains blocked, qualification credit zero and no requirement complete.

## Exact Consumed Tuple

Preparation commit `e17b6a56`. Source `df784b2014259196f149a2d747672ad18217c2f2`, tree `c95fadc32dcb6907463f28e68f6faa3e81071436`. Answer: `Authorize Plan 129 qualification once: 0c7f528ddae56eb053b1fd5c631eb2063721dd1059df5929f93150b8f8bc6ce8`. Preflight `0c7f528ddae56eb053b1fd5c631eb2063721dd1059df5929f93150b8f8bc6ce8`, supply `00915080f601b1e207089a9e287c686d8f7230b5325ad3faaf2ec630f2dba75d`, authorization `728691b766c887f3d6c7ddc13f5d20436182669976edf2839de3dc1f337823ff`, attempt `71cfa9d2766b4d532d34060da54dcbe2f955fac618faf75cc2fac33994dfc4af`, local gates `2d2118150cc118290a67f62b1c312156dbaf28a3ddc85651dea71f2c4a907063`.

Command: `bash scripts/maintainer/phase_133_local_gates.sh --subject df784b2014259196f149a2d747672ad18217c2f2 --plan 133-129 --offline-cache .planning/phases/133-evidence-charter-and-live-truth/133-129-SUPPLY.json --output .planning/phases/133-evidence-charter-and-live-truth/133-129-LOCAL-GATES.json`. Elixir 1.17.3 / OTP 27.3.4.15, `HEX_OFFLINE=1`, guard `0a5222386587bf836d30a070bd759c0194f999bf5503ba76c6c0f8cb84b19db2`, OS profile `(version 1) (allow default) (deny network*)`. Control exit 0, EPERM loopback denial exit 77. Child counts: one Node (7 tests, zero failures), one Mix, zero diagnostic Mix children. First red: dependencies, command `mix deps.get --check-locked`, exit/effective exit 1. Every later stage is unstarted. No HTTP request, retry, census or remote mutation occurred.

## Confirmed Missing Input and Diagnostic Limit

Read-only guarded ETS inspection of the unchanged original private cache found the locked mux version, but **13 other locked package records are absent**. A stable exclusive snapshot of the current shared cache lacks those same records and mux. The audit made no shared-cache write, Mix invocation, fetch or qualification replay. Existing authenticated tar archives cannot satisfy missing registry entries in offline dependency resolution. Preflight authenticated archives and mux, but did not inventory every locked registry record. A successor must enforce complete registry coverage before another qualification decision.

The dependency child produced 113 raw bytes; its diagnostic allowlist retained zero lines. Required cleanup removed the transient raw output. The exact first package/error string is therefore unknown and must not be invented. The separate full registry inventory proves the missing set. A successor must retain sanitized bounded Mix errors even when the old keyword allowlist does not match.

| Missing package | Locked version | Locked archive outer SHA256 |
|---|---|---|
| `bypass` | `2.1.0` | `d9b5df8fa5b7a6efa08384e9bbecfe4ce61c77d28a4282f79e02f1ef78d96b80` |
| `color` | `0.12.0` | `1e17768919dad0bd44f48d0daf294d24bdd5a615bbfe0b4e01a51312203bd294` |
| `doctor` | `0.23.0` | `b8eb63380fa14d9aced609671600359b1fd057da167339c5031b683eb2bac973` |
| `ex_machina` | `2.8.0` | `79fe1a9c64c0c1c1fab6c4fa5d871682cb90de5885320c187d117004627a7729` |
| `ex_marcel` | `0.2.0` | `fecf90bfe1cb4097d58ac7d444249afc9e8a314413f82cfb29a8a758ec65fcd5` |
| `gcs_signed_url` | `0.6.0` | `5ad5e4e0de832d774636e12c642a8fedd376522544697934fc06a7ddeeb805aa` |
| `goth` | `1.4.5` | `0fc2dce5bd710651ed179053d0300ce3a5d36afbdde11e500d57f05f398d5ed5` |
| `image` | `0.65.0` | `d2060e08d0f42564f49de1ea97a82a5d237f9ac91edb141dece51f1238dd8b4a` |
| `jose` | `1.11.12` | `31e92b653e9210b696765cdd885437457de1add2a9011d92f8cf63e4641bab7b` |
| `junit_formatter` | `3.4.0` | `bb36e2ae83f1ced6ab931c4ce51dd3dbef1ef61bb4932412e173b0cfa259dacd` |
| `muontrap` | `1.7.0` | `7bd4a90ae008bf6a25554aa13497b2c05dfa1fcc34be5bdcb8fb4dec9b3422e3` |
| `tesla` | `1.21.2` | `296bbafd1a328533c57e6b0e93078983cf40a827546e58a20464ce75485d5254` |
| `vix` | `0.38.0` | `dca58f654922fa678d5df8e028317483d9c0f8acb2e2714076a8468695687aa7` |

Original private cache: `/private/tmp/rindle-phase133-mux-150-cache-ad8fc01e51610def/cache.ets`, SHA256 `270d5e3cc4c4c6321b3ee0d09efdd4fa7abcf99988cb2c381199f0ed5b5bb320`. Shared read-only snapshot: `/private/tmp/rindle-p129-shared-audit-dfc9410d525a32e0.ets`, SHA256 `dfc9410d525a32e049954c5bf479f1cd9cbed24c4594f3881cf1ace7086c52a0`. Original Plan 150 signed supply and producer remain unchanged.

## Verification Logs

| Log | Raw SHA256 |
|---|---|
| `/private/tmp/rindle-p129-qualification.log` | `a06310f7b8b8a8d9ccc85147a3e7ea9dfe52cb3f9447db8b3f9fef74bf2bfc44` |
| `/private/tmp/rindle-p129-verify-halted.log` | `7c6800fcba1dcba22cbd059b15e9d1090312ede5e62d7cf1c19d40843190696a` |
| `/private/tmp/rindle-p129-registry-audit.log` | `f331dc60832bc9f5f6677803fbfebd80871420fdcfd9b9b69653d9faed8e7fdd` |
| `/private/tmp/rindle-p129-shared-registry-audit.log` | `38bc65b25bf94de262897fb774db0c93f44041835e5ea7beeb35518fd9a5013f` |

## Deviations and Next Readiness

The one-shot first-red boundary ran as planned. Post-stop read-only audits diagnosed the missing-input set without inheriting consumed permissions. Preparation and immutable halt history are complete; qualification remains halted. Preserve this executor, receipts and frozen source. A separately planned full-registry repair and diagnostic regression must precede a distinct fresh-source qualification. All five requirements remain Pending, eleven edges unresolved; Phase 133 incomplete and Phase 132 last completed.
