# Phase 104: Cache & Tooling Hygiene - Context

**Gathered:** 2026-06-21 (assumptions mode + maintainer-requested ecosystem research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Remove low-risk CI waste and fix **cache correctness + tooling hygiene** in the existing
`.github/workflows/ci.yml` (and the stray `release.yml` action) while keeping the
**single-workflow shape** — no required-check rename, no lane/trigger split. This is the
precondition for safely reshaping lanes later (Phase 106).

**In scope (CACHE-01..05):**
- CACHE-01 — `.github/actions/setup-elixir` composite action (+ shared MinIO setup) as the single
  source of truth for environment setup + cache keys across the jobs that duplicate it today.
- CACHE-02 — correct cache keys (OS+arch, OTP, Elixir, `MIX_ENV`, `mix.lock` hash, version buster);
  deps/`_build`/PLT kept separate, never restored across incompatible dimensions.
- CACHE-03 — Dialyzer PLT `actions/cache` **restore/save split** that persists the built PLT even
  when analysis fails; PLT key hashes `mix.exs`/`.dialyzer_ignore.exs`.
- CACHE-04 — `mix deps.get --check-locked` + `mix deps.unlock --check-unused` gate lockfile drift.
- CACHE-05 — version-invariant lint runs **once** on the primary pair; `.tool-versions` lands; the
  stray `setup-ffmpeg` in `release.yml` aligns to the repo's ffmpeg install path.

**Out of scope (later phases — do NOT pull forward):**
- `CI Summary` aggregate required check + branch-protection flip → **Phase 105** (GATE-01..02).
- Trigger/lane split, scoped package-consumer, nightly lane, concurrency groups → **Phase 106**
  (LANE-01..04).
- ExUnit async-safety/partitioning, action **SHA-pinning** + `dependabot.yml` + `mix_audit`,
  per-job least-privilege `permissions:`, `mix ci` alias + `CONTRIBUTING.md`, faithful
  Linux-Chromium repro → **Phase 107** (HARD-01..04).
</domain>

<decisions>
## Implementation Decisions

> Posture: decide-by-default. These are **locked**; alternatives appear only as rationale.
> Where the maintainer's CACHE-0x requirement text and the ecosystem-optimal pattern diverged,
> the **requirement text wins** (it is the contract, and the literal choice is a safe superset).

### CACHE-01 — Composite actions (DRY the duplicated setup)

- **D-01:** Create `.github/actions/setup-elixir/action.yml` as a **composite action** encapsulating
  `erlef/setup-beam@v1` → deps `actions/cache` → `_build` `actions/cache`. Inputs (explicit —
  composites cannot read the caller's `matrix`): `elixir-version` (required), `otp-version`
  (required), `mix-env` (default `test`), `cache-prefix` (default `deps`/`build`; set to
  `no-optional` for the `optional-dependencies` job to preserve its deliberately-separate cache
  namespace), `install-deps` (bool, default `true`). It **exposes the deps/`_build` `cache-hit`
  values as action `outputs:`** so the Phase-103 OBS-01 "cache hit/miss" `$GITHUB_STEP_SUMMARY`
  table keeps working unchanged. It does **NOT** compile — job-specific compile flags
  (`--warnings-as-errors`, `--no-optional-deps`, plain `mix compile`) stay at job level.

- **D-02:** Create a **second** composite `.github/actions/setup-minio/action.yml` for the
  MinIO bring-up trio (`docker run … minio/minio` + install `mc` client + create bucket). These are
  manual `run:` steps (NOT a job-level `services:` container), so they are movable into a composite.
  Job-level `env:` (`RINDLE_MINIO_*`) and any secret/label `if:` gates stay at job level.

- **D-03:** Adopt `setup-elixir` across the **9** jobs that inline the setup triplet today —
  `quality`, `integration`, `contract`, `proof`, `package-consumer`, `adoption-demo-unit`,
  `adoption-demo-e2e`, `adopter`, `package-consumer-gcs-live`. Adopt `setup-minio` across the **5**
  ci.yml jobs that duplicate the trio — `integration`, `package-consumer`, `adoption-demo-e2e`,
  `adopter`, `mux-soak` — **and** the **2** `release.yml` jobs (`publish`, `public_verify`) that
  duplicate it (CACHE-01 says "single source of truth"). **Migration order:** (1) `quality` first
  (matrix-driven — exercises the version inputs + cache outputs), confirm cache hits and the OBS-01
  summary are byte-identical; (2) the literal-`1.17/27` jobs; (3) `optional-dependencies` with
  `cache-prefix: no-optional`; (4) the MinIO trios. `gcs-soak`/`package-consumer-gcs-live` guard
  every step on an `enabled == 'true'` output — apply that `if:` to the composite call itself.

- **D-04:** A composite changes **step internals only** — job names, the `ci.yml` filename, and
  `name: CI` are untouched, so branch protection and the release train keep working. (See D-15.)

### CACHE-02 / CACHE-03 — Cache-key schema + PLT restore/save split

- **D-05:** Use **one uniform key template** for deps and `_build`, built from the composite's own
  resolved `setup-beam` outputs (patch-level, not coarse `matrix.otp`):
  ```
  deps:   deps-v1-${{ runner.os }}-${{ runner.arch }}-otp${{ steps.beam.outputs.otp-version }}-elixir${{ steps.beam.outputs.elixir-version }}-${{ env.MIX_ENV }}-${{ hashFiles('mix.lock') }}
          restore-keys: deps-v1-${{ runner.os }}-${{ runner.arch }}-otp…-elixir…-${{ env.MIX_ENV }}-
  _build: build-v1-${{ runner.os }}-${{ runner.arch }}-otp…-elixir…-${{ env.MIX_ENV }}-${{ hashFiles('mix.lock') }}
          restore-keys: build-v1-${{ runner.os }}-${{ runner.arch }}-otp…-elixir…-${{ env.MIX_ENV }}-
  ```
  This satisfies CACHE-02's literal schema (OS+arch, OTP, Elixir, `MIX_ENV`, lock hash, `v1`
  buster). `restore-keys` falls back across `mix.lock` hashes only — OTP/Elixir/`MIX_ENV` live in
  the **prefix** so a fallback can never poison `_build` across incompatible toolchains.
  - *Rationale / declined alternative:* the felt/ultimate-elixir-ci optimization (omit OTP/Elixir
    from the **deps** key so source tarballs are shared across the matrix; drop `runner.arch` on a
    single-arch runner) is **deliberately declined** — at this 2-cell matrix the saved deps download
    is negligible, and a uniform key shape both honors CACHE-02's literal text and is far easier to
    audit in review. `runner.arch` is a constant `X64` today but future-proofs an ARM/macOS leg at
    zero cost.

- **D-06:** Keep deps / `_build` / PLT as **three separate caches**. Preserve the
  `optional-dependencies` job's distinct namespace — it becomes `deps-no-optional-v1-…` /
  `build-no-optional-v1-…` via the `cache-prefix` input (D-01).

- **D-07:** The **PLT** key hashes **`mix.exs` + `.dialyzer_ignore.exs`** (NOT `mix.lock`); its
  prefix carries OS+arch+OTP+Elixir+buster:
  ```
  plt-v1-${{ runner.os }}-${{ runner.arch }}-otp…-elixir…-${{ hashFiles('mix.exs', '.dialyzer_ignore.exs') }}
  restore-keys: plt-v1-${{ runner.os }}-${{ runner.arch }}-otp…-elixir…-
  ```
  Rationale: the PLT is invalidated by the analyzed-app set (`mix.exs` `:dialyzer`/`:deps`) and the
  ignore rules + BEAM version — not by transitive lock pins. Hashing `mix.lock` there would
  over-invalidate the PLT (multi-minute rebuild) on every unrelated dep bump.

- **D-08:** Convert the PLT step from the single `actions/cache@v4` to the **restore/save split**:
  `actions/cache/restore@v4` (`id: plt_cache`) → build-PLT-if-miss (`if: cache-hit != 'true'`) →
  **`actions/cache/save@v4` placed BEFORE the `mix dialyzer` analysis step**, guarded
  `if: steps.plt_cache.outputs.cache-hit != 'true'`. Saving the PLT *before* analysis is the crux of
  CACHE-03 — the built PLT then persists even when `mix dialyzer` surfaces issues (it stays
  `continue-on-error`). The `cache-hit != 'true'` predicate saves on a cold OR prefix-only hit and
  skips only on an exact-key hit, avoiding both never-saving and the immutable-cache
  "already exists" re-save warning. (Do NOT use `if: always()` here.)

- **D-09:** Set `env: MIX_ENV` **explicitly** on every cache-bearing job so the key segment is never
  empty (an unset `MIX_ENV` renders `…-Linux--<hash>` and silently forks a separate cache lineage).
  Use `hashFiles('mix.lock')` (repo-root) — NOT `hashFiles('**/mix.lock')` — for this flat (non-
  umbrella) library.

### CACHE-04 — Lockfile-drift gates

- **D-10:** Add `--check-locked` to the existing `mix deps.get` step in `quality` so it runs on
  **both** matrix cells: `mix deps.get --check-locked`. It is free (a flag on a step that already
  runs), validates lock-vs-`mix.exs` even on a full cache hit, and closes the "broad `restore-keys`
  serves a stale partial-hit deps tree" gap on the OTP26 cell too.

- **D-11:** Add a **separate** `mix deps.unlock --check-unused` step in `quality`, **guarded to the
  lock's resolution OTP**: `if: matrix.otp == '27'`. `--check-unused` evaluates `mix.exs` against the
  **running** OTP; running it on a cell whose OTP differs from the lock's resolution OTP
  false-positives on the conditionally-included `{:json_polyfill, …}` dep (added only when OTP < 27;
  `mix.exs:141-147`). The repo's `mix.lock` is resolved under OTP 27, so pinning the check to OTP 27
  makes that false positive structurally impossible. (Empirically reproduced in research — see
  DISCUSSION-LOG.)

### CACHE-05 — Lint de-dup + `.tool-versions` + ffmpeg alignment

- **D-12:** De-dup version-invariant lint using the **Phoenix/Ecto/Oban idiom**: add `lint: true` to
  the **1.17/OTP27** matrix include and guard `mix format --check-formatted`, `mix credo --strict`,
  and `mix doctor --full --raise` with `if: ${{ matrix.lint }}`. This keeps lint **inside the
  `quality` job** → required-check names (`Quality (1.15, 26)` / `Quality (1.17, 27)`) stay
  byte-identical (a *separate* lint job would mint a new required-check name — deferred to the
  later lane-split phase). Home pair = **newest (1.17/27)** so the formatter enforces what an
  up-to-date contributor's local toolchain produces. Keep the existing `continue-on-error` on
  credo/doctor exactly as-is (this is de-dup, **not** gate-tightening). The plan must assert the
  lint step actually executed (a typo'd `if:` would silently skip lint with a green check).

- **D-13:** Land a repo-root **`.tool-versions`** (asdf format, tracks the primary/newest pair):
  ```
  elixir 1.17.<patch>-otp-27
  erlang 27.<patch>
  nodejs 20.<patch>
  ```
  This phase keeps it **local-dev-only** — do NOT wire `setup-beam` `version-file:` (that forces
  `version-type: strict` and risks CI churn); CI's inline `1.17`/`27` matrix stays the source of
  truth. Use `.tool-versions` (not `.mise.toml`) — it is the superset that serves both asdf and mise.
  *Execution note:* pin the exact patch strings to whatever `setup-beam` resolves for `1.17`/`27`
  (verify via `asdf list-all elixir | grep 1.17` and the run's resolved OTP) so local and CI agree.

- **D-14:** Replace `release.yml`'s `FedericoCarboni/setup-ffmpeg@v3` with
  `run: bash scripts/ci/install_ffmpeg.sh` — the canonical path already used 4× in `ci.yml` (BtbN
  static build, enforces ffmpeg ≥ 6). Safe: the `public_verify` job already runs repo scripts
  (`scripts/public_smoke.sh`), so the "prove install without repo scripts" argument doesn't hold.
  Retires the last stray instance of the documented intermittent-failure action. (Full SHA-pinning
  of *all* actions is Phase 107 — not here.)

### Hard invariants (highest blast radius — do not break)

- **D-15:** Never rename the `ci.yml` filename or its `name: CI`, and never change a **required-check
  (job) NAME** — release-train coupling via `release-please-automerge.yml` + `gate-ci-green`
  (filters `workflow_id: 'ci.yml'`) and branch protection both depend on them. All CACHE work
  changes step internals / adds steps only.

- **D-16:** Preserve the **single-workflow shape** — no reusable *workflows*, no `CI Summary`
  aggregate (Phase 105), no lane/trigger split or concurrency groups (Phase 106), no
  async/partition/SHA-pin/`mix ci` (Phase 107).

### Claude's Discretion / carried research flags
- Final composite input naming + exact `outputs:` wiring — planner choice within D-01.
- Exact `actions/cache/restore@v4` + `actions/cache/save@v4` YAML — pattern confirmed against
  dialyxir's own GitHub Actions doc; planner applies current `@v4` sub-action paths.
- Exact `.tool-versions` patch strings — verify against `setup-beam`'s live `1.17`/`27` resolution
  at execution (D-13).

### Folded Todos
- None. (The `2026-06-19-fix-docker-demo-startup-warnings` todo was reviewed and **not folded** —
  see Deferred.)
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/REQUIREMENTS.md` — CACHE-01..05 (authoritative acceptance criteria) + the GATE/LANE/
  HARD requirements that bound this phase's "out of scope", + the "Out of Scope" anti-features.
- `.planning/ROADMAP.md` — Phase 104 detail (Goal, Success criteria 1–5) and the load-bearing
  dependency-order note (104 must NOT rename required checks; that is 105).
- `.github/workflows/ci.yml` — the ~14-job pipeline. The 9 jobs inlining the setup triplet
  (quality, integration, contract, proof, package-consumer, adoption-demo-unit, adoption-demo-e2e,
  adopter, package-consumer-gcs-live); the 5 MinIO-trio jobs (integration, package-consumer,
  adoption-demo-e2e, adopter, mux-soak); current cache keys (deps ~L70, `_build` ~L78, PLT ~L165);
  the matrixed lint steps (`format`/`credo`/`doctor` ~L97-110); `mix deps.get` ~L85.
- `.github/workflows/release.yml` — the stray `FedericoCarboni/setup-ffmpeg@v3` (~L457) + the 2
  MinIO-trio jobs (`publish`, `public_verify`).
- `scripts/ci/install_ffmpeg.sh` — the canonical ffmpeg path (BtbN static, ffmpeg ≥ 6) that CACHE-05
  aligns `release.yml` onto.
- `mix.exs` — dialyzer config (`plt_file: priv/plts/dialyzer.plt`, `ignore_warnings:
  ".dialyzer_ignore.exs"`, ~L38-42), the conditional `json_polyfill_dep/0` (OTP<27 guard, ~L141-147),
  and the `~> 1.15` elixir constraint.
- `.dialyzer_ignore.exs` — hashed into the PLT key (D-07).
- `scripts/setup_branch_protection.sh` — the static *expected* required-check NAME list; CACHE work
  must keep every name it lists intact (do NOT edit it this phase — that is Phase 105).
- `.github/workflows/release-please-automerge.yml` + `gate-ci-green` — the release-train coupling
  that pins `ci.yml`'s filename + `name: CI`.
- `.planning/phases/103-observability-baseline/103-CONTEXT.md` + `103-BASELINE.md` — what Phase 103
  already added (cache `id:`s, OBS-01 summary, captured baseline + live required-check names); the
  cache `id:` work must be preserved/threaded through the composite's `outputs:`.

**Prior-art reference workflows (validated this phase — adapt, don't blind-copy):**
- `phoenixframework/phoenix`, `elixir-ecto/ecto`, `sorentwo/oban` — the `matrix.lint` +
  `if: ${{ matrix.lint }}` lint-on-newest idiom (D-12); they inline setup at 2–4 jobs.
- `felt/ultimate-elixir-ci` (`.github/actions/elixir-setup/action.yml`) — canonical composite input
  schema (D-01); also the deps-vs-`_build` key split (the optimization declined in D-05's rationale).
- `jeremyjh/dialyxir` GitHub Actions doc — the PLT restore/save split + `cache-hit != 'true'` guard
  (D-08).
- `erlef/setup-beam` README — `outputs.otp-version`/`elixir-version` for resolved-version keys (D-05);
  `version-type: strict` is mandatory with a version file (why D-13 stays local-dev-only).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/ci/install_ffmpeg.sh` already the canonical ffmpeg path (used 4× in `ci.yml`) → the
  single target `release.yml` aligns onto (D-14).
- Phase 103 already set cache `id:`s + the OBS-01 `$GITHUB_STEP_SUMMARY` cache hit/miss table → the
  composite must expose `cache-hit` via `outputs:` so that summary keeps working (D-01).
- The `optional-dependencies` job already proves the repo treats incompatible deps trees as a
  distinct cache namespace (`deps-no-optional-`/`build-no-optional-`) → preserved via `cache-prefix`
  (D-06), not re-invented.
- `erlef/setup-beam@v1` already in every job; it has **no** built-in deps/`_build` caching (only its
  own tool install) → `actions/cache` for deps/`_build` stays mandatory, encapsulated in the
  composite.

### Established Patterns
- Job NAMES are load-bearing required checks (branch protection + `gate-ci-green`) → composite
  refactor and lint de-dup are chosen specifically to keep names byte-identical (D-04, D-12, D-15).
- `continue-on-error` on `credo`/`doctor` is the current advisory posture (CI-04 policy) → preserved;
  this phase does not tighten gates (D-12).
- Conditional `json_polyfill` (OTP<27) is the one dep whose presence depends on the matrix cell →
  drives the `--check-unused` OTP guard (D-11).

### Integration Points
- New composites land in `.github/actions/{setup-elixir,setup-minio}/action.yml`; consumed via
  `uses: ./.github/actions/…` (in-repo path — no SHA pin needed).
- Cache-key changes + PLT restore/save split land inside the `setup-elixir` composite (deps/`_build`)
  and in the `quality` job (PLT) of `ci.yml`.
- `--check-locked`/`--check-unused` land in the `quality` job; `.tool-versions` at repo root;
  ffmpeg swap in `release.yml`.
</code_context>

<specifics>
## Specific Ideas

- Maintainer asked for an explicit ecosystem-research pass per area (pros/cons/tradeoffs, idiomatic
  Elixir/Phoenix CI, lessons from successful libs, DX/least-surprise, footguns) → four parallel
  `gsd-advisor-researcher` agents ran; their decisive recommendations are folded into the decisions
  above and the audit trail in DISCUSSION-LOG.
- Where a CACHE-0x requirement's literal key/version schema diverged from the ecosystem-optimal
  micro-optimization, the **requirement text was honored** (uniform full-dimension keys incl. arch;
  D-05) and the optimization recorded as a deliberate, documented decline.
- "User" for this DX-infrastructure phase = the OSS contributor/maintainer; least-surprise + stable
  required-check names + a one-command-local-toolchain (`.tool-versions`) are the DX wins.
</specifics>

<deferred>
## Deferred Ideas

- felt-style **deps-cache sharing across the matrix** (omit OTP/Elixir from the deps key) +
  dropping `runner.arch` — declined now (negligible at 2 cells; diverges from CACHE-02's literal
  schema). Revisit only if the matrix grows or an ARM/macOS leg lands.
- A clean **separate `lint`/`static` job** (vs the `if: ${{ matrix.lint }}` in-job gate) — nicer
  long-term, but it mints a new required-check name → **Phase 106** (lane split), where check-name
  changes are in scope.
- Wiring `setup-beam` `version-file: .tool-versions` (`version-type: strict`) — deferred; keep CI's
  inline matrix authoritative this phase to avoid churn.
- `CI Summary` aggregate + branch-protection flip → **Phase 105** (GATE-01..02).
- Trigger/lane split, scoped package-consumer, nightly lane, concurrency → **Phase 106** (LANE-01..04).
- ExUnit async/partitioning, action **SHA-pinning** + `dependabot.yml` + `mix_audit` +
  least-privilege `permissions:`, `mix ci` + `CONTRIBUTING.md`, Linux-Chromium repro → **Phase 107**
  (HARD-01..04).

### Reviewed Todos (not folded)
- `2026-06-19-fix-docker-demo-startup-warnings.md` (tooling, score 0.7) — keyword/area match only;
  it is **demo-runtime noise** (Mox/inotify warnings inside the Cohort demo container), unrelated to
  CI cache/tooling hygiene. Not folded into Phase 104 (same disposition as Phase 103).
</deferred>
