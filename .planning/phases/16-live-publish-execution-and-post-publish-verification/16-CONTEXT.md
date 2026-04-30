# Phase 16: Live Publish Execution and Post-Publish Verification — Context

**Gathered:** 2026-04-30 (assumptions mode, research-driven via 3 parallel subagents)
**Status:** Ready for planning

<domain>
## Phase Boundary

**Reality reconciliation:** This phase was authored assuming `v0.1.0` was the upcoming first publish. Reality, as of 2026-04-30: rindle `0.1.0–0.1.4` already shipped via release-please autopilot during Phase 15 execution; `mix hex.info rindle` reports `Releases: 0.1.4` live on Hex.pm. SC-1 (tag → publish), SC-2 (`mix deps.get` resolves), and SC-3 (hexdocs.pm browseable) are satisfied retroactively against `0.1.4`.

**Actual phase boundary** — three remaining work items:

1. **Runbook deviation capture (SC-4):** Update `guides/release_publish.md` to encode the lessons from the five `fix(release):` patches (`a7efefd`, `d5c21ad`, `65728e5`, `71a0f99`, `6dd0d54`) that landed during the 0.1.0 → 0.1.4 publish window on 2026-04-29. Plus one outstanding code change those patches imply (`sed`-based `mix.exs` version parsing in `release.yml`).

2. **Recovery-path bug fix:** Make `workflow_dispatch` recovery in `.github/workflows/release.yml` idempotent. Current bug: run `25135467509` (2026-04-29T21:43Z) failed at `Live publish to Hex` with Hex.pm's `Validation error(s) - inserted_at: must include the --replace flag to update an existing release` because the recovery path attempts to republish a version that is already live. `Public Verify` was skipped, not failed — original diagnosis corrected.

3. **SC-5 rehearsal:** Exercise the `mix hex.publish --revert VERSION` runbook before we need it. Current runbook has the **wrong command** (`mix hex.revert rindle VERSION` does not exist; canonical is `mix hex.publish --revert VERSION`). Tabletop rehearsal produces signed evidence in `16-REVERT-REHEARSAL.md`.

Out of scope for this phase: API renames (Phase 17), `@doc`/`@spec` coverage (Phase 18), convenience APIs (Phase 19), retiring `0.1.0–0.1.3` (decision below), publishing `0.1.5` (no library change forces it).

</domain>

<decisions>
## Implementation Decisions

### Work item (a) — Runbook deviation capture

- **D-01:** Restructure `guides/release_publish.md` into a two-tier shape: tight, opinionated happy-path at the top + clearly-fenced **Appendix A: Deviation Log** at the bottom. Drop nothing; only trim verbose prose inside numbered lists.
- **D-02:** Add a **TL;DR cheatsheet** (≤5 lines) at top of file, before "First Public Release."
- **D-03:** Add a **Footguns & Gotchas** section just before the appendices, populated from the inventory in research output A §8 (Hex.pm version immutability, last-version revert deletes package, owner-add is post-publish-only, 8MB/64MB tarball limits, git deps blocked, conventional-commits gate, autorelease-pending label, manual-tag conflicts, `mix docs --warnings-as-errors` is a publish gate, owner key vs API key confusion, component-vs-simple tag shapes, trusted-vs-local publish identity).
- **D-04:** Switch the prose voice from third-person ("the maintainer can…") to second-person imperative ("Run X. Then run Y."), modeled on Phoenix's `RELEASE.md`.
- **D-05:** Inline the deviation log inside `release_publish.md` — do **not** create a separate `RELEASE-LESSONS.md`. Single source of truth, ships to hexdocs, surfaces in `git log guides/release_publish.md`. Use the append-only "newest first" table format from research A §3.
- **D-06:** **Do NOT retire `0.1.0–0.1.3`.** They are not broken library versions; they are pipeline iterations whose code is identical to (or older than) `0.1.4`. Adopters using `~> 0.1.0` already resolve to `0.1.4` (no impact); adopters with exact pins chose that and would only see a confusing warning. Document the pipeline-iteration story in CHANGELOG and the deviation log instead.
- **D-07:** Add a one-line note at the top of `CHANGELOG.md`: "0.1.0–0.1.3 were release-pipeline shakedown iterations; treat 0.1.4 as the first recommended pin." Do not rewrite shipped entries (Hex history is immutable anyway).
- **D-08:** Future first-publishes from any szTheory library should ship `0.1.0-rc.1` first via release-please `prerelease: true`. Capture this as a pattern recommendation for the `bootstrap-elixir-hex-lib` skill — flagged as Deferred Idea below; not encoded in this phase's plan.

### Work item (b) — workflow_dispatch recovery fix

- **D-09:** Add an **idempotency probe step** in the `publish` job, after `Verify version alignment` and before `Dry run Hex publish`. Implementation: a new `scripts/hex_release_exists.sh` that runs `mix hex.info rindle <version>` (exit 0 = exists) with a `curl https://hex.pm/api/packages/rindle/releases/<version>` (HTTP 200 = exists) defense-in-depth fallback. Writes `already_published=true|false` to `$GITHUB_OUTPUT`.
- **D-10:** Gate both `Dry run Hex publish` and `Live publish to Hex` steps on `if: steps.idempotency.outputs.already_published != 'true'`. Skipped steps in a passing job leave job conclusion = success, so `public_verify` (gated on `needs.publish.result == 'success'`) automatically reruns.
- **D-11:** Add an `Idempotent publish summary` final step in the `publish` job that writes a one-line "what just happened" message to `$GITHUB_STEP_SUMMARY`: either "Skipped publish: rindle X.Y.Z was already on Hex.pm." or "Published rindle X.Y.Z to Hex.pm."
- **D-12:** Keep recovery-mode UX as **auto-detect, single mode, zero new inputs**. Do not introduce `verify_only: bool` or `recovery_mode: enum`. The registry answers the question; the maintainer should not have to.
- **D-13:** **`--replace` is forbidden in CI**, period. Document explicitly in `release_publish.md`. The maintainer runs `mix hex.publish --replace --yes` *locally* if and only if they want to mutate a live artifact within the grace window. For docs-only fixes, prefer `mix hex.docs publish` (no version mutation, no time window).
- **D-14:** Tighten the workflow's `concurrency` group to a single global `release-publish-rindle` token (not the current event-conditional split). `cancel-in-progress: false` stays. Reason: different concurrency groups don't block each other, so today a `push`-driven `release-main` and a `workflow_dispatch` `release-recovery-<sha>` can race; with the idempotency probe in place they would no-op safely, but the race still has a thin window where both runners pass the probe and both try `mix hex.publish --yes`. Single shared lock eliminates the race.
- **D-15:** Replace the `sed`-based version parsing in `release.yml` lines 144–152 with `mix run --no-start --no-deps-check -e 'IO.puts(Mix.Project.config()[:version])' | tail -n1 | tr -d '\r'`. This is the canonical Elixir idiom (`Mix.Project.config()[:version]`) and aligns the workflow step with `assert_version_match.sh`. Closes the lesson behind `fix(release): allow indented version parsing` once and for good.
- **D-16:** Rename release.yml steps for 2am-readability: `Live publish to Hex` → `Publish to Hex.pm (live)`; `Wait for Hex.pm index` → `Wait for Hex.pm index (post-publish)`; add `id: live_publish` to the live publish step. Add a top-of-file YAML comment block describing the four-job topology in 6 lines.
- **D-17:** Improve the `HEX_API_KEY` guard error message to point to runbook + Settings path: `"HEX_API_KEY missing/invalid. Configure repo Settings → Environments → release → secret HEX_API_KEY. See guides/release_publish.md 'One-Time Publish Prerequisites.'"`

### Work item (c) — SC-5 revert rehearsal

- **D-18:** Produce `.planning/phases/16-live-publish-execution-and-post-publish-verification/16-REVERT-REHEARSAL.md` as the SC-5 acceptance evidence file. Contents per research C §5 skeleton: identity proof transcript, decision matrix, command-canonicalization proof, communication template walkthrough, runbook-cross-reference signoff.
- **D-19:** Rehearsal exercises **read-only Hex commands only** (`mix hex.user whoami`, `mix hex.owner list rindle`, `mix hex.info rindle 0.1.4`) plus a documented tabletop walkthrough of revert + retire commands with their expected outputs and error modes. Do **not** invoke `mix hex.publish --revert 0.1.4 --yes` against the live package. Reasoning: SC-5 reads "Maintainer **can** execute" — a capability claim, not a "has executed" claim. A correct, documented runbook + read-only auth proof is sufficient evidence; a live revert call risks a destructive-intent audit-log entry on Hex with no marginal evidentiary value beyond the tabletop. (Stretch option flagged in `<specifics>` below.)
- **D-20:** **Fix the wrong command in `guides/release_publish.md` "Rollback and Revert"**: replace `mix hex.revert rindle VERSION` with `mix hex.publish --revert VERSION`. The former does not exist as a Mix task. Verified against `hexpm/hex` source (`lib/mix/tasks/hex.publish.ex` `@switches [revert: :string, ...]`).
- **D-21:** Rewrite the `Rollback and Revert` section as a drop-in replacement using the structure from research C §6: 90-second skim table at top, then Revert (within window), Retire (after window — preferred for runtime breakage), Window-closed fallback (full sequence), Rehearsal evidence pointer, Adopter advisory template pointer.
- **D-22:** Add `mix hex.retire rindle VERSION REASON --message "..."` as a peer procedure to revert. Document valid reasons (`renamed | deprecated | security | invalid | other`), 140-char message limit, `--unretire` reversibility, and the critical caveat: **retire still resolves; lockfiles still install the bad version. Always ship the fix patch alongside retire.**
- **D-23:** Add `mix hex.docs publish` as the documented path for "docs broken, code fine" — no version mutation, no time window, no rollback.
- **D-24:** Include the **adopter advisory template** (research C §7) inline in `release_publish.md`, ready to copy into a GitHub Release note when retire-and-patch fires. Plus the matching commit-message convention (`fix(release): retire <BAD>, ship <FIX>`) and GitHub Release title format.

### Cross-cutting

- **D-25:** All three work items land in a single phase, executed in this order: (b) workflow fix → (c) rehearsal evidence → (a) runbook deviations. Reason: (b) is the actionable bug and produces concrete code changes the runbook in (a) must reflect; (c) verifies the runbook section we are about to expand in (a); (a) lands last to incorporate everything cohesively.

### Claude's Discretion

The following are locked at the agent's judgment based on research; flag for the user only if you object before/during planning:

- Exact YAML indentation, step-id naming, log-line wording in `release.yml`.
- Exact bash style of `scripts/hex_release_exists.sh` (set -euo pipefail, error-handling shape).
- Section ordering inside the Footguns inventory.
- Whether the deviation log entries get headlines, numbered IDs, or just bullet-table rows.
- Markdown rendering choices (tables vs lists) inside the runbook.
- Whether to add a CI lint asserting all `scripts/*.sh` accept `RINDLE_PROJECT_ROOT` (recommend yes; lock under planner discretion).

</decisions>

<specifics>
## Specific Ideas

- **Stretch goal — opt-in only, surfaces if user explicitly approves**: a "live exercise" of `mix hex.publish --revert 0.1.4 --yes` against the closed-revert-window live package. Hex's API enforces the window and returns 422 ("can only modify a release up to one hour after it was created"); the rejection is the proof. Locked **off** by default per D-19 because the marginal evidence value is low and it leaves a destructive-intent entry in Hex audit logs. If the user wants this in the rehearsal, flip the toggle during planning and append the live transcript to `16-REVERT-REHEARSAL.md` §2.

- **Voice reference**: Phoenix's `RELEASE.md` (~27 lines, 10 numbered steps) is the model — terse, imperative, no "you should consider" hedge language.

- **Pattern reference**: `JS-DevTools/npm-publish` `strategy: all` mode is the cross-ecosystem reference for the idempotency probe pattern we are adopting in (b). RubyGems treats duplicate pushes as success server-side — the most pleasant ecosystem behavior; we emulate it client-side because Hex.pm doesn't.

- **Counterexample**: Bandit's `hex_publish.yml` and Tesla's `release.yml` both run `mix hex.publish --yes` blindly with no idempotency. Both would fail identically to rindle on a rerun. After the (b) fix, rindle is more rigorous than its peers — that is a credible differentiator.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or implementing.**

### Phase 16 source artifacts
- `guides/release_publish.md` — current runbook; subject of work items (a) and (c)
- `.github/workflows/release.yml` — current workflow; subject of work item (b)
- `scripts/assert_version_match.sh` — example of correct `mix.exs` version parsing; reference for D-15
- `scripts/public_smoke.sh` — already updated by `6dd0d54`; reference pattern for `MIX_ENV=test` discipline
- `scripts/release_preflight.sh` — already accepts `RINDLE_PROJECT_ROOT`; pattern for D-09's new `scripts/hex_release_exists.sh`

### Project context
- `.planning/PROJECT.md` — milestone goals, security invariants, "publish first then API audit" decision
- `.planning/REQUIREMENTS.md` §Routine Release — RELEASE-01, RELEASE-02 wording (RELEASE-02 = SC-5)
- `.planning/STATE.md` §Decision-Making Preference — "agent decides; escalate only high-impact" — informs why D-19 locks safe-default
- `.planning/STATE.md` §Blockers/Concerns — pre-existing reality-reconciliation note; this CONTEXT closes that loop
- `.planning/phases/15-ci-integrity-and-publish-preflight/15-02-SUMMARY.md` §Notes — already flags run `25135467509` as "a separate concern affecting manual recovery reruns, worth a dedicated phase before the next release"; this is that phase
- `.planning/phases/15-ci-integrity-and-publish-preflight/15-RELEASE-CANDIDATE-CHECKLIST.md` — canonical exact-SHA proof template; the trust-boundary contract carries forward

### Hex / Mix authoritative docs (research-grounded)
- https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html — `--revert` flag canonical syntax; revert window semantics
- https://hexdocs.pm/hex/Mix.Tasks.Hex.Retire.html — retire command, valid reasons (`renamed | deprecated | security | invalid | other`), `--unretire`
- https://hexdocs.pm/mix/Mix.Project.html — `Mix.Project.config()[:version]` is THE canonical version accessor (D-15)
- https://hex.pm/docs/publish — publish + grace window
- https://hex.pm/api/packages/rindle/releases/0.1.4 — HTTP 200 confirms version live (defense-in-depth probe in D-09)

### Peer ecosystem references (cited in research)
- https://github.com/phoenixframework/phoenix/blob/main/RELEASE.md — voice/structure model for runbook (D-04)
- https://github.com/JS-DevTools/npm-publish — idempotency-probe pattern reference (D-09)
- https://github.com/mtrudel/bandit/blob/main/.github/workflows/hex_publish.yml — Elixir peer baseline (no idempotency)
- https://github.com/teamon/tesla/blob/master/.github/workflows/release.yml — Elixir peer baseline (no idempotency)
- https://docs.rust-lang.org/cargo/commands/cargo-yank.html — yank-before-fix vs fix-before-yank pattern (informs D-22)
- https://peps.python.org/pep-0592/ — yank semantics (informs adopter advisory wording)

### Failed run under investigation
- https://github.com/szTheory/rindle/actions/runs/25135467509 — recovery dispatch that exposed the bug (job `Publish to Hex`, step `Live publish to Hex`, conclusion `failure`, error `Validation error(s) - inserted_at: must include the --replace flag to update an existing release`)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/release_preflight.sh`, `scripts/assert_version_match.sh`, `scripts/public_smoke.sh`, `scripts/install_smoke.sh` already accept `RINDLE_PROJECT_ROOT` — pattern is established and load-bearing. New `scripts/hex_release_exists.sh` (D-09) follows the same convention.
- `mix hex.info <pkg> <version>` exit-code semantics (0 = exists, 1 = missing) is already used downstream in the `Wait for Hex.pm index` step — reusing it for the idempotency probe (D-09) keeps the workflow consistent.
- `Mix.Project.config()[:version]` is already used inside `assert_version_match.sh`; D-15 aligns the workflow step with the script that follows it.
- `release_docs_parity_test.exs` and `package_metadata_test.exs` already enforce a parity contract between `release_publish.md` and the live workflow. Any runbook change in (a) and (c) MUST keep these tests green; planner should plan to update assertions where necessary.

### Established Patterns
- **"Current tooling, frozen source"** via `RINDLE_PROJECT_ROOT` worktree: tooling = `main` HEAD; source = `recovery_ref` (immutable). Already shipped in `71a0f99`. Document explicitly as an Architecture Note in `release_publish.md` Appendix B (per research A §6).
- **Two-job split with `gate-ci-green`**: rindle's pattern (push or recovery → gate on exact-SHA green CI → publish → public verify) is more rigorous than Phoenix-ecosystem peers; preserve and document.
- **Diagnostic-vs-authoritative distinction** (local preflight is diagnostic; remote CI on exact SHA is authoritative). Already encoded; trust boundary is solid; do not relax.
- **Conventional commits + release-please autopilot**: keep. The 5 `fix(release):` patches landed cleanly through this exact flow.

### Integration Points
- New `scripts/hex_release_exists.sh` lands as a sibling to existing release scripts; same `RINDLE_PROJECT_ROOT` env contract.
- `release.yml` `publish` job receives 1 new step + 2 modified `if:` conditions + 1 new summary step.
- `guides/release_publish.md` receives 3 large edits: TL;DR top + Footguns section + Appendices A/B (work item a); Recovery Workflow Contract update (work item b); Rollback and Revert rewrite (work item c).
- `CHANGELOG.md` receives a one-line top-of-file note (D-07).
- `release_docs_parity_test.exs` may need updated assertions to cover new runbook content (`mix hex.publish --revert`, `mix hex.retire`, idempotent recovery contract).
- `.planning/phases/16-live-publish-execution-and-post-publish-verification/16-REVERT-REHEARSAL.md` is a new evidence file; not shipped.

### Code-level changes count
- **5 files modified, 1 file created, 1 evidence file produced.** Modified: `.github/workflows/release.yml`, `guides/release_publish.md`, `CHANGELOG.md`, `scripts/release_preflight.sh` (only if planner finds an issue), `test/install_smoke/release_docs_parity_test.exs`. Created: `scripts/hex_release_exists.sh`. Evidence: `.planning/phases/16-.../16-REVERT-REHEARSAL.md`. Phase has no library-runtime code changes.

</code_context>

<deferred>
## Deferred Ideas

- **Future first-publish strategy** — adopt `0.1.0-rc.1` prerelease pattern via release-please `prerelease: true` for the next szTheory library bootstrap. Captured here from research A §7. Lands in the `bootstrap-elixir-hex-lib` skill, not in rindle. (Add to GSD backlog.)

- **`hex.docs publish` as a CI job** — currently docs are uploaded as part of `mix hex.publish`; a dedicated docs-only republish lane could fix doc rot without touching versions. Out of scope for v1.3; revisit if doc updates outpace code releases.

- **Live revert audit-log evidence** — opt-in stretch (see `<specifics>`). Surfaces if user explicitly enables.

- **CI lint asserting `RINDLE_PROJECT_ROOT` discipline in new shell scripts** — research A §6 recommendation. Lock under planner discretion (D-25 Cross-cutting). If planner judges it cheap enough to land in this phase, do it; otherwise, defer.

- **Squash-merge enforcement / non-conventional-commit rejection** — currently relies on maintainer discipline; release-please silently ignores non-conventional commits. Out of scope; revisit if the `fix(release):` discipline drifts.

- **Local `hexpm/hexpm` server for full-fidelity revert rehearsal** — research C §4 considered and rejected as disproportionate. Capture as a "if we ever need full-fidelity" note; not actionable now.

### Reviewed Todos (not folded)
None — no GSD todos matched this phase per `gsd-sdk query todo.match-phase` (todo_count=0 expected for this scope).

</deferred>

---

*Phase: 16-live-publish-execution-and-post-publish-verification*
*Context gathered: 2026-04-30 (assumptions mode + 3 parallel research subagents)*
*Research artifacts: A (runbook idioms), B (workflow_dispatch recovery), C (revert rehearsal) — full transcripts in DISCUSSION-LOG.md*
