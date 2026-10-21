# Agent notes (rindle)

## GSD model routing

This project currently runs GSD through **Codex**: `.planning/config.json` sets
`runtime` to `codex`. Tier routing lives in `model_profile_overrides`, per runtime:

- `claude`: `claude-opus-5-5` (opus tier), `claude-sonnet-5-5` (sonnet tier), `claude-haiku-5-5` (haiku tier)
- `codex`: `gpt-6.1-sol` for the opus tier (including the planner and debugger), `gpt-6-luna`
  for both the sonnet and haiku tiers

Keep these project-level overrides in sync with any intentional model-routing changes.

GSD parallelization and worktree isolation are enabled for this project. The GSD
Codex adapter uses worktrees when the active Codex session supports them and fails
closed when it does not.

## Repository workflow

**Contributors:** follow [`guides/release_publish.md`](guides/release_publish.md) and [`RUNNING.md`](RUNNING.md) for CI lanes and release gates. When **`.planning/`** is present, it holds milestone context for maintainers.

**Automated coding agents:** honor the constraints in this file; keep edits focused, run the checks **RUNNING.md** names for your change, and update **`.planning/PROJECT.md`** when you intentionally change product scope or shipped claims.

**Automation-first acceptance:** active requirements must close through executable tests, probes, or
evidence collectors—not human verification or UAT. Human checkpoints may authorize credentials or
irreversible actions, but their response must not satisfy a requirement. If acceptance cannot yet be
automated, add the automation-enablement work or leave the requirement open. After changing active
planning artifacts, run `./scripts/maintainer/automation_first_contract.sh`.

For UI/admin-console work, follow [guides/ui_principles.md](guides/ui_principles.md) before changing console, Cohort, E2E, or visual-polish surfaces.

Agents should default to the repo's **green-main release train** posture:

- keep `main` green on merge-blocking CI jobs (Quality/coveralls, Integration, Proof, Package Consumer, Adopter)
- prefer **PR-first** execution for serious milestone or feature-depth work (see [`.planning/DEVELOPMENT-TRAIN.md`](.planning/DEVELOPMENT-TRAIN.md))
- avoid speculative milestone reopening during `demand-gated-pause` unless LIFE-06 or STREAM-10 signal exists
- when the release train is idle and there is no approved work item, say so plainly instead of inventing work (**silence on the wire** — see [`.planning/RELEASE-TRAIN.md`](.planning/RELEASE-TRAIN.md))

Before release prep, run `./scripts/maintainer/repo_hygiene_check.sh`.
