---
phase: 137
phase_name: "Built-Package Twin Foundation"
project: "Rindle"
generated: "2026-10-22T00:29:13.603413+00:00"
counts: {decisions: 3, lessons: 4, patterns: 3, surprises: 3}
missing_artifacts: []
---

# Phase 137 Learnings

Maintainer-operated synthetic evidence; independent_pilot_credit: false.

## Decisions

### Use one minimal external adopter host
The dedicated Phoenix/Repo/default-Oban host supersedes the Cohort-centered
assumption. Existing smoke semantics stay intact; no framework or UI is added.
**Source:** 137-CONTEXT.md D-137-01; 137-01-SUMMARY.md.

### Keep retry authority in committed normal execution
A fixed atomic storage callback fault and quiescent between-attempt restart make
same-job retry observable without worker injection or forced scheduling.
**Source:** 137-03-SUMMARY.md; 137-VERIFICATION.md.

### Separate semantic evidence and live disposal
Caller-supplied retained expectations plus strict source-owned predicates reject
inconsistency; a separately guarded exact-resource janitor cannot upgrade a failed
domain receipt. Neither component is an authentication/witness framework.
**Source:** 137-04-SUMMARY.md; 137-05-SUMMARY.md.

## Lessons

### Cache provenance is part of fresh compilation
Fresh source staging alone does not prevent Docker compile-layer reuse. Bind the
compile key to a unique run ID and observe actual compilation, while retaining
ordinary dependency-download caching.
**Source:** 137-REVIEW.md; 137-06-SUMMARY.md.

### Freeze all packaged inputs during their probes
Changing documentation during an immutable package fixture caused an early content
mismatch. Stabilize the tree before running it; the exact test and full suite then
passed without changing expected errors or historical receipts.
**Source:** 137-06-SUMMARY.md.

### Keep normal craft gates authoritative for fixtures
External host source under test/ is still part of the complexity inventory. Flatten
real branching rather than growing the baseline, and honor the async-safety guard.
**Source:** 137-06-SUMMARY.md.

### Match adapter return shapes and exact Docker identities
S3 HEAD normalizes 404 to :not_found. Docker quiet IDs require --no-trunc for exact
comparisons; independent controller processes need exclusive unique private logs.
**Source:** 137-03-SUMMARY.md; 137-05-SUMMARY.md.

## Patterns

### Enumerate staged inputs and remove ambient redirection
Use an explicit host-file allowlist, exact archive extraction and effective image,
resource, mount, version and compile-argument checks. Clear inherited TWIN and Mix
path variables so a retained run descriptor remains the actual execution authority.
**Source:** 137-02-SUMMARY.md; 137-REVIEW.md.

### Validate the candidate before publishing it
Raw process/body/job-error material remains bounded and private. Publish only a
strictly validated candidate or a small safe failure result, with synthetic labeling.
**Source:** 137-04-SUMMARY.md.

### Check liveness again before each destructive step
Observe all owned hosts first, then repeat before container/storage/path removals.
Use exact names/IDs and non-forced removals; refuse unknown or foreign resource users.
**Source:** 137-05-SUMMARY.md.

## Surprises

### Doctor confuses host and legacy package migration ledgers
Supported versioned schema readiness passes while the legacy-files comparison fails.
Two diagnostics led to a narrow auxiliary-probe rescope and an explicit pending todo.
**Source:** 137-02-SUMMARY.md; 2026-10-21-doctor-versioned-host-migration-ledger.md.

### The minimal host needs explicit PubSub startup ordering
Without optional LiveView, declare the existing Phoenix PubSub application before
Rindle startup. No production dependency or public API change was necessary here.
**Source:** 137-01-SUMMARY.md.

### Local infrastructure can block otherwise valid acceptance
Docker disk exhaustion required explicitly approved unused build-cache cleanup.
That approval enabled the environment and did not count as requirement evidence.
**Source:** 137-01-SUMMARY.md; 137-VERIFICATION.md.
