---
id: SEED-005
status: promoted
planted: 2026-06-29
planted_during: post-v1.21 — maintainer's combined software-quality / CI-perf / deps / PG-schema prompt batch
promoted_to: v1.22 OSS Quality & Trust Hardening (chartered 2026-06-29) + v1.23 Postgres Schema Isolation
trigger_when: "Already promoted. The non-feature signal for the v1.22→v1.23 quality-consolidation arc — settle the OSS project down (trust/governance/positioning) and make Rindle a respectful database guest before more feature work. Surface analogs whenever scope touches OSS adoption polish, host-app respectfulness, or migration/upgrade ergonomics."
scope: Large (two milestones)
---

# SEED-005: Software-quality consolidation arc (v1.22 trust hardening → v1.23 schema isolation)

## Why This Matters

After v1.21 the maintainer asked to **settle things down and get software quality up** before more
feature work, via a batch of five prompts: a 36-dimension software-quality evaluation, a CI/CD
performance audit, a request to bump optional szTheory peer deps, and a decision to move Rindle's DB
tables into a dedicated Postgres **schema by default** — with the meta-ask "plan the next 1–3
milestones, group this however makes sense."

Parallel read-only recon (3 Explore agents + 1 design pass, 2026-06-29) turned the batch into a focused
**two-milestone arc** and corrected two false premises:

- **szTheory dep bumps → empty.** Rindle depends on **zero** szTheory-owned packages; nothing to bump.
  (Sibling-adoption, e.g. `oban_powertools`, is a separate future question.)
- **CI/CD performance → already done** by v1.20 (SEED-003) + v1.21 (SEED-004). The pasted audit prompt
  *is* SEED-003. Only deferred lever is `mix test --partitions`, gated on measuring core-starvation.

The weak dimensions the recon actually found (5=strong): **OSS governance/trust 2/5** (no SECURITY.md,
CODE_OF_CONDUCT, issue/PR templates; thin Hex `package.links`; no `maintainers`), **versioning/path-to-1.0
2/5** (no stated SemVer / pre-1.0 policy), **README positioning 2.5/5** (AV-heavy first-run, no "when not
to use"), and **host-app respectfulness 3.5/5** — whose one real gap is the Postgres schema issue (all 6
domain tables land in the host's `public` schema; Rindle even creates `oban_jobs` itself). Already-strong,
left alone: telemetry 5/5, docs/ExDoc IA 4.5/5, public API + `Rindle.Error` 4/5, CI/testing.

## The Arc

- **v1.22 — OSS Quality & Trust Hardening** (low-risk, ships 0.3.x): scored-weakness summary; SECURITY.md
  / CODE_OF_CONDUCT / issue+PR templates; Hex `package.links` (Changelog/Docs) + `maintainers`; stated
  SemVer/pre-1.0 policy + generalized upgrade guide; image-first skimmable README + "when not to use";
  the versioned `Rindle.Migration.up/1`+`down/1` module (Oban-style) replacing the raw 15-file install
  path and decoupling `oban_jobs` creation; release-hygiene (cut the stuck 0.3.2; fix stale seed frontmatter).
- **v1.23 — Postgres Schema Isolation** (breaking → 0.4.0): `rindle` schema by default via config-driven
  `@schema_prefix` (covers ~99% of ~180 query sites + 45 multis automatically — Rindle uses no
  `assoc`/`build_assoc`); 4 manual escapes (2 raw-SQL `runtime_checks.ex` lines + 2 Oban-binding queries);
  one-line `prefix: "public"` opt-out + `ALTER TABLE … SET SCHEMA` move migration.

## Release-hygiene finding (confirmed 2026-06-29)

**Hex 0.3.2 was never published.** Hex live = 0.3.1; `mix.exs`/manifest/CHANGELOG all = 0.3.1. The v1.21
`lib/` fixes (`fix(109-01)` `:epipe` absorb, `fix(110-01..04)` config override) plus 3 `feat`/6 `fix`
commits are merged to `main` but **unreleased** — no `release rindle 0.3.2` commit, no open release-please
PR. PROJECT.md's "ships as Hex 0.3.2" is aspirational. v1.22 HYGIENE must cut 0.3.2 and reconcile the claim.

## Related

- [[SEED-003]] — CI/CD performance audit → v1.20 (the pasted audit prompt; already shipped).
- [[SEED-004]] — `:epipe` double-suite-run flake → v1.21 (already shipped).
- [[reference_release_please_autopublish]] — green main auto-publishes; stalls if a release PR keeps
  `autorelease: pending`. Relevant to the unreleased-0.3.2 finding.
- Full roadmap: `/Users/jon/.claude/plans/software-quality-evaluation-prompt-txt-gleaming-sifakis.md`.
