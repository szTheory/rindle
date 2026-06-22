# Phase 107: Reliability, Security & DX Hardening - Research

**Researched:** 2026-06-22
**Domain:** ExUnit async correctness · GitHub Actions supply-chain hardening · Elixir DX tooling · Playwright container reproducibility
**Confidence:** HIGH (all four tracks resolved against the live codebase + sibling-repo prior art + registry verification)

## Summary

This is an internal DX/infra phase with ZERO `lib/` change. All four tracks are resolved
against the live codebase, the sibling szTheory repos (`sigra`, `rulestead`,
`lattice_stripe` — which have already shipped the dependabot/SHA-pin/mix_audit patterns),
and registry verification (GitHub tag→SHA resolution, MCR manifest existence checks, hex
package legitimacy).

**HARD-01** is the research-flagged track. The codebase's sandbox setup is already
async-correct by construction: `Rindle.DataCase.setup_sandbox/1` checks out the Ecto
sandbox with `shared: not tags[:async]` — so flipping a module to `async: true`
*automatically* switches it to a non-shared, per-test connection owner. Of the **68**
`async: false` test modules, **15 are clean conversion candidates** (no shared-state
primitive); the remaining 53 are GENUINELY-UNSAFE (overwhelmingly `Application.put_env`).
The conservatively-marked subset is real but smaller than the raw "74 occurrences" count
suggested, because the count double-counts multi-module files and the unsafe set is large.

**HARD-02/03/04** reduce to exact-value lookups, all resolved below: the 11 action SHAs
with `# vX.Y.Z` comments, the dependabot shape (match the family's grouped/weekly form),
`{:mix_audit, "~> 2.1"}` in the `quality` lane (matching `lattice_stripe`), the
`mix ci` alias task list mirroring the 10 PR-merge-blocking lanes, the
`mcr.microsoft.com/playwright:v1.57.0-noble` container (verified to exist), and the
shared `WCAG_AA_NORMAL = 4.5` constant location.

**Primary recommendation:** Ship the four tracks as independent plan slices in this order —
(1) HARD-02 SHA-pins+dependabot+mix_audit+permissions (lowest risk, pure config), (2) HARD-01
guard-then-convert (D-02 ordering mandatory), (3) HARD-04 container+contrast-constant, (4)
HARD-03 `mix ci`+docs (depends on the others being settled). No track touches `lib/`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| ExUnit async-safety guard (HARD-01) | Test tooling (`test/support/` or `test/async_safety_guard_test.exs`) | — | A meta-test that introspects test modules; lives in `test/`, runs in the `quality` lane |
| `async: true` conversions (HARD-01) | Test modules | Ecto Sandbox (`DataCase`) | Per-module header flip; sandbox already keys isolation on `tags[:async]` |
| SHA pins (HARD-02) | CI config (`.github/workflows/*`, `.github/actions/*`) | — | Pure YAML edit; no runtime surface |
| dependabot (HARD-02) | Repo config (`.github/dependabot.yml`) | — | GitHub-platform config; keeps SHAs current |
| mix_audit (HARD-02) | Build tooling (`mix.exs` deps + `quality` lane) | — | Advisory dep-scan; test/dev-only dep |
| permissions (HARD-02) | CI config (workflow + job blocks) | — | Token-scope hardening; workflow default already `contents: read` |
| `mix ci` alias (HARD-03) | Build tooling (`mix.exs` `aliases/0`) | — | Mirrors the PR merge-blocking lane set |
| CONTRIBUTING/README (HARD-03) | Docs | — | Fills the reserved section; badge already points at the gated run |
| Playwright container (HARD-04) | CI config + `scripts/ci/` | npm (`examples/adoption_demo`) | Pinned image both sides; exact npm pin must match the tag |
| Contrast constant (HARD-04) | brandbook tooling (`brandbook/src/`) | — | One JS module exports `4.5`; both gates import it |

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HARD-01 | Async-safety static guard lands BEFORE conversion; verified-safe modules → `async: true`; `--partitions` evidence-gated (deferred D-01) | Per-file classification table below (15 clean / 53 unsafe); guard mechanism recommendation; sandbox already async-correct via `shared: not tags[:async]` |
| HARD-02 | All actions SHA-pinned; `dependabot.yml`; `{:mix_audit, "~> 2.1"}`; least-privilege `permissions:` | 11 resolved SHAs + version comments; sibling dependabot shapes; `lattice_stripe` mix_audit pattern; ci.yml already has `contents: read` default |
| HARD-03 | `mix ci` mirrors merge-blocking checks; CONTRIBUTING documents lanes+check+command; README badge → `CI Summary` | The 10 PR merge-blocking lanes enumerated; `mix ci` task list; MinIO-leg handling; CONTRIBUTING reserved section located |
| HARD-04 | Pinned Playwright container + `e2e_local.sh` + exact `@playwright/test`/font pins; one shared contrast constant | `v1.57.0-noble` verified on MCR; `1.57.0` is the only stable 1.57.x; contrast literal locations + shared-constant shape |

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01 (partitioning — DEFER, async-only this phase):** Land the async-safety static guard,
  convert verified-safe modules to `async: true`; do NOT wire `--partitions` into CI this phase.
  Evidence: Quality job runs ~140s avg / 184s p95 — not a long pole. Partition infra
  (`MIX_TEST_PARTITION` in `config/test.exs:13,31`) already exists.
- **D-02 (guard-before-conversion — MANDATORY):** The static async-safety guard lands and passes
  BEFORE any module is flipped to `async: true`.
- **D-03 (SHA-pin breadth — pin ALL, uniform):** Pin every `uses:` to a full-length immutable
  commit SHA, including first-party `actions/*`, each with a trailing `# vX.Y.Z` comment.
- **D-04 (dependabot — grouped, low-noise):** `.github/dependabot.yml` with `github-actions` + `mix`
  ecosystems; grouped (minor+patch) updates; weekly cadence. (Optional `npm` ecosystem for the demo.)
- **D-05 (mix_audit — add to deps + audit lane):** Add `{:mix_audit, "~> 2.1"}` and wire
  `mix deps.audit` into the audit lane; advisory unless user wants security findings to block.
- **D-06 (least-privilege permissions):** Every job declares an explicit least-privilege
  `permissions:` (default `contents: read`; widen only where genuinely needed).
- **D-07 (`mix ci` mirrors merge-blocking PR set):** Add a `ci` alias running the same
  merge-blocking checks the PR gate runs; document local prerequisites (e.g. MinIO).
- **D-08 (CONTRIBUTING — fill reserved section):** Fill the reserved local-command section: lanes,
  sole required check (`CI Summary`), local `mix ci` command + prerequisites.
- **D-09 (README badge — keep workflow badge, clarify it reflects `CI Summary`):** No native
  per-check badge; keep the existing workflow-run badge; do NOT build a custom endpoint.
- **D-10 (both CI + local on ONE pinned container):** Move the adoption-demo E2E lane onto a pinned
  `mcr.microsoft.com/playwright:vX.Y.Z-<distro>` container; `scripts/ci/e2e_local.sh` runs the same image.
- **D-11 (exact version + font pins):** Pin `@playwright/test` exact (drop the caret); pin the font set;
  container tag and npm version must match.
- **D-12 (contrast — ONE shared 4.5:1 AA constant):** Single shared constant = 4.5:1 exported from one
  module, consumed by BOTH the token-pair gates and the runtime polish gate.

### Claude's Discretion
- Exact async-safety guard mechanism (Credo check vs ExUnit/`Code`-AST test vs script) and unsafe-primitive inventory.
- Which conservatively-`async: false` modules are actually convertible.
- Exact SHA values + version-comment format; whether to add the optional `npm` dependabot ecosystem.
- `mix_audit` dep environment (`:dev/:test` vs `:ci`) and gating-vs-advisory placement.
- Exact `mix ci` task list ordering and MinIO-leg handling (skip-with-note vs documented prerequisite).
- Exact Playwright container tag/distro (jammy vs noble) and font package list.
- Shared-constant module location/name and export shape.

### Deferred Ideas (OUT OF SCOPE)
- `--partitions` / DB-per-partition / merged coverage (D-01).
- `npm` dependabot ecosystem for the demo (optional, planner's discretion).
- Custom per-check `CI Summary` badge endpoint (rejected, D-09).
- DEFER-01 flaky-quarantine lane; DEFER-02 larger runners; DEFER-03 property-based/nightly test expansion.
</user_constraints>

## Project Constraints (from CONTEXT.md hard invariants)

These have locked-decision authority. Research recommends nothing that contradicts them:
- Never rename `ci.yml`'s filename or `name: CI` (release-train coupling).
- `CI Summary` stays the SOLE required check; `skipped` == pass. Pinning/permissions/audit must NOT
  add or remove a required check.
- Never weaken the release full-verification gate (5-profile matrix + `release_preflight` +
  `hex.publish --dry-run`).
- `nightly.yml` never becomes a PR-required check.
- ZERO `lib/` public-API or behavior change.

> No `./CLAUDE.md` or `.claude/skills/` found in the repo — no additional project-skill directives apply. [VERIFIED: filesystem]

---

## HARD-01 — Test Async Correctness

### Current state (verified)

[VERIFIED: codebase grep] Test inventory:
- 124 `_test.exs` files; **60** `async: true` occurrences, **74** `async: false` occurrences
  across **68** distinct `async: false` test files (one file —
  `owner_erasure_batch_opts_test.exs` — contains two modules, one `async: true` and one
  `async: false`, which is why occurrence counts exceed file counts).

### The sandbox is already async-correct by construction (KEY FINDING)

[VERIFIED: `test/support/data_case.ex`] `Rindle.DataCase.setup_sandbox/1`:
```elixir
def setup_sandbox(tags) do
  repo = tags[:sandbox_repo] || Rindle.Repo
  pid = Sandbox.start_owner!(repo, shared: not tags[:async])
  on_exit(fn -> Sandbox.stop_owner(pid) end)
end
```
`shared: not tags[:async]` means: an `async: true` module gets a **non-shared** connection
owner (correct, isolated); an `async: false` module gets the **shared** mode. So flipping a
DataCase-based module to `async: true` is *automatically* sandbox-safe — no per-test rewrite
needed. This is the single most important fact for the conversion: **the only thing that makes
a module genuinely unsafe is a NON-Ecto shared-state primitive.**

[VERIFIED: `test/test_helper.exs`] Sandbox is `:manual` for BOTH `Rindle.Repo` and
`Rindle.Adopter.CanonicalApp.Repo`. Oban is started `queues: false, testing: :manual`, but
`config/test.exs:56` sets `config :oban, Oban, testing: :inline` — jobs run inline in the
calling process and respect the sandbox connection. `Oban.Testing`'s `perform_job/2` (direct
worker invocation, no queue draining) is async-safe under the sandbox. [CITED: hexdocs.pm/oban/Oban.Testing.html]

[VERIFIED: codebase] Mox usage in the clean candidates is `set_mox_from_context` + `verify_on_exit!`
(private/per-process mode) — async-safe. Only `set_mox_global` is unsafe; it appears in 3 of the
GENUINELY-UNSAFE files (the admin LiveView tests).

### Unsafe-primitive inventory (the guard's detection set)

A module marked `async: true` is UNSAFE if it (or any module it defines/uses) contains:

| Primitive | Why unsafe | Detected via |
|-----------|-----------|--------------|
| `Application.put_env` / `Application.delete_env` | Mutates global app env visible to all concurrent tests | AST/regex on `Application.put_env(` / `delete_env(` |
| `System.put_env` / `System.delete_env` | Mutates global OS env | `System.put_env(` / `delete_env(` |
| `Mox.set_mox_global` / `set_mox_global()` | Switches Mox to global mode (cross-process expectations) | `set_mox_global` |
| Named/registered process start (`name: __MODULE__`, `name: SomeAtom`) | Name collision across concurrent tests | `name:` in `start_link`/`start_supervised`/`GenServer.start` |
| Unsandboxed public ETS (`:ets.new(... :public/:named_table)`) | Shared mutable table | `:ets.new` with `:named_table`/`:public` |
| `:persistent_term.put` | Global term store | `:persistent_term.put` |
| CWD / shared-path `File` mutation (`File.cd`, writes to a fixed shared path) | Process-global CWD; shared FS path races | `File.cd`, `File.write`/`mkdir`/`rm` to a non-`tmp_dir` fixed path |
| Ecto sandbox forced to shared in an `async: true` body | Defeats per-test isolation | `Sandbox.mode(_, {:shared, ...})` or explicit `shared: true` |

**Note on `File.*`:** A `File.write`/`mkdir` into ExUnit's per-test `@tag :tmp_dir` directory
is async-safe (unique path per test). Only writes to a *fixed shared path* are unsafe. The guard
should treat `tmp_dir`-scoped writes as safe; the conservative classification below flags any
fixed-path `File` mutation as unsafe.

### Per-file classification

**CLEAN — convert to `async: true` (15 modules)** — none contain an unsafe primitive; all are
DataCase/ExUnit.Case with private-Mox + process-unique telemetry handler IDs + inline-Oban:

| File | Basis (evidence) |
|------|------------------|
| `test/rindle/admin/queries_test.exs` | DataCase + Oban.Testing; no put_env/named-proc |
| `test/rindle/attach_detach_test.exs` | DataCase + Oban.Testing; no shared state |
| `test/rindle/delivery/streaming_dispatch_test.exs` | DataCase; private Mox |
| `test/rindle/domain/migration_test.exs` | DataCase; schema/migration assertions only |
| `test/rindle/ops/variant_maintenance_test.exs` | DataCase + Oban.Testing |
| `test/rindle/owner_erasure_batch_boundary_test.exs` | DataCase; no shared state |
| `test/rindle/owner_erasure_batch_opts_test.exs` (the `async: false` module) | DataCase; pairs with an already-`async: true` sibling module in same file |
| `test/rindle/owner_erasure_batch_proof_test.exs` | DataCase + Oban.Testing |
| `test/rindle/owner_erasure_batch_test.exs` | DataCase + Oban.Testing |
| `test/rindle/owner_erasure_test.exs` | DataCase; `set_mox_from_context` (private) |
| `test/rindle/runtime_status_task_test.exs` | DataCase; Profile-def only |
| `test/rindle/telemetry/emission_test.exs` | `:telemetry_test.attach_event_handlers(self(), …)` — handler keyed to `self()`, process-isolated |
| `test/rindle/upload/resumable_telemetry_test.exs` | `handler_id = "...#{System.unique_integer}"` — unique per test |
| `test/rindle/workers/ingest_provider_webhook_test.exs` | DataCase + Oban.Testing; unique telemetry handler IDs |
| `test/rindle/workers/purge_storage_test.exs` | DataCase + Oban.Testing; `perform_job` |

**GENUINELY-UNSAFE — stay `async: false` (53 modules).** Drivers (a file may have several;
the dominant one is listed):

| Driver primitive | Files (count) |
|------------------|----------------|
| `Application.put_env`/`delete_env` | 40 files incl. all `streaming/*`, `workers/mux_*`, `ops/*` (status/checks/upload/sweep/lifecycle), `storage/gcs*`, `storage/local_tus`, `upload/tus_*` + `broker`, `config/config_test`, `capability_test`, `application_test`, `doctor_test`, `live_view_direct_upload_test`, `contracts/telemetry_contract_test`, `delivery/webhook_plug_test` |
| `System.put_env` (+ put_env) | `application_test.exs`, `workers/process_variant_test.exs` |
| `Mox.set_mox_global` | `admin/live_update_test.exs`, `admin/live/home_assets_upload_test.exs`, `admin/live/variants_runtime_actions_test.exs` |
| Named/registered process | `doctor_test.exs`, `ops/runtime_checks_test.exs`, `upload/broker_test.exs` (also gcs-tagged) |
| Fixed-path `File` mutation | `batch_owner_erasure_task_test.exs`, `convenience_api_test.exs`, `av/ffprobe_test.exs`, `processor/{ffmpeg,av,waveform}_test.exs`, `ops/metadata_backfill_test.exs`, `probe/av_probe_test.exs` |
| Gating moduletag (external service; stays serial by convention) | `brandbook/admin_design_system_validation_test.exs` (`:integration`), `upload/tus_s3_integration_test.exs` (`:minio`), `upload/lifecycle_integration_test.exs` (`:integration`), `adopter/canonical_app/lifecycle_test.exs` (`:adopter`), `install_smoke/{generated_app_smoke,hex_release_exists}_test.exs` |
| `actions_live_test.exs`, `admin/queries`-adjacent admin LiveView | `Application.put_env` for runtime config toggles |

> The planner should treat the CLEAN list as the conversion target. The guard (D-02) must land
> and pass first; the conversions then ride green through it. Each conversion is one line
> (`async: false` → `async: true`). Recommend the executor re-run the full suite after the batch
> to confirm no hidden ordering dependency (the suite is ~140s, cheap to re-run).

### Guard mechanism recommendation

**Recommended: a bespoke ExUnit meta-test using `Code` AST traversal** (not a Credo check, not a
shell script). [ASSUMED — mechanism is Claude's-discretion per CONTEXT.md]

Rationale:
- **Credo custom check** runs in the (advisory, non-merge-blocking) Credo lane — wrong severity.
  The guard must be **merge-blocking**, and the `quality` lane's `mix coveralls`/`mix test` IS
  merge-blocking. A meta-test lands the guard in the gating suite for free.
- **A shell/grep script** can't reliably resolve `use`/`import`/macro-expanded primitives and is
  brittle. AST is precise.
- **The meta-test** (e.g. `test/async_safety_guard_test.exs`, itself `async: true`) does:
  1. Glob `test/**/*_test.exs`.
  2. For each, parse with `Code.string_to_quoted/2` (or read the file and regex the module header
     for `async: true`).
  3. For each `async: true` module, walk the AST (`Macro.prewalk/2`) collecting calls matching the
     unsafe-primitive set above.
  4. Assert the offending-primitive list is empty; on failure, report `file:line` + the primitive.

  This proves: *every module that CLAIMS `async: true` uses no unsafe primitive.* It is the exact
  inverse-guard that makes the subsequent conversions safe — a future contributor who flips a module
  to async while adding `Application.put_env` gets a red gate.

- Detection heuristic for the AST walk — match these node shapes:
  `{{:., _, [{:__aliases__, _, [:Application]}, :put_env]}, _, _}` (and `:delete_env`); same for
  `System`; `{:set_mox_global, _, _}`; any `start_link`/`start_supervised`/`GenServer.start` call
  whose keyword args include `:name`; `{{:., _, [{:__aliases__,_,[:File]}, m]}, _, _}` where
  `m in [:cd, :cd!, :write, :write!, :mkdir, :mkdir!, :rm, :rm!, :cp, :rename, :touch]` *and the
  path arg is not derived from a `tmp_dir`/`unique_integer` expression*; `:ets.new` with
  `:named_table`/`:public`; `:persistent_term.put`; `Sandbox.mode(_, {:shared, _})`.

- **Allowlist escape hatch:** support a `@async_safety_allow [:application_put_env]` module
  attribute (or a `# async-safety: justified — <reason>` comment) so a module that genuinely uses
  a primitive safely (e.g. `Application.put_env` inside a `start_supervised` child that's
  process-local) can opt out with a written justification. Keep the default fail-closed.

> **Ordering (D-02):** Plan slice = (1) land guard test + allowlist plumbing (passes against the
> current 60 already-async modules), then (2) flip the 15 CLEAN modules, re-running the guard +
> full suite after each batch.

### Partitioning — DEFER (D-01) is sound

[VERIFIED: 103-BASELINE + config] Quality job ~140s avg / 184s p95 on 2–4-core runners — far under
the ≤7-min budget; not a long pole. `--partitions` adds DB-per-partition + merged-coverage machinery
for marginal payoff. The infra (`MIX_TEST_PARTITION` parameterized DB name) already exists, so a
future enable is low-lift. **Do not wire partitions this phase.** Confirmed deferral is correct.

---

## HARD-02 — Supply-Chain Posture

### Resolved SHA pin map (D-03)

[VERIFIED: GitHub `git/ref/tags` API, resolved 2026-06-22] Pin each current mutable tag to this
full-length SHA with the trailing version comment. `actions/cache/restore` and `actions/cache/save`
are subpaths of the `actions/cache` repo → same SHA.

| Current `uses:` | Pin to (SHA `# version`) |
|-----------------|--------------------------|
| `actions/checkout@v4` | `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4.3.1` |
| `actions/setup-node@v4` | `actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020 # v4.4.0` |
| `actions/cache@v4` | `actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830 # v4.3.0` |
| `actions/cache/restore@v4` | `actions/cache/restore@0057852bfaa89a56745cba8c7296529d2fc39830 # v4.3.0` |
| `actions/cache/save@v4` | `actions/cache/save@0057852bfaa89a56745cba8c7296529d2fc39830 # v4.3.0` |
| `actions/upload-artifact@v4` | `actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4.6.2` |
| `actions/github-script@v7` | `actions/github-script@f28e40c7f34bde8b3046d885e986cb6290c5673b # v7.1.0` |
| `erlef/setup-beam@v1` | `erlef/setup-beam@fc68ffb90438ef2936bbb3251622353b3dcb2f93 # v1.24.0` |
| `google-github-actions/auth@v2` | `google-github-actions/auth@c200f3691d83b41bf9bbd8638997a462592937ed # v2.1.13` |
| `google-github-actions/setup-gcloud@v2` | `google-github-actions/setup-gcloud@e427ad8a34f8676edf47cf7d7925499adf3eb74f # v2.2.1` |
| `googleapis/release-please-action@v4` | `googleapis/release-please-action@5c625bfb5d1ff62eadeeb3772007f7f66fdcf071 # v4.4.1` |

> `erlef/setup-beam@fc68ffb…` is the EXACT same SHA already pinned in `sigra` — family-consistent.
> [VERIFIED: sigra/.github/workflows/ci.yml]

**Files to edit** (every `uses:` occurrence; `uses: ./...` composite refs are LOCAL paths and stay
unchanged): `ci.yml` (24 occurrences), `nightly.yml` (8), `release.yml` (13),
`branch-protection-apply.yml` (1), `.github/actions/setup-elixir/action.yml` (3: setup-beam +
2× cache). `release-please-automerge.yml` has no third-party `uses:` to pin (verify during planning).
[VERIFIED: codebase grep]

> **Format note:** Sibling repos use a SINGLE space before `#` in some lines and two in others —
> inconsistent. Recommend the canonical GitHub/StepSecurity form: one space, then `# vX.Y.Z`:
> `uses: owner/action@<40-hex> # vX.Y.Z`. Be uniform across the repo. [CITED: docs.github.com — "pin actions to a full-length commit SHA"]
>
> **Major-version note:** sigra runs newer majors (checkout@v6, cache@v5, setup-node@v6). Rindle
> currently uses @v4/@v5/@v7 tags. **Recommend pinning the CURRENT major's latest SHA** (table above)
> — NOT bumping majors — to keep this a zero-behavior-change config PR. dependabot will propose major
> bumps afterward as reviewable PRs.

### dependabot (D-04)

[VERIFIED: sibling repos] All three siblings ship `.github/dependabot.yml`. Match the family form —
**weekly, grouped (patch [+minor] together), labeled, scoped commit prefix.** Recommended shape
(closest to `lattice_stripe`/`rulestead`):

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 5
    labels: ["dependencies", "ci"]
    commit-message:
      prefix: "ci"
      include: "scope"
    groups:
      actions:
        patterns: ["*"]
        update-types: ["minor", "patch"]
  - package-ecosystem: "mix"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 5
    labels: ["dependencies"]
    commit-message:
      prefix: "build"
      include: "scope"
    groups:
      dev-dependencies:
        patterns: ["*"]
        update-types: ["minor", "patch"]
```

> `commit-message.prefix` MUST be a Conventional-Commits type that release-please treats as a NON-feature
> bump (`ci`/`build`/`chore`) so dependabot PRs don't trigger spurious minor releases. The siblings use
> `ci` (actions) and `build`/`chore` (mix) — adopt that. [VERIFIED: rulestead/lattice_stripe dependabot.yml]
>
> **Optional `npm` ecosystem** (D-04 discretion) for `examples/adoption_demo` keeps the HARD-04 Playwright
> pin current. Coherent but beyond HARD-02's stated scope — planner's call. If added, group it and pin the
> directory to `/examples/adoption_demo`.

### mix_audit (D-05)

[VERIFIED: hex.pm/api + Package Legitimacy] `mix_audit` = `mirego/mix_audit`, latest `2.1.5`,
`~> 2.1` resolves, GitHub source present. The canonical family pattern is in `lattice_stripe`:

```elixir
# mix.exs deps/0 — alongside the existing :junit_formatter test-only-dep pattern (mix.exs:127)
{:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
```
```yaml
# in the quality lane, as an advisory step (NOT a separate required check)
- name: Audit dependencies
  run: mix deps.audit
```

[VERIFIED: lattice_stripe ci.yml:260] In `lattice_stripe`, `mix deps.audit` runs inside the
`quality` lane next to Credo/docs/hex.build — advisory, not its own gate. **Recommend the same:**
add `mix deps.audit` as a step in rindle's `quality` job. Per the DNA "merge-blocking vs advisory
EXPLICIT" rule + the house default, make it **advisory** (`continue-on-error: true`) unless the user
wants security findings to block — note this choice in the step comment.

> **Network note:** `mix deps.audit` fetches the hex advisory DB (`hex_pesto`/local mirror). It is
> fast and deterministic but DOES hit the network; acceptable in the `quality` lane which already
> runs `mix deps.get`. For `mix ci` locally it works offline against a cached advisory DB after first
> fetch. [CITED: github.com/mirego/mix_audit]

### permissions (D-06)

[VERIFIED: ci.yml] `ci.yml` ALREADY declares workflow-level `permissions: contents: read` (line 35) —
the least-privilege default is in place. Job-scoped widening exists only where needed:
- `ci-summary` (line 1199): `actions: read` (for the duration `gh api` calls) — correct.
- `ci-observability` (line ~1185): uses `gh api --paginate` (line 1212) → **needs `actions: read`**;
  verify it has a job-scoped block, add one if missing.
- All other ci.yml jobs (quality, integration, package-consumer, etc.) need only `contents: read`,
  satisfied by the workflow default — **no per-job block required** (and adding redundant ones is noise).

[VERIFIED: codebase] `nightly.yml` already done (106 D-16: `nightly-failure-issue` has `issues: write`
and nothing else; workflow default `contents: read`). `release.yml` already has 6 job-scoped
`permissions:` blocks. `branch-protection-apply.yml` + `release-please-automerge.yml` already have
workflow-level `permissions:` blocks.

> **D-06 is largely a verification/audit task, not new construction.** The deliverable: confirm every
> workflow has a workflow-level `contents: read` default, confirm each job that uses a write/elevated
> scope (issue-comment, gh api, gcs auth, release publish) has a minimal job-scoped block, and add
> `actions: read` to `ci-observability` if absent. Do NOT grant scopes a job doesn't use. `upload-artifact@v4`
> does NOT need a write scope (it uses the run token's artifact API).

---

## HARD-03 — DX Docs + Local Parity

### The merge-blocking PR lane set (what `mix ci` must mirror)

[VERIFIED: ci.yml job list + trigger conditions] The jobs that gate `CI Summary` on a PR (i.e. the
merge-blocking set) are: `quality`, `optional-dependencies`, `integration`, `contract`, `proof`,
`package-consumer` (one `image` install-smoke on PR), `adoption-demo-unit`, `cohort-demo-smoke`,
`adopter`, `brandbook-tokens`. (`package-consumer-full`, `adoption-demo-e2e`, `mux-soak`, the broad
matrix, Dialyzer → push:main/nightly only — NOT mirrored by `mix ci`.)

The actual **mix-level merge-blocking commands** (the subset `mix ci` can faithfully run locally):

| Source lane | Command(s) | Local note |
|-------------|-----------|------------|
| quality | `mix deps.get --check-locked`, `mix deps.unlock --check-unused`, `mix compile --warnings-as-errors`, `mix format --check-formatted`, `mix coveralls` (gating test suite) | runnable locally; needs Postgres |
| optional-dependencies | `MIX_ENV=test mix deps.get --no-optional-deps && mix compile --no-optional-deps --warnings-as-errors` | runnable; separate deps tree |
| integration | `mix test --only integration` / storage-adapter `--include minio` + `bash scripts/assert_av_hygiene.sh` | **needs MinIO** (the storage legs) |
| contract | `mix test --only contract` (advisory in-lane, but suite-level) | runnable |
| proof | `mix test test/install_smoke/docs_parity_test.exs` + `bash scripts/maintainer/check_docs_links.sh` + adopter docs test | runnable |
| brandbook-tokens | `node brandbook/src/tokens-build.mjs`, `admin-css-build.mjs`, `admin-contrast.mjs`, `admin-gallery-check.mjs`, `sync-admin-css.mjs` + `git diff --exit-code` | needs Node + Playwright (for gallery proof) |

### `mix ci` alias recommendation (D-07)

[VERIFIED: mix.exs:286-294] No `ci` alias today; `precommit: ["test"]` is the closest. Recommended
alias (ordering: fast static checks → compile → format → drift gates → tests last):

```elixir
ci: [
  "deps.get --check-locked",
  "deps.unlock --check-unused",
  "compile --warnings-as-errors",
  "format --check-formatted",
  "cmd node brandbook/src/tokens-build.mjs",
  "cmd node brandbook/src/admin-css-build.mjs",
  "cmd node brandbook/src/admin-contrast.mjs",
  "cmd node brandbook/src/sync-admin-css.mjs",
  "coveralls"   # or `test` — the gating unit suite
],
```

**MinIO-leg handling (Claude's discretion):** Recommend **skip-with-note** for the local `mix ci`
default — the storage/MinIO integration legs require a running MinIO and are gated by the `:minio`
tag (excluded by default in `test_helper.exs`). The base `mix ci` runs the default-tag suite (which
already excludes `:integration`/`:minio`/`:contract`/`:adopter`), giving the fast local mirror of the
unit-level gate. Document the FULL parity command separately in CONTRIBUTING:
`RINDLE_MINIO_URL=… mix test --include minio --include integration` with a one-line "requires a local
MinIO (see [memory: MinIO local test run])" prerequisite. This keeps `mix ci` fast and runnable on a
fresh clone while documenting how to reproduce the storage legs. Do NOT make `mix ci` hard-fail when
MinIO is absent.

> Note the `gallery-check` step needs Playwright installed in `examples/adoption_demo`. The base
> `mix ci` can OMIT the browser gallery proof (it's covered by `brandbook-tokens` in CI + the
> HARD-04 container locally) to keep `mix ci` Elixir-toolchain-only; document the browser proof as
> the `scripts/ci/e2e_local.sh` path. Planner's call on whether to include `admin-gallery-check.mjs`.

### CONTRIBUTING.md (D-08)

[VERIFIED: CONTRIBUTING.md:9-12] The file literally reserves this: *"a single `mix ci` equivalent and
faithful local reproduction … is being added in a follow-up (Phase 107, HARD-03); this file will gain
those local commands then."* Fill that exact placeholder with: (1) the lane split (already prose-documented
above it), (2) the **sole required check = `CI Summary`** (`skipped`==pass), (3) the local `mix ci` command
+ the MinIO/Playwright prerequisites + the full-parity command. Keep coherent with `RUNNING.md` §"CI lane
severity" and the linked `106-LANE-CLASSIFICATION.md`.

### README badge (D-09)

[VERIFIED: README.md:10, ci.yml] GitHub has no native per-check badge. The existing
`…/actions/workflows/ci.yml/badge.svg?branch=main` workflow-run badge already reflects the run whose
conclusion is gated by `CI Summary`. **Keep it; add a docs line stating it represents the `CI Summary`
gate.** Do NOT build a custom endpoint.

---

## HARD-04 — Faithful Linux-Chromium Repro

### Playwright container ↔ npm pin (D-10/D-11)

[VERIFIED: npm registry + MCR manifest checks]
- `@playwright/test` is `^1.57.0` in `examples/adoption_demo/package.json:10`. The ONLY stable 1.57.x
  release is `1.57.0` (no patch releases; `1.58–1.61` are later minors). → **Pin exact `1.57.0`** (drop the caret).
- Matching container: `mcr.microsoft.com/playwright:v1.57.0-noble` — **verified HTTP 200** on the MCR
  manifest API. `v1.57.0-jammy` and unsuffixed `v1.57.0` also exist (200).
- **Recommend `v1.57.0-noble`** (Ubuntu 24.04 LTS). Since Playwright v1.50+ the unsuffixed/default tag
  IS noble; noble is current LTS and the project targets recent toolchains. (jammy = 22.04 is the older
  fallback; choose noble for forward-consistency.) The container tag's Playwright version and the npm
  `@playwright/test` version MUST be identical — both `1.57.0`. [VERIFIED: MCR + npm]

> **Caveat:** dependabot's `npm` ecosystem (if added per D-04) will eventually bump `@playwright/test`;
> the container tag must be bumped in lockstep (same PR). Document this coupling in a comment next to the
> pin and in CONTRIBUTING.

### Fonts (D-11)

[CITED: playwright.dev/docs/docker] The official Playwright images ship a deterministic font set
preinstalled (the image's `Dockerfile` installs `fonts-liberation`, `fonts-noto-color-emoji`,
`fonts-unifont`, `fonts-tlwg-loma-otf`, `fonts-freefont-ttf`, and the WebKit/Chromium font deps).
Because BOTH CI and local use the **same image**, glyph metrics are deterministic by construction —
no extra font install is needed beyond what the container provides. The "font pin" is therefore the
**container tag itself** (it pins the font set). [ASSUMED — exact font package list is the image's
internal Dockerfile; the load-bearing guarantee is "same image both sides," which is verified.] If
the demo renders any app-specific webfont, pin it as a checked-in asset in the demo, not via system
fonts.

### `scripts/ci/e2e_local.sh` + ci.yml change (D-10)

[VERIFIED: ci.yml:1131-1144] The current `adoption-demo-e2e` job runs `npx playwright install
--with-deps chromium` on bare `ubuntu`. Move it to run inside the pinned container (a job-level
`container:` key, or `docker run` in the script). `scripts/ci/e2e_local.sh` must:
1. `docker run --rm -it -v "$PWD:/work" -w /work/examples/adoption_demo mcr.microsoft.com/playwright:v1.57.0-noble`
   (or `--ipc=host` per Playwright's Docker guidance to avoid Chromium OOM).
2. Inside: `npm ci` then `npm run e2e` (which runs `playwright test` against the demo's `webServer`).
3. The `playwright.config.js` `webServer` starts `mix phx.server` — so the container needs Elixir+Postgres
   OR the script runs the Phoenix server on the host and the browser in the container against
   `host.docker.internal`. **Recommend:** server on host, browser-in-container against the host port
   (the config already parameterizes `ADOPTION_DEMO_BROWSER_PORT` and `ADOPTION_DEMO_REUSE_SERVER`).
   Planner resolves host/container networking; the invariant is *same image both sides*.

> [VERIFIED: ci.yml] `adoption-demo-e2e` is `needs: [quality, optional-dependencies]` and nightly/push-only
> (106 D-04) — **not a PR-required check**, so the container move touches no PR-critical-path timing and
> cannot add a required check. Confirmed safe under the invariants.

### Contrast — one shared 4.5:1 constant (D-12)

[VERIFIED: codebase] The divergence:
- **Token-pair gates** (`brandbook/src/contrast.mjs:35`, `admin-contrast.mjs:62`, `cohort-contrast.mjs:253`)
  each compute `ratio(fg,bg)` and compare `r >= p.min`, where `p.min` is a per-pair field. The `min`
  values are the literal `4.5` repeated dozens of times in `brandbook/src/admin-design-system-data.mjs`
  (the `CONSOLE_CONTRAST_PAIRS` table — `min: 4.5` on lines 88–151+) and the analogous base/cohort tables.
- **Runtime polish gate** (`brandbook/src/admin-gallery-check.mjs:283`) uses a hardcoded literal:
  `.filter(({ ratio }) => ratio < 4.5)`.

**Recommended shared-constant module:**
```js
// brandbook/src/contrast-constants.mjs
// WCAG 2.x AA minimum contrast for normal-size text (< 18pt / < 14pt bold).
export const WCAG_AA_NORMAL = 4.5;
```
Then:
- `admin-gallery-check.mjs`: `import { WCAG_AA_NORMAL } from "./contrast-constants.mjs";` and replace the
  literal: `.filter(({ ratio }) => ratio < WCAG_AA_NORMAL)`.
- The pair tables in `admin-design-system-data.mjs` (and base/cohort data): replace `min: 4.5` with
  `min: WCAG_AA_NORMAL` (import the constant at the top of each data module). Pairs with a NON-4.5 `min`
  (if any exist — e.g. a 3:1 large-text pair) keep their own value; only the 4.5 literals get the shared
  import. **Verify each `min: 4.5` is AA-normal before swapping** (don't blanket-replace a 3:1 pair).

> **Test coupling:** [VERIFIED: test/brandbook/admin_design_system_validation_test.exs:169-173] the
> validation test asserts the gates' OUTPUT strings — `"admin contrast: 58/58 pairs pass"`,
> `"47/47 pairs pass"`, and `data =~ "CONSOLE_CONTRAST_PAIRS"`. The refactor must keep the SAME computed
> ratios and pass counts (it's a constant-extraction, not a threshold change), so these assertions stay
> green. Run `node brandbook/src/admin-contrast.mjs` + `contrast.mjs` after the change to confirm the
> `N/N pairs pass` strings are unchanged.

---

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `mix_audit` (`~> 2.1`) | hex.pm | mature (2.1.5 current) | widely used | github.com/mirego/mix_audit | OK | Approved (matches `lattice_stripe` family use) |
| `@playwright/test` (`1.57.0`) | npm | mature | tens of M/wk | github.com/microsoft/playwright | OK | Approved (already a demo devDep; pinning exact) |

No new packages introduced beyond pinning an existing devDep and adding one well-known Elixir tool used
by a sibling repo. No `SLOP`/`SUS` verdicts. [VERIFIED: hex.pm/api, npm registry]

> The GitHub action SHAs are not "packages" but are subject to the same supply-chain concern — all 11
> resolved from official `owner/action` repos via the GitHub tag API and cross-checked against the SHA
> already shipped in sibling `sigra` (setup-beam). [VERIFIED]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Keeping SHA pins current | A cron script that re-resolves tags | `dependabot.yml` (D-04) | Native, reviewable PRs; the whole point of dependabot |
| Per-check status badge | A custom shields.io endpoint / serverless badge | The existing workflow-run badge (D-09) | GitHub has no per-check badge; workflow badge already reflects the gated run |
| Dep vulnerability scanning | A bespoke advisory-DB fetcher | `mix_audit` (D-05) | Maintained, hex-advisory-backed, family-standard |
| Faithful browser repro | A local script approximating CI's Chromium | The SAME pinned MCR container both sides (D-10) | "Faithful" = identical bytes; a script that approximates defeats the requirement |
| Contrast threshold | Re-deriving WCAG math per gate | One exported `WCAG_AA_NORMAL = 4.5` (D-12) | Single source of truth; no drift |
| Async-safety detection | grep over test files | An AST-walking ExUnit meta-test | Resolves macro/`use` expansion; precise file:line reporting |

**Key insight:** Every track here has an established, idiomatic solution already proven in the sibling
szTheory repos. The phase is "adopt the family conventions exactly," not "invent."

## Common Pitfalls

### Pitfall 1: Flipping `async: true` on a file that double-defines modules
**What goes wrong:** `owner_erasure_batch_opts_test.exs` has two modules (one async, one not). A blind
header flip can mis-target. **How to avoid:** the guard works per-module-AST, not per-file; convert the
specific `async: false` module, leave the sibling.

### Pitfall 2: dependabot commit prefix triggering a release
**What goes wrong:** A `feat:`/`fix:`-prefixed dependabot commit makes release-please cut a version.
**How to avoid:** force `commit-message.prefix: "ci"`/`"build"` (non-release types), matching the siblings.

### Pitfall 3: Bumping action majors during the pin
**What goes wrong:** Pinning `checkout` to sigra's `@v6` SHA changes behavior (Node24 runtime, etc.) and
risks a green→red flip mid-milestone. **How to avoid:** pin the CURRENT major's latest SHA (table above);
let dependabot propose majors as separate reviewable PRs.

### Pitfall 4: Contrast refactor changing a non-4.5 pair
**What goes wrong:** Blanket-replacing every `min:` with `WCAG_AA_NORMAL` would clobber any 3:1 large-text
pair. **How to avoid:** only swap `min: 4.5` occurrences; verify the `N/N pairs pass` output is byte-identical after.

### Pitfall 5: `mix ci` hard-failing on a fresh clone (no MinIO)
**What goes wrong:** Including the `:minio`/`:integration` legs in the base alias makes `mix ci` red for
anyone without MinIO. **How to avoid:** base `mix ci` runs the default-tag suite (already excludes those
tags); document the full-parity command separately.

### Pitfall 6: Adding redundant per-job `permissions:` blocks
**What goes wrong:** Cargo-culting `permissions: contents: read` onto every job is noise (the workflow
default already does it) and obscures the jobs that genuinely need MORE. **How to avoid:** only add
job-scoped blocks where a job needs a scope beyond the `contents: read` default.

## Validation Architecture

> nyquist_validation: enabled (config has no `workflow.nyquist_validation` key → treat as on).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir) + Node assert-based gates (`brandbook/src/*.mjs`) + Playwright (demo E2E) |
| Config file | `test/test_helper.exs`, `config/test.exs`, `examples/adoption_demo/playwright.config.js` |
| Quick run command | `mix test` (default-tag suite, ~140s) |
| Full suite command | `mix test --include integration --include minio --include contract --include adopter` (needs MinIO/Postgres) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HARD-01 | async-marked modules use no unsafe primitive | unit (meta) | `mix test test/async_safety_guard_test.exs` | ❌ Wave 0 (the guard IS the new test) |
| HARD-01 | converted modules still pass | unit | `mix test` (full default suite green after conversion) | ✅ |
| HARD-02 | every `uses:` is a 40-hex SHA | static | `! grep -rE 'uses: [^@]+@v[0-9]' .github/workflows .github/actions` (lint) | ❌ Wave 0 (optional guard script) |
| HARD-02 | mix_audit runs clean | advisory | `mix deps.audit` | ✅ (after dep added) |
| HARD-03 | `mix ci` reproduces the PR verdict | smoke | `mix ci` exits 0 locally | ❌ Wave 0 (the alias is new) |
| HARD-04 | contrast gates unchanged after constant extraction | unit | `mix test test/brandbook/admin_design_system_validation_test.exs:145` + `node brandbook/src/admin-contrast.mjs` | ✅ |
| HARD-04 | E2E runs against the pinned container | e2e | `bash scripts/ci/e2e_local.sh` | ❌ Wave 0 (the script is new) |

### Sampling Rate
- **Per task commit:** `mix compile --warnings-as-errors && mix format --check-formatted && mix test` (the guard + conversions).
- **Per wave merge:** `mix ci` (once it exists) + the contrast gates.
- **Phase gate:** full default suite green + `mix deps.audit` clean + `node admin-contrast.mjs`/`contrast.mjs` pass counts unchanged before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `test/async_safety_guard_test.exs` — the AST meta-test (HARD-01, D-02 — lands FIRST)
- [ ] `mix.exs` `aliases/0` `ci:` entry (HARD-03)
- [ ] `.github/dependabot.yml` (HARD-02)
- [ ] `brandbook/src/contrast-constants.mjs` (HARD-04)
- [ ] `scripts/ci/e2e_local.sh` (HARD-04)
- [ ] (optional) a SHA-pin lint script to keep pins from regressing (HARD-02)

## Security Domain

> security_enforcement: enabled (absent in config = enabled). This phase IS a security-hardening phase.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V1 Architecture / SDLC supply chain | yes | SHA-pinned actions (D-03), dependabot (D-04), mix_audit (D-05) — pin-and-scan posture |
| V5 Input Validation | no | No runtime input surface changed (ZERO `lib/`) |
| V6 Cryptography | no | None handled in this phase |
| V14 Configuration | yes | Least-privilege `permissions:` (D-06); immutable action refs; no `pull_request_target` (out of scope) |

### Known Threat Patterns for CI/CD supply chain
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Mutable tag hijack (a tag re-pointed to malicious commit) | Tampering | Full-length SHA pins (D-03) |
| Compromised action exfiltrating secrets via broad `GITHUB_TOKEN` | Information Disclosure / Elevation | Least-privilege `permissions:` per job (D-06); `contents: read` default |
| Stale pinned action with a known CVE | Tampering | dependabot weekly bumps (D-04) keep pins current |
| Vulnerable transitive hex dep | Tampering | `mix_audit` advisory scan (D-05) |
| Untrusted fork code reading secrets | Elevation | NO `pull_request_target` (explicitly out of scope); fork-PR fail-closed posture preserved |

## Environment Availability
| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` CLI | SHA resolution (research) | ✓ | (used to resolve all 11 SHAs) | — |
| Node.js | brandbook gates / contrast / Playwright | ✓ (asdf-pinned `22.14.0`) | 22.14.0 | — |
| Docker | HARD-04 container repro (local) | needed for `e2e_local.sh` | — | document as prerequisite |
| MinIO | integration/minio test legs (local full parity) | optional | — | base `mix ci` skips `:minio` tag; documented full-parity command |
| Postgres | `mix ci` test suite | required locally | — | document as prerequisite (already implied by existing test workflow) |

**Missing dependencies with no fallback:** none block the config-only tracks (HARD-02). Docker is a
documented prerequisite for `e2e_local.sh`; absent it, the existing CI E2E lane still covers the path.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Guard mechanism = AST meta-test (vs Credo/script) | HARD-01 guard mechanism | LOW — it's explicitly Claude's-discretion; any merge-blocking mechanism that proves the invariant satisfies D-02 |
| A2 | Recommend noble over jammy for the container | HARD-04 | LOW — both tags verified to exist; jammy is a 1-line fallback if a glyph diff appears |
| A3 | Exact font package list is the container's internal set | HARD-04 fonts | LOW — the load-bearing guarantee ("same image both sides") is verified; the list is informational |
| A4 | `mix ci` should skip MinIO legs by default | HARD-03 | LOW — discretion per CONTEXT; full-parity command documented either way |

## Open Questions

1. **Server/browser networking for `e2e_local.sh`** (container browser ↔ host `mix phx.server`).
   - What we know: `playwright.config.js` already parameterizes port + `REUSE_SERVER`.
   - What's unclear: host-network vs in-container Phoenix (the container would then need Elixir+PG).
   - Recommendation: run Phoenix on host, browser-in-container against `host.docker.internal:<port>`; the planner finalizes the exact networking flag.
2. **Whether `mix deps.audit` should block or stay advisory.**
   - What we know: house default is advisory; `lattice_stripe` runs it advisory in `quality`.
   - Recommendation: advisory (`continue-on-error: true`) unless the user wants security findings to fail the gate. Note in the step.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Mutable action tags (`@v4`) | Full-length SHA pins + dependabot | industry std since ~2022 (StepSecurity/OpenSSF) | Tamper-resistant CI |
| `npx playwright install` on bare runner | Pinned `mcr.microsoft.com/playwright:vX.Y.Z` container | Playwright Docker images standard | Byte-identical browser/font env |
| Per-pair `min: 4.5` literals | One exported `WCAG_AA_NORMAL` | this phase | No drift between gates |

**Deprecated/outdated:** none relevant — all chosen tools are current.

## Sources

### Primary (HIGH confidence)
- Live codebase: `test/test_helper.exs`, `test/support/data_case.ex`, `config/test.exs`, all `test/**/*_test.exs` headers, `.github/workflows/*.yml`, `.github/actions/*/action.yml`, `mix.exs`, `CONTRIBUTING.md`, `brandbook/src/*.mjs`, `examples/adoption_demo/*`.
- Sibling repos: `sigra`, `rulestead`, `lattice_stripe` `.github/dependabot.yml` + `ci.yml` + `mix.exs` (mix_audit + permissions + SHA-pin format prior art).
- GitHub tag→SHA API (all 11 action SHAs resolved 2026-06-22).
- MCR manifest API (v1.57.0 / -noble / -jammy all HTTP 200).
- hex.pm/api (`mix_audit` 2.1.5 legitimacy); npm registry (`@playwright/test` 1.57.0 only stable 1.57.x).

### Secondary (MEDIUM confidence)
- docs.github.com — "pin actions to a full-length commit SHA"; playwright.dev/docs/docker (font set, `--ipc=host`).

### Tertiary (LOW confidence)
- None load-bearing; the AST-guard mechanism and noble-vs-jammy are discretion calls flagged in the Assumptions Log.

## Metadata

**Confidence breakdown:**
- HARD-01 classification: HIGH — every async:false file grepped for the full unsafe-primitive set; sandbox async-correctness verified in source.
- HARD-02 SHA/dependabot/audit: HIGH — SHAs resolved from the GitHub API; dependabot/mix_audit shapes copied from shipped sibling repos.
- HARD-03 lane mirror: HIGH — PR merge-blocking jobs + their mix commands read directly from ci.yml.
- HARD-04 container/contrast: HIGH — container tags verified on MCR; contrast literals located by grep; test coupling identified.

**Research date:** 2026-06-22
**Valid until:** 2026-07-22 (action SHAs/Playwright version may advance; dependabot will track them — re-resolve only if the pin PR is delayed past ~30 days).
