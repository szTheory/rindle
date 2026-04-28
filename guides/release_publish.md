# Release Publishing

This runbook is for maintainers preparing Rindle's first public Hex.pm
release. It keeps publish-time ownership, versioning, and package review
steps in maintainer docs instead of pushing them into `README.md` or
`guides/getting_started.md`.

## Versioning

The first public release is `0.1.0`.

Use this sequence on the release branch:

1. Change `@version "0.1.0-dev"` in `mix.exs` to `0.1.0`.
2. Commit the release version change.
3. Create tag `v0.1.0`.
4. Run the preflight commands and publish.
5. After the release is live, bump `mix.exs` on `main` to the next `-dev`
   version.

Do not leave `main` on the release version after the publish completes.

## Hex Auth Check

Confirm the current maintainer account before any publish attempt:

```bash
mix hex.user whoami
```

This phase does not wire live `HEX_API_KEY` automation. The goal here is
to verify the human publish operator and the runbook contract before Phase
11 adds write-capable automation.

## First Publish Owner Model

The first public publish is personal-first: the maintainer account that
performs the inaugural publish becomes the initial owner for `rindle`.

Confirm the current owner set before and after the release:

```bash
mix hex.owner list rindle
```

After the first publish, add any additional maintainers explicitly:

```bash
mix hex.owner add rindle USERNAME
```

Do not rely on informal handoff. Owner follow-up is part of the release.

## Package metadata review

Before any live publish step, build the package exactly as shipped:

```bash
mix hex.build --unpack
```

Compare source metadata in `mix.exs` with the unpacked
`hex_metadata.config` and confirm all of the following:

- Package name is `rindle`.
- Release version matches the intended cut.
- License remains `MIT`.
- GitHub links point at the canonical repository.
- Packaged docs include `guides/release_publish.md`.

The point of this checklist is to validate shipped metadata, not just repo
source, before the first public release.

## Preflight Commands

Run this preflight sequence before publishing:

```bash
mix hex.user whoami
mix hex.owner list rindle
mix docs --warnings-as-errors
mix hex.build --unpack
```

Review the unpacked package contents and `hex_metadata.config` after the
build step. If any identity, license, link, or docs inclusion check fails,
fix the source and rebuild before publishing.

## Post-Publish Follow-Up

After `0.1.0` is published:

1. Verify the owner list again with `mix hex.owner list rindle`.
2. Add additional maintainers with `mix hex.owner add rindle USERNAME`.
3. Bump `mix.exs` on `main` back to the next `-dev` version.
4. Keep this runbook current if the owner roster, links, or release
   checklist changes.

## Rollback and Revert

Package rollback and revert procedures are manual maintainer actions; they are not automated in CI.

If a published release is broken, you can revert it using the native Hex tooling:

```bash
mix hex.revert rindle VERSION
```

**Important Constraints:**
- You have a **1-hour window** to revert a release.
- For the *first* release (`0.1.0`), this window is extended to **24 hours**.
- Once a version is reverted, you **can** reuse that version number for a future publish.
