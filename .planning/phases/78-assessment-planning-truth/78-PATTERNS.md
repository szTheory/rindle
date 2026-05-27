# Phase 78: Assessment & Planning Truth — Pattern Map

**Phase:** 78 - Assessment & Planning Truth  
**Generated:** 2026-05-27  
**Files analyzed:** 8 modified (6 primary + 2 plan outputs)  
**Analogs found:** 6 / 8 (Phase 77 plan artifacts archived; Phase 14 + 70-02 substitute)

---

## Data Flow Overview

```
.github/workflows/ci.yml  ──┐
RUNNING.md (CI severity)  ──┼──► evidence ladder (read-only for Phase 78)
                            │
                            ▼
.planning/threads/2026-05-27-post-v116-milestone-assessment.md
.planning/threads/2026-05-27-path-to-done-roadmap.md
                            │
                            ├──► .planning/JTBD-MAP.md (anchor + gap rank)
                            │
                            └──► .planning/PROJECT.md
                                 .planning/STATE.md
                                 .planning/REQUIREMENTS.md (traceability)
                                 .planning/ROADMAP.md (verify-only)
```

**Rule:** `ci.yml` > `RUNNING.md` `## CI lane severity` > planning threads. Phase 78 edits threads and charter docs only — no `ci.yml` / `RUNNING.md` policy changes (Phase 79 / CI-04).

---

## Files to Create/Modify

| File | Role | Data Flow | Wave | Closest Analog | Match Quality |
|------|------|-----------|------|----------------|---------------|
| `.planning/threads/2026-05-27-post-v116-milestone-assessment.md` | canonical post-v1.16 assessment thread | downstream of ci.yml/RUNNING.md; upstream to JTBD gap rank | 1 | assessment L107–115 Open concerns (already correct) | exact (same file) |
| `.planning/threads/2026-05-27-path-to-done-roadmap.md` | multi-milestone ordering thread | cross-links assessment + JTBD; doc drift checklist | 1 | path-to-done L28 CI proof honesty row | partial |
| `.planning/JTBD-MAP.md` | JTBD inventory + anchor | anchor ← git HEAD; gap rank ← assessment wedge #1 | 2 | JTBD L172–175 "What changed" entry pattern | exact |
| `.planning/PROJECT.md` | milestone charter | demand-gate vocabulary → STATE/ROADMAP/REQUIREMENTS | 2 | REQUIREMENTS.md L31 v1.18+ wording | partial |
| `.planning/STATE.md` | live position block | reflects Phase 78 progress + v1.17 active | 2 | v1.16 Phase 77 goal (STATE position cleanup) | structural |
| `.planning/REQUIREMENTS.md` | traceability table | TRUTH-06/PLAN-02 Pending → Complete | 2 (optional) | Phase 14 requirement closure pattern | partial |
| `78-01-PLAN.md` | Wave 1 execute plan | TRUTH-06 thread edits | — | `70-02-PLAN.md` (docs truth + grep verify) | format |
| `78-02-PLAN.md` | Wave 2 execute plan | PLAN-02 anchor + charter + closure grep | — | `14-01-PLAN.md` (planning hygiene doc-edit) | format |

### Read-Only (verification sources — do not edit)

| File | Role in Phase 78 |
|------|------------------|
| `.github/workflows/ci.yml` | merge-blocking vs `continue-on-error` evidence |
| `RUNNING.md` | `## CI lane severity` matrix (L14–36) |
| `.planning/ROADMAP.md` | success criteria reference (already aligned) |
| `.planning/milestones/v1.16-ROADMAP.md` | v1.16 shipped boundary |
| `.planning/milestones/v1.16-REQUIREMENTS.md` | PLAN-02 anchor traceability |

### Phase 77 analog note

`77-01-PLAN.md` is **not present** in the repo (Phase 77 completed; artifacts archived per ROADMAP). Closest substitutes:

- **Hygiene posture:** v1.16-ROADMAP.md Phase 77 — docs-only, zero `ci.yml` conflict, STATE position block
- **Document-edit + grep closure:** Phase 14 (`14-PATTERNS.md`, `14-01-PLAN.md`)
- **Support-truth grep tasks:** Phase 70-02 (`70-02-PLAN.md` TRUTH-03)

---

## Pattern Assignments

### `.planning/threads/2026-05-27-post-v116-milestone-assessment.md`

**Analog:** same file L107–115 (Open concerns — CI proof honesty, fixed in `9384191`)

**Edit targets (TRUTH-06):**

| Location | Current stale phrase | Action |
|----------|---------------------|--------|
| L30 Proof & CI row | `default mix test still advisory via Coveralls` | Replace with merge-blocking coveralls + advisory Credo/Doctor/Dialyzer split; cite `ci.yml` + `RUNNING.md` |
| L62–63 Rough edges | `does not guarantee full unit/Credo/Dialyzer pass` | Split: unit blocking via coveralls; static analysis advisory |
| L69 wedge #1 | `Done 2026-05-27` (premature) | `In progress — v1.17 Phase 78` until grep passes; flip to Done after Wave 2 |
| L81–82 Optional micro | `optional CI unit-suite blocking` | Branch C active; unit blocking shipped `0036760`; Phase 79 owns Credo/Dialyzer decision |

**Do not regress:** L107–115 Open concerns (already cites `RUNNING.md` and `ci.yml`).

**Correct citation pattern (analog excerpt — L109–113):**

```markdown
Merge-blocking lanes now include `proof`, `package-consumer`, `adopter`, `integration`,
`contract` (AV hygiene), and **`quality` — Run tests with coverage** (`mix coveralls`,
2026-05-27). **Advisory:** Credo, Doctor, Dialyzer in `quality` job. Release workflow can
bypass CI on timeout/failure (`gate-ci-green` BYPASSED). See `RUNNING.md` and
`.github/workflows/ci.yml`.
```

**Recommended L30 replacement (from 78-RESEARCH.md):**

```markdown
| Proof / CI | Merge-blocking: `proof` job, `package-consumer`, `adopter`, `integration`, `contract` AV hygiene, and `quality` — Run tests with coverage (`mix coveralls`; both matrix cells). Advisory in `quality`: Credo, Doctor, AV doctor, Dialyzer (`continue-on-error: true` in `.github/workflows/ci.yml`). See `RUNNING.md` `## CI lane severity`. |
```

---

### `.planning/threads/2026-05-27-path-to-done-roadmap.md`

**Analog:** same file L28 (CI proof honesty row — already correct)

**Edit targets (D-02):**

| Location | Action |
|----------|--------|
| L31–33 Doc drift note | Replace open drift list with **resolved** note after assessment L30/L63/L81–82 fixed |
| L50–56 Milestone 0 | Resequence: v1.17 Branch C active (Phases 78–79); Milestone 0 = default after v1.17 |
| L58 v1.17 conditional | Record Branch C **selected** (maintainer choice 2026-05-27) |
| L102–110 Branch C | Split Phase 78 (factual thread truth) vs Phase 79 (CI-04 policy decision) |
| L173–174 Verdict | Align with PROJECT.md: v1.17 hygiene in flight, then pause unless LIFE-06/STREAM-10 |

**Correct CI row pattern (analog excerpt — L28):**

```markdown
| CI proof honesty | **Maintenance wedge closed** | `mix coveralls` merge-blocking; Credo/Dialyzer advisory (`ci.yml`); `proof` job merge-blocking |
```

**Doc drift note target state:**

```markdown
**Doc drift note (resolved 2026-05-27, Phase 78):** post-v116 assessment CI severity
wording aligned with `ci.yml` and `RUNNING.md` `## CI lane severity`. Credo/Dialyzer
merge-blocking **decision** deferred to Phase 79 (CI-04).
```

---

### `.planning/JTBD-MAP.md`

**Analog:** L172–175 existing "What changed since last generation" entry

**Edit targets (PLAN-02 / D-03, D-04):**

| Location | Action |
|----------|--------|
| L3 anchor line | Refresh git sha `3dbf7ab` → current HEAD; keep milestone v1.16, hex 0.1.5 |
| L127–128 gap rank #1 | "Post-v1.16 hygiene complete" → in progress until TRUTH-06 grep passes |
| L165+ What changed | Append v1.17 planning-only delta entry (no new JTBD rows) |

**Anchor line pattern (L3 — update sha only):**

```markdown
> **Generated:** 2026-05-27 · **Against:** milestone v1.16 (shipped 2026-05-27) · **hex** 0.1.5 · **git** `<HEAD>`
```

**Update protocol (read before edit — L17–33):**

```markdown
1. Read the **anchor** line at the top (`Against: <milestone> · git <sha>`).
2. Compute the delta since the anchor:
   - `git log <anchor-sha>..HEAD --oneline`
   ...
6. **Do not** mirror to `guides/user_flows.md` — no user-visible job changes.
```

**Delta check (must pass before anchor refresh):**

```bash
git log 3dbf7ab..HEAD --oneline -- lib/ guides/ CHANGELOG.md mix.exs
# expect empty — planning/docs/ci-hygiene only
```

**What changed entry template:**

```markdown
- **2026-05-27 — v1.17 planning-only delta (Phase 78).** Anchor sha refreshed;
  no new JTBD rows. Delta: coveralls merge-blocking (`0036760`), v1.17 milestone
  charter, post-v116 thread TRUTH-06 closure. Gap rank #1 hygiene wording tracks
  Phase 78 completion.
```

---

### `.planning/PROJECT.md`

**Analog:** REQUIREMENTS.md L31 (`v1.18+` demand-gate vocabulary)

**Edit target:** L341 — `Deferred to v1.17+` → `Deferred to v1.18+` for LIFE-06/STREAM-10

**Target vocabulary (cross-artifact):**

- **v1.17:** Adopter-Confidence Hygiene (Branch C) — Phases 78–79, hygiene-only
- **v1.18+:** LIFE-06 force-delete, STREAM-10 second provider — demand-gated

---

### `.planning/STATE.md`

**Analog:** v1.16-ROADMAP.md Phase 77 success criterion #3 — STATE position reflects shipped milestone

**Edit targets (G-01):** L5, L27–29 — replace "Defining requirements" / "Not started" with Phase 78 in progress (or awaiting plan completion)

**Target shape:**

```markdown
Phase: 78 — Assessment & Planning Truth
Plan: —
Status: In progress
Last activity: 2026-05-27 — Phase 78 planning truth closure
```

---

### `.planning/REQUIREMENTS.md` (optional, end of phase)

**Analog:** Phase 14 traceability closure

**Edit targets:** L54–55 — TRUTH-06 and PLAN-02 Pending → Complete after verification gate passes

---

## Plan File Structure (two-wave grouping)

```
78-01-PLAN.md  — Wave 1: assessment + path-to-done TRUTH-06 edits
78-02-PLAN.md  — Wave 2: JTBD anchor + PROJECT/STATE/JTBD consistency + grep closure
```

Matches v1.16 Phase 77 hygiene pattern (docs-only waves) and isolates grep verification as explicit Wave 2 closure.

---

## Task XML Format (from prior PLAN.md files)

### Plan frontmatter (70-01-PLAN.md)

```yaml
---
id: 78-01
plan_number: 01
plan: 01
phase: 78
type: execute
wave: 1
depends_on: []
files_modified:
  - .planning/threads/2026-05-27-post-v116-milestone-assessment.md
  - .planning/threads/2026-05-27-path-to-done-roadmap.md
autonomous: true
requirements: [TRUTH-06]
requirements_addressed: [TRUTH-06]
tags: [planning, threads, ci-truth, hygiene]

must_haves:
  truths:
    - "Assessment L30/L63/L81–82 describe coveralls merge-blocking and advisory static analysis with ci.yml + RUNNING.md citations"
    - "Wedge #1 shows in-progress until TRUTH-06 grep audit passes"
    - "Path-to-done doc drift note marked resolved after assessment fixes"
  artifacts:
    - path: ".planning/threads/2026-05-27-post-v116-milestone-assessment.md"
      provides: "Canonical post-v1.16 CI severity truth"
      contains: "mix coveralls"
---
```

### Task block with grep verify (70-02-PLAN.md pattern — adapt for planning markdown)

```xml
<task type="auto">
  <name>Task 1: Fix assessment Proof & CI row and Rough edges (L30, L62–63)</name>
  <read_first>
    - .github/workflows/ci.yml (L94–113, L131–133)
    - RUNNING.md (## CI lane severity L20–36)
    - .planning/threads/2026-05-27-post-v116-milestone-assessment.md (L30, L62–63, L107–115 analog)
    - .planning/phases/78-assessment-planning-truth/78-CONTEXT.md (D-01)
    - .planning/phases/78-assessment-planning-truth/78-RESEARCH.md (stale location inventory)
  </read_first>
  <files>.planning/threads/2026-05-27-post-v116-milestone-assessment.md</files>
  <action>
    Patch L30 Proof & CI table row and L62–63 Rough edges paragraph per 78-RESEARCH.md
    recommended replacements. Every CI severity claim must cite `.github/workflows/ci.yml`
    and/or `RUNNING.md`. Do not edit L107–115 Open concerns (regression guard).
  </action>
  <acceptance_criteria>
    - `! rg -i 'mix test still advisory|still advisory via Coveralls' .planning/threads/2026-05-27-post-v116-milestone-assessment.md`
    - `! rg 'does not guarantee full unit/Credo/Dialyzer pass' .planning/threads/2026-05-27-post-v116-milestone-assessment.md`
    - `rg '\.github/workflows/ci\.yml|RUNNING\.md' .planning/threads/2026-05-27-post-v116-milestone-assessment.md`
  </acceptance_criteria>
  <verify>
    <automated>! rg -i 'mix test still advisory|still advisory via Coveralls' .planning/threads/2026-05-27-post-v116-milestone-assessment.md && rg '\.github/workflows/ci\.yml|RUNNING\.md' .planning/threads/2026-05-27-post-v116-milestone-assessment.md</automated>
  </verify>
</task>
```

### Task block with git delta verify (70-01-PLAN.md acceptance_criteria style)

```xml
<task type="auto">
  <name>Task 2: Refresh JTBD anchor sha and append What changed entry</name>
  <read_first>
    - .planning/JTBD-MAP.md (L3 anchor, L17–33 protocol, L165+ history)
    - .planning/phases/78-assessment-planning-truth/78-CONTEXT.md (D-03, D-04)
  </read_first>
  <files>.planning/JTBD-MAP.md</files>
  <action>
    Run `git log 3dbf7ab..HEAD --oneline -- lib/ guides/ CHANGELOG.md mix.exs` — confirm empty.
    Refresh L3 git sha to `git rev-parse --short HEAD`. Append v1.17 planning-only delta
    to What changed. Do NOT full JTBD regen. Do NOT edit guides/user_flows.md.
  </action>
  <acceptance_criteria>
    - Anchor line git sha matches `git rev-parse --short HEAD`
    - `git log 3dbf7ab..HEAD --oneline -- lib/ guides/ CHANGELOG.md mix.exs` exits 0 with no output
    - `rg 'v1\.17 planning' .planning/JTBD-MAP.md`
  </acceptance_criteria>
  <verify>
    <automated>test "$(rg -o 'git `[^`]+`' .planning/JTBD-MAP.md | head -1 | tr -d '`git ')" = "$(git rev-parse --short HEAD)"</automated>
  </verify>
</task>
```

### Plan-level verification block (70-01-PLAN.md L294–299)

```xml
<verification>
After all tasks:
- Forbidden phrase grep audit zero matches in `.planning/threads/`
- JTBD anchor sha = HEAD; lib/guides delta empty
- Manual read checklist 7/7 (TRUTH-06) + 6/6 (PLAN-02) from 78-RESEARCH.md
</verification>
```

### Document-edit task pattern (14-01-PLAN.md — planning hygiene)

```xml
<task type="auto">
  <name>Task 1: Update STATE position block for Phase 78 in progress</name>
  <files>.planning/STATE.md</files>
  <read_first>
    - .planning/STATE.md (L27–29 current stale block)
    - .planning/ROADMAP.md (Phase 78 goal L26–39)
    - .planning/milestones/v1.16-ROADMAP.md (Phase 77 STATE cleanup analog)
  </read_first>
  <action>
    Make EXACTLY the position-block edits per 78-RESEARCH.md G-01. Do not modify
    demand-gated deferred table (L56–57 already correct for coveralls).
  </action>
  <acceptance_criteria>
    - STATE.md Current Position does not contain "Defining requirements" or "Not started"
    - STATE.md references Phase 78 or v1.17 in-progress hygiene
  </acceptance_criteria>
  <verify>
    <automated>! rg 'Defining requirements|Phase: Not started' .planning/STATE.md</automated>
  </verify>
</task>
```

---

## Grep Verification Patterns

### TRUTH-06 — forbidden phrases (expect ZERO matches after Wave 1)

From `78-RESEARCH.md` § Validation Architecture; mapped in `78-VALIDATION.md`:

```bash
# Primary forbidden patterns
rg -i 'mix test still advisory|still advisory via Coveralls|optional CI unit-suite blocking|unit tests advisory' \
  .planning/threads/

# Undifferentiated rough-edge claim
rg 'does not guarantee full unit/Credo/Dialyzer pass' .planning/threads/

# Close variants
rg -i 'coveralls.*advisory|default.*mix test.*advisory' .planning/threads/
```

### TRUTH-06 — required citations (expect matches in both thread files)

```bash
rg '\.github/workflows/ci\.yml|RUNNING\.md' \
  .planning/threads/2026-05-27-post-v116-milestone-assessment.md \
  .planning/threads/2026-05-27-path-to-done-roadmap.md
```

### PLAN-02 — JTBD anchor

```bash
head -3 .planning/JTBD-MAP.md
git rev-parse --short HEAD

git log 3dbf7ab..HEAD --oneline -- lib/ guides/ CHANGELOG.md mix.exs
# expect empty

rg 'v1\.17 planning' .planning/JTBD-MAP.md
```

### PLAN-02 — charter consistency

```bash
rg 'v1\.18\+' .planning/PROJECT.md .planning/STATE.md .planning/ROADMAP.md .planning/REQUIREMENTS.md

rg 'Deferred to v1\.17\+' .planning/PROJECT.md
# expect zero after G-02 fix
```

### Per-task verify one-liners (78-VALIDATION.md task map)

| Task ID | Automated Command |
|---------|-------------------|
| 78-01-01 | `rg -i 'mix test still advisory\|still advisory via Coveralls' .planning/threads/` |
| 78-01-02 | `rg 'does not guarantee full unit/Credo/Dialyzer pass' .planning/threads/` |
| 78-01-03 | `rg -i 'optional CI unit-suite blocking' .planning/threads/` |
| 78-01-04 | `rg '\.github/workflows/ci\.yml\|RUNNING\.md' .planning/threads/2026-05-27-post-v116-milestone-assessment.md` |
| 78-02-01 | `head -3 .planning/JTBD-MAP.md && git rev-parse --short HEAD` |
| 78-02-02 | `git log 3dbf7ab..HEAD --oneline -- lib/ guides/ CHANGELOG.md mix.exs` |
| 78-02-03 | `rg 'v1\.18\+' .planning/PROJECT.md .planning/STATE.md .planning/ROADMAP.md` |
| 78-02-04 | Manual read checklist from 78-RESEARCH.md § Validation Architecture |

### ci.yml spot-check table (maintainer 30-second audit)

| Claim in threads | ci.yml line |
|------------------|-------------|
| coveralls merge-blocking | L112–113 (no `continue-on-error`) |
| Credo advisory | L97–99 |
| Doctor advisory | L101–103 |
| Dialyzer advisory | L131–133 |
| proof merge-blocking | L357–361 |
| contract ExUnit advisory | L295–297 |

### Phase completion gate

| Requirement | Gate |
|-------------|------|
| TRUTH-06 | All forbidden grep patterns zero; manual checklist 7/7; wedge #1 may flip to Done |
| PLAN-02 | JTBD anchor sha = HEAD; empty lib/guides delta; G-01–G-07 closed; charter grep clean |

---

## Shared Patterns

### Evidence ladder (78-CONTEXT.md)

**Source:** `.github/workflows/ci.yml` > `RUNNING.md` > planning threads  
**Apply to:** All thread CI severity edits; never infer severity from thread prose alone

### Forbidden-phrase grep closure (Phase 70-02 TRUTH-03 analog)

**Source:** `70-02-PLAN.md` Task 1 acceptance_criteria — `grep -q` / `! grep -q` pairs  
**Apply to:** Phase 78 uses `rg` on `.planning/threads/` instead of `guides/`; same red/green semantics

```markdown
- `grep -q 'bulk orchestration' guides/user_flows.md` returns exit 1 (phrase removed)
```

Phase 78 equivalent:

```bash
rg -i 'optional CI unit-suite blocking' .planning/threads/
# expect exit 1 (zero matches) after fix
```

### Wedge status honesty (D-05)

**Source:** assessment ranked-wedge table  
**Apply to:** Mark Done only after TRUTH-06 grep passes — not on partial doc commits (`7c547ab` lesson)

### Scope guardrails (D-07)

No edits to: `.github/workflows/ci.yml`, `RUNNING.md` Credo/Dialyzer policy, `lib/`

---

## Analog Excerpts

### ci.yml merge-blocking coveralls (L112–113)

```yaml
      - name: Run tests with coverage
        run: mix coveralls
```

(No `continue-on-error: true` — removed in commit `0036760`.)

### ci.yml advisory static analysis (L97–99)

```yaml
      - name: Credo (strict)
        run: mix credo --strict
        continue-on-error: true
```

### RUNNING.md severity row (L26)

```markdown
| `quality` — Run tests with coverage | merge-blocking | Same job | Default `mix test` suite via Coveralls; both matrix cells must pass |
```

### Phase 70-02 grep verify block (docs truth — structural analog)

```xml
  <acceptance_criteria>
    - `grep -q 'Batch owner erasure' guides/user_flows.md`
    - `grep -q 'bulk orchestration' guides/user_flows.md` returns exit 1 (phrase removed)
  </acceptance_criteria>
  <verify>
    <automated>grep -q 'Batch owner erasure' guides/user_flows.md && ! grep -q 'bulk orchestration' guides/user_flows.md</automated>
  </verify>
```

### Phase 14 planning hygiene posture

Pure `.planning/` document-edit; no `lib/` changes; verification via field/grep checks against authoritative evidence files.

---

## No Analog Found

| File | Gap | Mitigation |
|------|-----|------------|
| `77-01-PLAN.md` | Referenced in CONTEXT but not in repo | Use v1.16-ROADMAP Phase 77 goal + Phase 14/70-02 substitutes |
| `.planning/threads/*` exact stale-phrase fix | No prior phase edited post-v116 threads | Use in-file L107–115 + 78-RESEARCH recommended replacements |

---

## Metadata

**Analog search scope:** `.planning/milestones/`, `.planning/phases/`, `.planning/threads/`, prior `*-PLAN.md` / `*-PATTERNS.md`  
**Strongest analogs:** assessment L107–115 (CI citation); Phase 70-02 (grep verify); Phase 14 (planning doc-edit); v1.16 Phase 77 goal (STATE hygiene)  
**Pattern extraction date:** 2026-05-27

## PATTERN MAPPING COMPLETE
