# Release Publishing

This maintainer runbook covers Rindle's first public Hex.pm release
(`0.1.0`), routine releases after `0.1.0`, and the manual rollback/revert
path for a bad public release. It keeps workflow operations and one-time
publish prerequisites in maintainer docs instead of pushing them into
`README.md` or `guides/getting_started.md`.

## First Public Release (0.1.0)

Use this sequence on `main`:

1. Complete the one-time publish prerequisites in this guide.
2. Confirm the root `CHANGELOG.md` has a `0.1.0` entry matching the release scope.
3. Merge the Release Please PR that updates `mix.exs` from `@version "0.1.0-dev"` to `0.1.0` and tags `v0.1.0`.
4. Let `.github/workflows/release.yml` wait for `ci.yml` to finish green on the exact release SHA, then run the publish lane.
5. After the workflow succeeds, verify the initial owner state with `mix hex.owner list rindle` and add any additional maintainers.

Release intent starts from a reviewed Release Please PR on `main`, not from a manually pushed tag.

## Routine Releases After 0.1.0

Use this sequence for every later public release:

1. Merge the Release Please PR for the next version on `main`.
2. Monitor GitHub Actions until the `Release` workflow completes these
   step names in order:
   - `Release Please`
   - `Wait for CI to finish green on release SHA`
   - `Run release preflight`
   - `Verify version alignment`
   - `Dry run Hex publish`
   - `Live publish to Hex`
   - `Wait for Hex.pm index`
   - `Verify public Hex.pm artifact`
3. Use the recovery-only manual dispatch lane only if the trusted publish path must be rerun from an exact tag or 40-character SHA.

## One-Time Publish Prerequisites

Before enabling the first live publish, complete these maintainer-controlled checks outside CI:

```bash
mix hex.user whoami
```

- Confirm the current maintainer identity with `mix hex.user whoami`.
- Confirm Hex.pm package-name availability for `rindle` before the inaugural publish.
- Configure the `release` GitHub Actions environment secret `HEX_API_KEY`.
- Keep maintainer identity and package-name availability checks outside `scripts/release_preflight.sh` and outside secret-gated automation.

## First Publish Owner Model

The first public publish is personal-first: the maintainer account that
performs the inaugural publish becomes the initial owner for `rindle`.

After the first public publish, confirm the current owner set:

```bash
mix hex.owner list rindle
```

After the first publish, add any additional maintainers explicitly:

```bash
mix hex.owner add rindle USERNAME
```

Do not rely on informal handoff. Owner follow-up is part of the release.

## Exact-SHA Release Proof

Local preflight is diagnostic preparation, not authoritative release proof.
Authoritative signoff requires a green GitHub Actions run on the exact release-candidate SHA.
The maintainer can use `bash scripts/release_preflight.sh` and local
`mix hex.build --unpack` runs to iterate on the candidate, but the release
workflow does not publish until `ci.yml` is green on the exact release-candidate
SHA selected by Release Please or recovery dispatch.

Do not substitute a green branch head, a rerun on a different commit, or a
local-only shell transcript for this proof. The `Package Consumer + Release Preflight`
lane in `ci.yml` is part of that exact-SHA proof.

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

The packaged metadata review is still diagnostic until the same commit is
green in GitHub Actions CI.

## Preflight Commands

Run this preflight sequence before merging or recovering a release:

```bash
bash scripts/release_preflight.sh
```

Review the unpacked package contents and `hex_metadata.config` after the
preflight build. If any identity, license, link, changelog, or docs inclusion
check fails, fix the source and rebuild before the Release Please PR merges or before running recovery publish.

These commands are maintainer diagnostics. They do not replace the required
remote CI proof on the exact release-candidate SHA.

## Release Workflow Contract

Mainline releases are anchored to a Release Please PR on `main` plus the
repository workflow and commands already shipped in the repo. The `Release`
workflow runs:

```bash
bash scripts/release_preflight.sh
bash scripts/assert_version_match.sh
mix hex.publish --dry-run --yes
mix hex.publish --yes
bash scripts/public_smoke.sh
```

The repo's `package-consumer` CI lane shifts the release contract left before
publish time by running the shared preflight, mocking tag/version alignment,
and exercising `mix hex.publish --dry-run --yes`. The release workflow then
waits for `ci.yml` on the exact release SHA to finish green before it can enter
the protected publish lane. After live publish, the `Verify public Hex.pm artifact`
step serves as the automated post-publish proof on a fresh runner with
`HEX_API_KEY` cleared, so no separate human UAT step is required.

Manual maintainer checks for `mix hex.user whoami` and first-release
package-name availability stay outside CI as one-time prerequisites.

## Recovery Workflow Contract

The `workflow_dispatch` path in `.github/workflows/release.yml` is recovery-only.
It requires:

- `recovery_reason`
- `recovery_ref` set to an exact existing tag or a 40-character commit SHA

Recovery reruns the same exact-SHA green CI gate, preflight, dry-run publish,
live publish, and public verification as the normal Release Please path.

## Post-Publish Follow-Up

After the first `0.1.0` release:

1. Verify the owner list again with `mix hex.owner list rindle`.
2. Add additional maintainers with `mix hex.owner add rindle USERNAME`.

After every release, including `0.1.0`:

1. Verify the `Release` workflow finished successfully.
2. Confirm `Verify public Hex.pm artifact` passed.
3. Keep this runbook current if the owner roster, links, or release
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
