---
phase: 93-truth-docs-milestone-audit
reviewed: 2026-06-13T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - lib/rindle.ex
  - mix.exs
  - test/install_smoke/docs_parity_test.exs
  - test/rindle/api_surface_boundary_test.exs
  - guides/admin_console.md
  - guides/operations.md
  - guides/troubleshooting.md
  - guides/user_flows.md
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: resolved
resolution: "All 3 warnings (WR-01/02/03) fixed in commit 377a81d; full suite green (1151 tests, 0 failures). Info findings left as documented notes."
---

# Phase 93: Code Review Report

**Reviewed:** 2026-06-13
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Phase 93 (TRUTH-07) is a doc/test truth-parity correction: it reverses surfaces that
falsely denied the shipped admin console, adds `guides/admin_console.md`, wires the
guide into HexDocs extras, adds an `Admin Console` module group, reverses the JTBD
admin-UI exclusion in `user_flows.md`, and re-locks the corrected wording with parity
tests.

I verified every load-bearing factual claim against the actual code rather than
accepting the prose:

- The `Rindle` facade `@moduledoc` change is **accurate**: it affirms
  `Rindle.Admin.Router.rindle_admin/2`, correctly keeps `Rindle.Admin.Queries` framed
  as internal (`queries.ex` is `@moduledoc false`, and the boundary test confirms no
  `admin_*` reader was promoted onto the facade), and preserves the honest
  force-delete / cron-erasure deferrals.
- `guides/admin_console.md` matches the router implementation on every checkable
  detail: the eight `live(...)` routes, the production refusal rule
  (`allow_unauthenticated?` rejected in `:prod`; non-empty `:on_mount` OR
  `auth_guarded?: true` required), the static-asset allowlist
  (`rindle-admin.css`, `rindle-admin.js`, `logo.svg`, `favicon.svg`; `tokens.json`
  denied), and the option defaults (`as: :rindle_admin`, `home_path: "/"`,
  `live_socket_path: "/live"`, `transport: "websocket"`).
- `operations.md`'s "nine Mix tasks" claim matches the nine files under
  `lib/mix/tasks/`.
- The `mix.exs` `extras` path and the `groups_for_extras` Guides regex
  (`~r/guides\/(?!release_publish).*\.md$/`) correctly capture `guides/admin_console.md`.

No correctness or security defects were found in the facade code or the new guide
content. The findings below are docs-grouping completeness, test-assertion robustness
(over-broad / vacuous matchers that risk false-passing), and one pre-existing factual
error in `troubleshooting.md` that this in-scope file still carries.

## Warnings

### WR-01: `mix.exs` HexDocs module grouping omits 4 of the 9 shipped Mix tasks

**File:** `mix.exs:186-194`
**Issue:** The phase advertises "nine Mix tasks" in `operations.md` and the phase goal
is "closing requirements traceability" for the milestone audit, but the
`groups_for_modules` "Operations" group lists only 5 task modules:
`AbortIncompleteUploads`, `BackfillMetadata`, `CleanupOrphans`, `RegenerateVariants`,
`VerifyStorage`. Four shipped tasks with **visible** `@moduledoc` blocks are absent
from any module group:

- `Mix.Tasks.Rindle.Doctor`
- `Mix.Tasks.Rindle.RuntimeStatus`
- `Mix.Tasks.Rindle.BatchOwnerErasure`
- `Mix.Tasks.Rindle.SweepOrphanedTempFiles`

(also absent: the `Rindle.Ops.SweepOrphanedTempFiles` worker that `operations.md`
documents as cron-schedulable.) Because their `@moduledoc` is not `false`, ExDoc will
still render them — but ungrouped, they fall into the catch-all sidebar bucket instead
of "Operations." This is a documentation-traceability gap that contradicts the
operations guide's "nine Mix tasks" promise on the rendered HexDocs sidebar, and it is
squarely in scope for a milestone *audit* phase.
**Fix:** Add the four task modules (and the `SweepOrphanedTempFiles` worker) to the
`Operations` group:
```elixir
Operations: [
  Mix.Tasks.Rindle.AbortIncompleteUploads,
  Mix.Tasks.Rindle.BackfillMetadata,
  Mix.Tasks.Rindle.BatchOwnerErasure,
  Mix.Tasks.Rindle.CleanupOrphans,
  Mix.Tasks.Rindle.Doctor,
  Mix.Tasks.Rindle.RegenerateVariants,
  Mix.Tasks.Rindle.RuntimeStatus,
  Mix.Tasks.Rindle.SweepOrphanedTempFiles,
  Mix.Tasks.Rindle.VerifyStorage,
  Rindle.Workers.AbortIncompleteUploads,
  Rindle.Workers.CleanupOrphans,
  Rindle.Ops.SweepOrphanedTempFiles
]
```

### WR-02: operations.md "admin console" assertion can false-pass on the doc link alone

**File:** `test/install_smoke/docs_parity_test.exs:343-345`
**Issue:** The intent of this assertion is to verify that `operations.md` *affirms* the
mountable console (the affirmative half of TRUTH-07). The matcher is
`assert operations =~ ~r/admin[_ ]console/i`. But `operations.md` contains the link
target `admin_console.html`, whose substring `admin_console` already satisfies
`admin[_ ]console`. If a future edit deleted the prose sentence "Rindle now ships a
mountable admin console" but left the `[Admin Console](admin_console.html)` link, this
test would still pass while the affirmation it is meant to lock is gone. The companion
`refute "intentionally has no dashboard"` only guards the *old* phrasing, not the
presence of the new one — so the regression would be silent.
**Fix:** Tighten the assertion to match the affirmation prose, not the link, e.g.:
```elixir
assert operations =~ "ships a mountable admin console",
       "operations.md must affirm the mountable admin console (TRUTH-07)"
```
(or assert on `~r/mountable admin console/i`, which the link cannot satisfy).

### WR-03: `Rindle.delete/3` recovery instruction in troubleshooting.md is factually wrong

**File:** `guides/troubleshooting.md:112-113`
**Issue:** The Quarantined-Assets recovery step says: *"Run a deletion through
`Rindle.delete/3` (which transitions to `deleted` and enqueues `PurgeStorage`)."* This
is incorrect against the actual facade. `Rindle.delete/3` is
`delete(profile_module, storage_key, opts)` (`lib/rindle.ex:741-744`) — a raw
storage-adapter delete via `invoke_storage/3`. It takes a profile module and an object
key, **not** an asset, and it neither transitions any `MediaAsset` to the `deleted`
state nor enqueues a `PurgeStorage` job. An operator following this verbatim on a
quarantined asset would either pass the wrong arguments or, worse, delete a storage
object out from under a DB row without the state transition or purge bookkeeping the
guide promises — leaving the lifecycle inconsistent. This line predates Phase 93 (it
was not edited this phase), but `guides/troubleshooting.md` is an in-scope reviewed
file and the phase goal is doc-truth parity, so the inaccurate claim should be
corrected rather than carried forward.
**Fix:** Point at the supported owner/account-erasure or attachment-detach surfaces
(e.g. `Rindle.erase_owner/2` / `Rindle.detach/3`, which do drive state transitions and
async `PurgeStorage`), or describe the actual `quarantined -> deleted` mechanism, and
stop attributing FSM-transition + purge semantics to `Rindle.delete/3`.

## Info

### IN-01: `assert mix_exs =~ "guides/admin_console.md"` is a brittle wiring proxy

**File:** `test/install_smoke/docs_parity_test.exs:446-448`
**Issue:** The new "admin console truth" test reads `mix.exs` as text and asserts the
literal substring `"guides/admin_console.md"` is present. This passes whether the guide
is actually in the `extras` list or merely mentioned in a comment anywhere in `mix.exs`.
It is a reasonable lightweight smoke check, but it does not prove the guide is wired
into `extras` specifically (vs. appearing in some unrelated context). Low risk given the
file is small and hand-authored.
**Fix (optional):** Compile the docs config and assert membership in the extras list, or
scope the regex to the extras block. Acceptable to leave as-is for a doc smoke test.

### IN-02: Vacuous refute in troubleshooting parity assertion (pre-existing)

**File:** `test/install_smoke/docs_parity_test.exs:281`
**Issue:** `refute troubleshooting =~ "test/rindle/error_test.exs"` passes vacuously —
`guides/troubleshooting.md` has never contained that internal test path, so the refute
asserts nothing meaningful and would not catch the regression it implies it guards.
Pre-existing, not introduced by Phase 93.
**Fix (optional):** Remove the dead refute, or replace it with a positive assertion that
troubleshooting points at the public `Rindle.Error.message/1` surface (already asserted
on line 280), making the negative guard redundant.

### IN-03: admin_console.md advertises `{:rindle, "~> 0.3"}` while mix.exs is at 0.1.10

**File:** `guides/admin_console.md:54`, `mix.exs:4`
**Issue:** The guide's install snippet pins `{:rindle, "~> 0.3"}`, but the package
`@version` is currently `0.1.10`. Per the milestone plan the admin console ships in the
0.3.0 hex release, so this is an intentional forward-looking pin, not a bug. Flagged only
so the version is reconciled at release-cut time (the guide must not ship to HexDocs
under a 0.1.x artifact telling adopters to depend on `~> 0.3`).
**Fix:** No change needed now; verify the `~> 0.3` pin lands together with the 0.3.0
version bump at release.

### IN-04: "eight console pages" / "212 lines" claims are coupled to implementation

**File:** `guides/admin_console.md:117-132`
**Issue:** The guide hard-codes "The mount expands to eight routes" and enumerates a
route table. This currently matches the eight `live(...)` declarations in
`lib/rindle/admin/router.ex:95-108`, so it is accurate today. No parity test locks the
route count, so future router route additions/removals could silently drift the guide
out of truth.
**Fix (optional):** Consider a parity assertion that counts `live(` route declarations
against the guide's table, mirroring the existing TusPlug moduledoc parity pattern, if
this surface is expected to evolve.

---

_Reviewed: 2026-06-13_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
