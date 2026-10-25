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
local-only transcript for this proof. The lean `package-consumer` PR lane and
off-PR `Package Consumer Full Matrix + Release Preflight` lane are both part of
the maintained evidence chain.

## 0.4.0 Schema-Isolation Release Receipt

Rindle 0.4.0 shipped on 2026-08-20. Its immutable source was verified by exact-SHA
CI and the protected release workflow, and the installed Hex package passed fresh
public verification:

- [exact-source CI run 32371768158](https://github.com/szTheory/rindle/actions/runs/32371768158)
- [protected release and public verification run 32383632492](https://github.com/szTheory/rindle/actions/runs/32383632492)
- [0.4.0 on Hex.pm](https://hex.pm/packages/rindle/0.4.0)

The pre-release `Release-As: 0.4.0` correction and staged changelog procedure are
historical evidence, not current operator instructions. For adopter migration and
rollback guidance, use [Upgrading](upgrading.html). For the next patch release, use
the routine release procedure below and let Release Please own version, manifest,
tag, and generated changelog changes.

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
2. **Relabel any already-stuck, already-published release PR truthfully.** The
   current workflow now performs this transition automatically after Public
   Verify succeeds. For a release published before that guard shipped, use:
   `gh pr edit <N> --remove-label "autorelease: pending" --add-label "autorelease: tagged"`.
3. **Re-trigger `release.yml`.** Push (or re-run the latest `main` push) to
   re-run the canonical automerge → dispatch → gate-ci-green → publish chain.

**Historical `Actions: write` footgun (confirmed while cutting 0.3.2):** the then-current
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

The current automerge workflow uses its explicit Actions-write job token for
dispatch; the release App does not need Actions permission.

**Prevention:**

- `release-train-drift.yml` self-files an issue when `main` has releasable
  commits with no open release PR.
- The Release Please job fails on the originating push when releasable commits
  are blocked by a merged release PR that still has `autorelease: pending`.
- After Public Verify succeeds, `release.yml` transitions the matching merged
  Release Please PR to `autorelease: tagged` and verifies the label persisted.
- Explicit credential selection and admission reject partial configuration and
  invalid selected tokens. App tokens use installation-aware admission; PATs use
  user identity plus repository selection. Actual operations prove write grants.

## Runbook: Rotating `RELEASE_PLEASE_TOKEN`

`RELEASE_PLEASE_TOKEN` is a repository-scoped fine-grained PAT with a fixed
expiry. Rotate it before expiry so Release Please cannot stall behind the
present-but-invalid `|| github.token` fallback described above.

### Rotation log

| Rotated | Expires | Notes |
| --- | --- | --- |
| 2026-06-30 | ~2026-08 | 0.3.2 recovery token lacked `Actions: write`; publish dispatch required manual recovery. |
| 2026-08-18 | 2026-11-16 | Scoped only to `szTheory/rindle` with the authoritative permissions below. |

### Authoritative token configuration

Create a **fine-grained** token at
<https://github.com/settings/personal-access-tokens/new>:

| Field | Value |
| --- | --- |
| Token name | `rindle-release-please` |
| Resource owner | `szTheory` |
| Repository access | **Only select repositories** → `szTheory/rindle` |
| Expiration | Use the shortest operationally practical lifetime; record the exact date above. |

Grant exactly these repository permissions and leave all other configurable
permissions at *No access*:

| Permission | Access | Why |
| --- | --- | --- |
| Contents | Read and write | Release Please writes version/changelog commits. |
| Issues | Read and write | Release Please manages its release labels and issue metadata. |
| Pull requests | Read and write | Release Please opens and updates the release PR. |

GitHub adds mandatory `Metadata: Read-only`; account permissions remain at
zero. Never grant organization-wide or all-repository access.

### Rotation procedure

1. Confirm the token summary names only `szTheory/rindle` and the permissions
   above, then generate it.
2. Copy the value once. Never paste it into chat, a shell command, an issue, or
   a repository file.
3. Open <https://github.com/szTheory/rindle/settings/secrets/actions>, update
   the existing `RELEASE_PLEASE_TOKEN`, and save it under that exact name.
4. Confirm the secret's **Last updated** timestamp changed. GitHub deliberately
   does not expose the stored value.
5. On the next intended `release.yml` run, confirm the validator prints
   `credential_admitted: legacy; read-only identity, write acceptance remains pending`
6. Confirm intended Release Please PR maintenance and protected merge succeed.
   Admission proves authentication and repository selection, not write grants.
   Dispatch uses the separate job token and cannot certify PAT write access.
7. Record the new rotation and expiry date in the table above.

Do not rerun Release Please solely as a token health check while a release is
mid-flight. A push to `main` in the normal green-main release train provides the
canonical validation path.

### Staged GitHub App migration

The workflows support two separate repository-installed Apps. Configuration is
optional during rollout: with no App settings, release jobs select the existing
`RELEASE_PLEASE_TOKEN`, then their explicit job token if that secret is absent.
Protection selects its existing `BRANCH_PROTECTION_PAT`, or reports unconfigured.
Setting either half of an App configuration selects the App path: a missing half,
invalid key, failed mint or failed admission stops the job, without credential
fallback. The same client ID cannot serve release and protection.

| Principal | Repository variable | Repository secret | Installation grants |
| --- | --- | --- | --- |
| Release App | `RELEASE_APP_CLIENT_ID` | `RELEASE_APP_PRIVATE_KEY` | Contents, Pull requests, Issues: write; only `szTheory/rindle` |
| Protection App | `PROTECTION_APP_CLIENT_ID` | `PROTECTION_APP_PRIVATE_KEY` | Administration: write; only `szTheory/rindle` |

Each job mints a subset using the SHA-pinned official token action. Release Please
and baseline maintenance request Contents/Pull requests/Issues write. Automerge
requests Contents/Pull requests write. Protection requests only Administration
write. Release publication and explicit workflow dispatch use their existing job
token; baseline CI observation keeps `BASELINE_CHECKS_TOKEN` with Checks read.
Protection credentials are never a release fallback. These choices preserve the
exact-source CI, release environment, publish preflight and public verification.

The local credential action is loaded from trusted main tooling, never a PR head.
The minted token is restricted to the named repository and admitted through the
complete installation repository inventory, matching its numeric repository ID.
Installation tokens never go through the PAT-only `GET /user` guard. Token values
are job-local, masked, and revoked by the mint action at job completion; never put
tokens or API bodies in artifacts. App tokens last one hour: baseline landing
mints immediately before its existing 45-minute observer, separately from earlier
label reconciliation. An expired selected token fails; it never changes principal.

Roll out one principal at a time after reviewing the PR. App creation/installation
and secure secret entry are separate authorized setup actions. Do not paste a key
or token into chat. The mint/admission GETs prove identity and repository scope;
they do not prove write permission, automatic PR CI, protected merge, publish or
protection application. Keep migration acceptance open until intended real
operations yield machine evidence for automatic PR CI, protected merge/exact-ref
dispatch, and protection apply/readback. Do not dispatch the publish workflow as a
credential health probe. Keep existing credentials for rollback until replacement
operations pass. To roll back, remove both settings for the affected App together
and retain its existing valid credential; never recover by broadening the other
App. Retire each old credential only after its own replacement is proven.

The action's [permission and revocation inputs](https://github.com/actions/create-github-app-token/blob/64ab729a6294000f5aa4a4bc0b73d1f32bc45510/action.yml)
and GitHub's [installation repository endpoint](https://docs.github.com/en/rest/apps/installations#list-repositories-accessible-to-the-app-installation)
define the admission boundary. Explicit dispatch can use the job token under
[GitHub's workflow trigger rules](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow).

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
| 2026-04-30 | Added idempotent recovery reruns so `workflow_dispatch` skips publish when the target version is already live and still runs public verification. | Recovery fix on the release branch |
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
