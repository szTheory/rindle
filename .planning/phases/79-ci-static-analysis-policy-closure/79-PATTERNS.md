# Phase 79: CI Static-Analysis Policy Closure — Patterns

**Mapped:** 2026-05-27  
**Phase:** 79 — CI-04 documentation closure (no `lib/`)

---

## Evidence Ladder

**Rule:** `.github/workflows/ci.yml` > `RUNNING.md` `## CI lane severity` > planning threads.

Phase 79 adds `RUNNING.md` `### Static analysis policy (CI-04)` as the canonical **decision record** for Credo/Dialyzer severity. Threads cite it; they do not redefine policy.

---

## File Roles

| File | Role | Phase 79 action |
|------|------|-----------------|
| `.github/workflows/ci.yml` | CI wiring source of truth | Comments only at L94–96; preserve `continue-on-error: true` on Credo/Dialyzer |
| `RUNNING.md` | Maintainer-facing severity matrix + policy | Add CI-04 subsection; optional matrix cross-ref |
| `.planning/threads/2026-05-27-post-v116-milestone-assessment.md` | Post-ship assessment | Replace L118 "Decision deferred" |
| `.planning/threads/2026-05-27-path-to-done-roadmap.md` | Branch C roadmap | Verify L116–118; edit only if pending language remains |
| `.planning/REQUIREMENTS.md` | CI-04 traceability | Mark CI-04 complete after verification |
| `.planning/STATE.md` | Milestone position | Phase 79 complete / v1.17 shipped |
| `.planning/ROADMAP.md` | Phase success criteria | Mark Phase 79 plans complete |

---

## Closest Analog: Phase 78 Plan 01 (Thread CI Truth)

**Reference:** `.planning/phases/78-assessment-planning-truth/78-01-PLAN.md`

**Pattern:** Grep-verifiable task actions with exact find/replace strings; forbidden-phrase audit; manual read against RUNNING.md.

**Phase 79 delta:** Edits RUNNING.md + ci.yml comments (Phase 78 explicitly avoided these). Assessment Open concerns L118 is the primary thread target (Phase 78 fixed L30/L63/L81–82 and left L118 deferred).

---

## RUNNING.md Subsection Pattern (Phase 71)

**Reference:** `RUNNING.md` L14–43 — `## CI lane severity` with matrix table + `### Release train` sibling subsection.

**Insert location:** After matrix (L36), before `### Release train` (L38).

**Excerpt — matrix advisory rows (unchanged):**

```markdown
| `quality` — Credo (strict) | advisory | Same job | Step-level `continue-on-error` |
| `quality` — Dialyzer | advisory | Same job | Step-level `continue-on-error` |
```

---

## ci.yml Comment Pattern (Phase 71 → CI-04)

**Reference:** `.github/workflows/ci.yml` L94–96

```yaml
# Phase 71 (CI proof honesty): Credo, Doctor, AV doctor, and Dialyzer stay advisory.
# Default unit suite (mix coveralls) is merge-blocking (post-v1.16 assessment).
# See RUNNING.md `## CI lane severity` for the full matrix.
```

**Phase 79 evolution:** Replace Phase 71 framing with CI-04 closure pointer to `### Static analysis policy (CI-04)`.

---

## Assessment Thread Open Concerns Pattern

**Reference:** `.planning/threads/2026-05-27-post-v116-milestone-assessment.md` L107–118

Phase 78 made L107–116 factually correct. L118 remains the deferred stub:

```
**Decision deferred:** Credo / Dialyzer merge-blocking (static-analysis policy unchanged).
```

**Phase 79 flip:** Same section structure; replace deferred line with recorded advisory decision + RUNNING.md pointer (mirror Phase 78 citation style for ci.yml/RUNNING.md).

---

## Grep Audit Pattern (from Phase 78)

**Forbidden:**
```bash
rg 'Decision deferred.*Credo|Decision deferred.*Dialyzer' .planning/threads/
```

**Required citations in edited files:**
```bash
rg 'RUNNING\.md|\.github/workflows/ci\.yml' \
  .planning/threads/2026-05-27-post-v116-milestone-assessment.md
```

---

## PATTERN MAPPING COMPLETE
