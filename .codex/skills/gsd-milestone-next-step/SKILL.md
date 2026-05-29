---
name: "gsd-milestone-next-step"
description: "Assess how done a Phoenix/Elixir OSS library is at a new milestone boundary, pick the highest-leverage next wedge, and retain new planning knowledge"
metadata:
  short-description: "Adopter-first milestone assessment and next-step recommendation for Phoenix/Elixir OSS libraries"
---

<codex_skill_adapter>
## A. Skill Invocation
- This skill is invoked by mentioning `$gsd-milestone-next-step`.
- Treat all user text after `$gsd-milestone-next-step` as `{{GSD_ARGS}}`.
- If no arguments are present, treat `{{GSD_ARGS}}` as empty.

## B. AskUserQuestion → request_user_input Mapping
GSD workflows use `AskUserQuestion` (Claude Code syntax). Translate to Codex `request_user_input`:

Parameter mapping:
- `header` → `header`
- `question` → `question`
- Options formatted as `"Label" — description` → `{label: "Label", description: "description"}`
- Generate `id` from header: lowercase, replace spaces with underscores

Batched calls:
- `AskUserQuestion([q1, q2])` → single `request_user_input` with multiple entries in `questions[]`

Multi-select workaround:
- Codex has no `multiSelect`. Use sequential single-selects, or present a numbered freeform list asking the user to enter comma-separated numbers.

Execute mode fallback:
- When `request_user_input` is rejected (Execute mode), present a plain-text numbered list and pick a reasonable default.

## C. Task() → spawn_agent Mapping
GSD workflows use `Task(...)` (Claude Code syntax). Translate to Codex collaboration tools:

Direct mapping:
- `Task(subagent_type="X", prompt="Y")` → `spawn_agent(agent_type="X", message="Y")`
- `Task(model="...")` → omit (Codex uses per-role config, not inline model selection)
- `fork_context: false` by default — GSD agents load their own context via `<files_to_read>` blocks

Parallel fan-out:
- Spawn multiple agents → collect agent IDs → `wait(ids)` for all to complete

Result parsing:
- Look for structured markers in agent output: `CHECKPOINT`, `PLAN COMPLETE`, `SUMMARY`, etc.
- `close_agent(id)` after collecting results from each agent
</codex_skill_adapter>

<objective>
Run an adopter-first milestone-boundary assessment for a Phoenix/Elixir OSS
library. Determine how close the library is to "done enough" for its intended
scope, rank the most meaningful remaining wedges, pick the single highest-value
next milestone, and retain newly learned planning knowledge in the existing GSD
surfaces.

This command is for practical product judgment, not generic code review, repo
hygiene, or implementation work. It stops after assessment, recommendation, and
bookkeeping.
</objective>

<execution_context>
./.codex/skills/gsd-milestone-next-step/workflows/milestone-next-step.md
./.codex/skills/gsd-milestone-next-step/references/phoenix-oss-library-lens.md
./.codex/skills/gsd-milestone-next-step/references/bookkeeping-rules.md
./.codex/skills/gsd-milestone-next-step/templates/assessment-report.md
</execution_context>

<context>
Optional input: `{{GSD_ARGS}}`

Use any provided text only as a focus hint. Do not treat it as authoritative
scope. Repo-local truth always wins over freeform hints.

Expected repo shape:
- GSD-managed project with `.planning/`
- Usually a `prompts/` directory with research/context material
- Elixir/Phoenix/Plug/Ecto OSS library source, tests, docs, and optional guides
</context>

<process>
Read and execute `workflows/milestone-next-step.md` end-to-end.

Preserve these invariants:
- inspect repo truth before making claims
- prefer shipped code/tests/examples over aspirational docs
- rank wedges by adopter value, not novelty
- write only existing GSD artifact types
- do not start `$gsd-new-milestone`
- do not write implementation code
</process>

<success_criteria>
- The library's real adopter story is summarized from shipped evidence
- A rough done-% and done-band is justified from the rubric, not phase count
- The top 3-5 remaining wedges are ranked, with one clear next milestone pick
- Diminishing-returns and overbuilding risks are called out directly
- New decisions/concerns are written into `STATE.md` and durable project notes
  only when they materially changed
- Cross-session investigation context is written into `.planning/threads/`
  when needed
- Existing phase learnings are updated only when there is a clear, relevant
  destination file
- The command stops after reporting and bookkeeping
</success_criteria>
