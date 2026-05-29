# Bookkeeping Rules

This command writes planning artifacts by default, but only into existing GSD
surfaces and only when the assessment adds genuinely new signal.

## Allowed targets

- `.planning/STATE.md`
- `.planning/PROJECT.md`
- `.planning/threads/*.md`
- an existing relevant `*-LEARNINGS.md`

## STATE.md

Use `STATE.md` for:

- new current-position notes that matter before the next milestone
- new blockers or concerns surfaced by the assessment
- milestone-ordering decisions from this pass
- clear reminders about what should not be carried forward manually

Do not bloat `STATE.md` with a full report.

## PROJECT.md

Touch `PROJECT.md` only for durable truth changes:

- corrected project framing
- changed project priority or emphasis
- durable out-of-scope clarification
- support-truth or adopter-story corrections that future planning must honor

Do not rewrite historical sections just to mirror the report.

## Threads

Use `.planning/threads/` for cross-session investigations that should survive
until a future milestone decision or implementation pass.

Good thread material:

- unresolved candidate wedge comparisons
- important adopter-story doubts
- proof/CI/truth gaps that are not the main milestone
- research directions worth preserving

If there is no threads directory yet, create it only when an investigation
actually needs persistence.

## Learnings

Update `*-LEARNINGS.md` only when there is a clearly relevant existing phase
file and the assessment adds a real lesson, decision, surprise, or pattern not
already captured.

If the repo is between milestones and no relevant learnings file is the right
home:

- do not invent a new phase file
- mention in the report that the insight belongs in the next phase's learnings
  once the phase exists

## Duplication rule

Never write the same insight into multiple files unless each file truly serves a
different purpose.

Preferred pattern:

- `STATE.md` for "what matters next"
- `PROJECT.md` for durable truth
- `threads/` for open investigations
- `LEARNINGS.md` for phase-scoped institutional lessons
