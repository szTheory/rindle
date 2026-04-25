# GSD Bootstrap Research Index (Rindle)

## Purpose

This index is the source map for the Rindle bootstrap context pack.
It records what research inputs were used, where they live, and what signal each source contributed.

Use this file when you want to validate claims in:

- `prompts/gsd-rindle-elixir-oss-dna.md`
- `prompts/gsd-rindle-gsd-bootstrap-brief.md`
- `prompts/gsd-rindle-bootstrap-command.md`

## Primary Seed Research (Rindle)

### 1) Brand and product posture

- `prompts/rindle-brand-book.md`
- Contribution:
  - Core value proposition and voice ("calm, explicit, production-aware")
  - Domain language defaults (asset, attachment, variant, recipe, lifecycle)
  - UX/copy principles, status language, and anti-hype constraints
  - Security posture phrasing and "strict defaults, explicit escape hatches"

### 2) Deep media architecture research

- `prompts/phoenix-media-uploads-lib-deep-research.md`
- Contribution:
  - Domain model for post-upload lifecycle (session -> staged -> validated -> attached -> processed -> delivered)
  - Ecosystem and prior-art lessons (Active Storage, Shrine, Spatie, Cloudinary/imgproxy, Uppy/tus, provider differences)
  - Footguns and mitigations (lazy variant DoS, multipart cost leaks, purge-in-transaction, race conditions)
  - Suggested schema, telemetry, adapter boundaries, and phased rollout strategy

## Recent OSS Elixir Repos (GitHub + Local)

Selection rule: public, non-fork repos under `szTheory` with primary language `Elixir`.

| Repo | Updated At (UTC) | GitHub | Local Path |
| --- | --- | --- | --- |
| sigra | 2026-04-24T12:27:34Z | https://github.com/szTheory/sigra | `/Users/jon/projects/sigra` |
| lockspire | 2026-04-24T09:18:17Z | https://github.com/szTheory/lockspire | `/Users/jon/projects/lockspire` |
| accrue | 2026-04-24T08:52:53Z | https://github.com/szTheory/accrue | `/Users/jon/projects/accrue` |
| mailglass | 2026-04-24T08:29:08Z | https://github.com/szTheory/mailglass | `/Users/jon/projects/mailglass` |
| threadline | 2026-04-24T03:04:37Z | https://github.com/szTheory/threadline | `/Users/jon/projects/threadline` |
| rulestead | 2026-04-24T03:11:33Z | https://github.com/szTheory/rulestead | `/Users/jon/projects/rulestead` |
| kiln | 2026-04-24T03:00:01Z | https://github.com/szTheory/kiln | `/Users/jon/projects/kiln` |
| scrypath | 2026-04-24T02:57:52Z | https://github.com/szTheory/scrypath | `/Users/jon/projects/scrypath` |
| lattice_stripe | 2026-04-17T01:18:34Z | https://github.com/szTheory/lattice_stripe | `/Users/jon/projects/lattice_stripe` |

## Cross-Repo Artifact Classes Mined

All nine repos include `.planning/` and `.github/workflows/`.

### Planning truth surfaces

Primary signals were mined from:

- `.planning/PROJECT.md` (core value, key decisions, non-goals, prior-art lessons)
- `.planning/ROADMAP.md` (phase sequencing, explicit pitfall controls, success criteria)
- `.planning/STATE.md` (current truth, locked decisions, execution context)
- `.planning/RETROSPECTIVE.md` (top lessons and milestone-level operational learning)

### CI/CD and release signals

Primary signals were mined from:

- `.github/workflows/ci.yml`
- Release and publish workflows:
  - `release-please.yml`, `release.yml`, `publish-hex.yml`, `hex-publish.yml`, `verify-published-release.yml`
- Contract and quality patterns:
  - matrix testing, docs/contract gates, install/golden checks, workflow linting, dependency review, release parity verification

### Runtime/library design signals

Primary signals were mined from:

- `mix.exs` (version policy, aliases, package metadata, release posture)
- `lib/**/*.ex` in each repo:
  - transactional boundaries (`Ecto.Multi`, `Repo.transact/transaction`)
  - behavior seams (`@behaviour`)
  - config contracts (`NimbleOptions`)
  - telemetry architecture (`:telemetry.execute`, `:telemetry.span`, wrapper modules)
  - Ecto schema and changeset modeling patterns

### Maintainer and contributor docs

Primary signals were mined from:

- `README.md`, `CONTRIBUTING.md`, `MAINTAINING.md`, `SECURITY.md`, `CHANGELOG.md`
- Particularly for:
  - release discipline
  - CI truth statements
  - integration testing posture
  - explicit quality bars (`warnings-as-errors`, verify aliases)

## Repo-Level Evidence Pointers

### sigra

- Planning: `.planning/PROJECT.md`, `.planning/RETROSPECTIVE.md`, `.planning/MILESTONES.md`
- CI/Release: `.github/workflows/ci.yml`, `.github/workflows/release-please.yml`, `.github/workflows/hex-publish.yml`
- Docs: `MAINTAINING.md`, `CONTRIBUTING.md`, `README.md`
- Notable signal: install golden/idempotency contract discipline + GA evidence framing

### lockspire

- Planning: `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`
- CI/Release: `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `.github/workflows/dependency-review.yml`
- Docs: `README.md`, `SECURITY.md`
- Notable signal: protected release posture and explicit recovery-only manual publish path

### accrue

- Planning: `.planning/PROJECT.md`, `.planning/RETROSPECTIVE.md`, `.planning/ROADMAP.md`
- CI/Release: `.github/workflows/ci.yml`, `.github/workflows/release-please.yml`, `.github/workflows/publish-hex.yml`
- Runtime: `accrue/lib/accrue/**/*.ex` plus `accrue_admin/`
- Notable signal: Fake-first merge gates, extensive docs-contract verification, transaction + telemetry conventions

### mailglass

- Planning: `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`
- CI: `.github/workflows/ci.yml`
- Runtime: `lib/mailglass/**/*.ex`, `mailglass_admin/`
- Notable signal: explicit pitfall ledger in roadmap + strict telemetry/PII and optional-dependency discipline

### threadline

- Planning: `.planning/PROJECT.md`, `.planning/RETROSPECTIVE.md`, `.planning/ROADMAP.md`
- CI/Release: `.github/workflows/ci.yml`, `.github/workflows/hex-publish.yml`
- Runtime: `lib/threadline/**/*.ex`
- Notable signal: verify-task topology as first-class CI contract + brownfield realism framing

### rulestead

- Planning: `.planning/PROJECT.md`, `.planning/STATE.md`, `.planning/ROADMAP.md`
- CI/Release: `.github/workflows/ci.yml`, `.github/workflows/release-please.yml`, `.github/workflows/publish-hex.yml`
- Runtime: `rulestead/lib/rulestead/**/*.ex`, `rulestead_admin/`
- Notable signal: lock decisions early, encode policy into custom Credo checks, and keep release surfaces disciplined

### kiln

- Planning: `.planning/PROJECT.md`, `.planning/RETROSPECTIVE.md`, `.planning/ROADMAP.md`
- CI: `.github/workflows/ci.yml`, `.github/workflows/docker_operator.yml`
- Runtime: `lib/kiln/**/*.ex`
- Notable signal: bounded autonomy, explicit operator observability, and host-vs-CI truth honesty

### scrypath

- Planning: `.planning/PROJECT.md`, `.planning/RETROSPECTIVE.md`, `.planning/ROADMAP.md`
- CI/Release: `.github/workflows/ci.yml`, `.github/workflows/release-please.yml`, `.github/workflows/publish-hex.yml`, `.github/workflows/verify-published-release.yml`
- Runtime: `lib/scrypath/**/*.ex`, `scrypath_ops/`
- Notable signal: phase-scoped verify tasks and release parity/post-publish verification as standard operating procedure

### lattice_stripe

- Planning: `.planning/PROJECT.md`, `.planning/STATE.md`, `.planning/v1.1-accrue-context.md`
- CI/Release: `.github/workflows/ci.yml`, `.github/workflows/release.yml`
- Runtime: `lib/lattice_stripe/**/*.ex`
- Notable signal: API stability explicitness, behavior seams, and production-grade client ergonomics

## What This Index Enables

- Traceability from synthesized "DNA" claims back to concrete source artifacts.
- Fast handoff into `/gsd-new-project --auto` with context rooted in prior successful OSS patterns.
- Re-runs: if source repos evolve, this file is the checklist for refresh.
