# Phase 37 Deferred Items

Items discovered during Phase 37 execution but out of scope for the current plan.

## From Plan 37-01

### Pre-existing test failure: `Rindle.ApplicationTest.run_startup_checks` AV profile assertion

- **File:** `test/rindle/application_test.exs:41-55`
- **Symptom:** `assert metadata.affected_profiles == ["Elixir.Rindle.ApplicationTest.AVProfile"]` fails because the test environment also registers `Elixir.Rindle.Adopter.CanonicalApp.VideoProfile`. Other related assertions in the same file (`startup_checks` warnings) likely fail for the same reason.
- **Status:** Verified pre-existing — present on `git stash`'d working tree (no Phase 37 changes). Reproduces against Plan 37-01's base commit.
- **Out of scope reason:** Application-bootup AV profile detection. Phase 37 only touches GCS storage adapter HTTP plumbing — no Application or Profile registration changes.
- **Disposition:** Deferred. A follow-up task should investigate whether the canonical adopter app's `VideoProfile` registration is leaking into the application_test setup.
