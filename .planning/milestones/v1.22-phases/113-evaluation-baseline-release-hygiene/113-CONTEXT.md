# Phase 113: Evaluation Baseline & Release Hygiene - Context

**Gathered:** 2026-06-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Open the v1.22 milestone honestly with three hardening deliverables — no new capabilities:

1. **EVAL-01** — a concise, evidence-cited *scored-weakness summary* of Rindle's OSS quality (the
   milestone's opening artifact) that phases 114/115/116 consume as a prioritized work-list. Right-sized
   (weak-dimension triage), NOT the full 36-dimension report.
2. **HYGIENE-01** — cut the stuck Hex **0.3.2** release so the merged-but-unreleased v1.21 `lib/` fixes
   (`:epipe` absorb, `$callers` config override) reach adopters; investigate & record *why* release-please
   never opened a 0.3.2 PR; reconcile the aspirational "ships as 0.3.2" planning claims with reality.
3. **HYGIENE-02** — correct stale `status: open` frontmatter on SEED-003 / SEED-004 to `consumed`.

**Scope anchor:** This is low-risk planning/release hygiene + one small workflow guard. NO `lib/` public-API
change beyond the (already-merged) v1.21 patches this phase merely *releases*. The breaking Postgres
schema flip is v1.23 (0.4.0) and is explicitly out of scope.
</domain>

<decisions>
## Implementation Decisions

All three gray areas were researched one-shot via parallel subagents (release-mechanism, EVAL-summary,
reconciliation-breadth). Recommendations are locked and mutually coherent — phase 113 = "open the
milestone honestly": EVAL-01 is the *map*, the HYGIENE edits are the *truth-correction*, the 0.3.2 cut is
the *action*. All three outputs sit at the milestone tier.

### EVAL-01 — Scored-weakness summary artifact

- **D-01 (home):** Write it to **`.planning/milestones/v1.22-OSS-QUALITY-EVAL.md`** — milestone-tier,
  maintainer-facing, archived with the milestone, stable path for 114/115/116 to reference. Use the bare
  `OSS-QUALITY-EVAL` noun, NOT `MILESTONE-AUDIT` (that name is reserved for the *closing* audit doc produced
  at v1.22 archive time by `gsd-audit-milestone` — avoid collision).
- **D-02 (shape):** ~1 page (1.5 max). Two scored tables (**weak dims v1.22 fixes** / **strong dims it does
  NOT touch**), each row carrying an **inline evidence cell** (a present file, a *named* absence, or a code
  path) + a **weakness→closing-phase** column mapped byte-faithfully to REQUIREMENTS.md traceability. Plus a
  one-line headline verdict ("engineering strong / project-surface weak"), a scope/method note, and an
  explicit "out of this milestone" block (the strong dims + the deferred v1.23 schema flip). Scores are 1–5
  (5=strong), lifted from the SEED-005 recon — do NOT re-derive them. Full skeleton in the research output;
  reuse the dimension→phase mapping below.
- **D-03 (mapping — must match REQUIREMENTS.md exactly):**
  governance/trust 2/5 → **114** (TRUST-01/02/03, META-01/02); versioning/path-to-1.0 2/5 → **115**
  (VERSION-01/02); README positioning 2.5/5 → **115** (README-01/02); host-app respectfulness 3.5/5 →
  **116** substrate (MIGRATE-01/02), with the **breaking schema flip explicitly deferred to v1.23** so a
  reader doesn't expect it in v1.22. Strong/untouched: telemetry 5/5, docs/ExDoc IA 4.5/5, public API +
  `Rindle.Error` 4/5, CI/testing.
- **House-style note:** match Rindle's own `.planning/milestones/v1.21-MILESTONE-AUDIT.md` `## Scorecard`
  table format + frontmatter for tone/length. (accrue's `176-SCORECARD.md` is the structural cousin but is
  ~590 lines/per-screen — borrow its scored-table+evidence shape only; stay ~1 page.)

### HYGIENE-01 — Cut the stuck 0.3.2 release

- **D-04 (ROOT CAUSE — confirmed from Action logs):** The `release.yml` push-triggered **`Release Please`
  job 401'd with `release-please failed: Bad credentials`** (run `28399407429`, 2026-06-29). Cause: the
  **`RELEASE_PLEASE_TOKEN` PAT expired** between 2026-06-26 (last good run `28265065628`, which "Found pull
  request #40") and 2026-06-29. Because `release.yml:54` is `token: ${{ secrets.RELEASE_PLEASE_TOKEN ||
  github.token }}`, a **non-empty-but-invalid** secret wins the `||` and the `github.token` fallback never
  engages — so every push run now 401s before it can open the 0.3.2 PR. This is the whole reason no
  `chore(main): release rindle 0.3.2` PR exists. (The `autorelease: pending` label stuck on merged PR #40
  is a cosmetic symptom of Rindle's split `skip-github-release: true` topology, NOT the blocker — 0.3.1 did
  fully publish. Config/path-filter/commit-type hypotheses ruled out.) *Planner should re-confirm via the
  Action run + repo secret settings; the fix is the same regardless of expired-vs-revoked.*
- **D-05 (mechanism — LOCKED = Option A):** **Rotate the token, then let release-please cut 0.3.2
  naturally.** Steps: (1) **[HUMAN/maintainer action — repo admin]** rotate `RELEASE_PLEASE_TOKEN` (fine-
  grained PAT or, preferred, a GitHub App installation token) with `contents:write` + `pull-requests:write`
  (+ `issues:write`); update the repo secret; (2) clear the stale label truthfully — `gh pr edit 40
  --remove-label "autorelease: pending" --add-label "autorelease: tagged"` (0.3.1 IS tagged+published); (3)
  the phase-113 push to `main` re-triggers `release.yml` → release-please opens `chore(main): release rindle
  0.3.2`; (4) let the canonical chain run (automerge → dispatch publish → `gate-ci-green` → Publish to Hex →
  Public Verify). **Reject** hand-authoring the release PR (Option B — fragile vs the automerge file-set/
  title guard) and **reject** out-of-band `mix hex.publish` (Option C — bypasses the green-on-SHA gate the
  maintainer guards; irreversible).
- **D-06 (recurrence guards — IN SCOPE, serve the TRUST/HYGIENE intent):** (a) **Release-train drift check**
  — a scheduled (daily cron) + PR-non-blocking job that fails / self-files an issue when `main` has
  `feat:`/`fix:` commits ahead of the last `rindle-v*` tag with NO open release PR. Model on
  scrypath/rulestead `verify-published-release.yml` cron + `JasonEtco/create-an-issue@v2`
  (`update_existing`, auto-close). Keep it OFF the `CI Summary` required path. No sibling has this — adopting
  it makes Rindle the reference impl. (b) **Token-validity guard** — an early step in the `Release Please`
  job that, when `RELEASE_PLEASE_TOKEN` is non-empty, validates it (`gh api user`) and **fails loudly**
  ("present but invalid — rotate it; `|| github.token` does NOT fall back for a bad token") instead of dying
  on an opaque `Bad credentials` deep in the action.
- **D-07 (record the root cause):** Append a dated Verification-Log row to **`.planning/RELEASE-TRAIN.md`**
  (symptom string, run URL, "rotated + added drift guard") AND a "stuck-release / expired-token" runbook
  entry to **`guides/release_publish.md`** (extend its existing "Recovery Workflow Contract", ~line 118).
- **D-08 (secondary finding — separate follow-up, do NOT couple to the 0.3.2 cut):** 0.3.1's post-publish
  `Public Verify` job **failed** (`scripts/public_smoke.sh`: `could not write to file
  _build/test/junit/rindle-junit.xml: bad argument` — junit path not writable in the clean-room). Fix
  `public_smoke.sh` *this phase* so 0.3.2's parity proof is green, but track it as its own item, not a
  precondition of cutting the release.
- **D-09 (release-coupling invariants):** Option A touches NO versioned source by hand and does NOT touch
  `ci.yml` / `name: CI` / `CI Summary` / the full-verification gate. Only edits: docs + one new
  non-required guard workflow. Safe — but the planner must keep it that way.

### HYGIENE-01 — Reconcile the "ships as 0.3.2" claim (truth sweep)

- **D-10 (scope — tight, 3 live surfaces only):** Edit ONLY the live planning truth: **`.planning/PROJECT.md`**
  (lines ~18–19 Current-State; ~405 v1.21 bullet; ~599 D-v1.21-01 decision row; and re-date/tense the
  existing "Release-state correction" block ~43–48 once the cut lands), **`.planning/MILESTONES.md`** (~line
  20 v1.21 stats), **`.planning/RETROSPECTIVE.md`** (~line 9). `PROJECT.md:814` is already correct — leave it.
- **D-11 (canonical reconciliation sentence — reuse verbatim across touched docs):**
  > Hex 0.3.2 (the two adopter-invisible v1.21 `lib/` `fix:` patches) was merged to `main` in v1.21 but
  > left unreleased — release-please never opened the 0.3.2 PR (Hex live was 0.3.1). v1.22 Phase 113
  > (HYGIENE-01) cut the stuck release; 0.3.2 is now live.

  Short form: "…→ Hex 0.3.2 (merged in v1.21, released in v1.22 Phase 113 — was merged-but-unreleased)."
- **D-12 (sequencing — load-bearing):** **Investigate → cut/publish → THEN commit the truth edits in the
  same phase-113 commit.** Do NOT pre-write "0.3.2 is now live" before release-please actually publishes, or
  the docs become a *new* lie. The `[0.3.2]` CHANGELOG entry + `mix.exs`/manifest bump are written by
  release-please itself (the mechanical cut), not by the truth-sweep.
- **D-13 (out-of-scope — deliberately leave):** Do NOT rewrite `.planning/milestones/v1.21-*` archive or
  `v1.21-phases/109/110` execution artifacts (~20 of the 24 `0.3.2` hits) — accurate-as-of-their-date;
  rewriting falsifies the historical snapshot that proves the gap happened. Forward-plan refs in
  STATE.md/ROADMAP.md/REQUIREMENTS.md/SEED-005 already say "never published / merged-but-unreleased / cuts
  the stuck release" — correct, leave them (optional future→past tense polish only). CHANGELOG `0.3.2` hits
  are `**104-03:**`-style false positives.

### HYGIENE-02 — SEED frontmatter

- **D-14:** Set `status: consumed` on SEED-003 and SEED-004 (canonical "done-after-ship" token, matches
  SEED-002 precedent; NOT `promoted`, which means "promoted into a charter"). Add companion fields after
  `planted_during:`:
  - SEED-003: `consumed: 2026-06-22` / `consumed_by: "v1.20 CI/CD Performance (chartered 2026-06-20, shipped
    2026-06-22; 18/18 reqs). Reliability tail continued as SEED-004 → v1.21."`
  - SEED-004: `consumed: 2026-06-29` / `consumed_by: "v1.21 CI/DX Reliability Tail (chartered 2026-06-26,
    shipped 2026-06-29; 24/24 reqs)."`

### Claude's Discretion
- Exact line wording/formatting of the EVAL doc and the doc edits — within the structures locked above.
- Exact workflow YAML shape of the drift + token-validity guards — match sibling `verify-published-release.yml`
  idiom; keep both off the required `CI Summary` path.

### Memory note (not a doc edit)
- Leave user-memory files as-is (they correctly say "0.3.2 never published" — true when written). OPTIONALLY
  append one dated line to `project_v1_22_quality_consolidation_arc.md` after the cut ("0.3.2 cut in Phase
  113 on <date>"). Append, never rewrite; do NOT edit the v1.21 memory file.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & requirements
- `.planning/ROADMAP.md` §"Phase 113" — goal, depends-on, 4 success criteria.
- `.planning/REQUIREMENTS.md` — EVAL-01, HYGIENE-01, HYGIENE-02 (+ the Out-of-Scope table and v1.23 ISO23 future reqs).
- `.planning/seeds/SEED-005-software-quality-consolidation.md` — the recon that produced the dimension
  scores (governance 2/5, versioning 2/5, README 2.5/5, host-respectfulness 3.5/5; strong: telemetry 5/5,
  docs 4.5/5, API 4/5) AND the "Release-hygiene finding" confirming 0.3.2 was never published. EVAL-01
  distills this; do NOT re-derive scores.

### Release pipeline (HYGIENE-01)
- `.github/workflows/release.yml` — esp. line **54** (`token: ${{ secrets.RELEASE_PLEASE_TOKEN ||
  github.token }}` — the footgun) and **57** (`skip-github-release: true` — split topology).
- `.github/workflows/release-please-automerge.yml` — automerge file-set + title guard (Option B fragility lives here).
- `guides/release_publish.md` §"Recovery Workflow Contract" (~line 118) — extend with the token-rotation runbook.
- `.planning/RELEASE-TRAIN.md` — maintainer ledger; append the root-cause Verification-Log row.
- `scripts/public_smoke.sh` — the post-publish `Public Verify` smoke (junit-write bug, D-08).
- `.planning/seeds/reference_release_please_autopublish` (user memory) — autopublish/`autorelease: pending` behavior.

### Truth-reconciliation targets (HYGIENE-01 / HYGIENE-02)
- `.planning/PROJECT.md` (lines ~18–19, ~43–48, ~405, ~599, ~814).
- `.planning/MILESTONES.md` (~line 20).
- `.planning/RETROSPECTIVE.md` (~line 9).
- `.planning/seeds/SEED-003-ci-cd-performance-audit.md` / `SEED-004-ci-epipe-double-suite-run-flake.md` (frontmatter line 3).

### EVAL-01 format precedent / house style
- `.planning/milestones/v1.21-MILESTONE-AUDIT.md` — `## Scorecard` table format + frontmatter to mirror.
- Sibling pattern refs (for the drift-guard workflow): `/Users/jon/projects/scrypath/.github/workflows/verify-published-release.yml`,
  `/Users/jon/projects/rulestead/.github/workflows/verify-published-release.yml`,
  `/Users/jon/projects/lockspire/docs/maintainer-release.md` (recovery-runbook prose).

### Brand/voice (light — for the EVAL doc's prose tone only)
- `prompts/rindle-brand-book.md` / `brandbook/brand.css` — "calm, explicit, production-aware", anti-hype.
  (Phase 113 is doc/release hygiene; brand applies only to the summary's voice, not UI.)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **release-please pipeline is intact, just credential-starved** — no pipeline rebuild needed; rotate the
  token and it resumes (`release.yml`, `release-please-automerge.yml`).
- **Sibling `verify-published-release.yml` (scrypath/rulestead)** — copy the cron + `JasonEtco/create-an-issue`
  self-filing-issue idiom for both the new drift guard and (later) parity checks.
- **`v1.21-MILESTONE-AUDIT.md` `## Scorecard`** — existing in-house scored-table format to mirror for EVAL-01.

### Established Patterns
- **Release-coupling invariants (NEVER violate):** `ci.yml` filename + `name: CI` byte-unchanged; `CI
  Summary` treats `skipped` as pass and is the sole required check; release full-verification gate not
  weakened. The new guard workflows MUST stay off the required path.
- **`secrets.X || github.token` footgun:** a present-but-invalid secret defeats the fallback. Guard against it (D-06b).
- **Planning truth is single-source + append-only:** live PROJECT.md/MILESTONES/RETROSPECTIVE are truth;
  archived `milestones/v1.XX-*` is history — never falsify it.

### Integration Points
- EVAL-01 → feeds 114/115/116 as the prioritized work-list (its dimension→phase column IS the contract).
- The 0.3.2 cut → unblocks adopters getting the v1.21 `:epipe`/`$callers` fixes.
</code_context>

<specifics>
## Specific Ideas

- **Human-in-the-loop dependency (flag to maintainer):** D-05 step (1) — rotating `RELEASE_PLEASE_TOKEN` is a
  repo-admin secret action Claude cannot perform. The 0.3.2 cut is BLOCKED until the maintainer rotates the
  token. The planner should structure phase 113 so the doc/EVAL/frontmatter work proceeds independently and
  the release-cut + truth-reconciliation edits are gated on (and sequenced after) the human token rotation +
  successful publish.
- Prefer migrating `RELEASE_PLEASE_TOKEN` to a **GitHub App installation token** (no expiry surprise) over
  another expiring PAT, if the maintainer is willing.
</specifics>

<deferred>
## Deferred Ideas

- **Split `Public Verify` into "Hex index/hexdocs reachability" vs "tarball↔tag source parity"** (scrypath
  does this) — so a parity failure is distinguishable from indexing delay. Beyond the D-08 junit fix; future DX polish.
- **Adopt sibling evidence-tag legend** (`[VERIFIED: path]` / `[CITED: url]` / `[ASSUMED: reason]`,
  rulestead) in planning audits — optional house-style upgrade, not required for EVAL-01.
- Everything v1.22-but-later-phase (governance docs → 114; versioning/README → 115; `Rindle.Migration` → 116)
  and the breaking schema flip → v1.23. Out of phase 113.

None of these are scope creep into phase 113 — they're tracked for their proper homes.
</deferred>

---

*Phase: 113-evaluation-baseline-release-hygiene*
*Context gathered: 2026-06-29*
