---
phase: 45
slug: browser-mux-direct-creator-upload-sibling-droppable
status: approved
shadcn_initialized: false
preset: none
created: 2026-05-24
reviewed_at: 2026-05-24T11:10:00Z
---

# Phase 45 — UI Design Contract

> Visual and interaction contract for the browser to Mux direct creator upload flow. This is a baseline update to the existing spec, aligned to the locked v1.8 Phase 45 planning and the current Rindle LiveView/streaming seams.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none |
| Preset | not applicable |
| Component library | Phoenix LiveView native upload/forms plus a controller/JSON endpoint and `@mux/upchunk` browser client |
| Icon library | Heroicons or adopter-native icon set |
| Font | Inherit adopter app font stack; Rindle ships no font-family opinion in this phase |

**Scope note:** Rindle is defining a thin upload UX contract, not a branded UI kit. Lock interaction states, copy tone, spacing rhythm, and secret-handling rules; leave palette tokens and font family mapped to the adopter application.

**Delivery posture:** document the controller/JSON flow as the baseline; document `Rindle.LiveView.allow_direct_upload/4` as the convenience path built on the same state model.

---

## Spacing Scale

Declared values (must be the standard set only):

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Inline icon/text gaps, compact status chips |
| sm | 8px | Helper text offset, stacked metadata rows |
| md | 16px | Default field spacing, button padding, row gaps |
| lg | 24px | Upload panel padding, separation between chooser and status |
| xl | 32px | Gap between major surface blocks |
| 2xl | 48px | Major break between upload interaction and readiness/result rail |
| 3xl | 64px | Guide-page section spacing only |

**Component sizing constraints:**
- Progress bar height is `12px`; treat this as control sizing, not a spacing token.
- Interactive targets must be at least `44px` tall or wide; treat this as accessibility sizing, not spacing rhythm.
- The empty drop-zone surface must be at least `160px` tall so drag-and-drop affordance stays obvious; treat this as layout sizing, not spacing rhythm.

---

## Typography

| Role | Size | Weight | Line Height |
|------|------|--------|-------------|
| Body | 16px | 400 | 1.5 |
| Label | 14px | 600 | 1.4 |
| Heading | 24px | 600 | 1.2 |
| Display | 32px | 600 | 1.1 |

**Type rules:**
- Use only two weights in this phase: `400` and `600`.
- Use `Heading` for the upload surface title and ready/error panel title only.
- Use `Label` for field names, state labels, progress captions, and provider-status chips.
- Use tabular numerals for percent and byte counters when the adopter stack supports them.
- Reserve `Display` for docs/examples, not routine in-app upload forms.

---

## Color

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `app-surface-default` | Page background and primary upload panel |
| Secondary (30%) | `app-surface-subtle` | Drop zone fill, metadata cards, waiting-state panel |
| Accent (10%) | `app-accent-upload` | Primary CTA, active focus ring, progress fill, success check/state marker |
| Destructive | `app-danger` | Error callout border/icon and optional reset action only |

Accent reserved for: `Choose video`, active drop-zone/focus ring, upload progress fill, and final ready-state confirmation marker. Do not use accent for passive metadata, helper text, or secondary actions.

**Color posture:** lock semantic roles, not hex values. Adopters map these roles onto their own tokens. All text, icons, and progress labels must meet WCAG AA contrast.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Primary CTA | Choose video |
| Empty state heading | Upload a video directly from the browser |
| Empty state body | Select one video file to request a one-time Mux upload URL. The browser uploads directly to Mux, then Rindle waits for provider events before playback is ready. |
| Error state | Upload could not start or finish. Retry first; if it fails again, check the configured CORS origin, webhook delivery, and provider quota. |
| Destructive confirmation | No provider-side cancel action is in scope for this phase. If the adopter adds a local reset action, use: `Remove this file and request a new upload URL?` |

**State copy contract:**
- Idle helper text must say the upload URL is one-time and must not be reused.
- Signing state text is exactly `Requesting upload URL...`.
- Browser-transfer state text is exactly `Uploading to Mux...`.
- Post-transfer linker state text is exactly `Upload received. Linking provider asset...`.
- Post-link readiness state text is exactly `Asset linked. Preparing playback...`.
- Ready state must surface the durable Rindle `asset_id`; never surface raw Mux `upload_id` or provider asset ids in user-facing copy.
- Failure copy must name the next action: retry, check CORS origin, inspect webhook delivery, or inspect provider quota/configuration.

---

## Visual Hierarchy

**Primary focal point:** the file chooser/drop zone and `Choose video` CTA.

**Secondary focal point:** the single progress/status rail after a file is selected.

**Tertiary focal point:** the durable `asset_id` and next-step guidance once the asset is ready.

**Hierarchy rules:**
- The chooser surface carries the most weight on first render; diagnostics and implementation notes stay visually subordinate.
- Keep progress, linked, processing, ready, and error states in the same panel slot so the eye does not jump across the screen.
- The progress bar is the only continuously animating element during transfer.
- Success and error panels replace the progress panel inline; do not move them to toast-only or sidebar-only presentation.
- Any icon-only retry/copy actions must include an accessible label and visible tooltip or adjacent text.

---

## Interaction Contract

**Baseline path:** controller/JSON endpoint first.
1. User selects a single video file.
2. Browser requests a direct upload from the app server.
3. Server returns only `%{endpoint, asset_id}` to the browser-facing layer.
4. Browser uploads directly to Mux via UpChunk.
5. UI waits for provider linkage and readiness events before presenting playback-ready completion.

**Convenience path:** `Rindle.LiveView.allow_direct_upload/4` mirrors the existing `allow_upload/4` posture and returns external-upload metadata for the same browser flow. It is secondary in docs; it must not be the only documented path.

**Required visual states:**
- `Idle`: one file chooser/drop zone, one primary CTA, size/type guidance.
- `Signing`: controls disabled, inline spinner, text `Requesting upload URL...`.
- `Uploading`: progress bar, percent label, transferred byte summary if available.
- `Linked`: transfer finished, waiting on `video.upload.asset_created`; text `Upload received. Linking provider asset...`.
- `Processing`: provider asset linked, waiting on `video.asset.ready`; text `Asset linked. Preparing playback...`.
- `Ready`: success marker, durable `asset_id`, next-step guidance for playback or form submission.
- `Error`: inline error panel with retry CTA; never rely on toast-only failure handling.

**Behavior rules:**
- Single-file only in this phase.
- Disable repeat submission while signing or uploading.
- Preserve the visible state after upload transfer completes; do not collapse back to idle while waiting for provider readiness.
- Do not expose or persist `upload_url`, raw `upload_id`, or raw provider asset ids in DOM attributes, logs, analytics, or telemetry.
- If PubSub is unavailable in the adopter example, use polling on the same state model; do not invent alternate labels or different user-facing phases.
- Do not present a provider-side cancel control. `cancel_direct_upload/1` is deferred; any optional adopter reset is local-only and must request a fresh upload URL afterward.

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| shadcn official | none | not required |
| third-party UI registries | none | not applicable — no third-party UI registry blocks declared — 2026-05-24 |
| `@mux/upchunk` package | browser upload client only | locked dependency/docs boundary verified in upstream Mux direct-upload research — 2026-05-24 |

---

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS
- [x] Dimension 2 Visuals: PASS
- [x] Dimension 3 Color: PASS
- [x] Dimension 4 Typography: PASS
- [x] Dimension 5 Spacing: PASS
- [x] Dimension 6 Registry Safety: PASS

**Approval:** approved 2026-05-24
