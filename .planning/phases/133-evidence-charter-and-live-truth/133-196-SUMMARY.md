---
phase: 133-evidence-charter-and-live-truth
plan: "196"
status: complete
closeout_status: no_attempt
halted: false
requirements-completed: []
requirements_completed: []
requirements_pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
unresolved_edge_rows: 11
qualification_credit: 0
tasks_completed: 3
tasks_total: 3
reviewed_tool_invocations: 1
producer_invocations: 1
source_sha: 5fc6aad7833fdba40ff74675bb5602ae819940fb
source_tree: 71d7070fe900ba8415b14455627f9d6cbb9a5e61
diagnostic_present: true
diagnostic_raw_sha256: 7de036a05e391b606539b3323e02293c1a508f6d36fd898c833f57fe6a7c0d93
preparation_present: false
outcome_present: true
observation_present: true
initial_authentication_completed: true
key-files:
  created:
    - scripts/maintainer/phase_133_registry_collection_196.mjs
    - scripts/maintainer/phase_133_registry_collection_196_verify.mjs
    - .planning/phases/133-evidence-charter-and-live-truth/133-196-OBSERVATION.json
  modified: []
coverage:
  - deliverable: Original collection chain and portable closeout
    human_judgment: false
    verification:
      - kind: command
        ref: node --test scripts/maintainer/phase_133_registry_collection_196.test.mjs scripts/maintainer/phase_133_registry_collection_196_verify.test.mjs
        status: pass
      - kind: command
        ref: node scripts/maintainer/phase_133_registry_collection_196_verify.mjs verify --observation .planning/phases/133-evidence-charter-and-live-truth/133-196-OBSERVATION.json --summary .planning/phases/133-evidence-charter-and-live-truth/133-196-SUMMARY.md
        status: pass
---

# Phase 133 Plan 196: Authenticated Offline Collection

One exact environment-bound original invocation authenticates branch no_attempt. Collector terminal exit 0; 2 ordered original call(s), 185 output bytes / 5896e54ad917b39ae41840c9c541c8255bf1176b0b298f4615b76cbced42cf84. Immediate completion and empty zero-token pending chunks are supported without replacing the first result. Final receipt first bytes were read only after terminal completion. This is an offline prerequisite with zero qualification credit.

Source 5fc6aad7833fdba40ff74675bb5602ae819940fb, tree 71d7070fe900ba8415b14455627f9d6cbb9a5e61; nonce 178cc7563ad552eb789adf613198e81993ed02c91708db3c; root identity 7f1d0667fdab180ceea24e495521e17d06cc303adfe03349cac0a88fadb1779f. Fresh actual async proof c0b6bc463ed0d53def259e7ce7055c304cd6c473eddf37b322d088f4fcbdd4f9, summary 1974356b1e4445019ab728b243b5cdabfc37bfea912ff63d6846ecec1afba840, verified against private original calls before source freeze and command review.

Ordinal 0 (exec_command): request 608 bytes / 4d28e3791b214cd068fbaa29c137a3c78ed808362c9b58e5e4ed7fce53c343ed; result 110 bytes / ea69a6b9fa764850b5a0412c2bf0ca531121253ccd7b695bd873836c44c4f13c; supplied keys chunk_id, wall_time_seconds, session_id, original_token_count, output; unavailable exit_code.

Ordinal 1 (write_stdin): request 78 bytes / 6c18118f569d49811f99ce121721be45eb3d222fb6bd19118f1172525352d9a1; result 313 bytes / 622cef6d38c9d6e064ec0ad58a3ed9191799218817dfda4c45208b4dc33d353b; supplied keys chunk_id, wall_time_seconds, exit_code, original_token_count, output; unavailable session_id.

## Task Results

Task 1 adds fail-first disposable blocked/red/ready branch tests, all fourteen spent SHA/tree exclusions, reservation before Git/callbacks, exact guard checks, bounded nonce-bound private stderr and private ordered-chain authentication. Tests cover immediate and asynchronous completion, early receipt reads, wrong session/output, first-byte/source drift, private substitution and wholly rehashed forgeries. No production child runs through a fixture.

Task 2 makes at most one individually reviewed offline collector call at the negotiated physical GSD root. Signed Plan 153/155 supply and unchanged network-deny profile control exit 0 plus positive local EPERM/EACCES denial are required before private clone and one producer. The observed producer count is 1; narrow diagnostic code unavailable; specific cause unknown. Bounded original stderr is retained privately before clone cleanup, with only nonce/size/digest in safe receipts. No historical child is replayed.

Task 3 authenticates every original request/response against independent parent originals, source/code, final receipt and fresh-proof facts. Only the single declared verifier anchor slot changes after frozen observation; its executable core remains unchanged. GSD manifest-scoped merge/removal and transcript cleanup precede portable verification from the successor checkout without the old root, environment, private transcript, private stderr or Git. Retained producer stderr remains private audit evidence.

## Deviations from Plan

The first RED test run was a missing-module load failure, which is invalid behavioral RED evidence. A later disposable branch test failed on the blocked-output contract and drove its correction; final branch and chain tests pass. This TDD discipline limitation is retained explicitly. The initial-authentication CLI accepts an explicit private --facts file to supply independently retained parent originals. Execution remains inline at the user's request. Plan 194's retained stderr has no recoverable exact nonce/directory binding in available parent audit records, so its specific cause remains unknown; no wrapper repair is inferred from it. No acceptance scope changes.

## Preserved History and Acceptance

Plan 194 remains spent halted_untrusted with unchanged first DIAGNOSTIC/OUTCOME, summary/verifier, original pending result and absent PREPARATION/trusted OBSERVATION. Plans 190/192 and all prior spent sources remain immutable, unauthenticated history where applicable; Plan 190's specific producer cause remains unknown. Unrelated dirt is preserved.

All five requirements remain Pending, all eleven edges unresolved including both unclassified rows, and qualification credit zero. No qualification authorization/attempt, registry HTTP, external network request or remote mutation occurs. Phase 132 remains last complete, Phase 133 incomplete and Phase 134 unstarted; Plans 121–123 and 169 remain blocked. Further qualification needs separate planned work and authorization; this branch grants none.

## Self-Check: PASSED

Initial private authentication, independently pinned raw/source anchors, focused tests, syntax, committed/fresh prerequisites, immutable history, full-rehash rejection, portable verification after transcript/root removal and automation-first are required and verified before committed closeout.
