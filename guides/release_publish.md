# Release Publishing

This maintainer runbook covers Rindle's first public Hex.pm release
(`0.1.0`), routine releases after `0.1.0`, and the manual rollback/revert
path for a bad public release. It keeps publish-time ownership, versioning,
and workflow operations in maintainer docs instead of pushing them into
`README.md` or `guides/getting_started.md`.

## First Public Release (0.1.0)

Use this sequence on the release branch:

1. Change `@version "0.1.0-dev"` in `mix.exs` to `0.1.0`.
2. Confirm the root `CHANGELOG.md` has a `0.1.0` entry matching the release scope.
3. Commit the release version change.
4. Create tag `v0.1.0`.
5. Push the tag so `.github/workflows/release.yml` runs the `Release`
   workflow.
6. After the workflow succeeds, bump `mix.exs` on `main` to the next
   `-dev` version and commit that follow-up.

Do not leave `main` on the release version after the publish completes.

## Routine Releases After 0.1.0

Use this sequence for every later public release:

1. Derive the release version from the current `-dev` value in `mix.exs`.
2. Update `mix.exs` from the current `-dev` value to the release value.
3. Commit the version change.
4. Create and push tag `vVERSION`.
5. Monitor GitHub Actions until the `Release` workflow completes these
   step names in order:
   - `Run release preflight`
   - `Verify version alignment`
   - `Live publish to Hex`
   - `Verify public Hex.pm artifact`
6. After the workflow succeeds, bump `mix.exs` on `main` to the next
   `-dev` version and commit that follow-up.

## Hex Auth Check

Confirm the current maintainer account before any publish attempt:

```bash
mix hex.user whoami
```

Maintainers verify their identity with `mix hex.user whoami` before
pushing a release tag. The tag-triggered `Release` workflow then performs
the live publish using `HEX_API_KEY` stored in the `release` GitHub
Actions environment. After publish, the `public_verify` job runs the
`Verify public Hex.pm artifact` step on a fresh runner with `HEX_API_KEY`
cleared, confirming network resolution independently of the publish job.
The maintainer identity and owner checks above remain manual proof, not CI proof.

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

## Pre-Tag Go/No-Go Checklist

Before creating or pushing a release tag, confirm all of the following:

1. `mix hex.user whoami` shows the intended publishing maintainer.
2. `mix hex.owner list rindle` matches the expected owner state for this release.
3. Hex.pm package-name availability for `rindle` is still acceptable for the first public publish.
4. `CHANGELOG.md` includes the `0.1.0` entry for the first public release, or the current release entry for later cuts.
5. `bash scripts/release_preflight.sh` passes locally on the exact release-candidate commit.

Items 1 through 3 remain manual maintainer checks because they depend on mutable external Hex account and registry state.

## Package metadata review

Before any live publish step, build the package exactly as shipped:

```bash
bash scripts/release_preflight.sh
```

The shared preflight script builds the package with `mix hex.build --unpack`
and then runs metadata, docs parity, install smoke, and docs validation in the
same order used by CI and the live release workflow.
That docs validation includes `mix docs --warnings-as-errors`.

Compare source metadata in `mix.exs` with the unpacked `hex_metadata.config`
and confirm all of the following:

- Package name is `rindle`.
- Release version matches the intended cut.
- License remains `MIT`.
- GitHub links point at the canonical repository.
- Package description matches the intended Hex.pm summary.
- Packaged root files include `CHANGELOG.md`.
- Packaged docs include `guides/release_publish.md`.

The point of this checklist is to validate shipped metadata, not just repo
source, before both the first public release and every routine release
after it.

## Preflight Commands

Run this preflight sequence before publishing:

```bash
mix hex.user whoami
mix hex.owner list rindle
bash scripts/release_preflight.sh
```

Review the unpacked package contents and `hex_metadata.config` after the
preflight build. If any identity, license, link, changelog, or docs inclusion
check fails, fix the source and rebuild before publishing.

## Release Workflow Contract

Tagged releases are anchored to the repository workflow and commands already
shipped in the repo. The `Release` workflow runs:

```bash
bash scripts/release_preflight.sh
bash scripts/assert_version_match.sh
mix hex.publish --yes
bash scripts/public_smoke.sh
```

The repo's `package-consumer` CI lane shifts the release contract left before
tag time by running the shared preflight, mocking tag/version alignment, and
exercising `mix hex.publish --dry-run --yes`. The release workflow's
`Verify public Hex.pm artifact` step then serves as the automated
post-publish proof on a fresh runner with `HEX_API_KEY` cleared, so no
separate human UAT step is required.

## Post-Publish Follow-Up

After the first `0.1.0` release:

1. Verify the owner list again with `mix hex.owner list rindle`.
2. Add additional maintainers with `mix hex.owner add rindle USERNAME`.

After every release, including `0.1.0`:

1. Verify the `Release` workflow finished successfully.
2. Confirm `Verify public Hex.pm artifact` passed.
3. Bump `mix.exs` on `main` back to the next `-dev` version.
4. Keep this runbook current if the owner roster, links, or release
   checklist changes.

## Rollback and Revert

Package rollback and revert procedures are manual maintainer actions; they
are not automated in CI. This applies to both the first `0.1.0` release
and every routine release after it.

If a published release is broken, you can revert it using the native Hex tooling:

```bash
mix hex.revert rindle VERSION
```

**Important Constraints:**
- You have a **1-hour window** to revert a release.
- For the *first* release (`0.1.0`), this window is extended to **24 hours**.
- Once a version is reverted, you **can** reuse that version number for a future publish.
