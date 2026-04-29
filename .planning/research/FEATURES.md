# Feature Research

**Domain:** Elixir library — first live Hex.pm publish + API ergonomics review (v1.3)
**Researched:** 2026-04-29
**Confidence:** HIGH (Hex.pm publish mechanics — official docs verified), MEDIUM (API ergonomics — community patterns + official naming guidelines)

---

## Context: What This Milestone Covers

v1.3 has two distinct feature tracks. They share the milestone but have different
dependency graphs and risk profiles.

**Track A — Live Hex Publish (PUBLISH-01–03):** Execute the first real publish from
the existing automation, confirm post-publish verification from Hex.pm, establish
the routine release path.

**Track B — API Ergonomics (API-01–04):** Audit and improve the public surface before
adoption grows: naming, missing convenience functions, doc/typespec coverage,
breaking-change determination.

Track A is a prerequisite for the library being usable by anyone. Track B is a
prerequisite for not regressing adopters once the package is public.

---

## Feature Landscape

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Version bumped from 0.1.0-dev to a real semver (0.1.0) | Hex will reject the `-dev` suffix in the version string; published versions must be clean semver | LOW | mix.exs `@version` currently reads `"0.1.0-dev"`. Bump to `"0.1.0"` before tagging. Depends on: existing mix.exs, assert_version_match.sh script |
| HEX_API_KEY present in GitHub `release` environment | `mix hex.publish --yes` will fail with a missing/placeholder key; this is the publish credential gate | LOW | Key must be created at hex.pm under user account, scoped to `api:write`, and stored as the `HEX_API_KEY` environment secret in the GitHub `release` environment. Already modeled in release.yml. |
| Package name not already taken on Hex.pm | Hex rejects publish if package name is claimed | LOW | Verify `rindle` is available at hex.pm/packages/rindle before attempting. First publish claims the name for the authenticated user. |
| Email confirmation on Hex.pm account | Unconfirmed accounts cannot publish; confirmation email is sent at registration | LOW | Must be done once per account. Blocks publish silently if skipped. |
| Post-publish: package resolves from hex.pm in a new project | Official Hex docs say "test your package after publishing by adding it as a dependency" | MEDIUM | Existing public_smoke.sh + generated_app_smoke_test.exs already cover this path. The public_verify CI job already runs it. Depends on: public_smoke.sh, release.yml public_verify job |
| Docs published to hexdocs.pm alongside the package | `mix hex.publish` automatically runs `mix docs` and deploys to hexdocs.pm. Broken docs = broken publish. | LOW | `mix docs --warnings-as-errors` is already run in release_preflight.sh. No new work if preflight passes. |
| CHANGELOG.md present in published package | Hex's default file include list covers `CHANGELOG*`; hexdocs shows it as an extra page if configured | LOW | Rindle currently has no CHANGELOG.md. A minimal one covering 0.1.0 is required before first publish so the release history starts clean. |
| Routine release path documented and executable | After first publish, every subsequent release must be a predictable sequence; maintainer should not need to re-discover steps | LOW | Existing release_publish.md guide exists. Review after first publish; update any steps that differ from what actually happened. |
| Version alignment: git tag = mix.exs = CHANGELOG | `assert_version_match.sh` already enforces tag vs mix.exs; CHANGELOG entry for the published version is the community expectation | LOW | Depends on: CHANGELOG.md creation, assert_version_match.sh |

### Differentiators (Competitive Advantage)

These are improvements that distinguish a well-maintained library from a thrown-over-the-wall publish.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| @doc false on all internal implementation modules | Makes the public vs internal API boundary explicit; adopters know exactly what is stable | MEDIUM | Storage adapter implementations (Local, S3), workers, upload broker, domain FSM internals, and security internals are implementation details. They have @moduledoc content today but are not intended as public API. Mark them with `@doc false` on individual internal functions or confirm via @moduledoc false per module where appropriate. |
| @doc coverage on every public function | Hex ecosystem expectation for any library that gets adoption; ExDoc surfaces the coverage gaps prominently on hexdocs.pm | HIGH | Audit shows zero @doc annotations on: Storage.Local (11 public defs), Storage.S3 (11 public defs), Storage.Capabilities (5 public defs), Config (4 public defs), Security.Filename (1), Security.Mime (4), Profile.Digest (2), domain schema changesets (3), domain FSMs (partial). Rindle.HTML `picture_tag` is missing @doc. Depends on: no other features — purely additive. |
| @spec coverage on undocumented functions | Dialyzer needs specs to give useful warnings; hexdocs renders specs as part of the API reference | MEDIUM | Same set of modules as @doc gaps. @spec annotations are already present on most of Rindle's main entry points and delivery/ops modules. The gaps are in the adapter implementation layer and security modules. |
| Bang variants for common operations | Elixir convention: operations that return `{:ok, _}` or `{:error, _}` should have a `!` variant that raises on failure | MEDIUM | `Rindle.attach!/4`, `Rindle.detach!/3`, `Rindle.upload!/3`, `Rindle.url!/3`, `Rindle.variant_url!/4` are the natural candidates. Pattern-matches against the non-bang return; raises on error. Adopters writing pipelines will expect these. |
| Naming consistency audit across public surface | Inconsistent naming across modules is a breaking-change magnet at 1.0 | HIGH | Specifically: `verify_upload/2` vs `complete_multipart_upload/3` — both complete a session but use different vocabulary. `store_variant/4` is on the Rindle facade but variant logic is split across Rindle, Delivery, and the ops modules. Surface these inconsistencies now while the library is pre-1.0 and callers are rare. |
| Convenience query helpers for common adopter lookups | Adopters frequently need "get all ready variants for this asset" or "get attachment at slot X for this owner" without writing Ecto queries | HIGH | Candidates: `Rindle.attachment_for(owner, slot)` → `{:ok, attachment} | {:error, :not_found}`, `Rindle.ready_variants_for(asset)` → list of variant structs in `:ready` state. These reduce the amount of Ecto the adopter must import. Depends on: Config.repo/0 already works; domain schemas already imported. |
| CHANGELOG.md with structured release notes | hex.pm community expects structured per-version history; adopters evaluating upgrades read changelogs | LOW | Low complexity but high signal: libraries that ship without changelogs look unmaintained on hexdocs. A CHANGELOG covering v0.1.0 initial features is the minimum. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Publishing docs-only without package | Tempting shortcut to fix a doc issue post-publish | Creates version drift; hexdocs can be out of sync with what is installable | Fix the doc issue, bump the patch version, republish both. Use `mix hex.publish docs` only for urgent corrections to an already-correct package. |
| Exposing Storage.Local and Storage.S3 as primary API targets | Adopters will discover them and start depending on them directly | These modules implement the Rindle.Storage behaviour; their function signatures are internal contracts driven by the behaviour, not adopter-facing API | Keep the `Rindle` facade as the single interaction surface; route all storage access through `Rindle.store/4`, `Rindle.url/3`, etc. |
| Adding dynamic variant lookups or asset queries via raw Ecto to public API | Adopters want to be able to query assets by arbitrary criteria | Making arbitrary Ecto queries public API surface creates a versioning obligation for every query form | Provide targeted, named convenience helpers (attachment_for, ready_variants_for) and document that raw Ecto queries against Rindle schemas are adopter responsibility |
| Removing `-dev` suffix via a separate "version bump" PR/commit separate from the release tag | Seems like clean separation | The assert_version_match.sh gate enforces exact match between git tag and mix.exs; bumping mix.exs in a commit that is not the tag creates a window where HEAD and the tag disagree | Bump mix.exs version and tag the commit in the same operation, on main |
| Publishing with `--replace` to "fix" a published version | Seems like a safe correction path | --replace only works within the one-hour correction window; after that it silently fails or errors | Use `--replace` only within the correction window; for substantive changes, publish a new patch version |

---

## Feature Dependencies

```
[Version: 0.1.0 clean semver]
    └──required by──> [First Hex publish]
                          └──required by──> [Post-publish public verification]
                          └──required by──> [Routine release path documentation update]

[HEX_API_KEY in release environment]
    └──required by──> [First Hex publish]

[Email confirmation on Hex.pm account]
    └──required by──> [First Hex publish]

[CHANGELOG.md creation]
    └──required by──> [First Hex publish]  (community expectation; hexdocs extras)
    └──required by──> [Routine release path includes CHANGELOG step]

[CI pipeline green]
    └──required by──> [First Hex publish]  (release workflow runs preflight before publish)

[Naming audit complete]
    └──enhances──> [Breaking-change determination]

[@doc coverage complete]
    └──enhances──> [Hexdocs rendering quality on hexdocs.pm]

[Bang variants added]
    └──requires──> [Public function naming confirmed stable]  (bang variant names must match the non-bang)
```

### Dependency Notes

- **Version bump requires CHANGELOG and CI green first:** Tagging before CI is green risks a failed publish attempt that cannot be cleanly reverted after the 60-minute window.
- **API ergonomics (API-01–04) do not block Track A:** The publish can proceed before the full API review. However, publishing with significant doc gaps means hexdocs.pm will show incomplete documentation, which creates a poor first impression for any early adopters.
- **@doc false marking requires naming audit first:** If a module is internal, confirm that before marking it. If it turns out to have public-facing value, it needs docs first, not `@doc false`.

---

## MVP Definition for v1.3

### Launch With (v1.3 publish track)

Minimum needed for first live publish to be safe and clean:

- [ ] Version bumped to `0.1.0` in mix.exs — without this, `mix hex.publish` fails on semver validation
- [ ] CHANGELOG.md created with a 0.1.0 entry — table stakes for hexdocs.pm and community norms
- [ ] HEX_API_KEY configured in GitHub `release` environment — required for release.yml to publish
- [ ] CI pipeline passing on the tagged commit — release.yml runs preflight before publish
- [ ] Hex.pm account email confirmed, `rindle` package name available — blocked without these
- [ ] Post-publish: confirm package resolves from hex.pm and public_verify job passes

### Add in API Ergonomics Track (v1.3 API track)

These improve the surface before adoption grows, in priority order:

- [ ] @doc annotation pass on all public-facing modules — highest-visibility gap on hexdocs.pm
- [ ] Naming audit: document which names are stable and which to change before 1.0
- [ ] Breaking-change determination: mark internal modules with @moduledoc false / @doc false
- [ ] Convenience query helpers: `attachment_for/2`, `ready_variants_for/1`
- [ ] Bang variants for core operations: `attach!/4`, `upload!/3`, `url!/3`
- [ ] @spec pass on any public functions still missing specs

### Future Consideration (Post-v1.3)

- [ ] CHANGELOG automation (keep-a-changelog format, release-please integration) — defer until release cadence is established
- [ ] Full Dialyzer clean pass — valuable but time-consuming; schedule after API surface is stable

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Version 0.1.0 bump + CHANGELOG.md | HIGH | LOW | P1 |
| HEX_API_KEY + first live publish | HIGH | LOW | P1 |
| Post-publish verification pass | HIGH | LOW | P1 |
| @doc coverage on public functions | HIGH | MEDIUM | P1 |
| Breaking-change audit + @moduledoc false on internals | HIGH | MEDIUM | P1 |
| Naming consistency audit | HIGH | MEDIUM | P2 |
| Convenience query helpers (attachment_for, ready_variants_for) | MEDIUM | MEDIUM | P2 |
| Bang variants (attach!, upload!, url!) | MEDIUM | LOW | P2 |
| @spec pass on remaining gaps | MEDIUM | MEDIUM | P2 |
| Routine release path doc update | MEDIUM | LOW | P2 |

---

## Hex.pm Publish Expectations — What Actually Happens

Documented from official Hex.pm docs and mix hex.publish reference:

**At publish time:**
1. `mix hex.publish` inspects the unpacked artifact, shows files and deps, prompts for confirmation (skipped with `--yes`)
2. Authenticates with `HEX_API_KEY`; the authenticated user becomes the package owner
3. Package tarball uploaded to Hex.pm registry (immutable after the correction window)
4. `mix docs` is run and deployed to `hexdocs.pm/rindle/0.1.0`
5. `https://hexdocs.pm/rindle` redirects to the latest version automatically

**Correction windows:**
- First-ever package publish: revert or update within **24 hours** via `mix hex.publish --revert 0.1.0`
- Subsequent versions: **60 minutes** to replace/revert
- Documentation: can be republished anytime with `mix hex.publish docs`

**Post-publish verification steps the ecosystem expects:**
1. `hex.pm/packages/rindle` page appears with correct metadata, description, links
2. `hexdocs.pm/rindle` renders with all ExDoc extras (guides, README, CHANGELOG)
3. A fresh Phoenix app can add `{:rindle, "~> 0.1"}` to deps, `mix deps.get`, and compile without errors
4. The `public_verify` CI job passing is the automated form of this check

**Ownership:**
- Owner is the authenticated Hex.pm user who ran the publish
- Additional owners can be added: `mix hex.owner add rindle <other-user>`
- Transfer ownership: `mix hex.owner transfer rindle <org-or-user>`

**Pre-1.0 versioning contract (community expectation):**
- `0.x.y` means no stability guarantees; breaking changes are allowed on minor bumps
- Adopters are expected to pin to `"~> 0.1.0"` not `"~> 0.1"` for pre-1.0 packages
- The README already shows `{:rindle, "~> 0.1"}` — this is fine for attracting early adopters but the guides should note that patch-level pinning is safer for production

---

## API Ergonomics Audit — Current State vs Target

### Modules with @doc coverage gaps (all public defs, zero @doc annotations)

| Module | Public Functions | Status | Decision |
|--------|-----------------|--------|----------|
| Rindle.Storage.Local | 11 | No @doc on any | These are storage adapter implementations; the *behaviour* is public via Rindle.Storage. Adapters should be `@moduledoc false` (internal implementation). |
| Rindle.Storage.S3 | 11 | No @doc on any | Same as Local — internal implementation of Rindle.Storage behaviour. |
| Rindle.Storage.Capabilities | 5 | Has @spec, no @doc | Public helper — used by adopters building custom adapters. Needs @doc. |
| Rindle.Config | 4 | Has @spec, no @doc | Internal configuration access. Evaluate: public API or @moduledoc false? |
| Rindle.Security.Mime | 4 | Has @spec, no @doc | Used internally; adopters should not call directly. `@moduledoc false` is appropriate. |
| Rindle.Security.Filename | 1 | Has @spec, no @doc | Same as Mime — internal. `@moduledoc false`. |
| Rindle.Profile.Digest | 2 | Has @spec, no @doc | Internal; used by workers. `@moduledoc false`. |
| Domain schemas (changeset/1) | 3 | Has @spec, no @doc | Changesets are used by adopters writing custom insert paths; should have @doc. |
| Rindle.HTML | 1 | Has @spec, no @doc | Public helper; needs @doc for hexdocs. |
| Domain FSMs (variant, upload) | partial | Only asset_fsm has @doc | FSMs are internal state-machine logic; `@moduledoc false` is appropriate. |

### Naming patterns to audit

- `verify_upload/2` (completes a direct upload session) vs `complete_multipart_upload/3` (completes a multipart session) — vocabulary inconsistency. Consider: should single-part be `complete_upload/2` for symmetry? This is a breaking rename, so decide now while adopters are zero.
- `store_variant/4` lives on the Rindle facade but is a diagnostic helper, not a primary lifecycle operation. Evaluate whether it belongs on the facade or should be internal.
- `log_variant_processing_failure/3` is on the Rindle facade — this is an internal observability utility, not adopter API. It should be moved or hidden with `@doc false`.

### Missing convenience functions (adopter friction points)

- `Rindle.attachment_for(owner, slot)` — returns `{:ok, attachment} | {:error, :not_found}`. Adopters need this constantly (render the avatar, show the document); currently requires writing raw Ecto queries.
- `Rindle.ready_variants_for(asset)` — returns a list of `%MediaVariant{}` in `:ready` state. Required for rendering `picture_tag` with populated variants; currently requires raw Ecto.
- Bang variants: `attach!/4`, `detach!/3`, `upload!/3`, `url!/3`, `variant_url!/4`. The non-bang forms return `{:ok, _} | {:error, _}`; bang counterparts raise on error and are idiomatic Elixir for happy-path code.

---

## Competitor / Reference Library Patterns Observed

**Ecto:** Every public function in Ecto.Repo has @doc with a full description and examples. Changeset functions have @doc. Internal helpers have @moduledoc false.

**Oban:** Public-facing modules (Oban, Oban.Job, Oban.Worker) are fully documented; internal engine modules (Oban.Engine, queue supervisors) have `@moduledoc false`.

**Shrine (Ruby):** Reference for Rindle's architecture. Provides explicit "convenience" methods for attachment presence/absence checks that delegates to underlying data.

**Spatie Media Library (PHP):** Reference for day-two ergonomics. Provides `getFirstMedia`, `getMedia`, `hasMedia` — all convenience query wrappers that save adopters from writing manual queries.

The pattern is consistent: facade clean, internals hidden, bang variants present, convenience helpers for the 3–5 most common adopter access patterns.

---

## Sources

- [Hex.pm publish documentation](https://hex.pm/docs/publish) — official canonical publish steps
- [mix hex.publish task reference](https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html) — options, correction windows, dry-run
- [Hex.pm FAQ](https://hex.pm/docs/faq) — ownership, revert windows, immutability policy
- [Elixir Library Guidelines](https://hexdocs.pm/elixir/library-guidelines.html) — versioning, dependency policy, formatting
- [Elixir Naming Conventions](https://hexdocs.pm/elixir/naming-conventions.html) — snake_case, bang, predicate, get/fetch/fetch! patterns
- [Writing Documentation](https://hexdocs.pm/elixir/writing-documentation.html) — @doc, @moduledoc, @typedoc expectations, @doc false for internals
- [Elixir Compatibility and Deprecations](https://hexdocs.pm/elixir/compatibility-and-deprecations.html) — soft/hard deprecation, removal policy

---

*Feature research for: Rindle v1.3 — First Live Hex Publish & API Ergonomics*
*Researched: 2026-04-29*
