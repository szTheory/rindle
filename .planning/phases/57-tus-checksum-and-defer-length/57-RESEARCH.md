<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Implement `checksum` and `creation-defer-length` extensions in `Rindle.Upload.TusPlug`.
- Advertise `Tus-Checksum-Algorithm: sha1,sha256`.
- Use `:crypto.hash_init/update/final` during the stream drain to compute hashes.
- Return `460 Checksum Mismatch` on validation failure, delete `temp_path`, and do not persist chunk.
- Add nullable `upload_length: :integer` column to `media_upload_sessions` for deferred lengths.
- Require `Upload-Length` on first `PATCH` if deferred, otherwise `400 Bad Request`.
- Token encodes `length: "deferred"` to avoid signed URL mutations.

### the agent's Discretion
None explicitly noted, though implementation specifics around `:crypto` and stream reading inside `write_chunk` are implied.

### Deferred Ideas (OUT OF SCOPE)
None noted.
</user_constraints>

# Phase 57: Tus Checksum & Defer-Length - Research

**Researched:** 2026-05-27
**Domain:** Tus Protocol Extensions (Elixir/Plug)
**Confidence:** HIGH

## Summary

This phase extends the existing bare Plug tus server (`Rindle.Upload.TusPlug`) to support two official tus extensions: `checksum` and `creation-defer-length`. 

The `checksum` extension allows clients to append `Upload-Checksum` to their `PATCH` requests to guarantee data integrity over the wire. We must support `sha1` and `sha256` via Erlang's `:crypto` library. To respect our memory bounds, the hash state must be updated progressively during the 1 MiB chunk reading loop rather than buffering the payload.

The `creation-defer-length` extension allows clients to start an upload without knowing the final size, omitting `Upload-Length` and sending `Upload-Defer-Length: 1` instead. Because our architecture uses stateless signed URL tokens, we encode `length: "deferred"` into the initial token. The actual length is provided on the first `PATCH` and must be persisted to the `media_upload_sessions` database table, requiring a new nullable `upload_length` column.

**Primary recommendation:** Use `:crypto.hash_init`, `hash_update`, and `hash_final` threaded through the `drain/7` recursion to validate checksums without increasing memory overhead. Run an Ecto migration to add `upload_length` to `media_upload_sessions` and conditionally read/write it in `resolve_patch_length`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Stream Hashing | API / Backend (Plug) | — | Integrity validation must occur on the server as bytes are read, before sending to storage. |
| Defer-Length Storage | Database | API / Backend | The signed token is immutable, so deferred length discovery must persist to the database. |
| Protocol Flow Control | API / Backend (Plug) | — | Returning `460 Checksum Mismatch` and `400 Bad Request` are Plug's responsibility. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `:crypto` | (OTP) | SHA1/SHA256 Hashing | Built-in Erlang crypto, C-optimized NIFs, stream-friendly context API. |
| `Ecto.Migration` | ~> 3.10 | Database Schema Update | Standard Elixir database schema manipulation for the new column. |

**Installation:**
No new dependencies are required. `:crypto` is part of OTP and `Ecto` is already installed.

## Architecture Patterns

### Pattern 1: Streaming Hash Context
**What:** Progressive hashing of an incoming stream without buffering the entire payload in memory.
**When to use:** Validating payload integrity for large file uploads over HTTP.
**Example:**
```elixir
# Initialize based on requested algorithm
hash_ctx = case alg do
  "sha1" -> :crypto.hash_init(:sha)
  "sha256" -> :crypto.hash_init(:sha256)
  _ -> nil
end

# Update in the read loop
new_hash_ctx = if hash_ctx do
  :crypto.hash_update(hash_ctx, chunk)
else
  nil
end

# Finalize and compare
computed_hash = :crypto.hash_final(final_hash_ctx)
if computed_hash == expected_hash do
  {:ok, new_offset}
else
  {:error, :checksum_mismatch}
end
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SHA hashing | Custom Elixir bitwise hashing | `:crypto` (Erlang OTP) | NIF performance, standard library, security-hardened. |
| Base64 parsing | Custom string splitters/decoders | `Base.decode64` | `Upload-Checksum` passes the hash as a base64 encoded string. |

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `media_upload_sessions` DB table | Code edit / data migration: add nullable `upload_length: :integer` column |
| Live service config | None — verified | none |
| OS-registered state | None — verified | none |
| Secrets/env vars | None — verified | none |
| Build artifacts | None — verified | none |

## Common Pitfalls

### Pitfall 1: Memory Exhaustion via Whole-Body Hashing
**What goes wrong:** Calling a hashing function on the entire request body at once triggers large memory allocations, negating the 1 MiB stream bounding.
**Why it happens:** Using simpler one-shot functions like `:crypto.hash(:sha256, body)` instead of the stream-oriented `hash_init`/`hash_update` API.
**How to avoid:** Thread the `hash_ctx` through the recursive `drain/7` function in `TusPlug`.

### Pitfall 2: Mutating the Signed URL
**What goes wrong:** Attempting to update the `length` in the client's Tus token.
**Why it happens:** Treating the token as a session payload rather than a stateless verifiable claim.
**How to avoid:** Hardcode `length: "deferred"` into the initial creation token. Fetch and mutate the `upload_length` on the `MediaUploadSession` Ecto struct dynamically on `PATCH`.

### Pitfall 3: Checksum Failure Side-Effects
**What goes wrong:** A checksum mismatch leaves a dirty `.patch` temp file on disk and/or advances the stream offset.
**Why it happens:** Not cleaning up the temp file explicitly during the error path.
**How to avoid:** Ensure the `temp_path` cleanup runs via an `after` block or explicit `File.rm` regardless of the mismatch outcome, and do not call `dispatch_part` if the checksum fails.

## Code Examples

### Parsing Upload-Checksum
```elixir
defp parse_upload_checksum(conn) do
  case get_req_header(conn, "upload-checksum") do
    [value] ->
      case String.split(value, " ", parts: 2) do
        [alg, hash] when alg in ["sha1", "sha256"] ->
          case Base.decode64(hash) do
            {:ok, decoded} -> {:ok, alg, decoded}
            :error -> {:error, :invalid_checksum}
          end
        _ -> {:error, :invalid_checksum}
      end
    _ -> {:ok, nil, nil}
  end
end
```

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified beyond Postgres which is already present and active).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/rindle/upload/tus_plug_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-01 | Return 460 Checksum Mismatch | unit | `mix test test/rindle/upload/tus_plug_test.exs` | ✅ |
| REQ-02 | Accept SHA1/SHA256 valid payload | unit | `mix test test/rindle/upload/tus_plug_test.exs` | ✅ |
| REQ-03 | Defer length POST (returns 201) | unit | `mix test test/rindle/upload/tus_plug_test.exs` | ✅ |
| REQ-04 | Defer length PATCH persists length | unit | `mix test test/rindle/upload/tus_plug_test.exs` | ✅ |
| REQ-05 | Reject length-less deferred PATCH | unit | `mix test test/rindle/upload/tus_plug_test.exs` | ✅ |

### Wave 0 Gaps
None — existing test infrastructure covers all phase requirements.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Signed Tus token logic remains intact. |
| V3 Session Management | yes | Row-level DB state lookup for deferred length. |
| V4 Access Control | yes | Existing token and DB lookup validation. |
| V5 Input Validation | yes | `Integer.parse/1` for parsing headers; `String.split/3` and `Base.decode64` for checksum. |
| V6 Cryptography | yes | `:crypto` OTP lib for `sha1` and `sha256` payload verification. |

### Known Threat Patterns for Elixir / Plug

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unbounded memory allocation | Denial of Service | Do not buffer entire payload; strictly enforce streaming reads with `@read_length`. |
| Directory Traversal | Tampering | Session ID validates against DB before writing to restricted temporary location. |
| Time-of-Check to Time-of-Use | Tampering | Clean up file synchronously and unconditionally if integrity validation fails. |

## Sources

### Primary (HIGH confidence)
- Official tus Resumable Upload Protocol v1.0.0 documentation (Extensions: Checksum, Creation With Defer Length) - Confirmed protocol semantics (460 mismatch status, `Upload-Defer-Length: 1`).
- Erlang/OTP `:crypto` module documentation - Confirmed `hash_init`/`hash_update`/`hash_final` APIs and available algorithms.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Core Erlang/Elixir functionality.
- Architecture: HIGH - Matches existing `TusPlug` stream bounding mechanics and stateless token design.
- Pitfalls: HIGH - Correctly identifies memory bounding and file cleanup traps.

**Research date:** 2026-05-27
**Valid until:** Stable.
