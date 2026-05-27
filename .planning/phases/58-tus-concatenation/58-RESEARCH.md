<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
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

### the agent's Discretion
None explicitly requested, but schema mechanics (`metadata` column) require an implementation adjustment to honor the "avoid a database migration" constraint.

### Deferred Ideas (OUT OF SCOPE)
None explicitly listed.
</user_constraints>

# Phase 58: Tus Concatenation - Research

**Researched:** 2026-05-28
**Domain:** Tus Protocol Extension (Concatenation), S3 UploadPartCopy, GCS Compose API
**Confidence:** HIGH

## Summary

This phase implements the `Concatenation` extension for the `tus` resumable upload protocol, allowing parallel chunked uploads via `Upload-Concat: partial` and `Upload-Concat: final`. 

To fulfill this, a new polymorphic `concatenate/3` callback must be implemented across `Local`, `S3`, and `GCS` adapters. `S3` utilizes its `UploadPartCopy` API within a Multipart session, `GCS` utilizes the `compose` JSON API endpoint, and `Local` relies on bounded chunk streaming. `TusPlug` requires updates across `OPTIONS` and `POST` methods to handle these new headers, verify HMAC signatures on the provided partial URLs, and perform convergence.

**Primary recommendation:** Use `multipart_parts` for the `is_partial: true` JSON payload since `media_upload_sessions` does not have a `metadata` column; for `ExAws.S3.upload_part_copy`, perform a `HEAD` request on source keys to obtain byte sizes, as ExAws strictly mandates a Range struct (e.g. `0..size-1`) for its `source_range` argument.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| GCS Object Compose | API / Backend (`GCS.Client`) | — | Executed server-side using Google's HTTP `compose` JSON API. |
| S3 UploadPartCopy | API / Backend (`S3`) | — | Dispatched via `ExAws.S3` as server-to-server operations. |
| Token Verification | Frontend Server (`TusPlug`) | — | `TusPlug` extracts the trailing HMAC-signed token from `URL1 URL2` and verifies it. |
| Session Convergence | API / Backend (`Broker`) | `TusPlug` | Validating the state of partials and spinning up the final upload asset MUST be handled by the business layer, invoked by the Plug. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ex_aws_s3` | `~> 2.5` | S3 API interface | Standard, already adopted. `upload_part_copy/8` covers server-side concatenation. |
| `finch` | `~> 0.21` | HTTP Client for GCS | Standard, already adopted. Used to dispatch `POST .../compose` for Google Cloud Storage. |

**Installation:** None required. All libraries are present.

## Architecture Patterns

### Pattern 1: S3 `UploadPartCopy`
**What:** S3 server-side copying without pulling data through the application heap.
**When to use:** In `Rindle.Storage.S3.concatenate/3`.
**Example:**
```elixir
# 1. Initiate Multipart
{:ok, %{body: %{upload_id: id}}} = request(S3.initiate_multipart_upload(bucket, final_key), opts)

# 2. UploadPartCopy for each part
Enum.reduce_while(Enum.with_index(source_keys, 1), {:ok, []}, fn {src_key, part_number}, {:ok, parts} ->
  {:ok, %{size: size}} = head(src_key, opts)
  
  # CRITICAL: source_range MUST be a Range struct like 0..(size-1)
  case request(S3.upload_part_copy(bucket, final_key, bucket, src_key, id, part_number, 0..(size - 1)), opts) do
    {:ok, response} -> 
       etag = etag_from_headers(response) || etag_from_body(response) 
       {:cont, {:ok, [{part_number, etag} | parts]}}
    {:error, reason} -> 
       {:halt, {:error, reason}}
  end
end)

# 3. Complete Multipart & Delete Sources
request(S3.complete_multipart_upload(bucket, final_key, id, parts), opts)
Enum.each(source_keys, &request(S3.delete_object(bucket, &1), opts))
```

### Pattern 2: GCS `compose` API via Finch
**What:** Google Cloud Storage JSON API `compose` endpoint.
**When to use:** In `Rindle.Storage.GCS.Client.compose/4`.
**Example:**
```elixir
url = "#{base_url(opts)}/storage/v1/b/#{bucket}/o/#{URI.encode(final_key, &URI.char_unreserved?/1)}/compose"
source_objects = Enum.map(source_keys, fn key -> %{"name" => key} end)
metadata = %{"sourceObjects" => source_objects}

req = Finch.build(:post, url, [{"content-type", "application/json"} | auth_headers], Jason.encode!(metadata))
```

### Pattern 3: HMAC-Verified URL Resolution
**What:** Resolving space-separated URLs in `Upload-Concat: final;URL1 URL2`.
**When to use:** In `Rindle.Upload.TusPlug` POST handler.
**Example:**
```elixir
[_, uris_string] = String.split(header, ";", parts: 2)
uris = String.split(uris_string, " ", trim: true)

# 1. Extract Token from each URI
tokens = Enum.map(uris, fn uri -> URI.parse(uri).path |> Path.split() |> List.last() end)

# 2. Verify Token to extract session_id
Enum.map(tokens, fn token -> 
  Plug.Crypto.verify(secret_key_base, "rindle:tus:url", token) 
end)
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| S3 Object merging | Downloading parts and streaming them into a PUT | S3 `UploadPartCopy` API | Downloads cost bandwidth, tie up memory, and dramatically increase assembly time. S3 handles part copies completely server-side. |
| GCS Object merging | Downloading parts and streaming them into a PUT | GCS `compose` API | Same as above. The `compose` API instantly creates a composite object on Google's backend. |

## Common Pitfalls

### Pitfall 1: `media_upload_sessions` has no `metadata` column
**What goes wrong:** The planner assumes `metadata` exists in the schema and adds `is_partial: true` to it, leading to an Ecto cast error (`unknown field metadata`).
**Why it happens:** CONTEXT asserts `is_partial: true` should go "inside the existing JSON metadata column." However, `media_upload_sessions` has NO `metadata` column. The JSON-B column is named `multipart_parts: :map`.
**How to avoid:** To adhere strictly to "avoid a database migration," insert `%{"is_partial" => true}` inside the `multipart_parts` map field, which defaults to `%{}`, or use the `metadata` column natively available on the parent `MediaAsset` record.

### Pitfall 2: `ExAws.S3.upload_part_copy/8` Requires a Range Struct
**What goes wrong:** Calling `ExAws.S3.upload_part_copy` without `source_range` or setting it to `nil` crashes with a `MatchError`.
**Why it happens:** The `ex_aws_s3` library specifically destructured `first..last//_ = source_range` on line 1888. It strictly expects an Elixir Range struct to inject the `x-amz-copy-source-range` header.
**How to avoid:** Always perform a `Rindle.Storage.head/2` on the `source_key` (or reference `media_upload_sessions.upload_length`) to determine its size `N`. Supply `0..(N - 1)` as the range to `upload_part_copy`.

### Pitfall 3: GCS Compose does NOT automatically delete sources
**What goes wrong:** Storage buckets swell with orphaned partial chunks after successful `final` assemblies.
**Why it happens:** The GCS `compose` JSON API merely constructs the final object; it never mutates or deletes the source objects.
**How to avoid:** `Rindle.Storage.GCS.concatenate/3` must explicitly loop through `source_keys` and issue `delete` operations for each after `compose` returns a `2xx` response.

### Pitfall 4: GCS Compose 32-Object Limit
**What goes wrong:** The client attempts to assemble 50 parallel chunks; GCS returns `400 Bad Request`.
**Why it happens:** Google limits a single `compose` operation to a maximum of 32 source objects.
**How to avoid:** If `length(source_keys) > 32`, you must compose in batches (e.g. fold the first 32 into a temporary composition object, then compose that temporary object with the next chunk of keys), OR return an error/guard. The batch-compose strategy is recommended for robustness.

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified beyond the core storage providers S3/GCS which are already provisioned).

## Code Examples

### ExAws S3 Upload Part Copy Loop
```elixir
# S3 chunk iteration pattern
Enum.reduce_while(Enum.with_index(source_keys, 1), {:ok, []}, fn {src_key, part_num}, {:ok, acc} ->
  {:ok, %{size: size}} = Rindle.Storage.head(src_key, opts)
  
  case request(S3.upload_part_copy(bucket, final_key, bucket, src_key, upload_id, part_num, 0..(size - 1)), opts) do
    {:ok, response} -> 
       # Extract ETag from response headers or body
       etag = etag_from_headers(response) || etag_from_body(response) 
       {:cont, {:ok, [{part_num, etag} | acc]}}
    {:error, reason} -> 
       {:halt, {:error, reason}}
  end
end)
```

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `TusPlug` HMAC signature generation applies equally to `is_partial: true` sessions. | Architectural Responsibility Map | If tokens can't be decoded reliably, we won't be able to match the URL list to DB rows. |
| A2 | ExAws `upload_part_copy` XML bodies can be correctly parsed for ETags via `ExAws.S3.Parsers`. | Common Pitfalls | Custom XML parsing using `sweet_xml` may be necessary if it doesn't automatically unwrap the `CopyPartResult` ETag. |

## Open Questions (RESOLVED)

1. **GCS Compose limit handling**
   - What we know: GCS compose API enforces a 32 source-object limit per request.
   - What's unclear: Should `Rindle.Storage.GCS.concatenate/3` perform batch folding to handle arrays `> 32`, or enforce an upstream limit in `TusPlug`?
   - Recommendation: Implement a simple batch-folder loop in `Rindle.Storage.GCS.concatenate/3` since doing it adapter-side cleanly abstracts the limitation away from `TusPlug`.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Config file | `mix.exs` |
| Quick run command | `mix test` |
| Full suite command | `mix test` |

### Sampling Rate
- **Per task commit:** `mix test test/rindle/upload/tus_plug_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`
