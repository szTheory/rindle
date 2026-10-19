# Phase 135: Repository and Code-Craft Consolidation - Research

**Researched:** 2026-10-18
**Domain:** Repository hygiene tooling (bash + jq + git pathspecs), static residue scanning (ExUnit/Elixir script), behavior-preserving readability refactors, release-train safety
**Confidence:** HIGH on repo facts and gaps (every count and quote below was produced or read in this session); MEDIUM on the proposed ledger/scanner shape and the public-surface snapshot (design recommendations, not yet prototyped); LOW only where tagged `[ASSUMED]`.

Read-only investigation. No repository file was modified except this document. Probes that write
(`mix hex.build --unpack`, the three brandbook generators) were run against scratch output or proved
idempotent (`git status` clean afterwards). `git fetch` was deliberately NOT run (shared refs).

<user_constraints>
## User Constraints (from CONTEXT.md)

No `135-CONTEXT.md` exists for this phase (`skip_discuss: true`). Constraints are inherited from the
orchestrator brief, `AGENTS.md`, project memory and the ROADMAP/REQUIREMENTS text.

### Locked Decisions (inherited, treat as locked)
- **Automation-first acceptance** (AGENTS.md): every requirement closes through executable tests, probes or collectors. Human checkpoints may authorize credentials or irreversible actions but never satisfy a requirement. After changing active planning artifacts run `./scripts/maintainer/automation_first_contract.sh`.
- **Green-main release train**: PR-first; squash merge with a conventional `--subject`; `fix:`/`feat:` cut a Hex release, so readability/scan work uses `refactor:` / `test:` / `ci:` / `chore:` / `docs:` only.
- **PR branches must be faithful** (memory `reference_pr_branch_must_be_faithful`): never filter `.planning/`; build the PR branch tree-identical to main (`git branch <pr> main`); draft PR for CI observation.
- **No `.planning/phases/135-*` path may be read by live code** (the Phase 133/134 archive-breaks-CI debt, D-134-02 precedent). Durable artifacts live at stable non-phase paths.
- **No bespoke qualification framework** (D-134-01 scope-fence lesson from the 213-plan Phase 133): target a small plan count, <= 3 tasks per plan, stop and rescope instead of adding plans when a gate halts twice.
- **Contract preservation** (ROADMAP SC3 / milestone overview): no drift in public API, schema/migrations, telemetry, error vocabulary, release coupling, supported behavior, or the accepted PR timing envelope.
- Preserve `ci.yml`, workflow `CI`, the sole required `CI Summary` context, fork safety, exact-SHA release coupling.

### Claude's Discretion
Ledger file location and shape, scanner language, allowlist format, tranche order, which `credo` baseline
entries to use for CRAFT-05, how to rework the hygiene script, plan/wave/PR breakdown. All recommended below.

### Deferred Ideas (OUT OF SCOPE)
- GitHub App migration for release PATs (`.planning/todos/pending/2026-10-15-replace-release-pats-with-github-app.md`, due about 2026-11-15) - user-authorized remote action, not repo craft.
- Complexity-ledger ratchet, Dialyzer ledger, coverage floor, issue #42 experiment, CI timeout/cache structure, DX command map (Phase 136: MAINT-04, TYPE-03, COV-06, TEST-08, CI-15, CI-16, DX-05).
- Twin and recovery matrix (Phases 137-139).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CRAFT-03 | Every tracked, ignored, generated, or candidate artifact has documented authority, consumer, package status, retain/delete/ignore disposition | Artifact inventory (2,840 tracked files, 14 ignore rules, 183 shipped files), ledger design using git pathspec partition, package-set equality test, regeneration binding (see "Artifact Ledger Design") |
| CRAFT-04 | Planning-era identifiers in live code/tests/scripts/config/workflows removed or rewritten unless allowlisted present-tense policy reason | Measured census: 1,085 distinct lines / 186 files across 7 identifier classes; allowlist-with-ratchet design; tranche plan; contract-adjacent exceptions (see "Residue Scanner Design") |
| CRAFT-05 | Readability changes originate from the frozen candidate ledger and improve naming/cohesion/ownership/failure semantics while preserving contracts | Candidate-to-requirement map (12 candidates); trace file design; pilot set from the `quality-maintainability-curated-complexity` baseline; existing `refactor_contract.sh` (SAFE-01) plus two small additions (see "CRAFT-05") |
| CRAFT-06 | Mojibake, duplicated prose, obsolete narration, mechanically proven residue removed, with automated regression scan | Real hits found (4 mojibake lines, 1 duplicated-prose block, ~6 narration sites); scanner classes with false-positive calibration |
| HYGIENE-03 | Hygiene fails honestly on fetch failure, wrong branch, tracked junk, generated drift, incomplete `mix ci`, post-verification residue | Line-level gap analysis of `repo_hygiene_check.sh`; rework design with a git-repo-backed harness; hex-baseline race todo folded in (see "HYGIENE-03") |
</phase_requirements>

## Summary

The repo is in better mechanical shape than the requirement text implies for some classes and much worse
for others. **Mojibake is tiny** (4 lines in 2 test files, one pair is an intentional regression literal),
**duplicated prose is rare** (one real wrap-seam duplication in `mix.exs:301-306`), and **obsolete
narration is small** (about 6 true sites; the rest of the 29 keyword hits are legitimate domain wording such as
"previously advertised capability" in `Rindle.Error`). **Planning-era identifiers are the bulk of the work**:
1,085 distinct lines in 186 live files (decision ids `D-NN-NN` ~413 lines, requirement ids ~309, `Phase N` ~169,
`UI-SPEC`/`CR-`/`WR-` ~167, `.planning/` ~81, `vX.Y` ~76, `Plan N` ~47; classes overlap and are upper bounds). They sit
mostly in tests (615 lines), workflows/actions (185), `examples/` (101), `lib/` (98), `scripts/` (126),
`brandbook/src` (57). Two coupling hazards are real: merge-blocking Proof-lane scripts still read
`.planning/phases/133-...` files (archiving Phase 133 would red CI), and the Hex-shipped CSS carries 13
planning-id lines that originate in a generator.

`repo_hygiene_check.sh` (276 lines, no test harness) is **dishonest in exactly the six ways HYGIENE-03
lists**: fetch failure is swallowed (`|| true`), branch is only printed (and a detached HEAD "passes" as `HEAD`),
tracked junk and generated drift are not checked at all, `--with-mix-ci` runs `mix test` not `mix ci`, and no residue
check exists. `--ci` mode (used on push:main only) skips every local check. The proposed approach reuses the Phase 134
pattern that worked: stable-path JSON ledger + bash/jq validator + fixture harness in `ci-script-tests`, plus an
ExUnit wrapper where `mix` is needed.

**Primary recommendation:** Build three independent mechanisms first (artifact ledger + validator, live-residue scanner with a
removal-only baseline allowlist, hygiene rework with a real-git harness), then burn the residue baseline down in
directory tranches (one `refactor:`/`test:`/`ci:` PR each), land a small candidate-traced CRAFT-05 pilot (5 complexity/nesting
baseline entries that have dedicated tests and no "developer-approved" gate), and close by flipping the scanner to "zero
pending-removal entries". Roughly 11 plans in 5 waves, no `fix:`/`feat:` commit anywhere.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Artifact ledger authoring + completeness/partition check | Maintainer scripts (`scripts/maintainer`, bash+jq, git pathspec) | ExUnit (package-set equality, needs `mix hex.build`) | `ci-script-tests` has no Elixir toolchain; shape/partition is pure git+jq. Package unpack needs Mix |
| Regeneration drift detection | Existing `brandbook-tokens` CI job (merge-blocking, repo-gated) | `repo_hygiene_check.sh` local mode (reads ledger `regenerate` entries) | One source of truth for generator commands; CI already enforces on PR |
| Residue scanning (planning ids, mojibake, dup prose, narration) | ExUnit wrapper in Quality lane over a self-contained `.exs` scanner | Local CLI (`mix run --no-start`) for baseline regeneration | Regex power + fixtures; mirrors `planning_path_hygiene_test.exs`, `async_safety_guard_test.exs`, `evidence_census_test.exs` |
| Readability trace + boundary proof | `scripts/maintainer/` JSON trace + existing `refactor_contract.sh` (Contract job) | New public-surface snapshot ExUnit test | Behavior proof already merge-blocking; add export-level snapshot |
| Repo hygiene gate | `scripts/maintainer/repo_hygiene_check.sh` (local release-prep + `--ci` on push:main) | Harness `scripts/ci/test_repo_hygiene_check.sh` in `ci-script-tests` | Honest failure is proven only by a harness that forces each failure |
| Release coupling guard | Existing `release_guard_meta_test.exs`, `release.yml` | CRAFT-05 boundary check forbids touching them | Readability work must never touch release surfaces |

## Standard Stack

No new packages. Everything uses tools already required by the repo.

### Core
| Tool | Version (verified here) | Purpose | Why Standard |
|------|-------------------------|---------|--------------|
| bash | system 3.2-compatible code style | Validators and the hygiene script | Phase 134 scripts are written to bash 3.2 / jq 1.6 (no `mapfile`, no jq-1.7-only builtins) [CITED: `scripts/maintainer/validate_inbox_ledger.sh` header] |
| jq | /usr/bin/jq present; CI runner version `[ASSUMED]` 1.6 | Ledger rules | Existing validator pattern |
| git pathspec magic (`:(glob)`, `:(exclude)`) | git present | Partition/completeness without re-implementing globbing | `git ls-files` already evaluates pathspecs; avoids bespoke glob code [ASSUMED: works as described; prototype in plan 135-01 task 1] |
| ExUnit (Elixir 1.17.3 / OTP 27.3.4.15 locally; matrix 1.15/OTP 26 + 1.17/OTP 27 in CI) | `.tool-versions`: elixir 1.17.3-otp-27 | Scanner wrapper, package-set test, surface snapshot | Existing static-scan tests are ExUnit |
| Node 20.18.1 | `node --version` here; `.tool-versions` nodejs 20.18.1 | Brandbook generators (zero npm deps for the three used by `mix ci`) | Already used by `mix ci` and `brandbook-tokens` |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `mix hex.build --unpack -o <dir>` | Real shipped-file set (183 files verified) | Package-exclusion equality test and one-off ledger authoring |
| `mix credo_quality` | Complexity baseline equality (`cmp` of normalized multisets) | CRAFT-05 pilot: proves baseline shrink is exactly the removed findings |
| `bash scripts/maintainer/refactor_contract.sh` (SAFE-01) | Compile-connected cycle gate + 8 contract test files | CRAFT-05 behavior/boundary proof per PR |
| `shellcheck` (present locally) | Lint new bash | Optional local check; not wired in CI today `[ASSUMED]` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| JSON ledger + bash/jq validator | `.exs` validator | `.exs` needs the Elixir toolchain; `ci-script-tests` is "pure bash + jq, no project toolchain" [CITED: ci.yml:1461-1465 comment]. Use bash+jq for shape/partition; ExUnit only where Mix is unavoidable |
| ExUnit/`.exs` residue scanner | bash + `git grep` + jq | Allowlist matching on (path, class, normalized-line) is clumsy in jq; ExUnit gives regex lookbehind and fixture trees. Pattern precedent: `evidence_census_test.exs` runs `mix run --no-compile --no-start <script>` |
| Per-file artifact ledger rows | Class rows with pathspecs | 2,840 per-file rows rot; 40-60 class rows with a partition check stay reviewable |

**Installation:** none.

## Package Legitimacy Audit

No external package is installed by this phase. `gsd-tools package-legitimacy check` was not run because no
dependency is added (consistent with Phase 134).

**Packages removed due to [SLOP] verdict:** none. **Packages flagged [SUS]:** none.

## Frozen Candidate Ledger Map (CRAFT-05 / SC3 traceability)

Authority: `.planning/phases/133-evidence-charter-and-live-truth/133-213-CENSUS-LEDGER.json`
[VERIFIED: Read this session], `"subject_sha": "3858267b4837d04367f1d26b1ee74651e507ea77"`,
file sha256 `a56c8b6e68e68a84c1355247359733e60be9596a6582a4525488b5d23880bde4` [VERIFIED: `shasum -a 256`].
The older `133-EVIDENCE-CENSUS.json` (subject `9bb10539...`, sha256 `df484acd...`) has the identical 12 candidate
ids and identical dispositions [VERIFIED: python compare]; it is the Nightly-receipt authority path and must not be moved (see Pitfall 4).
12 candidates: 9 `fix`, 3 `retain`; 12 detectors. The candidates are **quality-dimension** candidates, not code-smell
lists, so "traces to the ledger" means citing `candidate_id` + `detector` + the concrete observation anchor.

| Candidate id | Disp. | Detector (command) | Phase 135 role | Owner phase |
|--------------|-------|--------------------|----------------|-------------|
| quality-maintainability-curated-complexity | fix | credo-quality (`mix credo_quality`, baseline `scripts/maintainer/credo_complexity_baseline.json`, 27 entries) | **Primary CRAFT-05 source**: shrink baseline by removing named findings | 135 pilot; ratchet in 136 (MAINT-04) |
| quality-correctness-default-suite | fix | default-exunit (`mix test`) | CRAFT-05 secondary source (test readability: e.g. the 3 ID-heavy install_smoke files); behavior proof for every PR | 135 |
| quality-documentation-accessibility | fix | docs-accessibility (`mix doctor --full --raise`, `refactor_contract.sh`) | CRAFT-05 docs/comment truth; doctor must stay green | 135 |
| quality-repository-hygiene | retain | repository-hygiene (`./scripts/maintainer/repo_hygiene_check.sh`) | **HYGIENE-03 direct**; CRAFT-03/04/06 scan wiring hangs off this detector | 135 |
| quality-packaging-generated-consumer | fix | package-consumer (`mix hex.build --unpack`, `package_metadata_test.exs`) | CRAFT-03 package-status column and package-exclusion check | 135 (twin in 137) |
| quality-release-exact-sha | fix | release-authority | Boundary only: CRAFT-05 PRs must not touch release surfaces | 135 boundary |
| quality-testing-automation-first | fix | automation-first (`automation_first_contract.sh`) | Reused unchanged by hygiene; rerun after planning edits | 135 reuse |
| quality-reliability-nightly | fix | nightly-policy | Not touched (Nightly structure) | 136 (CI-15) |
| quality-compatibility-supported-toolchain | fix | supported-toolchain | Not touched | 136 (TYPE-03) |
| quality-ci-required-topology | fix | workflow-topology | Boundary: workflow comment/name edits must keep `CI` / `CI Summary` | 136 (CI-15/16) |
| quality-security-dependency-policy | retain | mix-audit | Closed by Phase 134 | done |
| quality-performance-required-pr-timing | retain | pr-timing | Boundary: new CI steps must stay in `ci-script-tests`/existing lanes | 136 (CI-16) |

**Evidence-path caveat:** several `evidence[]` entries of the frozen ledger point at files that do not exist on main
(`test/install_smoke/phase_133_reconciliation_test.exs`, `phase_133_completed_validation_test.exs`,
`validate_phase_133_reconciliation.exs`, `133-27/28/32/37/38/39-SUMMARY.md` as bare names) [VERIFIED: existence check this session]. They are
frozen history from the dropped halted attempts. The trace file must therefore anchor to the **current** observation
(`credo` baseline identity), not to those evidence strings, and must embed the candidate ids + ledger sha256 rather than
read the phase directory (live tests cannot read `.planning/`, LOCK-05).

## Inventory (CRAFT-03 inputs)

[VERIFIED: `git ls-files`, `git check-ignore`, `mix hex.build --unpack -o <scratch>`, this session]

- **2,840 tracked files.** `.planning` 2,108 (milestones 1,361; phases 656 of which Phase 133 alone is most), `test` 203, `lib` 136, `examples` 114, `brandbook` 111, `scripts` 61, `guides` 22, `priv` 19, `.github` 14, `docker` 12, `prompts` 6, `config` 6, `.codex` 5, `.cursor` 2, plus root files. Largest tracked files are Phase 133 JSON receipts (`133-75-B.json` 4.1 MB, `133-77-B.json` 3.6 MB, `133-75-A.json` 3.6 MB, `133-77-A.json` 3.4 MB, `133-153-RETRIEVAL.json` 1.5 MB): intentional frozen history, retain; archived by `gsd-cleanup` at milestone close.
- **Shipped to Hex (183 files):** `mix.exs:277-278` declares
  `files:` / `~w(lib priv/repo/migrations priv/static/rindle_admin mix.exs README.md RUNNING.md CHANGELOG.md LICENSE guides)` [VERIFIED: read]. Unpacked set outside `lib/` and `guides/` is exactly: `mix.exs LICENSE CHANGELOG.md RUNNING.md README.md hex_metadata.config`, 4 files in `priv/static/rindle_admin/`, 15 migrations [VERIFIED: unpack listing]. Existing guard: `package_metadata_test.exs:37` `@prohibited_paths ["_build", ".planning", "test", ".github", "coveralls.json"]` plus a required-paths list [VERIFIED: read]. It checks ~11 required and 5 prohibited paths, **not** set equality, so an unwanted new file under `lib/`, `guides/` or `priv/static/rindle_admin/` is not detected.
- **Generated artifacts and their generators** [VERIFIED: ran `tokens-build.mjs`, `admin-css-build.mjs`, `sync-admin-css.mjs`; `git status` stayed clean = idempotent]:
  `brandbook/tokens/tokens.css` (tokens-build.mjs), `brandbook/tokens/rindle-admin.css` (admin-css-build.mjs), `priv/static/rindle_admin/rindle-admin.css` (byte copy via sync-admin-css.mjs; **shipped**). `brandbook/admin-gallery/index.html` and `brandbook/assets/logo/**` (66 files incl. `candidates/` = Phase-82 exploration provenance, `brandbook/README.md:15`) are generated by other brandbook scripts that need `npm ci` (opentype.js) [CITED: brandbook/README.md, brandbook/src/build.mjs header]. Hand-authored, shipped: `priv/static/rindle_admin/rindle-admin.js`, `logo.svg`, `favicon.svg`. `mix.lock`, `package-lock.json` (x2) are tool-generated lockfiles (retain). `examples/adoption_demo/priv/static/assets/cohort.css` is hand-authored (not produced by a generator) [VERIFIED: grep found no writer].
- **Ignore rules (`.gitignore`, 14 effective rules + comments):** `/_build/ /cover/ /deps/ /doc/ /.fetch erl_crash.dump *.ez *.beam /priv/plts/ .env .env.* .DS_Store Thumbs.db *.swp *.swo *~ .idea/ .vscode/ *.sublime-* .bg-shell/ .recovery/ .gsd/ .gsd-archive-*/ .planning/.gsd-archive-latest .planning/GSD1-RECOVERY.md .planning/tmp_*.json .planning/research/.cache/ /init.json /progress.txt /recent.txt /roadmap.json /state.json /credo.json /credo.txt /rindle-*/ .claude/ .codex/* !.codex/skills/ !.codex/skills/** /tmp/ brandbook/src/node_modules/`. `git ls-files -ci --exclude-standard` returns **0** (no tracked file is ignored) [VERIFIED]. **Defect:** `.gitignore:16` is `.env.*`, and `git check-ignore -v .env.example` reports `.gitignore:16:.env.*	.env.example` [VERIFIED]: a conventional tracked template could never be added. Narrow it (`.env.*` plus `!.env.example`) or drop it. No `.env.example` exists today and no doc references one `[VERIFIED: grep]`, so this is latent, not live.
- **Ignored residue produced by verification:** `tmp/` in the worktree holds five `Rindle.*Test` directories created by `@tag :tmp_dir` tests (ExUnit writes under `tmp/`); `/tmp/` is ignored so `git status` stays clean while the residue persists [VERIFIED: `ls tmp`]. HYGIENE-03 "post-verification residue" must therefore compare **ignored** state too, with an explicit allowlist of expected ignored roots.
- **Candidate/low-consumer artifacts needing an explicit disposition** [VERIFIED: grep for consumers]:
  - `.mcp.json` - tracked since 2026-04-25 (`df583717`), contains **machine-specific absolute paths** under `/Users/jon/.asdf/...` and `/Users/jon/.gsd/...`; no consumer anywhere in the repo. Strongest "tracked junk" candidate. Recommendation: delete (history keeps it) - **user-level destructive-delete decision, confirm once** (Open Question 2).
  - `prompts/*.md` (6) - historical bootstrap prompts, referenced by `brandbook/README.md` and `.codex/skills/gsd-milestone-next-step`; retain (consumer exists).
  - `.codex/skills/**`, `.cursor/**` - agent tooling; retain, `package: excluded`.
  - `coveralls.json` - consumed by `mix.exs`, `RUNNING.md`, ci.yml; retain, in `@prohibited_paths`.
  - `brandbook/assets/logo/candidates/**` - generated provenance; retain.
  - `docker/**` - consumed by cohort demo smoke and `docker_demo_dx.md`; retain.

## Architecture Patterns

### System Architecture Diagram

```
                        git ls-files / .gitignore / mix.exs package.files
                                           |
        +----------------------------------+------------------------------------+
        v                                  v                                    v
 scripts/maintainer/artifact_ledger.json   scripts/maintainer/live_residue_       scripts/maintainer/readability_
 (classes: pathspecs, authority,           allowlist.json (entries keyed by        changes.json (candidate_id +
  consumer, package, disposition,          path+class+normalized line text;         observation anchor + files +
  regenerate{cmd,paths}, ignore_rules)     reason_class; status)                    contract_proof commands)
        |                                           |                                         |
        v                                           v                                         v
 validate_artifact_ledger.sh  --------->  scan_live_residue.exs  <---- ExUnit wrapper   craft boundary: refactor_contract.sh
 (bash+jq, offline, in                    (classes: planning-id,      live_residue_    + public_surface_snapshot_test
  ci-script-tests: partition,             mojibake, dup-prose,        scan_test.exs    + git-diff forbidden-path check
  coverage, ignore narrowness)            narration, artifact-comment)  (Quality)
        |                                           |                                         |
        +--------------------+----------------------+-----------------------------------------+
                             v
        repo_hygiene_check.sh  (--ci: ledger+junk; local/release-prep: fetch, branch==main==origin/main,
        tracked junk, regenerate+git diff, full `mix ci` + sentinels, before/after residue snapshot)
                             |
                             v
        scripts/ci/test_repo_hygiene_check.sh (real temp git repos + bare origin; PATH shims for mix/node/gh)
                             |
                             v
        ci.yml: ci-script-tests (new steps)  ->  needs: of  CI Summary (unchanged)  ->  required check
```

### Recommended Project Structure
```
scripts/maintainer/
  artifact_ledger.json            # CRAFT-03 (stable path, NOT under .planning/)
  validate_artifact_ledger.sh     # bash+jq; --offline and --package <dir> modes
  scan_live_residue.exs           # scanner core + CLI (--list, --check, --regen-baseline)
  live_residue_allowlist.json     # CRAFT-04/06 baseline + policy allowlist
  readability_changes.json        # CRAFT-05 trace (candidate ids embedded, no .planning read)
  repo_hygiene_check.sh           # reworked, functions per check
scripts/ci/
  test_validate_artifact_ledger.sh
  test_repo_hygiene_check.sh
test/install_smoke/
  live_residue_scan_test.exs      # live tree + planted-violation fixtures
  artifact_package_set_test.exs   # ledger-derived shipped set == unpacked set
test/rindle/
  public_surface_snapshot_test.exs  + test/fixtures/public_surface.txt  # CRAFT-05 boundary
```
Rationale: `test/planning_path_hygiene_test.exs` (LOCK-05) fails any test that reads a live `.planning` path
[VERIFIED: read], so every artifact a test reads lives under `scripts/` or `test/`. Bash validators may read `.planning/` (precedent: `validate_inbox_ledger.sh --offline --ledger .planning/INBOX-LEDGER.json` at ci.yml:1483) but the ledgers here do not need to.

### Pattern 1: Partition ledger via git pathspecs (CRAFT-03)
**What:** each ledger class has `pathspecs: [":(glob)lib/**", ...]`; validator runs `git ls-files -- <spec>` per class, builds the multiset, then asserts (a) union == `git ls-files`, (b) no path in two classes (use `:(exclude)` to carve exceptions), (c) every `.gitignore` rule line appears in `ignore_rules[]` exactly once, (d) no tracked file matches an ignore rule (`git ls-files -ci --exclude-standard` empty), (e) each class has non-empty `authority`, `consumer`, `package` in `{shipped, excluded}`, `disposition` in `{retain, delete, ignore}`, and a `regenerate` object iff `authority == "generated"`, (f) every `consumer` path exists, (g) `package: shipped` classes match the `mix.exs` `files:` prefixes.
**Example (shape):**
```json
{"schema":"rindle-artifact-ledger-v1","classes":[
 {"id":"pkg-lib","pathspecs":[":(glob)lib/**"],"authority":"hand-authored","consumer":["mix.exs"],"package":"shipped","disposition":"retain"},
 {"id":"gen-admin-css","pathspecs":["brandbook/tokens/rindle-admin.css"],"authority":"generated","consumer":["priv/static/rindle_admin/rindle-admin.css"],"package":"excluded","disposition":"retain",
  "regenerate":{"commands":["node brandbook/src/admin-css-build.mjs"],"drift_paths":["brandbook/tokens/rindle-admin.css"]}},
 {"id":"gen-admin-css-shipped","pathspecs":["priv/static/rindle_admin/rindle-admin.css"],"authority":"generated","package":"shipped","regenerate":{"commands":["node brandbook/src/sync-admin-css.mjs"],"drift_paths":["priv/static/rindle_admin/rindle-admin.css"]}},
 {"id":"planning-history","pathspecs":[":(glob).planning/**"],"authority":"history","package":"excluded","disposition":"retain"}]}
```
(`[ASSUMED]` exact field names; planner may rename. The partition/pathspec mechanism must be prototyped in task 1 because `git ls-files` with `:(glob)` + `:(exclude)` combined has edge cases.)

### Pattern 2: Removal-only baseline allowlist (CRAFT-04/06)
Mirror the credo baseline: entries keyed by `(path, class, normalized_line_text_hash_or_literal)` (never line numbers), `reason_class` in `{policy, contract, fixture, immutable-receipt, pending-removal}`, and the scanner **fails if an entry no longer matches** (stale = shrink-only, like `cmp` in `credo_quality.sh`). Wave 1 lands the scanner with every current hit as `pending-removal`; each tranche PR deletes entries as it removes residue; the closure plan adds a test asserting **zero** `pending-removal` entries remain. This is what makes "reject unallowlisted identifiers" true from day one while the burn-down is staged.

### Pattern 3: Fixture harness with real git (HYGIENE-03)
`scripts/ci/test_repo_hygiene_check.sh` creates a bare origin and clone in `mktemp -d`, copies the script and minimal fixtures, PATH-shims `mix`/`node`/`gh`, and forces each failure. Precedent: `scripts/ci/test_collect_inbox.sh` (636 lines, fake `gh`), `test_validate_inbox_ledger.sh` (258 lines) [VERIFIED: wc].

### Anti-Patterns to Avoid
- **Line-number-keyed allowlist:** breaks on every edit; key by normalized text.
- **Allowlisting by directory** (e.g. all of `test/install_smoke`): defeats CRAFT-04. Allowlist by (file, literal).
- **Hand-editing generated output** to remove ids (`brandbook/tokens/rindle-admin.css`, `priv/static/rindle_admin/rindle-admin.css`): edit `admin-css-build.mjs`, regenerate, sync, commit all three (Pitfall 3).
- **Changing user-visible strings** (error messages, check-run names) as "narration cleanup" (Pitfall 2).
- **Reading `.planning/phases/135-*` from live code** (archive debt).
- **Deleting `Rindle.*Test` tmp dirs inside tests** to "fix residue": make the hygiene check tolerant of the known ignored roots instead.

## Residue Scanner Design (CRAFT-04, CRAFT-06)

### Scope
Tracked files under `lib test scripts config .github mix.exs .formatter.exs .credo.exs .doctor.exs .dialyzer_ignore.exs examples docker brandbook/src coveralls.json release-please-config.json` = **582 files** [VERIFIED: `git ls-files` count]. Add shipped/root docs (`README.md RUNNING.md CONTRIBUTING.md AGENTS.md SECURITY.md guides/ brandbook/README.md`) as a second, small scope (only 4 files hit: `guides/admin_console_architecture.md` 1, `AGENTS.md` 6, `examples/adoption_demo/README.md` 1, `brandbook/README.md` 2; AGENTS.md hits are present-tense policy and are allowlist candidates). Exclude: `.planning/**`, `CHANGELOG.md` (history), binary assets, `examples/adoption_demo/priv/static/assets/vendor/**` (minified third-party), lockfiles, the scanner and its own allowlist and test (explicit fixed exclusion list, asserted to contain exactly those three paths, same self-exclusion trick as LOCK-05).

### Classes, patterns and measured counts
[VERIFIED: python scan over the 582 live files, this session; counts are matching **lines per class** and overlap; treat as upper bounds]

| Class | Pattern (Elixir `Regex`, case-sensitive) | Lines | Notes |
|-------|-------------------------------------------|-------|-------|
| decision-id | `(?<![A-Za-z])D-\d{1,3}(?:-\d{2})?\b` | 413 | `ci.yml` 58, `examples/adoption_demo` 53, `brandbook/src` 39, `lib` 21; shipped CSS 13 |
| requirement-id | `\b(?:CRAFT\|HYGIENE\|EVID\|TRUTH\|COV\|EPIPE\|GATE\|ISO\|LOCK\|OBS\|CACHE\|LANE\|HARD\|INBOX\|SEC\|DEPS\|TWIN\|PIPE\|UPLIFT\|COHORT\|VIS\|ADMIN\|SAFE\|META\|MIGRATE\|EVAL\|TRUST\|COMPAT\|STREAM\|LIFE\|DX\|MAINT\|TYPE)-\d{2}\b` | 309 | 196 in `test/install_smoke` (OBS 68, CACHE 57, LANE 56 are the v1.20 policy tests) |
| phase-ref | `\bPhase[ -]?\d{1,3}\b` | 169 | |
| spec-ref | `UI-SPEC\|\b\d{2,3}-(?:RESEARCH\|CONTEXT\|PLAN\|SUMMARY\|VALIDATION)\.md\|\b(?:CR\|WR\|IN)-\d{2}\b\|Assumption A\d` | 167 | `lib/rindle/ops/upload_maintenance.ex` 12 (`CR-01`, `WR-01`...), `lib/rindle/admin/components.ex` 6 |
| planning-path | `\.planning/` | 81 | split in the next table |
| milestone-ref | `(?<![A-Za-z0-9.])v1\.\d{1,2}\b` | 76 | many are product-milestone words, a few are real **user-visible text** (Pitfall 2) |
| plan-ref | `\bPlan[ -]\d{1,3}(?:-\d{1,3})?\b` | 47 | |

Distinct matching lines: **1,085** across **186** files. By area: `test/install_smoke` 332, `test/rindle` 283, `.github/workflows` 170, `examples/adoption_demo` 101, `lib/rindle` 98, `scripts/ci` 61, `brandbook/src` 57, `scripts/maintainer` 51, `test/` root 30, `test/adopter` 16, `.github/actions` 15, `test/brandbook` 14. Top single files: `ci.yml` 142, `ci_lane_split_test.exs` 91, `ci_observability_test.exs` 52, `ci_cache_hygiene_test.exs` 44, `evidence_census_test.exs` 29, `admin-css-build.mjs` 23, `validator_test.exs` 21, `nightly.yml` 19, `components.ex` 19.

### Which hits are policy vs residue (planner's classification guide)
- **Residue (rewrite to present-tense rationale, drop the id):** nearly all `D-NN-NN`, `Phase N`, `Plan N`, `UI-SPEC`, `CR-/WR-NN`, `Assumption A3 in 05-RESEARCH.md` in comments and docs: for example `lib/rindle/admin/components.ex:8` `# Task-first nav labels/order (UI-SPEC §E, D-98-03): relabel for task-scent,`, `config/test.exs:27` `(Assumption A3 in 05-RESEARCH.md)`, `lib/rindle/storage/local.ex:92` `Phase-42 tus_append helper`.
- **Allowlist, `reason_class: contract` (user-visible or identity strings; do NOT change in this phase):**
  - `lib/rindle/error.ex:201,202,227,269,280,310` message text containing `Rindle v1.4`, `post-v1.4`, `v1.6 surface`, `pre-v1.13 rows`. These are rendered error messages asserted by `error_test.exs`; rewriting them is error-vocabulary drift (SC3). Open Question 3 proposes a deliberate follow-up with message-snapshot review.
  - `.github/workflows/ci.yml:279` job `name: ADMIN-06 Optional Dependencies`: the check-run name is consumed by `scripts/maintainer/dep_landing_evidence.sh:202` (`prefix: ["Quality (", "ADMIN-06 Optional Dependencies ("]`) and fixtures in `scripts/ci/test_dep_landing_evidence.sh:105`; and `ci.yml:90`/`:508` step names are asserted by `quality_signal_policy_test.exs:95` (`"Run SAFE-01 preservation contract"`). Rename only with all consumers in one PR, or allowlist. Recommend allowlist (low value, nonzero release-adjacent risk).
- **Allowlist, `reason_class: immutable-receipt`:** `scripts/ci/verify_nightly_run.sh:260` `ledger_path='.planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json'` (and its mirror in `test_verify_nightly_run.sh`, 133-census paths in `evidence_census.exs:25`/`validate_evidence_census.exs:29` pointing at `.planning/milestones/v1.25-phases/132-measured-closure/132-02-SUMMARY.md`). Committed receipts record this path, so a move changes receipt identity.
- **Allowlist, `reason_class: policy` (present-tense policy that must name `.planning/`):** `scripts/gsd_cleanup.sh`, `scripts/maintainer/repo_hygiene_check.sh` (RELEASE-TRAIN/DEVELOPMENT-TRAIN), `automation_first_contract.sh`, `update_release_train_baseline.sh`, `release.yml:621-629`, `ci.yml:93-95` (TRUTH-01 docs-truth guard reads `PROJECT.md`), `ci.yml:1483` (offline ledger validation), `AGENTS.md`. Each is a genuine read of a maintained planning doc, not history narration.
- **Fixture:** `test/install_smoke/ci_timing_automation_test.exs` writes `.planning/...` into temp fixture repos (lines 619-889): not a live read; scanner should skip when the line is inside a fixture-root write (or allowlist these literals).
- **Pending-removal then rewrite or relocate (needs a decision, Open Question 1):** `scripts/ci/test_nightly_dialyzer.sh:8` reads `.planning/phases/133-.../133-NIGHTLY-FAILURE-FINGERPRINT.json` and fails (`jq -e` on a missing file) if absent [VERIFIED: lines 8, 254-258], and `verify_nightly_run.sh` requires its ledger path to be tracked (`git ls-files --error-unmatch`, line 290). **Both run in the merge-blocking Proof job** (ci.yml "Run Nightly evidence harnesses", `test_nightly_dialyzer.sh test_verify_nightly_run.sh`). Archiving the Phase 133 directory at v1.26 close (`gsd-cleanup`) would red Proof for a non-shipped reason, the exact footgun in memory `reference_installsmoke_archive_path_coupling`.

### CRAFT-06 true hits found (not just keyword matches)
- **Mojibake (4 lines, 2 files)** [VERIFIED: python utf-8 scan of all 2,840 tracked files; only these match]:
  `test/install_smoke/docs_parity/operations_test.exs:216` `# reworked ÃÂ¢ÃÂÃÂ re-asserting the bare denial phrase would relock the` and `:221` `... (TRUTH-07) ÃÂ¢ÃÂÃÂ " <>` (double-encoded em dash; the test message is user-visible on failure). Fix by replacing with `-` or a real em dash. `test/install_smoke/docs_parity/onboarding_and_capabilities_test.exs:201-202` contain `Ã¢ÂÂ` **intentionally** (`refute Regex.match?(~r/PATCH\s*\|\s*Ã¢ÂÂ/, moduledoc)`): a regression guard against corrupted docs. The scanner must allow this by building the sequence from fragments (as LOCK-05 does) or allowlist it as `fixture`; rewrite the regex with `\x{00C3}\x{00A2}...` escapes so the file itself is clean. No other tracked file contains U+FFFD or the common mojibake sequences; the three non-UTF-8 files are binary media fixtures.
- **Duplicated prose (1 real, wrap-seam):** `mix.exs:301-306` [VERIFIED: read]:
  ```
  # MinIO/integration legs are deliberately ABSENT: the final `test` task runs
  # the default-tag suite, which test/test_helper.exs already excludes
  # :integration/:minio/:contract/:adopter from — so `mix ci` runs on a fresh
  # clone WITHOUT a running MinIO and never hard-fails for its absence
  # clone without a running MinIO. The full-parity storage command is documented
  ```
  (the clause "clone without a running MinIO" is stated twice). Adjacent-line identical detector found 5 hits, all false positives (code lines, an HTML snippet). A word-4-gram "repeated within 2 adjacent comment lines" detector over **alphabetic tokens only** (>= 4 distinct words, stopword-only grams excluded) found `mix.exs:304-305` plus 11 code-shaped false positives when tokens included punctuation/backticks; restricting to `[a-z]{3,}` tokens removes those. Calibrate on the live tree in plan 135-02 before committing the baseline. Also tidy `mix.exs:296-297` ("`brandbook-tokens`); it does NOT / include push:main...") which reads as a broken rewrap.
- **Obsolete narration (about 6 true sites):** `lib/rindle.ex:900` `# For now, we return the error`, `lib/rindle/processor/image.ex:68` `# For now, let's use thumbnail which is close`, `ci.yml:908` `was previously only human-verified`, `ci.yml:1239` `(the previously-used ...`, `cohort_demo_smoke.sh:7`, `test_ci_summary_gate.sh:9` `Previously that behavior was ...`, `lib/rindle/admin/live/actions_live.ex:574` `Previously this was a plain inline <form>`, `mux.ex:232`, plus `examples/.../admin_lifecycle_display_test.exs:7` and `brand_test.exs:7` (`formerly human-verified`) which narrate UAT history. False positives to allowlist or exclude by design: `lib/rindle/error.ex:117-139` (`previously advertised capability`; domain semantics), `scripts/ci/test_nightly_dialyzer.sh` ("was removed" is a test-case name). Detector list is a **closed phrase list with a per-line allowlist**, not a heuristic: `\b(?:previously|formerly|used to (?:be|do)|was changed to|now we|has been (?:renamed|moved|removed|replaced)|for now|no longer)\b`, scoped to comments (`#`, `//`, `*`, `<%!--`, `/*`) only.
- **TODO/FIXME/XXX/HACK:** zero in live scope [VERIFIED].

### Self-reference and hygiene of the scanner
It must not flag itself (build its own regex from fragments or exclude by fixed list), must not be sensitive to line numbers, must print `path:line: class: text` for every violation, and must fail on a **stale allowlist entry** (entry matches nothing). Include an anti-vacuous assertion (file count > 500) like `planning_path_hygiene_test.exs`'s `assert files != []`. Static scan tests are `async: true` read-only; any file mutation in fixtures needs `@moduletag async_safety_allow: [:file_mutation]` per `async_safety_guard_test.exs` (see `evidence_census_test.exs` header for the idiom).

## HYGIENE-03: Gap Analysis of `scripts/maintainer/repo_hygiene_check.sh`

[VERIFIED: read in full; line numbers from `grep -n`]

| Required failure | Today | Evidence | Fix |
|------------------|-------|----------|-----|
| Fetch failure | **Swallowed.** | `:214 git fetch "$REMOTE" --prune >/dev/null 2>&1 || true`; the following divergence block silently becomes `WARN could not compare` | Capture exit; `BLOCK "fetch"` on non-zero in local/release-prep mode. `--ci` mode keeps no fetch (the Actions checkout is the authority) |
| Wrong branch | **Not checked.** Branch is only recorded as PASS. On detached HEAD it records `HEAD` as PASS. | `:204 branch="$(git rev-parse --abbrev-ref HEAD)"` then `record_result "PASS" "current branch" "$branch"`; divergence compares **local `main` ref** (`:216 refs/heads/main`), not `HEAD` | BLOCK unless branch is `main` (override via `RINDLE_HYGIENE_BRANCH` for release branches) **and** `HEAD == $REMOTE/main` after a successful fetch. Ahead of origin is BLOCK in release-prep mode (today only WARN) |
| Tracked junk | **Not checked** in any mode. | No `ls-files` call. The only guard is the ExUnit `repository_residue_test.exs` for 9 named root files | `git ls-files` pattern scan (`.DS_Store erl_crash.dump *.beam *.ez *.log *.orig *.rej *.swp *~ /rindle-*/ /tmp/ init.json ...` plus any path `git ls-files -ci --exclude-standard` returns). Run in `--ci` mode too (pure git) so it is also exercised on push:main; also add it to `ci-script-tests` via the harness |
| Generated drift | **Not checked locally.** Only the repo-gated `brandbook-tokens` CI job diffs. | `mix ci` runs the generators (`mix.exs` aliases) but never `git diff`s afterward | After running the ledger's `regenerate.commands`, `git diff --exit-code -- <drift_paths>` and no untracked files at those paths. Read the lists from `artifact_ledger.json` so there is one source |
| Incomplete `mix ci` | **Wrong command, and only a smoke test.** | `:247-248 if [[ "$RUN_MIX_CI" == "1" ]]; then if mix test >/dev/null; then`; the flag is named `--with-mix-ci` and documented "local mix test" | Run `mix ci` itself under `pipefail`, tee a log, require exit 0 **and** completion sentinels: `[credo-quality] blocking warnings, public contract, and complexity inventory passed` (`credo_quality.sh` last line), `synced rindle-admin.css`, and an ExUnit summary matching `[0-9]+ tests?, 0 failures`. Missing sentinel with exit 0 = BLOCK `mix ci incomplete` (a stage was removed from the alias or short-circuited). Prove with a PATH-shim `mix` that exits 0 without the sentinel |
| Post-verification worktree residue | **Not checked.** | working-tree check runs once at `:207` before any verification | Snapshot `git status --porcelain=v1 -uall --ignored` before the verification phase and after; BLOCK on any path in the delta not under an allowlisted ignored root (`_build/ deps/ cover/ doc/ tmp/ priv/plts/ node_modules/`); report-but-clean option for `tmp/` |

Other findings:
- `--ci` mode (`:258 if [[ "$MODE" != "ci" ]]; then local_checks`) runs **only** repo-owned checks, and is invoked only by `package-consumer-full` on push:main/release (ci.yml:818-819) [VERIFIED]. No PR-time hygiene signal exists; the harness + ledger validator in `ci-script-tests` provides it.
- **There is no test for the script itself** (grep: only census registries and one docs-parity string mention it) [VERIFIED].
- **Hex-baseline publish race (todo `2026-10-15-hygiene-baseline-publish-race.md`):** the `hex baseline` branch (`:172-187` region) BLOCKs when Hex already lists `mix.exs`'s version but `RELEASE-TRAIN.md` still has the previous baseline; the release workflow records the baseline only after Public Verify in a `[skip ci]` commit [CITED: the todo, seen 2026-10-15 run 38809962966]. **In scope** because it is a false red of this very gate (honesty includes not lying red). Recommended: option 1 only, limited to `--ci` mode: when `hex_ver == mix_ver` and baseline is exactly the previous release, record `WARN` ("baseline recorded by release workflow after publish") instead of `BLOCK`; keep `BLOCK` in local release-prep mode (a maintainer prepping the next release should see a stale baseline). Do NOT take option 2 (drop `[skip ci]` in `release.yml`): that edits release coupling for no requirement credit. Add harness cases for both modes.
- Out of scope: the 2026-10-16 ledger landing-record todo (`validate_inbox_ledger.sh` landing rule; collector `failed_jobs` includes running jobs). It hardens Phase 134's ledger and credits none of CRAFT-03/04/05/06 or HYGIENE-03. Recommend a standalone `ci:` follow-up PR or defer to Phase 136 CI-15; do not fold into the 135 plan count.

### Hygiene rework design
Keep the PASS/WARN/BLOCK reporting and exit-code contract (`0` safe/caution, `1` not ready). Refactor `local_checks` into named functions (`check_fetch`, `check_branch`, `check_tracked_junk`, `check_generated_drift`, `check_mix_ci`, `check_residue`) and accept `RINDLE_HYGIENE_ROOT` (default `git rev-parse --show-toplevel`) so the harness can point at a temp repo. Introduce `--release-prep` as an explicit alias of today's local mode plus the new checks (default local mode keeps its flags to avoid surprising maintainers; `--with-mix-ci` now means full `mix ci`). `AGENTS.md` ("Before release prep, run `./scripts/maintainer/repo_hygiene_check.sh`") and `.planning/RELEASE-TRAIN.md:69` keep working unchanged. The required phrase list inside `release_train_has_required_lines` (`'./scripts/maintainer/repo_hygiene_check.sh'`) must keep matching RELEASE-TRAIN.md.

## CRAFT-05: Candidate-Backed Readability + Contract Proof

### Existing contract guards (all already merge-blocking) [VERIFIED: read]
- `scripts/maintainer/refactor_contract.sh` (SAFE-01, in the `contract` job, ci.yml:508): `MIX_ENV=test mix compile --force`; `mix xref graph --format cycles --label compile-connected --fail-above 0`; then `mix test --include contract --seed 0` over `api_surface_boundary_test.exs`, `schema_prefix_contract_test.exs`, `migration_fast_test.exs`, `contracts/telemetry_contract_test.exs`, `error_test.exs`, `error_streaming_freeze_test.exs`, `ci_lane_split_test.exs`, `release_guard_meta_test.exs`.
- `credo_quality.sh`: blocking warnings, `public_contract` check over an explicit public file list in `.credo.exs`, and complexity-multiset equality against the baseline.
- `telemetry_contract_test.exs`: exactly 21 public events (`assert length(@public_events) == 21`).
- Gaps: `api_surface_boundary_test.exs` (425 lines) asserts module **visibility** and selected function exports, not a full export list; nothing hashes `priv/repo/migrations`; nothing forbids a readability PR from touching release surfaces.

### Cheapest additional "no drift" proof (recommended, MEDIUM confidence, small)
1. **Public-surface snapshot** `test/rindle/public_surface_snapshot_test.exs` + `test/fixtures/public_surface.txt`: sorted lines `Module.fun/arity` for every non-`@moduledoc false` module in the `:rindle` application, excluding `@doc false` functions (via `Code.fetch_docs/1`), plus behaviour `behaviour_info(:callbacks)`, plus `priv/repo/migrations/* sha256`. Fails with a diff and the instruction to regenerate only for a deliberate API change. Telemetry and error shapes keep their existing dedicated tests. (`[ASSUMED]` ~100-200 lines; prototype first.)
2. **Forbidden-path diff guard** `scripts/maintainer/craft_boundary_check.sh <base>`: for a readability PR, `git diff --name-only <base>...HEAD` must not include `priv/repo/migrations/**`, `mix.lock`, `.release-please-manifest.json`, `release-please-config.json`, `.github/workflows/release*.yml`, `CHANGELOG.md`, and must not change the `version`, `deps`, or `package` blocks of `mix.exs`. Run by hand/executor per PR and as a `ci-script-tests` harness on fixtures; PR-time automation is optional.
3. Per-PR run list (executor checklist, all existing): `bash scripts/maintainer/refactor_contract.sh`, `mix credo_quality`, `mix doctor --full --raise` (MIX_ENV=dev), `mix test` default suite, and `mix ci` as the final gate.

### Trace file
`scripts/maintainer/readability_changes.json`: `{"candidate_ledger":{"subject_sha":"3858267b...","sha256":"a56c8b6e...","candidate_ids":[12 ids]}, "changes":[{"id","candidate_id","detector","anchor":{"check","file","trigger","observed_metric"},"files":[...],"intent":"naming|cohesion|ownership|failure-semantics","proof":["mix credo_quality","bash scripts/maintainer/refactor_contract.sh","mix test <focused files>"],"pr":N}]}`. Offline validator (bash+jq, in `ci-script-tests`): every `candidate_id` is in the embedded list; `intent` and `proof` non-empty; `anchor` identifies an entry that was **removed** from the credo baseline (check that `anchor` no longer appears in `credo_complexity_baseline.json` after the change, and appeared in the baseline at the previous commit via `git show <base>:...` when run with `--base`). A maintainer-only `--verify-source` mode compares the embedded sha256 to the phase file when it exists (never run in CI).

### Recommended pilot set (5 baseline entries, low risk, own tests, no "developer-approved" gate)
Baseline has 27 entries (10 cyclomatic, 17 nesting) [VERIFIED: counted]. Choose entries whose `removal_trigger` is mechanical ("Finding is absent" / "Named function is <=9"), the module is `@moduledoc false`/ops-internal, and a dedicated test exists:

| Baseline identity | File (lines) | Existing test |
|-------------------|--------------|---------------|
| Nesting `if` 3 | `lib/rindle/ops/sweep_orphaned_temp_files.ex` (189) | `test/rindle/ops/sweep_orphaned_temp_files_test.exs` (263) |
| Nesting `fn` 3 | `lib/rindle/ops/lifecycle_repair.ex` (375) | `test/rindle/ops/lifecycle_repair_test.exs` |
| Nesting `with` 3 | `lib/rindle/ops/runtime_checks/core_checks.ex` (215) | `test/rindle/ops/runtime_checks_test.exs` |
| Nesting `fn` 3 (two findings) | `lib/rindle/ops/runtime_checks.ex` (386) | `runtime_checks_test.exs`, `_gcs_`, `_streaming_` |
| Nesting `case` 3 (two findings) | `lib/rindle/upload/tus_protocol.ex` (180) | `test/rindle/upload/tus_plug_test.exs` + `api_surface_boundary_test.exs` hidden-function checks |

**Avoid in this phase:** the `Migration preflight classify` (15 and 25) and `raise_preflight_error!` entries (refusal vocabulary is public error behavior), every entry whose trigger reads "Developer-approved ... phase ..." (delivery, mux, ingest webhook, storage adapters, admin actions, AV processors, streaming): those require an explicit developer approval that this research cannot grant (Open Question 4), `upload_maintenance` (881 lines, also a residue hot spot: serialize after tranche A), and `generated_app_helper prove_package_install!` (20; test support for the package proof, owned by Phase 137).
Each PR deletes exactly the removed identities from `credo_complexity_baseline.json` (removal-only, never raising a metric), which `credo_quality.sh`'s `cmp` then verifies mechanically. Phase 136 (MAINT-04) owns the generalized ratchet and the rest of the baseline; the trace file's `changes` array hands it a clean history.

Scope guard (PROJECT.md "no aesthetic-only churn"): outside this pilot, CRAFT-05 changes are limited to test/script readability that an executor can tie to `quality-correctness-default-suite` or `quality-documentation-accessibility` and to a named cohesion/ownership/failure-semantics defect, recorded in the trace file. Residue removal (CRAFT-04/06) is not "readability change" and needs no candidate trace; it is traced by the scanner baseline instead.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Glob/partition of tracked files | A bash glob matcher | `git ls-files -- ':(glob)...' ':(exclude)...'` | Git already resolves pathspecs identically to how it tracks files |
| Detecting tracked-but-ignored files | Parsing `.gitignore` | `git ls-files -ci --exclude-standard` and `git check-ignore -v` | Handles negations/anchors correctly |
| Shipped-file set | Re-implementing Hex file expansion | `mix hex.build --unpack -o <dir>` and `find` | Authoritative; already used by `package_metadata_test.exs` |
| Complexity baseline equality | New comparer | Existing `credo_quality.sh` multiset `cmp` | Already the reviewed authority |
| Behavior preservation | New harness | `refactor_contract.sh` + default suite + `mix ci` | Merge-blocking already |
| Fixture repos for hygiene | Mocking `git` | Real `git init`/`git clone` from a bare temp origin | Fetch/branch/ahead-behind semantics are what is being tested |
| JSON in Elixir 1.17 | A parser | `Jason` via `mix run --no-start` (Elixir 1.17 has no built-in JSON) | Existing scripts do this |
| Generator commands list | A second copy | Ledger `regenerate.commands`, compared in a test to the `brandbook-tokens` job steps | Prevents ledger/CI divergence |

**Key insight:** every mechanism here already has a Phase 127-134 precedent in this repo (baseline multiset, fixture harness, stable-path ledger, self-excluding static scan). New invention is the main risk (Phase 133 burned 213 plans); copy the shape.

## Runtime State Inventory

Not a rename/migration phase in the data sense. Explicit answers for the string-removal and file-move parts:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None - verified: no datastore keys contain planning identifiers; all hits are source text | None |
| Live service config | GitHub check-run name `ADMIN-06 Optional Dependencies (...)` is consumed by `dep_landing_evidence.sh` and by recorded landings in `.planning/INBOX-LEDGER.json` `[ASSUMED: landing records include job names; not opened]` | Do not rename in this phase; allowlist as `contract` |
| OS-registered state | None - verified: no launchd/systemd/Task Scheduler registrations in repo | None |
| Secrets/env vars | `RINDLE_HYGIENE_REMOTE` (existing), proposed `RINDLE_HYGIENE_ROOT`, `RINDLE_HYGIENE_BRANCH`; no secret names change | Document in script usage |
| Build artifacts | `priv/static/rindle_admin/rindle-admin.css` (shipped) and `brandbook/tokens/rindle-admin.css` regenerate when `admin-css-build.mjs` comments change; Hex package bytes change (comment-only) on next release; `tmp/Rindle.*Test/` ignored test residue | Regenerate + sync in the same PR; hygiene residue allowlist includes `tmp/` |

## Common Pitfalls

### Pitfall 1: Tests assert the literal text of the files you are cleaning
**What goes wrong:** removing ids from `ci.yml`/`action.yml`/scripts reddens `install_smoke` tests that grep those files (memory `reference_obs02_metatest_content_drift`); `ci_lane_split_test.exs` (91 id lines), `ci_observability_test.exs`, `ci_cache_hygiene_test.exs`, `quality_signal_policy_test.exs` all assert shipped CI content.
**Why:** policy tests were written by requirement id.
**How to avoid:** change the workflow text and the asserting tests in the **same PR**; grep `test/install_smoke/` for each changed literal first; sequence the workflow/script tranche before the install_smoke-test tranche, or do them together.
**Warning signs:** `Quality` lane red on `Rindle.InstallSmoke.*` after a comment-only edit.

### Pitfall 2: "Cleanup" that changes user-visible contract strings
**What goes wrong:** `lib/rindle/error.ex` messages contain `Rindle v1.4` etc.; `lib/rindle.ex:28` doc text mentions `v1.10`; check-run names embed `ADMIN-06`. Editing them is error-vocabulary or release-adjacent drift.
**How to avoid:** classify before editing: comment/`#`/`<%!--` = free; `@moduledoc`/`@doc` = docs (allowed but `docs_parity` tests may assert them: run them); string literals returned or logged = contract (allowlist unless Open Question 3 is approved). Tag `reason_class: contract` entries with a removal trigger.

### Pitfall 3: Editing generated output or its generator comment without regenerating
**What goes wrong:** removing `D-96-11` from `brandbook/tokens/rindle-admin.css` by hand makes the `brandbook-tokens` gate fail (`git diff --exit-code`), and the Hex-shipped `priv/static/rindle_admin/rindle-admin.css` must be re-synced (13 id lines ship today).
**How to avoid:** edit `brandbook/src/admin-css-build.mjs`; run `node brandbook/src/admin-css-build.mjs && node brandbook/src/sync-admin-css.mjs`; commit all three; `test/brandbook/admin_design_system_validation_test.exs` asserts equality of the copy.

### Pitfall 4: Archiving breaks CI (the standing Phase 133 debt)
**What goes wrong:** `test_nightly_dialyzer.sh:8` and `verify_nightly_run.sh:260/290` read `.planning/phases/133-.../`; the Proof job runs both. Milestone close will archive that directory.
**How to avoid:** for the fingerprint file (consumed by one harness), copy to `scripts/ci/fixtures/` and repoint (safe). For the census ledger path baked into committed receipts, do not move; allowlist as `immutable-receipt` and record in the archive checklist that the 133 directory is excluded from `gsd-cleanup` (Open Question 1). Add a scanner rule: no **new** `.planning/phases/` or `.planning/milestones/` path in live code (policy-allowlist the two existing ones).

### Pitfall 5: Hygiene "fix" that makes the gate flaky or network-dependent in PR CI
**What goes wrong:** adding `git fetch` or `mix hex.info` to a PR-blocking path introduces the 401/API-hiccup class (ci.yml comment about `ci-observability`).
**How to avoid:** keep network checks in local/release-prep and push:main `--ci` (already off the PR critical path); PR-time coverage comes from harness fixtures with a local bare origin.

### Pitfall 6: Strict branch protection serializes ci.yml edits
**What goes wrong:** Plans 135-01, 03, 05 each add steps near `ci-script-tests` (ci.yml:1459-1483); parallel PRs conflict (Phase 134 saw this with #120).
**How to avoid:** merge those PRs serially (protection requires up-to-date branches anyway) and append steps at the end of the job; rebase with `gh pr update-branch N --rebase`.

### Pitfall 7: `mix ci` and the default test alias need Postgres
`ci` runs `test`, aliased to `ecto.create --quiet`, `ecto.migrate --quiet`, `test` (mix.exs:325). Local runs of any ExUnit file in this phase need Postgres up (it is: `pg_isready` accepts on :5432) and `mix deps.get` (the worktree has no `deps/`). The hygiene harness shims `mix` so it needs neither.

### Pitfall 8: Main-only lanes don't run on PRs
Memory `reference_ci_lanes_only_on_main`: E2E, Cohort Smoke, Mux Soak, Package-Consumer-Full skip PRs. `examples/adoption_demo` comment edits (101 hits, `.js` Playwright specs and `.ex`) are covered by `adoption-demo-unit` on PRs but not by `adoption-demo-e2e`. Keep example edits comment-only, and confirm the post-merge main push run before the next tranche (D-134-07 precedent).

## Code Examples

### Hygiene: honest fetch and branch (sketch)
```bash
# Source: design for scripts/maintainer/repo_hygiene_check.sh (replaces :214 swallow and :204 PASS-only)
check_fetch_and_branch() {
  if ! git fetch "$REMOTE" --prune >/dev/null 2>&1; then
    record_result "BLOCK" "fetch" "git fetch $REMOTE failed; cannot prove HEAD matches $REMOTE/$EXPECTED_BRANCH"
    return
  fi
  local branch; branch="$(git symbolic-ref --quiet --short HEAD || echo DETACHED)"
  if [[ "$branch" != "$EXPECTED_BRANCH" ]]; then
    record_result "BLOCK" "branch" "on '$branch', release prep requires '$EXPECTED_BRANCH'"
  fi
  local behind ahead
  read -r behind ahead <<<"$(git rev-list --left-right --count "$REMOTE/$EXPECTED_BRANCH...HEAD")"
  [[ "$behind" == 0 && "$ahead" == 0 ]] && record_result "PASS" "head vs origin" "HEAD == $REMOTE/$EXPECTED_BRANCH" \
    || record_result "BLOCK" "head vs origin" "HEAD is behind=$behind ahead=$ahead of $REMOTE/$EXPECTED_BRANCH"
}
```

### Hygiene: incomplete `mix ci` (sketch)
```bash
check_mix_ci() {
  local log; log="$(mktemp)"; trap 'rm -f "$log"' RETURN
  if ! (set -o pipefail; mix ci 2>&1 | tee "$log" >/dev/null); then
    record_result "BLOCK" "mix ci" "mix ci exited non-zero"; return
  fi
  local s
  for s in '\[credo-quality\] blocking warnings, public contract, and complexity inventory passed' \
           'synced rindle-admin.css' '[0-9]+ tests?, 0 failures'; do
    grep -Eq "$s" "$log" || { record_result "BLOCK" "mix ci" "incomplete: missing completion marker /$s/"; return; }
  done
  record_result "PASS" "mix ci" "full alias completed with all stage markers"
}
```
(The sentinel strings are quoted from `scripts/maintainer/credo_quality.sh` last line and the node scripts' output seen this session: `rindle-admin.css written - ...`, `synced rindle-admin.css -> ...`.)

### Scanner stale-allowlist rule (sketch)
```elixir
# entries not matched by any current hit are an error: allowlist can only shrink
stale = Enum.reject(allowlist, &Map.has_key?(hits_by_key, key(&1)))
assert stale == [], "stale allowlist entries (remove them): " <> inspect(stale)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phase-tagged provenance comments (`D-98-07`, `UI-SPEC §E`) | Present-tense rationale (v1.24 CLARITY-01..03, v1.25 PROV-01..02 set the standard) | v1.24/v1.25 | 1,085 older-style lines remain; Phase 135 finishes the job in live scope |
| Human-verified UAT claims in comments | Executable evidence | v1.19-v1.21 | Narration like "formerly human-verified" is stale |
| `mix test` as the "local CI" | `mix ci` alias is the discoverable gate | v1.2x `mix.exs:310` | Hygiene still runs `mix test` |

**Deprecated/outdated:** `INBOX-TRIAGE.md` is a pointer now; `.gsd/`/`.mcp.json` are GSD1/gsd-pi tooling remnants.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `git ls-files` with combined `:(glob)` and `:(exclude)` pathspecs partitions cleanly on the CI runner's git | Pattern 1 | Fallback to explicit per-class path lists; prototype in 135-01 task 1 |
| A2 | CI runner jq is 1.6 | Standard Stack | Validator must avoid 1.7 builtins (already the repo convention) |
| A3 | Public-surface snapshot via `Code.fetch_docs` is ~100-200 lines and deterministic across Elixir 1.15/1.17 | CRAFT-05 | Fallback: restrict to the `@public_modules` list already in `api_surface_boundary_test.exs`; if OTP26/27 docs chunks differ, snapshot only function names/arities from `__info__(:functions)` |
| A4 | `.planning/INBOX-LEDGER.json` landing records include check-run job names, so renaming `ADMIN-06 Optional Dependencies` is not free | Runtime State Inventory | If not, the rename is cheaper; still allowlist for safety |
| A5 | `shellcheck` is not wired in CI today | Standard Stack | None (optional) |
| A6 | Recommended plan count (11) and wave layout fit the phase fence | Plan Breakdown | Planner may merge 135-04 into 135-01 and 135-11 into 135-09 |
| A7 | Release-please treats `refactor:`, `test:`, `ci:`, `chore:`, `docs:` as non-releasing here: `release-please-config.json` has no custom `changelog-sections` and recent history shows `ci:`/`build(deps)`/`docs:` merges without releases [VERIFIED: config and `git log`], but `refactor:` specifically was not observed in recent history | Delivery | If `refactor:` released, use `chore:`/`test:` for lib comment edits |

## Open Questions

1. **Phase 133 directory coupling (user-level: release evidence)**
   - Known: `verify_nightly_run.sh` and `test_verify_nightly_run.sh` bake `.planning/phases/133-.../133-EVIDENCE-CENSUS.json` into receipt identity; `test_nightly_dialyzer.sh` reads the failure fingerprint; both harnesses run in the merge-blocking Proof job.
   - Unclear: whether to (a) leave the census path and exclude the 133 directory from `gsd-cleanup`, or (b) migrate receipt format.
   - Recommendation: (a) for the census ledger; copy the fingerprint to `scripts/ci/fixtures/` and repoint. Do not change receipt format here.
2. **Delete tracked `.mcp.json`?** (destructive delete; trivially recoverable from git) Recommend delete with one explicit user go-ahead in the plan's checkpoint, because it embeds `/Users/jon/...` absolute paths and has no consumer. Alternative: retain + `.gitignore` entry is not valid for an already-tracked file.
3. **User-visible `vX.Y` text in `Rindle.Error` messages and a few `@moduledoc`s.** Rewriting alters error-message contract. Recommend allowlist now (`contract`), and optionally a separate, explicitly reviewed `refactor:` after approving message wording (public-error semver question for the user).
4. **Is Phase 135 the "developer-approved phase" that 11 baseline entries' `removal_trigger` text requires?** Recommend NO (only the 5 mechanical-trigger pilots); the user may widen.
5. **Requirement-id policy tests** (`ci_lane_split_test.exs` etc.): rename the tests to behavior names (recommended, tranche C) or allowlist? Recommend rename; the descriptions carry the requirement id only as history.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| git | all | yes | system | - |
| jq | validators/harnesses | yes | /usr/bin/jq (1.7-apple per Phase 134) | write to 1.6 subset |
| bash | scripts | yes | 3.2-compatible style | - |
| Elixir/Erlang | ExUnit, `mix ci` | yes | 1.17.3 / OTP 27.3.4.15 via `ASDF_ELIXIR_VERSION=1.17.3-otp-27 ASDF_ERLANG_VERSION=27.3.4.15` | CI matrix 1.15/26 + 1.17/27 |
| Node | brandbook generators | yes | v20.18.1 | - |
| Postgres | `mix test`/`mix ci` | yes | accepting on :5432 | - |
| gh | hygiene local mode (optional), PR flow | yes | /opt/homebrew/bin/gh | `WARN` already handled when absent |
| python3 | research scans only | yes | local | not used by shipped tooling |
| shellcheck, rg | optional lint/search | yes | local | - |
| `deps/` in this worktree | `mix test`, `mix credo` | **no** (`ls deps` fails) | - | `mix deps.get` before any local mix verification (writes into the worktree, not shared deps) |

**Missing with no fallback:** none. **Missing with fallback:** `deps/` (run `mix deps.get --check-locked`). Local toolchain env for runs: `ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 MIX_ENV=test`.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.17.3/OTP 27 canonical; 1.15/OTP 26 also gates `quality`) + bash harnesses (`scripts/ci/test_*.sh`, "pass N/N" style) |
| Config file | `test/test_helper.exs`; `mix.exs` aliases (`test`, `ci`, `credo_quality`, `quality_signals`, `refactor_contract`) |
| Quick run command | `bash scripts/ci/test_repo_hygiene_check.sh` / `bash scripts/ci/test_validate_artifact_ledger.sh` / `mix test test/install_smoke/live_residue_scan_test.exs` |
| Full suite command | `mix ci` (needs Postgres); contract set: `bash scripts/maintainer/refactor_contract.sh` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CRAFT-03 | Every tracked path is in exactly one ledger class; every `.gitignore` rule accounted; no tracked file is ignored; each class has authority/consumer/package/disposition; consumers exist | script (bash+jq) | `bash scripts/maintainer/validate_artifact_ledger.sh --offline --ledger scripts/maintainer/artifact_ledger.json` | Wave 0 (new) |
| CRAFT-03 | Rejects: uncovered file, double-classified file, missing field, stale ignore rule, tracked-ignored file, shipped class absent from `mix.exs files:` | script harness (fixtures) | `bash scripts/ci/test_validate_artifact_ledger.sh` | Wave 0 (new) |
| CRAFT-03 | Ledger-derived shipped set equals the real unpacked package | ExUnit | `mix test test/install_smoke/artifact_package_set_test.exs` | Wave 0 (new) |
| CRAFT-03 | Ledger `regenerate` commands match the `brandbook-tokens` job steps; regenerating leaves `git diff` empty | ExUnit + local script | `mix test test/install_smoke/artifact_package_set_test.exs` and `node brandbook/src/tokens-build.mjs && node brandbook/src/admin-css-build.mjs && node brandbook/src/sync-admin-css.mjs && git diff --exit-code` | Wave 0 (new) / generators exist |
| CRAFT-04 | No unallowlisted planning-era identifier in live scope; stale allowlist entries rejected; planted violation of each class is detected; `pending-removal` count is 0 at phase close | ExUnit | `mix test test/install_smoke/live_residue_scan_test.exs` | Wave 0 (new) |
| CRAFT-06 | Mojibake, duplicated prose, closed-list narration, artifact comments rejected; the intentional `Ã¢ÂÂ` regression literal does not self-flag | ExUnit | same file, class-specific describe blocks | Wave 0 (new) |
| CRAFT-05 | Every `readability_changes.json` entry cites a frozen candidate id, a removed baseline identity, and proof commands | script | `bash scripts/maintainer/validate_readability_trace.sh --offline` (or inside the artifact validator) | Wave 0 (new) |
| CRAFT-05 | Behavior/boundary: SAFE-01 contract set green; complexity baseline equals Credo output after shrink; public export list unchanged; no forbidden path touched | script + ExUnit | `bash scripts/maintainer/refactor_contract.sh && mix credo_quality && mix test test/rindle/public_surface_snapshot_test.exs && bash scripts/maintainer/craft_boundary_check.sh origin/main` | refactor_contract/credo exist; snapshot + boundary new |
| HYGIENE-03 | Each failure forced and BLOCKed: fetch failure, wrong branch/detached, behind/ahead, tracked junk, generated drift, `mix ci` non-zero, `mix ci` exit 0 without sentinel, new untracked or non-allowlisted ignored path after verification; hex-baseline race = WARN in `--ci`, BLOCK in release-prep | script harness (real git + shims) | `bash scripts/ci/test_repo_hygiene_check.sh` | Wave 0 (new) |
| HYGIENE-03 | Live script still passes on current main (no false red) | script | `bash scripts/maintainer/repo_hygiene_check.sh --ci` | exists |
| All | Planning artifacts still satisfy automation-first | script | `./scripts/maintainer/automation_first_contract.sh` | exists |

How each fails (so a verifier can probe): ledger validator prints `REJECT: <reason>` and exits 1 (follow `validate_inbox_ledger.sh`); scanner prints `path:line: class: text` and the ExUnit assertion lists offenders; hygiene prints `[BLOCK] label: detail` and `Result: not ready`, exit 1; harness prints a failing case name and exits non-zero.

### Sampling Rate
- **Per task commit:** the focused harness or test for that task (seconds).
- **Per wave merge:** `bash scripts/maintainer/refactor_contract.sh`, `mix credo_quality`, `mix test` on touched dirs, all `scripts/ci/test_*.sh` added so far.
- **Phase gate:** `mix ci` green locally, PR CI green (`CI Summary`), post-merge main push run green (covers main-only lanes), `./scripts/maintainer/repo_hygiene_check.sh --ci` PASS and release-prep mode PASS on a clean main checkout.

### Wave 0 Gaps
- [ ] `scripts/maintainer/validate_artifact_ledger.sh` + `scripts/ci/test_validate_artifact_ledger.sh` - CRAFT-03
- [ ] `scripts/maintainer/scan_live_residue.exs` + `live_residue_allowlist.json` + `test/install_smoke/live_residue_scan_test.exs` - CRAFT-04/06
- [ ] `scripts/ci/test_repo_hygiene_check.sh` (and the function-ized `repo_hygiene_check.sh`) - HYGIENE-03
- [ ] `test/rindle/public_surface_snapshot_test.exs` + `test/fixtures/public_surface.txt`, `scripts/maintainer/craft_boundary_check.sh`, `readability_changes.json` validator - CRAFT-05
- [ ] Framework install: none (`mix deps.get` in this worktree only)

## Security Domain

`security_enforcement` is not set false in `.planning/config.json` (absent = enabled).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | - |
| V3 Session Management | no | - |
| V4 Access Control | no | - |
| V5 Input Validation | yes | Ledger/allowlist values reach jq only via `--arg`/`--slurpfile`/`--argjson`, never `eval` (the `validate_inbox_ledger.sh` rule); scanner treats file content as data; path values are matched, never executed |
| V6 Cryptography | no | sha256 of the frozen ledger only (`shasum -a 256`), no custom crypto |
| V14 Config / supply chain | yes | No new dependency; `.mcp.json` removal eliminates a tracked machine-specific executable path; hygiene keeps `release.yml` `(BYPASSED)` guard untouched |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Command injection through a ledger `regenerate.commands` string | Tampering | Treat commands as data; validator only compares them to an allowlisted set of exact strings; hygiene executes only commands that exactly match the vetted set (no `eval`) |
| Hygiene `mix ci` run on an attacker-controlled branch | Elevation | Release-prep mode runs only on a clean, fetched `main` equal to `origin/main` (that is the point of the wrong-branch check) |
| Allowlist used to hide new residue | Tampering | Stale-entry rejection, key by text not path-only, final zero-`pending-removal` assertion, reviewers see allowlist diffs |
| Sensitive absolute paths committed (`.mcp.json`) | Information disclosure | Tracked-junk scan + deletion (Open Question 2) |
| Token/secret echo in hygiene output | Information disclosure | Do not print env; the log tee for `mix ci` stays in a `mktemp` file removed on return |

## Delivery Plan (recommended): plans, waves, PRs

Fence (carry-over lesson D-134-01): <= 3 tasks per plan; if a gate halts twice on the same cause, rescope instead of adding plans. One PR per plan, squash with the conventional subject shown. **Never `fix:` or `feat:`.** PR branches tree-identical to main (draft PR for CI observation if needed); serialize merges that touch `ci.yml`.

| Plan | Wave | Reqs | Depends | Content | Commit prefix |
|------|------|------|---------|---------|---------------|
| 135-01 | 1 | CRAFT-03 | - | `artifact_ledger.json` (~40-60 classes + ignore rules), `validate_artifact_ledger.sh`, `test_validate_artifact_ledger.sh`, `ci-script-tests` steps; narrow `.gitignore:16`; `.mcp.json` disposition (after user go-ahead) | `ci:` (+ `chore:` for deletion) |
| 135-02 | 1 | CRAFT-04, CRAFT-06 | - | `scan_live_residue.exs`, classes + calibration, `live_residue_allowlist.json` seeded with every current hit as `pending-removal` / `policy` / `contract` / `immutable-receipt` / `fixture`, ExUnit wrapper with planted-violation fixtures | `test:` |
| 135-03 | 1 | HYGIENE-03 | - | Function-ize `repo_hygiene_check.sh`; add fetch/branch/junk/drift/`mix ci`/residue checks; hex-baseline race WARN in `--ci`; `test_repo_hygiene_check.sh` with real git; wire `ci-script-tests` | `ci:` |
| 135-04 | 2 | CRAFT-03 | 01, 03 | `artifact_package_set_test.exs` (ledger-derived shipped set vs unpack, extract `build_package!` helper from `package_metadata_test.exs` into `test/install_smoke/support/`), ledger `regenerate` parity with `brandbook-tokens` steps; hygiene drift reads ledger | `test:` |
| 135-05 | 2 | CRAFT-05 | 02 | `readability_changes.json` + offline validator, `craft_boundary_check.sh`, `public_surface_snapshot_test.exs` + fixture | `test:` / `ci:` |
| 135-06 | 3 | CRAFT-04, CRAFT-06 | 02 | Tranche A: `lib/`, `config/`, `mix.exs`, `.doctor.exs`, `.dialyzer_ignore.exs` (about 100 lines): comments/docs only; fix `mix.exs:301-306` duplication and `lib` narration (`rindle.ex:900`, `processor/image.ex:68`, `actions_live.ex:574`); `contract` strings stay allowlisted; run `refactor_contract.sh`, docs-parity, doctor | `refactor:` |
| 135-07 | 3 | CRAFT-04, CRAFT-06 | 02 | Tranche B: `.github/workflows`, `.github/actions`, `scripts/**`, `docker/`, `brandbook/src` generators (regenerate CSS + sync + shipped copy), fingerprint copy to `scripts/ci/fixtures/` (per Open Question 1) | `ci:` |
| 135-08 | 4 | CRAFT-04, CRAFT-06 | 06, 07 | Tranche C: `test/install_smoke/**` + `test/*.exs` (332 + 30 lines): rename requirement-id test names to behavior names, fix 4 mojibake lines; update asserting literals together with 07's workflow text | `test:` |
| 135-09 | 4 | CRAFT-04, CRAFT-06 | 06 | Tranche D: `test/rindle/**`, `test/adopter`, `test/brandbook`, `examples/adoption_demo/**` (comment-only), root docs | `test:` / `refactor:` |
| 135-10 | 4 | CRAFT-05 | 05, 06 | Pilot: 5 baseline identities (table above), one cohesive change per module, baseline entries removed, trace entries added, each with focused tests and `refactor_contract.sh` | `refactor:` |
| 135-11 | 5 | all | 01-10 | Closure: flip scanner to "zero `pending-removal`" assertion; update `RUNNING.md`/`CONTRIBUTING.md` pointers to the new gates; run `automation_first_contract.sh`; update `.planning/PROJECT.md` if shipped claims changed; record phase evidence in `.planning` (`docs(135):` PR) | `test:` + `docs(135):` |

Notes: 135-06 and 135-10 touch overlapping lib files (`upload_maintenance`-adjacent code is deliberately excluded from the pilot, but `runtime_checks*`, `lifecycle_repair`, `tus_protocol`, `sweep_orphaned_temp_files` may carry id comments): the pilot is sequenced after tranche A. After each tranche that touches `examples/`, `scripts/` or workflows, confirm the post-merge **main push run** (main-only lanes) is green before proceeding. Total: 11 plans, 5 waves; 135-04 may merge into 135-01 and 135-11 into 135-09 if the planner wants 9.

## Sources

### Primary (HIGH confidence - read or executed in this session)
- `.planning/phases/133-evidence-charter-and-live-truth/133-213-CENSUS-LEDGER.json`, `133-213-CENSUS-RECEIPT.json`, `133-EVIDENCE-CENSUS.json`, `133-REVIEW-DISPOSITION.md`
- `.planning/phases/134-dependency-security-and-inbox-disposition/134-RESEARCH.md`, `134-VERIFICATION.md`; `scripts/maintainer/validate_inbox_ledger.sh`, `scripts/ci/test_*.sh` sizes, `.planning/INBOX-LEDGER.json`
- `scripts/maintainer/repo_hygiene_check.sh` (full), `scripts/maintainer/refactor_contract.sh`, `scripts/maintainer/credo_quality.sh`, `scripts/maintainer/credo_complexity_baseline.json` (27 entries)
- `mix.exs` (package files, aliases, `ci`), `.gitignore`, `.credo.exs`, `.doctor.exs`, `release-please-config.json`, `.release-please-manifest.json`
- `.github/workflows/ci.yml` (jobs list, `ci-script-tests` 1459-1483, `package-consumer-full` 818-819, `brandbook-tokens` 1306+, Proof "Nightly evidence harnesses")
- `test/planning_path_hygiene_test.exs`, `test/install_smoke/repository_residue_test.exs`, `package_metadata_test.exs`, `evidence_census_test.exs`, `test/rindle/api_surface_boundary_test.exs`, `contracts/telemetry_contract_test.exs`
- `mix hex.build --unpack -o <scratch>` (183 files), brandbook generator runs (idempotent), `git ls-files`/`git check-ignore`/python scans over tracked files
- `.planning/todos/pending/2026-10-15-hygiene-baseline-publish-race.md`, `2026-10-16-ledger-landing-record-and-collector-gaps.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md` (Phase 135 section), `AGENTS.md`, project memory notes

### Secondary (MEDIUM confidence)
- Phase 134 research claims about jq/bash portability and `ci-script-tests` being toolchain-free (cited through its comments, not re-measured).

### Tertiary (LOW confidence)
- Assumptions A1-A7 above.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - no new dependencies; all tools verified present.
- Architecture: MEDIUM - shapes derived from Phase 134 precedent; pathspec partition and surface snapshot are prototype-first.
- Pitfalls: HIGH - each derived from a concrete file/line or a recorded project memory.
- Counts: HIGH for the scan (reproducible), upper-bound for class totals because classes overlap.

**Research date:** 2026-10-18
**Valid until:** 2026-11-17 (30 days; counts drift with every merge, so re-run the scanner census at the start of plan 135-02 and trust that number)
