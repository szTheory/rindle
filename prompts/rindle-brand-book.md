Rindle Brand Book v0.1

Working product: Phoenix/Ecto-native media lifecycle library for uploads, attachments, variants, previews, processing, secure delivery, observability, and day-2 operations.

Brand status: creative direction, not legal clearance. A quick search shows that rindle is already used by an npm streams utility and by older project-management/workflow products, so treat the name as amber rather than globally empty. That does not automatically block an OSS Elixir media library, but it does mean the package name, domain, GitHub org, and trademark path should be checked before final launch. Consider rindle_media as a fallback package/repo namespace while keeping Rindle as the brand.  ￼

⸻

1. Brand essence

One-line positioning

Rindle is a Phoenix-native media lifecycle library for turning uploads into durable, secure, observable media assets.

Short product description

Rindle manages the full media lifecycle after upload: staged objects, validation, analysis, attachments, variants, derivatives, previews, background processing, signed delivery, cleanup, regeneration, and operational visibility.

Brand promise

Rindle makes media boringly reliable in production.

Not flashy. Not magical. Not a SaaS wrapper. Rindle is the dependable layer that helps Phoenix teams ship media features without losing control of state, storage, security, or background jobs.

Core metaphor

A rindle means a small runnel or watercourse, which gives the brand a quiet “channel / flow / lifecycle” metaphor. Use that subtly: Rindle guides media through a safe path from upload to ready asset. Do not make the brand look like a water company.  ￼

Brand idea

A protected current.

Media enters as raw bytes. Rindle carries it through validation, processing, storage, delivery, and maintenance. The system is calm, strict, visible, and hard to derail.

⸻

2. Strategic pillars

1. Durable, not disposable

Rindle is not “just upload a file.” It models assets, attachments, variants, upload sessions, processing runs, and lifecycle state.

Message: Upload is the beginning, not the lifecycle.

2. Production-first

Rindle cares about retries, stale variants, cleanup, missing objects, storage costs, queue visibility, and admin workflows.

Message: Day-2 operations are part of the product.

3. Secure by default

Unknown files, arbitrary dynamic transforms, user-controlled paths, and blind presigned URLs are treated as risks.

Message: Strict defaults. Explicit escape hatches.

4. Phoenix-native

Rindle should feel native to Ecto, Phoenix, LiveView, Oban, and Telemetry.

Message: Built for Phoenix apps, not merely adapted to them.

5. Calm developer experience

The library is powerful, but the brand should feel simple, predictable, and respectful.

Message: Clear APIs. Visible state. No hidden magic.

⸻

3. Personality

Axis	Rindle should feel like	Rindle should not feel like
Technical	Precise, explicit, inspectable	Clever, magical, opaque
Emotional	Calm, capable, grounded	Loud, hype-driven, frantic
OSS posture	Peer-to-peer, practical, generous	Corporate, salesy, inflated
Security	Strict, thoughtful, composed	Fearmongering, paranoid
Design	Warm technical minimalism	Cold enterprise dashboard
Writing	Clear, direct, confident	Cute, vague, slogan-heavy

Brand adjectives

Reliable. Clear. Quiet. Durable. Native. Secure. Observable. Composable.

Anti-adjectives

Magical. Cloudy. Slick. Loud. Playful-for-playful’s-sake. Enterprise-bland.

⸻

4. Naming and verbal identity

Product name

Use Rindle in prose.

Use rindle only for package names, CLI commands, repo names, config keys, or code.

Correct:

Rindle helps Phoenix apps manage media assets.
Install the `rindle` package.
Run `mix rindle.cleanup_orphans`.

Avoid:

RINDLE
Rindle.js
Rindle Media Manager Pro
The Rindle Cloud

Naming posture

Rindle should not sound like a SAML, auth, or identity product. Avoid language that creates confusion with identity/security protocol ecosystems.

Avoid brand/product names using:

saml
assertion
identity
idp
sp
federation
signon
passport
auth
claim
principal

Use media-lifecycle terms instead:

asset
attachment
variant
derivative
profile
recipe
pipeline
processor
storage
delivery
session
cleanup

Tagline options

Primary recommendation:

Media, made durable.

Other strong options:

The media lifecycle for Phoenix.
From upload to ready.
Production-grade media for Phoenix apps.
Uploads are only the beginning.
Safe media pipelines for Phoenix.

Avoid:

The ultimate media platform
Magic uploads for Phoenix
Cloudinary for Elixir
SAML for media
Never think about files again

⸻

5. Visual identity direction

Visual concept

Rindle’s visual identity should combine three ideas:

1. Flow: upload session → asset → variants → delivery.
2. Protection: strict validation, secure delivery, safe defaults.
3. Materialization: raw media becoming queryable, observable, durable records.

Logo direction

The logo should be simple enough to work as:

GitHub avatar
Hex package icon
favicon
docs header mark
admin UI mark
social preview

Recommended logo routes

Route A: The channel mark

A rounded, single-line symbol that suggests a small stream or controlled path. It may resemble a bent channel, an r, or a flow line splitting into variants.

Best for: technical elegance, lifecycle metaphor.

Route B: The layered asset mark

A rounded square or soft container with two or three offset layers inside. Suggests original + variants + durable records.

Best for: product clarity, UI/admin association.

Route C: The recipe branch mark

A central dot or small object branches into three outputs. This communicates original asset → generated variants.

Best for: docs, diagrams, developer mental model.

Wordmark

Preferred wordmark style:

rindle

Lowercase wordmark, but product prose remains Rindle.

The lowercase wordmark makes it feel package-native, OSS-native, and approachable. The dot on the i can become a subtle source-object motif.

Logo construction guidance

* Use rounded terminals.
* Use one or two strokes, not complex illustration.
* Avoid hard sharp angles unless balanced by rounded geometry.
* Let the mark feel engineered but not mechanical.
* The icon should remain legible at 24px.

Logo don’ts

Do not use:

cloud upload arrows
camera shutters
generic photo icons
database cylinder icons
padlocks as the primary mark
purple Elixir-like potion motifs
SAML/auth/identity motifs
AI sparkle motifs as the main idea

Security, processing, and AI can be secondary product capabilities, not the logo.

⸻

6. Color system

The Rindle palette should feel warm, technical, secure, and alive. The signature color is green-teal, but the system should be mostly ink, shell, and calm surfaces.

Accessibility baseline: normal text should meet at least 4.5:1 contrast; large text should meet at least 3:1. UI component boundaries and meaningful non-text graphics should also have sufficient contrast, with W3C guidance using 3:1 for active controls and meaningful graphical objects.  ￼

Core palette

Token	Hex	Use
Ink	#101417	Primary text, dark backgrounds, code chrome
Deep Current	#123A35	Primary brand color, buttons, headers
Rindle Green	#32D08C	Signature accent, focus rings, highlights on dark
Rind Lime	#CFEF6A	Sparse energetic accent, diagrams, badges
Warm Shell	#F7F4EA	Main warm background
Porcelain	#FBFEFC	Cards, docs surfaces, content panels
Mist	#E3EAE5	Subtle backgrounds, dividers
Slate	#52605A	Secondary text
Border	#D9E0DA	Borders, separators

Semantic palette

Token	Hex	Use
Ready	#0E7A51	Success, ready, available
Processing	#6D5DD3	Processing, queued execution
Warning	#9A5C00	Stale, degraded, attention
Danger	#C83232	Failed, rejected, destructive
Quarantine	#5A4B6B	Security review, blocked
Info	#2C63D6	Neutral informational callouts
Code BG	#0E1316	Code block background
Code Text	#D7F8E7	Code block text

Usage rules

Good combinations

Ink on Warm Shell
Ink on Porcelain
Warm Shell on Deep Current
Porcelain on Deep Current
Rindle Green on Ink
Rind Lime on Ink
Ready on Warm Shell
Danger on Warm Shell
Code Text on Code BG

Avoid

Rindle Green as small text on Warm Shell
Rind Lime as text on light backgrounds
Warning-only color without label/icon
Danger-only color without label/icon
Low-contrast borders around inputs

CSS token starter

:root {
  --rindle-ink: #101417;
  --rindle-deep-current: #123A35;
  --rindle-green: #32D08C;
  --rindle-lime: #CFEF6A;
  --rindle-shell: #F7F4EA;
  --rindle-porcelain: #FBFEFC;
  --rindle-mist: #E3EAE5;
  --rindle-slate: #52605A;
  --rindle-border: #D9E0DA;
  --rindle-ready: #0E7A51;
  --rindle-processing: #6D5DD3;
  --rindle-warning: #9A5C00;
  --rindle-danger: #C83232;
  --rindle-quarantine: #5A4B6B;
  --rindle-info: #2C63D6;
  --rindle-code-bg: #0E1316;
  --rindle-code-text: #D7F8E7;
}

⸻

7. Typography

Use open-source, web-friendly fonts by default.

Primary stack

Role	Typeface	Why
Display / headings	Space Grotesk	Technical, distinctive, warm, geometric without feeling corporate
Body / UI / docs	Atkinson Hyperlegible	Highly readable, accessible, practical
Code / metrics / IDs	JetBrains Mono	Developer-native, strong code legibility

Space Grotesk is available through Google Fonts and is released under the SIL Open Font License by its publisher; Atkinson Hyperlegible was designed for improved legibility and is available free under the SIL Open Font License; JetBrains Mono is available under SIL Open Font License 1.1 and can be used free of charge for commercial and non-commercial purposes.  ￼

CSS font stack

:root {
  --font-display: "Space Grotesk", ui-sans-serif, system-ui, sans-serif;
  --font-sans: "Atkinson Hyperlegible", ui-sans-serif, system-ui, sans-serif;
  --font-mono: "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
}

Type scale

Role	Size	Line height	Weight
Hero	56–72px	0.95–1.05	600–700
H1	40–48px	1.05	600–700
H2	28–34px	1.15	600
H3	20–24px	1.25	600
Body	16–18px	1.55–1.7	400
Small UI	13–14px	1.4–1.5	400–600
Code	13–15px	1.45–1.6	400–500

Typography rules

* Use Space Grotesk for impact, not paragraphs.
* Use Atkinson Hyperlegible for docs, dense UI, admin screens, forms, and long reads.
* Use JetBrains Mono for code, object keys, checksums, event names, telemetry paths, CLI examples, and recipe digests.
* Avoid all-caps except tiny labels.
* Prefer sentence case for headings and UI labels.
* Keep docs line length around 68–78ch.
* Keep code blocks readable and avoid tiny code.

⸻

8. Layout and UI system

General feel

Rindle UI should feel like a calm operations console plus polished developer docs.

The interface should communicate:

This system knows where your media is.
This system knows what state it is in.
This system can repair, retry, regenerate, and explain failures.

Layout principles

* Use generous whitespace around concept explanations.
* Use dense, structured tables for operational views.
* Use cards for assets, variants, and processing runs.
* Use timelines for lifecycle history.
* Use side panels for metadata, errors, and actions.
* Use status chips everywhere state matters.

Shape language

Element	Radius
Small controls	8px
Inputs / buttons	10px
Cards	14px
Feature panels	20px
Pills / chips	999px

Borders and shadows

* Prefer borders over heavy shadows.
* Use soft inner surfaces instead of floating SaaS cards.
* Shadows should be rare and shallow.

--shadow-card: 0 1px 2px rgba(16, 20, 23, 0.06), 0 8px 24px rgba(16, 20, 23, 0.06);
--border-subtle: 1px solid var(--rindle-border);

UI signature elements

Rindle should have a few recognizable interface patterns:

1. Lifecycle rail
    A horizontal or vertical state path showing upload → validate → analyze → promote → process → ready.
2. Variant matrix
    A table showing each variant name, recipe digest, state, size, format, and last generated time.
3. Asset card
    Thumbnail or file icon, status, owner, profile, storage backend, byte size, and quick actions.
4. Processing timeline
    Oban job / processing run history with attempts, errors, duration, and retry actions.
5. Recipe diff
    A visual comparison showing current recipe digest vs stored variant digest.

⸻

9. Iconography

Style

* Rounded line icons.
* 1.75px or 2px stroke.
* Minimal fill.
* Use optical balance over strict geometry.
* Icons should work at 16px, 20px, and 24px.

Icon themes

Use icons for:

asset
attachment
variant
pipeline
processor
storage
signed URL
quarantine
retry
regenerate
cleanup
stale
missing
ready

Avoid icons for

generic cloud upload as brand icon
camera lens
magic wand
sparkles
robot/AI as core visual
padlock everywhere
database cylinder everywhere

Status icon pairing

Never rely on color alone.

Ready       check circle + label
Processing spinner/clock + label
Queued      hollow clock + label
Stale       warning triangle + label
Missing     broken link + label
Failed      x circle + label
Quarantine  shield pause + label

⸻

10. Imagery and illustration

Acceptable imagery

Rindle should use mostly abstract, technical imagery:

layer diagrams
branching variant maps
state machines
processing timelines
storage topology maps
cropped UI screenshots
code + output compositions
subtle asset thumbnails
abstract channels / current lines
protective shell / layer metaphors

Image style

* Warm neutral background.
* Thin lines.
* Rounded containers.
* Small accents of Rindle Green or Rind Lime.
* Clear labels.
* No decorative complexity in docs diagrams.
* Use diagrams to explain state, not to decorate.

Avoid

stock photos of photographers
people looking at laptops
generic upload cloud illustrations
AI-generated glossy 3D blobs
overly literal rivers/waterfalls
cybersecurity hacker imagery
corporate blue dashboard clichés
photo-camera brand identity

Diagram rules

* Every diagram must teach one lifecycle idea.
* Every state must be labeled.
* Use arrows sparingly and consistently.
* Use dashed lines for async/lazy work.
* Use solid lines for required/eager work.
* Use muted colors for inactive states.
* Use semantic colors only when paired with labels.

⸻

11. Motion and interaction

Motion personality

Rindle motion should feel like materialization, not entertainment.

Use motion to show:

upload progress
state transition
variant generation
retry
lazy materialization
timeline expansion
asset replacement

Timing

Interaction	Duration
Hover / press	100–140ms
Menu / popover	140–180ms
Toast / alert	180–240ms
Lifecycle transition	240–400ms
Diagram animation	400–800ms

Motion rules

* Respect prefers-reduced-motion.
* Do not use bouncing animations.
* Do not make status changes playful.
* Prefer opacity, position, and stroke-draw effects.
* Async processing should show real state, not fake progress.

⸻

12. Brand voice

Voice formula

Clear technical explanation + production empathy + calm confidence.

Rindle should write like an experienced Phoenix maintainer explaining hard-won production lessons to another developer.

Voice examples

Good:

Rindle stores variants as records, not hidden filenames, so failed and stale outputs are visible.

Good:

Direct uploads are sessions. Rindle does not attach or process an object until completion is verified.

Good:

This variant is stale because its recipe changed. Regenerate it to update the stored output.

Bad:

Rindle magically handles all your media!

Bad:

Never worry about uploads again.

Bad:

Enterprise-grade AI-powered media cloud for next-gen developers.

Writing principles

1. Explain state.
    Users should always know what happened, what is happening, and what to do next.
2. Name the footgun.
    Do not hide risks. Explain them calmly.
3. Prefer verbs over abstractions.
    “Regenerate stale variants” is better than “perform maintenance.”
4. Keep examples concrete.
    Use avatars, product photos, private documents, galleries, and previews.
5. Do not overpromise.
    Rindle is a library, not a complete media company.

⸻

13. Documentation tone

Docs should feel

practical
copy-pasteable
production-aware
honest about tradeoffs
structured around real Phoenix workflows

Docs should not feel

academic
marketing-heavy
overly abstract
framework-agnostic to the point of vagueness

Preferred docs structure

Each guide should follow:

# Task name
What you will build.
## When to use this
## Install / configure
## Define the profile
## Attach or upload
## Render or deliver
## Process in the background
## Failure modes
## Production notes
## Full example

Documentation slogans

Use sparingly:

Upload is the beginning, not the lifecycle.
Variants are records.
Recipes are versioned.
Processing is idempotent.
Storage I/O is not a database transaction.
Missing media should be visible.
Strict defaults, explicit escape hatches.

⸻

14. UX microcopy

Buttons

Use direct action labels.

Attach asset
Start upload
Complete upload
Retry processing
Regenerate variant
Regenerate stale variants
Clean up expired sessions
Purge orphaned objects
Verify storage
Copy signed URL
View processing run
Release from quarantine

Avoid vague labels:

Go
Submit
Process
Fix
Continue
Manage

Status labels

Staged
Validating
Analyzing
Promoting
Available
Processing
Ready
Degraded
Quarantined
Rejected
Detached
Purging
Deleted

Variant states:

Planned
Queued
Processing
Ready
Stale
Missing
Failed
Purging
Purged

Upload session states:

Initialized
Signed
Uploading
Uploaded
Verifying
Completed
Aborted
Expired
Failed

Empty states

No assets

No media assets yet.
Upload a file or attach an existing asset to start building this collection.

No variants

No variants have been generated.
Define named variants in this profile, then enqueue processing.

No failed runs

No failed processing runs.
Recent jobs completed without recorded errors.

No orphaned objects

No orphaned objects found.
Expired staged uploads and detached files are currently clean.

Error messages

MIME mismatch

This file says it is image/jpeg, but its contents look like image/png. Upload a valid file or allow this type in the profile.

Too large

This file is larger than the Avatar profile allows. Maximum size: 8 MB.

Variant stale

This variant was generated from an older recipe. Regenerate it to match the current profile.

Missing object

Rindle has a record for this object, but storage did not return the file. Verify storage or regenerate the variant.

Quarantined

This asset is quarantined and cannot be delivered until it is reviewed or released.

Unauthorized delivery

You do not have permission to access this asset.

Toasts

Variant regeneration queued.
Expired upload sessions cleaned up.
Asset attached.
Asset detached. Purge has been queued.
Storage verification started.
Signed URL copied.

Confirmation modals

Use precise, non-alarmist copy.

Purge this asset?
The asset record will be marked for deletion and Rindle will enqueue storage cleanup. This action may remove the original file and generated variants.
[Cancel] [Purge asset]
Regenerate stale variants?
Rindle will enqueue jobs for variants whose recipe digest no longer matches the current profile.
[Cancel] [Regenerate variants]

⸻

15. Product surface guidance

Landing page

Hero

# Rindle
Media, made durable.
Phoenix/Ecto-native media lifecycle for uploads, attachments, variants, previews, secure delivery, Oban processing, and day-2 operations.

CTA labels:

Read the docs
View on GitHub
Install Rindle

Hero visual

Show a clean lifecycle diagram:

Upload Session
   ↓
Staged Object
   ↓
Validate → Analyze → Scan
   ↓
Media Asset
   ↓
Attachment + Variants
   ↓
Signed Delivery + Cleanup

Feature sections

## Model the whole lifecycle
Assets, attachments, variants, upload sessions, and processing runs are first-class records.
## Generate variants safely
Use named recipes, recipe digests, eager or lazy generation, and visible state.
## Built for Phoenix operations
Oban workers, Telemetry events, cleanup tasks, regeneration, and admin views.
## Secure by default
Strict validation, generated storage keys, signed delivery, and scanner hooks.

Proof points

Use product proof, not hype:

Variants are queryable records.
Recipes can be marked stale.
Direct uploads are verified before attachment.
Storage cleanup is explicit and idempotent.
Processing failures are visible.

Documentation homepage

Docs landing page should prioritize:

Getting started
Core concepts
Profiles and recipes
Phoenix uploads
LiveView uploads
Direct uploads
Variants and responsive images
Secure delivery
Background processing
Operations and cleanup
Security checklist

Admin UI

Admin UI should be practical and dense.

Primary views:

Assets
Attachments
Variants
Upload sessions
Processing runs
Storage verification
Cleanup
Quarantine

Asset detail layout:

Header: filename, status, profile, owner
Left: preview / file icon
Right: metadata, storage, checksums, security
Tabs: variants, processing runs, attachments, delivery, audit
Actions: retry, regenerate, detach, quarantine, purge

⸻

16. Component style

Buttons

Primary button:

Deep Current background
Warm Shell text
10px radius
Medium weight
Subtle press state

Secondary button:

Transparent or Porcelain background
Ink text
Border color Border

Danger button:

Danger background only for final destructive action
Otherwise use outline danger style

Inputs

* Porcelain or white background.
* Visible 1px border.
* Focus ring in Rindle Green with enough contrast.
* Error state includes icon + message, not just red border.

Cards

* Porcelain background.
* Border, not heavy shadow.
* Clear header.
* Status chip in top right.
* Metadata rows use mono for keys and IDs.

Code blocks

* Code BG background.
* Code Text primary.
* Syntax highlighting should be restrained.
* Copy button appears on hover and keyboard focus.
* Avoid bright rainbow syntax themes.

Tables

Tables are core to the Rindle admin experience.

Rules:

Sticky header for long tables
Status chip in first visible columns
Monospace IDs but truncated with copy action
Human-readable time + exact timestamp on hover
Bulk actions only after selection

⸻

17. Brand applications

GitHub README

README should open with clarity:

# Rindle
Media, made durable.
Rindle is a Phoenix/Ecto-native media lifecycle library for uploads, attachments, variants, previews, background processing, secure delivery, observability, and day-2 operations.

Then show a compact example quickly:

defmodule MyApp.Media.Avatar do
  use Rindle.Profile
  accepts :image,
    content_types: ~w(image/jpeg image/png image/webp),
    max_bytes: 8 * 1024 * 1024
  variants do
    image :thumb, width: 160, height: 160, fit: :cover, format: :webp
    image :profile, width: 512, height: 512, fit: :cover, format: :webp
  end
end

Social preview

Use:

Warm Shell background
Deep Current wordmark
Small lifecycle diagram
One line: Media, made durable.

Avoid:

busy screenshots
generic cloud graphics
tiny code no one can read

Hex package icon

Use the standalone mark on Deep Current or Warm Shell. It must survive at small sizes.

Docs favicon

Use simplified channel mark or lowercase r symbol. Avoid complex variant-branch mark at favicon size.

⸻

18. Acceptable visual prompts for logo/design exploration

Logo prompt

Design a logo for “Rindle”, an open-source Phoenix/Ecto media lifecycle library. The identity should feel calm, technical, secure, and production-ready. Explore a lowercase wordmark “rindle” with a simple abstract mark suggesting a protected channel, lifecycle flow, or original asset branching into variants. Use rounded geometry, minimal strokes, and a warm technical palette: deep green-black, warm shell, and bright green accent. Avoid cloud upload arrows, camera shutters, padlocks as the main symbol, generic database cylinders, AI sparkles, or purple Elixir motifs.

Landing page prompt

Create a landing page for Rindle, an open-source media lifecycle library for Phoenix apps. The page should feel like polished developer infrastructure: warm off-white background, deep green headers, crisp typography, code examples, lifecycle diagrams, status chips, and subtle rounded cards. Emphasize assets, attachments, variants, processing runs, secure delivery, Oban jobs, Telemetry, cleanup, and regeneration. Voice: calm, precise, production-aware. Avoid startup hype and generic SaaS stock imagery.

Admin UI prompt

Design a Rindle admin UI for inspecting media assets, variants, upload sessions, and processing runs. Use dense but calm tables, asset cards, status chips, processing timelines, recipe digest metadata, and clear actions like retry, regenerate, quarantine, and purge. Visual style: warm technical minimalism, high contrast, rounded controls, deep current green, bright green accents, readable typography, minimal shadows.

⸻

19. Copy bank

Hero lines

Media, made durable.
The media lifecycle for Phoenix.
Uploads are only the beginning.
Production-grade media for Phoenix apps.
From upload to ready.

Product claims

Model assets, attachments, variants, and processing runs as real records.
Generate image variants with named, versioned recipes.
Attach media to Ecto schemas without hiding lifecycle state.
Process variants with Oban and observe them with Telemetry.
Deliver private media through signed URLs or authorized proxies.
Clean up expired sessions, stale variants, and orphaned objects.

Philosophy lines

Variants are records, not hidden filenames.
Direct uploads are sessions, not blind presigned URLs.
Recipes are versioned so stale outputs are visible.
Processing should be idempotent.
Storage cleanup should be explicit.
A missing variant should be a state, not a mystery.

Security lines

Strict defaults for untrusted files.
Generated storage keys, not user-controlled paths.
Named variants by default; signed dynamic transforms only when explicit.
Scanner hooks for teams that need deeper review.
Private delivery without making storage public.

Day-2 operations lines

Regenerate stale variants after recipe changes.
Retry failed processing runs.
Verify storage against database state.
Clean up expired staged uploads.
Find orphaned objects before they become a bill.

⸻

20. Do / don’t summary

Do

Use Rindle as a calm infrastructure brand.
Use lifecycle diagrams.
Use real state names.
Use strict, practical security language.
Use warm technical colors.
Use readable typography.
Use code examples early.
Show admin/operations value.
Explain failure modes.

Don’t

Make it look like a photo app.
Make it look like a cloud storage SaaS.
Overuse water imagery.
Overuse locks and shields.
Use AI sparkle imagery as the brand.
Say “magic.”
Say “never worry again.”
Hide tradeoffs.
Use color as the only status indicator.
Use generic purple Elixir branding.

⸻

21. Compact LLM context capsule

Use this when context is tight:

Rindle is an open-source Phoenix/Ecto-native media lifecycle library. It is not just file upload; it manages upload sessions, staged objects, validation, analysis, media assets, attachments, variants/derivatives/previews, background processing, secure delivery, telemetry, cleanup, regeneration, and admin/day-2 operations. Brand essence: “Media, made durable.” Personality: calm, precise, production-aware, secure-by-default, OSS-native, warm technical minimalism. Avoid hype, magic, generic cloud-upload imagery, camera/photo-app clichés, SAML/auth/identity language, AI sparkle branding, and purple Elixir motifs.
Visual system: lowercase `rindle` wordmark; optional abstract mark suggesting a protected channel, lifecycle flow, or original asset branching into variants. Palette: Ink #101417, Deep Current #123A35, Rindle Green #32D08C, Rind Lime #CFEF6A, Warm Shell #F7F4EA, Porcelain #FBFEFC, Mist #E3EAE5, Slate #52605A. Typography: Space Grotesk for headings, Atkinson Hyperlegible for body/UI/docs, JetBrains Mono for code. UI should use high-contrast text, rounded cards, visible borders, status chips, lifecycle rails, variant matrices, processing timelines, and practical admin actions.
Voice: developer-to-developer, clear, direct, honest about footguns. Key phrases: “Upload is the beginning, not the lifecycle.” “Variants are records, not hidden filenames.” “Direct uploads are sessions, not blind presigned URLs.” “Recipes are versioned.” “Processing is idempotent.” “Storage cleanup is explicit.” UX copy should explain state and next action: Retry processing, Regenerate stale variants, Verify storage, Clean up expired sessions, Release from quarantine, Purge orphaned objects.