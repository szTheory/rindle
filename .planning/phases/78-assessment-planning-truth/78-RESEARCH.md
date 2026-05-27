# Phase 78: Assessment & Planning Truth — Research

**Researched:** 2026-05-27  
**Domain:** Planning-truth closure (TRUTH-06, PLAN-02) — `.planning/` markdown only  
**Confidence:** HIGH (repo-truth verified against live `ci.yml`, `RUNNING.md`, and git history)

<user_constraints>
## User Constraints (from 78-CONTEXT.md)

### Locked Decisions
- **D-01:** Patch three stale locations in post-v116 assessment (L30, L63, L81–82).
- **D-02:** Update path-to-done drift note after assessment fixes; defer Credo/Dialyzer **decision** to Phase 79.
- **D-03:** JTBD anchor stays at v1.16; refresh git sha from stale `3dbf7ab` to current HEAD.
- **D-04:** Run JTBD update protocol (delta check → anchor refresh → "What changed" entry); no full regen.
- **D-05:** Revert wedge #1 "Done 2026-05-27" to "In progress — v1.17 Phase 78" until TRUTH-06 grep passes.
- **D-06:** Close TRUTH-06 with grep audit + manual read against `RUNNING.md` `## CI lane severity`.
- **D-07:** No `ci.yml`, `RUNNING.md` policy, or `lib/` edits.

### Claude's Discretion
- Exact replacement wording (must match ci.yml/RUNNING.md facts).
- Path-to-done "drift resolved" note and JTBD "What changed" entry wording.
- Inline verification tasks vs maintainer checklist in PLAN.md.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **TRUTH-06** | Post-v116 assessment and path-to-done threads accurately describe CI severity — `mix coveralls` merge-blocking, `proof` merge-blocking — with no stale "unit tests advisory" claims; `ci.yml` cited as source of truth | Three confirmed stale phrases in assessment thread; path-to-done already documents them; Open concerns section (L107–115) is **already correct** after commit `9384191` |
| **PLAN-02** | JTBD-MAP anchor verified at v1.16 shipped boundary; PROJECT.md, STATE.md, ROADMAP.md reflect v1.17 charter and demand-gated LIFE-06 / STREAM-10 posture | Anchor sha stale; git delta is planning/docs/ci-hygiene only; minor PROJECT/STATE/path-to-done consistency gaps identified below |
</phase_requirements>

---

## Summary

Phase 78 is a **planning-artifact hygiene** phase with zero `lib/` surface. The CI wiring truth was settled in commit `0036760` (2026-05-27): `mix coveralls` lost `continue-on-error: true` in `.github/workflows/ci.yml` L112–113 and `RUNNING.md` L26 now reads **merge-blocking**. Partial thread updates landed in `9384191` (Open concerns) and `7c547ab` (premature wedge #1 "Done"), but **three upstream stale phrases remain** in the Done estimate table, Rough edges paragraph, and Optional micro milestone block — exactly where path-to-done documents them.

**Primary recommendation:** Two-wave plan — (1) thread TRUTH-06 edits + wedge status honesty, (2) JTBD anchor refresh + PROJECT/STATE/path-to-done/JTBD consistency pass + grep verification closure.

---

## 1. Technical Findings: ci.yml vs RUNNING.md vs Thread Drift

### Canonical CI severity (source of truth ladder)

**Order:** `.github/workflows/ci.yml` > `RUNNING.md` `## CI lane severity` > planning threads (methodology lens only).

#### `.github/workflows/ci.yml` — merge-blocking vs advisory

| Location | Step / job | Severity | Evidence |
|----------|------------|----------|----------|
| L88–89 | Compile, Check formatting | merge-blocking | No `continue-on-error` |
| L97–99 | Credo (strict) | advisory | `continue-on-error: true` |
| L101–103 | Doctor (full, raise) | advisory | `continue-on-error: true` |
| L105–110 | Verify AV runtime (public doctor) | advisory | `continue-on-error: true` |
| **L112–113** | **Run tests with coverage (`mix coveralls`)** | **merge-blocking** | **No `continue-on-error`** (removed in `0036760`) |
| L131–133 | Dialyzer | advisory | `continue-on-error: true` |
| L223–226 | integration tests | merge-blocking | No `continue-on-error` |
| L290–291 | contract AV hygiene gate | merge-blocking | No `continue-on-error` |
| L295–297 | contract tests (`--only contract`) | advisory | `continue-on-error: true` |
| L357–361 | proof (docs parity + batch erasure) | merge-blocking | No `continue-on-error` |
| L458–487 | package-consumer | merge-blocking | No `continue-on-error` |
| L582–583 | adopter lifecycle | merge-blocking | No `continue-on-error` |

Comments at L94–96 explicitly document the post-v1.16 policy:

```yaml
# Phase 71 (CI proof honesty): Credo, Doctor, AV doctor, and Dialyzer stay advisory.
# Default unit suite (mix coveralls) is merge-blocking (post-v1.16 assessment).
# See RUNNING.md `## CI lane severity` for the full matrix.
```

#### `RUNNING.md` — `## CI lane severity` (L14–36)

Matrix aligns with `ci.yml`. Key row for TRUTH-06:

| L26 | `quality` — Run tests with coverage | **merge-blocking** | Default `mix test` suite via Coveralls; both matrix cells must pass |

Advisory rows: Credo L23, Doctor L24, AV doctor L25, Dialyzer L27, contract ExUnit L30.

**Out of scope for Phase 78:** L38–43 release `gate-ci-green` bypass — explicitly deferred per REQUIREMENTS.md.

### Thread drift inventory (TRUTH-06 edit targets)

Path-to-done `.planning/threads/2026-05-27-path-to-done-roadmap.md` L31–33 correctly identifies three stale locations. Assessment thread `.planning/threads/2026-05-27-post-v116-milestone-assessment.md` state as of HEAD `25bcb44`:

#### Stale location 1 — Done estimate / Proof & CI row

**File:** `2026-05-27-post-v116-milestone-assessment.md` **L30**

**Current (wrong):**
```
| Proof / CI | v1.16 merge-blocking `proof` job; package-consumer/adopter/integration blocking; default `mix test` still advisory via Coveralls |
```

**Problem:** Contradicts `ci.yml` L112–113 and `RUNNING.md` L26. Commit `0036760` shipped merge-blocking coveralls; `9384191` fixed Open concerns (L107–115) but **not** this table row.

**Recommended replacement (factual, cites sources):**
```
| Proof / CI | Merge-blocking: `proof` job, `package-consumer`, `adopter`, `integration`, `contract` AV hygiene, and `quality` — Run tests with coverage (`mix coveralls`; both matrix cells). Advisory in `quality`: Credo, Doctor, AV doctor, Dialyzer (`continue-on-error: true` in `.github/workflows/ci.yml`). See `RUNNING.md` `## CI lane severity`. |
```

#### Stale location 2 — Rough edges

**File:** `2026-05-27-post-v116-milestone-assessment.md` **L62–63**

**Current (wrong):**
```
**Rough edges:** Streaming/tus need optional deps + webhook mount. TUS multi-node needs
sticky sessions. Green PR CI does not guarantee full unit/Credo/Dialyzer pass.
```

**Problem:** Undifferentiated blanket claim. Default unit suite **is** merge-blocking; only static analysis and contract ExUnit remain advisory.

**Recommended replacement:**
```
**Rough edges:** Streaming/tus need optional deps + webhook mount. TUS multi-node needs
sticky sessions. Green PR CI blocks on the default unit suite (`mix coveralls` in `quality`) but
Credo, Doctor, and Dialyzer remain advisory (`continue-on-error: true` in `.github/workflows/ci.yml`;
`RUNNING.md` `## CI lane severity`). Contract ExUnit (`--only contract`) is also advisory.
```

#### Stale location 3 — Optional micro milestone

**File:** `2026-05-27-post-v116-milestone-assessment.md` **L81–82**

**Current (wrong):**
```
**Optional micro milestone:** v1.17 Planning Truth & Adopter-Confidence — JTBD regen,
optional CI unit-suite blocking — **no new public API**.
```

**Problem:** "optional CI unit-suite blocking" shipped in `0036760`. v1.17 Branch C (now **active** on `main`) is planning-truth closure + deferred static-analysis policy (Phase 79 / CI-04), not optional unit blocking.

**Recommended replacement:**
```
**Active micro milestone (Branch C, 2026-05-27):** v1.17 Adopter-Confidence Hygiene —
planning-truth closure (Phase 78) and explicit Credo/Dialyzer policy record (Phase 79 / CI-04).
Default unit suite merge-blocking shipped in commit `0036760`. **No new public API.**
```

#### Already correct (do not regress)

**Open concerns — CI proof honesty (L107–115):** Updated in `9384191`. Correctly lists `mix coveralls` as merge-blocking and Credo/Doctor/Dialyzer as advisory; cites `RUNNING.md` and `ci.yml`. **Decision deferred** line correctly scoped to Credo/Dialyzer only (Phase 79).

**Ranked wedge #2 (L70):** Correct — "`mix coveralls` merge-blocking; Credo/Dialyzer still advisory".

#### Premature "Done" — wedge #1 (PLAN-02 / D-05)

**File:** `2026-05-27-post-v116-milestone-assessment.md` **L69**

**Current (premature):**
```
| 1 | Planning hygiene | IMPORTANT-BUT-NARROW | **Done 2026-05-27:** post-v116 thread, JTBD anchor v1.16; no feature surface |
```

**Problem:** Commit `7c547ab` marked Done before TRUTH-06 grep audit; REQUIREMENTS.md still shows TRUTH-06 Pending.

**Recommended replacement (during Phase 78):**
```
| 1 | Planning hygiene | IMPORTANT-BUT-NARROW | **In progress — v1.17 Phase 78:** thread CI truth + JTBD anchor refresh; no feature surface |
```

**After TRUTH-06 verification passes:** revert to **Done** with date.

### Path-to-done thread updates (D-02)

**File:** `.planning/threads/2026-05-27-path-to-done-roadmap.md`

| Location | Current | Action |
|----------|---------|--------|
| L31–33 Doc drift note | Lists 3 stale assessment locations | Replace with **resolved** note after L30/L63/L81–82 fixed; cite verification date |
| L28 CI proof honesty row | Already correct | Keep |
| L50–56 Milestone 0 "(current)" | Says "Demand-gated pause — DEFAULT" while v1.17 is active on `main` | Update: Milestone 0 → post-v1.17 default; v1.17 Branch C → **active (Phases 78–79)** |
| L58 | "Milestone v1.17 (conditional — pick ONE branch)" | Note Branch C **selected**; A/B remain demand-gated alternatives |
| L102–110 Branch C | Describes optional micro; lists Credo/Dialyzer decision | Split: Phase 78 = factual thread truth; Phase 79 = CI-04 policy decision |
| L173–174 Verdict | "stay in pause" | Align with PROJECT.md: v1.17 hygiene in flight, then pause unless LIFE-06/STREAM-10 |

### Forbidden phrases (grep audit targets)

After edits, **zero matches** in `.planning/threads/` for:

| Pattern | Current hits (pre-fix) |
|---------|------------------------|
| `mix test still advisory` | assessment L30 |
| `still advisory via Coveralls` | assessment L30 |
| `optional CI unit-suite blocking` | assessment L82 |
| `optional.*unit-suite blocking` | assessment L82 (regex) |
| `unit tests advisory` | none in threads (REQUIREMENTS.md mentions as forbidden example only) |
| `does not guarantee full unit/Credo/Dialyzer pass` | assessment L63 |

**Close variants to watch:**
- "default `mix test` … advisory"
- "Coveralls … advisory"
- "unit suite … optional"

### Required citations

Every CI severity claim in **both thread files** after edit must reference at least one of:
- `.github/workflows/ci.yml`
- `RUNNING.md` (prefer `## CI lane severity`)

The Open concerns section (L112–113) already models the pattern.

---

## 2. JTBD Anchor Verification Protocol (PLAN-02)

### Current anchor state

**File:** `.planning/JTBD-MAP.md` **L3**

```
> **Generated:** 2026-05-27 · **Against:** milestone v1.16 (shipped 2026-05-27) · **hex** 0.1.5 · **git** `3dbf7ab`
```

| Field | Current | Should be after Phase 78 |
|-------|---------|--------------------------|
| Milestone | v1.16 (shipped 2026-05-27) | **Unchanged** — still correct boundary |
| hex | 0.1.5 | **Unchanged** — `mix.exs` `@version "0.1.5"` |
| git sha | `3dbf7ab` (stale) | **`25bcb44`** (current HEAD at research time) |

### Delta since anchor (`git log 3dbf7ab..HEAD --oneline`)

```
25bcb44 docs(state): record phase 78 context session
685d467 docs(78): capture phase context (assumptions mode)
7d6de6d docs: start milestone v1.17 Adopter-Confidence Hygiene
7c547ab docs: mark post-v116 hygiene complete in assessment
3b76b04 docs: handoff after post-v116 assessment and CI hygiene
0036760 ci: make default unit suite merge-blocking via coveralls
9384191 ci: make default unit suite merge-blocking via coveralls (companion docs)
0600f72 docs: post-v1.16 assessment and demand-gated pause
```

### Shipped-job delta check

```bash
git log 3dbf7ab..HEAD --oneline -- lib/ guides/ CHANGELOG.md mix.exs
# (empty — no output)
```

**Conclusion:** No new JTBD inventory rows required. Delta is planning/docs/ci-hygiene only:
- `0036760` / `9384191`: coveralls merge-blocking (CI policy, not user-facing job)
- `0600f72`–`7d6de6d`: assessment, JTBD anchor move to v1.16, v1.17 milestone start
- `685d467`–`25bcb44`: Phase 78 context

### Protocol steps (from JTBD-MAP.md L17–33)

1. Read anchor line (L3) — milestone v1.16 confirmed correct.
2. `git log 3dbf7ab..HEAD --oneline` — 8 commits, all planning/ci-hygiene.
3. Confirm no new shipped jobs — **pass** (empty lib/guides delta).
4. Refresh anchor sha: `3dbf7ab` → current HEAD.
5. Append "What changed since last generation" entry (L165+), e.g.:

```
- **2026-05-27 — v1.17 planning-only delta (Phase 78).** Anchor sha refreshed;
  no new JTBD rows. Delta: coveralls merge-blocking (`0036760`), v1.17 milestone
  charter, post-v116 thread TRUTH-06 closure. Gap rank #1 hygiene wording tracks
  Phase 78 completion.
```

6. **Do not** mirror to `guides/user_flows.md` — no user-visible job changes.

### JTBD internal consistency note

**JTBD-MAP.md L127–128** claims "Post-v1.16 hygiene complete" in gap rank #1. After D-05, this should read **in progress until Phase 78 TRUTH-06 passes** — aligned with assessment wedge #1, not ahead of verification.

---

## 3. PROJECT / STATE / ROADMAP Consistency Gaps

### Already aligned (no edit required unless drift reintroduced)

| Artifact | v1.17 charter | Demand gates |
|----------|---------------|--------------|
| `ROADMAP.md` L5, L26–39 | Phase 78 goal + success criteria | L87–95 deferred v1.18+ |
| `REQUIREMENTS.md` L7–21 | TRUTH-06, PLAN-02, CI-04 mapped | L31–36 future reqs demand-gated |
| `PROJECT.md` L3–17 | Current Milestone v1.17 | L14–15 LIFE-06/STREAM-10 → v1.18+ |
| `STATE.md` L32–39 | v1.17 active | L56–57, L70 demand-gated deferred table |
| `STATE.md` L57 | `mix coveralls` merge-blocking per `ci.yml` | Correct |

### Gaps to close in Phase 78 (PLAN-02)

| Gap | Location | Issue | Recommended fix |
|-----|----------|-------|-----------------|
| **G-01** | `STATE.md` L5, L27–29 | Status still "Defining requirements" / "Not started" while Phase 78 context exists and ROADMAP says v1.17 in progress | Update to Phase 78 in progress (or awaiting plan) after `/gsd-plan-phase 78` |
| **G-02** | `PROJECT.md` L341 | "Deferred to **v1.17+**" for LIFE-06/STREAM-10 | Change to **v1.18+** to match REQUIREMENTS.md L31, STATE.md L56, ROADMAP.md L87 |
| **G-03** | `path-to-done` L50–56 | Milestone 0 marked "(current)" while v1.17 Branch C is active | Resequence: v1.17 active; Milestone 0 = default after v1.17 ships |
| **G-04** | `path-to-done` L58 | v1.17 still "conditional — pick ONE branch" | Record Branch C selected (maintainer choice 2026-05-27) |
| **G-05** | Assessment L69 vs REQUIREMENTS TRUTH-06 | Wedge #1 "Done" vs requirement Pending | D-05 revert until grep passes |
| **G-06** | `JTBD-MAP.md` L3 | Stale sha `3dbf7ab` | Refresh to HEAD |
| **G-07** | `JTBD-MAP.md` L127 | "hygiene complete" premature | Align with wedge #1 in-progress until TRUTH-06 |

### Cross-artifact demand-gate vocabulary (target state)

All four files should agree:

- **v1.17:** Adopter-Confidence Hygiene (Branch C) — Phases 78–79, hygiene-only, no public API
- **v1.18+:** LIFE-06 force-delete, STREAM-10 second provider — demand-gated
- **After v1.17:** Default returns to demand-gated pause unless compliance/adopter signal

---

## 4. Recommended Plan Structure

### Wave 1 — TRUTH-06 thread truth (assessment + path-to-done)

**Goal:** One honest CI story in canonical threads.

| Task | File(s) | Lines |
|------|---------|-------|
| Fix Proof & CI table row | `threads/2026-05-27-post-v116-milestone-assessment.md` | L30 |
| Fix Rough edges split statement | same | L62–63 |
| Fix Optional/active micro milestone block | same | L81–82 |
| Revert wedge #1 to in-progress | same | L69 |
| Resolve doc drift note | `threads/2026-05-27-path-to-done-roadmap.md` | L31–33 |
| Update Milestone 0 / v1.17 status | same | L50–58, L102–110, L173–174 |
| Cross-link check (ci.yml + RUNNING.md cited) | both threads | all CI claims |

**Dependencies:** None — read-only verification against `ci.yml` / `RUNNING.md` first.

**Out of scope:** `RUNNING.md` Credo/Dialyzer policy change (Phase 79 / CI-04).

### Wave 2 — PLAN-02 anchor + charter alignment

**Goal:** JTBD anchor current; PROJECT/STATE/ROADMAP/path-to-done/JTBD agree on v1.17 + v1.18+ gates.

| Task | File(s) |
|------|---------|
| Refresh JTBD anchor sha + "What changed" entry | `JTBD-MAP.md` L3, L165+ |
| Fix gap rank #1 hygiene wording | `JTBD-MAP.md` L127–128 |
| Fix PROJECT deferred milestone wording | `PROJECT.md` L341 |
| Update STATE position block | `STATE.md` L27–29 |
| Mark wedge #1 Done (if grep passes) | assessment L69 |
| Update REQUIREMENTS traceability (optional, end of phase) | `REQUIREMENTS.md` L54–55 |

### Suggested plan file grouping

```
78-01-PLAN.md  — Wave 1: assessment + path-to-done TRUTH-06 edits
78-02-PLAN.md  — Wave 2: JTBD anchor + PROJECT/STATE/JTBD consistency + verification closure
```

Single-plan alternative is valid (small diff volume) but two-plan matches v1.16 phase 77 hygiene pattern and isolates grep-verification as explicit closure step.

### Reusable patterns (reference only — no edits)

- **Evidence ladder:** `ci.yml` > `RUNNING.md` > threads (from 78-CONTEXT.md)
- **v1.16 Phase 77:** Planning artifact cleanup without public API
- **`docs_parity_test.exs`:** Merge-blocking proof lane pattern for *code* docs — Phase 78 uses grep/manual for *planning* docs (no new ExUnit unless explicitly requested later)

### Risk register

| Risk | Mitigation |
|------|------------|
| Marking wedge #1 Done before grep | D-05: in-progress until audit passes |
| Accidentally editing `ci.yml` / RUNNING.md policy | D-07 scope guard; Phase 79 owns CI-04 |
| Full JTBD regen scope creep | D-04: anchor refresh only; empty lib/guides delta |
| path-to-done Branch A/B phase numbers (78–80) confuse v1.17 roadmap | Add footnote: Branch A/B phase numbers are **hypothetical**; active v1.17 is ROADMAP Phases 78–79 only |

---

## Validation Architecture

How to verify TRUTH-06 and PLAN-02 close. Phase 78 has **no automated test target** — validation is grep + manual read (consistent with PLAN-01 / phase 77 planning hygiene).

### TRUTH-06 — CI thread truth

#### Automated grep (must exit 0 / zero matches)

Run from repo root after Wave 1 edits:

```bash
# Forbidden phrases — expect ZERO matches in threads
rg -i 'mix test still advisory|still advisory via Coveralls|optional CI unit-suite blocking|unit tests advisory' \
  .planning/threads/

# Undifferentiated rough-edge claim
rg 'does not guarantee full unit/Credo/Dialyzer pass' .planning/threads/

# Close variants
rg -i 'coveralls.*advisory|default.*mix test.*advisory' .planning/threads/
```

#### Required presence grep (expect matches in both thread files)

```bash
rg '\.github/workflows/ci\.yml|RUNNING\.md' \
  .planning/threads/2026-05-27-post-v116-milestone-assessment.md \
  .planning/threads/2026-05-27-path-to-done-roadmap.md
```

#### Manual read checklist

1. **Assessment L30** — Proof & CI row lists `mix coveralls` merge-blocking and names advisory tools separately.
2. **Assessment L62–63** — Rough edges split: unit blocking vs Credo/Doctor/Dialyzer advisory.
3. **Assessment L81–82** — No "optional unit-suite blocking"; v1.17 Branch C scope accurate.
4. **Assessment L107–115** — Open concerns still consistent (regression check).
5. **Path-to-done L31–33** — Drift note says **resolved** (not open).
6. **Path-to-done L28** — CI row still matches `ci.yml`.
7. Cross-read `RUNNING.md` L20–36 against assessment Proof/CI and Open concerns — no contradictions.

#### Spot-check against ci.yml (maintainer 30-second audit)

| Claim in threads | ci.yml line |
|------------------|-------------|
| coveralls merge-blocking | L112–113 (no continue-on-error) |
| Credo advisory | L97–99 |
| Doctor advisory | L101–103 |
| Dialyzer advisory | L131–133 |
| proof merge-blocking | L357–361 |
| contract ExUnit advisory | L295–297 |

### PLAN-02 — JTBD anchor + charter consistency

#### JTBD anchor verification

```bash
# Anchor sha matches HEAD after refresh
head -3 .planning/JTBD-MAP.md
git rev-parse --short HEAD

# No shipped jobs since old anchor
git log 3dbf7ab..HEAD --oneline -- lib/ guides/ CHANGELOG.md mix.exs
# expect empty

# New "What changed" entry exists for v1.17 planning delta
rg 'v1\.17 planning' .planning/JTBD-MAP.md
```

#### Charter consistency grep

```bash
# LIFE-06 / STREAM-10 demand-gated at v1.18+ (not v1.17+) in active artifacts
rg 'v1\.18\+' .planning/PROJECT.md .planning/STATE.md .planning/ROADMAP.md .planning/REQUIREMENTS.md

# Stale "Deferred to v1.17+" should be gone from PROJECT Active section
rg 'Deferred to v1\.17\+' .planning/PROJECT.md
# expect zero after fix
```

#### Manual read checklist

1. **PROJECT.md** L3–17 — v1.17 charter matches ROADMAP Phases 78–79.
2. **STATE.md** — Current milestone v1.17; position reflects Phase 78 (not "Defining requirements" stale).
3. **ROADMAP.md** L26–39 — Success criteria satisfied by thread + JTBD edits.
4. **JTBD-MAP.md** L3 — sha current; milestone still v1.16.
5. **JTBD-MAP.md** L127–128 — hygiene status matches assessment wedge #1.
6. **path-to-done** — v1.17 Branch C active; Milestone 0 not falsely "(current)".

### Phase completion gate

| Requirement | Gate |
|-------------|------|
| TRUTH-06 | All forbidden grep patterns zero; manual checklist 7/7; wedge #1 may flip to Done |
| PLAN-02 | JTBD anchor sha = HEAD; empty lib/guides delta confirmed; G-01–G-07 closed; charter grep clean |

### Explicit non-validation (Phase 79 scope)

- Credo/Dialyzer merge-blocking **decision** recorded
- `ci.yml` or `RUNNING.md` wiring changes
- `mix test test/install_smoke/docs_parity_test.exs` — unchanged; proves *code* docs, not `.planning/threads/`

---

## RESEARCH COMPLETE
