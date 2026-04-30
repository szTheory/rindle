# Release Publishing

## TL;DR

- Merge the Release Please PR on `main`.
- Wait for `ci.yml` to finish green on the exact release SHA.
- Let the `Release` workflow run `Run release preflight`, `Verify version alignment`, and `Check whether Hex.pm release already exists`.
- If the version is already live, recovery reruns skip publish and continue to public verification.
- Use `mix hex.publish --revert VERSION` for in-window rollback; use retire plus a fix release after the window.

This maintainer runbook documents the workflow that shipped Rindle to Hex.pm on
2026-04-29. `0.1.0` through `0.1.3` were pipeline shakedown iterations during
that first publish window. Treat `0.1.4` as the first recommended pin.

## First Public Release History

Start from a reviewed Release Please PR on `main`, not from a manual tag push.
The first publish flow converted `@version "0.1.0-dev"` into `0.1.0`, created
`v0.1.0`, and then continued through follow-up release fixes until `0.1.4`
closed the publish window.

## One-Time Publish Prerequisites

Run these checks outside CI:

```bash
mix hex.user whoami
mix hex.owner list rindle
```

- Confirm the current maintainer identity with `mix hex.user whoami`.
- Confirm package-name availability before the inaugural publish of a new package.
- Configure the `release` GitHub Actions environment secret `HEX_API_KEY`.
- Keep maintainer identity and package-name availability checks outside `scripts/release_preflight.sh` and outside secret-gated automation.
- Confirm the initial owner after first publish, then add additional owners with `mix hex.owner add rindle USERNAME`.

## Exact-SHA Release Proof

Local preflight is diagnostic preparation, not authoritative release proof.
Authoritative signoff requires a green GitHub Actions run on the exact release-candidate SHA.
Run `bash scripts/release_preflight.sh` and local `mix hex.build --unpack`
while iterating, then rely on the exact-SHA `ci.yml` run selected by Release
Please or `workflow_dispatch` recovery.

Do not substitute a green branch head, a rerun on a different commit, or a
local-only transcript for this proof. The `Package Consumer + Release Preflight`
lane in `ci.yml` is part of the exact-SHA boundary.

## Package Metadata Review

Build the package exactly as shipped before every release attempt:

```bash
bash scripts/release_preflight.sh
```

Check the unpacked `hex_metadata.config` and package contents for:

- `rindle`
- the intended release version
- `MIT`
- `GitHub`
- `CHANGELOG.md`
- `guides/release_publish.md`
- `mix docs --warnings-as-errors`

Review shipped metadata, not just repo source. The packaged metadata review is
still diagnostic until the same commit is green in GitHub Actions CI.

## Routine Releases

Run this sequence on every release after the inaugural publish:

1. Merge the Release Please PR on `main`.
2. Wait for the `Release` workflow to complete these step names in order:
   - `Release Please`
   - `Wait for CI to finish green on release SHA`
   - `Run release preflight`
   - `Verify version alignment`
   - `Check whether Hex.pm release already exists`
   - `Dry run Hex publish`
   - `Publish to Hex.pm (live)`
   - `Wait for Hex.pm index (post-publish)`
   - `Verify public Hex.pm artifact`
3. Use the recovery-only dispatch lane only when you must rerun the trusted path from an exact immutable ref.

## Release Workflow Contract

The repository workflow runs these shipped commands:

```bash
bash scripts/release_preflight.sh
bash scripts/assert_version_match.sh
bash scripts/hex_release_exists.sh
mix hex.publish --dry-run --yes
mix hex.publish --yes
bash scripts/public_smoke.sh
```

The repo's `package-consumer` lane shifts the release contract left before
publish time. The release workflow waits for `ci.yml` on the exact release SHA
to finish green before entering the protected publish lane. After live publish,
`Verify public Hex.pm artifact` proves the package from a fresh runner with
`HEX_API_KEY` cleared.

Do not use `--replace` in CI. If you need `mix hex.publish --replace --yes`,
run it locally during the grace window with deliberate human review. For
docs-only repair, prefer `mix hex.docs publish`.

## Recovery Workflow Contract

`workflow_dispatch` in `.github/workflows/release.yml` is recovery-only. Supply:

- `recovery_reason`
- `recovery_ref`
- an exact existing tag or a 40-character commit SHA

Recovery reruns the exact-SHA gate, preflight, version alignment, idempotency
probe, publish lane, and public verification. If the target version is already
live on Hex.pm, the workflow skips both publish steps, writes a skip summary,
and still runs public verification.

## Post-Publish Follow-Up

After the first publish:

1. Run `mix hex.owner list rindle`.
2. Add additional owners with `mix hex.owner add rindle USERNAME`.

After every publish:

1. Confirm the `Release` workflow finished successfully.
2. Confirm `Verify public Hex.pm artifact` passed.
3. Update this runbook when workflow behavior changes.

## Rollback and Revert

Use this quick decision table first:

| Situation | Command | Notes |
| --- | --- | --- |
| Bad release within revert window | `mix hex.publish --revert VERSION` | 24h for the first publish, 1h for subsequent releases |
| Runtime breakage after revert window | `mix hex.retire rindle VERSION REASON --message "..."` | Reasons: `renamed`, `deprecated`, `security`, `invalid`, `other` |
| Docs broken, code fine | `mix hex.docs publish` | Republish docs without mutating package version |
| Window closed and code broken | retire bad version, ship fix patch release | Lockfiles still install the bad version; publish the fix immediately |

Runbook rules:

- `mix hex.publish --revert VERSION` is the canonical revert command.
- `mix hex.revert rindle VERSION` is wrong legacy wording. Do not use it.
- `mix hex.retire` messages are limited to 140 characters.
- `mix hex.retire --unretire` removes a retirement marker.
- Retirement warns new resolvers but lockfiles still install the bad version.

Window-closed fallback:

1. Run `mix hex.retire rindle VERSION REASON --message "..."`.
2. Ship the fix release immediately.
3. Update the GitHub Release note with the adopter advisory.

Adopter advisory template:

```text
Adopter advisory: VERSION is retired due to REASON. Upgrade to FIX_VERSION immediately. Existing lockfiles can still install VERSION until you update your dependency resolution.
```

Use this commit title when retire-and-patch fires:

```text
fix(release): retire BAD_VERSION, ship FIX_VERSION
```

Use this GitHub Release title format:

```text
rindle FIX_VERSION - replacement for retired BAD_VERSION
```

## Footguns & Gotchas

- Hex.pm versions are immutable once the revert window closes.
- Reverting the last release removes the package entry for that version.
- `mix hex.owner add` is post-publish-only for the package owner set.
- Hex tarballs have practical 8MB and hard 64MB size pressure.
- Git dependencies do not prove a Hex.pm release path.
- Conventional commits and Release Please drive the release train.
- The `autorelease: pending` label is part of the release-please loop.
- Manual tag pushes fight the trusted workflow contract.
- `mix docs --warnings-as-errors` is a publish gate, not optional cleanup.
- Owner key and API key are different concerns; do not confuse them.
- Component tags and simple `vX.Y.Z` tags are different release-please shapes.
- Trusted current tooling is not the same thing as the frozen release source tree.

## Appendix A: Deviation Log

| Date | Change | Evidence |
| --- | --- | --- |
| 2026-04-30 | Added idempotent recovery reruns so `workflow_dispatch` skips publish when the target version is already live and still runs public verification. | Phase 16 recovery fix on current branch |
| 2026-04-29 | Hardened publish preflight after first live publish friction. | `d5c21ad`, `65728e5` |
| 2026-04-29 | Locked current tooling against frozen source via `git worktree` recovery flow. | `71a0f99` |
| 2026-04-29 | Moved public verification to the public package path and refreshed smoke discipline. | `6dd0d54` |
| 2026-04-29 | Fixed release version parsing drift in the workflow. | `a7efefd` |

## Appendix B: Architecture Note

The release flow uses current tooling and frozen source:

- `main HEAD` supplies the trusted workflow and scripts.
- `recovery_ref` selects the immutable source commit or tag.
- `git worktree` materializes that frozen source tree under the current tooling.
- The workflow runs preflight, version checks, idempotency probe, publish, and public verification against that split model.
