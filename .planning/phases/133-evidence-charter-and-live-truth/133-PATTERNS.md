# Phase 133: Evidence Charter and Live Truth — Successor Gap Pattern Map

**Mapped:** 2026-10-10
**Scope:** Plan 161's halted detached-source `verify-preflight` boundary only
**Files classified:** 6 likely source/test files; 5 tracked analogs read
**Analogs found:** 6 / 6 (two files share the same test analog)

The upstream `133-CONTEXT.md` and `133-RESEARCH.md` establish machine-checked, exact-source, fail-closed evidence and leave helper boundaries discretionary. The newer `133-161-SUMMARY.md` is the controlling gap evidence: source `16fddcc4ee897baa5a454f592becbd2088e3ff85` published ready preflight/supply/zero-fetch receipts, then Plan 159 `verify-preflight` exited 1 with `Unexpected end of JSON input`. Plan 161 is terminal before authorization. Its receipts and summary are immutable inputs, not edit targets. All five requirements remain Pending, 11 edges unresolved, and credit zero.

## File Classification

| Likely new/modified file | Role | Data flow | Closest tracked analog | Match |
|---|---|---|---|---|
| `scripts/maintainer/phase_133_qualification_159.mjs` | verifier/utility | request-response, child process, detached file I/O | same file, lines 179-187 and 266-297 | exact |
| `scripts/maintainer/phase_133_plan159_authority.test.mjs` | contract test | request-response, detached fixture | same file, lines 16-27 and 86-180 | exact |
| `scripts/maintainer/phase_133_registry_closure_154.mjs` | verifier/service | batch, child process, file I/O | same file, lines 548-615 and 729-769 | exact |
| `scripts/maintainer/phase_133_registry_closure_154.test.mjs` | contract test | batch, file I/O, source mutation | same file, lines 62-89 | exact |
| `scripts/maintainer/phase_133_local_supply.mjs` | diagnostic utility | request-response, bounded child output | same file, lines 248-340 | role match |
| `scripts/maintainer/phase_133_local_supply.test.mjs` | diagnostic test | request-response, fake child | `scripts/maintainer/phase_133_plan159_authority.test.mjs`, lines 86-103 | role match |

The last four rows are conditional implementation seams: change them only if diagnosis locates the defect there. A successor may instead add a focused diagnostic module and test, using the Plan 159 verifier and test patterns below. The phase documents specify behavior rather than a required new filename.

## Pattern Assignments

### `phase_133_qualification_159.mjs` — detached verifier and child JSON boundary

**Analog:** `scripts/maintainer/phase_133_qualification_159.mjs` (tracked). Preserve the source/receipt checks and repair the narrow child-output boundary.

**Imports and error convention** (lines 3-9, 29-37):

```js
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import * as supply from './phase_133_local_supply.mjs';
const check = (condition, code, detail = code) => {
  if (!condition) throw Object.assign(new Error(detail), { code });
};
```

**Current child seam** (lines 179-187):

```js
const result = spawnSync(process.execPath, [script, 'qualification-preflight'], {
  cwd: checkoutRoot, encoding: 'utf8', timeout: 180000, maxBuffer: 4 * 1024 * 1024,
  env: { ...process.env, ERL_FLAGS: '+S 2:2' }
});
check(!result.error && result.status === 0, 'plan161_registry_preflight',
  result.stderr || result.stdout || result.error?.message || 'Plan 154 qualification-preflight failed');
return JSON.parse(result.stdout.trim());
```

This is the observed loss-of-context point: exit zero alone permits empty/malformed stdout to reach an unlabelled `JSON.parse` exception. The error text does **not** establish why stdout was incomplete. A successor should first preserve bounded child status, signal, stdout/stderr size and a safe output fingerprint in diagnostic evidence, then distinguish empty/malformed output from a semantic mismatch. It must never treat the failed child as a ready preflight.

**Independent detached reproduction** (lines 266-281, 284-297):

```js
git(root, 'worktree', 'add', '--detach', worktree, source.sha);
const result = registryCommand(root, worktree);
verifyPlan154Output(result, source, expected);
check(git(worktree, 'rev-parse', 'HEAD^{tree}') === source.tree, 'plan161_detached_tree');
check(git(worktree, 'status', '--porcelain') === '', 'plan161_detached_dirty');
// finally: git worktree remove --force; fs.rmSync(worktree, { recursive: true, force: true })
```

Preserve cleanup on every exit. The Plan 161 receipt comparison at lines 288-296 uses canonical result equality plus a SHA-256 digest. A new source and new receipts are required before any later qualification; do not make Plan 161's published digest pass by weakening this equality.

### `phase_133_plan159_authority.test.mjs` — source reproduction regression

**Analog:** `scripts/maintainer/phase_133_plan159_authority.test.mjs` (tracked).

**Fixture/cleanup pattern** (lines 16-27, 86-103):

```js
const fixture = createFixture();
try {
  assert.deepEqual(authority.verifyPublishedPreflight(fixture.root, fixture.preflight,
    fixture.registry, fixture.manifest), fixture.expected);
} finally {
  fs.rmSync(fixture.root, { recursive: true, force: true });
}
```

The dirty-detached test also snapshots `git worktree list --porcelain` and the `phase133-plan161-` temporary directories, then asserts both return to their original state after failure (lines 86-103). Reuse that cleanup assertion for malformed child output, timeout, spawn failure, and any discovered real-child failure.

**Coverage gap to close:** `createFixture` writes a small `registryFixtureSource` replacement (lines 105-165), then calls that script through `spawnSync` (lines 168-170). It proves orchestration and identity checks, but does not execute the real Plan 154 `qualificationPreflight` path with Plan 153/154/155 receipts and local supply. Add a focused integration fixture or deterministic child seam that reproduces the observed detached behavior and checks a coded fail-stop plus zero authorization/attempt/credit. Keep byte checks against Plan 161 receipts.

### `phase_133_registry_closure_154.mjs` — actual producer and source checks

**Analog:** `scripts/maintainer/phase_133_registry_closure_154.mjs` (tracked).

**Source integrity** (lines 35-66): `importClosure` follows local `.mjs` imports; `sourceEvidence` requires clean Git status and hashes each imported file; `verifySource` checks tree, ancestry, imported-file hashes and an explicit post-source-change allowlist. Copy this source binding if a successor adds a detached diagnostic. Do not broaden its receipt allowlist merely to make a dirty checkout pass.

**Qualification producer** (lines 548-615):

```js
const report = read154(root); checked(report, PLAN154);
const current = sourceEvidence(root);
check(current.sha !== report.source.sha && current.tree !== report.source.tree,
  'registry_qualification_source_not_distinct');
const fresh = preflightContext(root, { verify153: true, source: report.source });
// ... compare sealed fresh preflight with recorded Plan 154 report
const supplyReceipt = verifySupply(root, { allowNoRequest: true, allowDistinctSource: true });
return { plan: '133-qualification-preflight', status: 'ready', source: current,
  registry_closure_plan: '133-155', registry_supply_sha256: supplyReceipt.report_sha256,
  required_names: supplyReceipt.required_names.length, qualification_credit: 0,
  requirements_completed: [] };
```

The CLI dispatch at lines 761-768 calls `qualificationPreflight(root)` and writes one JSON line with `console.log(JSON.stringify(result))`; caught errors write a halted JSON object to stderr and set exit code 1. Diagnosis should establish which part of this actual path differs between the execution checkout and a detached checkout before changing Plan 154 logic. Its `plan153` helper launches a live `verify-supply` child with explicit runtime environment and 180-second timeout (lines 69-87), a likely boundary to instrument if output or process status differs.

### `phase_133_registry_closure_154.test.mjs` — committed-source mutation

**Analog:** `scripts/maintainer/phase_133_registry_closure_154.test.mjs` (tracked), lines 62-89. It creates a temporary Git repository, commits the verifier file, checks `verifySource(root, source)`, permits only named receipt dirt, and rejects modified source bytes or unexpected `mix.lock`. Reuse this fixture style for real Plan 154 producer behavior and exact detached-source checks; preserve the fixed `registry_source_changed` and `registry_post_source_change` error codes.

### `phase_133_local_supply.mjs` and its test — bounded diagnostic records

**Analog:** `scripts/maintainer/phase_133_local_supply.mjs` (tracked), lines 248-260 and 293-340. `boundedOutput` records text, original byte count, and truncation; `diagnoseNetworkGuard` injects `spawnChild`, captures exit code, spawn error, stdout/stderr, and returns a structured `unavailable` result when a control fails. Its companion test exercises fake spawn responses and truncated stderr at `phase_133_local_supply.test.mjs:265-295`. Reuse this bounded, injectable diagnostic shape if the successor needs a standalone probe. Keep absolute cache paths, secrets, and raw registry payloads out of the durable report.

## Shared Patterns

- **No authorization on verifier failure:** `phase_133_qualification_159.mjs:380-393` invokes `verifyBase` before checking a fresh literal and publishing authorization. A successor repair must retain that order and keep Plan 161's absent authorization/attempt receipts absent.
- **No-clobber evidence:** `phase_133_qualification_159.mjs:261-265` limits receipt names and calls `supply.publish`; new diagnostics should have their own explicit path and must not overwrite Plan 161 PREFLIGHT/SUPPLY/RETRIEVAL/SUMMARY.
- **Exact source and result:** `phase_133_qualification_159.mjs:238-255,284-297` checks source SHA/tree, allowed executor dirt, independent detached result, canonical equality and result digest. Preserve all of these gates.
- **Fail-closed child boundary:** `phase_133_registry_closure_154.mjs:729-769` expects a single JSON stdout result or nonzero halted stderr; `phase_133_local_supply.mjs:315-340` shows how to retain bounded context when a child fails. A zero-exit empty stdout is a contract failure, never a ready result.
- **Required check after planning artifact edit:** `AGENTS.md` requires `./scripts/maintainer/automation_first_contract.sh`. This map does not close any active requirement.

## No Analog Found

There is no existing integration test that runs the **real** Plan 154 `qualification-preflight` in a detached checkout with the full historical Plan 153/154/155 inputs and compares it to a published successor receipt. The planner should allocate that regression explicitly; the small Plan 159 replacement-script fixture alone cannot diagnose the observed failure.

## Metadata

**Search scope:** tracked `scripts/maintainer/phase_133_*.mjs` and matching tests, plus the current Phase 133 context, research, Plan 161 summary, and Plan 161 plan.
**Tracked-source gate:** each named source analog returned from `git ls-files -- <path>` in the active worktree. No install/runtime mirror is cited.
**Output boundary:** planning map only; no source, PLAN, receipt, authorization, or qualification action.
