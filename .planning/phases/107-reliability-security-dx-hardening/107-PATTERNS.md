# Phase 107: Reliability, Security & DX Hardening - Pattern Map

**Mapped:** 2026-06-22
**Files analyzed:** 5 NEW + ~12 EDIT (workflows/actions/data modules collapsed by family)
**Analogs found:** 5 / 5 NEW with in-repo or sibling-repo analogs; all EDIT targets have an established in-file pattern

> RESEARCH.md already resolved the exact SHAs (11), the container tag (`v1.57.0-noble`),
> the per-file async classification (15 clean / 53 unsafe), and the shared-constant shape.
> This PATTERNS.md adds the **concrete analog code excerpts** the executor mirrors, with
> file paths + line numbers. Do not re-derive values RESEARCH.md already locked.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `test/async_safety_guard_test.exs` (NEW) | test (meta/AST) | transform (file-glob → AST → assert) | `test/install_smoke/docs_parity_test.exs` | role-match (meta-test that globs+reads+asserts; AST walk is new) |
| `.github/dependabot.yml` (NEW) | config | batch (scheduled PR updates) | `/Users/jon/projects/lattice_stripe/.github/dependabot.yml` | exact (family-shipped shape) |
| `brandbook/src/contrast-constants.mjs` (NEW) | utility (constant module) | n/a (pure export) | `brandbook/src/contrast.mjs` (export/import style) | role-match (ESM `export const` in same dir) |
| `scripts/ci/e2e_local.sh` (NEW) | utility (shell wrapper) | event-driven (CI/local invocation) | `scripts/ci/adoption_demo_e2e.sh` | exact (same lane, same demo dir, same `set -euo pipefail` + `repo_root` idiom) |
| `mix.exs` `deps/0` `{:mix_audit, ...}` (EDIT) | config | n/a | `mix.exs:127` `{:junit_formatter, "~> 3.4", only: :test}` | exact (test/dev-only-dep pattern) |
| `mix.exs` `aliases/0` `ci:` (EDIT) | config | batch (task list) | `mix.exs:284` `precommit: ["test"]` + `test:` alias | role-match (alias list; `ci` mirrors PR set) |
| `.github/workflows/{ci,nightly,release,release-please-automerge,branch-protection-apply}.yml` + `.github/actions/{setup-elixir,setup-minio}/action.yml` SHA pins + `permissions:` (EDIT) | config | n/a | `nightly.yml:444` job-scoped `permissions:` block; `ci.yml:33` workflow default | exact (least-privilege pattern already shipped) |
| `examples/adoption_demo/package.json` exact pin (EDIT) | config | n/a | self (`@playwright/test` `^1.57.0` → `1.57.0`) | exact |
| `brandbook/src/admin-gallery-check.mjs:283` (EDIT) | utility | transform | self (`ratio < 4.5` → `ratio < WCAG_AA_NORMAL`) | exact |
| `brandbook/src/{contrast,admin-contrast,cohort-contrast}.mjs` + `admin-design-system-data.mjs` (EDIT) | utility | transform | self (`min: 4.5` literals → shared import) | exact |
| `CONTRIBUTING.md` (~:9-12), `README.md:10` (EDIT) | docs | n/a | reserved section / existing badge | exact |
| `test/brandbook/admin_design_system_validation_test.exs:148,169-173` (EDIT) | test | transform | self (assertions stay green post-refactor) | exact |

## Pattern Assignments

### `test/async_safety_guard_test.exs` (NEW — test, meta/AST transform)

**Analog:** `test/install_smoke/docs_parity_test.exs` — the established in-repo
"meta-test that reads source files and asserts over their content." The guard extends
this from string-`=~` assertions to `Code.string_to_quoted/2` + `Macro.prewalk/2` AST
traversal (the AST mechanism is new; the *shape* — `async: true` meta-test, module
attrs for paths, `setup_all` to load files, list-of-failures assertion — is the analog).

**Module header + async pattern** (`docs_parity_test.exs:3-5`):
```elixir
defmodule Rindle.InstallSmoke.DocsParityTest do
  alias Rindle.InstallSmoke.GeneratedAppHelper
  use ExUnit.Case, async: true
```
> The guard test itself MUST be `async: true` (it is read-only over the filesystem and
> uses no unsafe primitive — it would pass its own check).

**File-set + load pattern** (`docs_parity_test.exs:7-16,32-43`): module attrs hold the
target paths; `setup_all` reads them once. The guard replaces the fixed attr list with a
glob — mirror `Path.wildcard("test/**/*_test.exs")` and `File.read!/1` per file, then
`Code.string_to_quoted!/1`.

**Detection heuristic (from RESEARCH HARD-01, the AST node shapes to match in `Macro.prewalk/2`):**
```elixir
# Application.put_env / delete_env
{{:., _, [{:__aliases__, _, [:Application]}, m]}, _, _} when m in [:put_env, :delete_env]
# System.put_env / delete_env  → same shape with [:System]
# Mox global mode
{:set_mox_global, _, _}
# named/registered process — any start_* with a :name kwarg
# File mutation NOT scoped to tmp_dir/unique_integer
{{:., _, [{:__aliases__, _, [:File]}, m]}, _, _} when m in [:cd, :cd!, :write, :write!, :mkdir, :mkdir!, :rm, :rm!, :cp, :rename, :touch]
# :ets.new with :named_table/:public ; :persistent_term.put ; Sandbox.mode(_, {:shared, _})
```

**Assertion + report pattern:** collect `{file, line, primitive}` for every `async: true`
module that contains a match; `assert offenders == [], message_listing_offenders`. Mirror
the docs-parity style of building a readable failure message rather than a bare boolean.

**Allowlist escape hatch (RESEARCH HARD-01):** support a `@async_safety_allow [...]` module
attribute or `# async-safety: justified — <reason>` comment; default **fail-closed**.

**Sandbox context the guard reasons about (do NOT edit — read-only inputs):**
- `test/support/data_case.ex:22-26` — `Sandbox.start_owner!(repo, shared: not tags[:async])`.
  This is WHY a DataCase module is async-safe by construction; the guard need not flag Ecto.
- `test/test_helper.exs:1-2,9-15` — `Sandbox.mode(:manual)` for BOTH `Rindle.Repo` and
  `Rindle.Adopter.CanonicalApp.Repo`; `Oban.start_link(... testing: :manual)`. Inline-Oban
  + private-Mox are async-safe (RESEARCH KEY FINDING).

**Conversion target (D-02 ordering — guard lands+passes FIRST, then flip):** the 15 CLEAN
modules enumerated in RESEARCH HARD-01 "Per-file classification" table. Each conversion is a
one-line `async: false` → `async: true` header flip. Note `owner_erasure_batch_opts_test.exs`
double-defines modules — convert only the `async: false` one (Pitfall 1).

---

### `.github/dependabot.yml` (NEW — config, batch)

**Analog:** `/Users/jon/projects/lattice_stripe/.github/dependabot.yml` (family-shipped).
Full file (this is the pattern to mirror, adapted per RESEARCH D-04 — add grouping +
`github-actions` first or both ecosystems):
```yaml
version: 2
updates:
  - package-ecosystem: "mix"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 5
    labels:
      - "dependencies"
    commit-message:
      prefix: "chore"          # NON-feature type → release-please won't cut a release
      include: "scope"
    groups:
      dev-dependencies:
        dependency-type: "development"
        patterns:
          - "*"

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 5
    labels:
      - "dependencies"
    commit-message:
      prefix: "chore"
      include: "scope"
```
> **Critical (Pitfall 2):** keep `commit-message.prefix` a non-release Conventional type
> (`chore`/`ci`/`build`). RESEARCH recommends `ci` for the actions group + grouped
> minor/patch — reconcile with this `lattice_stripe` shape (it omits the actions group +
> uses `chore`). Either is family-consistent; pick one and be uniform. Optional `npm`
> ecosystem for `examples/adoption_demo` is Claude's discretion (D-04).

---

### `brandbook/src/contrast-constants.mjs` (NEW — utility, pure export)

**Analog:** `brandbook/src/contrast.mjs` — same directory, ESM, header-comment + `export`
style. The new module is a one-constant export:
```js
// brandbook/src/contrast-constants.mjs
// WCAG 2.x AA minimum contrast for normal-size text (< 18pt / < 14pt bold).
export const WCAG_AA_NORMAL = 4.5;
```

**Consumer-side edit — `brandbook/src/admin-gallery-check.mjs:283`** (current literal):
```js
    .filter(({ ratio }) => ratio < 4.5);
```
becomes `import { WCAG_AA_NORMAL } from "./contrast-constants.mjs";` + `ratio < WCAG_AA_NORMAL`.

**Token-pair side — `contrast.mjs:36-38`** computes `r >= p.min` where `p.min` comes from
the data tables; the `min: 4.5` literals live in `brandbook/src/admin-design-system-data.mjs`
(`CONSOLE_CONTRAST_PAIRS`) and the base/cohort data. Replace only the `min: 4.5` occurrences
with `min: WCAG_AA_NORMAL` (import the constant atop each data module). **Verify each is
AA-normal before swapping** — do NOT clobber a 3:1 large-text pair (Pitfall 4).

**Test coupling (do NOT change the asserted strings) — `admin_design_system_validation_test.exs:169-173`:**
```elixir
    admin_output = run_node("brandbook/src/admin-contrast.mjs")
    assert admin_output =~ "status chips processing"
    assert admin_output =~ "admin contrast: 58/58 pairs pass"
    base_output = run_node("brandbook/src/contrast.mjs")
    assert base_output =~ "47/47 pairs pass"
```
> This is a constant-extraction, not a threshold change — the `N/N pairs pass` counts must
> stay byte-identical. Run both `.mjs` gates after the edit to confirm.

---

### `scripts/ci/e2e_local.sh` (NEW — utility, shell wrapper)

**Analog:** `scripts/ci/adoption_demo_e2e.sh` — same lane, same demo dir, same prelude.
Mirror these idioms exactly:

**Header + strict-mode + repo_root** (`adoption_demo_e2e.sh:1-7,17`):
```bash
#!/usr/bin/env bash
# Adoption demo Playwright lane — merge-blocking CI wrapper.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
demo_dir="${repo_root}/examples/adoption_demo"
...
cd "${repo_root}"
```

**Demo bring-up sequence** (`adoption_demo_e2e.sh:31-44`) — the new script reuses this
server-side bring-up but swaps the **browser** install/run onto the pinned container:
```bash
cd "${demo_dir}"
mix deps.get --only test
mix assets.vendor
mix ecto.drop --quiet || true
mix ecto.create
mix ecto.migrate
mix rindle.migrate
PHX_SERVER= mix run priv/repo/seeds.exs

npm ci
npm run vendor:js
npx playwright install --with-deps chromium   # ← REPLACED by container run
export ADOPTION_DEMO_PRESEEDED=1
npm run e2e
```

**D-10 change:** replace the `npx playwright install` + bare `npm run e2e` with a
`docker run` against the pinned image (RESEARCH HARD-04 §`e2e_local.sh`):
```bash
docker run --rm --ipc=host \
  -v "$PWD:/work" -w /work/examples/adoption_demo \
  --add-host=host.docker.internal:host-gateway \
  mcr.microsoft.com/playwright:v1.57.0-noble \
  sh -c "npm ci && npm run e2e"
```
> Recommended networking (RESEARCH Open Q1): Phoenix server on host, browser-in-container
> against `host.docker.internal:<port>` via the demo's `ADOPTION_DEMO_BROWSER_PORT` /
> `ADOPTION_DEMO_REUSE_SERVER` knobs. The invariant is **same image both sides** (CI lane
> + this script share `v1.57.0-noble`).

**CI-side analog — the lane this replaces (`ci.yml:867-877`):**
```yaml
      - name: Install Playwright chromium
        working-directory: examples/adoption_demo
        run: npx playwright install --with-deps chromium
```
The `adoption-demo-e2e` job (`ci.yml:859-861`, `runs-on: ubuntu-22.04`, push/nightly-only,
`needs: [quality, optional-dependencies]`) moves to a job-level `container:` or calls
`scripts/ci/e2e_local.sh`. It is NOT a PR-required check → no PR-critical-path impact, no
new required check.

---

### `mix.exs` `deps/0` — add `{:mix_audit, "~> 2.1"}` (EDIT — config)

**Analog:** `mix.exs:127` — the established test-only-dep line:
```elixir
{:junit_formatter, "~> 3.4", only: :test},
```
Add alongside it (RESEARCH D-05, matching `lattice_stripe`):
```elixir
{:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
```
Wire `mix deps.audit` into the `quality` lane as an **advisory** step
(`continue-on-error: true` per house default unless user wants it gating). The `credo`/
`dialyxir`/`doctor` lines at `mix.exs:131-133` are the `only: [:dev, :test], runtime: false`
pattern for a tool dep.

### `mix.exs` `aliases/0` — add `ci:` (EDIT — config)

**Analog:** `mix.exs:284-290` — the current alias list (`precommit: ["test"]` is the
closest):
```elixir
  defp aliases do
    [
      "gsd.clean": ["cmd bash scripts/gsd_cleanup.sh"],
      precommit: ["test"],
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
```
Add the `ci:` entry mirroring the PR merge-blocking set (RESEARCH HARD-03 task list:
`deps.get --check-locked`, `deps.unlock --check-unused`, `compile --warnings-as-errors`,
`format --check-formatted`, the brandbook `cmd node ...` drift gates, `coveralls`/`test`
last). MinIO/`:minio`/`:integration` legs are **skip-with-note** (default-tag suite already
excludes them via `test_helper.exs:24-29`); document the full-parity command in CONTRIBUTING
(Pitfall 5).

---

## Shared Patterns

### Least-privilege `permissions:` (D-06)
**Source (workflow default):** `.github/workflows/ci.yml:33-34`
```yaml
permissions:
  contents: read
```
**Source (job-scoped widening — the worked example):** `.github/workflows/nightly.yml:444-445`
```yaml
    permissions:
      issues: write
```
**Apply to:** every workflow + job. RESEARCH D-06 is largely **verification**: confirm each
workflow has the `contents: read` default; add a job-scoped block ONLY where a job uses a
wider scope (e.g. `ci-observability` needs `actions: read` for `gh api --paginate`). Do NOT
cargo-cult `contents: read` onto every job (Pitfall 6) — the workflow default covers them.

### SHA-pin format (D-03)
**Apply to:** every third-party `uses:` in `ci.yml`, `nightly.yml`, `release.yml`,
`branch-protection-apply.yml`, `.github/actions/setup-elixir/action.yml`,
`.github/actions/setup-minio/action.yml`. Canonical form (one space before `#`):
```yaml
uses: owner/action@<40-hex-sha> # vX.Y.Z
```
The 11 exact SHA→version mappings are in RESEARCH HARD-02 "Resolved SHA pin map." Pin the
CURRENT major's latest SHA — do NOT bump majors (Pitfall 3). `uses: ./...` composite refs
are LOCAL paths and stay unchanged. `release-please-automerge.yml` has no third-party
`uses:` to pin (verify during planning).

### Test/dev-only tool dep (D-05)
**Source:** `mix.exs:127,131-134` (`:junit_formatter`, `:credo`, `:dialyxir`, `:doctor`,
`:excoveralls` — all `only:`-scoped, tool deps `runtime: false`).
**Apply to:** the new `{:mix_audit, "~> 2.1"}` line.

### Brandbook gate output stability (D-12)
**Source:** `test/brandbook/admin_design_system_validation_test.exs:148,169-173`
**Apply to:** every contrast-constant edit. The validation test asserts `N/N pairs pass`
strings and `data =~ "CONSOLE_CONTRAST_PAIRS"`; the constant-extraction must keep those
byte-identical.

## No Analog Found

No file in this phase lacks an analog. The only genuinely **new mechanism** is the
AST-walk inside `async_safety_guard_test.exs` (the meta-test *shape* has an analog in
`docs_parity_test.exs`; the `Code.string_to_quoted/2` + `Macro.prewalk/2` traversal is
new construction, mechanism-of-discretion per CONTEXT D-02/§Discretion). Planner: lean on
RESEARCH HARD-01 "Guard mechanism recommendation" for the AST node shapes.

## Metadata

**Analog search scope:** `test/`, `test/support/`, `test/install_smoke/`,
`test/brandbook/`, `brandbook/src/`, `scripts/ci/`, `scripts/`, `mix.exs`,
`.github/workflows/`, `.github/actions/`, `examples/adoption_demo/`, sibling
`/Users/jon/projects/lattice_stripe/.github/dependabot.yml`.
**Files scanned:** 11 read in full/targeted (data_case, test_helper, docs_parity_test,
contrast.mjs, admin-gallery-check.mjs, adoption_demo_e2e.sh, lattice_stripe dependabot,
mix.exs deps+aliases, nightly.yml permissions, ci.yml header+e2e lane, validation test,
package.json).
**Pattern extraction date:** 2026-06-22
</content>
</invoke>
