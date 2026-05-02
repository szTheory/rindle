# Phase 14: Validation Closure for Publish Milestone - Pattern Map

**Mapped:** 2026-04-28
**Files analyzed:** 2 modified files
**Analogs found:** 2 / 2

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `.planning/milestones/v1.2-phases/10-publish-readiness/10-VALIDATION.md` | validation artifact (YAML-fronted markdown) | document-edit | `.planning/phases/12-public-verification-and-release-operations/12-VALIDATION.md` | exact |
| `.planning/milestones/v1.2-phases/11-protected-publish-automation/11-VALIDATION.md` | validation artifact (YAML-fronted markdown) | document-edit | `.planning/phases/12-public-verification-and-release-operations/12-VALIDATION.md` | exact |

---

## Pattern Assignments

### `.planning/milestones/v1.2-phases/10-publish-readiness/10-VALIDATION.md`

**Analog:** `.planning/phases/12-public-verification-and-release-operations/12-VALIDATION.md`

This is a pure document-editing task. No code is written or executed. The analog is Phase 12's VALIDATION file — the only file in the project already at `status: complete` with `wave_0_complete: true`, all sign-off checkboxes checked, and an approved Approval line. Phase 10's file has the same format and must reach the same end state.

**Frontmatter pattern** (analog lines 1-9):
```yaml
---
phase: 12
slug: public-verification-and-release-operations
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-28
updated: 2026-04-28
---
```

Apply to Phase 10 VALIDATION by changing:
- Line 4: `status: ready` → `status: complete`
- Line 6: `wave_0_complete: false` → `wave_0_complete: true`

**Per-Task Verification Map — green status pattern** (analog lines 36-39):

The analog shows tasks with `✅` in the File Exists column and `⬜ pending` in Status, because Phase 12 was written with all tasks pre-confirmed. For Phase 10, the three tasks must be updated from their current stale state to the completed state:

Current stale (10-VALIDATION.md lines 41-43):
```markdown
| 10-01-01 | 01 | 1 | RELEASE-04 | T-10-01 | ... | `mix test test/install_smoke/release_docs_parity_test.exs` | ❌ W0 | ⬜ pending |
| 10-02-01 | 02 | 2 | RELEASE-05 | T-10-02 | ... | `mix test test/install_smoke/package_metadata_test.exs` | ❌ W0 | ⬜ pending |
| 10-02-02 | 02 | 2 | RELEASE-05 | T-10-05 / T-10-06 | ... | `mix docs --warnings-as-errors && rg -n ...` | ❌ W0 | ⬜ pending |
```

Target state for each row:
- Task 10-01-01: `❌ W0` → `✅` and `⬜ pending` → `✅ green`
- Task 10-02-01: `❌ W0` → `✅` and `⬜ pending` → `✅ green`
- Task 10-02-02: `❌ W0` → `✅` and `⬜ pending` → `✅ green`

**Wave 0 checklist — completed pattern** (analog lines 43-46):
```markdown
## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No Wave 0 test scaffolding is required before execution.
```

For Phase 10, do not replace the section text with the analog's prose — instead flip each `[ ]` to `[x]` on the four existing items (10-VALIDATION.md lines 51-54):
```markdown
- [x] `test/install_smoke/release_docs_parity_test.exs` — verify maintainer release guide presence plus key owner/versioning/checklist instructions for `RELEASE-04`
- [x] `test/install_smoke/package_metadata_test.exs` — assert unpacked `hex_metadata.config` and exact package file expectations for `RELEASE-05`
- [x] Release workflow/build command for `mix docs --warnings-as-errors`
- [x] Warning cleanup for the current docs warning around `Rindle.LiveView.allow_upload/4`
```

**Quick-run command update** (10-VALIDATION.md line 22):

Current:
```markdown
| **Quick run command** | `mix test test/install_smoke/docs_parity_test.exs` (and use the plan-owned targeted ExUnit file once it exists) |
```

Target (both test files now exist):
```markdown
| **Quick run command** | `mix test test/install_smoke/release_docs_parity_test.exs` or `mix test test/install_smoke/package_metadata_test.exs` |
```

**Validation Sign-Off — fully approved pattern** (analog lines 55-62):
```markdown
## Validation Sign-Off

- [x] All tasks have `<automated>` verify or an explicit blocking checkpoint.
- [x] Sampling continuity is defined across both plans.
- [x] No Wave 0 gaps remain.
- [x] No watch-mode flags are used.
- [x] Feedback latency is bounded for the executable smoke lane.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-04-28
```

For Phase 10, flip the four unchecked boxes (10-VALIDATION.md lines 68-71) from `[ ]` to `[x]` and change `**Approval:** pending` to `**Approval:** approved`. The two already-checked lines (latency + nyquist) stay as-is. The checkbox wording is Phase 10–specific — preserve it, only flip the `[ ]` markers.

---

### `.planning/milestones/v1.2-phases/11-protected-publish-automation/11-VALIDATION.md`

**Analog:** `.planning/phases/12-public-verification-and-release-operations/12-VALIDATION.md`

Same analog applies. Phase 11's file has fewer stale fields than Phase 10 — only the frontmatter status/wave fields, one task row's File Exists and Status columns, and the Approval line need editing. The six sign-off checkboxes are already all checked (11-VALIDATION.md lines 64-69).

**Frontmatter pattern** (analog lines 1-9, same as Phase 10):

Apply to Phase 11 VALIDATION by changing:
- Line 4: `status: draft` → `status: complete`
- Line 6: `wave_0_complete: false` → `wave_0_complete: true`

**Per-Task Verification Map — task 11-01-01** (11-VALIDATION.md line 41):

Current stale:
```markdown
| 11-01-01 | 01 | 1 | RELEASE-06 | — | Hex publish via GHA | unit/workflow | (Verified by GHA environment config) | ✅ | ⬜ pending |
```

Target (File Exists already `✅`, only Status changes):
```markdown
| 11-01-01 | 01 | 1 | RELEASE-06 | — | Hex publish via GHA | unit/workflow | (Verified by GHA environment config) | ✅ | ✅ green |
```

**Per-Task Verification Map — task 11-02-01** (11-VALIDATION.md line 42):

Current stale:
```markdown
| 11-02-01 | 02 | 2 | RELEASE-07 | — | Abort on version mismatch | script | `bash scripts/assert_version_match.sh` | ❌ W0 | ⬜ pending |
```

Target:
```markdown
| 11-02-01 | 02 | 2 | RELEASE-07 | — | Abort on version mismatch | script | `bash scripts/assert_version_match.sh` | ✅ | ✅ green |
```

**Wave 0 checklist** (11-VALIDATION.md line 51):

Current stale:
```markdown
- [ ] `scripts/assert_version_match.sh` — stubs for REQ-07
```

Target:
```markdown
- [x] `scripts/assert_version_match.sh` — exists and executable; validated by `11-VERIFICATION.md` behavioral spot-check (`Version matches: 0.1.0-dev`)
```

**Manual-Only Verifications update** (11-VALIDATION.md lines 56-59):

The current table lists one manual check (Hex API Key) that was subsequently automated by Phase 11 Plan 03. The section should note that this has been superseded by automated CI. Pattern from 12-VALIDATION.md's "External Runtime Verifications" section (lines 49-51) and 13-VALIDATION.md's "Manual-Only Verifications: None" prose (line 49):

```markdown
## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Hex API Key | RELEASE-06 | Superseded — automated CI dry-run (`mix hex.publish --dry-run --yes`) in the `package-consumer` job verifies publish path without a live secret; `11-VERIFICATION.md` confirms "Human Verification Required: None" | Verified automatically by CI per `11-03-SUMMARY.md` and `11-VERIFICATION.md` |
```

**Validation Sign-Off — Approval only** (11-VALIDATION.md line 71):

The six checkboxes are already all `[x]`. Only the Approval line changes:

Current:
```markdown
**Approval:** pending
```

Target (matching analog pattern from 12-VALIDATION.md line 62):
```markdown
**Approval:** approved
```

---

## Shared Patterns

### YAML Frontmatter — "complete" state
**Source:** `.planning/phases/12-public-verification-and-release-operations/12-VALIDATION.md` lines 1-9
**Apply to:** Both Phase 10 and Phase 11 VALIDATION files

The only file in the project already carrying `status: complete` and `wave_0_complete: true`. Both target files must reach this same frontmatter state. The `updated:` field is optional (Phase 12 has it, Phase 10/11 do not currently) — add it if desired, or leave it absent to match the Phase 11 analog structure.

```yaml
status: complete
nyquist_compliant: true
wave_0_complete: true
```

### Approval Line — "approved" state
**Source:** `.planning/phases/12-public-verification-and-release-operations/12-VALIDATION.md` line 62
**Apply to:** Both Phase 10 and Phase 11 VALIDATION files

```markdown
**Approval:** approved 2026-04-28
```

Phase 09's analog (`.planning/milestones/v1.1-phases/09-install-release-confidence/09-VALIDATION.md` line 102) uses a similar pattern:

```markdown
**Approval:** revised 2026-04-28
```

Use `approved` (not `revised`) because the files are advancing from pending/draft, not being revised after a prior approval.

### Checkbox Flip — `[ ]` → `[x]`
**Source:** `.planning/phases/12-public-verification-and-release-operations/12-VALIDATION.md` lines 55-61; `.planning/milestones/v1.1-phases/09-install-release-confidence/09-VALIDATION.md` lines 94-100
**Apply to:** Phase 10 VALIDATION (four unchecked boxes); Phase 11 VALIDATION (already all checked — no change needed)

Both analogs show that all sign-off checkboxes must be `[x]` before Approval can advance from pending to approved. Preserve the original wording per file — only the `[ ]` → `[x]` marker changes.

### Status Symbol — `⬜ pending` → `✅ green`
**Source:** 12-VALIDATION.md Per-Task map columns; status legend line in all VALIDATION files
**Apply to:** All `⬜ pending` Status cells in Phase 10 (3 tasks) and Phase 11 (2 tasks)

The legend in every VALIDATION file reads: `Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky`. Tasks that are confirmed passing in VERIFICATION.md must show `✅ green`.

### File Exists Symbol — `❌ W0` → `✅`
**Source:** 12-VALIDATION.md Per-Task map File Exists column (all `✅`)
**Apply to:** Phase 10 tasks 10-01-01, 10-02-01, 10-02-02; Phase 11 task 11-02-01

`❌ W0` means "Wave 0 dependency — file does not yet exist." Since all referenced files now exist and are confirmed by VERIFICATION.md, the column must show `✅`.

---

## No Analog Found

None. Both modified files have a direct, exact analog in the same codebase (`12-VALIDATION.md`), and the specific field changes are fully enumerated in `14-RESEARCH.md`.

---

## Metadata

**Analog search scope:** `.planning/milestones/` and `.planning/phases/` — all `*-VALIDATION.md` files
**Files scanned:** 11 VALIDATION files across all phases
**Strongest analogs:** `12-VALIDATION.md` (only file with `status: complete` + `wave_0_complete: true` + `Approval: approved`); `09-VALIDATION.md` (wave_0_complete: true, all boxes checked — secondary reference)
**Pattern extraction date:** 2026-04-28
