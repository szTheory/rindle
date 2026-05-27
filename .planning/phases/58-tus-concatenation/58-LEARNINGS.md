# Phase 58 Learnings — Tus Concatenation

## Decisions

- Mark partial sessions with `%{"is_partial" => true}` inside `multipart_parts` JSONb rather than a new column.
- Route final assembly through `Broker.concatenate_tus_sessions/3` → `Storage.concatenate/3` so adapter logic stays centralized.

## Bugs avoided

- **`persist_offset` must merge keys** into `multipart_parts`; a replace-only update wiped `is_partial` and broke partial/final discrimination.

## Patterns (graduation candidate)

- Partial uploads complete at declared length; final `Upload-Concat` validates token URLs and total length before compose.

## For next phases

- Proof phases should assert concat + checksum + defer-length vocabulary together, not per-extension in isolation.
