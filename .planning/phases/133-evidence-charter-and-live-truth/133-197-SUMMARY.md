---
phase: 133-evidence-charter-and-live-truth
plan: "197"
status: complete
closeout_status: implementation_only
halted: false
requirements-completed: []
requirements_completed: []
requirements_pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
unresolved_edge_rows: 11
qualification_credit: 0
tasks_completed: 2
tasks_total: 2
reviewed_tool_invocations: 0
producer_invocations: 0
production_clones: 0
plan198_receipts_present: false
subsystem: evidence
key-files:
  created:
    - scripts/maintainer/phase_133_registry_collection_198.mjs
    - scripts/maintainer/phase_133_registry_collection_198.test.mjs
    - scripts/maintainer/phase_133_registry_collection_198_verify.mjs
    - scripts/maintainer/phase_133_registry_collection_198_verify.test.mjs
  modified: []
coverage:
  - deliverable: Pinned-runtime disposable tracer and immutable successor prerequisites
    human_judgment: false
    verification:
      - kind: command
        ref: node --test scripts/maintainer/phase_133_registry_collection_198.test.mjs scripts/maintainer/phase_133_registry_collection_198_verify.test.mjs
        status: pass
      - kind: command
        ref: node scripts/maintainer/phase_133_tool_chain_195.mjs verify-fixture --proof .planning/phases/133-evidence-charter-and-live-truth/133-195-CHAIN-FIXTURE.json --summary .planning/phases/133-evidence-charter-and-live-truth/133-195-SUMMARY.md
        status: pass
      - kind: command
        ref: node scripts/maintainer/phase_133_registry_collection_196_verify.mjs verify --observation .planning/phases/133-evidence-charter-and-live-truth/133-196-OBSERVATION.json --summary .planning/phases/133-evidence-charter-and-live-truth/133-196-SUMMARY.md
        status: pass
      - kind: command
        ref: ./scripts/maintainer/automation_first_contract.sh
        status: pass
---

# Phase 133 Plan 197: Pinned Producer Runtime Prerequisite

The prospective Plan 198 wrapper selects the original authenticated Node 22.14.0 producer executable instead of the collector's Node 26.10.0 fallback. This implementation demonstrates that executable inequality caused the strict comparison to reject; future complete producer success remains unobserved. Plan 198 collection is a separate unexecuted step.

## Task Results

Task 1 traverses physical GSD binding, exclusive diagnostic reservation, disposable runtime/version and dual guards, an isolated local no-hardlink clone, fixed pinned launch to a fake producer, private stderr retention before clone cleanup, exclusive branch receipts, independently retained original immediate/async tool pairs, fresh prerequisite authentication and portable closeout after root/private transcript removal. The unchanged Plan 154 production comparison receives the authentic old guard unchanged; all four fresh Node 26 executable references move together and are rejected. The same pinned Node 22 guard passes when all other fields match. A disposable cache replaces only the test report's cache location/digest; it supplies no host qualification evidence.

Task 2 verifies runtime unavailable/path/link/mode/hash/version/report failures, pre-launch binary change, callback/CLI override exclusion, fixed PATH and sanitized Node options, weak guard control/denial/witness/proof metadata, strict complete structured stderr diagnosis, nonce/permissions/first bytes, original session/output/truncation/terminal checks, exclusive publication, code drift, wholly rehashed forgeries and independent runtime metadata. New runtime_identity and pinned_guard blocked branches authenticate both immediate and pending-to-terminal original chains and remain portable after cleanup. Original stderr stays private; only a known bounded code is projected. Existing narrow validated prefix support remains. Structured diagnostic_code registry_qualification_preflight_mismatch identifies the comparison error; it does not identify every divergent report field.

The initial-only verify-fresh-prerequisite CLI requires a regular 0600 single-link private facts file wrapping complete originals, proof_raw_sha256 and summary_raw_sha256. It delegates to unchanged Plan 195 verification, checks exact deterministic summary and raw hashes, and requires private master/call pairs. The ordinary verifier uses immutable safe observation/code anchors; it neither reads nor executes the pinned binary or any private transcript/stderr. The frozen binary pin is code metadata; only OBSERVED_ANCHORS is a later normalized anchor slot.

## Observed Runtime and Pins

Plan 154 PREFLIGHT raw SHA-256: 74fb95f020a8a0a451dc9513b5b5006326193f716177bf4800e3b7620f994c28.

Canonical report digest: 298a9d83826485607962db6f59281a2cb1e9e8ead4c257c253c369bfad857505.

Original physical executable: /Users/jon/.asdf/installs/nodejs/22.14.0/bin/node. Binary SHA-256: e2d4915d03eda6a2f00a09920e7eeb7a04ad123f9aaad61b1481179fe1bf50e0.

A real harmless bounded --version invocation under exact profile (version 1) (allow default) (deny network*) exited 0 with exact v22.14.0 newline, after regular/executable/physical/hash verification. Safe observation is retained at /private/tmp/rindle-plan197-runtime-observed.json. This was the only actual pinned child in Plan 197; no actual-host guard, registry producer, production collection/clone, Mix, registry HTTP or qualification ran. Guard and fake producer observations in tests are fixture-only.

## TDD Gate Compliance

Task 1 behavioral RED 32b510ec loaded existing launch plumbing and failed its executable assertion: actual Node 26.10.0 versus expected historical Node 22.14.0. GREEN 7ba8e05f passed 20 tracer tests, syntax and historical portable verification before expansion. This is a behavioral failure, not a missing-module/import failure.

Task 2 behavioral RED 45e2a73c rejected an incomplete guard validator: substituted pinned proof host executable was accepted. The corrected validator binds host identity, actual-host request, canonical probe, denial output and bounded output digests to observed control/denial tuples. Final combined suite passes 29/29, including all immediate/async and blocked/red/ready branches; both helper syntax checks and immutable Plan 195/196 portable proofs pass. The tracer verification gate passed before expansion.

## Deviations and Execution Scope

Execution continued inline at the user's established preference, in a GSD adapter-created manifest-bound disposable worktree. No subagent or model-routing change occurred. The host's headless executor descriptor is null; no headless executor was dispatched. Isolation/merge/cleanup use the existing GSD adapter. An initial Task 1 whitespace check found one extra final blank line; Task 2 removed it and final whitespace checks pass.

A binary change discovered by the final immediate pre-launch hash after private clone creation preserves an incomplete reservation and starts zero producer children; it does not fabricate a zero-clone blocked receipt. Pre-clone missing/version/hash failures publish an authenticated zero-clone blocked branch with complete observations. Output-bound or unexpected inspection failures likewise preserve the first incomplete reservation. This keeps effect counts truthful.

Schema and UI capability gates do not block; no UI/schema files changed. Codebase drift is skipped because STRUCTURE.md is absent. Configured code-review capability is false; inline source/integrity review was performed. No independent subagent review is claimed.

## Preserved History and Acceptance

Plan 196 DIAGNOSTIC raw 7de036a05e391b606539b3323e02293c1a508f6d36fd898c833f57fe6a7c0d93, OUTCOME raw 42298d4a1405591732a62c1171e60f9d5ffb831d15b07a44c24172c952e21d05, OBSERVATION raw 3c32cc042aa3d9accbbad47dc8df678ec094e8b7671c77325a0aae9c210cef75 and SUMMARY raw 5d853c4028b18e0d93f82d268870b3f562e38cfb753f99afb68bfc8c1ef35999 remain pinned, with absent PREPARATION and unchanged collector/verifier core. Its diagnostic_code remains null and its original then-unknown summary unchanged. Subsequent read-only diagnosis does not rewrite history. Plan 196 SHA 5fc6aad7833fdba40ff74675bb5602ae819940fb / tree 71d7070fe900ba8415b14455627f9d6cbb9a5e61 joins the previous fourteen spent sources; either SHA or tree equality rejects.

Plan 194 remains halted_untrusted. Historical helpers, receipts, summaries, absences, private producer stderr and audits remain untouched. Test-only transcripts and roots are removed by fixture cleanup. All five requirements remain Pending; eleven edges unresolved including both unclassified rows; zero qualification credit. Phase 132 remains last complete, Phase 133 incomplete and Phase 134 unstarted. Plans 121–123 and 169 remain blocked. No qualification authority, external request or remote action was granted or performed. No production Plan 198 DIAGNOSTIC, PREPARATION, OUTCOME, OBSERVATION or SUMMARY exists.

Plan 198 becomes eligible after this implementation summary/tests commit and immutable prerequisites verify. Its fresh actual harmless original-chain proof must authenticate before its distinct-source freeze and separately reviewed one-call collection; keep all fresh private pairs through initial authentication. Do not replay spent sources or invoke roadmap.update-plan-progress.

## Self-Check: PASSED

Focused 29-test suite, helper syntax, original runtime comparison, observed bounded pinned version, immutable history/absence, Plan 195/196 portable proofs, automation-first and whitespace gates verify this implementation-only closeout. No future producer or requirement completion is inferred.
