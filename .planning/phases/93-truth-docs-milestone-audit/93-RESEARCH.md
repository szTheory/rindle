# Phase 93: Truth, Docs & Milestone Audit - Research

**Researched:** 2026-06-13
**Domain:** Documentation truth-parity, requirements traceability closure, milestone audit (Elixir/HexDocs project)
**Confidence:** HIGH (every claim below is grepped/read from this repo this session)

## Summary

Phase 93 is the v1.18 closeout. It is a TRUTH/DOCS/AUDIT phase, not a feature build. The
mountable admin console has shipped (`Rindle.Admin.Router.rindle_admin/2`, read surfaces in
Phase 89, ops actions in Phase 90, Cohort demo + mount in Phase 91, deterministic E2E in
Phase 92). Earlier docs and the `lib/rindle.ex` facade moduledoc were written when there was
NO admin UI and still assert "admin UI" is excluded / out of scope / not promised. This phase
makes every public and internal surface tell the truth, writes the adopter-facing
`guides/admin_console.md`, reverses the JTBD T4 "admin UI" exclusion, closes requirements
traceability, and regenerates the v1.18 milestone audit.

The false-claim surface is small and fully enumerated below: **exactly 7 hits across 5 files**
(`lib/rindle.ex`, `guides/operations.md`, `guides/troubleshooting.md`, `guides/user_flows.md`,
`.planning/JTBD-MAP.md` — two hits in user_flows, two in JTBD-MAP). The repo already has a
mechanical truth-locking pattern (`test/install_smoke/docs_parity_test.exs` using
`Code.fetch_docs/1` + `assert doc =~` / `refute doc =~`) that this phase should extend so the
corrected phrases are CI-locked and the false phrases can never reappear.

**Primary recommendation:** Treat this as a grep-asserted truth phase. (1) Fix the 7 false
claims with truthful replacements. (2) Author `guides/admin_console.md` (adopter-facing) and
wire it into `mix.exs` `docs/extras`. (3) Reverse JTBD T4 idempotently via the in-file anchor
protocol. (4) Add `refute "<false phrase>"` + `assert "<true phrase>"` parity assertions per
surface. (5) Close REQUIREMENTS.md traceability (flip stale "Planned" → "Complete"). (6)
Regenerate `.planning/v1.18-MILESTONE-AUDIT.md` (the existing draft is STALE — written
2026-06-12 when phases 90–93 did not exist).

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRUTH-07 | Docs/facade parity for the scope reversal — `lib/rindle.ex` facade contract, `guides/`, JTBD-MAP T4 row, and README updated truthfully. | False-Claim Inventory (exact 7 hits + corrections), Validation Architecture (grep/parity assertions), Console Ground Truth (what to describe), Traceability Closure spec, Milestone Audit spec. |

**Note on README:** TRUTH-07 names README explicitly, but the exhaustive scan found NO false
admin-UI claim in `README.md` — README simply OMITS the console. "Truthful" here means
ADDING an honest, short admin-console mention + a link to `guides/admin_console.md`, not
deleting a false claim. Success criterion 4 ("README and HexDocs describe the shipped console
truthfully") is satisfied by addition, not correction.
</phase_requirements>

## Architectural Responsibility Map

This phase touches documentation/planning surfaces only. No runtime tier work. Mapping is
which *surface* owns each truth obligation.

| Capability | Primary Surface | Secondary Surface | Rationale |
|------------|-----------------|-------------------|-----------|
| Facade truth (no "admin UI" denial) | `lib/rindle.ex` @moduledoc | `docs_parity_test.exs` | HexDocs renders the facade moduledoc as the landing module (`main: "Rindle"`). |
| Adopter how-to (mount/auth/pages/actions) | `guides/admin_console.md` (NEW) | `mix.exs` docs/extras | Adopter-facing guide; must be in HexDocs extras to be discoverable. |
| Operator truth ("no dashboard" reversal) | `guides/operations.md`, `guides/troubleshooting.md` | — | These claim a dashboard does not exist; now one does. |
| Job map (public) | `guides/user_flows.md` | — | Public JTBD map; two "admin UI excluded" hits. |
| Job map (internal strategy) | `.planning/JTBD-MAP.md` | — | T4 reversal lives here (row 36 + T4 frontier table); idempotent anchor protocol. |
| README discoverability | `README.md` | `mix.exs` docs/extras | Omission, not falsehood — add honest mention + guide link. |
| Traceability closure | `.planning/REQUIREMENTS.md` traceability table | phase SUMMARY/VERIFICATION frontmatter | Stale "Planned" rows for shipped reqs. |
| Milestone audit | `.planning/v1.18-MILESTONE-AUDIT.md` | `.planning/MILESTONES.md`, `.planning/ROADMAP.md` | Canonical milestone closeout artifact. |

## Standard Stack

No external packages installed. This phase edits Markdown, an Elixir `@moduledoc`, and an
ExUnit parity test. No `## Package Legitimacy Audit` needed (no installs).

| Tool | Already present | Purpose |
|------|-----------------|---------|
| `Code.fetch_docs/1` | yes (used in `docs_parity_test.exs`) | Read compiled `@moduledoc` to assert/ refute phrases. |
| `mix docs` (ex_doc) | yes (`mix.exs docs()`) | HexDocs generation; `extras:` list controls which guides ship. |
| grep / ripgrep | yes | Mechanical false-phrase absence checks. |

## False-Claim Inventory (CRITICAL — exhaustive)

Scanned: `lib/`, `README.md`, `guides/`, `mix.exs`, `.planning/JTBD-MAP.md`,
`guides/user_flows.md`, `examples/adoption_demo/README.md`. Phrases:
`admin ui`, `no dashboard`, `intentionally has no`, `out of scope … (ui|console)`,
`excluded by design`, `headless`, `bring your own ui`, `library only`, `no web interface`.

**Result: exactly 7 false/stale hits in 5 public surfaces. No others exist.**
`[VERIFIED: grep over repo, 2026-06-13]`

| # | File:Line | Offending text (verbatim) | Truthful correction (intent — planner finalizes wording) |
|---|-----------|---------------------------|----------------------------------------------------------|
| F1 | `lib/rindle.ex:46` | "This facade contract does not promise inline storage deletion, **admin UI**, scheduler/cron erasure jobs, or force-delete behavior…" | Remove "admin UI" from the negative list. The facade still doesn't promise inline storage deletion / cron erasure / force-delete, but the admin UI now EXISTS (mountable, separate from the facade). Optionally add a one-line pointer: the mountable console is `Rindle.Admin.Router.rindle_admin/2`, documented in `guides/admin_console.md`; admin reads live in `Rindle.Admin.Queries`, not this facade. |
| F2 | `guides/operations.md:43` | "The current contract intentionally **has no dashboard** and no auto-remediation." | "Rindle now ships a mountable admin console (`guides/admin_console.md`) for read + operational surfaces. The contract still has no auto-remediation — the console executes existing operator verbs, it does not act on its own." |
| F3 | `guides/troubleshooting.md:21` | "The contract intentionally **has no dashboard** and no auto-remediation layer in this release." | Same as F2: dashboard now exists (link the guide); auto-remediation still absent by design. |
| F4 | `guides/user_flows.md:301` | "…and `mix rindle.batch_owner_erasure`. **Admin UI**, force-delete policy for still-shared assets, and scheduler/cron erasure jobs remain deferred." | Remove "Admin UI" from the deferred list (it shipped v1.18 / hex 0.3.0). Force-delete + cron erasure remain deferred. Optionally add a sentence pointing to the console for erasure preview/execute UX. |
| F5 | `guides/user_flows.md:354` | "Deliberately *out of scope*, by design: … broad PDF/Office handling, **an admin UI**, or a CDN replacement." | Remove "an admin UI" from the out-of-scope list. The other non-goals stand. |
| F6 | `.planning/JTBD-MAP.md:91` (job row 36) | "\| 36 \| "Full HLS/DASH platform, DRM, AI/GPU processing, PDF/Office, **admin UI**, CDN replacement." \| — \| ⛔ \| — \| Explicit non-goals…" | Remove "admin UI" from row 36's excluded list AND add a NEW shipped JTBD row for the admin console (✅, v1.18, `Rindle.Admin.Router.rindle_admin/2`). See T4 Reversal section. |
| F7 | `.planning/JTBD-MAP.md:106` (T4 frontier table) | "\| **T4 — Beyond the frontier** \| HLS/DASH platform, DRM, AI/GPU, PDF/Office, **admin UI**, CDN replacement \| **Negative** … \| ⛔ Excluded by design \|" | Remove "admin UI" from the T4 row. Admin console is now shipped (a deliberate, charter-recorded scope change, not a T4 capitulation). See T4 Reversal section. |

**Non-hits worth noting (do NOT "fix"):**
- `guides/ui_principles.md:31` "No UI text depends on hover-only disclosure." — accessibility rule, unrelated.
- `guides/admin_console_architecture.md` / `guides/rindle_admin_css.md` — describe the console truthfully (these are internal Phase 86/88 architecture docs, NOT in HexDocs extras).
- `README.md` — NO false claim; it OMITS the console (handled by addition, see F-README below).
- `examples/adoption_demo/README.md` — already truthful; documents `http://localhost:4102/admin/rindle` and an "Admin Console Walkthrough" section.

**F-README (addition, not correction):** `README.md` has no admin/console/dashboard mention in
its guide list (lines ~267–269) or body. Add a short honest mention and a
`[Admin Console](admin_console.html)` link so a hex.pm/HexDocs reader learns the console exists.

## Console Ground Truth (what the docs MUST describe)

All verified by reading `lib/rindle/admin/router.ex` and phase 89/90 artifacts this session.
`[VERIFIED: source read, 2026-06-13]`

**Public entry point (the ONLY new public surface this milestone):**
- Router macro: `Rindle.Admin.Router.rindle_admin/2` — `defmacro rindle_admin(path, opts \\ [])`.
- Module is guarded: `if Code.ensure_loaded?(Phoenix.LiveView) and Code.ensure_loaded?(Phoenix.Router) and Code.ensure_loaded?(Plug.Static)` — compiles away cleanly without `phoenix_live_view` (ADMIN-06).
- Macro expands to **direct LiveView routes** inside a `live_session` (LiveDashboard/Oban-Web style), NOT a forward-only plug.

**Mount / auth model (ADMIN-01):**
- Host owns browser pipeline, auth pipeline, LiveView `:on_mount`, scope placement, actor assigns. Rindle owns only route expansion + static asset serving.
- Production refuses unsafe mounts: requires non-empty `:on_mount` OR explicit `auth_guarded?: true`.
- `allow_unauthenticated?: true` is a dev/test-only escape hatch, rejected in `:prod`.
- Options: `:on_mount`, `:as` (default `:rindle_admin`), `:home_path` (default `"/"`), `:live_socket_path` (default `"/live"`), `:transport` (default `"websocket"`), `:csp_nonce_assign_key`, `auth_guarded?`, `allow_unauthenticated?`.

**Self-contained assets (ADMIN-02):** served via `Rindle.Admin.Router.StaticAssetsPlug` from
`priv/static/rindle_admin/` — allowlist `rindle-admin.css`, `rindle-admin.js`, `logo.svg`,
`favicon.svg`; `tokens.json` explicitly denied. Zero host Tailwind/esbuild dependency.

**Pages / routes (from the macro, ADMIN-03 read surfaces + ADMIN-04 actions):**
| Route (relative to mount `path`) | LiveView | Surface |
|----------------------------------|----------|---------|
| `/` (home) | `Rindle.Admin.Live.HomeLive` | Task-oriented home / status |
| `/assets` | `Rindle.Admin.Live.AssetsLive :index` | Assets list (FSM-state filterable) |
| `/assets/:id` | `Rindle.Admin.Live.AssetsLive :show` | Asset detail (timeline, variants, attachments) |
| `/upload-sessions` | `Rindle.Admin.Live.UploadSessionsLive :index` | Upload sessions |
| `/upload-sessions/:id` | `Rindle.Admin.Live.UploadSessionsLive :show` | Upload session detail |
| `/variants-jobs` | `Rindle.Admin.Live.VariantsJobsLive` | Variant/job activity + findings |
| `/runtime-doctor` | `Rindle.Admin.Live.RuntimeDoctorLive` | Doctor + runtime status |
| `/actions` | `Rindle.Admin.Live.ActionsLive` | Ops actions hub (ADMIN-04) |

**Ops actions (ADMIN-04, Phase 90 — verified 8/8 truths):** owner erasure preview/execute with
typed `ERASE type:id` confirmation; batch erasure with typed `ERASE N OWNERS` confirmation +
partial-failure receipts; lifecycle repair (`Rindle.reprobe/1`, `Rindle.requeue_variants/2`);
variant regeneration (`Rindle.Ops.VariantMaintenance.regenerate_variants/1`); read-only
quarantine triage panel. **No new lifecycle semantics** — reuses existing facade/ops.

**Live updates (ADMIN-05):** reuses `Rindle.PubSub` and existing `:asset` / `:variant` /
`:upload_session` topics; reads isolated in `Rindle.Admin.Queries` (7 `/1` query fns +
`actions_directory/0`), NOT on the public `Rindle` facade.

**Cohort mount (DEMO-03):** `examples/adoption_demo/lib/adoption_demo_web/router.ex` — `scope
"/admin"` + `rindle_admin("/rindle", allow_unauthenticated?: true)` → reachable at
`/admin/rindle` (demo port 4102). Walkthrough documented in `examples/adoption_demo/README.md`
under "Admin Console Walkthrough".

## guides/admin_console.md (NEW — does not exist yet)

`ls guides/admin_console.md` → NOT FOUND. `[VERIFIED]` The closest existing artifacts:
- `guides/admin_console_architecture.md` — internal Phase 86 architecture LOCK (forward-looking, "Phase 89 implements…"). NOT in HexDocs extras. Good source material, wrong audience/tense.
- `guides/admin_console_ia.md`, `guides/admin_console_motion.md`, `guides/rindle_admin_css.md`, `guides/admin_design_system.md` — internal design/IA docs, also not in extras.

**Format analog to mirror:** `guides/streaming_providers.md` and `guides/storage_gcs.md` are the
canonical adopter-facing "optional feature" guides (env/setup → wiring → usage → troubleshooting,
~340/~9.8k chars). Match their voice and section rhythm.

**Recommended structure for `guides/admin_console.md` (present-tense, adopter how-to):**
1. What it is — host-authenticated, library-owned mountable console; the only new public surface.
2. Requirements — `phoenix_live_view` optional dep; host owns auth.
3. Mounting — the `rindle_admin/2` macro inside an authenticated `scope`, copy-pasteable example (mirror the `admin_console_architecture.md` snippet but present-tense and adopter-framed).
4. Auth & the production refusal rule — `:on_mount` / `auth_guarded?` / dev-only `allow_unauthenticated?`.
5. Pages — the 8-route table above.
6. Actions — destructive UX, typed confirmation, reuse of existing facade verbs, no new semantics.
7. Assets / CSP — self-contained assets, `:csp_nonce_assign_key`, `:live_socket_path`, `:transport`.
8. Optional-dependency behavior — compiles away without LiveView.
9. Try it — point to the Cohort demo `/admin/rindle`.

**Must wire into `mix.exs` `docs/extras`** (currently absent) and likely into the `Guides:`
`groups_for_extras` regex (which already matches `guides/.*\.md` except release_publish).

## user_flows + JTBD-MAP "T4 admin UI reversal"

**What "T4" is:** `.planning/JTBD-MAP.md` defines a five-tier completeness frontier
(T0 table-stakes → T4 "Beyond the frontier"). T4 = "HLS/DASH platform, DRM, AI/GPU, PDF/Office,
**admin UI**, CDN replacement" marked "⛔ Excluded by design / Negative value". The v1.18 charter
(ROADMAP line 32; REQUIREMENTS lines 9–14) **deliberately reverses** the admin-UI exclusion as a
recorded maintainer-pull scope change.

**The reversal touches THREE rows** (not one):
- JTBD-MAP job **row 36** (line 91): remove "admin UI" from the non-goals list.
- JTBD-MAP **T4 frontier table** (line 106): remove "admin UI" from the T4 row.
- ADD a **new shipped JTBD row** (✅, v1.18, `Rindle.Admin.Router.rindle_admin/2`) — the admin
  console is now a shipped job, not just an un-excluded one. Phrase it as a charter-recorded
  scope change, not a frontier capitulation (the OTHER T4 items stay excluded).
- `guides/user_flows.md` rows F4 (line 301) and F5 (line 354) — remove "admin UI" from the
  deferred/out-of-scope lists; optionally add a short "manage the lifecycle in a UI" job.

**Anchor protocol (idempotent — MUST follow):** `.planning/JTBD-MAP.md` has an "Update protocol"
section (lines 17–30). The file is regenerated by re-running the JTBD prompt, in place:
1. Read the **anchor** line at top: `> Generated: … · Against: milestone v1.16 … · hex 0.1.5 · git fbd09de`.
2. Compute delta: `git log <anchor-sha>..HEAD --oneline`, new ROADMAP/MILESTONES rows, new CHANGELOG sections, new `lib/`/`guides/` files.
3. Move rows 🔲 Backlog → ✅ Shipped; re-rank gaps; reverse the T4 admin-UI exclusion.
4. **Refresh the anchor line** (date, milestone → v1.18, hex 0.3.0, new sha) and append a dated regeneration-history entry (the file keeps a history list at the bottom, e.g. lines 188–198).

`guides/user_flows.md` does NOT carry a machine anchor line — it is the public companion; update
it in lockstep with JTBD-MAP (the two "move together" per JTBD-MAP intro). It references the
Cohort demo at top; the admin console should appear in its job map too.

**Skill note:** No `SKILL.md` for JTBD/user-flows exists in this repo
(`find … -name SKILL.md` → only `.codex/skills/gsd-milestone-next-step/`). The "recurring JTBD
docs workflow" is the in-file Update-protocol section itself, plus the user's MEMORY entry
"JTBD docs workflow" (in-file anchor protocol, idempotent). Treat the in-file protocol as authority.

## README + HexDocs parity

**README today:** No false admin claim; the console is simply absent. Guide list (lines ~267–269)
links User Flows / Getting Started but not the console. Action: add a short, honest console
mention + `[Admin Console](admin_console.html)` link.

**HexDocs config (`mix.exs docs()`):** `[VERIFIED: mix.exs read]`
- `main: "Rindle"` → the facade `@moduledoc` (with the F1 false "admin UI" line) is the LANDING page. Fixing F1 is high-leverage.
- `extras:` lists 16 docs; **none of the admin_console_* guides are included.** `guides/admin_console.md` must be ADDED here or HexDocs readers never see it.
- `groups_for_extras: Guides: ~r/guides\/(?!release_publish).*\.md$/` — a new `guides/admin_console.md` auto-falls into "Guides" once added to `extras`.
- `groups_for_modules:` has no "Admin Console" group. Optional: add one for `Rindle.Admin.Router` so the macro is discoverable in the module sidebar. (`Rindle.Admin.Queries` is intentionally internal — keep it OUT of public module groups.)
- `description: "Phoenix/Ecto-native media lifecycle library. Media, made durable."` — no UI claim; fine as-is (optional: mention the console, low priority).

**Places a HexDocs reader forms a false impression today:** (1) `Rindle` landing moduledoc F1;
(2) `operations.md` F2; (3) `troubleshooting.md` F3; (4) `user_flows.md` F4/F5. All four are in
`extras` and rendered. Fixing the 7 hits + adding the guide closes HexDocs parity.

## Requirements Traceability Closure

**How traceability is tracked:** `.planning/REQUIREMENTS.md` has a `## Traceability` table
(lines 148–175): `| Requirement | Phase | Status |`. "Closed" operationally means every active
v1.18 requirement's Status reflects reality, cross-referenced 3 ways (REQUIREMENTS checkbox +
phase VERIFICATION.md + SUMMARY frontmatter), per the prior-audit pattern in
`v1.15-MILESTONE-AUDIT.md` ("3-source cross-reference").

**Stale rows to fix (current vs. truth):** `[VERIFIED: REQUIREMENTS.md + phase artifacts]`
| Req | Current Status | Should be | Evidence |
|-----|----------------|-----------|----------|
| ADMIN-03 | Planned | Complete | Phase 89 VERIFICATION passed; checkbox already `[x]`. |
| ADMIN-04 | Planned | Complete | Phase 90 VERIFICATION 8/8 truths verified. |
| ADMIN-05 | Planned | Complete | Phase 89 VERIFICATION passed. |
| DEMO-01 | Planned | Complete | Phase 91 VERIFICATION 6/6; checkbox `[x]`. |
| DEMO-02 | Planned | Complete | Phase 91 VERIFICATION. |
| DEMO-03 | Planned | Complete | Phase 91; Cohort mounts `/admin/rindle`. |
| E2E-01 | Planned | Complete | Phase 92 SUMMARYs `requirements-completed: [E2E-01]`. |
| DX-01/02/03 | Planned | Complete (DX-03 was "partial" in draft audit only because Cohort had not mounted yet — Phase 91 closed it) | Phase 87 passed; Phase 91 mounts console so DX-03 URL map is now routeable. |
| TRUTH-07 | Planned | Complete (THIS phase) | Closed by Phase 93 itself. |

Also note the REQUIREMENTS checkboxes (lines 18–70): all are `[x]` EXCEPT **TRUTH-07** (`[ ]`,
line 69). Phase 93 flips TRUTH-07 to `[x]` and resolves the Status-column drift. The draft audit's
`tech_debt` item "REQUIREMENTS.md traceability table still marks ADMIN-03, ADMIN-05, DX-01..03 as
Planned even though phase verification marks them satisfied" is exactly this closure work.

**Update the Coverage summary** (lines 177–181): "8 satisfied" → 19/19 satisfied at close.

## v1.18 Milestone Audit

**The existing draft is STALE.** `.planning/v1.18-MILESTONE-AUDIT.md` (untracked, dated
2026-06-12T17:42) was written when phases 90–93 had no directories. It scores "11/19 satisfied,
7 orphaned" and marks 90/91/92/93 "missing". That is now FALSE: phases 90, 91, 92 all have
PLAN/SUMMARY/VERIFICATION/VALIDATION artifacts and `status: human_needed` with all must-haves
verified (90: 8/8, 91: 6/6, 92: 4/4). **Treat the draft as an input/template, not authority —
regenerate it.** `[VERIFIED: phase dir + VERIFICATION reads]`

**Canonical audit structure** (from `v1.15-MILESTONE-AUDIT.md`, the cleanest analog):
1. **YAML frontmatter:** `milestone`, `name`, `audited` (ISO), `status` (gaps_found | tech_debt | shipped), `scores: {requirements, phases, integration, flows}`, `nyquist: {compliant_phases, partial_phases, missing_phases, overall}`, `gaps: {requirements, integration, flows}`, `tech_debt`.
2. **Result / Status** + one-paragraph verdict.
3. **Scope table** (PROJECT/ROADMAP/REQUIREMENTS/phase-artifacts found).
4. **Phase Verification Summary** table (Phase | Goal | VERIFICATION.md | Status | Requirements Verified) — for ALL 8 phases 86–93.
5. **Requirements Coverage 3-source cross-reference** (Req | Phase | VERIFICATION | SUMMARY frontmatter | REQUIREMENTS.md | Final).
6. **Integration Report** (wired paths / broken paths).
7. **Nyquist Coverage** table (per-phase VALIDATION.md compliance).
8. **Tech Debt by Phase.**
9. **Verdict.**

**Required inputs:** all 8 phase VERIFICATION.md + SUMMARY frontmatter; REQUIREMENTS.md
traceability (post-closure); ROADMAP success criteria 1–6 for Phase 93 itself.

**Expected score at honest close:** 19/19 requirements satisfied; 8/8 phases verified. Caveat:
phases 90/91/92/93 are `status: human_needed` (HUMAN-UAT pending), and Nyquist VALIDATION.md
exists for 90/91/92 but NOT yet for 93 — the audit must note Phase 93's own VALIDATION as a
follow-up (or the plan creates `93-VALIDATION.md`). The audit should reflect whether human UAT
is signed off; if not, status may be `tech_debt` (shippable with recorded human-UAT follow-ups)
rather than `shipped`. **Do not over-claim `shipped`** if HUMAN-UAT items remain open — flag them.

**Naming:** prior audits live at BOTH `.planning/vX-MILESTONE-AUDIT.md` (working) and
`.planning/milestones/vX-MILESTONE-AUDIT.md` (archived at next milestone). The working copy is
`.planning/v1.18-MILESTONE-AUDIT.md` (overwrite the stale draft). ROADMAP/MILESTONES link the
`milestones/` archived path at completion.

## Runtime State Inventory

This is a docs/audit phase. Categories assessed:
| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no datastore stores any phrase being changed. | none |
| Live service config | None — no external service config references "admin UI". | none |
| OS-registered state | None. | none |
| Secrets/env vars | None — no secret/env key references the changed text. | none |
| Build artifacts | The `Rindle` `@moduledoc` is COMPILED — `docs_parity_test.exs` reads it via `Code.fetch_docs/1`, so after editing `lib/rindle.ex` the module must recompile before the parity assertion runs. `mix test` handles this automatically. Stale `_build` HexDocs/ExDoc output regenerates on `mix docs`. | recompile (automatic under mix) |

**Nothing found** in Stored data / Live service config / OS-registered / Secrets — verified by
the exhaustive grep scope (no DB keys, no service config, no env names carry the phrase).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Verifying the false phrases are gone | A bespoke audit script | Extend `test/install_smoke/docs_parity_test.exs` with `refute doc =~ "admin UI"` (facade) + `refute guide =~ "intentionally has no dashboard"` etc. | The repo already locks doc truth this exact way; CI runs it merge-blocking (proof lane). |
| Reading the facade moduledoc | File-grep on `lib/rindle.ex` source | `Code.fetch_docs(Rindle)` | Source grep misses interpolation/compilation; the existing parity test reads compiled docs. |
| Idempotent JTBD-MAP update | Recreating the file | The in-file Update-protocol + anchor line | Recreating loses the regeneration history and breaks idempotency the file explicitly requires. |
| Milestone audit scoring | Inventing a new format | Copy `v1.15-MILESTONE-AUDIT.md` frontmatter + section skeleton | Tooling and humans expect the canonical 3-source structure. |

**Key insight:** Truth in this repo is enforced mechanically, not by prose discipline. Every
corrected phrase should have a matching `assert`/`refute` so it can never silently regress.

## Common Pitfalls

### Pitfall 1: Treating the stale draft audit as ground truth
**What goes wrong:** The existing `.planning/v1.18-MILESTONE-AUDIT.md` says phases 90–93 don't
exist and 7 reqs are orphaned. Copying its conclusions would re-orphan shipped work.
**How to avoid:** Regenerate from current phase artifacts (90/91/92 are done). Use the draft only
for its structure.

### Pitfall 2: Missing the JTBD T4 reversal's THREE edit points
**What goes wrong:** Fixing only the visible "T4 row" (line 106) and leaving job row 36 (line 91)
and the two `user_flows.md` hits still excluding admin UI.
**How to avoid:** The False-Claim Inventory lists all of them (F4–F7) plus the NEW shipped row.

### Pitfall 3: Authoring guides/admin_console.md but not wiring it into HexDocs
**What goes wrong:** The guide exists in `guides/` but `mix.exs` `extras:` doesn't list it, so
hex.pm readers never see it — success criterion 4 fails silently.
**How to avoid:** Add to `extras:` (and confirm it lands in the `Guides:` group).

### Pitfall 4: Over-claiming `shipped` while HUMAN-UAT is open
**What goes wrong:** Phases 90/91/92/93 are `status: human_needed`. Declaring the milestone
`shipped` ignores pending human verification.
**How to avoid:** Audit status = `tech_debt` (or `gaps_found`) with explicit human-UAT follow-ups
unless the maintainer signs off UAT during this phase.

### Pitfall 5: Editing the facade moduledoc wording so the parity test still matches an old assertion
**What goes wrong:** `docs_parity_test.exs` asserts specific facade phrases; removing/adding text
near them can break an existing `assert doc =~`.
**How to avoid:** Run `mix test test/install_smoke/docs_parity_test.exs` after the F1 edit.

## Validation Architecture

> `workflow.nyquist_validation` is not disabled → this section is REQUIRED. It defines how each
> truth-claim is mechanically VERIFIABLE so a `93-VALIDATION.md` can be derived.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir) + grep/ripgrep for absence checks |
| Config file | `mix.exs` (`test/test_helper.exs`); parity tests under `test/install_smoke/` |
| Quick run command | `mix test test/install_smoke/docs_parity_test.exs` |
| Full suite command | `mix test` (and `mix docs` to regenerate HexDocs) |
| Existing pattern | `test/install_smoke/docs_parity_test.exs` uses `Code.fetch_docs/1` + `assert/refute doc =~` |

### Phase Requirements → Test Map
| Req | Behavior | Test Type | Automated Command | Exists? |
|-----|----------|-----------|-------------------|---------|
| TRUTH-07 (F1) | Facade moduledoc no longer denies admin UI | unit | `mix test test/install_smoke/docs_parity_test.exs` with `refute Code.fetch_docs(Rindle)... =~ "admin UI"` | ❌ Wave 0 (extend test) |
| TRUTH-07 (F1+) | Facade points to console truthfully | unit | `assert doc =~ "Rindle.Admin.Router.rindle_admin"` | ❌ Wave 0 |
| TRUTH-07 (F2/F3) | operations + troubleshooting no longer claim "no dashboard" | unit | `refute File.read!("guides/operations.md") =~ "intentionally has no dashboard"` (+ troubleshooting) | ❌ Wave 0 |
| TRUTH-07 (F4/F5) | user_flows no longer excludes admin UI | unit | `refute uf =~ "an admin UI"` and `refute uf =~ "Admin UI, force-delete"` | ❌ Wave 0 |
| TRUTH-07 (guide) | admin_console.md exists, in extras, mentions macro | unit | `assert File.exists?("guides/admin_console.md")`; `assert mix_docs_extras includes it`; `assert guide =~ "rindle_admin"` | ❌ Wave 0 |
| TRUTH-07 (README) | README mentions the console | unit | `assert File.read!("README.md") =~ "admin_console.html"` (or "Admin Console") | ❌ Wave 0 |
| TRUTH-07 (JTBD-MAP) | T4 no longer excludes admin UI; anchor refreshed to v1.18 | grep/manual | `! grep -q "admin UI" <T4 + row36 lines>`; `grep -q "v1.18" anchor` | ❌ Wave 0 (or manual check) |
| TRUTH-07 (traceability) | No active req stuck "Planned"; TRUTH-07 `[x]` | grep | `! grep -E "ADMIN-0[345].*Planned" .planning/REQUIREMENTS.md` ; `grep -q "TRUTH-07.*Complete"` | ❌ Wave 0 (or manual) |

### Sampling Rate
- **Per task commit:** `mix test test/install_smoke/docs_parity_test.exs`
- **Per wave merge:** `mix test` + `mix docs` (confirm guide renders, no broken extras link)
- **Phase gate:** full suite green + a repo-wide `grep` proving zero false phrases remain on public surfaces, before `/gsd:verify-work`.

### Concrete verification commands (drop-in)
```bash
# 1. No false admin-UI denial on any public surface (must return zero lines):
grep -rni -E "admin ui|intentionally has no dashboard|excluded by design.*admin|an admin UI" \
  lib/rindle.ex README.md guides/operations.md guides/troubleshooting.md guides/user_flows.md \
  | grep -v "admin_console" || echo "OK: no false admin-UI claims remain"

# 2. Facade moduledoc no longer denies admin UI (compiled doc):
MIX_ENV=test mix run -e 'IO.puts(elem(Code.fetch_docs(Rindle), 4) |> Map.get("en"))' | grep -i "admin ui" \
  && echo "FAIL: facade still mentions admin UI denial" || echo "OK"

# 3. New guide exists and is wired into HexDocs:
test -f guides/admin_console.md && grep -q "admin_console.md" mix.exs && echo "OK: guide wired"

# 4. JTBD-MAP anchor refreshed to v1.18:
grep -E "Against:.*v1\.18" .planning/JTBD-MAP.md && echo "OK: anchor refreshed"

# 5. Parity test passes:
mix test test/install_smoke/docs_parity_test.exs
```

### Wave 0 Gaps
- [ ] Extend `test/install_smoke/docs_parity_test.exs` (or add `admin_console_docs_parity_test.exs`) with the `refute`/`assert` truth assertions above — covers TRUTH-07.
- [ ] `guides/admin_console.md` must be created before the "guide exists + in extras" assertion can pass.
- [ ] `93-VALIDATION.md` does not exist yet — the plan should create it (phases 90/91/92 have one; 93 must too for Nyquist closure, and the milestone audit flags its absence).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir/mix | running `mix test` / `mix docs` | ✓ (repo builds) | project toolchain | — |
| ex_doc | `mix docs` HexDocs render | ✓ (configured in `mix.exs docs()`) | — | — |
| grep/ripgrep | absence assertions | ✓ | — | — |
| git | JTBD anchor delta (`git log <sha>..HEAD`) | ✓ | — | — |

No external services. No installs. No blocking dependencies.

## Project Constraints (from CLAUDE.md)

No `./CLAUDE.md` exists in the repo (`Read` returned file-not-found). Constraints drawn from
planning docs instead:
- **v1.18 new-API boundary (STATE.md):** the ONLY new public surface is the mountable console (router macro + mount config); operational queries stay in `Rindle.Admin.Queries`; console actions reuse existing facade capabilities — **no new lifecycle semantics.** Docs must describe exactly this and not promote `Rindle.Admin.Queries` to the public facade.
- **Do NOT** reopen tus/Mux/owner-erasure semantics or add force-delete/second-provider (demand-gated → v1.19+). Truth edits must keep force-delete + cron erasure listed as deferred/out-of-scope (only "admin UI" leaves those lists).
- **JTBD idempotency (MEMORY + JTBD-MAP):** update JTBD-MAP/user_flows in place via the anchor protocol; do not recreate.
- **Plan→execute cost checkpoint (MEMORY):** offer one checkpoint before auto-advancing into execution.

## State of the Art

| Old (pre-v1.18) | Current (v1.18 / hex 0.3.0) | When changed | Impact |
|-----------------|------------------------------|--------------|--------|
| "Rindle has no admin UI; headless library only" | Mountable `Rindle.Admin.Router.rindle_admin/2` console shipped | v1.18 charter 2026-06-10, implemented phases 89–92 | All 7 false claims must flip; new adopter guide + HexDocs entry. |
| JTBD T4 excludes admin UI "by design" | Admin UI is a recorded scope reversal, now shipped | charter 2026-06-10 | T4 frontier + job row 36 + new shipped row. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Exact corrected WORDING of each fixed phrase is the planner's/maintainer's call; this research gives intent, not final prose. | False-Claim Inventory | Low — planner finalizes; assertions test intent not exact prose. |
| A2 | Milestone status at close is likely `tech_debt` not `shipped`, because phases 90–93 are `status: human_needed` (HUMAN-UAT pending). | Milestone Audit | Medium — if maintainer signs UAT during this phase, status can be `shipped`. Verify UAT sign-off state at plan time. |
| A3 | Whether to add a `Rindle.Admin.Router` "Admin Console" group to `groups_for_modules` is optional polish, not required by TRUTH-07. | README + HexDocs | Low. |

## Open Questions (RESOLVED)

1. **Milestone close status (`shipped` vs `tech_debt`).**
   - Known: phases 90/91/92 verified all must-haves but are `status: human_needed`; `91-HUMAN-UAT.md` and `92-HUMAN-UAT.md` exist.
   - Unclear: whether the maintainer has signed off human UAT.
   - Recommendation: audit reports `tech_debt` with explicit HUMAN-UAT follow-ups unless sign-off is confirmed during the phase; do not block Phase 93 docs work on it.

2. **Does Phase 93 itself need a `93-VALIDATION.md` for Nyquist closure?**
   - Known: 90/91/92 each have one; the stale audit flags 93 missing.
   - Recommendation: yes — the plan should produce `93-VALIDATION.md` so the regenerated audit shows Nyquist `complete`, not `partial`.

3. **Should `mix.exs description` mention the console?**
   - Recommendation: optional/low priority; the guide + landing moduledoc carry the truth.

## Sources

### Primary (HIGH confidence — all read/grepped this session)
- `lib/rindle.ex` (facade @moduledoc, line 46 false claim) — read
- `lib/rindle/admin/router.ex` (macro, options, routes, asset plug) — read
- `mix.exs` (`docs()`, `extras`, `groups_for_*`, package files) — read
- `guides/operations.md`, `guides/troubleshooting.md`, `guides/user_flows.md` — grep + context
- `.planning/JTBD-MAP.md` (T4 table, row 36, anchor/update protocol) — read
- `.planning/REQUIREMENTS.md` (TRUTH-07, traceability table, coverage) — read
- `.planning/ROADMAP.md`, `.planning/MILESTONES.md`, `.planning/STATE.md` — read
- `.planning/v1.18-MILESTONE-AUDIT.md` (stale draft — assessed as input) — read
- `.planning/milestones/v1.15-MILESTONE-AUDIT.md` (canonical audit structure) — read
- `test/install_smoke/docs_parity_test.exs` (truth-locking pattern) — grep
- Phase 90/91/92 VERIFICATION.md + SUMMARY frontmatter — read
- `examples/adoption_demo/lib/adoption_demo_web/router.ex` + `README.md` (Cohort mount `/admin/rindle`, walkthrough) — grep
- `guides/admin_console_architecture.md` (format/material analog) — read

### Secondary / Tertiary
- None — no web research required; this is a closed-repo truth/audit phase.

## Metadata

**Confidence breakdown:**
- False-claim inventory: HIGH — exhaustive grep over all named public surfaces; 7 hits, fully located.
- Console ground truth: HIGH — read directly from `router.ex` + phase VERIFICATIONs.
- Audit structure: HIGH — copied from prior shipped audit.
- Traceability closure: HIGH — cross-referenced REQUIREMENTS vs phase artifacts.
- Milestone close status: MEDIUM — depends on human-UAT sign-off state (A2/Q1).

**Research date:** 2026-06-13
**Valid until:** 2026-06-27 (stable; only invalidated by further edits to the named surfaces)

## RESEARCH COMPLETE
