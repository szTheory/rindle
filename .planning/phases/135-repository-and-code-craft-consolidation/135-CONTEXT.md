# Phase 135: Repository and Code-Craft Consolidation — Context

**Gathered:** 2026-10-18. The orchestrator wrote this from 135-RESEARCH.md. The user said "go for it" and has a standing "follow your recommendations" preference, so research recommendations are locked here.
**Requirements:** CRAFT-03, CRAFT-04, CRAFT-05, CRAFT-06, HYGIENE-03
**Baseline:** origin/main 4b7b8e33 (0.4.10 on Hex, no open PRs).

<decisions>

## Locked decisions

- **D-135-01 — Scope fence.**
- At most 14 plans and at most 3 tasks per plan. (Amended 2026-10-18 after plan check: the residue tranches touch about 150 files.)
- Residue tranches are mechanical comment, name and identifier rewrites. Their correctness gate is the per-area scanner shard reaching zero `pending-removal`, plus the existing suites.
- Split a tranche into two plans when it exceeds about 30 files: test/rindle, and workflows plus scripts plus generators. Otherwise partition tasks by subdirectory. One squash PR per plan, using the conventional subject named in the plan.
- Never `fix:` or `feat:`, because this phase must not cut a Hex release. Use `ci:`, `test:`, `refactor:`, `chore:` and `docs(135):`.
- If a gate halts twice on the same cause, rescope instead of adding plans.
- Serialize merges that touch `.github/workflows/ci.yml`.

- **D-135-02 — No `.planning/` reads from new live code.**
- Exception (amended 2026-10-18): Phase 133's directory is a retained, non-archivable receipt (D-135-03). A mechanical guard enforces this. The archive simulation must cover 134 and 135 and show CI stays green. It must also show that removing 133 fails with an explicit "retained receipt" message, never an unrelated red.
- New ledgers, allowlists and validators live under `scripts/maintainer/`, `scripts/ci/` or `test/`, never under `.planning/phases/135-*`.
- Archiving any phase directory must not turn CI red.

- **D-135-03 — Phase 133 coupling (research Open Question 1, option a).**
- Leave the receipt-baked `133-EVIDENCE-CENSUS.json` path in `verify_nightly_run.sh` and its test unchanged. The receipt format does not change.
- Record the 133 directory as `retain`, with authority "immutable receipt", in the artifact ledger and as an allowlist entry.
- Copy the failure-fingerprint file that `test_nightly_dialyzer.sh` reads into `scripts/ci/fixtures/` and repoint the script there.

- **D-135-04 — Delete the tracked `.mcp.json`** (Open Question 2).
- It embeds machine-specific absolute paths and has no consumer. Git keeps it recoverable.
- The deletion lands as its own `chore:` commit in the CRAFT-03 PR. The user merging that PR is the authorization.

- **D-135-05 — Contract strings are allowlisted, not rewritten** (Open Question 3).
- Allowlist under class `contract`:
  - user-visible `vX.Y` / planning-era text in `Rindle.Error` messages and public `@moduledoc`s
  - check-run names consumed by scripts, such as `ADMIN-06 Optional Dependencies`
  - telemetry event names
- Any rewording is a separate, explicitly approved, semver-reviewed change outside this phase.

- **D-135-06 — CRAFT-05 pilot is limited to the 5 mechanical-trigger baseline entries** (Open Question 4).
- The entries are `sweep_orphaned_temp_files`, `lifecycle_repair`, `core_checks`, `runtime_checks` and `tus_protocol`.
- Phase 135 is not the "developer-approved phase" that the 13 developer-approved-trigger entries name. Those entries stay in the baseline, as do the 9 other mechanical-trigger entries outside the pilot. (Count corrected 2026-10-18; the baseline has 27 entries.)

- **D-135-07 — Requirement-id test names are renamed to behavior names** (Open Question 5).
- Requirement ids may survive only as allowlisted `policy` entries when the id is itself the present-tense contract.

- **D-135-08 — Readability traceability.**
- Every readability change carries an entry in a tracked `readability_changes.json`.
- Each entry cites a frozen candidate id from `133-213-CENSUS-LEDGER.json` (sha256 embedded, never read at test time), the removed baseline identity, and the proof commands.
- Contract proof is required: `refactor_contract.sh` (SAFE-01) green, `mix credo_quality` green after the baseline shrinks, the public-export snapshot unchanged, and the forbidden-path boundary check clean (release, migration, lock and telemetry surfaces).

- **D-135-09 — Residue scanner ratchet.**
- The allowlist starts seeded with every current hit, each classed as `pending-removal`, `policy`, `contract`, `immutable-receipt` or `fixture`.
- Stale entries are rejected, and entries are keyed by text, not path alone.
- Tranches remove `pending-removal` entries. Phase close asserts zero `pending-removal`.
- The intentional mojibake regression literal is allowlisted as `fixture`.

- **D-135-10 — Generated artifacts are fixed at the generator.**
- Shipped `priv/static/rindle_admin/rindle-admin.css` residue is fixed in `brandbook/src/admin-css-build.mjs`, then regenerated and synced.
- The generated output is never hand-edited.

- **D-135-11 — Hygiene semantics.**
- `repo_hygiene_check.sh` BLOCKs on:
  - fetch failure
  - a wrong branch or detached HEAD, and HEAD behind or ahead of `origin/main`
  - tracked junk
  - generated drift
  - `mix ci` exiting non-zero, or exiting 0 without its completion sentinel
  - untracked or non-allowlisted ignored paths that appear after verification
- `--with-mix-ci` must run `mix ci`.
- The hex-baseline publish race (todo 2026-10-15) is WARN in `--ci` mode and BLOCK in release-prep mode.
- A real-git fixture harness tests every case.
- `--ci` mode deliberately skips generated drift, fetch, branch and `mix ci` (amended 2026-10-18). On PRs, the merge-blocking `brandbook-tokens` job proves generated drift. Local and `--release-prep` modes BLOCK on it.

- **D-135-12 — Remote mutations are authorized actions, never credit** (carried from D-134-05).
- Merges are user-run, or explicitly authorized per PR in chat.
- Requirement credit comes only from executable gates passing on main.

### Claude's Discretion
- Exact JSON schemas, script function names, ledger class granularity, and tranche boundaries within the research delivery table.
- Merging 135-04 into 135-01, or 135-11 into 135-09, if it keeps plans coherent.

</decisions>

## Deferred Ideas
- The validator landing-record and equivalence rule, and the collector's in-progress-jobs bug (todo 2026-10-16). Not in Phase 135 scope.
- Rewording public error messages that contain milestone text (see D-135-05).
- The 13 credo baseline entries whose triggers name a developer-approved phase, and the 9 other mechanical-trigger entries outside the pilot.
</content>
</invoke>
