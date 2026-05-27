# Phase 79: CI Static-Analysis Policy Closure — Research

**Researched:** 2026-05-27  
**Domain:** CI-04 policy documentation — `RUNNING.md`, `ci.yml` comments, planning threads  
**Confidence:** HIGH (repo-truth verified against live `ci.yml`, `RUNNING.md`, Phase 78 artifacts)

<user_constraints>
## User Constraints (from 79-CONTEXT.md)

### Locked Decisions
- **D-01:** Keep Credo (strict) and Dialyzer advisory — retain `continue-on-error: true` in `ci.yml`; no wiring changes.
- **D-02:** Record explicit decision in `RUNNING.md` under `### Static analysis policy (CI-04)` with three-factor rationale.
- **D-03:** Update `ci.yml` quality-job comment block (L94–96) — comments only; reference CI-04 policy in RUNNING.md.
- **D-04:** Matrix rows for Credo/Dialyzer remain advisory; cross-reference new subsection.
- **D-05:** Assessment thread Open concerns L118 — remove "Decision deferred" for Credo/Dialyzer.
- **D-06:** Path-to-done Branch C — verify "Done enough" reflects recorded decision (edit only if still pending).
- **D-07–D-08:** No Doctor/AV doctor re-decision; no `lib/` or branch-protection changes.
- **D-09:** Close CI-04 with grep/read verification.

### Claude's Discretion
- Exact wording of RUNNING.md subsection and ci.yml comments.
- Single vs split plan structure.
- Whether path-to-done needs edit beyond assessment thread.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **CI-04** | Maintainer records explicit Credo/Dialyzer severity decision (merge-blocking vs advisory); `RUNNING.md` CI matrix and `ci.yml` comments match with rationale (fork latency, signal value, green-main honesty) | Advisory decision locked in CONTEXT; live wiring already advisory; gap is documentation only — RUNNING.md lacks dedicated policy subsection; assessment thread L118 still says "Decision deferred" |
</phase_requirements>

---

## Summary

Phase 79 closes **CI-04** — the last v1.17 requirement. Live CI wiring already matches the locked decision: Credo L97–99 and Dialyzer L131–133 use `continue-on-error: true`. Phase 78 settled factual CI truth in threads; Phase 79 records the **maintainer policy decision** that static analysis stays advisory.

**Primary recommendation:** Two-wave plan — (1) `RUNNING.md` policy subsection + `ci.yml` comment alignment, (2) assessment thread closure + REQUIREMENTS/STATE/ROADMAP traceability + grep gate.

---

## 1. Current State vs Target

### Live wiring (unchanged)

| Tool | Location | Severity | Evidence |
|------|----------|----------|----------|
| Credo (strict) | `ci.yml` L97–99 | advisory | `continue-on-error: true` |
| Dialyzer | `ci.yml` L131–133 | advisory | `continue-on-error: true` |
| mix coveralls | `ci.yml` L112–113 | merge-blocking | no `continue-on-error` |

### Documentation gaps

| Artifact | Current | Target |
|----------|---------|--------|
| `RUNNING.md` | Matrix rows L23, L27 list Credo/Dialyzer as advisory | Add `### Static analysis policy (CI-04)` with explicit decision + three-factor rationale |
| `ci.yml` L94–96 | Phase 71 historical note; implies policy context but not CI-04 closure | Reference RUNNING.md `### Static analysis policy (CI-04)` as recorded decision |
| Assessment thread L118 | `**Decision deferred:** Credo / Dialyzer merge-blocking` | Recorded advisory decision + RUNNING.md pointer |
| `REQUIREMENTS.md` | CI-04 Pending | Complete after verification |
| Path-to-done L116–118 | Phase 79 scope accurate; "Done enough" mentions CI policy record | Verify no "pending decision" language remains after L118 fix |

### Forbidden after Phase 79

```bash
rg 'Decision deferred.*Credo|Decision deferred.*Dialyzer' .planning/threads/
# expect zero matches
```

### Required after Phase 79

```bash
rg 'Static analysis policy \(CI-04\)' RUNNING.md
rg 'CI-04' .github/workflows/ci.yml RUNNING.md
rg 'advisory' RUNNING.md  # Credo + Dialyzer rows and policy subsection
```

---

## 2. RUNNING.md Insertion Point

Insert `### Static analysis policy (CI-04)` **after** the CI matrix table (after L36) and **before** `### Release train` (L38).

**Required content elements (from D-02):**
1. **Decision:** Credo and Dialyzer remain advisory.
2. **Rationale — Signal value:** Static analysis catches style and typespec drift; results visible in CI logs.
3. **Rationale — Fork latency:** Dialyzer PLT build is slow; merge-blocking raises contributor/fork PR cost disproportionate to adopter impact.
4. **Rationale — Green-main honesty:** Adopter-critical lanes already merge-blocking (`mix coveralls`, `proof`, `package-consumer`, `adopter`, `integration`, contract AV hygiene); static analysis is maintainer hygiene.

**Matrix cross-reference:** Add note on Credo L23 and Dialyzer L27 rows pointing to `### Static analysis policy (CI-04)` (inline parenthetical or Notes column — discretion).

---

## 3. ci.yml Comment Block (L94–96)

**Current:**
```yaml
# Phase 71 (CI proof honesty): Credo, Doctor, AV doctor, and Dialyzer stay advisory.
# Default unit suite (mix coveralls) is merge-blocking (post-v1.16 assessment).
# See RUNNING.md `## CI lane severity` for the full matrix.
```

**Target pattern (comments only — preserve Doctor/AV doctor advisory mention):**
```yaml
# CI-04 (v1.17): Credo and Dialyzer remain advisory (continue-on-error).
# Doctor and AV doctor also advisory — not part of CI-04 decision record.
# Default unit suite (mix coveralls) is merge-blocking. See RUNNING.md
# `### Static analysis policy (CI-04)` and `## CI lane severity`.
```

Do **not** remove or add `continue-on-error` on any step.

---

## 4. Assessment Thread Edit (L118)

**Find:**
```
**Decision deferred:** Credo / Dialyzer merge-blocking (static-analysis policy unchanged).
```

**Replace with (substance required, exact wording discretion):**
```
**Recorded (CI-04, v1.17):** Credo and Dialyzer remain **advisory** — merge-blocking rejected
for fork latency, signal-value, and green-main honesty rationale. See `RUNNING.md`
`### Static analysis policy (CI-04)` and `.github/workflows/ci.yml` L97–99, L131–133.
```

---

## 5. Phase 78 Pattern Reuse

| Pattern | Source | Phase 79 application |
|---------|--------|---------------------|
| Repo-truth ladder | Phase 78 / methodology | `ci.yml` > RUNNING.md > threads |
| Grep forbidden phrases | 78-RESEARCH.md Validation Architecture | "Decision deferred" for Credo/Dialyzer |
| Two-wave docs plan | 78-01 + 78-02 | Policy record wave 1; thread/charter closure wave 2 |
| Manual read against RUNNING.md | 78-02 verification | Cross-read matrix vs ci.yml vs thread Open concerns |

---

## 6. Out of Scope Guards

- No `lib/` edits (REQUIREMENTS.md Out of Scope)
- No `continue-on-error` removal (v1.16 REQUIREMENTS: merge-blocking without explicit decision forbidden — decision is advisory)
- Doctor/AV doctor: mention in ci.yml comments only; no separate RUNNING.md policy subsection (D-07)
- GitHub branch protection: outside repo (D-08)

---

## Validation Architecture

### CI-04 — Static-analysis policy closure

#### Forbidden grep (expect zero after Phase 79)

```bash
rg 'Decision deferred.*Credo|Decision deferred.*Dialyzer|Decision deferred: Credo' \
  .planning/threads/
```

#### Required presence grep

```bash
rg 'Static analysis policy \(CI-04\)' RUNNING.md
rg 'CI-04' RUNNING.md .github/workflows/ci.yml
rg 'fork latency|Fork latency' RUNNING.md
rg 'signal value|Signal value' RUNNING.md
rg 'green-main|Green-main' RUNNING.md
rg 'continue-on-error: true' .github/workflows/ci.yml  # Credo + Dialyzer steps still present
```

#### Scope guard grep (expect zero lib changes)

```bash
git diff --name-only HEAD -- lib/
# expect empty during phase execution
```

#### Manual read checklist

1. **RUNNING.md** — `### Static analysis policy (CI-04)` states advisory decision with all three rationale factors.
2. **RUNNING.md L23, L27** — Credo and Dialyzer rows still advisory; no contradiction with subsection.
3. **ci.yml L94–96** — Comments reference CI-04 subsection; L97–99 and L131–133 still have `continue-on-error: true`.
4. **Assessment L107–118** — Open concerns factual; L118 shows recorded decision not deferred.
5. **Path-to-done L116–118** — Phase 79 scope and "Done enough" consistent with recorded policy.
6. **REQUIREMENTS.md** — CI-04 marked complete; traceability table updated.
7. Cross-read: no thread claim contradicts `ci.yml` wiring.

### Phase completion gate

| Requirement | Gate |
|-------------|------|
| CI-04 | Forbidden grep zero; required grep matches; manual checklist 7/7; no `lib/` changes |

---

## RESEARCH COMPLETE
