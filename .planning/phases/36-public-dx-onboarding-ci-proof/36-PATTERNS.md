# Phase 36: Public DX, Onboarding, CI Proof — Pattern Map

**Mapped:** 2026-05-07
**Files analyzed:** 16 (6 added + 10 modified, per CONTEXT.md D-31 + D-32)
**Analogs found:** 16 / 16 (all in-repo; one analog — `scripts/install_smoke.sh` — is a shape-only match for `scripts/mux_soak_cleanup.sh`)

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/rindle/profile/presets/mux_web.ex` (new) | preset macro | compile-time DSL emission | `lib/rindle/profile/presets/web.ex` (lines 18-43) | exact (same role + same data flow; literal template) |
| `guides/streaming_providers.md` (new) | adopter guide (markdown) | doc | `guides/secure_delivery.md` (lines 1-80) | exact (style template, same audience) |
| `scripts/mux_soak_cleanup.sh` (new) | shell script (CI cleanup) | side-effect / API call | `scripts/install_smoke.sh` (lines 1-43) | shape-only (bash + `set -euo pipefail` + `mix run --no-start`-style invocation; planner picks bash vs Elixir) |
| `test/fixtures/mux/test_signing_public_key.pem` (new) | fixture (PEM) | static asset | `test/fixtures/mux/test_signing_private_key.pem` (committed in Phase 34 D-37) | exact (companion key — generated via `openssl rsa -pubout`) |
| `test/rindle/profile/presets/mux_web_test.exs` (new) | ExUnit test | compile-time + runtime assertion | `test/rindle/profile/presets_web_test.exs` (full file) | exact (same pattern: nested `defmodule` test profile + `Web.variants/1` assertions + profile-consumption assertions) |
| `test/rindle/ops/runtime_checks_streaming_test.exs` (new) | ExUnit test | runtime check report assertion | `test/rindle/ops/runtime_checks_test.exs` (lines 1-165+) | exact (same `RuntimeChecks.run/2` driver + `fetch_check/2` accessor pattern) |
| `mix.exs` (modified) | config | static list extension | `mix.exs` (extras list lines 116-128) | exact (insertion-point match) |
| `lib/rindle/ops/runtime_checks.ex` (modified) | runtime check pipeline | profile-discovery-gated checks | `lib/rindle/ops/runtime_checks.ex` (checks list lines 44-54 + `defp check_local_playback` lines 220-251) | exact (self-template; append four `defp check_streaming_*` clauses) |
| `lib/mix/tasks/rindle.doctor.ex` (modified) | mix task | OptionParser flag plumbing | `lib/mix/tasks/rindle.doctor.ex` (lines 33-50) | exact (self-template; add `:streaming` strict opt) |
| `test/install_smoke/support/generated_app_helper.ex` (modified) | test helper | env/config injection | `test/install_smoke/support/generated_app_helper.ex` (existing `:image | :video` heads) | exact (self-template; add `:mux` discriminator) |
| `test/install_smoke/generated_app_smoke_test.exs` (modified) | ExUnit test module | report assertions | `Rindle.InstallSmoke.GeneratedAppSmokeImageTest` / `Video` (lines 36-95) | exact (mirror module shape; add `Mux` module) |
| `scripts/install_smoke.sh` (modified) | shell script | profile dispatch | `scripts/install_smoke.sh` line 19 (self) | exact (one-line case-arm extension) |
| `.github/workflows/ci.yml` (modified) | GitHub Actions workflow | CI orchestration | `.github/workflows/ci.yml` (`package-consumer` 284-391 + `adopter` 393-545 + doc-parity 518-545) | exact (self-templates for step + sibling job + required-strings list) |
| `README.md` (modified) | doc | static markdown append | existing AV Quickstart heading at `README.md:101` | exact (append after canonical AV path) |
| `guides/getting_started.md` (modified) | doc | static markdown append | existing Section 9 ("Bang Variants") at line 310 / Section 10 area | exact (append after Section 10 / canonical AV path) |
| `CHANGELOG.md` (modified) | doc | release-note append | existing `## [Unreleased] ### Added` block at top | exact (append additive entries — no rewrites per D-34) |

## Pattern Assignments

### `lib/rindle/profile/presets/mux_web.ex` (new — preset macro, compile-time DSL emission)

**Analog:** `lib/rindle/profile/presets/web.ex` (full 47-line file)

**Imports / module shape pattern** (lines 1-13):
```elixir
defmodule Rindle.Profile.Presets.Web do
  @moduledoc """
  Stock AV preset helpers for the canonical web onboarding story.
  ...
  """

  @type option :: {:scrub_strip, boolean()}
```

**`__using__/1` macro pattern** (lines 17-30):
```elixir
@doc false
defmacro __using__(opts) do
  opts = Macro.expand_literals(opts, __CALLER__)
  scrub_strip? = Keyword.get(opts, :scrub_strip, false)

  profile_opts =
    opts
    |> Keyword.delete(:scrub_strip)
    |> Keyword.put(:variants, variants(scrub_strip: scrub_strip?))

  quote do
    use Rindle.Profile, unquote(Macro.escape(profile_opts))
  end
end
```

**`variants/1` helper pattern** (lines 32-43):
```elixir
@doc """
Returns the stock AV variant declarations for the onboarding story.
"""
@spec variants([option()]) :: keyword(keyword())
def variants(opts \\ []) do
  scrub_strip? = Keyword.get(opts, :scrub_strip, false)

  [
    web_720p: [kind: :video, preset: :web_720p],
    poster: [kind: :image, preset: :video_poster_scene]
  ] ++ maybe_scrub_strip(scrub_strip?)
end
```

**What changes vs. the analog (per D-01..D-04):**
- `MuxWeb.__using__/1` does **not** redeclare variant atoms — it calls `Rindle.Profile.Presets.Web.variants/1` directly to inherit `web_720p` + `poster` verbatim (D-01: "do NOT redeclare the variant atoms — call `Rindle.Profile.Presets.Web.variants/1`"). This preserves the package-consumer assertion `["poster", "web_720p"]` byte-identically.
- After computing `profile_opts` from `Web.variants/1`, MuxWeb merges the locked `:delivery` block last so adopter overrides win (D-01 final clause):
  ```elixir
  delivery: [
    streaming: %{
      provider: Rindle.Streaming.Provider.Mux,
      playback_policy: :signed,
      ingest_mode: :server_push,
      source_variant: :web_720p
    }
  ]
  ```
- Passes through the same opts as `Web` (`:storage`, `:allow_mime`, `:max_bytes`, `:scrub_strip`) — D-01 "thin wrapper" posture.
- No `__using__/1` opt-out option for streaming (D-03: "MuxWeb is a streaming-on preset by definition").
- No new variant atoms (D-04). Validation happens through Phase 33's `@streaming_schema` in `lib/rindle/profile/validator.ex`.

---

### `guides/streaming_providers.md` (new — adopter guide markdown)

**Analog:** `guides/secure_delivery.md` (full file, 209 lines; first 80 examined)

**Heading + private-by-default narrative pattern** (lines 1-21):
```markdown
# Secure Delivery

Rindle is **private-by-default**. A profile that does not opt into public
delivery serves every original and every variant via signed, time-limited
URLs. ...

This guide covers:

- The default private delivery posture
- How to configure signed URL TTL per profile
- ...

For the full adapter/provider matrix, ..., see [Storage Capabilities](storage_capabilities.html).
```

**Locked-snippet pattern** (lines 22-44):
```markdown
## Default: Private with Signed URLs

A profile that declares no `delivery:` option is private:

```elixir
defmodule MyApp.MediaProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    variants: [thumb: [mode: :fit, width: 64, height: 64]]
end
\``` <!-- escape -->
```

**What changes vs. the analog (per D-09..D-13):**
- 11-section ordering locked by D-10 (Why → Add deps → Mux signing key → Configure profile → Wire webhook → Schedule cron → Local tunnel → Secret rotation → `mix rindle.doctor --streaming` → Stuck-asset runbook → Performance note).
- Mux-only narrative (D-09): no second-provider scaffold headings.
- Steps 5–6 copy verbatim from the moduledocs at `lib/rindle/delivery/webhook_plug.ex` lines 7-23 (Steps 1-3 of the plug's adopter wiring) and `lib/rindle/workers/mux_sync_coordinator.ex` lines 13-24 (the "Cron Configuration Example" block). When inlined, include `<!-- source: lib/rindle/delivery/webhook_plug.ex @moduledoc -->` HTML comments per D-13.
- Step 7 (local tunnel): cloudflared primary, ngrok alternative-with-caveat (D-11) — 5-10 lines, link out to vendor docs only.
- Step 11 (performance note): document the `JOSE.JWK.from_pem/1` re-parse footgun and `:persistent_term` cache recommendation; note the cache itself ships in v1.7+ (Phase 34 D-09 deferred).
- Bottom-of-guide Quick Reference table listing every Phase 35 telemetry event under `[:rindle, :provider, :webhook, _]` and `[:rindle, :provider, :mux, :webhook_attempt, _]` (mirrors `secure_delivery.md` table style).

---

### `scripts/mux_soak_cleanup.sh` (new — soak-lane belt-and-suspenders cleanup)

**Analog:** `scripts/install_smoke.sh` (full 43-line file — shape only)

**Shell preamble pattern** (lines 1-9):
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR="${RINDLE_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/rindle-install-smoke-script-XXXXXX")
PACKAGE_NAME=$(cd "$ROOT_DIR" && mix run --no-start -e 'project = Mix.Project.config(); IO.write("#{project[:app]}-#{project[:version]}")')
PACKAGE_ROOT="${RINDLE_INSTALL_SMOKE_PACKAGE_ROOT:-$WORK_DIR/$PACKAGE_NAME}"
PROFILE="${1:-${RINDLE_INSTALL_SMOKE_PROFILE:-image}}"
```

**Cleanup-on-EXIT pattern** (lines 11-15):
```bash
cleanup() {
  rm -rf "$WORK_DIR"
}

trap cleanup EXIT
```

**`mix run --no-start -e ...` invocation pattern** (line 7 — the only template precedent for shell-out to a one-shot Elixir task):
```bash
mix run --no-start -e 'project = Mix.Project.config(); IO.write("#{project[:app]}-#{project[:version]}")'
```

**What changes vs. the analog (per D-22, D-23, "Claude's Discretion" §227):**
- Purpose differs entirely — install_smoke.sh dispatches the test runner; mux_soak_cleanup.sh sweeps Mux assets via the SDK. Only the bash-script *shape* (set flags, SCRIPT_DIR/ROOT_DIR resolution, optional cleanup trap) transfers.
- Body invokes `mix run --no-start -e "Mux.Video.Assets.list/1 + delete loop"` against real Mux, gated on `RINDLE_MUX_TOKEN_ID` / `RINDLE_MUX_TOKEN_SECRET` being set; exits 0 when env unset (so the `if: always()` step does not fail when secrets resolved to empty strings on a fork PR).
- Filter strategy: list assets, filter by metadata tag (`{"meta": {"rindle_soak": "true"}}`) per CONTEXT.md §231 preference (more robust than name-pattern matching).
- Logs MUST redact `provider_asset_id` to last-4 chars per security invariant 14 (use `Rindle.Domain.MediaProviderAsset.redact_id/1` if invoked from Elixir; or trim to last 4 chars in bash).
- Planner may pick a thin bash-only implementation that shells out to `mix run --no-start -e ...` (matches the install_smoke.sh idiom) OR a standalone `priv/scripts/mux_soak_cleanup.exs` Elixir script invoked via `mix run` — either is acceptable per "Claude's Discretion" §226.

---

### `test/fixtures/mux/test_signing_public_key.pem` (new — fixture)

**Analog:** `test/fixtures/mux/test_signing_private_key.pem` (committed in Phase 34 D-37)

**Generation pattern (per D-31 file note):**
```bash
openssl rsa \
  -in test/fixtures/mux/test_signing_private_key.pem \
  -pubout \
  -out test/fixtures/mux/test_signing_public_key.pem
```

**What changes vs. the analog:**
- The private key already exists; this is the public half generated once and committed. Both keys are RSA-2048 fixtures used only for cassette-mode JWT signing/decoding — never for real Mux traffic.
- Consumer: the new `lifecycle_test_source(_app_module, :mux)` head-clause asserts that `Rindle.Delivery.streaming_url/3` returns a Mux-signed HLS URL whose JWT decodes against this public key (D-15).

---

### `test/rindle/profile/presets/mux_web_test.exs` (new — preset compile + DSL validation tests)

**Analog:** `test/rindle/profile/presets_web_test.exs` (full 73-line file). Note path: the existing test lives at `test/rindle/profile/presets_web_test.exs` (flat filename), not under `presets/`. Phase 36 may either follow the existing flat pattern (`test/rindle/profile/presets_mux_web_test.exs`) or create the `presets/` subdirectory — D-31 specifies the latter, but planner should call out the inconsistency.

**Test module + nested test-profile pattern** (lines 1-24):
```elixir
defmodule Rindle.Profile.PresetsWebTest do
  use ExUnit.Case, async: true

  alias Rindle.Adopter.CanonicalApp.VideoProfile, as: CanonicalVideoProfile
  alias Rindle.Profile.Presets.Web

  defmodule PresetProfile do
    @moduledoc false

    use Web,
      storage: Rindle.Storage.Local,
      allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
      max_bytes: 524_288_000
  end

  defmodule PresetProfileWithStrip do
    @moduledoc false

    use Web,
      storage: Rindle.Storage.Local,
      allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
      max_bytes: 524_288_000,
      scrub_strip: true
  end
```

**`variants/1` assertion pattern** (lines 26-41):
```elixir
describe "variants/1" do
  test "teaches the explicit web_720p plus poster onboarding story" do
    assert Web.variants() == [
             web_720p: [kind: :video, preset: :web_720p],
             poster: [kind: :image, preset: :video_poster_scene]
           ]
  end
end
```

**Profile-consumption assertion pattern** (lines 43-57):
```elixir
describe "profile consumption" do
  test "compiles into a real profile without inventing raw FFmpeg policy" do
    assert PresetProfile.variants() == [
             poster: %{preset: :video_poster_scene},
             web_720p: %{kind: :video, preset: :web_720p, faststart: true}
           ]
  end
end
```

**What changes vs. the analog:**
- Test module name: `Rindle.Profile.PresetsMuxWebTest`.
- Nested test profile uses `use Rindle.Profile.Presets.MuxWeb, ...` instead of `Web`.
- Drop `scrub_strip: true` variation (MuxWeb has no `:scrub_strip` opt-in per D-03).
- Add a new describe block: `"streaming delivery policy"` asserting `PresetProfile.delivery_policy().streaming == %{provider: Rindle.Streaming.Provider.Mux, playback_policy: :signed, ingest_mode: :server_push, source_variant: :web_720p}` — directly proves D-02's locked block.
- Add an assertion that `MuxWeb` inherits `Web.variants/1` (D-01 invariant): `assert PresetProfile.variants() == PresetProfileFromWeb.variants()` where `PresetProfileFromWeb` is a sibling test profile using `Web` with the same opts.

---

### `test/rindle/ops/runtime_checks_streaming_test.exs` (new — four streaming check tests)

**Analog:** `test/rindle/ops/runtime_checks_test.exs` (lines 1-165+)

**Test setup + nested profile pattern** (lines 1-31):
```elixir
defmodule Rindle.Ops.RuntimeChecksTest do
  use ExUnit.Case, async: true

  alias Rindle.Ops.RuntimeChecks
  alias Rindle.Storage.Local

  defmodule ImageProfile do
    use Rindle.Profile,
      storage: Rindle.Storage.S3,
      variants: [thumb: [mode: :fit, width: 64, height: 64]]
  end

  defmodule VideoProfile do
    use Rindle.Profile.Presets.Web,
      storage: Rindle.Storage.S3,
      allow_mime: ["video/mp4"],
      max_bytes: 10_000_000
  end
```

**`RuntimeChecks.run/2` driver + `fetch_check/2` accessor pattern** (lines 34-67, 138-142):
```elixir
report =
  RuntimeChecks.run([],
    probe: fn -> :ok end,
    env: %{},
    profiles: [ImageProfile, VideoProfile],
    oban_config: [...],
    migration_statuses: [],
    local_playback_route: [...]
  )

# ...

check = fetch_check(report, "doctor.delivery_support")
assert check.status == :error
assert check.summary =~ "PrivateLocalImageProfile"
assert check.fix =~ "signed_url"
```

**What changes vs. the analog:**
- Add a `MuxStreamingProfile` test profile using `Rindle.Profile.Presets.MuxWeb`.
- Four new describe blocks, one per check ID:
  - `"doctor.streaming_credentials"` — test PASS with all five env vars set; FAIL with each missing (table-driven).
  - `"doctor.streaming_signing_key"` — test PASS with the fixture PEM; FAIL with malformed PEM (`JOSE.JWK.from_pem/1` raises).
  - `"doctor.streaming_webhook_secrets"` — test PASS with `whsec_…(≥32 chars)`; FAIL with empty list and FAIL with a too-short secret.
  - `"doctor.streaming_smoke_ping"` — test PASS when `streaming: true` opt + Mox stub returns 200; PASS-skip when `streaming: false`/absent (default; vacuous summary); FAIL on 401/403/429/timeout/5xx (per D-08 fix-recipe taxonomy).
- All four checks must additionally test the **profile-discovery gate** (D-06): when `profiles: [ImageProfile]` (no streaming-enabled profile), each check returns `ok_result` with summary `"No streaming-enabled profiles discovered."` — mirrors `check_local_playback`'s vacuous-summary pattern at `runtime_checks.ex:225-233`.
- Pass `env:` map directly to `RuntimeChecks.run/2` (existing `Keyword.get(opts, :env, System.get_env())` seam at `runtime_checks.ex:34`); avoid mutating `System.put_env/2` in `async: true` tests.

---

### `mix.exs` (modified — add `streaming_providers.md` to extras)

**Analog:** `mix.exs` lines 116-128 (self-template — the existing `extras` list)

**Insertion-point pattern** (lines 116-128):
```elixir
extras: [
  "README.md",
  "RUNNING.md",
  "guides/getting_started.md",
  "guides/core_concepts.md",
  "guides/storage_capabilities.md",
  "guides/profiles.md",
  "guides/secure_delivery.md",
  "guides/background_processing.md",
  "guides/operations.md",
  "guides/release_publish.md",
  "guides/troubleshooting.md"
],
```

**What changes vs. the analog:**
- Per CONTEXT.md D-32 ("alphabetical position: between `secure_delivery.md` and `troubleshooting.md`"): insert `"guides/streaming_providers.md"` between `"guides/secure_delivery.md"` (line 123) and `"guides/background_processing.md"` (line 124). Note: strict alphabetical ordering would place it after `secure_delivery.md` — the existing list is NOT pure alphabetical (background_processing, operations, release_publish are out of order), so D-32's "between secure_delivery.md and troubleshooting.md" is the intended placement (immediately after `secure_delivery.md`).
- No other changes to `mix.exs` — `extras` list is the only edit. `groups_for_extras: [Guides: ~r/guides\/.*/]` (lines 129-131) already matches the new file.

---

### `lib/rindle/ops/runtime_checks.ex` (modified — append four streaming checks)

**Analog:** self — `lib/rindle/ops/runtime_checks.ex` (existing checks list lines 44-54, `defp check_local_playback` at lines 220-251, `ok_result`/`error_result` helpers at 476-482)

**`checks` list append-point pattern** (lines 44-54):
```elixir
checks =
  [
    fn -> check_delivery_support(profiles) end,
    fn -> check_ffmpeg_runtime(probe) end,
    fn -> check_local_playback(profiles, local_playback_route) end,
    fn -> check_migration_pending(migration_statuses) end,
    fn -> check_migration_unresolved(migration_statuses) end,
    fn -> check_oban_default_instance(oban_config) end,
    fn -> check_oban_required_queues(profiles, oban_config) end,
    fn -> check_profile_runtime_fit(resolved, env) end
  ]
  |> Enum.map(&run_check/1)
  |> Enum.sort_by(& &1.id)
```

**Profile-discovery-gated check pattern (the "vacuous OK when no relevant profiles")** (lines 220-251 — `check_local_playback`):
```elixir
defp check_local_playback(profiles, local_playback_route) do
  local_av_profiles =
    profiles
    |> Enum.filter(&(local_av_profile?(&1)))
    |> Enum.map(&inspect/1)

  cond do
    local_av_profiles == [] ->
      ok_result(
        "doctor.local_playback",
        :delivery,
        "No local AV playback profiles were discovered.",
        @local_playback_fix
      )

    complete_local_playback_route?(local_playback_route) ->
      ok_result(
        "doctor.local_playback",
        :delivery,
        "Local AV playback route config is present for #{Enum.join(local_av_profiles, ", ")}.",
        @local_playback_fix
      )

    true ->
      error_result(
        "doctor.local_playback",
        :delivery,
        "Local AV playback route config is missing or incomplete for #{Enum.join(local_av_profiles, ", ")}.",
        @local_playback_fix
      )
  end
end
```

**`ok_result` / `error_result` helper pattern** (lines 476-482):
```elixir
defp ok_result(id, component, summary, fix) do
  %{id: id, status: :ok, component: component, summary: summary, fix: fix}
end

defp error_result(id, component, summary, fix) do
  %{id: id, status: :error, component: component, summary: summary, fix: fix}
end
```

**What changes vs. the analog (per D-05..D-08):**
- Append four new `fn -> check_streaming_*(profiles, env, opts) end` thunks to the `checks` list at lines 44-54 (after `check_profile_runtime_fit`). The `Enum.sort_by(& &1.id)` line auto-orders the report, so insertion order doesn't matter.
- Each new `defp check_streaming_<id>` mirrors `check_local_playback`'s shape: filter `profiles` by `delivery_policy().streaming` (consume via `Rindle.Capability.report/0` per D-06), return vacuous `ok_result` when empty, otherwise validate the env / config and return ok or error.
- All four checks emit `component: :streaming` in their result map.
- Smoke-ping check `doctor.streaming_smoke_ping` reads `Keyword.get(opts, :streaming, false)`; when false, returns `ok_result` with summary `"Smoke ping skipped (pass --streaming to enable live API check)."` (D-07). When true, runs `Mux.Video.Assets.list/1` via `Task.async`/`Task.await(5_000)`/`Task.shutdown` for the hard 5s timeout (D-07).
- `:mux` optional-dep gate (D-06): when at least one streaming-enabled profile is discovered but `Code.ensure_loaded?(Mux.Video.Assets)` returns false, return `error_result` with fix `"Add {:mux, \"~> 3.2\", optional: true} and {:jose, \"~> 1.11\", optional: true} to your deps."`
- Failure-mode taxonomy for `doctor.streaming_smoke_ping` per D-08: HTTP 200 → ok; 401/403 → token-error fix; 429 → rate-limit fix; timeout/connection → reachability fix; other → status-referenced fix.
- Internal organization is "Claude's Discretion" §230 — single file `runtime_checks.ex` is fine; planner may extract a `Rindle.Ops.RuntimeChecks.Streaming` private module if cohesion improves (still `@moduledoc false`).

---

### `lib/mix/tasks/rindle.doctor.ex` (modified — add `--streaming` flag)

**Analog:** self — `lib/mix/tasks/rindle.doctor.ex` (full 73-line file)

**Task entry-point pattern** (lines 27-50):
```elixir
@impl Mix.Task
def run(args) do
  run_checks(args)
end

@doc false
def run_checks(args, opts \\ []) do
  shell = Keyword.get(opts, :shell, Mix.shell())
  mix_app = Keyword.get(opts, :mix_app, Mix.Project.config()[:app])
  exit_on_failure? = Keyword.get(opts, :exit_on_failure?, true)

  shell.info("Rindle: running environment checks...")

  report =
    args
    |> RuntimeChecks.run(Keyword.put(opts, :mix_app, mix_app))
    |> emit_report(shell)

  if exit_on_failure? and not report.success? do
    raise Mix.Error, message: "Rindle.Doctor failed: #{report.failed} check(s) failed"
  end

  report
end
```

**What changes vs. the analog (per D-07):**
- Inside `def run(args)`, parse args via `OptionParser.parse!/2` with `strict: [streaming: :boolean]` (the file currently passes `args` straight through; this is the new boundary).
- Plumb `streaming: streaming?` into the `opts` keyword passed to `run_checks/2`, then into `RuntimeChecks.run/2` (the existing `Keyword.put(opts, :mix_app, mix_app)` becomes `opts |> Keyword.put(:mix_app, mix_app) |> Keyword.put(:streaming, streaming?)`).
- Update `@moduledoc` "Usage" section to add `mix rindle.doctor --streaming` and "Exit codes" stays unchanged.
- `--streaming` is the third public CLI flag on the task; the failure-mode taxonomy from D-08 is the load-bearing detail (Specifics §3 in CONTEXT.md).

---

### `test/install_smoke/support/generated_app_helper.ex` (modified — add `:mux` profile mode)

**Analog:** self — multiple sites in `test/install_smoke/support/generated_app_helper.ex`

**`profile_enabled?/1` guard pattern** (lines 14-17):
```elixir
def profile_enabled?(profile_mode) when profile_mode in [:image, :video] do
  selected_profiles()
  |> Enum.member?(profile_mode)
end
```

**`prove_package_install!/1` guard pattern** (line 19):
```elixir
def prove_package_install!(profile_mode \\ :image) when profile_mode in [:image, :video] do
```

**`selected_profiles/0` env-var dispatch pattern** (lines 857-864):
```elixir
defp selected_profiles do
  case System.get_env("RINDLE_INSTALL_SMOKE_PROFILE", "all") do
    "all" -> [:image, :video]
    "image" -> [:image]
    "video" -> [:video]
    other -> raise "unsupported RINDLE_INSTALL_SMOKE_PROFILE: #{inspect(other)}"
  end
end
```

**`lifecycle_test_source/2` head-clause pattern** (lines 866-902 image, 905-end video):
```elixir
defp lifecycle_test_source(_app_module, :video) do
  """
      test "generated app proves the canonical AV upload, processing, playback-ready variants, and signed delivery path" do
        assert_install_smoke_marker!()
        assert :presigned_put in VideoProfile.storage_adapter().capabilities()

        fixture_path = Path.expand("../tmp/generated-app-video.webm", __DIR__)

        {:ok, session} = Rindle.initiate_upload(VideoProfile, filename: "generated-app-video.webm")
        ...
        assert Enum.map(variants, & &1.name) == ["poster", "web_720p"]
        ...
      end
  """
end
```

**`patch_test_config!/2` config-append pattern** (lines 342-382):
```elixir
defp patch_test_config!(root, app_name) do
  path = Path.join(root, "config/test.exs")

  updated =
    path
    |> File.read!()
    |> String.replace(...)
    |> Kernel.<>("""

    config :#{app_name}, Oban,
      ...

    config :#{app_name}, #{Macro.camelize(app_name)}.Repo,
      ...

    config :rindle, :repo, #{Macro.camelize(app_name)}.Repo
    """)

  File.write!(path, updated)
end
```

**`shared_env/1` env injector pattern** (lines 789-804):
```elixir
defp shared_env(db_name) do
  [
    {"MIX_ENV", "test"},
    {"RINDLE_INSTALL_SMOKE_DB", db_name},
    {"PGUSER", env_or_default("PGUSER", System.get_env("USER") || "postgres")},
    ...
    {"RINDLE_MINIO_REGION", env_or_default("RINDLE_MINIO_REGION", "us-east-1")}
  ]
  |> Enum.reject(fn {_key, value} -> is_nil(value) end)
end
```

**What changes vs. the analog (per D-14..D-17, D-21):**
- Extend the `profile_enabled?/1` guard from `[:image, :video]` to `[:image, :video, :mux]` (line 14).
- Extend the `prove_package_install!/1` guard the same way (line 19).
- Extend `selected_profiles/0` (lines 857-864) to add `"mux" -> [:mux]` and `"all" -> [:image, :video, :mux]`.
- Add a new `lifecycle_test_source(_app_module, :mux)` head-clause **after** the existing `:video` head (currently runs lines 905→1192). The new head reuses the `:video` lifecycle verbatim and appends one new assertion: cassette-driven `Rindle.Delivery.streaming_url/3` returns a Mux-signed HLS URL whose JWT decodes against `test/fixtures/mux/test_signing_public_key.pem` (D-15).
- Extend `patch_test_config!/2` (lines 342-382) — append a new conditional block when `profile_mode == :mux`:
  ```elixir
  if profile_mode == :mux and System.get_env("RINDLE_MUX_USE_REAL_API") != "1" do
    Kernel.<>("""

    config :rindle, Rindle.Streaming.Provider.Mux,
      http_client: Rindle.Streaming.Provider.Mux.ClientMock
    """)
  end
  ```
  (D-16, D-21). When `RINDLE_MUX_USE_REAL_API == "1"` (soak mode), omit the config block — defaults to the real `Rindle.Streaming.Provider.Mux.HTTP`.
- Extend `shared_env/1` (lines 789-804) — append the five fixture-value `RINDLE_MUX_*` env vars per D-17:
  ```elixir
  {"RINDLE_MUX_TOKEN_ID", "test-token-id"},
  {"RINDLE_MUX_TOKEN_SECRET", "test-token-secret"},
  {"RINDLE_MUX_SIGNING_KEY_ID", "test-signing-key-id"},
  {"RINDLE_MUX_SIGNING_PRIVATE_KEY", File.read!("test/fixtures/mux/test_signing_private_key.pem")},
  {"RINDLE_MUX_WEBHOOK_SECRETS", "whsec_test_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
  ```
- Mirror the MinIO staging pattern at lines 384-421 for copying `test/fixtures/mux/asset_create_201.json`, `asset_get_ready.json`, `webhook_video_asset_ready.json` into the generated app's `test/fixtures/mux/` (D-16).

---

### `test/install_smoke/generated_app_smoke_test.exs` (modified — add `Mux` test module)

**Analog:** `Rindle.InstallSmoke.GeneratedAppSmokeImageTest` / `…VideoTest` blocks (lines 36-95)

**Test module template pattern** (lines 64-95 — `VideoTest`):
```elixir
if GeneratedAppHelper.profile_enabled?(:video) do
  defmodule Rindle.InstallSmoke.GeneratedAppSmokeVideoTest do
    use ExUnit.Case, async: false
    use Rindle.InstallSmoke.GeneratedAppSmokeAssertions

    setup_all do
      report = GeneratedAppHelper.prove_package_install!(:video)
      on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
      {:ok, report: report}
    end

    test "generated Phoenix app installs the AV-enabled profile from the configured package source without repo-local fallback",
         %{report: report} do
      assert_install_source!(report)
    end

    test "generated Phoenix app proves the canonical AV path with web_720p, poster, and signed delivery",
         %{report: report} do
      assert report.host_migration_ran?
      assert report.migration_resolution == :application_app_dir
      assert String.ends_with?(report.rindle_migration_path, "/priv/repo/migrations")
      refute String.contains?(report.rindle_migration_path, "deps/rindle")
      assert report.smoke_exit_code == 0
      assert report.lifecycle_proved?
      assert report.av_ready_variants == ["poster", "web_720p"]
      assert is_binary(report.av_playback_storage_key)
      assert String.contains?(report.av_playback_storage_key, "web_720p")
      assert is_binary(report.av_delivery_path)
      assert String.contains?(report.av_delivery_path, report.av_playback_storage_key)
    end
  end
end
```

**Also extend the `profile_mode in [...]` set in `assert_install_source!/1` (lines 12-30):**
```elixir
assert report.profile_mode in [:image, :video, :upgrade]
```

**What changes vs. the analog (per D-15, D-26):**
- New module name: `Rindle.InstallSmoke.GeneratedAppSmokeMuxTest`.
- Gate: `if GeneratedAppHelper.profile_enabled?(:mux) do`.
- `setup_all` calls `GeneratedAppHelper.prove_package_install!(:mux)`.
- First test mirrors `VideoTest`'s install-source assertion verbatim (cassette-mode default has zero new env requirements beyond `shared_env/1`).
- Second test mirrors the AV-canonical assertions (`av_ready_variants == ["poster", "web_720p"]` is byte-identical per D-04) AND adds two new assertions:
  - `assert is_binary(report.mux_signed_hls_url)`
  - `assert {:ok, _claims} = JOSE.JWT.peek_payload(report.mux_signed_hls_url) |> verify_with_test_public_key()` (the JWT-decode assertion per D-15).
- The `report` map structure must be extended in `generated_app_helper.ex`'s `prove_package_install!/1` to surface `:mux_signed_hls_url` (similar to how `:av_playback_storage_key` is surfaced today).
- Extend `assert_install_source!/1`'s `profile_mode in [:image, :video, :upgrade]` to `[:image, :video, :upgrade, :mux]`.

---

### `scripts/install_smoke.sh` (modified — extend case dispatch)

**Analog:** self — `scripts/install_smoke.sh` line 19

**Profile validation pattern** (lines 19-25):
```bash
case "$PROFILE" in
  all|image|video) ;;
  *)
    echo "unsupported install smoke profile: $PROFILE" >&2
    exit 1
    ;;
esac
```

**What changes vs. the analog (per D-18):**
- One-line extension: `all|image|video) ;;` → `all|image|video|mux) ;;`. No other changes — the `mix test test/install_smoke/generated_app_smoke_test.exs --include minio` invocation at line 43 is profile-agnostic (the new `Mux` test module's `if profile_enabled?(:mux)` gate handles dispatch internally via `RINDLE_INSTALL_SMOKE_PROFILE=mux`).

---

### `.github/workflows/ci.yml` (modified — `labeled` trigger + cassette step + soak job + doc-parity extension)

**Analog:** self — `.github/workflows/ci.yml`

**`pull_request` trigger pattern** (lines 3-7):
```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```

**`package-consumer` cassette-step append-point** (lines 376-377):
```yaml
- name: Run built-artifact AV package-consumer proof against MinIO
  run: bash scripts/install_smoke.sh video
```

**`adopter` job structural template** (lines 393-490):
```yaml
adopter:
  name: Adopter
  runs-on: ubuntu-latest
  needs: [quality, integration, contract]
  env:
    MIX_ENV: test
    PGUSER: postgres
    PGPASSWORD: postgres
    PGHOST: localhost
    PGPORT: "5432"
    RINDLE_MINIO_URL: http://localhost:9000
    RINDLE_MINIO_ACCESS_KEY: minioadmin
    RINDLE_MINIO_SECRET_KEY: minioadmin
    RINDLE_MINIO_BUCKET: rindle-test
    RINDLE_MINIO_REGION: us-east-1

  services:
    postgres:
      image: postgres:16-alpine
      ports:
        - 5432:5432
      env:
        POSTGRES_USER: postgres
        POSTGRES_PASSWORD: postgres
        POSTGRES_DB: rindle_test
      options: >-
        --health-cmd pg_isready
        --health-interval 10s
        --health-timeout 5s
        --health-retries 5

  steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Set up Elixir
      uses: erlef/setup-beam@v1
      with:
        elixir-version: "1.17"
        otp-version: "27"

    - name: Install libvips
      run: sudo apt-get install -y libvips-dev
    ...
    - name: Install dependencies
      run: mix deps.get
```

**Doc-parity guard pattern** (lines 518-545):
```yaml
- name: Verify AV onboarding docs stay on the public facade path
  run: |
    set -euo pipefail
    ...
    for DOC in README.md guides/getting_started.md; do
      ...
      for REQUIRED in \
        "mix rindle.doctor" \
        "Rindle.Profile.Presets.Web" \
        "Rindle.initiate_upload" \
        "Rindle.verify_completion" \
        "Rindle.attach" \
        "Rindle.url"
      do
        if ! search_fixed "$REQUIRED" "$DOC"; then
          echo "FAIL: $DOC is missing required AV onboarding reference: $REQUIRED"
          exit 1
        fi
      done

      if search_regex "Broker\\.initiate_session|Broker\\.verify_completion|Rindle\\.Delivery\\.url" "$DOC"; then
        echo "FAIL: $DOC still references stale non-facade onboarding calls"
        exit 1
      fi
    done
```

**What changes vs. the analog (per D-18, D-19, D-20, D-22, D-27):**

1. **Trigger** (lines 3-7): extend `pull_request:` block to add `types: [opened, synchronize, reopened, labeled]` (D-19; default types per external research Topic 1 are `[opened, synchronize, reopened]` and `labeled` MUST be explicit).

2. **`mux-enabled` cassette step** (insert after line 377): one new step inside the existing `package-consumer` job. Reuses MinIO + Postgres services already up:
   ```yaml
   - name: Run built-artifact Mux-enabled package-consumer proof (cassette mode)
     run: bash scripts/install_smoke.sh mux
   ```

3. **`mux-soak` sibling job** (D-20, structural mirror of `adopter` job 393-490): `name: Mux Soak (real API)`, `runs-on: ubuntu-latest`, `needs: quality`, label gate `if: contains(github.event.pull_request.labels.*.name, 'streaming')`, env block sets `RINDLE_MUX_USE_REAL_API: "1"` plus the five `${{ secrets.RINDLE_MUX_* }}` vars (D-24). Uses `pull_request` (NOT `pull_request_target`) so fork PRs labeled `streaming` fire the lane but secrets resolve to empty strings → fail closed (Specifics §2). Postgres service identical to `adopter` (D-20). Steps follow the `adopter` template up through `mix deps.get`, then `bash scripts/install_smoke.sh mux`, finally an `if: always()` step running `bash scripts/mux_soak_cleanup.sh` for D-22 belt-and-suspenders cleanup.

4. **Doc-parity guard extension** (lines 524-530): append one new line to the `for REQUIRED in \` list:
   ```yaml
   "Rindle.Profile.Presets.MuxWeb" \
   ```
   The negative regex check at line 538 stays unchanged — `MuxWeb` does NOT introduce new forbidden patterns (D-27).

---

### `README.md` (modified — append "Streaming with Mux (optional)" subsection)

**Analog:** existing AV Quickstart heading at `README.md:101` ("## First Run: AV Quickstart")

**What changes vs. the analog (per D-25, D-26, D-28):**
- New `## Streaming with Mux (optional)` heading inserted **after** the canonical AV Quickstart and after "After First Run: Querying Attachments and Variants" (line 172) — i.e., before "Next Reads" (line 242).
- ≤15 lines total. Three elements only:
  1. One sentence: "For HLS streaming via signed URLs, opt your profile into a streaming provider."
  2. One Elixir code snippet (`use Rindle.Profile.Presets.MuxWeb, ...`).
  3. One sentence linking to `[streaming_providers.md](streaming_providers.md)`.
- D-28 invariant: the canonical AV Quickstart section (lines 101-171) stays byte-identical to v1.5.

---

### `guides/getting_started.md` (modified — append "Streaming with Mux (optional)" subsection)

**Analog:** existing "## 9. Bang Variants" at line 310 / canonical AV path Sections 1-9; new content lands after Section 10 area (currently ends at "Next Reads" line 364).

**What changes vs. the analog (per D-25, D-26, D-28):**
- New `### Streaming with Mux (optional)` heading inserted **after** Section 10 (or appended as a new top-level Section 11 if numbering preserved) and **before** "Next Reads" (line 364).
- Content elements identical to README per D-26 (one sentence + one snippet + one link).
- D-28 invariant: Sections 1-9/10 stay byte-identical.

---

### `CHANGELOG.md` (modified — v0.2.0 entry per D-33)

**Analog:** existing `## [Unreleased]` block at top of `CHANGELOG.md`

**Structure pattern** (lines 5-15 — current `## [Unreleased] ### Added` shape):
```markdown
## [Unreleased]

### Added

- `@doc` annotations on every public `@callback` ...
- Behaviour-level named result types ...
```

**What changes vs. the analog (per D-33, D-34):**
- Append (do NOT rewrite v1.4-v1.5 entries) one new bullet to the `## [Unreleased] ### Added` block, capturing the v1.6 streaming-onboarding surface in one entry:
  > Public adopter onboarding for streaming providers — `Rindle.Profile.Presets.MuxWeb`, `mix rindle.doctor --streaming`, `guides/streaming_providers.md`, generated-app `mux-enabled` package-consumer lane (cassette default + label-gated `mux-soak` lane against real Mux).
- The release-please bot will re-tag this `[Unreleased]` block as `[0.2.0]` at v1.6 close (per `memory/project_v0_2_0_release_plan.md`).

---

## Shared Patterns

### Optional-dep / Code.ensure_loaded? guard
**Source:** `lib/rindle/workers/mux_sync_coordinator.ex` lines 1-3 + Phase 34 D-01
**Apply to:** `lib/rindle/profile/presets/mux_web.ex`, the four new `defp check_streaming_*` clauses in `runtime_checks.ex`
```elixir
# Compiled only when {:mux, "~> 3.2"} is loaded.
# Adopters who do not configure streaming pay zero transitive cost.
if Code.ensure_loaded?(Mux.Video.Assets) do
  defmodule Rindle.Workers.MuxSyncCoordinator do
    ...
  end
end
```
**Note:** `MuxWeb` itself does NOT need a `Code.ensure_loaded?` guard at the module level — the DSL stores only the provider-module atom; runtime resolution happens via `Code.ensure_loaded?` in `Rindle.Delivery.streaming_url/3` (Phase 33). The doctor checks DO need the guard around the smoke-ping call only.

### Single-source-of-truth adopter-wiring snippets
**Source:** `lib/rindle/delivery/webhook_plug.ex` lines 7-23 (Steps 1-3) + `lib/rindle/workers/mux_sync_coordinator.ex` lines 13-24 (Cron Configuration Example)
**Apply to:** `guides/streaming_providers.md` Steps 5 and 6 only
```elixir
# Step 1 — install the body reader globally in `endpoint.ex` (BEFORE `Plug.Parsers`):

    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      body_reader: {Rindle.Delivery.WebhookBodyReader, :read_body, []},
      json_decoder: Jason

# Step 2 — mount the Plug in `router.ex`, one `forward` per provider:

    forward "/webhooks/rindle/mux", Rindle.Delivery.WebhookPlug,
      provider: Rindle.Streaming.Provider.Mux,
      secrets: {:application, :rindle, [Rindle.Streaming.Provider.Mux, :webhook_secrets]}

# Step 3 — set `RINDLE_MUX_WEBHOOK_SECRETS` (comma-separated) in your runtime
# config, and configure your Mux dashboard webhook to POST to
# `https://yourapp.example.com/webhooks/rindle/mux`.
```
**Note:** Per D-13, the guide must inline-copy these blocks verbatim AND include `<!-- source: lib/rindle/delivery/webhook_plug.ex @moduledoc -->` HTML comments so a future reader can find the canonical. The moduledoc is the single source of truth — when the wiring shape evolves, only one place updates.

### Profile-discovery gating (vacuous-OK pattern)
**Source:** `lib/rindle/ops/runtime_checks.ex` lines 220-251 (`check_local_playback`)
**Apply to:** all four new `defp check_streaming_*` clauses
```elixir
cond do
  streaming_profiles == [] ->
    ok_result(
      "doctor.streaming_<id>",
      :streaming,
      "No streaming-enabled profiles discovered.",
      @streaming_<id>_fix
    )

  # ... actual check logic ...
end
```

### `ok_result` / `error_result` helpers
**Source:** `lib/rindle/ops/runtime_checks.ex` lines 476-482
**Apply to:** all four new `defp check_streaming_*` clauses
```elixir
defp ok_result(id, component, summary, fix) do
  %{id: id, status: :ok, component: component, summary: summary, fix: fix}
end

defp error_result(id, component, summary, fix) do
  %{id: id, status: :error, component: component, summary: summary, fix: fix}
end
```

### Telemetry redaction (security invariant 14)
**Source:** Phase 35 D-39 + `Rindle.Domain.MediaProviderAsset.redact_id/1`
**Apply to:** `scripts/mux_soak_cleanup.sh` log output (last-4-char redaction)
**Note:** Any `provider_asset_id` that appears in cleanup-script logs MUST be redacted to last-4 chars. If the script shells out to Elixir via `mix run --no-start -e`, call `Rindle.Domain.MediaProviderAsset.redact_id/1`. If pure bash, trim with `${id: -4}`.

### Cassette-mode default + secret-gated soak mode
**Source:** v1.2 protected-publish lane precedent (CONTEXT.md §362)
**Apply to:** `mux-enabled` step (cassette, unconditional) + `mux-soak` job (label-gated, real-API)
**Pattern:** Same conceptual split — cassette runs every PR, soak runs only when explicitly requested. `RINDLE_MUX_USE_REAL_API=1` is the env-level discriminator inside the test helper; the GitHub Actions `if: contains(... 'streaming')` is the workflow-level discriminator.

### Doc-parity guard append-only invariant
**Source:** `.github/workflows/ci.yml:518-545`
**Apply to:** the doc-parity extension (D-27)
**Pattern:** ADD to the `for REQUIRED in \` list; never remove existing entries. D-28 invariant — image and AV onboarding strings stay enforced.

## No Analog Found

No file in this phase lacks a close in-repo analog. The single shape-only match is:

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `scripts/mux_soak_cleanup.sh` | shell script (CI cleanup) | API-side-effect | No prior shell script in `scripts/` invokes a vendor SDK to delete remote resources. `scripts/install_smoke.sh` is the closest precedent for the bash preamble + `mix run --no-start -e` invocation idiom; the cleanup body itself (Mux SDK list+delete loop) is novel. Planner picks bash-shells-out-to-Elixir vs standalone Elixir per "Claude's Discretion" §226. |

## Metadata

**Analog search scope:** `lib/rindle/profile/presets/`, `lib/rindle/ops/`, `lib/mix/tasks/`, `lib/rindle/delivery/`, `lib/rindle/workers/`, `test/install_smoke/`, `test/rindle/profile/`, `test/rindle/ops/`, `test/fixtures/mux/`, `scripts/`, `.github/workflows/`, `guides/`, `mix.exs`, `README.md`, `CHANGELOG.md`.
**Files scanned:** ~25 (16 analog reads + 9 supporting verifications).
**Pattern extraction date:** 2026-05-07
