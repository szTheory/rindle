---
phase: 138
phase_name: Lifecycle Failure and Recovery Matrix
project: Rindle
generated: "2026-10-22T15:45:44.112738+00:00"
counts:
  decisions: 2
  lessons: 3
  patterns: 2
  surprises: 2
missing_artifacts: [UAT.md]
---

# Phase 138 Learnings: Lifecycle Failure and Recovery Matrix

## Decisions

### Serialize acceptance before provider writes

Lock the current provider row inside the transaction before replay/freshness/FSM decisions. Polling compares the complete accepted snapshot after remote fetch. Emit success effects after the owning transaction commits.

**Rationale:** Row timestamps alone miss accepted events within the same second; stale fetches must not overwrite a newer webhook, and rolled-back writes must not publish success.
**Source:** 138-04-PLAN.md; 138-04-SUMMARY.md.

### Freeze domain evidence before infrastructure disposal

Require exactly six bound case receipts plus complete stopped-writer audits before disposal. Descriptor/label/mount/liveness/foreign-user checks are separate from domain acceptance.

**Rationale:** Removing a volume cannot prove the application cleaned its own rows or objects. Repeated infrastructure cleanup must preserve an original failed verdict.
**Source:** 138-06-PLAN.md; 138-06-SUMMARY.md; 138-VERIFICATION.md.

## Lessons

### Confirm committed fixture identities before cleanup

MediaAsset.changeset does not cast id. Set the fixture UUID on the struct and assert exact committed-row removal on a separate connection.

**Context:** An attribute UUID was ignored, so cleanup addressed the wrong row. Corrected tests leave no new rows; preserve older unrelated residue and use an isolated test partition for final CI.
**Source:** 138-04-SUMMARY.md; 138-06-SUMMARY.md.

### Complete transition routing after phase completion

Run the normal post-completion transition and reconcile STATE prose, current plan, session resume pointer and state.json next command. Give the next concrete discuss/plan/execute command when its stage is known.

**Context:** phase.complete advances structured phase status but preserves some custom fields and writes a generic progress pointer. Handing back immediately would repeat the progress loop despite successful execution. Auto-advance remains disabled; no extra approval or conversation reset is needed for an authorized stage.
**Source:** .planning/STATE.md; 138-06-SUMMARY.md; normal execute-phase/transition owner results.

### Distinguish session expiry from remote multipart cleanup

The supported abort task marks expiry; cleanup_orphans performs remote abort. Observe both effects and use a Repo-only fixture startup role for single-use maintenance tasks.

**Context:** Mix app.start still starts supervision when required by the task. A small host role avoids competing queue/endpoint owners while preserving shipped maintenance behavior.
**Source:** 138-06-PLAN.md execution clarification; 138-06-SUMMARY.md.

## Patterns

### Require exact finite audits rather than positive counts

Bind exact case/run/archive/asset/job/event identities and every resource class. Reject unknown relations, jobs, fixture operations, denied or incomplete listings, canaries and swapped inputs. Verify retained inputs/archive in a separate process.

**When to use:** Synthetic acceptance tooling that could otherwise assert its own success or hide residue during teardown.
**Source:** 138-06-SUMMARY.md; 138-VALIDATION.md; 138-VERIFICATION.md.

### Use durable public lifecycle cuts

Observe a committed attempt-zero promotion job, kill the actual owned runtime, prove death and a new boot, then require continuation of the same job without repeating upload stimulus. For cleanup, interrupt after real storage deletion but before row deletion and rerun the supported janitor twice.

**When to use:** Recovery proof across database/external-storage/process boundaries, with normal queue attempts and leases preserved.
**Source:** 138-05-SUMMARY.md; 138-06-SUMMARY.md.

## Surprises

### SIGKILL retains an ordinary Oban peer lease

A new host may recover jobs before its old leader lease has naturally handed over. Wait for current-node peer ownership before graceful shutdown and independent empty-peer audit.

**Impact:** The first full matrix correctly failed residue accounting. The successful rerun uses normal takeover, with no direct lease deletion or policy relaxation.
**Source:** 138-06-SUMMARY.md.

### Thermal sleep can invalidate time-sensitive VM tests

The machine log showed a 954-second thermal sleep during an earlier CI run. Five LocalPlug checks failed after wake; the precise failing VM clock delta was not captured. A fresh VM passed when run alone after Docker, with an idle-sleep assertion and unchanged token lifetimes.

**Impact:** Preserve failed evidence, isolate environmental diagnosis and rerun unchanged security tests. Do not invent a token-lifetime workaround or claim an unmeasured clock offset as fact.
**Source:** 138-06-SUMMARY.md.
