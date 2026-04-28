# Phase 5: CI & 1.0 Readiness - Research

**Researched:** 2026-04-26
**Domain:** Elixir library CI, ExCoveralls, telemetry, ExDoc, Hex packaging, GitHub Actions
**Confidence:** HIGH (all major claims verified via Context7 or official Hex docs; a small number of edge claims tagged ASSUMED)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Telemetry Emission Backfill**
- D-01: Phase 5 ships actual `:telemetry.execute/3` calls at the locked event family boundaries before the contract lane is authored. Emission and contract verification ship together.
- D-02: Emission sites map directly to existing modules — no new abstractions. Asset state change at `lib/rindle/domain/asset_fsm.ex`, variant state change at `lib/rindle/domain/variant_fsm.ex`, upload start/stop at `lib/rindle/upload/broker.ex`, signed delivery at `lib/rindle/delivery.ex`, cleanup runs at `lib/rindle/workers/*` and `lib/rindle/ops/upload_maintenance.ex`.
- D-03: Emission is additive only. No public API or state machine change. `profile` and `adapter` metadata fields are required; measurements stay numeric.

**Contract Lane (CI-06)**
- D-04: Contract lane is `test/rindle/contracts/` tagged `:contract`, run as `mix test --only contract`.
- D-05: Asserts exact event-name allowlist, required `profile` + `adapter` metadata keys, and that all measurements are numeric.
- D-06: No NimbleOptions schema DSL — flat assertion module.

**Adopter Lane (CI-08)**
- D-07: Canonical adopter integration in-repo at `test/adopter/canonical_app/`.
- D-08: Adopter fixture boots an adopter-owned Repo (distinct from `Rindle.Repo`) and exercises full lifecycle against MinIO + Postgres.
- D-09: Adopter lane runs as a third CI job after `quality` and `integration`.

**Release Lane (CI-09)**
- D-10: Release lane runs on `workflow_dispatch` and tag push (`v*`) only — not every PR.
- D-11: Release lane runs `mix hex.publish --dry-run`, `mix hex.build` artifact inspection, and a post-publish parity diff.
- D-12: Pre-1.0 version is `0.1.0-dev`; release lane is dry-run-only until 1.0 cutover.

**Coverage (CI-03)**
- D-13: `excoveralls` with `coveralls.json` configured to fail below 80% line coverage.
- D-14: Quality lane installs `libvips-dev` via `apt-get install -y libvips-dev` before `mix deps.get`.

**Documentation (DOC-01..08)**
- D-15: Narrative guides in `guides/` root folder: `getting_started.md`, `core_concepts.md`, `profiles.md`, `secure_delivery.md`, `background_processing.md`, `operations.md`, `troubleshooting.md`. Wired via `mix.exs docs/0 extras:` and `groups_for_extras:`.
- D-16: DOC-01 adopter snippet must match the working code path the adopter lane runs — drift is a CI failure.
- D-17: Five domain schema modules get full `@moduledoc`. `lib/rindle/repo.ex` gets `@moduledoc false`. `lib/rindle/application.ex` keeps `@moduledoc false`.
- D-18: Mix tasks already have detailed `@moduledoc` — DOC-06 is cross-linking from `guides/operations.md`.

### Claude's Discretion
- Internal module split for any new test fixtures (contract assertions module, adopter Repo module, etc.).
- Exact ExDoc `groups_for_extras:` grouping labels.
- Coverage exclusion patterns (test support, Mix tasks) — pick conventional defaults; document in `coveralls.json`.
- Whether to run the contract lane inside the existing `quality` job or as its own job.
- Whether `phx_media_library v0.6.0` API study materially changes any guide example.

### Deferred Ideas (OUT OF SCOPE)
- `phx_media_library v0.6.0` API ergonomics study.
- Cloudflare R2 presigned PUT semantics verification.
- A separate `rindle_adopter_example` external repo.
- Running the release lane on every PR.
- LiveDashboard integration (DASH-01/02).
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CI-01 | `mix format --check-formatted` gate | Existing CI has this step; confirmed exit code semantics |
| CI-02 | `mix compile --warnings-as-errors` gate | Existing CI has this step; confirmed exit semantics |
| CI-03 | Coverage threshold via excoveralls | `coveralls.json` `minimum_coverage: 80` + `mix coveralls` exit-1 on failure — verified |
| CI-04 | Credo gate | Existing CI runs `mix credo --strict`; `.credo.exs` already present with strict: true |
| CI-05 | Dialyzer gate | Existing CI has `mix dialyzer --format github` with PLT cache; already working |
| CI-06 | Contract lane for telemetry events | ExUnit `:contract` tag, `:telemetry_test.attach_event_handlers/2` pattern documented |
| CI-07 | Integration lane (existing) | Already shipping — MinIO + Postgres service containers; extend only |
| CI-08 | Adopter lane | New job; adopter-owned Repo pattern, same env vars as integration lane |
| CI-09 | Release lane | `workflow_dispatch` + `push: tags: v*` trigger; `mix hex.build --unpack` for artifact inspection |
| DOC-01 | Getting started guide | `guides/getting_started.md` wired via `extras:`; snippet verified by adopter lane |
| DOC-02 | Core concepts guide with state diagrams | Mermaid via `before_closing_head_tag:` CDN injection into ExDoc |
| DOC-03 | Profile and recipe guide | `guides/profiles.md` |
| DOC-04 | Secure delivery guide | `guides/secure_delivery.md` |
| DOC-05 | Background processing guide | `guides/background_processing.md` |
| DOC-06 | Operations guide | `guides/operations.md` — cross-link to existing Mix task `@moduledoc` blocks |
| DOC-07 | Troubleshooting guide | `guides/troubleshooting.md` |
| DOC-08 | `@moduledoc` / `@doc` audit | Five domain schema modules missing `@moduledoc`; `Rindle.Repo` needs `@moduledoc false` |
</phase_requirements>

---

## Summary

Phase 5 bundles two technically distinct but strategically unified deliveries: (1) wiring the actual `:telemetry.execute/3` calls that Phase 3 described but never shipped, and (2) building the five-lane CI structure that gates the 1.0 release. These ship together because the contract lane (CI-06) cannot assert a real telemetry surface without the emission being present.

The existing CI (`ci.yml`) already has working `quality` and `integration` jobs with Postgres and MinIO service containers, format/compile/Credo/Dialyzer steps, and PLT caching. Phase 5 extends this rather than replacing it — adding: libvips install + coveralls replacement of bare `mix test` in quality; a new `contract` job; a new `adopter` job; and a release workflow on a separate trigger.

The ExDoc and documentation work is orthogonal: seven guide files, Mermaid diagram injection via `before_closing_head_tag:`, and a `@moduledoc` backfill for the five domain schema modules that have no docs today.

**Primary recommendation:** Use `:telemetry_test.attach_event_handlers/2` (from the `:telemetry` package itself, not a third-party lib) for contract tests; use `coveralls.json` `minimum_coverage: 80` with `mix coveralls` for the threshold gate; wire Mermaid via CDN `before_closing_head_tag:` — no external plugin needed.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Telemetry emission (additive) | Library internals | — | Emission is side-effect only inside existing module functions; no tier boundary crossed |
| Contract test assertions | ExUnit test suite | CI `contract` job | In-process, no real MinIO; asserts the shape of events emitted by library code under test |
| Coverage threshold enforcement | CI quality job | `coveralls.json` config | excoveralls hooks into `mix test`; threshold is declared in repo root JSON file |
| Adopter Repo isolation | Test fixture (`test/adopter/`) | CI `adopter` job | Adopter-owned Ecto.Repo; separate from `Rindle.Repo` dev/test harness |
| Hex artifact inspection | CI release job | `mix hex.build` | Build + unpack + diff happen in a standalone workflow triggered by tag or manual dispatch |
| ExDoc guide rendering | ExDoc + CDN Mermaid script | `mix.exs docs/0` | Mermaid rendered client-side via `before_closing_head_tag:` injection; no server-side dep |
| `@moduledoc` audit | Library `lib/` source | — | Code edit in five domain schema modules + `Rindle.Repo` |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| excoveralls | ~> 0.18.5 | Coverage threshold + report | De facto standard for Elixir coverage with `minimum_coverage` CI gate; integrates with `mix test` |
| telemetry | ~> 1.2 (already in deps) | Emission + `:telemetry_test` test helpers | Already a direct dep; `:telemetry_test` module ships inside the same package |
| dialyxir | ~> 1.4 (already in deps) | Dialyzer wrapper | Already present; PLT cache strategy already wired in CI |
| ex_doc | ~> 0.40.1 | Documentation generation | Current latest; upgraded from ~> 0.34 in existing `mix.exs` to gain `groups_for_extras:` and Mermaid-ready injection hooks |
| credo | ~> 1.7 (already in deps) | Static analysis | Already present; `.credo.exs` already committed with `strict: true` |

[VERIFIED: mix hex.info excoveralls — version 0.18.5, 2026]
[VERIFIED: mix hex.info ex_doc — version 0.40.1, 2026]
[VERIFIED: mix hex.info dialyxir — version 1.4]

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| mox | ~> 1.2 (already in deps) | Mock adapters in contract tests | Contract tests need controllable adapters that emit events predictably |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `mix coveralls` (local) | `mix coveralls.github` | `.github` posts to coveralls.io service; for local threshold-only CI, plain `mix coveralls` with `minimum_coverage` is sufficient and requires no external service |
| Mermaid via `before_closing_head_tag:` | Pre-render to SVG/PNG and embed images | CDN Mermaid is simpler to maintain when diagrams change; pre-rendered images require a build step and go stale silently |

**Installation (new deps only):**

```bash
# Add to mix.exs deps:
{:excoveralls, "~> 0.18", only: [:test, :dev], runtime: false}
# ex_doc version bump from ~> 0.34 to ~> 0.40
```

---

## Architecture Patterns

### System Architecture Diagram

```
PR Push / main push
         │
         ▼
   ┌─────────────┐
   │  quality job │  format → compile-warn → coveralls (80%) → credo → dialyzer
   └──────┬──────┘
          │ needs: quality
          ▼
   ┌──────────────────────────────────────────────┐
   │  contract job  │  integration job             │  (parallel, both need quality)
   │  (in-process,  │  (MinIO + Postgres,           │
   │   no services) │   lifecycle_integration_test) │
   └──────┬─────────┴──────────────────────────────┘
          │ needs: contract + integration
          ▼
   ┌─────────────┐
   │ adopter job │  MinIO + Postgres, adopter-owned Repo, full lifecycle
   └─────────────┘

Tag push (v*) or workflow_dispatch
         │
         ▼
   ┌──────────────┐
   │ release job  │  hex.publish --dry-run → hex.build --unpack → assert paths
   └──────────────┘
```

### Recommended Project Structure

```
.
├── coveralls.json                  # NEW — excoveralls threshold + skip_files
├── guides/                         # NEW — narrative documentation
│   ├── getting_started.md
│   ├── core_concepts.md            # FSM state diagrams (Mermaid)
│   ├── profiles.md
│   ├── secure_delivery.md
│   ├── background_processing.md
│   ├── operations.md
│   └── troubleshooting.md
├── test/
│   ├── adopter/                    # NEW — adopter lane fixture
│   │   └── canonical_app/
│   │       ├── repo.ex             # adopter-owned Ecto.Repo module
│   │       ├── profile.ex          # adopter profile for lifecycle test
│   │       └── lifecycle_test.exs  # @tag :adopter tests
│   └── rindle/
│       └── contracts/
│           ├── behaviour_contract_test.exs  # existing
│           └── telemetry_contract_test.exs  # NEW — @tag :contract
├── .github/
│   └── workflows/
│       ├── ci.yml                  # EXTENDED — contract/adopter jobs + libvips + coveralls
│       └── release.yml             # NEW — workflow_dispatch + tag trigger
```

### Pattern 1: coveralls.json Threshold Gate

**What:** A JSON config file at repo root that excoveralls reads automatically.
**When to use:** Required once for CI-03; values are per-project decisions.

```json
// Source: https://github.com/parroty/excoveralls/blob/master/README.md
{
  "coverage_options": {
    "minimum_coverage": 80
  },
  "skip_files": [
    "test/support",
    "test/adopter",
    "lib/rindle/repo.ex",
    "lib/rindle/application.ex",
    "priv/repo/migrations"
  ]
}
```

**Exit code:** `mix coveralls` exits with status 1 when coverage < `minimum_coverage`. This is what fails the CI step.

**mix.exs additions required:**

```elixir
# In project/0:
test_coverage: [tool: ExCoveralls],
preferred_cli_env: [
  coveralls: :test,
  "coveralls.detail": :test,
  "coveralls.html": :test,
  "coveralls.json": :test
]
```

**CI command to use:**

```bash
mix coveralls
# NOT mix coveralls.github (that posts to coveralls.io service)
# NOT mix test (that bypasses the threshold gate)
```

### Pattern 2: Telemetry Emission (Additive)

**What:** `:telemetry.execute/3` call inserted inside existing functions, after the function's primary work, without altering return value.
**When to use:** All five emission sites (D-02).

The locked Phase 3 public contract (TEL-01..TEL-08) requires:
- Event name: list of atoms, e.g. `[:rindle, :asset, :state_change]`
- Measurements: map of atom keys → numeric values
- Metadata: map including at minimum `profile:` and `adapter:` atom keys

Use `:telemetry.span/3` for operations with a measurable duration (upload start/stop). Use `:telemetry.execute/3` for point-in-time events (state change, delivery signed, cleanup run). The BEAM telemetry convention is: span for anything with a meaningful start/stop wall clock; execute for notifications.

```elixir
# Source: https://hexdocs.pm/telemetry/telemetry.html
# Point-in-time event (state change, delivery):
:telemetry.execute(
  [:rindle, :asset, :state_change],
  %{system_time: System.system_time()},
  %{profile: profile_name, adapter: adapter_module, from: current_state, to: target_state}
)

# Duration span (upload start/stop) — emits :start, :stop, :exception automatically:
:telemetry.span([:rindle, :upload], %{profile: profile_name, adapter: adapter_module}, fn ->
  result = do_the_upload(...)
  {result, %{}}
end)
```

**Additive insertion pattern for AssetFSM.transition/3:**

```elixir
def transition(current_state, target_state, context \\ %{}) do
  if target_state in Map.get(@allowed_transitions, current_state, []) do
    # Existing return value unchanged:
    :ok
    |> tap(fn _ ->
      :telemetry.execute(
        [:rindle, :asset, :state_change],
        %{system_time: System.system_time()},
        %{
          profile: Map.get(context, :profile, :unknown),
          adapter: Map.get(context, :adapter, :unknown),
          from: current_state,
          to: target_state
        }
      )
    end)
  else
    log_transition_failure(current_state, target_state, context)
    {:error, {:invalid_transition, current_state, target_state}}
  end
end
```

Note: `tap/2` returns its first argument unchanged — safe for additive insertion without altering the `:ok` return. Emission only fires on successful transitions (correct: failed transitions are not lifecycle events).

### Pattern 3: Telemetry Contract Test

**What:** ExUnit test tagged `:contract` that attaches handlers to all public event names, triggers each emission site via the smallest possible in-process call, and asserts shape.
**When to use:** CI-06; runs in `contract` lane, no MinIO required.

```elixir
# Source: https://hexdocs.pm/telemetry/telemetry_test.html
defmodule Rindle.Contracts.TelemetryContractTest do
  use ExUnit.Case, async: false
  @moduletag :contract

  @public_events [
    [:rindle, :upload, :start],
    [:rindle, :upload, :stop],
    [:rindle, :asset, :state_change],
    [:rindle, :variant, :state_change],
    [:rindle, :delivery, :signed],
    [:rindle, :cleanup, :run]
  ]

  setup do
    ref = :telemetry_test.attach_event_handlers(self(), @public_events)
    on_exit(fn -> :telemetry.detach(ref) end)
    {:ok, ref: ref}
  end

  test "event names match the public allowlist exactly" do
    # trigger each emission site (in-process, mocked adapters)
    # assert_received {event_name, ^ref, measurements, metadata}
    # ...
    for event <- @public_events do
      assert_received {^event, _ref, measurements, metadata}
      assert is_number(measurements[hd(Map.keys(measurements))])
      assert Map.has_key?(metadata, :profile)
      assert Map.has_key?(metadata, :adapter)
    end
  end
end
```

**Race-free assertion pattern:** Use `assert_received` (synchronous, no timeout) after triggering emission synchronously in-process. If the emission is async (inside an Oban job), use `assert_receive` with a short timeout. Since contract tests trigger the FSM/delivery directly — not through Oban — `assert_received` is appropriate.

**Detach in `on_exit`:** Critical. If the test process exits without detaching, the handler remains until the name collides on the next test run. `:telemetry_test.attach_event_handlers/2` returns a ref; pass that ref to `:telemetry.detach(ref)` in `on_exit`.

**Handler auto-detach:** If a handler raises, telemetry auto-detaches it. Tests that trigger emission but never attach a handler will not raise — events silently go unhandled.

### Pattern 4: Adopter Repo Isolation

**What:** A separate `Ecto.Repo` module owned by the fixture, not by Rindle, that starts its own Postgres connection pool.
**When to use:** CI-08 adopter lane.

```elixir
# test/adopter/canonical_app/repo.ex
defmodule Rindle.Adopter.CanonicalApp.Repo do
  use Ecto.Repo,
    otp_app: :rindle,  # reuse existing OTP app; config key distinguishes pools
    adapter: Ecto.Adapters.Postgres
end
```

The adopter Repo reads from a distinct config key. In `config/test.exs` (or a test helper), configure:

```elixir
config :rindle, Rindle.Adopter.CanonicalApp.Repo,
  database: "rindle_adopter_test",
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  hostname: System.get_env("PGHOST", "localhost"),
  pool: Ecto.Adapters.SQL.Sandbox
```

The adopter test starts the Repo via `ExUnit.start_supervised!` or a test helper. It uses the same Postgres service container already present in CI. The adopter Repo runs migrations from `priv/repo/migrations/` (same migrations — adopter just owns the connection pool, not a separate DB schema).

**`Rindle.Repo` references in `lib/rindle.ex` (confirmed from code read):**
- Line 91: `Rindle.Repo.get!(Rindle.Domain.MediaAsset, ...)` inside `attach/4`
- Line 101: `Rindle.Repo.transaction()` inside `attach/4`
- Line 123: `Rindle.Repo.get!(Rindle.Domain.MediaAsset, ...)` inside `detach/3`
- Line 130: `Rindle.Repo.transaction()` inside `detach/3`
- Line 211: `Rindle.Repo.transaction()` inside `upload/3`

These are hard-coded to `Rindle.Repo` — not config-driven. Per D-09, the adopter lane will surface this leak. The planner must decide: introduce `config :rindle, :repo` resolution, or document as a closed gap where adopters call `Rindle.attach/4` and Rindle internally uses its own harness Repo (which is not adopter-repo-first in production use).

**Recommendation for planner:** The adopter lane test should call `Rindle.attach/4` etc. through `Rindle.Repo` running against the adopter's Postgres; since both the adopter Repo and `Rindle.Repo` connect to the same test DB with Ecto SQL Sandbox, the lane works — but it is calling `Rindle.Repo`, not the adopter's repo. This is the exact "leak" D-09 refers to. Surface it explicitly in the adopter test as a `TODO` comment pending a config-driven resolution.

### Pattern 5: ExDoc Guides Wiring

**What:** `extras:` and `groups_for_extras:` in `mix.exs docs/0` to add navigation.
**When to use:** DOC-01..07.

```elixir
# Source: https://hexdocs.pm/ex_doc/v0.38.4/ex_doc
defp docs do
  [
    main: "Rindle",
    source_url: @source_url,
    extras: [
      "README.md",
      "guides/getting_started.md",
      "guides/core_concepts.md",
      "guides/profiles.md",
      "guides/secure_delivery.md",
      "guides/background_processing.md",
      "guides/operations.md",
      "guides/troubleshooting.md"
    ],
    groups_for_extras: [
      "Guides": ~r/guides\/.*/
    ],
    before_closing_head_tag: &before_closing_head_tag/1
  ]
end

defp before_closing_head_tag(:html) do
  # Source: https://hexdocs.pm/ex_doc/v0.38.4/ex_doc — Mermaid rendering pattern
  """
  <script defer src="https://cdn.jsdelivr.net/npm/mermaid@10.2.3/dist/mermaid.min.js"></script>
  <script>
    let initialized = false;
    window.addEventListener("exdoc:loaded", () => {
      if (!initialized) {
        mermaid.initialize({
          startOnLoad: false,
          theme: document.body.className.includes("dark") ? "dark" : "default"
        });
        initialized = true;
      }
      let id = 0;
      for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
        const preEl = codeEl.parentElement;
        const graphDefinition = codeEl.textContent;
        const graphEl = document.createElement("div");
        const graphId = "mermaid-graph-" + id++;
        mermaid.render(graphId, graphDefinition).then(({svg, bindFunctions}) => {
          graphEl.innerHTML = svg;
          bindFunctions?.(graphEl);
          preEl.insertAdjacentElement("afterend", graphEl);
          preEl.remove();
        });
      }
    });
  </script>
  """
end

defp before_closing_head_tag(:epub), do: ""
```

**`extras:` does NOT accept a glob.** Each file must be listed explicitly. [VERIFIED: Context7 / hexdocs.pm/ex_doc]

**To make `getting_started.md` the featured "main" extra:** In ExDoc, `main:` sets the landing module/page. For a guide to be the landing page, set `main: "getting_started"` (the guide title, lowercase, matching the file stem). If keeping `main: "Rindle"` (the module), the getting started guide still appears first in the Guides group by listing it first in `extras:`.

### Pattern 6: Release Lane (GitHub Actions)

**What:** A separate workflow file triggered by `workflow_dispatch` and version tag push.
**When to use:** CI-09.

```yaml
# .github/workflows/release.yml
name: Release

on:
  workflow_dispatch:
  push:
    tags:
      - "v*"

jobs:
  release:
    name: Release Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: "1.17"
          otp-version: "27"
      - run: mix deps.get
      - name: Dry-run publish
        run: mix hex.publish --dry-run
      - name: Build and inspect artifact
        run: |
          mix hex.build --unpack
          # Assert required paths present
          ls rindle-*/lib/rindle.ex
          ls rindle-*/mix.exs
          ls rindle-*/README.md
          # Assert prohibited paths absent
          ! test -e rindle-*/_build
          ! test -e rindle-*/.planning
          ! test -e rindle-*/priv/plts
```

**`mix hex.publish --dry-run`:** "Builds package and performs local checks without publishing." [VERIFIED: hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html]. Does not require authentication for `--dry-run`. [ASSUMED: based on the doc description "performs local checks" — no auth requirement documented, but not explicitly confirmed for all Hex CLI versions.]

**`0.1.0-dev` pre-release version:** The `-dev` suffix is valid semver pre-release format. Hex.pm accepts it. [VERIFIED: Hex publish docs — "all Hex packages are required to follow semantic versioning"; pre-release identifiers after `-` are valid semver]. `mix hex.publish --dry-run` should accept it without auth.

**`mix hex.build` output:** Produces `<app>-<version>.tar` (e.g., `rindle-0.1.0-dev.tar`) in the current directory. `--unpack` additionally unpacks to a directory `<app>-<version>/` for inspection. [VERIFIED: hexdocs.pm/hex/Mix.Tasks.Hex.Build.html]

**`package: [files: ...]` in `mix.exs`:** Current `mix.exs` package block has only `licenses:` and `links:`. Phase 5 must add an explicit `files:` allowlist per D-11:

```elixir
defp package do
  [
    licenses: ["MIT"],
    links: %{"GitHub" => @source_url},
    files: ~w(lib priv/repo/migrations mix.exs README.md LICENSE)
  ]
end
```

This prevents `.planning/`, `priv/plts/`, `test/`, and `_build/` from being included in the published tarball.

### Pattern 7: libvips in CI

**What:** `apt-get install -y libvips-dev` step before `mix deps.get`.
**Why:** By default, `vix` (the NIF underlying the `:image` dep) uses **precompiled NIF + bundled libvips**. Installing `libvips-dev` is NOT required for basic operation but IS required if `VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS` is set.

**Key finding (VERIFIED: hexdocs.pm/image/readme.html):** The `:image` package defaults to precompiled NIFs — libvips is bundled. `apt-get install libvips-dev` is not required for the default mode. It is only needed for extended format support (HEIF, JPEG XL) or if the adopter explicitly sets `VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS`.

**Implication for D-14:** The `apt-get install -y libvips-dev` step in D-14 is a precaution, not a hard requirement for the CI green path. However, installing it does not hurt (it ensures extended format coverage paths in `lib/rindle/processor/image.ex` can be exercised). The planner should include it as documented in D-14 but annotate that it is not strictly required for the default precompiled mode.

### Anti-Patterns to Avoid

- **Using `mix coveralls.github` instead of `mix coveralls`:** `.github` posts to coveralls.io (external service, requires token). For a local threshold gate, `mix coveralls` with `minimum_coverage` in `coveralls.json` is sufficient and has no external dependency.
- **Triggering emission inside DB transactions:** `Rindle.Repo.transaction()` in `attach/4` and `detach/3` runs multiple Ecto.Multi steps. Do not call `:telemetry.execute/3` inside a Multi step — it would emit even if the transaction rolls back. Emit AFTER `Rindle.Repo.transaction()` returns `{:ok, ...}`.
- **Using the same handler ID across async tests:** `:telemetry.attach_many/4` requires a unique handler ID. Use `:telemetry_test.attach_event_handlers/2` which generates a unique ref automatically.
- **Listing `test/support` in `elixirc_paths` and not skipping it in coveralls.json:** `test/support` is not tested but is compiled for `:test` env; its lines inflate the denominator, reducing reported coverage. Always add it to `skip_files`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Coverage threshold enforcement | Custom `mix test` wrapper that parses output | `excoveralls` + `coveralls.json` `minimum_coverage` | excoveralls hooks into `:cover` at the correct level; parsing output text is fragile and breaks on format changes |
| Telemetry test helpers | Custom `:telemetry.attach_many/4` boilerplate in every test | `:telemetry_test.attach_event_handlers/2` | Ships inside the `:telemetry` package already in deps; generates unique refs; returns `{event, ref, measurements, metadata}` messages compatible with `assert_received` |
| Mermaid diagram rendering | Pre-rendered SVG/PNG images committed to repo | ExDoc `before_closing_head_tag:` + Mermaid CDN | Diagrams update when Markdown changes; no build-step or image management required |
| Hex file exclusion | `.hexignore` | `package: [files: ~w(...)]` in `mix.exs` | `files:` is the Hex standard; `.hexignore` is an older pattern and `files:` takes precedence |

**Key insight:** All four of these have library-provided solutions that are already on the dependency path or trivially addable — building custom versions would introduce fragile, untested glue code for solved problems.

---

## Common Pitfalls

### Pitfall 1: Emitting Telemetry Inside a Transaction

**What goes wrong:** Telemetry event fires, but the DB transaction rolls back. Subscribers see an event for a lifecycle transition that never actually happened.
**Why it happens:** `Rindle.Repo.transaction()` / `Ecto.Multi` runs the `:telemetry.execute/3` call as part of the transaction body.
**How to avoid:** Emit AFTER the transaction result is matched. Use `tap/2` or a `with` clause that only emits on `{:ok, ...}`.
**Warning signs:** Contract test sees duplicate events or events without corresponding DB state.

### Pitfall 2: Handler ID Collision in Async Tests

**What goes wrong:** `** (ArgumentError) handler with ID "my_handler" is already registered` — second test fails before it runs.
**Why it happens:** `async: true` tests in the same suite attach the same handler ID concurrently.
**How to avoid:** Use `:telemetry_test.attach_event_handlers/2` (auto-generates unique ref) or include `self()` in the handler ID.
**Warning signs:** Flaky contract test failures when running `mix test` with `--max-cases 4`.

### Pitfall 3: `mix coveralls` Threshold Not Triggering

**What goes wrong:** CI passes even though coverage is below 80%.
**Why it happens:** `mix.exs` is missing `test_coverage: [tool: ExCoveralls]` — bare `mix test` runs and bypasses the threshold check.
**How to avoid:** Replace `mix test` with `mix coveralls` in the CI step AND add `test_coverage: [tool: ExCoveralls]` to `project/0`.
**Warning signs:** CI log shows "Running tests..." without any ExCoveralls coverage table output.

### Pitfall 4: Domain Schema Modules Trigger Credo ModuleDoc Warning

**What goes wrong:** `mix credo --strict` fails with `Credo.Check.Readability.ModuleDoc` on the five domain schema modules after they are touched.
**Why it happens:** The five domain schema modules currently have no `@moduledoc` — Credo flags them.
**How to avoid:** DOC-08 adds full `@moduledoc` to all five; do this before or alongside any other changes to those modules. `Rindle.Repo` gets `@moduledoc false`.
**Warning signs:** `credo --strict` passes today only because those modules are not yet in the Credo check scope (or are being tolerated by a suppressed check).

### Pitfall 5: `mix hex.publish --dry-run` Requires Hex Auth on Some Versions

**What goes wrong:** Release CI step fails with "No authenticated user found" error.
**Why it happens:** Some versions of the Hex CLI require auth even for `--dry-run`.
**How to avoid:** In CI, either (a) mock the auth check by setting `HEX_API_KEY` to a dummy value in a release dry-run job that won't actually publish, or (b) use `mix hex.build` (no auth required) for artifact inspection and skip `hex.publish --dry-run` until 1.0. [ASSUMED: not explicitly confirmed from Hex docs which path requires auth for dry-run; treat as a risk to verify during plan execution.]
**Warning signs:** CI log shows "** (Mix) No authenticated user found" from a `mix hex.publish --dry-run` step.

### Pitfall 6: `extras:` Glob Not Supported in ExDoc

**What goes wrong:** `extras: ["guides/*.md"]` silently produces an empty guide list — no guides appear in docs.
**Why it happens:** ExDoc `extras:` does not accept file globs. Each file must be listed explicitly. [VERIFIED: Context7 ExDoc docs]
**How to avoid:** List each `guides/*.md` file by explicit path.
**Warning signs:** `mix docs` succeeds but navigation sidebar has no Guides section.

---

## Code Examples

### excoveralls Full mix.exs Configuration

```elixir
# Source: https://hexdocs.pm/excoveralls/readme.html
def project do
  [
    # ... existing keys ...
    test_coverage: [tool: ExCoveralls],
    preferred_cli_env: [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.html": :test,
      "coveralls.json": :test
    ]
  ]
end

defp deps do
  [
    # ... existing deps ...
    {:excoveralls, "~> 0.18", only: [:test, :dev], runtime: false}
  ]
end
```

### coveralls.json

```json
{
  "coverage_options": {
    "minimum_coverage": 80
  },
  "skip_files": [
    "test/support",
    "test/adopter",
    "lib/rindle/repo.ex",
    "lib/rindle/application.ex",
    "priv/repo/migrations"
  ]
}
```

### `:telemetry_test` Attach Pattern

```elixir
# Source: https://hexdocs.pm/telemetry/telemetry_test.html
setup do
  ref = :telemetry_test.attach_event_handlers(self(), [
    [:rindle, :asset, :state_change],
    [:rindle, :upload, :start],
    [:rindle, :upload, :stop]
  ])
  on_exit(fn -> :telemetry.detach(ref) end)
  {:ok, ref: ref}
end

test "asset state change emits telemetry", %{ref: ref} do
  AssetFSM.transition("staged", "validating", %{profile: "MyProfile", adapter: MyAdapter})
  assert_received {[:rindle, :asset, :state_change], ^ref, measurements, metadata}
  assert is_integer(measurements.system_time)
  assert metadata.profile == "MyProfile"
  assert metadata.adapter == MyAdapter
end
```

### CI Quality Job Extension (excerpt)

```yaml
# Source: existing ci.yml — extend steps
- name: Install libvips
  run: sudo apt-get install -y libvips-dev

- name: Install dependencies
  run: mix deps.get

- name: Run tests with coverage
  run: mix coveralls
  # Replaces: mix test
  # Exits 1 if coverage < minimum_coverage in coveralls.json
```

### GitHub Actions Release Trigger

```yaml
# Source: docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions
on:
  workflow_dispatch:
  push:
    tags:
      - "v*"
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `mix coveralls.travis` / `.circle` for CI | `mix coveralls` + `minimum_coverage` in `coveralls.json` — no external service required | excoveralls 0.10+ | CI coverage gate works without a coveralls.io account |
| Commit Mermaid SVGs to repo | `before_closing_head_tag:` CDN Mermaid injection | ExDoc 0.29+ | Diagrams stay in sync with docs; no build step |
| Manual telemetry `attach/4` with atom handler IDs | `:telemetry_test.attach_event_handlers/2` | telemetry 1.0+ | Returns unique ref; avoids handler ID collisions in test suites |
| `files:` omitted (Hex includes everything) | Explicit `files: ~w(...)` allowlist in `mix.exs package/0` | Always best practice | Prevents `.planning/`, `priv/plts/`, secrets from shipping in published tarballs |

**Deprecated/outdated:**
- `mix coveralls.github`: Still works but posts to coveralls.io service; not needed for a local threshold-only gate.
- `Application.get_env(:ex_doc, ...)` for script injection: Replaced by `before_closing_head_tag:` function option in ExDoc >= 0.24.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `mix hex.publish --dry-run` does not require Hex authentication | Common Pitfalls (Pitfall 5) | Release CI step fails until auth mock or alternative approach (use `mix hex.build` only) is used |
| A2 | libvips-dev install is not required for the `:image` dep in default precompiled mode | Pattern 7 / Common Stack | If wrong, Dialyzer or `mix compile` fails in CI without libvips; easy to fix by including the apt step per D-14 |
| A3 | The adopter-owned Repo can share the same test DB as `Rindle.Repo` using Ecto SQL Sandbox | Adopter Pattern | If wrong, adopter lane needs a separate DB, requiring extra Postgres service config in CI |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed.
(Table is not empty — three assumptions above require plan-time validation.)

---

## Open Questions

1. **`Rindle.Repo` hard-coded in `lib/rindle.ex` — config-driven resolution or documented constraint?**
   - What we know: Lines 91, 101, 123, 130, 211 of `lib/rindle.ex` call `Rindle.Repo` directly (confirmed by code read).
   - What's unclear: Whether Phase 5 should introduce `config :rindle, :repo, Rindle.Repo` resolution (making the adopter-repo-first principle real in the runtime), or document this as a v1.1 concern.
   - Recommendation: The adopter lane should surface this with an explicit TODO comment. Planner should note as a fast-follow rather than a Phase 5 blocker — the in-repo adopter test can use the same Sandbox-wrapped Rindle.Repo without runtime divergence.

2. **`mix credo --strict` and new `@moduledoc` additions**
   - What we know: `.credo.exs` includes `Credo.Check.Readability.ModuleDoc` and `strict: true` is enabled.
   - What's unclear: Whether Credo is currently passing despite the five domain schema modules having no `@moduledoc`. It may be that the missing-moduledoc check is not currently being triggered (modules have no docs but Credo passes). Phase 5 adds `@moduledoc` which should make Credo happier, not sadder — but if a new module is created without docs during the phase, Credo will catch it.
   - Recommendation: Add `@moduledoc` to all five domain schema modules as the first task in Wave 1.

3. **Whether contract lane runs inside the existing `quality` job or as its own job**
   - What we know: Discretion area per CONTEXT.md.
   - Trade-off: Separate job enables parallelism and keeps quality job runtime bounded; combined job simplifies workflow YAML and shares the same Elixir boot cost.
   - Recommendation: Separate `contract` job that `needs: quality` and runs in parallel with `integration`. Contract tests are fast (in-process, no services) and parallel execution saves wall-clock time on PRs.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL | quality / integration / adopter lanes | CI service container | 16-alpine (already in ci.yml) | — |
| MinIO | integration / adopter lanes | CI docker run step (already in ci.yml) | latest minio/minio | — |
| Docker | MinIO start step | CI ubuntu-latest runner | Included on ubuntu-latest | — |
| libvips-dev | image dep (optional extended modes) | Not pre-installed on ubuntu-latest | — | Default precompiled mode works without it |
| Hex CLI | Release lane (`mix hex.publish`) | Included with Elixir setup | bundled with elixir | — |

---

## Validation Architecture

> `workflow.nyquist_validation` is not set to false in `.planning/config.json` — section included.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in, Elixir 1.15+) |
| Config file | `test/test_helper.exs` (existing) |
| Quick run command | `mix test --only contract` |
| Full suite command | `mix coveralls` (replaces `mix test` in quality lane) |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CI-01 | `mix format --check-formatted` exits non-zero on violation | CI gate (no unit test) | `mix format --check-formatted` | N/A — CI step |
| CI-02 | `mix compile --warnings-as-errors` exits non-zero on warning | CI gate | `mix compile --warnings-as-errors` | N/A — CI step |
| CI-03 | Coverage >= 80% | Coverage gate | `mix coveralls` | ❌ Wave 0: `coveralls.json` + `mix.exs` changes needed |
| CI-04 | Credo passes strict | CI gate | `mix credo --strict` | N/A — `.credo.exs` exists |
| CI-05 | Dialyzer passes | CI gate | `mix dialyzer --format github` | N/A — already wired |
| CI-06 | Telemetry events match allowlist + metadata shape | contract unit | `mix test --only contract` | ❌ Wave 0: `test/rindle/contracts/telemetry_contract_test.exs` |
| CI-07 | Integration lifecycle passes | integration | `mix test --include integration` | ✅ `test/rindle/upload/lifecycle_integration_test.exs` |
| CI-08 | Adopter full lifecycle passes | adopter integration | `mix test --only adopter` | ❌ Wave 0: `test/adopter/canonical_app/lifecycle_test.exs` |
| CI-09 | Hex artifact inspection passes dry-run | CI gate | `mix hex.build --unpack && ...` | ❌ Wave 0: `release.yml` workflow |
| DOC-01 | Getting started guide matches adopter lane code path | adopter integration + doc review | `mix test --only adopter` (snippet parity) | ❌ Wave 0: `guides/getting_started.md` |
| DOC-02 | Core concepts guide with state diagrams | manual review + `mix docs` | `mix docs` | ❌ Wave 0: `guides/core_concepts.md` |
| DOC-03..07 | Narrative guides exist and wire into ExDoc | `mix docs` build succeeds | `mix docs` | ❌ Wave 0: 5 guide files |
| DOC-08 | All public modules have `@moduledoc` | Credo ModuleDoc check | `mix credo --strict` | ❌ Wave 0: 5 domain modules need `@moduledoc` |

### Sampling Rate

- **Per task commit:** `mix test --only contract` (fast, in-process)
- **Per wave merge:** `mix coveralls` (full suite with threshold)
- **Phase gate:** Full suite green + `mix credo --strict` + `mix dialyzer --format github` before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `coveralls.json` — covers CI-03 threshold gate
- [ ] `test/rindle/contracts/telemetry_contract_test.exs` — covers CI-06
- [ ] `test/adopter/canonical_app/repo.ex` — covers CI-08 adopter Repo
- [ ] `test/adopter/canonical_app/profile.ex` — adopter profile fixture
- [ ] `test/adopter/canonical_app/lifecycle_test.exs` — covers CI-08 end-to-end
- [ ] `guides/getting_started.md` — covers DOC-01
- [ ] `guides/core_concepts.md` — covers DOC-02 (Mermaid diagrams)
- [ ] `guides/profiles.md` — covers DOC-03
- [ ] `guides/secure_delivery.md` — covers DOC-04
- [ ] `guides/background_processing.md` — covers DOC-05
- [ ] `guides/operations.md` — covers DOC-06
- [ ] `guides/troubleshooting.md` — covers DOC-07
- [ ] `.github/workflows/release.yml` — covers CI-09
- [ ] `mix.exs` — `test_coverage:`, `preferred_cli_env:`, `docs/0` extensions, `package: [files:]`
- [ ] `lib/rindle/domain/media_asset.ex` et al. (5 files) — `@moduledoc` additions (DOC-08)
- [ ] `lib/rindle/repo.ex` — `@moduledoc false`
- [ ] Telemetry emission in `asset_fsm.ex`, `variant_fsm.ex`, `broker.ex`, `delivery.ex`, `workers/cleanup_orphans.ex`, `ops/upload_maintenance.ex` — covers D-01/D-02/D-03 + enables CI-06

---

## Security Domain

> `security_enforcement` not explicitly false in config — section included.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No — no auth in telemetry/docs/CI layer | — |
| V3 Session Management | No | — |
| V4 Access Control | Partial — Hex publish token must be scoped to org | Hex API key as GitHub Actions secret, scoped to release workflow only |
| V5 Input Validation | Partial — adopter test module name resolution | `String.to_existing_atom/1` already used (pattern from `broker.ex`); don't use `String.to_atom/1` in new fixture code |
| V6 Cryptography | No — no new crypto | — |

### Known Threat Patterns for this Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Hex API key exposed in PR CI logs | Information Disclosure | Release workflow uses `workflow_dispatch` + tag-push ONLY; Hex secret never accessed on fork PRs |
| Atom table exhaustion in adopter test | Denial of Service | Use `String.to_existing_atom/1` not `String.to_atom/1` in profile/adapter resolution (existing pattern in broker.ex) |

---

## Sources

### Primary (HIGH confidence)

- `/parroty/excoveralls` (Context7) — `minimum_coverage`, `skip_files`, `coverage_options` schema, `mix coveralls` exit code behavior
- `https://hexdocs.pm/ex_doc/v0.38.4/ex_doc` (Context7) — `extras:`, `groups_for_extras:`, `before_closing_head_tag:`, Mermaid CDN injection pattern
- `https://hexdocs.pm/telemetry/telemetry_test.html` — `:telemetry_test.attach_event_handlers/2` API and ExUnit pattern
- `https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html` — `--dry-run` semantics
- `https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html` — `mix hex.build --unpack` output location
- `https://hexdocs.pm/image/readme.html` — libvips precompiled vs platform-provided mode

### Secondary (MEDIUM confidence)

- `github.com/parroty/excoveralls README` — confirmed `minimum_coverage` field path (`coverage_options.minimum_coverage` vs top-level), `skip_files` schema
- `docs.github.com/actions` — `workflow_dispatch` + `push: tags: v*` trigger syntax

### Tertiary (LOW confidence)

- `mix hex.publish --dry-run` auth requirement — not explicitly documented as auth-free; flagged as Assumption A1 above

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all library versions verified via `mix hex.info`
- Architecture (CI lanes): HIGH — based on existing `ci.yml` which is the extension substrate
- Telemetry patterns: HIGH — verified via Context7 telemetry docs + telemetry_test module
- ExDoc configuration: HIGH — verified via Context7 ExDoc docs
- libvips requirement: MEDIUM — precompiled default confirmed; extended-mode details nuanced
- Hex publish auth: LOW — Assumption A1; needs plan-time verification

**Research date:** 2026-04-26
**Valid until:** 2026-05-26 (30 days for stable toolchain; excoveralls/ex_doc change infrequently)

---

## RESEARCH COMPLETE

**Phase:** 05 - CI & 1.0 Readiness
**Confidence:** HIGH (3 low-confidence assumptions documented; core stack fully verified)

### Key Findings

- **excoveralls `minimum_coverage: 80`** in `coveralls.json` plus `test_coverage: [tool: ExCoveralls]` in `mix.exs` is the correct gate; `mix coveralls` exits 1 below threshold. `mix test` must be replaced, not augmented.
- **`:telemetry_test.attach_event_handlers/2`** ships inside the existing `:telemetry` dep — no new library needed for contract tests. Returns a ref for both assertion and detach; use in `on_exit` to prevent handler leaks.
- **Telemetry must NOT be emitted inside Ecto.Multi / transactions** — emit after `Repo.transaction()` returns `{:ok, ...}`. The `attach/4` and `detach/3` functions in `lib/rindle.ex` run Ecto.Multi; this is the primary emission placement risk.
- **`lib/rindle.ex` hard-codes `Rindle.Repo`** at 5 call sites — the adopter lane will surface this. Planner must decide config-driven resolution vs. documented v1.1 gap.
- **ExDoc `extras:` does not accept globs** — all seven guide files must be listed explicitly. Mermaid is supported via `before_closing_head_tag:` CDN injection — no plugin needed.
- **libvips-dev is NOT required** for the default precompiled NIF mode; including the `apt-get` step per D-14 is a precaution for extended format coverage.

### File Created

`.planning/phases/05-ci-1-0-readiness/05-RESEARCH.md`

### Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Standard stack | HIGH | All versions confirmed via `mix hex.info` |
| CI lane architecture | HIGH | Extension of verified existing `ci.yml` |
| excoveralls configuration | HIGH | Context7 + official README verified |
| Telemetry patterns | HIGH | Context7 telemetry_test module docs |
| ExDoc guides wiring | HIGH | Context7 ExDoc v0.38.4 docs |
| Hex publish dry-run auth | LOW | Not explicitly documented; Assumption A1 |
| libvips requirement | MEDIUM | Default precompiled mode confirmed; platform-provided nuanced |

### Open Questions

1. Config-driven `Rindle.Repo` resolution in `lib/rindle.ex` — v1 fix or v1.1 gap?
2. `mix hex.publish --dry-run` auth requirement — verify against actual Hex CLI behavior during plan execution.
3. Contract lane as separate job vs. folded into quality — planner's call (recommendation: separate parallel job).

### Ready for Planning

Research complete. Planner can now create PLAN.md files.
