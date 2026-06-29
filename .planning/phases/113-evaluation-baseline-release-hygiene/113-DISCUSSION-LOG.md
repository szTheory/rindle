# Phase 113: Evaluation Baseline & Release Hygiene - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-29
**Phase:** 113-evaluation-baseline-release-hygiene
**Areas discussed:** 0.3.2 release mechanism, EVAL-01 summary home & shape, Reconciliation breadth

**Mode:** Research-driven one-shot. User selected all three gray areas and directed deep parallel
subagent research (pros/cons/tradeoffs, Elixir/Hex ecosystem idiom, sibling-repo + cross-ecosystem
lessons, DX/footguns) to produce locked, mutually-coherent recommendations rather than an interview.

---

## 0.3.2 release mechanism (+ root-cause depth)

| Option | Description | Selected |
|--------|-------------|----------|
| A. Rotate token, let release-please cut 0.3.2 naturally | Fix the credential root cause; canonical pipeline resumes; no hand-edited versioned files | ✓ |
| B. Hand-author the release-please release PR | Manually bump mix.exs/manifest/CHANGELOG in the bot's exact shape | |
| C. Out-of-band `mix hex.publish` | Fastest raw unblock; bypasses the green-on-SHA gate (rejected) | |

**User's choice:** Option A (research recommendation, accepted).
**Notes:** Root cause confirmed from Action logs — `release.yml` `Release Please` job 401'd with
`release-please failed: Bad credentials` (run 28399407429); the `RELEASE_PLEASE_TOKEN` PAT expired
2026-06-26→29 and the `secrets.RELEASE_PLEASE_TOKEN || github.token` fallback does not engage for a
present-but-invalid secret. Locked add-ons: a release-train drift guard + a token-validity guard (both
off the required `CI Summary` path); record root cause in RELEASE-TRAIN.md + release_publish.md; fix the
separate 0.3.1 `public_smoke.sh` junit-write failure. Token rotation is a human/maintainer action — the
cut is gated on it.

---

## EVAL-01 summary home & shape

| Option | Description | Selected |
|--------|-------------|----------|
| `.planning/milestones/v1.22-OSS-QUALITY-EVAL.md` | Milestone-tier, maintainer-facing, archived with milestone, stable ref for 114/115/116 | ✓ |
| `.planning/research/` memo | For ecosystem/candidate research, not milestone self-assessment | |
| `.planning/` top-level / phase-113-scoped | Floats un-archived / wrong altitude for a milestone-spanning work-list | |

**User's choice:** milestone-tier doc (research recommendation, accepted).
**Notes:** ~1 page, two scored tables (weak/strong dims) with inline evidence cells + weakness→closing-phase
column mapped byte-faithfully to REQUIREMENTS.md. Scores lifted from SEED-005 recon (not re-derived).
Mirror `v1.21-MILESTONE-AUDIT.md` `## Scorecard` format. Footguns: scope-bloat back toward the 36-dim
report, vanity scoring without cites, dimension→phase drift. Prior art: OpenSSF Scorecard/Best-Practices
Badge (score + evidence per item), CHAOSS (resist over-modeling).

---

## Reconciliation breadth

| Option | Description | Selected |
|--------|-------------|----------|
| Tight: 3 live surfaces only | PROJECT.md + MILESTONES.md + RETROSPECTIVE.md; leave archive/forward-plans/memory | ✓ |
| Broad: sweep all 24 `0.3.2` hits | Would rewrite archived milestone history (falsifies the snapshot) | |

**User's choice:** tight sweep (research recommendation, accepted).
**Notes:** ~20 of 24 hits are archived history (accurate-as-of-date) or already-correct forward-plan prose —
leave them. Canonical reconciliation sentence locked for verbatim reuse. Sequence: investigate → cut/publish
→ THEN commit truth edits in the same phase commit (never pre-write "0.3.2 is live"). SEED-003/004
frontmatter → `status: consumed` + `consumed`/`consumed_by` companion fields (SEED-002 precedent).

---

## Claude's Discretion

- Exact line wording/formatting of the EVAL doc and the reconciliation edits (within locked structures).
- Exact YAML shape of the drift + token-validity guard workflows (match sibling `verify-published-release.yml`
  idiom; keep both off the required `CI Summary` path).

## Deferred Ideas

- Split `Public Verify` into Hex-index/hexdocs-reachability vs tarball↔tag source-parity (scrypath pattern).
- Adopt sibling evidence-tag legend (`[VERIFIED]`/`[CITED]`/`[ASSUMED]`) in planning audits.
- All later-phase v1.22 work (114 governance, 115 versioning/README, 116 `Rindle.Migration`) and the
  breaking v1.23 schema flip — out of phase 113.
