# Phase 115: Versioning & README Positioning - Pattern Map

**Mapped:** 2026-07-01
**Files analyzed:** 4 new/modified files
**Analogs found:** 4 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `README.md` | documentation | human onboarding / request-response | `README.md` plus `guides/user_flows.md` | exact |
| `CONTRIBUTING.md` | documentation | contributor workflow / request-response | `CONTRIBUTING.md` | exact |
| `guides/upgrading.md` | documentation | versioned upgrade workflow / batch | `guides/upgrading.md` plus `CHANGELOG.md` | role-match |
| `test/install_smoke/docs_parity_test.exs` | test | contract proof / transform | `test/install_smoke/docs_parity_test.exs` | exact |

Reference-only surfaces that should inform edits but are not phase targets:

| Reference File | Use |
|----------------|-----|
| `guides/user_flows.md` | Source truth for "library, not a platform" and out-of-scope boundary copy. |
| `RUNNING.md` | Durable libvips and FFmpeg install matrix. README should link here instead of duplicating long setup. |
| `guides/getting_started.md` | Deep adopter guide that should stay coherent with README facade-first examples. |
| `CHANGELOG.md` | Release history link target; do not duplicate changelog entries in upgrading guide. |
| `mix.exs` | Existing ExDoc extras and package-file wiring; do not add a new docs subsystem. |

## Pattern Assignments

### `README.md` (documentation, human onboarding / request-response)

**Analog:** `README.md`

**Imports / document header pattern** (`README.md` lines 1-17):

```markdown
<p>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/szTheory/rindle/main/brandbook/assets/logo/rindle-logo-dark.svg">
    <img src="https://raw.githubusercontent.com/szTheory/rindle/main/brandbook/assets/logo/rindle-logo.svg" alt="rindle" height="84">
  </picture>
</p>

# Rindle

[![CI](https://github.com/szTheory/rindle/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/szTheory/rindle/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/rindle.svg)](https://hex.pm/packages/rindle)
[![Docs](https://img.shields.io/badge/hexdocs-latest-blue.svg)](https://hexdocs.pm/rindle)
```

**Orientation pattern** (`README.md` lines 19-34):

```markdown
**Media, made durable.**

Phoenix/Ecto-native media lifecycle library. Rindle owns the durable work that
happens after upload: session tracking, verification, asset state, variants,
background processing, signed delivery, and cleanup.

The first-tier adopter concepts are `Rindle` and `Rindle.Profile`: define a
profile once, then use the facade for upload lifecycle, attachments, and
delivery.

This file is the narrow quickstart. [Getting Started](getting_started.html)
is the canonical deep adopter guide for the same first-run path.
```

Use this voice for the new top sections. Keep the README as the narrow quickstart and link deeper guides for detail.

**Current install and runtime dependency placement to revise** (`README.md` lines 36-72):

````markdown
## Install

Add Rindle to your deps:

```elixir
def deps do
  [
    {:rindle, "~> 0.1"}
  ]
end
```

For AV profiles, install `FFmpeg >= 6.0` before you touch background jobs, then
run `mix rindle.doctor`. The per-platform install/runtime matrix lives in
[Running](running.html).

For image variants, install **libvips** on the host before background image
processing jobs run (`libvips-dev` on Debian/Ubuntu, `vips` via Homebrew on
macOS). See [Running](running.html) for the install matrix.
````

Planner note: the FFmpeg/libvips prerequisite paragraphs are currently above first-run code. Move or reframe them so `## First Attachment in ~2 Minutes` appears before AV setup, FFmpeg, libvips, `kind: :video`, and `Rindle.Profile.Presets.Web`.

**Migration snippet pattern to preserve** (`README.md` lines 96-113):

````markdown
## Migrations

Run your host app migrations and the packaged Rindle migrations explicitly:

```elixir
rindle_path = Application.app_dir(:rindle, "priv/repo/migrations")
host_path = Path.join([File.cwd!(), "priv", "repo", "migrations"])

{:ok, _, _} =
  Ecto.Migrator.with_repo(MyApp.Repo, fn repo ->
    for path <- [host_path, rindle_path] do
      Ecto.Migrator.run(repo, path, :up, all: true)
    end
  end)
```

Rindle does not ship a public `mix rindle.*` install task for migrations. The
public path is the docs snippet above.
````

Keep this current migration shape. Do not document `Rindle.Migration.up/1` or `Rindle.Migration.down/1` in this phase.

**Core facade flow pattern to reuse with image profile** (`README.md` lines 155-175):

```elixir
{:ok, session} =
  Rindle.initiate_upload(MyApp.VideoProfile, filename: "clip.mp4")

{:ok, %{session: signed, presigned: presigned}} =
  Rindle.Upload.Broker.sign_url(session.id)

# your client PUTs bytes to presigned.url

{:ok, %{session: completed, asset: asset}} =
  Rindle.verify_completion(session.id)

{:ok, attachment} =
  Rindle.attach(asset.id, current_user, "hero_video")

{:ok, signed_url} =
  Rindle.url(MyApp.VideoProfile, asset.storage_key)
```

For the new first attachment path, keep this lifecycle but change it to an original-only image profile with `variants: []`, image filename/slot names, and the facade calls required by the UI spec.

**AV quickstart demotion pattern** (`README.md` lines 115-149):

```markdown
## First Run: AV Quickstart

The locked onboarding path is:

1. `mix deps.get`
2. install `FFmpeg >= 6.0` from [Running](running.html)
3. declare one `kind: :video` variant plus the stock poster
4. run `mix rindle.doctor`
5. follow the normal facade-first upload lifecycle

The stock onboarding story is `Rindle.Profile.Presets.Web`: `web_720p` video
output plus `poster` image output.
```

Rename and move this below the image-first path as `## AV Quickstart`. Keep the AV content available, but no longer make it the first hands-on path.

**Boundary source pattern** (`guides/user_flows.md` lines 18-26):

```markdown
## The mental model in one paragraph

Rindle owns everything that happens **after** the upload button. You keep your controllers,
your LiveViews, your schemas, your auth. Rindle takes over the durable, easy-to-get-wrong
middle: handing out direct-to-storage upload tickets, verifying the bytes really landed,
modeling each asset and its derivatives as queryable database rows, generating variants in
the background, serving private signed URLs, and cleaning up after itself. It is a **library,
not a platform** -- it doesn't run a daemon, replace your CDN, or become a streaming service.
```

**Out-of-scope source pattern** (`guides/user_flows.md` lines 357-359):

```markdown
Deliberately *out of scope*, by design: being a full HLS/DASH streaming platform, DRM,
AI/GPU processing, broad PDF/Office handling, or a CDN replacement. Rindle stays
a focused library; those belong to other tools.
```

Use these phrases for `## When Not to Use Rindle`. Keep it as a product-fit boundary, not a warning.

**Next reads pattern** (`README.md` lines 280-288):

```markdown
## Next Reads

- [User Flows](user_flows.html): map your job to the right guide (start here when evaluating)
- [Admin Console](admin_console.html): mount the optional host-authenticated operator console
- [Upgrading](upgrading.html): existing-adopter upgrade runbook (pre-0.1.4 image-only -> current)
- [Getting Started](getting_started.html): deep greenfield guide -- Repo, Oban, migrations, profiles
- [Running](running.html): libvips and FFmpeg install matrix (macOS, Linux, Fly, Heroku, Render, CI)
```

Update the Upgrading label so it no longer describes only the pre-0.1.4 runbook.

---

### `CONTRIBUTING.md` (documentation, contributor workflow / request-response)

**Analog:** `CONTRIBUTING.md`

**Document opening and insertion point** (`CONTRIBUTING.md` lines 1-10):

```markdown
# Contributing to Rindle

Thanks for contributing. Rindle is an Elixir/Phoenix/Ecto-native media lifecycle
library; contributions follow the same production-aware, maintainer-to-maintainer
posture as the rest of the project.

This document focuses on **what CI runs on your PR versus after merge**, so you know
which signal is fast-feedback and which is release-readiness breadth, and on the single
local command -- `mix ci` -- that reproduces the PR verdict before you push.
```

Insert `## Versioning and stability` after this opening and before `## Reproduce the PR gate locally: mix ci`.

**CI command pattern to preserve** (`CONTRIBUTING.md` lines 11-35):

````markdown
## Reproduce the PR gate locally: `mix ci`

`mix ci` runs the same merge-blocking checks the PR gate runs, in a sensible local order:

```sh
mix ci
```

It executes, in order:

1. `deps.get --check-locked` and `deps.unlock --check-unused` -- lockfile drift gates
2. `compile --warnings-as-errors`
3. `format --check-formatted`
4. the four brandbook token->CSS drift gates
5. the gating unit suite (the default-tag ExUnit suite, run under `MIX_ENV=test`)
````

Keep this CI section intact below the new versioning contract.

**Scope note pattern** (`CONTRIBUTING.md` lines 163-167):

```markdown
## Scope note

Rindle keeps `lib/` and public behavior unchanged in CI/infrastructure work. Documentation
and CI-topology changes (like this file) are docs/workflow-only and must not alter the
public API surface.
```

Use this tone if adding a contributor-facing sentence around docs-only stability wording.

---

### `guides/upgrading.md` (documentation, versioned upgrade workflow / batch)

**Analog:** `guides/upgrading.md`

**Current intro to generalize** (`guides/upgrading.md` lines 1-11):

```markdown
# Upgrading Existing Adopters

Use this runbook when your app already ships Rindle from the pre-0.1.4
image-only shape and you need to move onto the current AV-aware runtime
contract. Fresh installs should stay on [README](readme.html) and
[Getting Started](getting_started.html).

CI validates this upgrade path from a generated Phoenix app before each Hex
publish. Follow the checkpoints in order: explicit host plus packaged migrations,
`mix rindle.doctor`, optional `mix rindle.runtime_status`, then the repair verb
that matches the observed state.
```

Change this from a single runbook intro into a reusable upgrade home intro. Add a `CHANGELOG.md` link and `## Version index` immediately after the intro.

**Migration proof sequence to preserve** (`guides/upgrading.md` lines 34-59):

````markdown
## 2. Run Explicit Host And Packaged Migrations

Run your host migrations and the packaged Rindle migrations explicitly. The
canonical upgrade path stays on `Application.app_dir(:rindle, "priv/repo/migrations")`:

```elixir
Application.ensure_all_started(:rindle)
{:ok, _pid} = MyApp.Repo.start_link()

host_path = Path.join([File.cwd!(), "priv", "repo", "migrations"])
rindle_path = Application.app_dir(:rindle, "priv/repo/migrations")

unless File.dir?(rindle_path) do
  raise "Rindle migration path missing: #{rindle_path}"
end

{:ok, _, _} =
  Ecto.Migrator.with_repo(MyApp.Repo, fn repo ->
    for path <- [host_path, rindle_path] do
      Ecto.Migrator.run(repo, path, :up, all: true)
    end
  end)
```

Rindle still does not hide this behind a public install task. The host app owns
the migration handoff.
````

Wrap this inside the version section `## 0.1.3 and earlier -> current AV-aware runtime`.

**Validation pattern to preserve** (`guides/upgrading.md` lines 61-85):

````markdown
## 3. Validate The Upgraded Runtime

Run the read-only environment check immediately after migrations:

```bash
mix rindle.doctor
```

`mix rindle.doctor` validates setup and drift. If it reports FFmpeg, Oban, or
migration issues, fix those before you attempt any repair command.

## 4. Inspect Degraded Upgraded Work When Needed

```bash
mix rindle.runtime_status --format json
```
````

Put these under the required `Verification` subsection for the preserved pre-0.1.4 upgrade entry.

**Repair command pattern to preserve** (`guides/upgrading.md` lines 87-112):

````markdown
## 5. Repair One Upgraded Asset Through The Public Facade

For one failed upgraded asset, use the asset-scoped repair surface:

```elixir
asset_id = "..."

{:ok, report} =
  Rindle.requeue_variants(asset_id, variant_names: ["web_720p"])
```

## 6. Reserve Broad Drift Repair For Stale Or Missing Variants

```bash
mix rindle.regenerate_variants
```
````

Preserve these action lanes under `Upgrade steps` or `Verification`; do not lose `Rindle.requeue_variants/2` or `mix rindle.regenerate_variants`.

**Versioned changelog section analog** (`CHANGELOG.md` lines 1-6, 46-50, 132-136):

```markdown
# Changelog

0.1.0-0.1.3 were release-pipeline shakedown iterations; treat 0.1.4 as the first recommended pin.

## [0.3.1](https://github.com/szTheory/rindle/compare/rindle-v0.3.0...rindle-v0.3.1) (2026-06-26)

## [0.3.0](https://github.com/szTheory/rindle/compare/rindle-v0.1.10...rindle-v0.3.0) (2026-06-20)

## [0.1.10](https://github.com/szTheory/rindle/compare/rindle-v0.1.9...rindle-v0.1.10) (2026-05-30)
```

Use newest-first version sections in the upgrade guide, but keep the guide action-oriented instead of copying changelog bullets.

---

### `test/install_smoke/docs_parity_test.exs` (test, contract proof / transform)

**Analog:** `test/install_smoke/docs_parity_test.exs`

**Imports and path attributes pattern** (`test/install_smoke/docs_parity_test.exs` lines 1-18):

```elixir
Code.require_file("support/generated_app_helper.ex", __DIR__)

defmodule Rindle.InstallSmoke.DocsParityTest do
  alias Rindle.InstallSmoke.GeneratedAppHelper
  use ExUnit.Case, async: true

  @readme_path Path.expand("../../README.md", __DIR__)
  @guide_path Path.expand("../../guides/getting_started.md", __DIR__)
  @upgrade_path Path.expand("../../guides/upgrading.md", __DIR__)
  @troubleshooting_path Path.expand("../../guides/troubleshooting.md", __DIR__)
  @release_path Path.expand("../../guides/release_publish.md", __DIR__)
  @running_path Path.expand("../../RUNNING.md", __DIR__)
  @user_flows_path Path.expand("../../guides/user_flows.md", __DIR__)
  @operations_path Path.expand("../../guides/operations.md", __DIR__)
  @admin_console_path Path.expand("../../guides/admin_console.md", __DIR__)
  @mix_exs_path Path.expand("../../mix.exs", __DIR__)
```

Add `@contributing_path Path.expand("../../CONTRIBUTING.md", __DIR__)` here if the test reads CONTRIBUTING through setup. Direct `File.read!(@contributing_path)` inside a single test is also consistent with nearby tests that read one-off files.

**Setup pattern** (`test/install_smoke/docs_parity_test.exs` lines 32-43):

```elixir
setup_all do
  {:ok,
   %{
     readme: File.read!(@readme_path),
     guide: File.read!(@guide_path),
     upgrade: File.read!(@upgrade_path),
     troubleshooting: File.read!(@troubleshooting_path),
     release: File.read!(@release_path),
     running: File.read!(@running_path),
     user_flows: File.read!(@user_flows_path)
   }}
end
```

Use this map for shared docs read by multiple tests. Add CONTRIBUTING only if multiple new assertions need it.

**Facade-first assertion pattern** (`test/install_smoke/docs_parity_test.exs` lines 45-60):

```elixir
test "README and getting-started guide teach the facade-first lifecycle and handoff", %{
  readme: readme,
  guide: guide
} do
  for doc <- [readme, guide] do
    assert doc =~ "Rindle.Profile"
    assert doc =~ "Rindle.initiate_upload"
    assert doc =~ "Rindle.verify_completion"
    assert doc =~ "Rindle.attach"
    assert doc =~ "Rindle.url"
  end

  assert readme =~ "getting_started.html"
  assert readme =~ "canonical deep adopter guide"
  assert guide =~ "[README](readme.html)"
end
```

Extend or add sibling tests rather than weakening this. New README first-run assertions should still preserve the facade-first lifecycle.

**Current AV onboarding assertion to revise deliberately** (`test/install_smoke/docs_parity_test.exs` lines 164-179):

```elixir
test "README and getting-started guide teach the locked AV onboarding path", %{
  readme: readme,
  guide: guide
} do
  for doc <- [readme, guide] do
    assert doc =~ "mix deps.get"
    assert doc =~ "mix rindle.doctor"
    assert doc =~ "libvips"
    assert doc =~ "Rindle.Profile.Presets.Web"
    assert doc =~ "kind: :video"
    assert doc =~ "preset: :web_720p"
    assert doc =~ "preset: :video_poster_scene"
    assert doc =~ "FFmpeg >= 6.0"
    assert doc =~ "running.html"
  end
end
```

Keep proof that the AV path exists, but add README-specific order assertions so AV is below the image-first section.

**Upgrade proof pattern** (`test/install_smoke/docs_parity_test.exs` lines 198-221):

```elixir
test "upgrade guidance is discoverable without polluting the greenfield path", %{
  readme: readme,
  guide: guide,
  upgrade: upgrade,
  release: release
} do
  assert readme =~ "upgrading.html"
  assert guide =~ "[Upgrading](upgrading.html)"
  assert release =~ "[Upgrading](upgrading.html)"
  assert upgrade =~ "[Getting Started](getting_started.html)"
  assert upgrade =~ "pre-0.1.4"
  assert String.downcase(upgrade) =~ "existing adopters"
end

test "upgrade guide mirrors the canonical generated-app proof sequence", %{upgrade: upgrade} do
  steps = GeneratedAppHelper.canonical_upgrade_step_sequence()

  for step <- steps do
    assert String.downcase(upgrade) =~ String.downcase(step.checkpoint)
    assert upgrade =~ step.proof
  end

  assert_in_order!(upgrade, Enum.map(steps, & &1.checkpoint))
end
```

Add assertions for `## Version index`, `## Unreleased / Next`, `## 0.1.3 and earlier -> current AV-aware runtime`, and subsection labels `Applies to`, `What changed`, `Upgrade steps`, `Verification`.

**Runtime matrix assertions to preserve** (`test/install_smoke/docs_parity_test.exs` lines 223-248):

```elixir
test "running guide publishes the durable libvips install matrix", %{running: running} do
  for snippet <- [
        "libvips",
        "libvips-dev",
        "brew install vips",
        "Image runtime (libvips)"
      ] do
    assert running =~ snippet
  end
end

test "running guide publishes the durable FFmpeg install matrix", %{running: running} do
  for snippet <- [
        "FFmpeg >= 6.0",
        "brew install ffmpeg",
        "apt-get install -y ffmpeg",
        "apk add --no-cache ffmpeg",
        "FedericoCarboni/setup-ffmpeg",
        "mix rindle.doctor"
      ] do
    assert running =~ snippet
  end
end
```

These support README links to `running.html`; do not duplicate long matrices in README.

**Ordering helper pattern** (`test/install_smoke/docs_parity_test.exs` lines 508-537):

```elixir
defp introductory_section(doc) do
  case Regex.split(~r/^##\s+/m, doc, parts: 2) do
    [intro] -> intro
    [intro, _rest] -> intro
  end
end

defp assert_in_order!(doc, snippets) do
  normalized_doc = String.downcase(doc)

  {_last_index, _last_snippet} =
    Enum.reduce(snippets, {-1, nil}, fn snippet, {last_index, _last_snippet} ->
      index = string_index(normalized_doc, String.downcase(snippet))

      assert index,
             "expected snippet #{inspect(snippet)} to appear in order after index #{last_index}"

      assert index > last_index,
             "expected snippet #{inspect(snippet)} to appear after #{last_index}, got #{index}"

      {index, snippet}
    end)
end

defp string_index(doc, snippet) do
  case :binary.match(doc, snippet) do
    {index, _length} -> index
    :nomatch -> nil
  end
end
```

Use `assert_in_order!/2` for README section ordering and `string_index/2` for "image section before AV tokens" checks.

## Shared Patterns

### Stability Contract

**Source:** `.planning/phases/115-versioning-readme-positioning/115-UI-SPEC.md` lines 135-140

**Apply to:** `README.md`, `CONTRIBUTING.md`, `test/install_smoke/docs_parity_test.exs`

```markdown
README and CONTRIBUTING must use the same stability sentence: `Rindle follows Semantic Versioning. While Rindle is 0.x, public APIs may change between minor versions; review CHANGELOG.md and guides/upgrading.md before upgrading. Rindle 1.0 will mean the public API is stable enough that breaking public API changes move to major versions.`

`guides/upgrading.md` must separate "what changed" from "what to do" using these exact subsection labels under each version: `Applies to`, `What changed`, `Upgrade steps`, `Verification`.

The upgrade guide must be newest-first and link to `CHANGELOG.md`.

Do not document future `Rindle.Migration.up/1` or `down/1` in Phase 115. Phase 116 owns that API.
```

### Required Markdown Hierarchy

**Source:** `.planning/phases/115-versioning-readme-positioning/115-UI-SPEC.md` lines 105-117

**Apply to:** `README.md`, `CONTRIBUTING.md`, `guides/upgrading.md`

```markdown
| README | `## Versioning and stability` | Above first-run code, near install/orientation |
| README | `## First Attachment in ~2 Minutes` | First hands-on path; must appear before any AV quickstart heading, FFmpeg prerequisite, libvips prerequisite, `kind: :video`, or `Rindle.Profile.Presets.Web` |
| README | `## AV Quickstart` | Below the image/original-only first attachment path; clearly framed as the heavier path |
| README | `## When Not to Use Rindle` | Before final guide links or near positioning section; lift and compress from `guides/user_flows.md` |
| CONTRIBUTING | `## Versioning and stability` | Near the top, before CI/release-process detail |
| guides/upgrading.md | `## Version index` | Immediately after the intro |
| guides/upgrading.md | `## Unreleased / Next` | First entry in the versioned notes |
| guides/upgrading.md | `## 0.1.3 and earlier -> current AV-aware runtime` | Preserve the current pre-0.1.4 upgrade path as a versioned section |
```

### Callout And Copy Shape

**Source:** `.planning/phases/115-versioning-readme-positioning/115-UI-SPEC.md` lines 127-133

**Apply to:** All Markdown docs touched in this phase

```markdown
- Use portable Markdown blockquotes with bold lead labels, not custom admonition plugins.
- Approved labels: `Versioning:`, `Note:`, `When not to use Rindle:`, `Upgrade note:`.
- Maximum three callouts before `AV Quickstart`.
- Keep callouts factual and short. No marketing claims, hype, or decorative language.
- Do not use warning/error styling for normal versioning or product-fit boundaries.
```

### Runtime Dependency Boundary

**Source:** `RUNNING.md` lines 1-32 and 227-240

**Apply to:** `README.md`, docs parity assertions

```markdown
# Running Rindle Image and AV Profiles

Use this guide for host-runtime dependencies before Rindle background jobs process
variants. Image processing uses libvips (via Vix). AV processing uses FFmpeg.

## Image runtime (libvips)

Image-only adopters need libvips on the host before `ProcessVariant` jobs run:

## AV runtime (FFmpeg)

Use this section when your adopter app enables video or audio processing. The AV
runtime contract is small and explicit:

1. install `FFmpeg >= 6.0` for the target platform
2. run `mix rindle.doctor`
3. only then start background jobs that process AV variants

[README](readme.html) stays the narrow quickstart. [Getting Started](getting_started.html)
is the canonical deep onboarding guide. This file is the shared install/runtime
matrix both of those entrypoints link to.
```

Do not claim the complete image background lifecycle is libvips-free. Safe wording: original-only first attachment avoids AV setup and does not require FFmpeg; image variants/background image processing still need libvips.

### ExDoc Extras And Packaging

**Source:** `mix.exs` lines 155-179 and 279-289

**Apply to:** Planning boundaries for all docs work

```elixir
defp docs do
  [
    main: "Rindle",
    source_url: @source_url,
    logo: "brandbook/assets/logo/rindle-mark-dark.svg",
    favicon: "brandbook/assets/logo/favicon.svg",
    extras: [
      "README.md",
      "RUNNING.md",
      "guides/user_flows.md",
      "guides/getting_started.md",
      "guides/upgrading.md",
      "guides/core_concepts.md",
      "guides/storage_capabilities.md",
      "guides/storage_gcs.md",
      "guides/profiles.md",
      "guides/admin_console.md",
      "guides/secure_delivery.md",
      "guides/resumable_uploads.md",
      "guides/streaming_providers.md",
      "guides/background_processing.md",
      "guides/operations.md",
      "guides/troubleshooting.md",
      "guides/release_publish.md"
    ],
```

```elixir
files:
  ~w(lib priv/repo/migrations priv/static/rindle_admin mix.exs README.md RUNNING.md CHANGELOG.md LICENSE guides)
```

Phase 115 should not add a docs site, Markdown plugin, CSS/JS dependency, or new ExDoc subsystem.

### Verification Commands

**Source:** `CONTRIBUTING.md` lines 11-17 and research validation map

**Apply to:** Plan verification section

```sh
MIX_ENV=test mix test test/install_smoke/docs_parity_test.exs --trace
mix format --check-formatted test/install_smoke/docs_parity_test.exs
```

Full phase gate remains `mix ci` or the documented equivalent required by `RUNNING.md` and `CONTRIBUTING.md`.

## No Analog Found

All scoped files have usable local analogs.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| none | n/a | n/a | n/a |

## Metadata

**Analog search scope:** `README.md`, `CONTRIBUTING.md`, `guides/*.md`, `RUNNING.md`, `CHANGELOG.md`, `mix.exs`, `test/install_smoke/*.exs`, phase `115-UI-SPEC.md`
**Files scanned:** 38 repo files plus 3 phase artifacts
**Pattern extraction date:** 2026-07-01
**Project instructions loaded:** `AGENTS.md`; repo-local skill index `.codex/skills/gsd-milestone-next-step/SKILL.md`
