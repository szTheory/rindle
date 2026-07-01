# Upgrading Existing Adopters

Use this guide with [CHANGELOG.md](../CHANGELOG.md): the changelog names release
history, and this guide explains how existing apps should move safely. Fresh
installs should stay on [README](readme.html) and
[Getting Started](getting_started.html).

CI validates the documented upgrade paths from generated Phoenix apps before
each Hex publish. Keep future entries newest-first, action-oriented, and focused
on adopter work rather than duplicating the changelog.

## Version index

- [Unreleased / Next](#unreleased--next)
- [0.1.3 and earlier -> current AV-aware runtime](#013-and-earlier---current-av-aware-runtime)

## Unreleased / Next

### Applies to

Future releases that list adopter action items in [CHANGELOG.md](../CHANGELOG.md).

### What changed

No upgrade notes for this version yet.

### Upgrade steps

There are no adopter action items for this version. Review `CHANGELOG.md` before
upgrading, then return here when a release lists migration or behavior changes.

### Verification

Use the release's documented verification steps once an upgrade note exists.

## 0.1.3 and earlier -> current AV-aware runtime

### Applies to

Apps that already ship Rindle from the pre-0.1.4 image-only shape and need to
move onto the current AV-aware runtime contract.

### What changed

The runtime now supports AV-aware assets and variants. Existing adopters need to
confirm runtime ownership, keep explicit host plus packaged migrations, validate
the upgraded environment, and use the bounded repair verb that matches the
observed state.

### Upgrade steps

#### 1. Confirm runtime ownership and AV prerequisites

Before you touch migrations, make sure the host app still owns the same runtime
boundaries:

- Rindle persists through your adopter-owned Repo.
- Oban stays on the default `Oban` instance and the host app owns that
  supervision tree.
- Install `FFmpeg >= 6.0` before you enable AV variants or diagnose AV work.

If you are bumping the package version as part of the upgrade, fetch the new
dependency first:

```bash
mix deps.get
```

If you only need the greenfield setup details again, return to
[Getting Started](getting_started.html). This guide assumes the app already
owns its Repo, Oban config, and storage configuration.

#### 2. Run explicit host and packaged migrations

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

#### 3. Validate the upgraded runtime

Run the read-only environment check immediately after migrations:

```bash
mix rindle.doctor
```

`mix rindle.doctor` validates setup and drift. If it reports FFmpeg, Oban, or
migration issues, fix those before you attempt any repair command.

#### 4. Inspect degraded upgraded work when needed

If a specific upgraded asset or variant looks wrong after the migration, inspect
the bounded runtime report before you mutate anything:

```bash
mix rindle.runtime_status --format json
```

`mix rindle.runtime_status` is optional in the happy path. Use it when you need
to confirm whether the problem is failed asset-scoped work,
`stale`/`missing` drift, or broader runtime residue. Deep diagnostics and error
maps stay in [Operations](operations.html) and
[Troubleshooting](troubleshooting.html).

#### 5. Repair one upgraded asset through the public facade

For one failed upgraded asset, use the asset-scoped repair surface:

```elixir
asset_id = "..."

{:ok, report} =
  Rindle.requeue_variants(asset_id, variant_names: ["web_720p"])
```

`Rindle.requeue_variants/2` is the sharp lane for one asset. It re-enqueues the
named failed variants without pulling `ready`, `queued`,
`processing`, `stale`, or `missing` siblings into the run.

#### 6. Reserve broad drift repair for stale or missing variants

Do not use asset-scoped `requeue` as a surrogate for profile drift or missing
storage objects. For broader derivative drift, stay on:

```bash
mix rindle.regenerate_variants
```

That command is the broad maintenance lane for `stale` or `missing` variants
after recipe, preset, or storage drift.

### Verification

Run the same checks that CI uses for this path:

1. Confirm the explicit host plus packaged migrations completed.
2. Run `mix rindle.doctor`.
3. If needed, inspect degraded work with `mix rindle.runtime_status --format json`.
4. Repair one failed upgraded asset with
   `Rindle.requeue_variants(asset_id, variant_names: ["web_720p"])`.
5. Reserve broad drift repair for stale or missing variants with
   `mix rindle.regenerate_variants`.

## Next Reads

- [Operations](operations.html) for the day-2 verb map and task boundaries
- [Troubleshooting](troubleshooting.html) for error-state recovery guidance
- [Getting Started](getting_started.html) for the greenfield install path
