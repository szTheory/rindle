---
phase: 36-public-dx-onboarding-ci-proof
plan: 02
subsystem: docs
tags:
  - documentation
  - guide
  - hexdocs
  - readme
  - changelog
  - ci-doc-parity
  - onboarding
  - streaming
  - mux
requirements:
  - MUX-17
  - MUX-19
dependency-graph:
  requires:
    - guides/secure_delivery.md (style template — D-12)
    - lib/rindle/delivery/webhook_plug.ex @moduledoc (D-13 source-of-truth for Step 5)
    - lib/rindle/workers/mux_sync_coordinator.ex @moduledoc (D-13 source-of-truth for Step 6)
    - .github/workflows/ci.yml:518-545 doc-parity guard (extended)
    - mix.exs :extras list (extended)
  provides:
    - Public end-to-end Mux adopter onboarding guide (guides/streaming_providers.md)
    - "Streaming with Mux (optional)" README subsection
    - "## 10. Streaming with Mux (optional)" getting_started subsection
    - Doc-parity required-string for Rindle.Profile.Presets.MuxWeb
    - CHANGELOG [Unreleased] v1.6 streaming-onboarding entry
  affects:
    - HexDocs published bundle (new extras entry)
    - CI doc-parity guard (one new required string)
    - release-please [Unreleased] → [0.2.0] retag pipeline
tech-stack:
  added: []
  patterns:
    - guides/secure_delivery.md style template (private-by-default narrative + locked code blocks + Quick Reference table)
    - D-13 single-source-of-truth via inline-copy + HTML source comment (`<!-- source: ... -->`)
    - D-25/D-26 ≤15-line subsection with three elements (intro sentence + snippet + link)
    - D-28 append-only invariant for AV-canonical onboarding strings
key-files:
  created:
    - guides/streaming_providers.md (341 lines)
  modified:
    - mix.exs (extras list +1 entry)
    - README.md (+15 lines streaming subsection)
    - guides/getting_started.md (+15 lines Section 10)
    - .github/workflows/ci.yml (doc-parity guard +1 required string)
    - CHANGELOG.md (Unreleased ### Added +1 bullet)
decisions:
  - D-09 honored — single guide, Mux-only narrative, no second-provider scaffolding
  - D-10 honored — locked 11-section ordering (Why → deps → signing key → MuxWeb → webhook → cron → tunnel → rotation → doctor → runbook → perf note)
  - D-11 honored — cloudflared TryCloudflare primary, ngrok alternative-with-2026-signup-caveat
  - D-12 honored — style mirrors secure_delivery.md
  - D-13 honored — Steps 5-6 inline-copy verbatim from webhook_plug.ex + mux_sync_coordinator.ex moduledocs with HTML source comments pointing back
  - D-25 honored — ≤15-line README + getting_started subsections, both placed after canonical AV path
  - D-26 honored — three-element subsection (intro + snippet + link)
  - D-27 honored — doc-parity guard required-strings extended with Rindle.Profile.Presets.MuxWeb; existing strings + negative regex unchanged
  - D-28 honored — image and AV onboarding text stays byte-identical (verified via doc-parity guard local execution)
  - D-32 honored — alphabetical extras position immediately after secure_delivery.md
  - D-33 honored — single CHANGELOG bullet appended to [Unreleased] ### Added (release-please retags as [0.2.0] at v1.6 close)
  - D-34 honored — no rewrites of v1.4-v1.5 entries
  - Pitfall 4 mitigation honored — guide uses Rindle.Delivery.streaming_url exclusively (the streaming_ prefix differentiates from the doc-parity guard's banned Rindle.Delivery.url)
metrics:
  duration: ~25 min
  completed: 2026-05-07
  tasks_completed: 5
  files_changed: 6
  lines_added: 383
  lines_removed: 1
---

# Phase 36 Plan 02: Public DX, Onboarding, CI Proof — Docs Lane Summary

Shipped the public Mux-streaming adopter onboarding surface for v0.2.0:
the end-to-end `guides/streaming_providers.md` guide (~340 lines mirroring
`guides/secure_delivery.md` style), the appended ≤15-line "Streaming with
Mux (optional)" subsections in `README.md` and `guides/getting_started.md`,
the `.github/workflows/ci.yml` doc-parity guard extension that enforces
`Rindle.Profile.Presets.MuxWeb` as a required onboarding string, and the
CHANGELOG `[Unreleased]` entry that release-please will auto-retag as
`[0.2.0]` at v1.6 close.

## Objective Recap

Adopters needed a single end-to-end reference to onboard Mux streaming —
deps, signing-key creation via the Mux dashboard, profile config with
`MuxWeb`, webhook plug wiring, cron coordinator, local cloudflared
tunnel, secret rotation, doctor smoke recipe, stuck-asset runbook, and a
JOSE perf footgun note. The canonical first-run README/getting_started
narrative had to stay byte-identical (D-28) so image and AV onboarding
remain the first-run story; streaming is appended as an opt-in
peripheral.

## Tasks Executed

### Task 1: Author `guides/streaming_providers.md` + extend `mix.exs` extras

**Commit:** `f681f33` — `docs(36-02): add guides/streaming_providers.md adopter guide`

Created the new 341-line guide with the locked 11-section ordering (D-10):

1. Why a streaming provider — paragraph contrasting progressive download
   vs provider-resolved playback URLs.
2. Add Mux to your dependencies — `{:mux, "~> 3.2", optional: true}` +
   `{:jose, "~> 1.11", optional: true}` plus the Phase 34 D-29 runtime
   config block verbatim.
3. Create your Mux signing key — out-of-band Mux dashboard steps with the
   "download once" caveat.
4. Configure your profile with `MuxWeb` — `use Rindle.Profile.Presets.MuxWeb,
   storage: ..., allow_mime: [...], max_bytes: ...` snippet plus the locked
   `delivery.streaming` map for reference.
5. Wire the webhook plug — verbatim copy of the @moduledoc Steps 1-3 from
   `lib/rindle/delivery/webhook_plug.ex`, wrapped with
   `<!-- source: lib/rindle/delivery/webhook_plug.ex @moduledoc — keep in sync -->`
   HTML comments (D-13). Includes the response-codes table.
6. Schedule the sync coordinator — verbatim copy of the cron snippet from
   `lib/rindle/workers/mux_sync_coordinator.ex` @moduledoc, same
   `<!-- source: ... -->` framing.
7. Local development with a webhook tunnel — `cloudflared tunnel --url
   http://localhost:4000` PRIMARY (D-11, signup-free TryCloudflare quick
   tunnel), ngrok ALTERNATIVE-WITH-2026-SIGNUP-CAVEAT (kept to 5-10 lines).
8. Webhook secret rotation workflow — five-step procedure consuming the
   `[:rindle, :provider, :mux, :webhook_attempt, :secret_used]`
   `secret_index` telemetry from Phase 35 D-11; recommended 24h grace.
9. Run `mix rindle.doctor --streaming` — expected PASS output table plus
   the four FAIL fix recipes from D-08 (200/401-403/429/timeout/other).
10. Operator runbook: stuck assets — `mix rindle.runtime_status
    --provider-stuck` (Phase 35 D-39/D-40); Oban cancellation note; future
    `Rindle.cancel_provider_ingest/1` planned for v0.3+.
11. Performance note: high-throughput JWT signing — `JOSE.JWK.from_pem/1`
    re-parse footgun (Phase 34 D-09); recommends `:persistent_term` cache;
    notes the in-library cache ships in v0.3+.

Bottom of guide: Quick Reference table listing every Phase 35 telemetry
event the adopter can subscribe to, plus a configuration cheat-sheet.

Also extended `mix.exs` `:extras` list with `"guides/streaming_providers.md"`
inserted immediately after `"guides/secure_delivery.md"` (D-32 alphabetical
posture).

**Verification:** `MIX_ENV=dev mix docs --formatter html` succeeded; the
expected `doc/streaming_providers.html` exists. The guide contains
`Rindle.Profile.Presets.MuxWeb`, contains `cloudflared`, and contains zero
references to the bare `Rindle.Delivery.url` (Pitfall 4 mitigation).

### Task 2: Append "Streaming with Mux (optional)" subsection to `README.md`

**Commit:** `2449cbd` — `docs(36-02): add Streaming with Mux (optional) subsection to README`

Added a 15-line `## Streaming with Mux (optional)` subsection between
"### Bang Variants" (the closing subsection of "## After First Run:
Querying Attachments and Variants") and "## Next Reads", per D-25
placement. The subsection contains the three D-26 elements only:

1. One sentence: "For HLS streaming via signed playback URLs, opt a
   profile into a streaming provider."
2. One Elixir snippet: `use Rindle.Profile.Presets.MuxWeb, storage: ...,
   allow_mime: [...], max_bytes: ...`.
3. One link: `[guides/streaming_providers.md](guides/streaming_providers.md)`.

**Verification:** All six existing doc-parity required strings
(`mix rindle.doctor`, `Rindle.Profile.Presets.Web`, `Rindle.initiate_upload`,
`Rindle.verify_completion`, `Rindle.attach`, `Rindle.url`) remain present
in README.md. No forbidden patterns introduced
(`Broker.initiate_session`, `Broker.verify_completion`,
`Rindle.Delivery.url`).

### Task 3: Append "## 10. Streaming with Mux (optional)" to `guides/getting_started.md`

**Commit:** `6ec79ad` — `docs(36-02): add Section 10 Streaming with Mux to getting_started.md`

Added the new Section 10 after Section 9 (Bang Variants), before "##
Next Reads". Identical content shape to the README counterpart (D-26):
intro sentence + MuxWeb snippet + link to `streaming_providers.md`. Total
15 lines (D-25 cap).

**Verification:** Sections 1-9 stay byte-identical (D-28). All six
existing doc-parity required strings still present. No forbidden
patterns introduced.

### Task 4: Extend doc-parity guard with `Rindle.Profile.Presets.MuxWeb`

**Commit:** `49e33ab` — `ci(36-02): extend doc-parity guard with Rindle.Profile.Presets.MuxWeb`

Appended one new line to the `for REQUIRED in \` list at
`.github/workflows/ci.yml:524-531`:

```yaml
"Rindle.Profile.Presets.MuxWeb"
```

The negative regex check (`Broker\.initiate_session|Broker\.verify_completion|Rindle\.Delivery\.url`)
stays UNCHANGED — D-27 final clause: "MuxWeb does NOT introduce new
forbidden patterns."

**Verification:** Ran the doc-parity guard locally as a bash script
extraction with the new required-strings list against both README.md and
guides/getting_started.md — `OK: README.md and guides/getting_started.md
stay aligned to the public AV onboarding path`.

### Task 5: Add v1.6 streaming-onboarding bullet to `CHANGELOG.md`

**Commit:** `ce0a6fd` — `docs(36-02): add v1.6 streaming-onboarding entry to CHANGELOG Unreleased`

Appended one new bullet to `## [Unreleased] ### Added`:

> Public adopter onboarding for streaming providers —
> `Rindle.Profile.Presets.MuxWeb` preset (signed-HLS twin of
> `Rindle.Profile.Presets.Web`), `mix rindle.doctor --streaming` smoke
> check (credentials / signing-key parse / webhook-secrets / 5s
> `api.mux.com` ping), the
> [`guides/streaming_providers.md`](guides/streaming_providers.md)
> end-to-end guide, and the generated-app `mux-enabled`
> package-consumer CI lane (cassette default + label-gated `mux-soak`
> lane against real Mux).

Existing v1.4-v1.5 entries stay byte-identical (D-34). release-please
will auto-retag this `[Unreleased]` block as `[0.2.0]` at v1.6 close per
`memory/project_v0_2_0_release_plan.md`.

## Decisions Made / Honored

All decisions were front-loaded by the planner — Plan 02 had zero new
decisions; the executor honored all 12 listed in the planning frontmatter
(D-09, D-10, D-11, D-12, D-13, D-25, D-26, D-27, D-28, D-32, D-33, D-34)
plus the Pitfall 4 mitigation (use `Rindle.Delivery.streaming_url`
exclusively, never the bare `Rindle.Delivery.url`).

## Verification Run

Final verification snapshot from the worktree at execution close:

```
=== mix docs builds streaming_providers.html ===          OK
=== mix.exs extras includes streaming_providers.md ===    OK
=== Plan must_haves ===
  MuxWeb in guide                                          OK
  no bare Rindle.Delivery.url                              OK
  cloudflared mentioned                                    OK
  signing-key section                                      OK
  JOSE.JWK.from_pem/1 perf footgun                         OK
  stuck-asset runbook                                      OK
  secret rotation workflow                                 OK
=== README + getting_started have streaming subsection === OK + OK
=== CI doc-parity guard required-strings includes MuxWeb === OK
=== CHANGELOG MuxWeb entry in Unreleased ===              OK
=== streaming_providers.md line count ===                 341 (≥150 floor)
=== README streaming subsection length ===                15 (≤15 cap)
=== getting_started streaming subsection length ===       15 (≤15 cap)
=== AV onboarding canonical strings still present ===     6/6 README, 6/6 getting_started
=== Source comments link guide back to canonicals ===     2/2 (webhook_plug.ex + mux_sync_coordinator.ex)
=== Local doc-parity-guard bash run ===                   OK on README.md + guides/getting_started.md
```

## Deviations from Plan

**None — plan executed as written.**

The only minor judgment call was where to place the README subsection
relative to "### Bang Variants". The plan said "between 'After First
Run...' (~line 172-241) and 'Next Reads' (~line 242)." Since "Bang
Variants" is an `### h3` subsection visually nested under "## After
First Run: Querying Attachments and Variants", placing the new `##
Streaming with Mux (optional)` `h2` heading AFTER "Bang Variants" content
preserves the implicit nesting (Bang Variants stays inside "After First
Run") and matches the plan's "after canonical AV path" intent. This is
the placement landed in `2449cbd`.

## Authentication Gates

**None — plan was docs-only.** No CLI auth, no API tokens, no service
account credentials were exercised at any point. `mix docs` ran offline
against locally-cached deps after `mix deps.get`.

## Known Stubs

**None.** All five files contain finished, adopter-facing content. No
"TODO", "coming soon", or placeholder values were introduced.

## Threat Flags

No new security-relevant surface introduced beyond what Phase 34/35
already document. The guide's Step 5 (webhook plug wiring) inline-copies
the canonical adopter wiring snippets verbatim from the moduledoc; the
`<!-- source: ... -->` HTML comments make divergence loud at the next
review pass. The webhook secret rotation workflow (Step 8) reinforces the
Phase 35 D-11 multi-secret rotation pattern; no new attack surface is
created.

The doc-parity guard's negative regex still bans `Rindle.Delivery.url` —
the new public surface uses `Rindle.Delivery.streaming_url` (with the
`streaming_` prefix). Pitfall 4 (negative-regex landmine) is mitigated by
exclusive use of `streaming_url` throughout the guide.

## Self-Check: PASSED

**Files created (1):**
- guides/streaming_providers.md — FOUND (341 lines)

**Files modified (5):**
- mix.exs — FOUND (extras list +1)
- README.md — FOUND (+15-line subsection)
- guides/getting_started.md — FOUND (+15-line Section 10)
- .github/workflows/ci.yml — FOUND (doc-parity guard +1 required string)
- CHANGELOG.md — FOUND (Unreleased +1 bullet)

**Commits (5):**
- f681f33 — FOUND
- 2449cbd — FOUND
- 6ec79ad — FOUND
- 49e33ab — FOUND
- ce0a6fd — FOUND

**Plan must_haves verified (8/8):**
- Guide is one-stop reference covering all D-10 sections — ✓
- Guide builds via `mix docs --formatter html` (`doc/streaming_providers.html` produced) — ✓
- README + getting_started gain ONE subsection each titled "Streaming with Mux (optional)", ≤15 lines, AFTER canonical AV path — ✓
- Doc-parity guard adds `"Rindle.Profile.Presets.MuxWeb"`; existing required strings unchanged — ✓
- Doc-parity negative regex unchanged; new content uses `streaming_url` exclusively — ✓
- Local-tunnel section recommends cloudflared FIRST and ngrok SECOND with 2026 signup caveat — ✓
- CHANGELOG `[Unreleased]` ### Added gains one new bullet referencing MuxWeb, doctor --streaming, streaming_providers.md, mux-enabled lane — ✓
- Plan-frontmatter `key_links` patterns all present — ✓
