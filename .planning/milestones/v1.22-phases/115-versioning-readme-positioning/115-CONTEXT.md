# Phase 115: Versioning & README Positioning - Context

**Gathered:** 2026-07-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 115 is a docs-and-proof phase. It closes VERSION-01, VERSION-02, README-01, and README-02 by:

1. Stating Rindle's SemVer / pre-1.0 stability contract in `README.md` and `CONTRIBUTING.md`.
2. Turning `guides/upgrading.md` from a single pre-0.1.4 runbook into a reusable newest-first versioned upgrade home.
3. Reordering the README so the first hands-on path is an original-only image attachment path, with AV setup below it.
4. Adding an honest "when not to use Rindle" boundary in the README, lifted and compressed from `guides/user_flows.md`.

No `lib/`, `priv/`, runtime behavior, package dependency, docs styling, release version file, or migration API work is authorized by this phase. Phase 116 owns `Rindle.Migration.up/1` / `down/1` and the Oban-owned migration rewrite. v1.23 owns the breaking schema-isolation flip.

</domain>

<decisions>
## Implementation Decisions

### Discussion Outcome

- **D-01:** Do not ask new user questions for this phase. The roadmap, requirements, research, and approved UI-SPEC already lock the implementation direction. The UI-SPEC explicitly says "Do not add new user questions for this phase"; downstream planning should proceed from the artifacts listed in `<canonical_refs>`.
- **D-02:** Treat `115-UI-SPEC.md` as a locked documentation UX/design contract, not as a requirements SPEC. It governs Markdown hierarchy, copy labels, ordering, callout shape, and dependency boundaries for README/guide work.

### Stability Contract

- **D-03:** README and CONTRIBUTING must use the same stability sentence:
  `Rindle follows Semantic Versioning. While Rindle is 0.x, public APIs may change between minor versions; review CHANGELOG.md and guides/upgrading.md before upgrading. Rindle 1.0 will mean the public API is stable enough that breaking public API changes move to major versions.`
- **D-04:** Place `## Versioning and stability` near the top of README, above the first-run code and near install/orientation. Add the same heading near the top of CONTRIBUTING before CI/release-process detail.
- **D-05:** Do not invent a custom versioning policy detached from SemVer. Keep the contract short, factual, and pre-1.0 specific.

### Upgrade Guide Structure

- **D-06:** `guides/upgrading.md` becomes a reusable versioned guide with `## Version index` immediately after the intro, `## Unreleased / Next` as the first entry, and `## 0.1.3 and earlier -> current AV-aware runtime` preserving the existing pre-0.1.4 upgrade path.
- **D-07:** Each versioned upgrade entry must use these exact subsection labels: `Applies to`, `What changed`, `Upgrade steps`, and `Verification`.
- **D-08:** The guide must be newest-first and link to `CHANGELOG.md`. It should separate "what changed" from "what to do" rather than duplicating the changelog.
- **D-09:** Preserve the current generated-app proof sequence and migration/runtime repair details while wrapping them in the new versioned structure.

### README First-Run Repositioning

- **D-10:** The first hands-on README section must be `## First Attachment in ~2 Minutes`, and it must appear before `## AV Quickstart`, any FFmpeg prerequisite, any libvips prerequisite, `kind: :video`, `Rindle.Profile.Presets.Web`, `web_720p`, or poster variants.
- **D-11:** The first-run path must use an image profile with `variants: []`, `allow_mime`, and `max_bytes`, followed by the facade flow: `Rindle.initiate_upload`, `Rindle.Upload.Broker.sign_url`, client PUT, `Rindle.verify_completion`, `Rindle.attach`, and `Rindle.url`.
- **D-12:** Phrase the path as original-only first attachment before variants/AV processing. Do not promise that complete image background processing is libvips-free: current image promotion still probes via `Rindle.Probe.Image`, so image variants/background image processing still require libvips.
- **D-13:** Demote AV setup below the image-first path as `## AV Quickstart`. It may mention `FFmpeg >= 6.0`, `Rindle.Profile.Presets.Web`, `web_720p`, and poster variants only after the image-first path.
- **D-14:** Keep long host dependency matrices out of README. Link to `RUNNING.md` / rendered `running.html` for FFmpeg/libvips platform details.

### Product-Fit Boundary

- **D-15:** Add `## When Not to Use Rindle` to README before final guide links or near the positioning section. Lift and compress the source truth from `guides/user_flows.md`.
- **D-16:** The boundary must make self-disqualification easy: Rindle is a Phoenix/Ecto library, not a hosted media platform, daemon, CDN replacement, DRM system, full HLS/DASH streaming platform, AI/GPU processing suite, or broad PDF/Office document-processing system.
- **D-17:** Do not style this as a destructive warning. Use normal Markdown prose or a short portable blockquote with an approved label from the UI-SPEC.

### Proof And Verification

- **D-18:** Extend `test/install_smoke/docs_parity_test.exs` as the regression lock for this phase. Add assertions for the shared stability sentence in README and CONTRIBUTING, upgrade guide version structure, README image-before-AV order, and README boundary copy.
- **D-19:** Update existing AV onboarding assertions deliberately so they continue to prove the AV path exists without requiring it to be the first README path.
- **D-20:** Recommended quick verification: `MIX_ENV=test mix test test/install_smoke/docs_parity_test.exs --trace` plus `mix format --check-formatted test/install_smoke/docs_parity_test.exs` when the test file changes. Phase gate remains `mix ci` or the documented equivalent required by RUNNING/CONTRIBUTING.

### Scope Guardrails

- **D-21:** Do not document future `Rindle.Migration.up/1` or `Rindle.Migration.down/1` in Phase 115. Keep current migration snippets unless Phase 116 has already landed.
- **D-22:** Do not reconcile local release version files (`mix.exs`, `.release-please-manifest.json`, `CHANGELOG.md`) as an implicit Phase 115 task. The research found live/local version tension; planners should avoid changing release truth unless a separate scoped task authorizes it.
- **D-23:** Do not add a docs site, Markdown plugin, shadcn/Radix/Tailwind component, registry block, custom admonition system, CSS/JS dependency, or generated docs styling for this phase. GitHub Markdown and ExDoc extras are the target surfaces.

### Claude's Discretion

- Exact prose around the locked sentence, section transitions, and examples, as long as the required headings, labels, order, and safety wording are preserved.
- Exact test helper shape in `DocsParityTest`, including whether to add a `@contributing_path`, new setup key, or direct file read inside the new test.
- Whether README links use source paths or rendered ExDoc `.html` links, matching nearby existing README style.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Scope And Locked Decisions

- `.planning/ROADMAP.md` section "Phase 115: Versioning & README Positioning" - phase goal, dependency on Phase 113, requirements, and success criteria.
- `.planning/REQUIREMENTS.md` - VERSION-01, VERSION-02, README-01, README-02, and out-of-scope future requirements.
- `.planning/STATE.md` - current v1.22 posture, Phase 115 docs-only boundary, Phase 116 migration boundary, and deferred v1.23 schema isolation.
- `.planning/phases/115-versioning-readme-positioning/115-RESEARCH.md` - research-backed implementation recommendations, pitfalls, validation map, and release/version mismatch warning.
- `.planning/phases/115-versioning-readme-positioning/115-UI-SPEC.md` - approved documentation UX/design contract; MUST read before planning.
- `.planning/phases/113-evaluation-baseline-release-hygiene/113-CONTEXT.md` - EVAL-01 maps versioning and README weaknesses to Phase 115.

### Documentation Surfaces To Edit Or Preserve

- `README.md` - currently AV-first; target surface for versioning, image-first first attachment, AV demotion, and "when not to use" boundary.
- `CONTRIBUTING.md` - currently CI-focused; target surface for the contributor-facing versioning and stability section.
- `guides/upgrading.md` - current pre-0.1.4 runbook to wrap into the reusable versioned guide.
- `guides/user_flows.md` - source truth for the "library, not a platform" and out-of-scope boundary copy.
- `RUNNING.md` - durable FFmpeg/libvips install matrix; README should link here instead of duplicating long platform setup.
- `CHANGELOG.md` - linked from the stability contract and upgrade guide; do not duplicate it in `guides/upgrading.md`.
- `guides/getting_started.md` - deep adopter guide that should remain coherent with README's first-run posture.

### Verification And Docs Wiring

- `test/install_smoke/docs_parity_test.exs` - existing docs parity lock; extend for all four Phase 115 requirements.
- `mix.exs` - ExDoc extras already include README, user flows, upgrading, and related guides; do not add a new docs subsystem.
- `CONTRIBUTING.md` - defines `mix ci` and the PR gate; use it with `RUNNING.md` when choosing final verification.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `test/install_smoke/docs_parity_test.exs` already reads README, getting started, upgrading, running, release, operations, troubleshooting, and user flows; it has `assert_in_order!/2` and `string_index/2` helpers suited for README image-before-AV assertions.
- `guides/user_flows.md` already contains the concise source boundary: Rindle is a library, not a platform, and deliberately out of scope for full HLS/DASH platform, DRM, AI/GPU processing, broad PDF/Office handling, or CDN replacement.
- `guides/upgrading.md` already contains the upgrade proof sequence and repair commands that should be preserved inside the new versioned section.
- `README.md` already has the facade-first call flow, but it is currently under an AV-first profile and must be moved behind an image/original-only profile.

### Established Patterns

- Documentation claims that encode adopter contracts are locked with ExUnit docs parity tests, not just prose review.
- README is the narrow quickstart; detailed runtime dependency matrices live in `RUNNING.md`.
- ExDoc extras are the existing rendered-docs mechanism. Phase 115 should stay Markdown-first.
- Rindle docs use facade-first examples (`Rindle.initiate_upload`, `verify_completion`, `attach`, `url`) and keep lower-level upload broker details as a transport step, not the conceptual entrypoint.

### Integration Points

- README, CONTRIBUTING, and upgrading guide edits should be paired with docs parity assertions in `test/install_smoke/docs_parity_test.exs`.
- If README first-run wording changes affect `guides/getting_started.md` parity expectations, update the test intentionally rather than weakening the broader facade-first coverage.
- Any libvips/FFmpeg wording must remain compatible with `RUNNING.md` and current image/AV implementation reality.

</code_context>

<specifics>
## Specific Ideas

- Required README headings from the UI-SPEC: `## Versioning and stability`, `## First Attachment in ~2 Minutes`, `## AV Quickstart`, and `## When Not to Use Rindle`.
- Required CONTRIBUTING heading from the UI-SPEC: `## Versioning and stability`.
- Required upgrading headings from the UI-SPEC: `## Version index`, `## Unreleased / Next`, and `## 0.1.3 and earlier -> current AV-aware runtime`.
- Approved portable callout labels: `Versioning:`, `Note:`, `When not to use Rindle:`, and `Upgrade note:`.
- Primary CTA/copy concept for README first-run path: `Create first attachment`.

</specifics>

<deferred>
## Deferred Ideas

- Phase 116 owns `Rindle.Migration.up/1` / `down/1`, the new install/upgrade migration snippets, and stopping Rindle from creating `oban_jobs`.
- v1.23 owns the breaking Postgres schema isolation default flip.
- A true no-libvips complete image lifecycle would require code changes outside this docs-only phase.
- No todos were folded into Phase 115. `todo.match-phase` reported no matches for this phase.

</deferred>

---

*Phase: 115-versioning-readme-positioning*
*Context gathered: 2026-07-01*
