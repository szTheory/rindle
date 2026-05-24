---
phase: 45
slug: browser-mux-direct-creator-upload-sibling-droppable
status: approved
shadcn_initialized: false
preset: none
created: 2026-05-24
reviewed_at: 2026-05-24T00:00:00Z
---

# Phase 45 — UI Design Contract

> Visual and interaction contract for frontend phases. Generated for the browser to Mux direct creator upload flow and verified against the current LiveView, PubSub, and Mux planning contracts.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none |
| Preset | not applicable |
| Component library | Phoenix LiveView native forms plus UpChunk integration |
| Icon library | Heroicons or adopter-native icon set |
| Font | Inherit adopter app font stack; Rindle ships no font opinion in this phase |

**Scope note:** This phase defines a thin browser upload contract for adopter apps, not a Rindle-owned visual theme. The contract therefore locks states, spacing, copy tone, and metadata shape, while leaving brand palette and font family aligned to the adopter application.

---

## Spacing Scale

Declared values (must be multiples of 4):

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Inline icon/text gaps, progress label padding |
| sm | 8px | Helper text offset, compact metadata stacks |
| md | 16px | Default control spacing, form row gap |
| lg | 24px | Upload panel padding, state-group separation |
| xl | 32px | Gap between chooser/progress/result sections |
| 2xl | 48px | Major split between upload form and readiness/status rail |
| 3xl | 64px | Full-page section spacing in guide examples only |

Exceptions: `chunk/progress` bar height may use `12px`; drag target min-height may use `160px`; no other exceptions.

---

## Typography

| Role | Size | Weight | Line Height |
|------|------|--------|-------------|
| Body | 16px | 400 | 1.5 |
| Label | 14px | 600 | 1.4 |
| Heading | 24px | 700 | 1.25 |
| Display | 32px | 700 | 1.1 |

**Type rules:**
- Use `Heading` for the upload surface title only.
- Use `Label` for field names, state labels, and webhook/readiness chips.
- Use tabular numerals for percentage progress and byte-size displays if the adopter stack supports it.
- Never use `Display` for routine form screens; reserve it for guide hero examples only.

---

## Color

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `app-surface-default` | Page background, panel surface |
| Secondary (30%) | `app-surface-subtle` | Drop zone fill, metadata cards, progress rail |
| Accent (10%) | `app-accent-upload` | Progress fill, active focus ring, primary CTA only |
| Destructive | `app-danger` | Retry failure state, destructive cancellation only |

Accent reserved for: `Choose video`, `Start upload`, active progress bar, focused upload area, and the final ready-state success marker. Never use the accent color for passive metadata, helper text, or secondary actions.

**Color posture:** Because Rindle is a library, this phase locks semantic usage rather than hex codes. Adopters map these roles into their design tokens. Contrast must meet WCAG AA for all text and progress labels.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Primary CTA | Choose video |
| Empty state heading | Upload a video directly from the browser |
| Empty state body | Pick one video file to mint a one-time Mux upload URL. Upload runs in the browser; playback becomes available after provider events finish processing. |
| Error state | Upload could not start. Check provider configuration, CORS origin, or webhook setup, then try again. |
| Destructive confirmation | Cancel upload: Stop this browser upload? The provider-side upload URL will expire, and you may need to request a new upload. |

**State copy contract:**
- Pre-upload helper text must mention that the URL is one-time and should not be reused.
- In-progress text must separate `Uploading to Mux` from `Waiting for asset processing`; those are distinct states.
- Success text must name the Rindle asset id as the durable handle and avoid exposing raw Mux upload ids.
- Failure text must be fix-oriented and point to the next operator action: retry, inspect CORS origin, inspect webhook delivery, or inspect provider quota.

---

## Visual Hierarchy

**Primary focal point:** the upload drop zone and `Choose video` CTA are the first visual anchor on the screen.

**Secondary focal point:** the progress rail and phase-state label (`Requesting upload URL`, `Uploading to Mux`, `Preparing playback`) become the anchor immediately after selection.

**Tertiary focal point:** the durable `asset_id` and next-step guidance become the anchor only after the asset reaches `Ready`.

**Hierarchy rules:**
- On initial load, the chooser surface occupies the most visual weight; readiness diagnostics and provider-status detail stay visually subordinate.
- The progress bar is the only continuously animating element during transfer; do not animate surrounding metadata cards.
- Success and failure panels must appear inline in the same layout slot as progress so the eye does not jump to a different region.
- If an adopter adds icon-only affordances such as retry, copy-id, or open-log actions, each must include an accessible label and a visible tooltip or adjacent text label; no unlabeled icon-only controls.

---

## Interaction Contract

**Primary path:** document and design around a controller/JSON endpoint first. The baseline UX is:
1. User selects a single video file.
2. Browser requests a direct-upload token from the app server.
3. Server returns only `%{endpoint, asset_id}` to the browser-facing layer.
4. UpChunk uploads directly to Mux and emits browser progress.
5. UI transitions into a waiting state after upload success until `:provider_asset_created` and then `:provider_asset_ready` arrive through PubSub or polling.

**LiveView convenience path:** `Rindle.LiveView.allow_direct_upload/4` mirrors `allow_upload/4` but returns external-upload metadata for UpChunk. It is secondary in docs and examples; it must not be the only documented path.

**Required visual states:**
- Idle: file chooser, size/type guidance, one primary CTA.
- Signing: controls disabled, inline spinner, text `Requesting upload URL...`.
- Uploading: progress bar, percentage label, transferred byte summary if available.
- Linked: upload finished, awaiting `video.upload.asset_created`; message `Upload received. Linking provider asset...`.
- Processing: awaiting `video.asset.ready`; message `Asset linked. Preparing playback...`.
- Ready: success badge, durable `asset_id`, next-step guidance for playback or form submission.
- Error: inline error panel with retry CTA; never hide the failed state behind a toast only.

**Behavior rules:**
- Single-file only for this phase unless a later plan explicitly broadens scope.
- Disable repeated submit clicks while signing or uploading.
- Preserve visible state when the upload completes but provider readiness is still pending.
- Never render or log `upload_url` or raw Mux `upload_id` into durable DOM attributes, analytics, or telemetry.
- If PubSub is unavailable in the adopter example, poll via the documented controller/JSON variant; do not invent a separate visual state model.

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| shadcn official | none | not required |
| `@mux/upchunk` | browser uploader client only | version pin + documented integration snippet required |
| Phoenix LiveView external uploads | existing framework primitive | contract test against returned metadata shape required |

---

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS
- [x] Dimension 2 Visuals: PASS
- [x] Dimension 3 Color: PASS
- [x] Dimension 4 Typography: PASS
- [x] Dimension 5 Spacing: PASS
- [x] Dimension 6 Registry Safety: PASS

**Approval:** approved 2026-05-24
