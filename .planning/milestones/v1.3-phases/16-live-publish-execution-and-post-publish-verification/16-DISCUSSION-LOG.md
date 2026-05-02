# Phase 16: Live Publish Execution and Post-Publish Verification — Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `16-CONTEXT.md` — this log preserves the analysis and research provenance.

**Date:** 2026-04-30
**Phase:** 16-live-publish-execution-and-post-publish-verification
**Mode:** assumptions (per `workflow.discuss_mode = "assumptions"`)
**Areas analyzed:** Runbook deviation capture (a); workflow_dispatch recovery fix (b); SC-5 revert rehearsal (c)
**Research depth:** 3 parallel `general-purpose` subagents covering Elixir/Hex idioms, GitHub Actions release-recovery patterns, Hex revert/retire semantics — peer ecosystems sampled (Phoenix, Ecto, Plug, Bandit, Oban, Tesla, Req, Finch, npm changesets, JS-DevTools/npm-publish, RubyGems, Cargo, PyPI)
**User interaction surface:** zero blocking questions (per STATE.md "agent decides; escalate only high-impact" + saved feedback memory). One opt-in stretch goal flagged in CONTEXT `<specifics>`.

## Reality Reconciliation Reframe

Phase 16 was authored assuming `v0.1.0` was the upcoming first publish. Verified against current repo state on 2026-04-30:

- `mix hex.info rindle` → `Releases: 0.1.4`
- Live SHA `6dd0d54` (HEAD of main) — green CI run `25135464796`
- SC-1, SC-2, SC-3 retroactively satisfied against `0.1.4`
- SC-4 (runbook deviations) and SC-5 (revert rehearsal) were still undone
- One bug surfaced during the publish run: `workflow_dispatch` recovery path (run `25135467509`) failed with `Validation error(s) - inserted_at: must include the --replace flag to update an existing release`

Reframed phase scope = (a) update runbook for deviations + (b) fix the recovery-path idempotency bug + (c) exercise SC-5 by tabletop rehearsal. Original SCs 1–3 are evidenced retroactively; this phase delivers SCs 4–5 plus the latent bug fix.

## Assumptions Presented (locked without correction)

### Area: Work item (a) — runbook deviation capture

| Assumption | Confidence | Evidence |
|---|---|---|
| Inline `Appendix A: Deviation Log` beats a separate `RELEASE-LESSONS.md` | Confident | Cargo Book release process, release-plz docs, Bandit CHANGELOG headers all converge on inline pattern; ships to hexdocs; single source of truth |
| Per-fix tabular structure (Symptom / Commit / Root cause / Permanent fix) | Confident | Standard incident-postmortem shape; readable at 2am |
| Voice should switch to second-person imperative | Confident | Phoenix `RELEASE.md` is the ecosystem reference (~27 lines, 10 imperative steps) |
| Do NOT retire `0.1.0–0.1.3` | Confident | They are not broken library versions; pipeline iterations only; `~> 0.1.0` adopters resolve to `0.1.4` already; exact-pin adopters chose that and would see a confusing warning |
| Add CHANGELOG top-of-file note explaining 0.1.0–0.1.3 as pipeline iterations | Confident | Hex history is immutable; cannot rewrite shipped entries; in-place note is the honest signal |
| `0.1.0-rc.1` prerelease for future first-publishes | Likely | Bandit, LiveView, Ash use this pattern; release-please supports `prerelease: true`; defer to `bootstrap-elixir-hex-lib` skill, not this phase |

### Area: Work item (b) — workflow_dispatch recovery fix

| Assumption | Confidence | Evidence |
|---|---|---|
| Root cause = no idempotency check before `mix hex.publish --yes` | Confident | Run `25135467509` log: `Validation error(s) - inserted_at: must include the --replace flag to update an existing release` after 100% upload progress; Hex.pm correctly rejected |
| `mix hex.info <pkg> <version>` exit code is the canonical idempotency probe | Confident | Verified against `hexpm/hex` source; 0 = exists, 1 = missing; no API key required; mirror-aware; consistent with downstream `Wait for Hex.pm index` step |
| Auto-detect single mode > `verify_only` input | Confident | The registry already knows the answer; forcing the maintainer at 2am to know which Case before opening dispatch form is a footgun (changesets/action README explicitly calls out this gap) |
| `--replace` forbidden in CI | Confident | Mutates published artifact; only valid in 1h grace window for routine versions; supply-chain footgun if automated; safer alternative for docs-only is `mix hex.docs publish` |
| Concurrency group must be a single global token | Confident | GitHub Actions docs: different concurrency groups don't block each other; current event-conditional split allows `push`-driven and `workflow_dispatch` to race; single shared `release-publish-rindle` group eliminates it |
| Replace `sed`-based version parsing with `mix run --no-start --no-deps-check -e ...` | Confident | `Mix.Project.config()[:version]` is THE canonical accessor (Mix docs); already used in `assert_version_match.sh`; closes the lesson behind `fix(release): allow indented version parsing` |

### Area: Work item (c) — SC-5 revert rehearsal

| Assumption | Confidence | Evidence |
|---|---|---|
| Current runbook command `mix hex.revert rindle VERSION` does not exist | Confident | `hexpm/hex` source: only `hex.publish`, `hex.retire`, `hex.owner`, etc.; no `hex.revert` Mix task; canonical form is `mix hex.publish --revert VERSION` |
| Tabletop rehearsal + read-only auth proof = sufficient SC-5 evidence | Confident | SC-5 wording is "Maintainer **can** execute" — capability claim, not has-executed claim; correct documented runbook + read-only auth proof satisfies the claim; live revert call adds destructive-intent audit-log entry without marginal evidence value |
| `mix hex.retire` belongs alongside `mix hex.publish --revert` in the runbook | Confident | `mix hex.publish --revert` only valid within window (1h routine, 24h first publish); `hex.retire` is the only tool after window closes; current runbook is silent on retire |
| Adopter advisory template belongs inline in the runbook | Confident | Communication is the actual control after retire (lockfiles still resolve retired versions; warnings only on `deps.get`); template-ready-to-paste reduces incident-time friction |
| Live `--revert 0.1.4 --yes` against closed-window package is technically safe but evidentially marginal | Likely → locked off | Hex enforces window via 422 rejection; Subagent C agreed this is non-destructive; flagged as opt-in stretch in CONTEXT `<specifics>` so user can flip on if desired |

### Area: Cross-cutting

| Assumption | Confidence | Evidence |
|---|---|---|
| Execution order = (b) → (c) → (a) | Confident | (b) produces concrete code changes the runbook in (a) must reflect; (c) verifies the runbook section (a) expands; (a) lands last to incorporate everything cohesively |
| Single phase, not split | Confident | All three work items share the same code surface (`release.yml`, `release_publish.md`); splitting would force duplicate parity-test churn; sub-day execution time per work item suggests one phase is right-sized |
| `release_docs_parity_test.exs` may need new assertions | Likely | Currently locks runbook to live workflow contract; new content (`--revert`, `--retire`, idempotency) may need explicit parity coverage; planner discretion to scope |

## Corrections Made

**None.** All assumptions confirmed via STATE.md "agent decides" stance + research evidence. The user's saved feedback memory ("research-driven one-shot recommendations; escalate only VERY impactful items") aligned with the assumptions-mode default flow.

## Auto-Resolved (Unclear → Recommended Default)

- **Live revert call against 0.1.4** (Likely → off-by-default). Locked safe; flagged as opt-in stretch in CONTEXT `<specifics>` for user to flip if they want destructive-intent audit-log evidence.
- **`hex.retire` 0.1.0–0.1.3** (Unclear → no). Locked no; CHANGELOG note + deviation log entry capture the story without affecting adopters.
- **CI lint for `RINDLE_PROJECT_ROOT` discipline** (Unclear → planner discretion). Locked as planner judgment call inside this phase, not a separate phase.

## External Research

### Subagent A — Elixir/Hex runbook idioms (251K-token research, 36 tool uses, 4m duration)
Key findings: two-tier runbook structure (happy-path top + Appendix A: Deviation Log); per-fix tabular pattern; Phoenix RELEASE.md as voice/structure reference; `Mix.Project.config()[:version]` as canonical version accessor; `0.1.0-rc.1` prerelease pattern for future first-publishes; full footgun inventory (12 items). Output recommended `mix hex.retire 0.1.0–0.1.3 invalid` — *rejected* on user-impact analysis (D-06).

### Subagent B — workflow_dispatch recovery research (54K-token research, 44 tool uses, 4m duration)
Key findings: `mix hex.info` exit-code semantics is the canonical idempotency probe; `--replace` forbidden in CI; concurrency group must be single global token; defense-in-depth `curl https://hex.pm/api/...` as fallback; `JS-DevTools/npm-publish` `strategy: all` as cross-ecosystem pattern reference; Bandit + Tesla peer baselines lack idempotency (rindle becomes more rigorous); 10-item footgun checklist with mitigation status.

### Subagent C — Hex revert/retire research (41K-token research, 20 tool uses, 3m duration)
Key findings: canonical command is `mix hex.publish --revert VERSION` (not `mix hex.revert`); `hex.retire` valid reasons + 140-char message + `--unretire`; tabletop rehearsal sufficient for SC-5 capability claim; `--dry-run` is silently ignored on revert path (destructive on first call); reverting last version deletes package; admin-removed versions are permanently reserved (user-revert versions can be reused); adopter advisory template; full decision matrix covering revert/retire/docs-republish/key-rotation/owner-change/admin-removal.

## Sources Consulted (deduplicated across subagents)

- hexdocs.pm/hex (Mix.Tasks.Hex.Publish, Mix.Tasks.Hex.Retire)
- hexdocs.pm/mix (Mix.Project, Mix.Tasks.Run)
- hex.pm/docs (publish, faq)
- hex.pm/api/packages/rindle/releases/0.1.4
- github.com/hexpm/hex (lib/mix/tasks/hex.publish.ex, lib/mix/tasks/hex.retire.ex)
- github.com/phoenixframework/phoenix/blob/main/RELEASE.md
- github.com/mtrudel/bandit/blob/main/.github/workflows/hex_publish.yml
- github.com/teamon/tesla (release.yml + release-please.yml)
- github.com/oban-bg/oban (CHANGELOG-as-source-of-truth pattern)
- github.com/wojtekmach/req/blob/main/CHANGELOG.md
- github.com/elixir-tesla/tesla/blob/master/CONTRIBUTING.md
- github.com/JS-DevTools/npm-publish (strategy: all)
- github.com/changesets/action (explicit non-mitigation)
- github.com/rubygems/rubygems.org (idempotent-push behavior)
- github.com/npm/cli/issues/4927, github.com/npm/rfcs/issues/387
- github.com/orgs/community/discussions/9252 (concurrency race discussion)
- github.com/szTheory/rindle/actions/runs/25135467509 (failed run under investigation)
- elixirschool.com/blog/managing-releases-with-release-please
- conventionalcommits.org/en/v1.0.0
- github.com/googleapis/release-please, github.com/googleapis/release-please-action
- github.com/zachdaniel/git_ops
- github.com/crate-ci/cargo-release
- doc.crates.io/contrib/process/release.html
- doc.rust-lang.org/cargo/commands/cargo-yank.html
- doc.rust-lang.org/cargo/reference/publishing.html
- rust-lang.github.io/rust-project-goals/2024h2/yank-crates-with-a-reason.html
- peps.python.org/pep-0592/, docs.pypi.org/project-management/yanking/
- github.com/rubygems/bundler/issues/2277, github.com/rubygems/bundler/issues/3500
- github.com/rubygems/rfcs/issues/34
- docs.npmjs.com/policies/unpublish/
- blog.npmjs.org (left-pad incident, unpublish policy change)
- en.wikipedia.org/wiki/Npm_left-pad_incident
- paraxial.io/blog/hex-security
- docs.github.com/en/actions (concurrency, conditional jobs)
- docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases
- git-scm.com/docs/git-worktree
- blog.orhun.dev/automated-rust-releases

## Decision-Making Preference Honored

Per `.planning/STATE.md` "Decision-Making Preference":

- **Default**: agent decides discussion/planning details ✓
- **Escalate only for high-impact**: public API/semver, destructive data, security/compliance, irreversible infra/cost, scope shifts
- **Workflow preference**: skip discuss by default, move directly into planning/execution

Plus user-saved feedback memory `feedback_research_driven_one_shot.md`: "research-driven one-shot recommendations; escalate only VERY impactful items."

**Outcome:** Zero blocking AskUserQuestion calls. One stretch goal flagged in CONTEXT `<specifics>` (live revert call) for opt-in only. Three parallel research subagents produced ~12K words of synthesized recommendations; the locked decisions in CONTEXT.md are the coherent one-shot answer.

---

*Discussion gathered: 2026-04-30*
*Mode: assumptions; 0 user corrections; 3 research subagents*
