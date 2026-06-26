# Phase 92: E2E & Screenshot-Driven Polish Loop - Context

**Gathered:** 2026-06-12 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 92 aims to make console behavior and polish deterministic through merge-blocking Playwright specs (happy/error/boundary/theme/destructive) and all-screens × light/dark screenshot capture feeding analyze→fix polish iteration passes.
</domain>

<decisions>
## Implementation Decisions

### Test Environment & Setup
- **D-92-01:** The Admin Console E2E specs will be executed within the existing `adoption_demo` Playwright harness rather than a dedicated standalone test application.

### Screenshot Capture Target
- **D-92-02:** The screenshot polish loop will run against the live Phoenix LiveView app rather than extending the existing static gallery harness.

### Theme & Appearance Testing Strategy
- **D-92-03:** Theme visual regression will be asserted by programmatically toggling the console's UI theme-picker rather than exclusively emulating OS media features.

### Element Selection Strategy
- **D-92-04:** Playwright specs for the Admin Console will locate elements using the `data-rindle-admin-*` attributes rather than the generic `data-testid` attributes.

### Claude's Discretion
Theme & Appearance Testing Strategy and Element Selection Strategy were accepted with "Likely" confidence; planning should execute them as decided above.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/PROJECT.md`
- `examples/adoption_demo/lib/adoption_demo_web/router.ex`
- `scripts/ci/adoption_demo_e2e.sh`
- `brandbook/src/admin-gallery-check.mjs`
- `examples/adoption_demo/e2e/ops-surfaces.spec.js`

No external specs — requirements fully captured in decisions above
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `examples/adoption_demo/playwright.config.js` configures the existing Playwright harness.
- `brandbook/src/admin-gallery-check.mjs` contains a working implementation of a screenshot capture strategy and WCAG contrast check.

### Established Patterns
- Test assertions should verify theme overrides natively using app-level toggles in addition to system preferences.
- Locators inside the admin console use `data-rindle-admin-*` data attributes instead of `data-testid` to prevent test identifiers from leaking into the published library package.

### Integration Points
- Tests will execute against the live `adoption_demo` application which mounts the admin console router at `/admin`.
</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches
</specifics>

<deferred>
## Deferred Ideas

None — analysis stayed within phase scope
</deferred>
