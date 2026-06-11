# Agent notes (rindle)

## GSD model routing in Cursor

This repo uses a **Cursor-only** GSD overlay (see `.planning/config.json`):

- **Planning / research subagents** → `auto` (Auto+Composer usage pool)
- **Execution / verify subagents** → `composer-2.5`

Global defaults in `~/.gsd/defaults.json` stay **`balanced`** for Codex, Gemini, and Claude Code.

### Manual backup (if overrides do not apply)

| Stage | Cursor model picker | Command |
|-------|---------------------|---------|
| Discuss / plan | **Auto** | `/gsd-discuss-phase`, `/gsd-plan-phase` |
| Execute / verify | **Composer** | `/gsd-execute-phase` |

Check [cursor.com/dashboard](https://cursor.com/dashboard) — usage should hit **Auto + Composer**, not API tier models.

### Verify resolution

```bash
gsd-sdk query resolve-model gsd-planner
gsd-sdk query resolve-model gsd-executor
```

Expected in this repo: `auto` and `composer-2.5` (not `opus` / `sonnet`).

### Pilot checklist (2026-05-27)

Config verification (automated):

- [x] `gsd-sdk query resolve-model gsd-planner` → `auto`
- [x] `gsd-sdk query resolve-model gsd-executor` → `composer-2.5`
- [x] `init.execute-phase` → `executor_model: composer-2.5`, `verifier_model: composer-2.5`

Usage pool (manual — on your next GSD run):

- [ ] Set picker to **Auto**, run `/gsd-discuss-phase` or `/gsd-plan-phase`
- [ ] Set picker to **Composer**, run `/gsd-execute-phase`
- [ ] Confirm [cursor.com/dashboard](https://cursor.com/dashboard) **Auto + Composer** bar moves, not API tier

If subagents still bill API models, fall back to manual picker only (remove `model_overrides` from `.planning/config.json`, keep `inherit` + `omit`).

## Repository workflow

**Contributors:** follow [`guides/release_publish.md`](guides/release_publish.md) and [`RUNNING.md`](RUNNING.md) for CI lanes and release gates. When **`.planning/`** is present, it holds milestone context for maintainers.

**Automated coding agents:** honor the constraints in this file; keep edits focused, run the checks **RUNNING.md** names for your change, and update **`.planning/PROJECT.md`** when you intentionally change product scope or shipped claims.

For UI/admin-console work, follow [guides/ui_principles.md](guides/ui_principles.md) before changing console, Cohort, E2E, or visual-polish surfaces.

Agents should default to the repo's **green-main release train** posture:

- keep `main` green on merge-blocking CI jobs (Quality/coveralls, Integration, Proof, Package Consumer, Adopter)
- prefer **PR-first** execution for serious milestone or feature-depth work (see [`.planning/DEVELOPMENT-TRAIN.md`](.planning/DEVELOPMENT-TRAIN.md))
- avoid speculative milestone reopening during `demand-gated-pause` unless LIFE-06 or STREAM-10 signal exists
- when the release train is idle and there is no approved work item, say so plainly instead of inventing work (**silence on the wire** — see [`.planning/RELEASE-TRAIN.md`](.planning/RELEASE-TRAIN.md))

Before release prep, run `./scripts/maintainer/repo_hygiene_check.sh`.
