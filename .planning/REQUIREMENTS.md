# Requirements: v1.11 Tus Protocol Completion

## Milestone Goal

Complete the `tus` resumable protocol contract to resolve dangling edge cases and uncommitted work, marking the end of active feature development for the core library.

## Scope

- **TUS-01:** Wrap up uncommitted `Rindle.LiveView.allow_tus_upload` local edits.
- **TUS-02:** Implement `Checksum` support for `tus` protocol to ensure data integrity during upload.
- **TUS-03:** Implement `Concatenation` support for `tus` protocol to allow parallel chunked uploads.
- **TUS-04:** Implement `Upload-Defer-Length` support to allow uploads when the final size is not known upfront.
- **PROOF-01:** Add end-to-end tests and unit tests for Checksum, Concatenation, and Upload-Defer-Length.
- **TRUTH-01:** Document the fully completed `tus` protocol contract in `guides/resumable_uploads.md` and update planning state.

## Out of Scope

- IETF RUFH (tus 2.0)
- GCS-as-tus-backend / R2-native tus proxying
- Rindle-owned standalone tus JS client package
- Generic uploader UI kits beyond the supported helper path
- Second streaming provider
- `cancel_direct_upload/1`
