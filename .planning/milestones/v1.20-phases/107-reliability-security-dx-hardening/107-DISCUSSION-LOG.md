# Phase 107: Reliability, Security & DX Hardening - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-22
**Phase:** 107-reliability-security-dx-hardening
**Areas discussed:** Partitioning (HARD-01), Pin breadth (HARD-02), Repro fidelity (HARD-04), Badge + contrast (HARD-03/04)

---

## Partitioning (HARD-01)

| Option | Description | Selected |
|--------|-------------|----------|
| Guard + async only, defer partitions | Land async-safety static guard, convert verified-safe modules to async:true; defer `--partitions` (test job ~140s/184s p95 is not a long pole; 2–4-core runners). | ✓ |
| Also adopt --partitions now | Wire DB-per-partition + merged coverage into the PR test lane in addition to async:true. | |

**User's choice:** Guard + async only, defer partitions
**Notes:** Evidence-backed by the Phase 103 baseline (Quality ~140s avg / 184s p95, already under the ≤7-min budget). Partition infra (`MIX_TEST_PARTITION`) already exists in `config/test.exs`, so a future enable is low-lift. → D-01/D-02.

---

## Pin breadth (HARD-02)

| Option | Description | Selected |
|--------|-------------|----------|
| Pin ALL actions, grouped dependabot | Pin every `uses:` (incl. first-party `actions/*`) to immutable SHAs with version comments; dependabot for github-actions + mix, grouped, weekly. | ✓ |
| Third-party only | Pin only non-GitHub actions; leave `actions/*` on tags. | |

**User's choice:** Pin ALL actions, grouped dependabot
**Notes:** Uniform, auditable rule over a non-uniform carve-out; dependabot keeps the SHAs current. → D-03/D-04 (+ D-05 mix_audit, D-06 least-privilege permissions).

---

## Repro fidelity (HARD-04)

| Option | Description | Selected |
|--------|-------------|----------|
| Both CI + local on pinned container | Move CI's E2E lane + `e2e_local.sh` onto the same pinned `mcr.microsoft.com/playwright` image for true byte parity. | ✓ |
| Local script only; pin CI to match | Keep CI on `npx`-install but pin exact version + fonts; local script reproduces it. | |

**User's choice:** Both CI + local on pinned container
**Notes:** A repro is only "faithful" if both sides share the exact image; kills the "green in CI, red locally" class by construction. E2E lane is nightly/push-only, so no PR-critical-path impact. → D-10/D-11.

---

## Badge + contrast (HARD-03/04)

| Option | Description | Selected |
|--------|-------------|----------|
| Workflow badge + single 4.5 AA constant | Keep the `ci.yml` workflow-run badge (reflects the `CI Summary`-gated run); reconcile contrast to one shared 4.5:1 WCAG-AA constant in a single module. | ✓ |
| Discuss these separately | Treat badge mechanism + contrast constant value/location as open deep-dives. | |

**User's choice:** Workflow badge + single 4.5 AA constant
**Notes:** GitHub has no native per-check badge; the workflow-run badge already reflects the gated run. One 4.5:1 constant imported by both the token-pair gates and the runtime polish gate. → D-09/D-12.

---

## Claude's Discretion

- Async-safety guard mechanism + exact unsafe-primitive inventory; which conservatively-`async: false` modules are actually convertible (phase research flag).
- Exact SHA values + version-comment format; optional `npm` dependabot ecosystem for the demo.
- `mix_audit` dep environment + gating-vs-advisory placement.
- Exact `mix ci` task list + local MinIO handling.
- Playwright container tag/distro + font package list.
- Shared-constant module location/name/export shape.

## Deferred Ideas

- `--partitions` / DB-per-partition / merged coverage (HARD-01) — deferred per D-01.
- `npm` dependabot ecosystem for `examples/adoption_demo` — optional, planner's discretion.
- Custom per-check `CI Summary` badge endpoint — rejected (D-09).
- Milestone deferrals carried in REQUIREMENTS.md: DEFER-01 (flaky-quarantine lane),
  DEFER-02 (larger runners), DEFER-03 (property-based/nightly expansion).
