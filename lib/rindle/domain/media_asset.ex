defmodule Rindle.Domain.MediaAsset do
  @moduledoc """
  Ecto schema for a media asset.

  A `MediaAsset` represents a single uploaded file moving through the
  asset lifecycle. Each row tracks the asset's current
  state, MIME type, byte size, and the storage key under which the
  original file is stored.

  ## States

  | State | Meaning |
  |-------|---------|
  | `"staged"` | Reserved slot; upload has not been verified. |
  | `"validating"` | Upload verified; MIME scan in progress. |
  | `"analyzing"` | Dimensions / metadata extraction in progress. |
  | `"promoting"` | Promotion job running. |
  | `"available"` | Ready for variant processing and delivery. |
  | `"processing"` | One or more variant jobs running. |
  | `"ready"` | All configured variants generated. |
  | `"degraded"` | One or more variants failed; original still deliverable. |
  | `"quarantined"` | MIME mismatch or scan failure; not deliverable. |
  | `"deleted"` | Soft-deleted; storage object may already be purged. |

  See the state table below for the supported lifecycle transitions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @states [
    "staged",
    "validating",
    "analyzing",
    "promoting",
    "available",
    "processing",
    "transcoding",
    "ready",
    "degraded",
    "quarantined",
    "deleted"
  ]

  @kinds ~w(image video audio)

  @kind_field_invariants %{
    "image" => [:duration_ms, :has_video_track, :has_audio_track],
    "video" => [],
    "audio" => [:width, :height, :has_video_track]
  }

  @type t :: %__MODULE__{}

  schema "media_assets" do
    field :state, :string, default: "staged"
    field :storage_key, :string
    field :content_type, :string
    field :byte_size, :integer
    field :filename, :string
    field :metadata, :map, default: %{}
    field :recipe_digest, :string
    field :profile, :string
    field :kind, :string, default: "image"
    field :width, :integer
    field :height, :integer
    field :duration_ms, :integer
    field :has_video_track, :boolean
    field :has_audio_track, :boolean
    field :error_reason, :string

    has_many :attachments, Rindle.Domain.MediaAttachment, foreign_key: :asset_id
    has_many :variants, Rindle.Domain.MediaVariant, foreign_key: :asset_id
    has_many :upload_sessions, Rindle.Domain.MediaUploadSession, foreign_key: :asset_id
    has_many :processing_runs, Rindle.Domain.MediaProcessingRun, foreign_key: :asset_id

    timestamps()
  end

  @doc """
  Builds a changeset for an asset row.

  Casts the writable lifecycle and storage fields, requires the minimum
  promotion-time invariants (`:state`, `:storage_key`, `:profile`), and
  validates the lifecycle state against the canonical state list.
  """
  @spec changeset(t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(asset, attrs) do
    asset
    |> cast(attrs, [
      :state,
      :storage_key,
      :content_type,
      :byte_size,
      :filename,
      :metadata,
      :recipe_digest,
      :profile,
      :kind,
      :width,
      :height,
      :duration_ms,
      :has_video_track,
      :has_audio_track,
      :error_reason
    ])
    |> validate_required([:state, :storage_key, :profile, :kind])
    |> validate_inclusion(:state, @states)
    |> validate_inclusion(:kind, @kinds)
    |> validate_kind_field_consistency()
    |> unique_constraint(:storage_key)
  end

  defp validate_kind_field_consistency(changeset) do
    case get_field(changeset, :kind) do
      nil ->
        changeset

      kind ->
        forbidden = Map.get(@kind_field_invariants, kind, [])
        validate_forbidden_fields(changeset, kind, forbidden)
    end
  end

  defp validate_forbidden_fields(changeset, kind, forbidden) do
    Enum.reduce(forbidden, changeset, fn field, acc ->
      case get_field(acc, field) do
        nil ->
          acc

        _value ->
          add_error(acc, field, "must be nil for kind=#{kind} (probe column not applicable)",
            kind: kind,
            field: field
          )
      end
    end)
  end
end
