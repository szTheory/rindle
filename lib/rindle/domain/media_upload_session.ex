defmodule Rindle.Domain.MediaUploadSession do
  @moduledoc """
  Ecto schema for a direct upload session.

  A `MediaUploadSession` tracks the lifecycle of a direct-to-storage
  upload — from the moment Rindle issues a presigned PUT URL through
  verification of the uploaded object.

  ## States

  | State | Meaning |
  |-------|---------|
  | `"initialized"` | Session created; no presigned URL yet. |
  | `"signed"` | Presigned PUT URL issued to client. |
  | `"uploading"` | Client has begun (or is presumed to have begun) the PUT. |
  | `"uploaded"` | Storage reports the object exists at the expected key. |
  | `"verifying"` | Server-side validation (MIME, size) in progress. |
  | `"completed"` | Verification passed; asset promoted. |
  | `"aborted"` | Client cancelled or server rejected. |
  | `"expired"` | TTL elapsed before completion. |
  | `"failed"` | Verification failed (MIME mismatch, size limit, scanner). |

  See the state table below for the supported transitions and
  `Rindle.Upload.Broker` for the lifecycle entry points.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @states [
    "initialized",
    "signed",
    "uploading",
    "uploaded",
    "verifying",
    "completed",
    "aborted",
    "expired",
    "failed"
  ]

  @type t :: %__MODULE__{}

  schema "media_upload_sessions" do
    field :state, :string, default: "initialized"
    field :upload_key, :string
    field :upload_strategy, :string, default: "presigned_put"
    field :multipart_upload_id, :string
    field :multipart_parts, :map, default: %{}
    field :session_uri, :string
    field :session_uri_expires_at, :utc_datetime_usec
    field :last_known_offset, :integer, default: 0
    field :region_hint, :string
    field :expires_at, :utc_datetime_usec
    field :verified_at, :utc_datetime_usec
    field :failure_reason, :string

    belongs_to :asset, Rindle.Domain.MediaAsset

    timestamps()
  end

  @doc """
  Builds a changeset for an upload-session row.

  Casts the lifecycle, multipart, and verification columns; requires the
  minimum invariants (`:asset_id`, `:state`, `:upload_key`, `:upload_strategy`,
  `:expires_at`); validates the lifecycle state against the canonical state
  list.
  """
  @spec changeset(t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(upload_session, attrs) do
    upload_session
    |> cast(attrs, [
      :asset_id,
      :state,
      :upload_key,
      :upload_strategy,
      :multipart_upload_id,
      :multipart_parts,
      :session_uri,
      :session_uri_expires_at,
      :last_known_offset,
      :region_hint,
      :expires_at,
      :verified_at,
      :failure_reason
    ])
    |> validate_required([:asset_id, :state, :upload_key, :upload_strategy, :expires_at])
    |> validate_inclusion(:state, @states)
    |> foreign_key_constraint(:asset_id)
  end

  @spec redact_session_uri(nil | String.t()) :: nil | String.t()
  def redact_session_uri(nil), do: nil
  def redact_session_uri(session_uri) when is_binary(session_uri), do: "[REDACTED]"
  def redact_session_uri(_session_uri), do: "[REDACTED]"
end

defimpl Inspect, for: Rindle.Domain.MediaUploadSession do
  def inspect(session, opts) do
    redacted = %{
      session
      | session_uri: Rindle.Domain.MediaUploadSession.redact_session_uri(session.session_uri)
    }

    Inspect.Any.inspect(redacted, opts)
  end
end
