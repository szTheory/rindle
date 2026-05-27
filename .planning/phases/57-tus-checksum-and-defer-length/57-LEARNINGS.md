# Phase 57 Learnings — Tus Checksum & Defer-Length

## Decisions

- Stream checksum verification in 1 MiB slices via `:crypto.hash_update` to bound memory on large tus PATCH bodies.
- Persist deferred `Upload-Length` on the first PATCH chunk that supplies a length, not at POST creation.

## Surprises

- `460 Checksum Mismatch` must trigger the same cleanup path as other hard tus failures so partial blobs do not linger.

## Patterns (graduation candidate)

- Advertise extensions in `OPTIONS` (`Tus-Extension`, `Tus-Checksum-Algorithm`) before wiring PATCH behavior — keeps client negotiation honest.

## For next phases

- Concatenation (Phase 58) must not clobber JSONb keys when updating `multipart_parts` offsets.
