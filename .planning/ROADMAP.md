# Roadmap: Rindle

## Milestones

- ✅ **v1.23 Postgres Schema Isolation** — Phases 117–120 (shipped 2026-08-20, Hex 0.4.0, 12/12 requirements, 4/4 verified phases; [archive](milestones/v1.23-ROADMAP.md), [requirements](milestones/v1.23-REQUIREMENTS.md), [audit](milestones/v1.23-MILESTONE-AUDIT.md))
- ✅ **v1.22 OSS Quality & Trust Hardening** — Phases 113–116 (shipped 2026-07-02; [archive](milestones/v1.22-ROADMAP.md), [requirements](milestones/v1.22-REQUIREMENTS.md), [audit](milestones/v1.22-MILESTONE-AUDIT.md))
- ✅ **v1.21 CI/DX Reliability Tail** — Phases 108–112 (shipped 2026-06-29; [archive](milestones/v1.21-ROADMAP.md), [requirements](milestones/v1.21-REQUIREMENTS.md), [audit](milestones/v1.21-MILESTONE-AUDIT.md))
- ✅ **v1.20 CI/CD Performance** — Phases 103–107 (shipped 2026-06-22; [archive](milestones/v1.20-ROADMAP.md), [requirements](milestones/v1.20-REQUIREMENTS.md), [audit](milestones/v1.20-MILESTONE-AUDIT.md))
- ✅ **v1.19 Design-System Stress-Test** — Phases 94–102 (shipped 2026-06-19; [archive](milestones/v1.19-ROADMAP.md), [audit](milestones/v1.19-MILESTONE-AUDIT.md))
- ✅ **v1.18 Admin Console & Adoption Lab** — Phases 86–93 (shipped 2026-06-20; [archive](milestones/v1.18-ROADMAP.md), [requirements](milestones/v1.18-REQUIREMENTS.md), [audit](milestones/v1.18-MILESTONE-AUDIT.md))
- ✅ **b1.0 Brand Foundations** — Phases 81–85 (shipped 2026-06-10; [archive](milestones/b1.0-ROADMAP.md), [audit](milestones/b1.0-MILESTONE-AUDIT.md))
- ✅ **v1.17 Adopter-Confidence Hygiene** — Phases 78–80 (shipped 2026-05-27; [archive](milestones/v1.17-ROADMAP.md), [audit](milestones/v1.17-MILESTONE-AUDIT.md))
- ✅ **v1.16 CI Enforcement & Planning Hygiene** — Phases 75–77 (shipped 2026-05-27; [archive](milestones/v1.16-ROADMAP.md))
- ✅ **v1.15 Maintenance & Proof Honesty** — Phases 71–74 (shipped 2026-05-27; [audit](milestones/v1.15-MILESTONE-AUDIT.md))
- ✅ **v1.14 Bulk Owner-Erasure Orchestration** — Phases 67–70 (shipped 2026-05-27; [archive](milestones/v1.14-ROADMAP.md))
- ✅ **v1.13 Cancel Direct Upload** — Phases 64–66 (shipped 2026-05-27; [archive](milestones/v1.13-ROADMAP.md))
- ✅ **v1.12 Adopter Truth & Maintenance Hygiene** — Phases 60–63 (shipped 2026-05-27; [archive](milestones/v1.12-ROADMAP.md))
- ✅ **v1.11 Tus Protocol Completion** — Phases 56–59 (shipped 2026-05-27; [archive](milestones/v1.11-ROADMAP.md))
- ✅ **v1.10 Owner Account Erasure** — Phases 53–55 (shipped 2026-05-26; [archive](milestones/v1.10-ROADMAP.md))
- ✅ **v1.9 Phoenix Tus DX Completion** — Phases 48–52 (shipped 2026-05-25; [archive](milestones/v1.9-ROADMAP.md))
- ✅ **v1.8 Resumable Browser Ingest** — Phases 42–47 (shipped 2026-05-25; [archive](milestones/v1.8-ROADMAP.md))
- ✅ **v1.7 GCS Resumable Adapter** — Phases 37–41 (shipped 2026-05-08; [archive](milestones/v1.7-ROADMAP.md))
- ✅ **v1.6 Provider Boundary + Mux** — Phases 33–36 (shipped 2026-05-07; [archive](milestones/v1.6-ROADMAP.md))
- ✅ **v1.5 Adopter Hardening & Lifecycle Repair** — Phases 29–32 (shipped 2026-05-06; [archive](milestones/v1.5-ROADMAP.md))
- ✅ **v1.4 Video & Audio Wedge** — Phases 23–28 (shipped 2026-05-05; [archive](milestones/v1.4-ROADMAP.md))
- ✅ **v1.3 Live Publish & API Ergonomics** — Phases 15–22 (shipped 2026-05-02; [archive](milestones/v1.3-ROADMAP.md))
- ✅ **v1.2 First Hex Publish** — Phases 10–14 (shipped 2026-04-29; [archive](milestones/v1.2-ROADMAP.md))
- ✅ **v1.1 Adopter Hardening** — Phases 6–9 (shipped 2026-04-28; [archive](milestones/v1.1-ROADMAP.md))
- ✅ **v1.0 MVP** — Phases 1–5 (shipped 2026-04; [archive](milestones/v1.0-ROADMAP.md))

## Phases

<details>
<summary>✅ v1.23 Postgres Schema Isolation (Phases 117–120) — SHIPPED 2026-08-20</summary>

Rindle 0.4.0 isolates its six domain tables and migration marker in `rindle` by default, retains an
explicit `public` compatibility build, provides a bounded host-owned populated-install move and guarded
reverse, keeps Oban and the host migration ledger independent, and proves the contract through packed
generated apps, Cohort, operational diagnostics, documentation parity, exact-source CI, and the public
Hex artifact.

- [x] Phase 117: Prefix Routing Architecture (5/5 plans) — completed 2026-08-08
- [x] Phase 118: Isolated Migration & Safe Upgrade (6/6 plans) — completed 2026-08-09
- [x] Phase 119: Ownership Boundaries & Diagnostics (5/5 plans) — completed 2026-08-09
- [x] Phase 120: Adoption Proof & Release Truth (14/14 plans) — completed 2026-08-20

Archive: [milestones/v1.23-ROADMAP.md](milestones/v1.23-ROADMAP.md); requirements:
[milestones/v1.23-REQUIREMENTS.md](milestones/v1.23-REQUIREMENTS.md); audit:
[milestones/v1.23-MILESTONE-AUDIT.md](milestones/v1.23-MILESTONE-AUDIT.md).

</details>

Historical phase detail is retained in the milestone archives linked above.

## Demand-Gated Pause

There is no approved post-v1.23 feature milestone. Default to release-train maintenance and silence on
the wire until a qualifying signal exists:

- **LIFE-06** — a compliance/legal ticket for force-deleting still-shared assets, or
- **STREAM-10** — a named adopter for a second streaming provider.

Resolved in post-v1.23 cleanup: `test/install_smoke/release_docs_parity_test.exs` now derives the active
version from the release manifest, requires `mix.exs` and the generated changelog heading to agree, and
separately preserves the historical 0.4.0 schema-isolation contract (cleanup PR #68).

## Deferred to a Demand-Gated Milestone

- Force-delete semantics for still-shared assets (LIFE-06) — compliance pull only.
- Second streaming provider (Cloudflare/Bunny) — explicit adopter demand only.
- IETF RUFH / tus 2.0; GCS-as-tus-backend / R2-native tus proxying.
- Rindle-owned standalone tus JS client package and richer uploader abstractions.
- Signed dynamic image transforms and explicit original EXIF/GPS stripping.
- `mix test --partitions` parallelization — evidence-gated on measured core starvation (DEFER-02).

## Backlog

_(empty — no open backlog items)_

---
*Last updated: 2026-08-22 — reconciled the completed post-v1.23 cleanup through public rindle 0.4.2. No active milestone; release-train maintenance and demand-gated pause remain the default.*
