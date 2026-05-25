# v1.8 Strategy / Sequencing / Ecosystem-Fit — Locked Recommendation

> Historical v1.8 note: this file uses pre-v1.9 shorthand. For the current
> support contract, see `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`,
> `.planning/ROADMAP.md`, and `guides/resumable_uploads.md`.

**Project:** Rindle — "Media, made durable." (Hex `0.1.5`, internal milestone v1.7 shipped)
**Author role:** Lead strategy researcher (cross-cutting synthesis)
**Date:** 2026-05-22
**Decision posture:** One-shot, opinionated, locked. Escalation flagged only where genuinely high-blast-radius.
**Confidence:** HIGH on the sequencing call; MEDIUM-HIGH on exact phase count (depends on whether the maintainer wants the bundled DX win).

---

## 0. Bottom line up front (BLUF)

**Ship v1.8 = "Resumable Browser Ingest" — tus protocol as the spine, with browser→Mux direct creator upload folded in as a small sibling, and Phase 34/35 advisory code-review debt riding along as a hygiene sub-stream.**

- **Milestone name:** `v1.8 — Resumable Browser Ingest`
- **Goal sentence:** *Make unreliable-network, large-file, browser-origin uploads durable — ship the tus 1.0 protocol on a mountable Plug (Local + S3/MinIO backing) and pull forward browser→Mux direct creator upload, so every browser ingest path Rindle exposes is resume-safe and converges into the one trusted verify/promote lane.*
- **Requirement families IN:** `TUS-01..19` (tus core, the spine), `MUX-20..23` (browser→Mux direct upload, the sibling DX win), `CR-*` Phase 34/35 advisory polish (hygiene sub-stream, not its own milestone).
- **Defers to v1.9:** tus concatenation/checksum extensions, IETF RUFH (tus 2.0), R2-native/GCS-native tus, a Rindle-owned standalone tus JS client package, richer reusable uploader component abstractions beyond the supported helper path, broader future Phoenix upload abstractions, second streaming provider.
- **Effort:** ~6 phases, ~15–18 working days. tus is the boundary-expanding majority (~13–15 days); Mux-direct is ~1 day additive; code-review polish is ~0.5–1 day folded into early/late phases.
- **Hex semver:** publish this as **`0.2.0`** (minor, still pre-1.0; additive only, no breaks). The maintainer memory already plans 0.2.0 at the next milestone close — this is the right moment.

This is not a menu. It is one coherent set with one story: **"browser to durable, even on a bad connection."**

---

## 1. The candidate set and their real sizes (validated against source)

| Candidate | Real size | Risk | Status in repo | Verdict |
|---|---|---|---|---|
| **(a) tus protocol** (`TUS-01..19`) | 5 phases / ~18 plans / ~13–15 days | Boundary-expanding (Rindle becomes an upload server on the hot path) | Locked plan exists (`v1.6-CANDIDATE-TUS.md`, 6/10 "for v1.6 then") | **Spine of v1.8** |
| **(b) browser→Mux direct upload** (`MUX-20..23`) | ~1 day, 1 phase | LOW | Deferred MUX-20..23; behaviour callback `create_direct_upload/2` already reserved as `@optional_callbacks`; `video.upload.asset_created` webhook branch already shipped v1.6 | **Fold in as sibling** |
| **(c) Phase 34/35 code-review polish** | ~9 Warning + 3 Info (Ph34) + ~6 Warning + 7 Info (Ph35) ≈ **25 advisory findings**, all non-blocking | LOW | Deferred at v1.6 close; Phase 36 findings already resolved pre-close (no debt there) | **Hygiene sub-stream inside v1.8** |
| **(d) Phase 36 CI-only UAT items** | 5 items, all CI-time observables by design | NONE (already passing at artifact level) | Deferred as "CI-only by Plan 03 design" | **Not milestone work — close by observation** |

**Sizes are verified, not guessed:**
- tus size confirmed in `v1.6-CANDIDATE-TUS.md §14`: "~13-15 working days… smaller than v1.4 AV because the lifecycle core is unchanged."
- Mux-direct size confirmed in `v1.6-CANDIDATE-PROVIDER-MUX.md §12` (Phase 37: "1.0 day, LOW") and `STATE.md` Pending Todos ("~1 day, LOW risk").
- Code-review debt count from `STATE.md` Deferred Items table.

**Anything else carried forward worth surfacing?** Two items, both correctly left OUT:
1. **Second streaming provider** (Cloudflare/Bunny) — explicitly the *contract test* for v1.7+ but only valuable once a real adopter pulls. No demand signal. Defer.
2. **Richer reusable uploader component abstractions beyond the supported helper path** — natural follow-on, named in `v1.6-CANDIDATE-TUS.md §15` as v1.7+. Defer to v1.9; do not let it inflate v1.8.

---

## 2. Sequencing logic — why tus is the natural next wedge RIGHT NOW

The 4/10 in the original `TUS-CANDIDATE-MEMO.md` was explicitly *relative*: tus scored low **because GCS, provider/streaming, and adopter hardening were ahead of it**. Re-weighting per the prompt's instruction: **all three of those shipped (v1.4 AV → v1.5 hardening → v1.6 Mux streaming → v1.7 GCS resumable).** The blockers that held tus back are gone. The capability vocabulary it needs (`:resumable_upload`, `:resumable_upload_session`) was *reserved in v1.1 and made REAL in v1.7* — tus is now landing on prepared ground, not breaking it.

The arc is coherent and tus is its keystone:
- **v1.4** taught Rindle to ingest large AV (smartphone video).
- **v1.5** hardened the adopter story for it.
- **v1.6** gave it a streaming delivery answer (Mux).
- **v1.7** gave it *provider-native* resumable (GCS session-URI, client talks directly to GCS).
- **v1.8 (tus)** closes the one remaining gap: **resumable ingest for the S3/Local world and for any browser that can't get a presigned URL** — the unreliable-network large-upload case that presigned PUT and even plain multipart cannot recover gracefully.

The smartphone-on-flaky-LTE uploading a 500 MB video is the single clearest unblocked user pain in the whole roadmap, and it is *exactly* tus's sweet spot (`v1.6-CANDIDATE-TUS.md §13`: "the killer mobile-AV ingest path"). This is the natural wedge.

---

## 3. Coherence / least-surprise — do tus + Mux-direct dilute focus?

**No. They are complementary, not competing.** Both are the *same job-to-be-done*: **"browser → durable ingest."** v1.8's one-sentence promise unifies them. The distinction that makes them compose cleanly (verified against the codebase):

- **GCS resumable (v1.7, shipped):** client talks **directly to GCS** via a session URI; Rindle brokers and verifies but is **not** in the byte hot-path. Surface: `Rindle.Upload.Broker.initiate_resumable_session/2`, `resumable_session_status/2`, `cancel_resumable_session/2`.
- **tus (v1.8):** client talks **to Rindle's Plug**; Rindle **is** on the hot path (PATCH chunks), backed by S3 multipart (or local-tmp) for the S3/Local adapters GCS-native resumable doesn't cover. Surface: `initiate_resumable_upload/2` + `cancel_resumable_upload/2` + HTTP Plug.
- **Mux-direct (v1.8):** client talks **directly to Mux**; Rindle brokers the upload URL and links it via the already-shipped `video.upload.asset_created` webhook branch.

These are three *different brokerage shapes for three different backends* — not three implementations of one thing. Rindle's whole DNA is "adapters expose capabilities; don't fake parity" (`gsd-rindle-elixir-oss-dna.md`, "Behavior Seams + Adapter Capability Boundaries"). Shipping all three resumable-browser-ingest shapes under one milestone is the *most* coherent expression of that DNA: every browser ingest path becomes resume-safe, each honest about its mechanism.

**Why fold Mux-direct in rather than ship tus alone?** Because it is nearly free (~1 day, LOW, primitives already built), it completes the "browser→durable ingest" story rather than leaving a visible gap right next to the new tus work, and shipping it standalone later would be a thin, awkward micro-milestone. It is the "free DX win" the prompt asks about — and it is genuinely free because v1.6 already reserved the `create_direct_upload/2` callback and shipped the linking webhook branch. **One caveat (escalate if maintainer disagrees):** if execution velocity is at risk, Mux-direct is the clean drop — it is explicitly designed as a droppable pull-forward (`v1.6-CANDIDATE-PROVIDER-MUX.md §13`). Default: keep it in.

**Code-review polish: hygiene sub-stream, NOT its own thing.** ~25 advisory Warning/Info findings is not a milestone; it is a chore. Per Decision-Making Preference ("advisory rather than blocking → prefer telemetry/docs/metadata"), run `/gsd-code-review 34 --fix` and `/gsd-code-review 35 --fix` as a hygiene pass folded into v1.8's foundation phase (low-risk, touches Mux files that Mux-direct also touches — natural locality) and/or the final docs/CI phase. Do not spin a "polish milestone"; that would be the kind of unfocused, low-leverage cycle the OSS DNA warns against.

---

## 4. Risk & budget — bounding the "Rindle becomes an upload server" risk

This is the real risk and the locked plan already bounds it well. Reinforce these guardrails as milestone scope fences:

1. **BEAM RAM/disk is the #1 risk.** Hard-lock per-call body limits (`read_length: 1 MiB`, `length: 16 MiB`) so heap pressure is bounded regardless of client `chunkSize`; back S3 with `UploadPart`-per-PATCH so BEAM disk stays constant for any upload size. (`v1.6-CANDIDATE-TUS.md §3, §7, Risk 1.) **Never** buffer whole uploads locally.
2. **HMAC-signed bearer URLs are mandatory** — use `Plug.Crypto.MessageVerifier` (existing Phoenix dep), not hand-rolled HMAC. tus session URLs are bearer-equivalent (security invariant 14 already covers "tus upload URLs"); they must never appear in logs/telemetry/`inspect`. This is the security-critical phase; gate it with tampered-URL contract tests. **(Escalate-worthy: security boundary — but the plan's posture is sound; no escalation needed unless the maintainer wants to weaken HMAC-mandatory.)**
3. **One dependency, one shape.** `tussle ~> 0.3.1` (active maintainer, verified) as a hard runtime dep behind a capability gate; in-process Plug only — **no external tusd, no bundled Go binary, no "support both modes."** This honors "Tech stack: Elixir/Phoenix/Ecto only in core."
4. **Reuse, don't reinvent.** Converge into the existing `verify_completion/2` lane; extend the v1.1 `AbortIncompleteUploads` + `CleanupOrphans` workers; reuse `media_upload_sessions` with additive `tus_*` columns. **No parallel table, no parallel completion vocabulary, no new worker.** This is what keeps a boundary-expanding milestone from ballooning.
5. **Scope fence:** core + creation + expiration + termination extensions ONLY. Concatenation, checksum, RUFH, provider-native tus, and a Rindle tus client are all explicitly v1.9+ (`v1.6-CANDIDATE-TUS.md §15`). Hold this line.

**Budget discipline:** if the milestone runs long, the cut order is (1) Mux-direct sibling first, (2) then trim the generated-app proof lane to a lighter assertion — never cut the HMAC/auth phase or the S3-cleanup proof.

---

## 5. Idiomatic OSS-library cadence — what should a healthy Elixir lib ship as its next minor?

Lessons from peers and Rindle's own OSS DNA:

- **Active Storage / Shrine / Spatie all treat resumable/direct upload as a post-v1 expansion, not a v1 promise** (`phoenix-media-uploads-lib-deep-research.md §18`: "Include soon after v1: GCS resumable, S3 multipart, … provider webhooks"). Rindle has been executing exactly this curve. tus + Mux-direct is the textbook "soon after v1" minor.
- **Shrine's central lesson:** keep S3 multipart and tus as *separate, explicit choices*, not merged into one confusing abstraction (`TUS-CANDIDATE-MEMO.md §6`). v1.8's three-distinct-shapes design honors this precisely.
- **Cadence rhythm:** Rindle's recent minors have been tightly scoped 4–6 phase milestones shipped in 2–4 days of focused work each (v1.4 was the outlier at 6 phases; v1.5/v1.6/v1.7 were 4–5). v1.8 at ~6 phases sits at the top of that band — appropriate for a boundary-expanding minor, and still disciplined. A healthy Elixir lib ships *one coherent capability per minor*, freezes its public surface, and verifies via package-consumer CI. v1.8 does exactly that.
- **Freeze-before-adoption discipline:** every prior milestone froze its error vocabulary + telemetry contract before adoption pressure grew. v1.8 must do the same for the tus error atoms (`:tus_offset_conflict`, `:tus_session_expired`, etc., already enumerated in the locked plan §4) and the `[:rindle, :upload, :resumable, …]` telemetry contract.

---

## 6. Hex semver call (0.1.5 → 0.2.0)

- Internal milestone numbering (`v1.8`) and Hex semver (`0.x`) stay separate; do not conflate.
- v1.8 is **purely additive** (new Plug, new capability advertisements on Local/S3, additive `tus_*` columns, additive error atoms, additive telemetry, additive Mux-direct callback). No breaking changes. The one v1.6 telemetry `kind` extension already shipped.
- Therefore: cut **`0.2.0`** at v1.8 close (minor bump, release-please-driven). Still pre-1.0, so additive features carry no breaking-change cost; 0.2.0 simply signals "meaningful new capability surface (resumable browser ingest)" — which is true and adopter-legible. This matches the maintainer's preserved 0.2.0 plan. **No escalation needed:** 0.x additive minor is a routine, low-blast-radius semver move.

---

## 7. Locked phase shape (continues from Phase 41)

| Phase | Name | Families | Effort | Risk |
|---|---|---|---|---|
| 42 | tus Foundations (capability lift on Local/S3, additive `tus_*` migration, broker entrypoints) + fold Phase 34 code-review polish here | TUS-01..03, RESUMABLE-tie-in, CR-34 | ~2 d | Low |
| 43 | tus Plug & Endpoint Wiring (mountable macro, Plug.Parsers `:pass`, Local-backed e2e) | TUS-04..07 | ~3 d | Medium |
| 44 | S3 Storage Backing & MinIO Proof (UploadPart-per-PATCH, 1 GiB drop-and-resume) | TUS-08..11 | ~3–4 d | Med-High |
| 45 | Oban Expiry, Termination, HMAC Auth (security-critical; bearer-URL discipline) | TUS-12..15 | ~3 d | Med-High |
| 46 | tus DX, Docs, Telemetry, Generated-App CI Proof + fold Phase 35 code-review polish here | TUS-16..19, CR-35 | ~2 d | Low-Med |
| 47 | Browser→Mux Direct Creator Upload (sibling; droppable under budget pressure) | MUX-20..23 | ~1 d | Low |

Phase 36 CI-only UAT items: close by observation during the v1.8 CI runs (cassette PR run, mux-soak, HexDocs publish wire, fork-secret boundary, generated-app cassette test) — not net-new work.

---

## 8. Single locked recommendation

**v1.8 = "Resumable Browser Ingest": tus 1.0 protocol (spine) + browser→Mux direct creator upload (sibling) + Phase 34/35 advisory code-review polish (hygiene sub-stream). ~6 phases, ~15–18 days. Cut Hex `0.2.0` at close. HIGH confidence.**

One story, one freeze, one coherent capability: *every browser ingest path Rindle exposes becomes resume-safe and converges into the same trusted verify/promote lane.*

---

## Sources

**Local (read in full):** `.planning/PROJECT.md`, `.planning/MILESTONES.md`, `.planning/STATE.md`, `prompts/gsd-rindle-research-index.md`, `prompts/gsd-rindle-elixir-oss-dna.md`, `prompts/rindle-brand-book.md`, `prompts/phoenix-media-uploads-lib-deep-research.md`, `.planning/research/TUS-CANDIDATE-MEMO.md`, `.planning/research/v1.6-CANDIDATE-TUS.md`, `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md`, `.planning/research/v1.5-GCS-RESUMABLE-RECOMMENDATION.md`, `.planning/research/v1.8-MUX-SDK-BOUNDARY.md`

**Codebase facts (verified 2026-05-22):** `mix.exs` (`@version "0.1.5"`); `lib/rindle/storage/capabilities.ex` (resumable atoms now real, not reserved); `lib/rindle/storage/{s3,local,gcs}.ex` (`capabilities/0` — GCS advertises resumable, S3/Local do not yet → tus's target); `lib/rindle/upload/broker.ex` (`initiate_resumable_session/2`, `resumable_session_status/2`, `cancel_resumable_session/2` are GCS-native shapes, distinct from tus → they compose, not duplicate)

**External (from locked plans, verified at their authoring dates):** tus 1.0 protocol (tus.io); `tussle ~> 0.3.1` (hex.pm, jvantuyl); Mux Elixir SDK direct-upload + `video.upload.asset_created` webhook; Shrine derivatives/tus separation; Active Storage / Spatie post-v1 expansion curve.
