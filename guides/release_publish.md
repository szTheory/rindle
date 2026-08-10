# Release Publishing

## TL;DR

- Merge the Release Please PR on `main`.
- Wait for `ci.yml` to finish green on the exact release SHA.
- Let the `Release` workflow run `Run release preflight`, `Verify version alignment`, `Check whether Hex.pm release already exists`, and public metadata verification.
- If the version is already live, recovery reruns skip publish and continue to public verification.
- Use `mix hex.publish --revert VERSION` for in-window rollback; use retire plus a fix release after the window.

This maintainer runbook documents the workflow that shipped Rindle to Hex.pm on
2026-04-29. `0.1.0` through `0.1.3` were pipeline shakedown iterations during
that first publish window. Treat `0.1.4` as the first recommended pin.
When a release needs existing-adopter guidance, summarize the change here and
deep-link to [Upgrading](upgrading.html) instead of duplicating the full
procedure in the release runbook.

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
local-only transcript for this proof. The `Package Consumer Proof Matrix + Release Preflight`
lane in `ci.yml` is part of the exact-SHA boundary.

## 0.4.0 Schema-Isolation Signoff

Use the focused checks below to diagnose the 0.4.0 schema-isolation release
candidate before requesting release signoff. They are local diagnostic evidence,
not release authority:

```bash
mix test test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs --seed 0
bash scripts/install_smoke.sh image
cd examples/adoption_demo && mix precommit
```

Run `bash scripts/ci/cohort_demo_smoke.sh` for the Cohort cold-start and schema
boot assertion. It verifies the composed demo can build, start, and serve its
seeded homepage and admin console, but a checkout transcript never replaces the
exact-SHA GitHub Actions result.

Before merging the Release Please PR, review its generated `## [0.4.0]` note:
fold the staged `## Unreleased / 0.4.0` text into that generated block and remove the staging marker. Keep the detailed operator procedure linked through [Upgrading](upgrading.html). Release Please alone owns the final version, tag, and generated changelog heading.

The authoritative evidence chain is a green `ci.yml` run on the exact
release-candidate SHA. Confirm the following live workflow results:

- `Proof` docs/parity result
- Lean `Package Consumer Proof Matrix + Release Preflight` result
- `Adoption Demo Unit` result
- Off-PR `Package Consumer Full Matrix + Release Preflight` result on push to `main`
- `Cohort Demo Smoke` result on push to `main`

Then let the `Release` workflow run `Run release preflight`, `Verify version
alignment`, `Dry run Hex publish`, and `Verify public Hex.pm artifact`; those
packed and public gates, not local checkout results, authorize the release.

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
- `Changelog`
- `Docs`
- `CHANGELOG.md`
- `guides/release_publish.md`
- `mix docs --warnings-as-errors`

Review shipped metadata, not just repo source. The packaged metadata review is
still diagnostic until the same commit is green in GitHub Actions CI.
Hex owner/maintainer display is verified after publish from the public Hex API
by `scripts/verify_hex_package_metadata.sh VERSION`; it is not a `mix.exs`
package metadata key.

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
   - `Verify public Hex.pm metadata`
   - `Verify HexDocs reachability`
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
bash scripts/verify_hex_package_metadata.sh "$VERSION"
curl --fail --location --silent --show-error "https://hexdocs.pm/rindle/$VERSION"
bash scripts/public_smoke.sh "$VERSION"
```

The repo's `package-consumer` lane shifts the release contract left before
publish time. The release workflow waits for `ci.yml` on the exact release SHA
to finish green before entering the protected publish lane. After live publish,
`Wait for Hex.pm index (post-publish)` polls for up to 5 minutes with
15-second retries. `Verify public Hex.pm metadata` checks the package API for
GitHub/Changelog/Docs links plus the `sztheory` owner. The HexDocs probe follows
redirects to the final `2xx` response for
`https://hexdocs.pm/rindle/$VERSION`. `Verify public Hex.pm artifact` then
proves the package from a fresh runner with `HEX_API_KEY` cleared.

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

### Stuck release: expired `RELEASE_PLEASE_TOKEN` (the `|| github.token` footgun)

**Symptom:** `release-please failed: Bad credentials` in the Release Please job;
no `chore(main): release rindle X.Y.Z` PR appears despite releasable commits on
`main`.

**Root cause (corrected chain):** The `:epipe`/`$callers` fix commits merged
**2026-06-28**, AFTER the last successful release-please run (**2026-06-26**,
which only re-found the already-merged 0.3.1 PR — **PR #40 was the 0.3.1 release
PR, NOT a 0.3.2 PR**). The next push-to-`main` (**2026-06-29, run 28399407429**) —
the first that would have opened a **0.3.2** PR — failed with `Bad credentials`
because `RELEASE_PLEASE_TOKEN` had **expired**, and the workflow expression
`secrets.RELEASE_PLEASE_TOKEN || github.token` lets a *present-but-invalid*
secret WIN the `||` (a non-empty string is truthy), so `github.token` never
engages as a fallback. As a result **no 0.3.2 PR was ever opened**.

**Recovery:**

1. **Rotate `RELEASE_PLEASE_TOKEN`.** Prefer a GitHub App installation token (no
   expiry surprise) or a fine-grained PAT with **contents: read/write +
   pull-requests: read/write + issues: read/write + `Actions: read/write`**.
   Update repo **Settings → Secrets and variables → Actions**.
2. **Relabel any stuck-but-published release PR truthfully.** If a prior release
   PR is stuck on `autorelease: pending` while its version IS already published,
   relabel it so release-please stops re-finding it and will open the next
   version:
   `gh pr edit <N> --remove-label "autorelease: pending" --add-label "autorelease: tagged"`.
3. **Re-trigger `release.yml`.** Push (or re-run the latest `main` push) to
   re-run the canonical automerge → dispatch → gate-ci-green → publish chain.

**`Actions: write` footgun (confirmed while cutting 0.3.2):** this repo's
automerge job publishes by *dispatching* `release.yml`
(`gh workflow run … --field recovery_ref=<merge_sha>`). A PAT **without**
`Actions: write` merges the release PR fine but the dispatch step **403s**
(`Resource not accessible by personal access token`), so Publish/Public-Verify
never run (they are `workflow_dispatch`-gated, NOT push-gated). If only this
fails, complete the publish manually:
`gh workflow run release.yml --ref main --field recovery_reason="…" --field recovery_ref=<merge_sha>`.

**What actually unstuck 0.3.2 (2026-06-30):** THREE fixes in series — (a) rotate
the expired token, (b) relabel #40 `pending` → `tagged`, and (c) (because the new
PAT lacked `Actions: write`) a manual publish-dispatch. Published + verified via
run **28420598348**; Hex live == **0.3.2**.

**Prevention:**

- `release-train-drift.yml` self-files an issue when `main` has releasable
  commits with no open release PR.
- The token-validity step in the Release Please job should fail loudly on a
  present-but-invalid token (and ideally check `Actions: write` capability, not
  just `gh api user`) so the `|| github.token` mask cannot pass silently.

## Post-Publish Follow-Up

After the first publish:

1. Run `mix hex.owner list rindle`.
2. Add additional owners with `mix hex.owner add rindle USERNAME`.

After every publish:

1. Confirm the `Release` workflow finished successfully.
2. Confirm `Verify public Hex.pm metadata` passed.
3. Confirm `Verify HexDocs reachability` passed for `https://hexdocs.pm/rindle/$VERSION`.
4. Confirm `Verify public Hex.pm artifact` passed.
5. Update this runbook when workflow behavior changes.

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
