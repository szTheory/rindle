# Phase 58: Tus Concatenation Context

## Goal
Implement the `Concatenation` extension for the `tus` resumable upload protocol to allow parallel chunked uploads, and update the underlying storage adapters (`Local`, `S3`, `GCS`) to support chunk assembly.

## Alignment
The discuss phase concluded with alignment on the following technical strategy:

1. **Storage Layer (`Rindle.Storage`)**: Introduce a new `@callback concatenate(final_key, source_keys, opts)`.
   - **Local**: Open source files, stream contents into the new `final_key`, and delete sources.
   - **S3**: Initiate a new S3 multipart upload, use `UploadPartCopy` to copy each source object as a part, complete the upload, and delete the source objects.
   - **GCS**: Utilize the GCS `compose` API to combine the source objects, then delete the sources.

2. **Database (`media_upload_sessions`)**: 
   - When `Upload-Concat: partial` is sent on `POST`, we will store `is_partial: true` inside the existing JSON `metadata` column to avoid a database migration.

3. **Plug Layer (`Rindle.Upload.TusPlug`)**:
   - Add `Concatenation` to the `Tus-Extension` header response for `OPTIONS`.
   - For `POST` with `Upload-Concat: partial`, handle it as a regular upload but flag it in metadata.
   - For `POST` with `Upload-Concat: final;URL1 URL2...`, resolve the session UUIDs from the URLs, assert they are all `is_partial` and fully completed. Then call `Rindle.Storage.concatenate/3`, create the final `media_upload_sessions` record, and immediately mark it as complete.

## Next Steps
Proceed to the plan phase (`/gsd-plan-phase 58`) to map patterns, research implementation details, and produce the actionable implementation plan.
