# GSD command continuity diagnosis

Generated: 2026-10-21. Problem: repeated intermediate stops and missing next GSD commands.

## Findings

| Check | Evidence | Finding |
|---|---|---|
| Repeated stop loop | Session responses after bea89f08/c11bd9b3 ended at repair/qualification status; the user repeatedly requested the next command. | Confirmed agent handoff failure: the next workflow command and terminal state were omitted or ambiguous. |
| Stale resume artifact | HANDOFF.json named Phase133/Plan170; STATE named Phase136. GSD resume-project.md explicitly treats HANDOFF.json as primary resume context. | Confirmed routing hazard. No evidence proves the stale file was actually consumed during the problematic responses. |
| Conflicting state | Pre-repair STATE header said current_plan15 and last_activity Oct18; its tail still directed Phase133 Wave28 and described Phase134 as unstarted. | Confirmed contradictory resume instructions despite the active Phase136 job and completed133–135 roadmap entries. |
| Missing closeout | GSD find-phase136 reports15 plans/14 summaries; verification.status reports missing with next_command execute-phase136. | Plan07/verification are genuinely unfinished; merge success cannot close them. |
| Abandoned work / crash | Manifest136-07-final-measurements is running; progress reached async; final-pin coverage, Dialyzer, bootstrap and regression succeeded; seed0 passed. | No observed crash or abandoned collector. Preserve the existing job. |
| Routing debt | roadmap.analyze reports current_phase133 and checkbox conflicts133–135; verification.status135 names six shared files changed by136. | Generic roadmap routing can disagree with active job ownership. Fingerprints are genuinely stale, not evidence of a code regression; real re-verification remains due. |
| CI as suspected cause | PR162 merged; final-head PR and main CI passed in retained merge evidence. | Required CI is not the current wait. Final-source evidence collection is. |

## Root cause

The command-based GSD workflow remains installed and callable. The observed conversational
failure came from stopping at intermediate results without a complete command handoff.
Contradictory long-lived state and a stale one-shot handoff made resumption less reliable.
Later source repairs legitimately invalidated earlier exact-source measurement credit,
while the accepted numeric speed deferral was not fully reconciled with the old Plan07
text. These facts were repeatedly presented as status instead of a clear current command,
wait condition, and next transition. There is no evidence of a GSD runtime crash causing
this behavior; the model-bake warning alone does not establish a cause.

## Repairs

- Archive the obsolete Phase133 HANDOFF byte-for-byte and preserve the full old STATE.
- Replace current STATE with concise Phase136/Plan07 ownership and command routing.
- Add planning-scoped agent instructions and the Development Train handoff contract.
- Add a read-only resume guard and behavioral tests for stale-phase rewinds, duplicate
  jobs, running versus completed jobs, failed jobs, foreign commands, and missing verification.
- Keep source e2d3b5c frozen and leave the existing collection pipeline running.
- Require a concrete GSD command in every future workflow handoff. Background compute
  is a legal wait, not a promise that the agent automatically wakes after the turn ends.

## Recovery route

While the existing job runs: `$gsd-progress` in the Phase136 execution worktree.
After it terminates: `$gsd-execute-phase 136` to verify the existing outputs and close
Plan07/the phase only when acceptance passes. After verified completion, use GSD routing
for Phase137 (currently no context or plans; expected next `$gsd-discuss-phase 137`).
Numeric exact-ten CI timing remains deferred unfinished with zero credit. Prior-phase
verification debt must be reconciled with real evidence, never a digest-only refresh.

This report diagnoses repository/session continuity; it is not an upstream GSD crash report.

## Validation

The handoff guard passes10 behavioral tests. Live output selects external_job_waiting,
next_command `$gsd-progress`, then `$gsd-execute-phase 136` after the job. Both
archived artifacts match their pre-repair Git bytes. STATE is under150 lines.
The automation-first contract and frozen-subject projection checks pass.
The collector remains active; two of25 seeds had completed at the last observation.
