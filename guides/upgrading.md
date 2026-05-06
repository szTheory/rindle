# Upgrading Existing Adopters

Use this runbook when your app already ships Rindle from the pre-v1.4
image-only shape and you need to move onto the current AV-aware runtime
contract. Fresh installs should stay on [`README.md`](../README.md) and the
greenfield deep guide in [`getting_started.md`](getting_started.md).

The generated package-consumer upgrade proof exercises the same public path this
guide teaches: explicit host plus packaged migrations, `mix rindle.doctor`,
optional `mix rindle.runtime_status`, then the repair verb that matches the
observed state.

## 1. Confirm Runtime Ownership And AV Prerequisites

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
[`getting_started.md`](getting_started.md). This guide assumes the app already
owns its Repo, Oban config, and storage configuration.

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

## 3. Validate The Upgraded Runtime

Run the read-only environment check immediately after migrations:

```bash
mix rindle.doctor
```

`mix rindle.doctor` validates setup and drift. If it reports FFmpeg, Oban, or
migration issues, fix those before you attempt any repair command.

## 4. Inspect Degraded Upgraded Work When Needed

If a specific upgraded asset or variant looks wrong after the migration, inspect
the bounded runtime report before you mutate anything:

```bash
mix rindle.runtime_status --format json
```

`mix rindle.runtime_status` is optional in the happy path. Use it when you need
to confirm whether the problem is failed asset-scoped work,
`stale`/`missing` drift, or broader runtime residue. Deep diagnostics and error
maps stay in [`operations.md`](operations.md) and
[`troubleshooting.md`](troubleshooting.md).

## 5. Repair One Upgraded Asset Through The Public Facade

For one failed upgraded asset, use the asset-scoped repair surface:

```elixir
asset_id = "..."

{:ok, report} =
  Rindle.requeue_variants(asset_id, variant_names: ["web_720p"])
```

`Rindle.requeue_variants/2` is the sharp lane for one asset. It re-enqueues the
named failed variants without pulling `ready`, `queued`,
`processing`, `stale`, or `missing` siblings into the run.

## 6. Reserve Broad Drift Repair For Stale Or Missing Variants

Do not use asset-scoped `requeue` as a surrogate for profile drift or missing
storage objects. For broader derivative drift, stay on:

```bash
mix rindle.regenerate_variants
```

That command is the broad maintenance lane for `stale` or `missing` variants
after recipe, preset, or storage drift.

## Next Reads

- [`operations.md`](operations.md) for the day-2 verb map and task boundaries
- [`troubleshooting.md`](troubleshooting.md) for error-state recovery guidance
- [`getting_started.md`](getting_started.md) for the greenfield install path
