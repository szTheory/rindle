# Phase 57: Tus Checksum & Defer-Length

## Strategic Intent
Implement the tus `checksum` and `creation-defer-length` extensions in `Rindle.Upload.TusPlug` to comply with the Phase 57 roadmap goals.

## Scope & Implementation Plan

### 1. Upload-Checksum
The `checksum` extension allows clients to verify data integrity of individual `PATCH` chunks.
- **OPTIONS:** Add `checksum` to `Tus-Extension` and advertise `Tus-Checksum-Algorithm: sha1,sha256`.
- **PATCH:** If the `Upload-Checksum` header is present (e.g., `sha256 <base64>`), we must hash the bytes received in `stream_append/4`. 
- Since we drain the conn stream into a temporary part file (`temp_path`), we can compute the hash as we stream using `:crypto.hash_init/update/final`. 
- If the computed hash matches the header, we proceed with `dispatch_part`. If it fails, we return `460 Checksum Mismatch`, delete the `temp_path`, and do not persist the chunk or advance the offset. 
- A helper `plug` or logic in `handle_patch` will parse the algorithm and expected hash before draining.

### 2. Upload-Defer-Length (creation-defer-length)
The `creation-defer-length` extension allows creating an upload without knowing its total size initially.
- **OPTIONS:** Add `creation-defer-length` to `Tus-Extension`.
- **POST:** If `Upload-Length` is missing but `Upload-Defer-Length: 1` is provided, we create the session with a deferred length. 
- Because our signed URL token currently encodes `length` immutably (to avoid a DB lookup on every verification, see D-10), a deferred length will be encoded in the token as `length: "deferred"`.
- **PATCH:** The protocol dictates the client MUST send `Upload-Length` on the first `PATCH` if it was deferred. 
  - If the token indicates `"deferred"`, and the request includes `Upload-Length`, we must persist this newly discovered length. 
  - Since the signed token cannot be mutated, we will introduce a new nullable column `upload_length: :integer` to the `media_upload_sessions` table via an Ecto migration.
  - When parsing the token, if `length` is `"deferred"`, `TusPlug` will look up `session.upload_length`. If it is `nil`, it reads it from the incoming `PATCH` header, validates it against `max_size`, updates the `MediaUploadSession` row, and uses it for the rest of the stream.
  - If `Upload-Length` is omitted on a deferred session's `PATCH`, we reject it with `400 Bad Request`.

### 3. Unit Tests
- Update `test/rindle/upload/tus_plug_test.exs` to cover:
  - Checksum mismatch (460) and success for SHA-256 and SHA-1.
  - Defer-length POST (returns 201 without length).
  - Defer-length PATCH successfully setting the length on the DB row.
  - Rejecting length-less PATCH when length is deferred.

## Escalation / Decision 
Introducing `upload_length` as a column on `media_upload_sessions` is a data model change. However, since `MediaUploadSession` is a library-owned internal lifecycle table and adding a nullable integer column is a non-destructive, backwards-compatible migration, we can safely proceed as the "best default" without user escalation as per GSD default behavior.

## Next Steps
Proceed to execution phase (`/gsd-execute-phase 57`).
