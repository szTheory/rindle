defmodule Rindle.Storage do
  @moduledoc """
  Behaviour contract for all storage adapters used by Rindle.

  Storage I/O must never happen inside database transactions. Callers should
  persist domain state first, then execute storage side effects in separate
  steps.
  """

  @typedoc """
  Shared storage capability vocabulary exposed by adapters via `c:capabilities/0`.

  Adapters only advertise the capabilities they actually support. The resumable
  atoms are shipped broker-facing contracts, but non-resumable adapters remain
  honest by omitting them from `c:capabilities/0`.
  """
  @type capability ::
          :presigned_put
          | :multipart_upload
          | :signed_url
          | :head
          | :local
          | :resumable_upload
          | :resumable_upload_session
          | :tus_upload

  @typedoc "Successful storage write metadata. Adapters MUST include `:key`; other fields are adapter-specific."
  @type put_result :: %{:key => String.t(), optional(atom()) => term()}

  @typedoc "Successful storage delete metadata. Adapters MUST include `:key` when known."
  @type delete_result :: %{optional(:key) => String.t(), optional(atom()) => term()}

  @typedoc "Resolved delivery URL string."
  @type url_result :: String.t()

  @typedoc "Presigned upload payload. `:url`, `:method`, and `:headers` are required; multipart variants add `:part_number` and `:upload_id`."
  @type presign_result :: %{
          required(:url) => String.t(),
          required(:method) => atom() | String.t(),
          required(:headers) => map() | list(),
          optional(:part_number) => pos_integer(),
          optional(:upload_id) => String.t()
        }

  @typedoc "Multipart-upload initiation metadata. `:upload_id` is required; other fields are adapter-specific."
  @type multipart_init_result :: %{
          required(:upload_id) => String.t(),
          optional(:upload_key) => String.t(),
          optional(:bucket) => String.t(),
          optional(:part_size) => pos_integer(),
          optional(atom()) => term()
        }

  @typedoc "Multipart-upload completion metadata. `:upload_id` and `:upload_key` are required."
  @type multipart_complete_result :: %{
          required(:upload_id) => String.t(),
          required(:upload_key) => String.t(),
          optional(atom()) => term()
        }

  @typedoc "Storage object metadata returned by HEAD. `:size` is required; `:content_type` is best-effort."
  @type head_result :: %{
          required(:size) => non_neg_integer(),
          optional(:content_type) => String.t() | nil,
          optional(atom()) => term()
        }

  @typedoc """
  Resumable-upload initiation metadata.

  `:session_uri`, `:upload_id`, and `:expires_at` are required; any region
  pinning or transport hints remain advisory metadata only.
  """
  @type resumable_init_result :: %{
          required(:session_uri) => String.t(),
          required(:upload_id) => String.t(),
          required(:expires_at) => DateTime.t(),
          optional(:region_hint) => String.t() | nil,
          optional(atom()) => term()
        }

  @typedoc """
  Resumable-upload status metadata.

  `:committed_bytes` is the server-observed offset and `:state` reflects the
  remote session lifecycle only.
  """
  @type resumable_status_result :: %{
          required(:committed_bytes) => non_neg_integer(),
          required(:state) => :in_progress | :complete | :expired,
          optional(atom()) => term()
        }

  @typedoc """
  Per-PATCH streaming part-write state for a tus upload (Topology B,
  server-mediated — bytes flow on the BEAM hot path).

  `:offset` is the new committed offset (== the tus `Upload-Offset`) the edge
  persists and reports on the next `HEAD`. The optional keys carry the
  cross-PATCH multipart bookkeeping S3 needs and Local omits:

    * `:upload_id` — the S3 multipart `UploadId` (absent for Local; Local has no
      part semantics).
    * `:parts` — the accumulated, server-issued part list, each entry a
      `%{part_number: pos_integer(), etag: String.t()}`. `part_number` is
      1-based and strictly increasing; reassembly is by `part_number`, never by
      arrival order, and the ETag is sourced from S3 responses, never the client.

  The map is persisted between PATCHes (S3 keeps it in `multipart_parts` +
  `multipart_upload_id` on the session row) and threaded back in as the `state`
  argument on the next call.
  """
  @type tus_part_state :: %{
          required(:offset) => non_neg_integer(),
          optional(:upload_id) => String.t(),
          optional(:parts) => [%{part_number: pos_integer(), etag: String.t()}],
          optional(atom()) => term()
        }

  @doc """
  Stores the file at `source` under `key`, returning adapter-specific write metadata.

  Callers must pass an absolute or otherwise resolvable `source` path. The
  adapter writes the object at the storage-side address derived from `key` and
  returns a `t:put_result/0` containing `:key` plus any adapter-specific
  metadata (path, ETag, etc.). Storage I/O must happen outside DB transactions.
  """
  @callback store(key :: String.t(), source :: Path.t(), opts :: keyword()) ::
              {:ok, put_result()} | {:error, term()}

  @doc """
  Downloads the object at `key` to `destination`, returning the destination path.

  The adapter reads the object identified by `key` and writes its bytes to
  `destination`. Callers are responsible for ensuring `destination` is a writable
  path; adapters may create the parent directory but should not assume it exists.
  Returns `{:error, term()}` if the object is missing or unreadable.
  """
  @callback download(key :: String.t(), destination :: Path.t(), opts :: keyword()) ::
              {:ok, Path.t()} | {:error, term()}

  @doc """
  Deletes the object at `key`.

  Adapters return a `t:delete_result/0` map (which MAY include `:key` when
  known). Deleting a non-existent key is adapter-defined: implementations may
  return `:ok` (idempotent) or `{:error, :not_found}`. Async-purge callers
  should treat both as successful eventual deletion.
  """
  @callback delete(key :: String.t(), opts :: keyword()) ::
              {:ok, delete_result()} | {:error, term()}

  @doc """
  Resolves the delivery URL for `key`.

  Public adapters return a bare URL; private adapters return a signed URL whose
  expiry is governed by the adapter's signed-URL TTL configuration. Authorization
  (when configured) MUST be evaluated by the caller before invoking this callback;
  the adapter does not perform authorization itself.
  """
  @callback url(key :: String.t(), opts :: keyword()) ::
              {:ok, url_result()} | {:error, term()}

  @doc """
  Generates a presigned PUT URL adopters can hand to clients for direct uploads.

  Requires the adapter to advertise the `:presigned_put` capability via
  `c:capabilities/0`. The returned `t:presign_result/0` includes `:url`,
  `:method`, and `:headers` that the client must use verbatim. `expires_in` is
  the URL lifetime in seconds.
  """
  @callback presigned_put(key :: String.t(), expires_in :: pos_integer(), opts :: keyword()) ::
              {:ok, presign_result()} | {:error, term()}

  @doc """
  Initiates a multipart upload session for `key` with the given `part_size`.

  Requires the adapter to advertise the `:multipart_upload` capability via
  `c:capabilities/0`. Returns `t:multipart_init_result/0` carrying the
  `:upload_id` adopters must echo back through `c:presigned_upload_part/5`,
  `c:complete_multipart_upload/4`, and `c:abort_multipart_upload/3`.
  """
  @callback initiate_multipart_upload(
              key :: String.t(),
              part_size :: pos_integer(),
              opts :: keyword()
            ) :: {:ok, multipart_init_result()} | {:error, term()}

  @doc """
  Generates a presigned URL for one part of an in-progress multipart upload.

  Requires the adapter to advertise the `:multipart_upload` capability. Callers
  pass the `upload_id` from `c:initiate_multipart_upload/3` and a 1-based
  `part_number`. The returned `t:presign_result/0` carries the part-scoped
  presigned PUT URL the client uploads the chunk to.
  """
  @callback presigned_upload_part(
              key :: String.t(),
              upload_id :: String.t(),
              part_number :: pos_integer(),
              expires_in :: pos_integer(),
              opts :: keyword()
            ) :: {:ok, presign_result()} | {:error, term()}

  @doc """
  Finalizes a multipart upload after all parts have been uploaded.

  Requires the adapter to advertise the `:multipart_upload` capability. Callers
  pass the `upload_id` and the ordered `parts` list (each entry carrying at
  least `:part_number` and the storage-side ETag). Returns
  `t:multipart_complete_result/0` describing the assembled object.
  """
  @callback complete_multipart_upload(
              key :: String.t(),
              upload_id :: String.t(),
              parts :: [map() | {pos_integer(), String.t()}],
              opts :: keyword()
            ) :: {:ok, multipart_complete_result()} | {:error, term()}

  @doc """
  Aborts an in-progress multipart upload, releasing storage-side resources.

  Requires the adapter to advertise the `:multipart_upload` capability. Used by
  cleanup workers to compensate for orphaned multipart sessions. The success
  shape is intentionally adapter-specific (`{:ok, term()}`); on missing uploads
  adapters typically return `{:error, :not_found}`, which callers may treat as
  successful idempotent abort.
  """
  @callback abort_multipart_upload(
              key :: String.t(),
              upload_id :: String.t(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @doc """
  Returns object metadata (size, content-type) without downloading the body.

  Requires the adapter to advertise the `:head` capability via `c:capabilities/0`.
  The returned `t:head_result/0` carries `:size` (required) and best-effort
  `:content_type`. Used by the upload broker to verify storage-side completion
  before promoting an asset.
  """
  @callback head(key :: String.t(), opts :: keyword()) ::
              {:ok, head_result()} | {:error, term()}

  @doc """
  Initiates a resumable upload session for `key`.

  Adapters expose this callback only when they advertise the
  `:resumable_upload` capability. Along with
  `c:verify_resumable_completion/3`, it forms the minimum adapter surface
  behind broker resumable initiation; the broker still owns the session
  lifecycle and persistence rules.
  """
  @callback initiate_resumable_upload(
              key :: String.t(),
              expected_size :: pos_integer() | nil,
              opts :: keyword()
            ) :: {:ok, resumable_init_result()} | {:error, term()}

  @doc """
  Returns remote status for an in-flight resumable upload session.

  Adapters expose this callback only when they advertise the
  `:resumable_upload_session` capability. Together with
  `c:cancel_resumable_upload/3`, it provides the broker's operational surface
  for polling and cleanup.
  """
  @callback resumable_upload_status(
              key :: String.t(),
              session_uri :: String.t(),
              opts :: keyword()
            ) :: {:ok, resumable_status_result()} | {:error, term()}

  @doc """
  Cancels a resumable upload session, releasing remote-side state when possible.

  Adapters expose this callback only when they advertise the
  `:resumable_upload_session` capability. Missing or expired sessions may still
  return tagged adapter errors callers treat as idempotent cleanup.
  """
  @callback cancel_resumable_upload(
              key :: String.t(),
              session_uri :: String.t(),
              opts :: keyword()
            ) :: {:ok, %{cancelled: boolean()}} | {:error, term()}

  @doc """
  Verifies resumable completion through adapter-side metadata lookup.

  Adapters expose this callback only when they advertise the
  `:resumable_upload` capability. This exists for adapter parity and storage
  protocol handling, but it does not redefine broker trust:
  `Rindle.Upload.Broker.verify_completion/2` remains `c:head/2`-based.
  """
  @callback verify_resumable_completion(
              key :: String.t(),
              session_uri :: String.t(),
              opts :: keyword()
            ) :: {:ok, head_result()} | {:error, term()}

  @doc """
  Streams one PATCH body into the adapter's resumable part store for a tus upload.

  Adapters expose this callback only when they advertise the `:tus_upload`
  capability. The tus edge (`Rindle.Upload.TusPlug`) drains the PATCH body to a
  temp file FIRST — bounded by the per-PATCH ceiling, so an oversize body is
  rejected with `413` before this callback is reached — then hands that
  `temp_path`. The temp file therefore holds exactly ONE PATCH worth of bytes;
  the adapter pulls bytes from it and never buffers the whole upload in memory.

  `base_offset` is the upload's committed offset before this PATCH (the tus
  `Upload-Offset` the client sent). `state` carries the prior
  `t:tus_part_state/0` (S3's `:upload_id` + accumulated `:parts`, or `%{offset:
  n}` for Local). Returns the updated `t:tus_part_state/0` to persist on the
  session row.

  S3 appends the temp file to a tail buffer under the sweepable `Rindle.tmp/`
  root, slicing off each full 5 MiB part as a multipart `UploadPart` and keeping
  any sub-5-MiB remainder buffered across PATCHes. Local appends the bytes to its
  per-session part file. The edge dispatches polymorphically — it never branches
  on the adapter module.
  """
  @callback upload_part_stream(
              key :: String.t(),
              temp_path :: String.t(),
              base_offset :: non_neg_integer(),
              state :: tus_part_state(),
              opts :: keyword()
            ) :: {:ok, tus_part_state()} | {:error, term()}

  @doc """
  Finalizes a tus upload after the last PATCH, converging into the trusted
  verify/promote lane.

  Adapters expose this callback only when they advertise the `:tus_upload`
  capability. It is the symmetric companion to `c:upload_part_stream/5`: the edge
  calls it once, polymorphically, after the final PATCH brings the committed
  offset to `Upload-Length` — there is no `if adapter == Local` branch.

  `temp_path` is the final PATCH's drained temp file (the last bytes of the
  upload), passed for symmetry with `c:upload_part_stream/5`; the edge has
  already appended those bytes during the matching `c:upload_part_stream/5`
  call, so `temp_path` is the residual handle the adapter may flush as the last
  part. `state` carries the accumulated `t:tus_part_state/0` (S3's `:upload_id` +
  ordered `:parts`).

  S3 flushes the remaining tail buffer as the final `UploadPart` (any size, even
  below the 5 MiB minimum, since it is the last part) and then
  `complete_multipart_upload/4` with the full ordered `parts` list from `state`.
  Local performs the atomic same-filesystem `File.rename` of its part file onto
  the final key. After this returns `{:ok, _}` the edge calls
  `Rindle.Upload.Broker.verify_completion/2`, the single `c:head/2`-based trust
  gate (unchanged), to promote the asset.
  """
  @callback complete_part_stream(
              key :: String.t(),
              temp_path :: String.t() | nil,
              state :: tus_part_state(),
              opts :: keyword()
            ) :: {:ok, map()} | {:error, term()}

  @doc """
  Returns the adapter's supported capability atoms.

  Values must come from `t:capability/0`.
  """
  @callback capabilities() :: [capability()]

  @optional_callbacks initiate_resumable_upload: 3,
                      resumable_upload_status: 3,
                      cancel_resumable_upload: 3,
                      verify_resumable_completion: 3,
                      upload_part_stream: 5,
                      complete_part_stream: 4
end
