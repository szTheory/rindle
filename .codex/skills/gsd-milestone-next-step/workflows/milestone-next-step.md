<purpose>
Assess a Phoenix/Elixir OSS library at a milestone boundary from an adopter's
perspective. Determine how "done enough" it is for its stated scope, identify
the single highest-leverage next milestone, rank the next few after it, and
retain any genuinely new lessons and investigations in the existing GSD
surfaces.
</purpose>

<required_reading>
Read all files referenced by the invoking prompt's execution_context before
starting.
</required_reading>

<process>

<step name="guardrails">
Apply these rules throughout:

- This is not a generic code review or repo-hygiene pass.
- Focus on real adopter value for a Phoenix SaaS developer using the library in
  a production app.
- Prefer repo-local evidence over internet browsing.
- Browse only when a current market expectation claim would otherwise be weak.
- Do not write implementation or feature code.
- Do not create new planning file types.
- Do not start `$gsd-new-milestone`.
</step>

<step name="discover_repo">
Resolve the actual repo state before making any judgment.

At minimum, inspect:
- `.planning/PROJECT.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/MILESTONES.md`
- `.planning/REQUIREMENTS.md` if present; otherwise use the latest archived
  milestone requirements file from `.planning/milestones/`
- `.planning/JTBD-MAP.md` if present
- recent relevant `.planning/phases/*/` artifacts, especially:
  `*-LEARNINGS.md`, `*-RESEARCH.md`, `*-SUMMARY.md`, `*-VERIFICATION.md`
- any `.planning/threads/*.md` files if they exist
- `README.md`
- a small, targeted set of guides or install docs if present
- `prompts/` files when present, prioritizing names containing:
  `deep-research`, `oss-dna`, `context`, `brand`, `research-index`
- enough `lib/`, `test/`, install-smoke, and example/demo surfaces to verify
  what is truly shipped

Use parallel reads where possible to keep context efficient.
</step>

<step name="evidence_priority">
If artifacts disagree, use this evidence order:

1. shipped code, tests, install-smoke, examples
2. active planning state
3. archived milestones and phase artifacts
4. prompts and framing docs

If shipped evidence and planning disagree:
- say so explicitly
- lower confidence
- do not pretend certainty
</step>

<step name="current_story">
Summarize the adopter story briefly:

- the one primary job the library serves
- which flows are clearly real today
- which Phoenix SaaS adopters it already serves well
- where the story is rough, partial, or under-explained

Do not re-onboard the maintainer if the repo already documents the basics.
</step>

<step name="done_estimate">
Estimate rough "done enough" percent from this rubric:

- core JTBD coverage
- breadth vs what adopters in this category actually expect
- docs / onboarding / install / examples quality
- operator / admin / diagnostic / support-truth posture
- proof / CI / verification honesty
- remaining delta type:
  - `FOUNDATIONAL`
  - `IMPORTANT-BUT-NARROW`
  - `LONG-TAIL POLISH`

Map the result into one band:
- `90-95%` — near-done, diminishing returns soon
- `80-89%` — strong, meaningful wedges remain
- `70-79%` — credible and useful, important adopter gaps remain
- `<70%` — still missing foundational expectations

The estimate must be justified by shipped/open evidence, not milestone counts.
</step>

<step name="candidate_research">
Generate 3-5 serious milestone candidates from the repo's deferred items,
rough edges, open investigations, and adopter gaps.

For each candidate wedge, weigh:
- concrete adopter value
- pros / cons / tradeoffs
- idiomatic Elixir / Phoenix / Plug / Ecto shape
- lessons from this repo's prior research and learnings
- successful patterns from comparable libraries when already captured locally
- risk of overbuilding or scope drift
- coherence with the project's stated scope and architecture

When parallel subagent research is available, use one investigation per serious
candidate. Otherwise do the comparison inline. In either case, produce one
coherent recommendation set; do not hand the maintainer an unresolved trade
study.
</step>

<step name="pick_next_milestone">
Rank the top 3-5 wedges and choose exactly one next milestone recommendation.

For each ranked wedge, include:
- why it matters
- who it serves
- what "done enough" looks like
- whether it is foundational, important-but-narrow, or polish

Also call out tempting items that are likely:
- diminishing returns
- adjacent but not central
- overbuilding for the library's scope

Suggest the ordering for the next few wedges after the primary pick.
</step>

<step name="bookkeeping">
Retain only genuinely new information, and only in existing GSD surfaces.

Allowed write targets:
- `.planning/STATE.md`
- `.planning/PROJECT.md`
- `.planning/threads/*.md`
- an existing relevant `*-LEARNINGS.md`

Rules:
- If there is no active phase or no clearly relevant learnings file, do not
  invent a new phase artifact just to store the assessment.
- Put cross-session open investigations into `.planning/threads/`.
- Update `STATE.md` with current position notes, new decisions, and new
  blockers/concerns from the assessment.
- Update `PROJECT.md` only when the assessment changes durable truth:
  scope boundary, project priority, durable out-of-scope guidance, or a
  meaningful framing correction.
- If a useful insight belongs in a future phase's learnings rather than an
  existing file, say that explicitly in the final report instead of creating a
  placeholder file.
- Do not duplicate information the repo already records clearly.

If the repo has no `.planning/threads/` directory yet and a new investigation
must persist, create the directory and one thread file using existing
`gsd-thread` conventions.
</step>

<step name="shift_left">
Shift-left recurring preferences only when low risk.

- Prefer project-local behavior over global defaults.
- Auto-apply low-risk routine preferences only if they are not already covered
  by the project-local skill or current `.planning/config.json`.
- Never silently change high-impact settings such as model profile, verifier,
  research toggles, plan-check, or quality gates.
- In this command's final report, explicitly list any config/default changes
  made. If none were needed, say so plainly.
</step>

<step name="output">
Present the result using the template shape in
`templates/assessment-report.md`.

The output must include:
1. framing
2. current state
3. adopter coverage map
4. next-work recommendation
5. diminishing-returns judgment
6. blunt maintainer takeaway
7. bookkeeping written
8. shift-left applied

Before finalizing, sanity-check that every conclusion can be traced back to
repo inspection rather than a milestone title or a single document.
</step>

</process>
