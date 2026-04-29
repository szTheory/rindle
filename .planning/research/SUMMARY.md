# Project Research Summary

**Project:** Rindle v1.3 — Live Hex Publish and API Ergonomics
**Domain:** Elixir library — first live Hex.pm publish execution + pre-1.0 API surface audit
**Researched:** 2026-04-29
**Confidence:** HIGH

## Executive Summary

Rindle v1.3 covers two distinct but sequentially ordered tracks: executing the first real publish to Hex.pm using the already-complete release automation, and auditing and tightening the public API surface before adoption grows. The existing stack (Elixir/Phoenix/Ecto, Oban, ExDoc, Credo, Dialyxir, GitHub Actions with a protected `release` environment) is validated and carries forward unchanged. The only new tooling addition is `doctor ~> 0.22.0` for `@doc`/`@spec` coverage thresholds — the single gap not covered by Credo, Dialyxir, or ExDoc.

The recommended approach is strict phase sequencing: publish `0.1.0` first to claim the package name and validate the end-to-end pipeline, then run the API audit as a separate step. Publishing with API gaps is normal for a `0.x.y` release. What is not normal — and the primary risk — is running the API review simultaneously with publish and shipping breaking changes in the same or next patch version. The pre-1.0 semver convention in the Elixir community treats minor bumps as the effective breaking-change vehicle; patch versions must be safe for adopters who pin `~> 0.1.0`.

The key operational risk is the publish correction window: new packages have a 24-hour revert window, subsequent versions only 1 hour. The first 60 minutes post-publish must be treated as a hot observation period with rollback steps immediately accessible. The API audit risk is scope creep: an over-broad review produces a breaking-change flood in `v0.2.0` that destroys adopter trust faster than it improves ergonomics. Both risks are preventable with explicit phase gates and a focused audit scope.

## Key Findings

### Stack Additions

The existing stack requires no new runtime or CI dependencies for the publish track. The release pipeline is already fully wired. The only operational action is changing `@version "0.1.0-dev"` to `"0.1.0"`, committing, and pushing a `v0.1.0` tag. For the API ergonomics track, `doctor ~> 0.22.0` fills the coverage gap that Credo, Dialyxir, and ExDoc each leave open.

**Core technologies (new or clarified role):**
- `mix hex.publish --yes` (Hex 2.4.1): live publish with `HEX_API_KEY`; no new tooling required
- `mix hex.build --unpack`: required pre-publish gate; verifies tarball contents before live push
- `mix hex.publish --revert VERSION`: rollback within 24h (first publish) or 1h (subsequent)
- `mix hex.package diff VERSION1 VERSION2`: post-release audit workflow for breaking-change detection
- `doctor ~> 0.22.0` (dev only): `@doc`/`@spec`/`@moduledoc` coverage with per-module thresholds; fills the gap Credo and Dialyxir leave
- Credo `~> 1.7` (existing): `@moduledoc` presence, naming conventions
- Dialyxir `~> 1.4` (existing): spec correctness; does NOT flag missing specs
- ExDoc `~> 0.40` (existing): broken doc references; does NOT flag missing `@doc`

### Feature Table Stakes

**Publish track (P1):** Version bumped to `0.1.0`; `HEX_API_KEY` in `release` environment; `CHANGELOG.md` with 0.1.0 entry; CI green on tagged commit; Hex.pm email confirmed; `rindle` name verified available; `public_verify` job passing.

**API ergonomics track (P1):** `@doc` on all intentionally public modules; `@moduledoc false` / `@doc false` on internal modules (Storage.Local, Storage.S3, Security.*, Profile.Digest, domain FSMs) applied before the documentation sprint; breaking-change determination before `0.1.0` ships.

**Should have (P2):** Naming audit resolving `verify_upload/2` vs `complete_multipart_upload/3` vocabulary inconsistency; `attachment_for/2`, `ready_variants_for/1` convenience helpers; bang variants `attach!/4`, `detach!/3`, `upload!/3`, `url!/3`, `variant_url!/4`; `@spec` tightening from `map()`/`term()` to named struct types (must happen before `0.1.0` — narrowing after publish is a breaking change for Dialyzer users).

**Defer to post-v1.3:** CHANGELOG automation; full Dialyzer clean pass; `Rindle.Ops.*` promotion decision.

### Watch Out For

1. **One-hour correction window closes before you notice a problem** — treat the first 60 minutes post-publish as a hot observation period; run `mix hex.build --unpack` as a required CI gate; keep `mix hex.publish --revert 0.1.0` in the runbook with tested syntax ready before the tag is pushed

2. **API review runs simultaneously with publish, breaking changes ship in a patch version** — publish first, confirm stability, then run the review as a separate milestone phase; any rename affecting published signatures belongs in `v0.2.0` not `v0.1.x`

3. **Internal modules accidentally promoted to public API during the `@doc` sprint** — apply `@doc false` / `@moduledoc false` to all internal modules before adding any documentation; the boundary audit is a named phase task, not an afterthought

4. **`@spec` types left too broad before first publish** — narrowing from `map()` to `MediaAsset.t()` after `0.1.0` is a Dialyzer-level breaking change; tighten before the tag push

5. **Package metadata locked permanently after the correction window** — verify `:description`, `:licenses` (SPDX), `:links` (all URLs resolvable), and package name as a named pre-publish checklist step

## Implications for Roadmap

### Phase A: Publish Preflight and CI Integrity
**Rationale:** CI must be green on the exact commit to be tagged; de-risks live publish by ensuring dry-run path is clean first.
**Delivers:** Green CI on the release candidate; all preflight gates passing; metadata reviewed; CHANGELOG.md created; `rindle` name verified on Hex.pm.
**Addresses:** PUBLISH-02; Pitfalls 4 and 5.

### Phase B: Live Publish Execution
**Rationale:** Once CI is clean, version bump and tag push are minimal mechanical steps. Must happen before any rename work to claim the name.
**Delivers:** `rindle 0.1.0` live on Hex.pm; `hexdocs.pm/rindle` resolving; `public_verify` passing; runbook updated.
**Addresses:** PUBLISH-01, PUBLISH-03.

### Phase C: API Surface Boundary Audit
**Rationale:** The public-vs-internal boundary must be locked before any documentation is written. Adding `@doc` to internal modules first makes them permanent public API.
**Delivers:** All internal modules marked `@moduledoc false`/`@doc false`; public surface list finalized; naming inconsistencies resolved or explicitly deferred to `v0.2.0`; `@spec` types tightened.
**Addresses:** API-01, API-04.

### Phase D: Documentation and Spec Coverage
**Rationale:** With the boundary locked, the documentation sprint is safe. Doctor enforces thresholds in CI.
**Delivers:** `doctor ~> 0.22.0` added to `mix.exs` and CI; `@doc` on all public modules; `mix doctor --raise` passing.
**Addresses:** API-03.

### Phase E: Convenience API Additions
**Rationale:** Additive-only work; comes after the boundary audit so new additions land in the correct classification.
**Delivers:** `attachment_for/2`, `ready_variants_for/1`; bang variants; all documented and spec'd.
**Addresses:** API-02.

### Phase Ordering Rationale
- Preflight before publish: a failed first publish wastes a version slot and creates an immutable bad record on Hex.pm.
- Publish before API review: package name claimed on first publish; pre-1.0 `0.x.y` semantics explicitly allow iteration.
- Boundary audit before documentation sprint: writing `@doc` to all `def` without first auditing intent permanently expands public surface to internal helpers.
- Spec tightening before `0.1.0`: narrowing return types after any public release is a Dialyzer breaking change regardless of semver version.
- Additive convenience work last: benefits from naming decisions made during boundary audit.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Official Hex.pm docs, official Elixir library guidelines, Context7-verified |
| Features | HIGH | Publish mechanics from official Hex.pm docs; API ergonomics from official Elixir guides and live codebase inspection |
| Architecture | HIGH | Derived from live codebase inspection of `lib/`, `scripts/`, `.github/workflows/` — no inference |
| Pitfalls | HIGH | Official Hex docs, official Elixir design anti-patterns guide, library guidelines |

**Overall confidence:** HIGH

### Gaps to Address
- **`Rindle.Config` public-vs-internal decision:** Phase C must make an explicit call — document as public API or mark `@moduledoc false`. Product decision, not a research gap.
- **`Rindle.Ops.*` surface decision:** whether ops helpers should be directly callable by adopters is deferred to Phase C.
- **One-time human steps before first tag:** Hex.pm email confirmation and `rindle` package name availability cannot be validated by CI; must be verified manually before any tag is pushed.

## Sources

- https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html — flags, correction windows
- https://hex.pm/docs/publish — `HEX_API_KEY`, owner assignment
- https://hex.pm/docs/faq — immutability policy, revert windows
- https://hex.pm/packages/doctor and https://github.com/akoutmos/doctor — doctor 0.22.0
- https://hexdocs.pm/elixir/library-guidelines.html — naming, docs, dependency policy
- https://hexdocs.pm/elixir/writing-documentation.html — `@doc false` conventions
- https://hexdocs.pm/elixir/design-anti-patterns.html — `Application.get_env` in libraries
- Live codebase inspection: `lib/`, `scripts/`, `.github/workflows/`, `mix.exs`

---
*Research completed: 2026-04-29*
*Ready for roadmap: yes*
