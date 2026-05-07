---
phase: 36-public-dx-onboarding-ci-proof
reviewed: 2026-05-07T00:00:00Z
depth: standard
files_reviewed: 19
files_reviewed_list:
  - .github/workflows/ci.yml
  - CHANGELOG.md
  - README.md
  - guides/getting_started.md
  - guides/streaming_providers.md
  - lib/mix/tasks/rindle.doctor.ex
  - lib/rindle/capability.ex
  - lib/rindle/ops/runtime_checks.ex
  - lib/rindle/profile/presets/mux_web.ex
  - mix.exs
  - scripts/install_smoke.sh
  - scripts/mux_soak_cleanup.sh
  - test/fixtures/mux/test_signing_public_key.pem
  - test/install_smoke/generated_app_smoke_test.exs
  - test/install_smoke/support/generated_app_helper.ex
  - test/rindle/doctor_test.exs
  - test/rindle/ops/runtime_checks_streaming_test.exs
  - test/rindle/ops/runtime_checks_test.exs
  - test/rindle/profile/presets/mux_web_test.exs
findings:
  blocker: 3
  warning: 9
  total: 12
status: issues_found
---

# Phase 36: Code Review Report

**Reviewed:** 2026-05-07
**Depth:** standard
**Files Reviewed:** 19
**Status:** issues_found

## Summary

Phase 36 introduces the Mux streaming provider onboarding surface — `Rindle.Profile.Presets.MuxWeb`, four streaming-aware `mix rindle.doctor` checks, the `guides/streaming_providers.md` adopter guide, the cassette + soak generated-app smoke lanes, and a belt-and-suspenders Mux soak cleanup script.

The implementation is largely coherent with the plans, but adversarial review surfaces three BLOCKER defects and nine WARNINGs:

1. The "layer 3" Mux soak cleanup is non-functional because no code path tags created Mux assets with the metadata the cleanup filter relies on. Combined with a layer-1 race window where assets can be created on Mux before being recorded in ETS, the soak lane has a real asset-leak risk despite the documented three-layer safety net.
2. The streaming guide pins `{:rindle, "~> 0.2.0"}` but the project version is still `0.1.4`. If HexDocs builds against 0.1.4 (e.g., a docs preview, a manual `mix docs`, or any publish that lands before the `release-please` 0.2.0 bump), adopters following the guide get an unresolvable dep.
3. `shared_env/1` unconditionally reads `test/fixtures/mux/test_signing_private_key.pem` even when the smoke profile is `:image` or `:video`, coupling non-Mux runs to a Mux-only fixture.

The smaller findings cover doctor/queue drift versus the guide, the unused `_app_name` parameter, missing direct test coverage of `Rindle.Capability.configured_streaming_profiles/1`, soft `OptionParser` handling of unknown flags, broken raw-markdown links, and a few style/quality concerns.

## Blocker Issues

### CR-01: Mux soak cleanup script filters by metadata that is never written

**File:** `scripts/mux_soak_cleanup.sh:69-85`, `lib/rindle/streaming/provider/mux.ex:200-207`, `test/install_smoke/support/generated_app_helper.ex:1271-1308`
**Issue:** The "belt-and-suspenders layer 3" cleanup script (CI workflow `if: always()` step) lists every asset in the test Mux account and filters down to ones tagged `meta.rindle_soak == "true"`:

```bash
soak_assets =
  Enum.filter(assets, fn asset ->
    meta = Map.get(asset, "meta") || Map.get(asset, :meta) || %{}
    Map.get(meta, "rindle_soak") == "true" or Map.get(meta, :rindle_soak) == "true"
  end)
```

But the only Mux asset-creation code path (`Rindle.Streaming.Provider.Mux.build_create_params/2`) builds the request body as:

```elixir
%{
  "inputs" => [%{"url" => source_url}],
  "playback_policies" => [Atom.to_string(policy_atom)],
  "mp4_support" => "standard",
  "max_resolution_tier" => "1080p"
}
```

There is no `meta`, `passthrough`, or any other field that would carry `rindle_soak: "true"`. A repo-wide grep for `rindle_soak` finds the string only in the cleanup script itself — never on the producing side.

The result: the cleanup script always reports "no soak assets found" and exits 0 even when soak assets are leaked. Combined with CR-02 (layer-1 ETS race), there is no functional safety net. The Mux free tier caps stored on-demand assets at 10, so a few leaks will brick the soak lane.

**Fix:** Tag every soak-mode asset on creation, then filter on that tag. Two reasonable shapes:

(a) Pass `passthrough` from the test through `Rindle.Streaming.Provider.Mux.create_asset/3` (extend `opts` and `build_create_params/2` to honor a `:passthrough` key, soak test sets it to `"rindle_soak"`, cleanup filters by `passthrough == "rindle_soak"`):

```elixir
defp build_create_params(source_url, policy_atom, opts) do
  base = %{
    "inputs" => [%{"url" => source_url}],
    "playback_policies" => [Atom.to_string(policy_atom)],
    "mp4_support" => "standard",
    "max_resolution_tier" => "1080p"
  }

  case Keyword.get(opts, :passthrough) do
    nil -> base
    passthrough when is_binary(passthrough) -> Map.put(base, "passthrough", passthrough)
  end
end
```

(b) Have the soak install-smoke test stamp `meta: %{"rindle_soak" => "true"}` via the same plumbing, and update the cleanup script to filter on the API field that Mux actually returns.

Either way, the cleanup script's filter and the producer's request body must agree on a single tagging convention with at least one regression test that confirms the tag survives a real `Mux.Video.Assets.create` call.

---

### CR-02: Soak `try/after` records `provider_asset_id` AFTER assertions, leaving a leak window

**File:** `test/install_smoke/support/generated_app_helper.ex:1189-1310`
**Issue:** The Mux lifecycle test wraps the assertions in `try/after` (lines 1189 and 1287). The `provider_asset_id` is inserted into ETS at lines 1271-1286, **inside** the try block, **after** the upload + variant processing has already triggered the `MuxIngestVariant` worker and created an asset on Mux's side.

If any assertion between lines 1190-1270 fails (e.g., the streaming-URL regex on line 1247, the JWT verify on line 1257, or the variant-processing assertion on line 1232), control transfers to the `after` block, which looks up an ETS row that was never written. The `case :ets.lookup(...)` falls through to `_ -> :ok` and the asset stays on Mux.

In effect, the layer-1 cleanup only reaps assets when the test passes — but the test passing is exactly when layers 2/3 are also healthy. The layer that exists for failure cases is the one that fails on failure.

**Fix:** Record the `provider_asset_id` in ETS as soon as it's available — i.e., immediately after `perform_job(ProcessVariant, ...)` for `web_720p` returns, well before the streaming-URL assertions. A safer shape is to read the row right after the variant job finishes, not at the end of the test:

```elixir
# Right after the variant perform_job loop:
if mode == :soak do
  provider_row =
    Repo.one(
      from p in Rindle.Domain.MediaProviderAsset,
        where: p.asset_id == ^asset.id,
        limit: 1
    )

  if provider_row do
    :ets.insert(
      provider_asset_id_table,
      {provider_asset_id_ref, provider_row.provider_asset_id}
    )
  end
end

# THEN do the streaming-URL assertions; if they fail, the after-block has the id.
```

Pair this with CR-01 so layer-3 actually catches anything layer-1 misses (e.g., a process crash before the ETS insert).

---

### CR-03: `shared_env/1` always reads Mux private-key fixture, coupling `:image`/`:video` runs to Mux fixtures

**File:** `test/install_smoke/support/generated_app_helper.ex:912-936`
**Issue:** `shared_env/1` is invoked from both `prove_package_install!/1` and `prove_upgrade_install!/0` regardless of profile mode (`:image`, `:video`, `:mux`). Inside it, lines 916-918:

```elixir
private_key_pem =
  System.get_env("RINDLE_MUX_SIGNING_PRIVATE_KEY") ||
    File.read!("test/fixtures/mux/test_signing_private_key.pem")
```

When `RINDLE_MUX_SIGNING_PRIVATE_KEY` is unset (the normal case for `:image` and `:video` runs), `File.read!/1` is forced and will raise `File.Error` if the fixture is missing or relocated. This means a contributor cannot run `bash scripts/install_smoke.sh image` against a checkout that lacks the Mux fixtures (e.g., a leaner test bundle, a future split of the fixture tree, or a partial submodule fetch).

Worse, the staged-fixture step (`stage_mux_fixtures!/1`) silently skips missing fixtures via `if File.exists?(src) do File.cp!(src, ...)`, so the failure mode for a missing private key is "shared_env crashes before staging" — the diagnosing developer sees a low-level `File.read!` stack trace, not a clear "the Mux profile requires X fixture."

**Fix:** Read the private-key PEM only for the `:mux` profile mode. Push the read into `mux_env/0` (or a `mux_env(profile_mode)` predicate) and let `:image`/`:video` runs skip it entirely:

```elixir
defp shared_env(db_name, profile_mode) do
  base_env = [...]

  if profile_mode == :mux do
    mux_env = build_mux_env()
    base_env ++ mux_env
  else
    base_env
  end
  |> Enum.reject(fn {_k, v} -> is_nil(v) end)
end

defp build_mux_env do
  private_key_pem =
    System.get_env("RINDLE_MUX_SIGNING_PRIVATE_KEY") ||
      File.read!("test/fixtures/mux/test_signing_private_key.pem")
  # ...
end
```

While here, also make `stage_mux_fixtures!/1` `File.cp!` unconditionally and raise loudly if a fixture is missing — silent skipping defers the failure to the generated-app test where it's much harder to diagnose.

---

## Warnings

### WR-01: Streaming guide pins `{:rindle, "~> 0.2.0"}` while project is at `0.1.4`

**File:** `guides/streaming_providers.md:53`, `mix.exs:4`
**Issue:** The guide tells adopters to add `{:rindle, "~> 0.2.0"}`, but `mix.exs` still declares `@version "0.1.4"`. If `mix docs` runs before the release-please 0.2.0 bump (e.g., a manual maintainer preview, an out-of-band docs publish, or a CI artifact uploaded before the version bump lands), the published guide will tell adopters to use a non-existent Hex version. README.md and getting_started.md both use `~> 0.1`, which works for 0.1.4 today.

**Fix:** Either (a) bump `mix.exs` to `0.2.0-dev` (or similar) at the start of the streaming work and let release-please tag the final `0.2.0`, or (b) hold the streaming-guide version pin to `~> 0.1` until 0.2.0 actually ships, then update in the same PR that bumps the version. Add a parity check to `scripts/release_preflight.sh` that fails when any guide pins a version higher than `mix.exs`.

---

### WR-02: `mix.exs` `:extras` list omits `guides/upgrading.md` even though README/getting_started reference it

**File:** `mix.exs:117-129`, `README.md:259-260`, `guides/getting_started.md:19`
**Issue:** README.md and getting_started.md both link to `guides/upgrading.md` for the existing-adopter upgrade runbook. `mix.exs` `extras:` lists every other guide (core_concepts, storage_capabilities, profiles, secure_delivery, streaming_providers, background_processing, operations, release_publish, troubleshooting) but does NOT include `upgrading.md`. As a result, HexDocs will not render the upgrade guide and the `[guides/upgrading.md](upgrading.md)` link in the rendered README/getting_started page will 404 on hexdocs.pm.

**Fix:** Add `"guides/upgrading.md"` to the `extras` list in `mix.exs`. Since this is a docs-only change, add a line near `guides/getting_started.md`:

```elixir
extras: [
  "README.md",
  "RUNNING.md",
  "guides/getting_started.md",
  "guides/upgrading.md",
  ...
]
```

---

### WR-03: Doctor does not require `rindle_provider` queue when streaming-enabled profile is present

**File:** `lib/rindle/ops/runtime_checks.ex:434-443`, `guides/streaming_providers.md:185-194`
**Issue:** The streaming guide instructs adopters to declare `queues: [rindle_provider: 4]` (and the cron coordinator `MuxSyncCoordinator` enqueues itself onto `:rindle_provider`). But `RuntimeChecks.required_queues/1` only adds `:rindle_media` (when AV variants exist) — never `:rindle_provider`, even when streaming-enabled profiles are present. Adopters who follow the guide but mistype the queue name get `mix rindle.doctor` saying "OK" while their Mux ingestion silently fails.

**Fix:** Extend `required_queues/1` to add `:rindle_provider` when `Rindle.Capability.configured_streaming_profiles(profiles) != []`:

```elixir
defp required_queues(profiles) do
  base =
    cond do
      Enum.any?(profiles, &profile_has_av_variants?/1) -> @base_queues ++ [:rindle_media]
      true -> @base_queues
    end

  if Rindle.Capability.configured_streaming_profiles(profiles) == [] do
    Enum.sort(base)
  else
    Enum.sort(base ++ [:rindle_provider])
  end
end
```

Add a regression test in `runtime_checks_streaming_test.exs` that asserts the `doctor.oban_required_queues` failure mode when `:rindle_provider` is missing.

---

### WR-04: Generated `:mux` lane never adds `rindle_provider` queue, hiding the same gap end-to-end

**File:** `test/install_smoke/support/generated_app_helper.ex:393-411`, `test/install_smoke/support/generated_app_helper.ex:504-513`
**Issue:** Both the `config/test.exs` and `config/runtime.exs` Oban blocks the helper writes for the `:mux` profile mode include only the AV-progressive queues (`rindle_media`, `rindle_promote`, `rindle_process`, `rindle_purge`, `rindle_maintenance`). The generated app's Mux lane never declares `rindle_provider`. The cassette test passes only because it calls `Oban.Testing.perform_job/2` directly (which bypasses the queue dispatcher), masking the missing queue. A real adopter copying this generated config to production would hit the gap WR-03 already describes.

**Fix:** When `profile_mode == :mux`, append `rindle_provider: 1` to the queue lists in both `patch_test_config!/3` and `patch_runtime_config!/3`. Better, derive both blocks from a single `oban_queues_for(profile_mode)` helper to prevent future drift between test/runtime.

---

### WR-05: `Mox.verify_on_exit!(self())` and `Mox.set_mox_from_context(%{async: false})` are non-idiomatic and rely on internal arg-discarding

**File:** `test/install_smoke/support/generated_app_helper.ex:1141-1148`
**Issue:** The generated `:mux` test calls:

```elixir
setup do
  if @cassette_mode? do
    Mox.set_mox_from_context(%{async: false})
    Mox.verify_on_exit!(self())
  end

  :ok
end
```

`Mox.verify_on_exit!/1`'s function head is `def verify_on_exit!(_context \\ %{})` — the argument is bound to `_context` and discarded. Passing `self()` works only by accident (the pid is tossed). Future Mox versions could break this when they start doing something with the context. `Mox.set_mox_from_context/1` pattern-matches `%{async: true}` to private mode and falls through to global for everything else; passing `%{async: false}` works but the documented `setup :set_mox_from_context` form (which receives the real ExUnit context) is safer.

**Fix:** Use the documented setup-callback form:

```elixir
if @cassette_mode? do
  setup :set_mox_from_context
  setup :verify_on_exit!
end
```

If a top-level `setup` block must remain, drop the bogus `self()` arg and use the no-arg call:

```elixir
Mox.set_mox_from_context(%{})
Mox.verify_on_exit!()
```

---

### WR-06: `Mix.Tasks.Rindle.Doctor.run/1` silently discards unknown CLI flags

**File:** `lib/mix/tasks/rindle.doctor.ex:35-42`
**Issue:** The task uses `OptionParser.parse(args, strict: [streaming: :boolean])` and then discards the third element with `_invalid`. A user mistyping `--streming` (or any future flag) will see no error and the doctor will quietly run without the requested flag. Mix tasks generally fail on unknown flags so the user notices the typo immediately.

**Fix:** Inspect `_invalid` and emit a `Mix.raise` for any unknown flags:

```elixir
{parsed, rest, invalid} =
  OptionParser.parse(args, strict: [streaming: :boolean])

case invalid do
  [] -> :ok
  invalid_flags ->
    Mix.raise(
      "Unknown options: " <>
        Enum.map_join(invalid_flags, ", ", fn {flag, _} -> flag end)
    )
end
```

---

### WR-07: `Rindle.Capability.configured_streaming_profiles/1` is public but lacks a direct test

**File:** `lib/rindle/capability.ex:90-104`, `test/rindle/ops/runtime_checks_streaming_test.exs`
**Issue:** Phase 36 promotes `configured_streaming_profiles/1` to a documented public function with `@spec` and `@doc` (line 98), but it has no unit test. Coverage is transitive through `RuntimeChecks.run/2`, which also exercises `streaming_config_for/1`, `streaming_provider/1`, and the various profile-discovery paths. A test that walks through (a) profile with no `:streaming` key, (b) profile with map-shape `:streaming`, (c) profile with keyword-shape `:streaming`, (d) profile whose `delivery_policy/0` raises, would lock the contract.

**Fix:** Add a `Rindle.CapabilityTest` (or extend an existing one) with explicit cases for each input shape. The map vs keyword-list dual handling at lines 121-126 is exactly the kind of branch that should not silently regress.

---

### WR-08: Streaming guide markdown links to `*.html` paths render broken on GitHub raw view

**File:** `guides/streaming_providers.md:29`
**Issue:** Line 29 links to `[Secure Delivery](secure_delivery.html)`. HexDocs resolves this correctly when the page is rendered, but a reader viewing the file on GitHub (the CHANGELOG's primary surface, the README's secondary surface, anyone landing via a pre-publish PR review) sees a 404. Other guides in the repo use the same pattern (e.g., `core_concepts.md`, `profiles.md`), so this is pre-existing — but the new file inherits the bug.

**Fix:** Use the `.md` extension and let ExDoc rewrite to `.html` at build time, the same way `getting_started.md` links to `streaming_providers.md`:

```markdown
streaming provider, see [Secure Delivery](secure_delivery.md).
```

ExDoc's link rewriter handles `.md` → `.html` automatically. This makes the file readable both on GitHub and on hexdocs.pm.

---

### WR-09: `mux_config_block/1` accepts an unused parameter

**File:** `test/install_smoke/support/generated_app_helper.ex:421, 429`
**Issue:** `mux_config_block(_app_name)` is called with `app_name` but discards it via the `_` prefix. Either the parameter should be removed, or the function should actually use it — silently ignored parameters are a code smell that obscures intent.

**Fix:** Remove the parameter:

```elixir
defp mux_config_block do
  if System.get_env("RINDLE_MUX_USE_REAL_API") == "1" do
    # ... soak block ...
  else
    # ... cassette block ...
  end
end

# call site:
base_updated <> mux_config_block()
```

---

### WR-10: `verify_signing_key_pem/1` rescue clause swallows the original exception, hiding root-cause for `--raise` failures

**File:** `lib/rindle/ops/runtime_checks.ex:594-620`
**Issue:** When `JOSE.JWK.from_pem/1` raises (e.g., a future jose version changes behavior), the `rescue _ ->` clause produces a generic "RINDLE_MUX_SIGNING_PRIVATE_KEY parse raised (malformed PEM)." summary. The exception's class and message are lost, making the `mix doctor --raise` output unhelpful for a maintainer trying to diagnose why a previously-valid PEM started failing.

**Fix:** Capture and surface (a redacted form of) the exception:

```elixir
rescue
  exception ->
    error_result(
      "doctor.streaming_signing_key",
      :streaming,
      "RINDLE_MUX_SIGNING_PRIVATE_KEY parse raised: " <>
        inspect(exception.__struct__) <>
        " (malformed PEM).",
      @streaming_signing_key_fix
    )
end
```

The exception struct name is non-sensitive (it's not the PEM body) and unlocks "is it `MatchError` or `FunctionClauseError`?" diagnosis without echoing key material.

---

## Notes

- The doctor `streaming?` flag plumbing through `Mix.Tasks.Rindle.Doctor → RuntimeChecks.run/2 → check_streaming_smoke_ping/3` is correct.
- The 5-second smoke-ping ceiling using `Task.async + Task.yield + Task.shutdown(:brutal_kill)` is the right OTP idiom (matches the file's own RESEARCH note).
- The locked `:streaming` block in `Rindle.Profile.Presets.MuxWeb.__using__/1` is correctly protected against adopter overrides via the `Keyword.merge(adopter_delivery, locked_streaming)` ordering — keys in the second arg win, so adopter delivery keys other than `:streaming` survive.
- `Rindle.Capability.signed_playback_configured?/0` correctly avoids echoing config values back (security invariant 14) — the function returns booleans only.
- The CI parity gate in `.github/workflows/ci.yml:526-553` is well-constructed and the negative regex `Rindle\.Delivery\.url` correctly does not match `Rindle.Delivery.streaming_url` (no word boundary issue).

---

_Reviewed: 2026-05-07_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
