# SECURITY — Phase 90: console-ops-actions

**Audit type:** Threat-mitigation verification (register authored at plan time; not a fresh STRIDE scan)
**ASVS Level:** 2
**block_on:** high
**Result:** SECURED — 4/4 threats resolved (3 mitigate CLOSED, 1 accept documented)
**Implementation files:** READ-ONLY — not modified during this audit.

Trust boundary under review: **Admin UI → Ops Facade**. Admin inputs must be
verified server-side before reaching `Rindle` facades; destructive actions must
not be bypassable via client-side manipulation.

---

## Threat Verification

| Threat ID | Category | Disposition | Status | Evidence |
|-----------|----------|-------------|--------|----------|
| T-90-01 | Spoofing | mitigate | CLOSED | `lib/rindle/admin/live/actions_live.ex:57-68` (owner), `:133-144` (batch) |
| T-90-02 | Tampering | mitigate | CLOSED | `lib/rindle/admin/live/actions_live.ex:90-113` (owner), `:166-189` (batch) |
| T-90-03 | Denial of Service | accept | DOCUMENTED | Accepted-risk log below |
| T-90-04 | Elevation of Privilege | mitigate | CLOSED | `lib/rindle/admin/live/actions_live.ex:548-567` (no event surface) |

---

## T-90-01 — Spoofing: ActionsLive form state — CLOSED

**Claim:** Changing target-scope inputs after a preview invalidates the existing
preview/confirmation state immediately, so a confirmation typed for owner A
cannot execute against owner B.

**Evidence — owner erasure** (`actions_live.ex:48-68`): the `change_owner_erasure`
handler has three clauses. The no-op clause (`:57-64`) only matches when the
submitted `owner_type`/`owner_id` exactly equal the previewed
`action_data.{type,id}` (`when type == current_type and id == current_id`). Any
divergence falls through to the catch-all (`:66-68`) which resets
`action_state: :input` and clears `action_data: %{}`, destroying the preview.

**Evidence — batch erasure** (`actions_live.ex:124-144`): identical structure
keyed on `owners_text` vs. the previewed `action_data.owners_text`.

**Test:** `actions_live_test.exs:191-207` (owner erasure: changing `owner_id`
after preview returns the view to `data-rindle-admin-state="input"`).

---

## T-90-02 — Tampering: Execution events — CLOSED

**Claim:** Execute handlers must re-verify the typed confirmation string
server-side against the *previewed* targets before invoking facades; the count N
and target identity must be bound to the previewed set, not attacker-controllable
at execute time.

**Evidence — owner erasure** (`actions_live.ex:89-113`): the execute clause only
matches when `action_state: :preview` and destructures `type`/`id` from
**socket.assigns.action_data** (the previewed targets), taking only
`confirmation` from client params. The expected phrase is rebuilt server-side as
`"ERASE #{type}:#{id}"` from previewed assigns (`:100`). The owner that is erased
is re-derived via `parse_owner(type, id)` using those same previewed assigns
(`:103`) — client-submitted `owner_type`/`owner_id` params are ignored. Mismatch
→ `"Confirmation does not match."` (`:111`).

**Evidence — batch erasure** (`actions_live.ex:165-189`): execute clause matches
only on `action_state: :preview`, destructuring `owners_text` and `count` from
**socket.assigns.action_data**. Expected phrase rebuilt server-side as
`"ERASE #{count} OWNERS"` from the previewed count (`:176`). The erased set is
re-parsed from the previewed `owners_text` (`:179`), not from client params.

**No-preview guard:** Catch-all execute clauses (`:115-122`, `:191-198`) force any
execute event lacking a `:preview` state back to `:input` with
`"Preview this action before executing."` — closing the direct-handler-invocation
bypass.

**Tests:** `actions_live_test.exs:209-232` (wrong confirmation stays in preview;
exact phrase executes). `:337-387` — tamper tests via `render_hook` invoke
`execute_owner_erasure` / `execute_batch_erasure` directly with forged
confirmation strings and no preview state; both are rejected by the no-preview
guard. Full suite: 12 tests, 0 failures.

---

## T-90-04 — Elevation of Privilege: Quarantine Review — CLOSED

**Claim (D-90-17):** No mutations, button actions, or state transitions in the
quarantine review panel.

**Evidence** (`actions_live.ex:548-567`): the `:quarantine_review` panel renders
only static `<p>`/`<code>`/`<strong>` text plus a `data-rindle-admin-panel`
marker. It contains **no `<form>`, no `<button>`, no `phx-click`, no
`phx-submit`, no `phx-change`, and no facade call.** A handler-level sweep
(`grep handle_event` across the module) confirms **zero** event handlers
reference quarantine — there is no server-side mutation surface to reach. The
panel only directs operators to the Asset List (`state=quarantined`) and to the
Owner Erasure panel for removal.

**Test:** `actions_live_test.exs:465-475` (renders read-only instructional panel;
asserts "permanently blocked from delivery" and `state=quarantined`).

---

## Accepted Risk Log

### T-90-03 — Denial of Service: Variant Regeneration — ACCEPTED

**Disposition:** accept (per `90-02-PLAN.md` threat register).

**Rationale:** The admin console sits behind an authenticated maintainer boundary
(`rindle_admin("/rindle", auth_guarded?: true)`,
`actions_live_test.exs:11-14`). Broad variant regeneration enqueues Oban jobs by
design; large-scale enqueues are intentional operator work, not an external
attack vector. The panel additionally gates execution behind a deliberate
confirmation checkbox (`actions_live.ex:281-311`, `:770-775`) and reports work as
asynchronous via Oban (`:785-794`).

**Acceptance is reasonable and documented.** No mitigation required. Owner of
accepted risk: phase maintainer. Revisit if the admin boundary is ever exposed to
lower-privilege roles or unauthenticated access.

---

## Unregistered Flags (new attack surface without a threat mapping)

`90-01-SUMMARY.md` declares no `## Threat Flags` section. `90-02-SUMMARY.md`
`## Threat Flags`: "None — adhered strictly to T-90-04 by ensuring Quarantine
Review has no mutations." Verified against implementation: confirmed accurate.

**No unregistered flags.** All event handlers in the implementation map to a
registered threat or to non-destructive, registered operational panels
(lifecycle repair / variant regeneration, which fall under the accepted T-90-03
maintainer boundary).

---

## Notes for future audits

- Owner/batch erasure security rests on the invariant that execute handlers read
  the target set from `socket.assigns.action_data` (previewed state), never from
  client execute-event params. The preview-state forms re-render `owner_type` /
  `owner_id` / `owners` inputs with `value=` populated; these are display-only and
  are NOT consumed by the execute handlers. Any future change that makes an execute
  handler read the target from params would reopen T-90-02 — re-verify on edit.
- T-90-01's protection depends on the no-op `change_*` clause guard matching the
  previewed identity exactly. Loosening that guard would reopen the
  confirm-for-A-execute-against-B path.
