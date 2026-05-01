# Phase 22: LiveView Corrective Fixes

**Goal**: Fix the code review and warning findings from Phase 20 regarding LiveView and onboarding nil-derefs.
**Depends on**: Phase 20
**Tech Debt**: TD-17
**Success Criteria** (what must be TRUE):
  1. LiveView components no longer trigger CR-01/CR-02 issues.
  2. Onboarding nil-deref (WR-04) and other warnings (WR-01..WR-05) are resolved.

## Source Artifacts
- **Code Review**: `.planning/phases/20-v1.3-verification-and-metadata-closure/20-REVIEW.md` (contains CR-01, CR-02, WR-01..WR-05, IN-01..IN-03)
- **Roadmap**: `.planning/ROADMAP.md` (Phase 22 goals)

## Fix Details to Implement

### LiveView Core Defects (CR-01, CR-02, WR-01, WR-02, WR-03, IN-01)
- Fix `lib/rindle/live_view.ex` protocol violations (`{:error, term}` 2-tuples instead of `{:error, %{...}, socket}` 3-tuples) in `handle_initiate_upload` and `do_allow_upload`. (CR-01, WR-01)
- Fix `consume_uploaded_entries` silent bypass when `session_id` is missing from meta. (CR-02)
- Fix `consume_uploaded_entries` return shape on verification failure to use `{:postpone, ...}` or raise. (WR-02)
- Fix `consume_uploaded_entries` non-idempotency failing FSM transitions on retry. (WR-03)
- Tighten `@spec` for `consume_uploaded_entries/3`. (IN-01)
- Related tests in `test/rindle/live_view_test.exs` need to be updated and added to cover these scenarios.

### Documentation & Minor Issues (WR-04, WR-05, IN-02, IN-03)
- Fix nil-deref in README and `guides/getting_started.md` examples. (WR-04)
- Fix `Rindle.LiveView` moduledoc example referencing nonexistent `entry.asset_id`. (WR-05)
- Fix discarded return value of `Code.ensure_loaded?` in `test/rindle/live_view_test.exs`. (IN-02)
- Move unrelated moduledoc test out of `consume_uploaded_entries/3` describe block in `test/rindle/live_view_test.exs`. (IN-03)
