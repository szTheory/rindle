# Rindle Development Train

Rindle uses two lanes after the v1.17 mission-complete boundary:

- The sustaining release train keeps `main` green and lets patch-eligible changes flow through
  Release Please (see `.planning/RELEASE-TRAIN.md`).
- The milestone development train gives future feature work a reviewable GSD branch and one PR
  back to `main`.

This document defines the feature-development lane. Release publication remains owned by
`.planning/RELEASE-TRAIN.md` and the repo-controlled Release Please workflow.

## Default Posture

`main` is the release-train source of truth. Do not run open-ended feature work directly on
`main` during the demand-gated pause.

Patch/support/release-hygiene changes may use ordinary PRs when they do not widen Rindle's
public support contract. New feature work uses a milestone branch and one milestone PR.

## Milestone PR Shape

Use one branch and one PR per feature milestone.

- Branch name: `milestone/vNEXT-short-slug`
- PR target: `main`
- GSD state: active only on the milestone branch
- Merge condition: milestone audit, verification evidence, green PR CI (all merge-blocking jobs)

Examples:

- `milestone/v1.18-force-delete-shared-assets` (LIFE-06)
- `milestone/v1.18-second-streaming-provider` (STREAM-10)

Do not create a separate release branch for feature work. After the milestone PR merges to
`main`, Release Please decides the release PR from merged commits and checked-in release config.

## When To Open A Feature Milestone

Open a milestone PR only with a documented demand signal in the milestone charter:

| Signal | Milestone | Trigger |
|--------|-----------|---------|
| LIFE-06 | Force-delete shared assets | Concrete compliance/legal ticket |
| STREAM-10 | Second streaming provider | Named adopter + provider choice |
| TRANS-01 / PRIV-01 | Privacy & delivery polish | Explicit product pull |

Do **not** open a feature milestone without one of these signals (`block_feature_milestone_without_signal` in `.planning/config.json`).

Keep using ordinary patch PRs for:

- Bug fixes on shipped behavior
- Docs or support-truth corrections
- CI, release-hygiene, and maintainer-runbook hardening
- Narrow hardening on already-supported surfaces

## Workflow

1. Start from clean, green `main`.
2. Run `./scripts/maintainer/repo_hygiene_check.sh` before opening the milestone branch.
3. Create `milestone/vNEXT-short-slug` from `main`.
4. Run `/gsd-new-milestone` on the milestone branch with the documented demand signal.
5. Execute GSD phases on the milestone branch (discuss → plan → execute → verify → audit).
6. Open one PR from the milestone branch to `main` when implementation-complete.
7. Before merge, confirm all merge-blocking CI jobs pass on the PR.
8. Merge the milestone PR to `main`.
9. Let Release Please update or open the release PR from `main`.
10. After any real publish, update `.planning/RELEASE-TRAIN.md` with publish proof.

## Merge Gate

A milestone PR is mergeable only when all of these are true:

- GSD phase summaries exist for every planned phase
- Milestone verification and audit artifacts are present and passing
- All merge-blocking GitHub PR checks pass
- Public support wording matches shipped code (docs parity tests green)
- The PR does not bypass Release Please or create a manual release path

## Release Boundary

Milestone PRs deliver product changes to `main`; they do not publish packages by themselves.

Release Please remains the normal release-intent mechanism. The trusted `release` environment
publish lane starts only after the Release Please PR merges and the automerge workflow dispatches
the exact-ref publish path, as described in `.planning/RELEASE-TRAIN.md` and
`guides/release_publish.md`.

## Standing Assumptions

- `demand-gated-pause` remains the normal idle state between feature milestones
- GSD planning artifacts may live on milestone branches before merge
- Patch train work should not be inflated into a milestone unless it changes scope, support truth, or public contract
- Do not run `/gsd-plan-phase` or `/gsd-autonomous` on `main` during pause

## GSD command handoffs

Preserve the user's command loop: `$gsd-discuss-phase N` → `$gsd-plan-phase N`
→ `$gsd-execute-phase N`, with verification and next-phase routing owned by GSD.
Honor existing context/config when choosing which of those steps is actually next.
When the next stage is known, hand off directly to that stage: discussion without
context, planning with context, execution with outstanding plans, or the verification
owner's recovery command. Do not make the user run `$gsd-progress` to discover an
action that can already be resolved. If the guard falls back to progress, resolve
GSD's normal routing before responding. Progress remains available for requested
status checks and the existing external-job waiting case below.

Every GSD status, pause, completion, and resume response must include:

1. The actual workflow state: executing, external job waiting, blocked, gaps found,
   or verified complete. PR merged and CI green do not imply phase completion.
2. One primary literal `$gsd-...` command the user can run next, its correct
   worktree, and whether to run it now or after an existing job finishes.
3. For an external job, its durable owner and current status. Use `$gsd-progress`
   while it runs and the manifest's phase-specific execute command after it ends.
   Verify results before writing a summary or advancing; never resubmit the job
   merely because the plan lacks a summary. Background collection does not imply
   an agent will automatically wake up and finish verification after the turn ends.

Run `python3 .planning/tools/check_gsd_handoff.py` before giving a handoff. This
read-only check rejects conflicting phases and duplicate job ownership, and uses
GSD's verification owner when no job is outstanding. Validate changes to this
contract with `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s .planning/tools -p 'test_gsd_handoff.py'`.

Keep STATE.md current and concise. It must name the active plan, real wait,
worktree, and next command. Archive an obsolete HANDOFF.json after successful
resumption, preserving its evidence under forensics; never leave a different
phase's one-shot handoff active. Historical authorization and failure narratives
belong in explicitly historical artifacts, not current blockers.

Carry an authorized command through its required gates. Fix permitted routine
reversible blockers within scope. If a mandatory skill gate requires stopping,
name the gate and provide the concrete GSD recovery command. Do not stop merely
because an intermediate repair passed. Reuse already recorded authorization.

An explicit scope deferral stays unfinished with zero acceptance credit. Reconcile
it against active success criteria before continuing; do not restart its collectors
from obsolete plan text. Keep other required evidence gates intact. Older shared-file
verification fingerprints can become stale during a later phase: surface that debt,
retain the current job's ownership, and re-verify through GSD rather than silently
rewinding active execution or rewriting old fingerprints to green.

## Immutable snapshot acceptance

Phase139's approved `rindle-snapshot-v2` path fixes an explicit authenticated previously-main
candidate while ordinary development and PRs continue. Scheduled proof still belongs to
that candidate; mutable private sources, ledger, protection and authoritative adoption
facts refresh from current main. Snapshot completion is historical, never current-main
or publication credit. Do not freeze the train or reset a candidate solely for unrelated
main movement. Use RUNNING.md's `--snapshot --subject FULL_SHA` commands after the policy
has landed and the selected candidate has its actual complete CI and scheduled proof.
