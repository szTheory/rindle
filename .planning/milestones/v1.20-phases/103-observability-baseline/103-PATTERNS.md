# Phase 103: Observability / Baseline - Pattern Map

**Mapped:** 2026-06-20
**Files analyzed:** 6 (4 modify, 2 create + 1 doc create)
**Analogs found:** 6 / 6 (every touched file has an in-repo analog)

> All work is **additive/observational** (D-14: zero gate-behavior change). No `run:` command's
> pass/fail changes, nothing is renamed, `permissions:` is never widened at workflow level.
> `./CLAUDE.md` does not exist; constraints come from CONTEXT.md D-01..D-14 + RESEARCH.md.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `.github/workflows/ci.yml` (MODIFY) | config / CI workflow | event-driven (CI) + request-response (`gh api`) | self (existing cache `id:`, `$GITHUB_STEP_SUMMARY`) + `release.yml:101-103` (job-scoped perms) + `branch-protection-apply.yml:28-33` (summary append) | exact (in-file + sibling workflow) |
| `mix.exs` (MODIFY) | config / build manifest | n/a (declarative deps) | self — existing `only: :test` deps block (`mix.exs:125-136`) + `files:` allowlist (`mix.exs:278-279`) | exact (same file) |
| `test/test_helper.exs` (MODIFY) | config / test bootstrap | n/a (test setup) | self — existing `ExUnit.start(exclude: …)` (`test_helper.exs:24-31`) | exact (same file) |
| `scripts/ci/collect_ci_baseline.sh` (CREATE) | utility / maintainer script | request-response (`gh api`) + batch (aggregate over N runs) | `scripts/ci/cohort_demo_smoke.sh` (house style) + `scripts/setup_branch_protection.sh` (`gh api`/`jq`) | role-match (no existing `gh api` collector) |
| `scripts/ci/check_required_checks.sh` (CREATE) | utility / maintainer script | request-response (`gh api`) + transform (diff) | `scripts/setup_branch_protection.sh` (`--print-expected-json`, same protection endpoint) | exact (same domain + diff target) |
| `.planning/phases/103-observability-baseline/103-BASELINE.md` (CREATE) | doc (internal) | n/a | none needed — internal `.planning/` doc, deliberately outside Hex `files:`/`extras` | n/a |
| `.gitignore` (verify only) | config | n/a | self | already covered — see "Shared Patterns / gitignore" |

---

## Pattern Assignments

### `.github/workflows/ci.yml` (MODIFY — config, event-driven)

Four additive change-classes. Each replicates an existing in-repo pattern. **Do not** rename the
file or `name: CI` (D-13; `ci.yml:1`). **Do not** touch workflow-level `permissions: contents: read`
(`ci.yml:18-19`).

**1. Add `id:` to deps/`_build` cache restore steps (D-02).**
The PLT step is the only one with an `id:` today — replicate that exact shape.

Existing PLT pattern to copy (`ci.yml:120-126`):
```yaml
      - name: Restore PLT cache
        uses: actions/cache@v4
        id: plt-cache
        with:
          path: priv/plts
          key: plt-${{ runner.os }}-${{ matrix.elixir }}-${{ matrix.otp }}-${{ hashFiles('**/mix.lock') }}
          restore-keys: plt-${{ runner.os }}-${{ matrix.elixir }}-${{ matrix.otp }}-
```

Apply the same `id:` line to the un-id'd restore steps — `quality` deps cache (`ci.yml:65-70`),
`quality` build cache (`ci.yml:72-77`), `integration` deps/build cache (`ci.yml:228-240`), and the
matching restore steps in `package-consumer` (job starts `ci.yml:423`). Add only the `id:` key
(e.g. `id: deps-cache`, `id: build-cache`); leave `path`/`key`/`restore-keys` byte-for-byte intact:
```yaml
      - name: Restore deps cache
        uses: actions/cache@v4
        id: deps-cache              # ADD — was unset; makes steps.deps-cache.outputs.cache-hit readable
        with:
          path: deps
          key: deps-${{ runner.os }}-${{ matrix.elixir }}-${{ matrix.otp }}-${{ hashFiles('**/mix.lock') }}
          restore-keys: deps-${{ runner.os }}-${{ matrix.elixir }}-${{ matrix.otp }}-
```

**2. Append timing / cache hit-miss / OBS-02 evidence to `$GITHUB_STEP_SUMMARY` (D-01, D-04, D-05).**
Copy the brace-group redirect idiom verbatim from `branch-protection-apply.yml:28-33`:
```yaml
            {
              echo "## Branch Protection Apply — Skipped"
              echo ""
              echo "BRANCH_PROTECTION_PAT secret not set."
              echo "Add a fine-grained PAT with Administration read/write for this repo."
            } >> "$GITHUB_STEP_SUMMARY"
```
New summary steps land **inline in `quality`, `integration`, `package-consumer` only** (D-04 scope).
Coalesce `cache-hit` with `|| 'false'` (Pitfall 1 — partial `restore-keys` hits leave it empty).
For OBS-02, wrap (do **not** replace) the existing test step `mix coveralls` (`ci.yml:117-118`):
```yaml
      - name: Run tests with coverage
        run: mix coveralls
```
The gating run stays `mix coveralls`; `--slowest 20`, seed grep, `mix compile --profile time`, and
`System.schedulers_online()` are added as additive surfacing (tee to summary). See RESEARCH.md
§"OBS-02 evidence step" for the exact step bodies.

**3. JUnit + coverage artifact upload (D-06, D-07).**
Copy the `actions/upload-artifact@v4` shape from `ci.yml:752-760` (note `if:` guard + multi-line
`path:` + `if-no-files-found:`):
```yaml
      - name: Upload Playwright report on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: adoption-demo-playwright-report
          path: |
            examples/adoption_demo/playwright-report/
            examples/adoption_demo/test-results/
          if-no-files-found: ignore
```
For 103, use `if: always()` (artifacts wanted on pass too), `name: junit-coverage-${{ github.job }}-…`,
`path:` = `_build/test/junit/rindle-junit.xml` + `cover/excoveralls.json`. Add a sibling
`mix coveralls.json` step (`if: always()`) — additive, NOT a replacement for the gating `mix coveralls`
(D-07 / RESEARCH.md Anti-Patterns). `retention-days` is planner discretion.

**4. `ci-observability` aggregator job (D-03 option b).**
Copy the **job-scoped `permissions:`** pattern from `release.yml:101-103` — this is the precedent that
`actions: read` can be scoped to one job without widening the workflow default:
```yaml
  gate-ci-green:
    name: Gate on Exact-SHA Green CI
    needs: [recovery-validation]
    ...
    permissions:
      actions: read
      contents: read
```
The new job declares `permissions: { actions: read }` at job level only, `if: always()`, and
`needs:` the non-skip-prone jobs. **Confirmed job keys** (from `ci.yml`):
`quality`, `optional-dependencies`, `integration`, `contract`, `proof`, `package-consumer`,
`adoption-demo-unit`, `cohort-demo-smoke`, `adoption-demo-e2e`, `adopter`, `brandbook-tokens`.
**OMIT** `mux-soak`, `gcs-soak`, `package-consumer-gcs-live` from `needs:` (Pitfall 4 — they
`if:`-skip on forks/unlabeled PRs and would block/fail the aggregator). Job body uses the
`gh api .../runs/${RUN_ID}/jobs` call from RESEARCH.md §Pattern 1.

---

### `mix.exs` (MODIFY — config, declarative)

**Analog:** the existing `only: :test` deps block — copy the entry shape exactly.

Dev/Test deps block (`mix.exs:125-135`) — add the new line alongside the existing test-only deps:
```elixir
      # Dev/Test
      {:lazy_html, ">= 0.1.0", only: :test},
      {:mox, "~> 1.2", only: :test},
      {:bypass, "~> 2.1", only: :test},
      {:ex_machina, "~> 2.7", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.22.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:test, :dev], runtime: false},
```
Add: `{:junit_formatter, "~> 3.4", only: :test},` (D-06). The `only: :test` scope is what keeps it
out of the shipped package.

**`files:` allowlist (`mix.exs:278-279`) — DO NOT EDIT, just confirm it excludes the dep:**
```elixir
      files:
        ~w(lib priv/repo/migrations priv/static/rindle_admin mix.exs README.md RUNNING.md CHANGELOG.md LICENSE guides)
```
No `_build`/`deps`/`test` entry here ⇒ the test-only dep never ships (basis for "zero `lib/` change").
ExCoveralls is already wired (`mix.exs:43` `test_coverage: [tool: ExCoveralls]`; `mix.exs:49-53`
`preferred_envs` maps `coveralls.json`/`coveralls.html` to `:test`) — no coverage tooling change.

---

### `test/test_helper.exs` (MODIFY — config, test bootstrap)

**Analog:** the current bare `ExUnit.start` — extend it, do not restructure.

Existing tail of the helper (`test_helper.exs:24-35`):
```elixir
exclude_tags =
  if targeted_adopter_or_integration? do
    [:minio, :contract]
  else
    [:integration, :minio, :contract, :adopter]
  end

ExUnit.start(exclude: exclude_tags)

unless Code.ensure_loaded?(Rindle.StorageMock) do
  Code.require_file("support/mocks.ex", __DIR__)
end
```
Keep `exclude_tags` and the repo/Oban/Mock startup (`test_helper.exs:1-15, 33-35`) intact. Add a
`formatters` list + `Application.put_env(:junit_formatter, …)` lines before `ExUnit.start`, then pass
`formatters: formatters` on `ExUnit.start` (D-06; exact body in RESEARCH.md §"junit_formatter wiring").
Gate `JUnitFormatter` on `System.get_env("CI")` so local runs stay quiet. Target XML path:
`_build/test/junit/rindle-junit.xml` (must match the upload-artifact `path:` in ci.yml).

---

### `scripts/ci/collect_ci_baseline.sh` (CREATE — utility, batch over `gh api`)

**Analog (house style):** `scripts/ci/cohort_demo_smoke.sh`. Replicate the shebang + leading
comment block + `set -euo pipefail` + `repo_root` resolution (`cohort_demo_smoke.sh:1-25`):
```bash
#!/usr/bin/env bash
# Cold-start smoke for the Cohort Docker-compose demo stack.
#
# [... multi-line WHY comment block — match this documentation density ...]
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"
```
Also note `install_ffmpeg.sh:24,38` `echo "[prefix] …"` logging idiom and `--retry`-style robustness.

**Analog (`gh api` + `jq` mechanics):** `scripts/setup_branch_protection.sh:64-85, 100-116` — env-var
defaults (`OWNER`/`REPO_NAME` with `:-` fallbacks), the `command -v gh`/`command -v jq` guards
(`setup_branch_protection.sh:100-108`), and `gh api -H "Accept: application/vnd.github+json"`.
Body (runs/jobs aggregation, `run_attempt` rerun derivation, awk avg/p95) = RESEARCH.md §collector
skeleton. Read-only; maintainer-local `gh` session. Output is a Markdown table for `103-BASELINE.md`.

---

### `scripts/ci/check_required_checks.sh` (CREATE — utility, `gh api` + diff)

**Analog (exact domain):** `scripts/setup_branch_protection.sh`. This new script is the **read+diff**
sibling of the existing **write** script. Reuse its expected list via the existing flag rather than
re-encoding names.

The diff target — `--print-expected-json` (`setup_branch_protection.sh:64-96`):
```bash
expected_json() {
  ...
  jq -n --argjson contexts "${contexts_json}" \
    '{ required_status_checks: { strict: true, contexts: $contexts }, ... }'
}
case "${1:-}" in
  --print-expected-json)
    expected_json
    exit 0
    ;;
esac
```
And the live read uses the **same endpoint + headers** as the write path (`setup_branch_protection.sh:112-116`),
but GET the `required_status_checks` sub-resource and read `.contexts[]` (Pitfall 3 — prefer
`.contexts[]` over `.checks[].context`):
```bash
gh api -X PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "repos/${REPO}/branches/${BRANCH}/protection" \
```
Full body in RESEARCH.md §check_required_checks skeleton. **Expected live drift today:** `brandbook-tokens`
(expected at `setup_branch_protection.sh:30`) is missing from live `.contexts[]` — record verbatim,
do NOT re-apply (D-09/D-14 — reading only, no mutation).

---

### `.planning/.../103-BASELINE.md` (CREATE — internal doc)

No code analog. Committed internal doc holding the collector's table + verbatim live required-check
names + the recorded drift. Stays in `.planning/` only — NOT in Hex `files:` (`mix.exs:278-279`) or
HexDocs `extras` (D-10). No `.gitignore` exclusion needed (`.planning/` is committed except the
`.gsd*`/`tmp_*` patterns already in `.gitignore`).

---

## Shared Patterns

### `$GITHUB_STEP_SUMMARY` append (brace-group redirect)
**Source:** `.github/workflows/branch-protection-apply.yml:28-33`
**Apply to:** every new summary-writing step in `ci.yml` (cache hit/miss, per-step timing, OBS-02
evidence, aggregator per-job table).
```bash
{
  echo "## Heading"
  echo ""
  echo "| Col | Col |"
  echo "| --- | --- |"
} >> "$GITHUB_STEP_SUMMARY"
```

### Job-scoped least-privilege `permissions:`
**Source:** `.github/workflows/release.yml:101-103` (`gate-ci-green` job)
**Apply to:** the `ci-observability` aggregator job only.
```yaml
    permissions:
      actions: read
```
Job-level `permissions:` overrides the workflow default **for that job only** — workflow-level
`contents: read` (`ci.yml:18-19`) stays untouched (D-03/D-14, ASVS V4/V14).

### `gh api` + `jq` over GitHub JSON (maintainer scripts)
**Source:** `scripts/setup_branch_protection.sh` (`gh`/`jq` `command -v` guards `:100-108`;
`-H "Accept: application/vnd.github+json"` + `-H "X-GitHub-Api-Version: 2022-11-28"` `:112-116`;
env-default vars `:11-15`).
**Apply to:** both new `scripts/ci/*.sh` files.

### Shell house style (`scripts/ci/`)
**Source:** `scripts/ci/cohort_demo_smoke.sh:1-25` (shebang, multi-line WHY block, `set -euo pipefail`,
`repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"`) and `install_ffmpeg.sh:24,38`
(`echo "[prefix] …"` logging, fail-loud guards).
**Apply to:** both new `scripts/ci/*.sh` files. Wave-0 gate: `bash -n <script>`.

### `actions/upload-artifact@v4` shape
**Source:** `.github/workflows/ci.yml:752-760`
**Apply to:** the OBS-02 JUnit+coverage upload step (swap `if: failure()`→`if: always()`,
new `name:`/`path:`).

### gitignore coverage (already satisfied)
**Source:** `.gitignore` — `/_build/` and `/cover/` are already ignored.
**Implication:** JUnit XML at `_build/test/junit/rindle-junit.xml` and `cover/excoveralls.json` are
**already** gitignored. The "possibly MODIFY `.gitignore`" item resolves to **verify only** — no
edit needed unless the planner chooses a JUnit `report_dir` outside `_build/`. (If `report_dir`
stays under `_build/`, no `.gitignore` change at all.)

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `.planning/.../103-BASELINE.md` | doc | n/a | Internal `.planning/` artifact; no code pattern to copy (note: keep out of Hex `files:`/`extras`). |

(No source-code file lacks an analog. The `ci-observability` aggregator job has no prior
*aggregator* job in `ci.yml`, but its two load-bearing patterns — job-scoped `permissions: actions: read`
and `gh api` reads — both have exact in-repo precedents cited above.)

---

## Metadata

**Analog search scope:** `.github/workflows/` (ci.yml, release.yml, branch-protection-apply.yml),
`scripts/` (setup_branch_protection.sh), `scripts/ci/` (cohort_demo_smoke.sh, install_ffmpeg.sh,
adoption_demo_e2e.sh, adoption_demo_gcs_live.sh), `mix.exs`, `test/test_helper.exs`, `.gitignore`.
**Files scanned:** 11
**Pattern extraction date:** 2026-06-20
