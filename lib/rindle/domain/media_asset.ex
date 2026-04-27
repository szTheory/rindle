defmodule Rindle.Domain.MediaAsset do
  @moduledoc """
  Ecto schema for a media asset.

  A `MediaAsset` represents a single uploaded file moving through the
  `Rindle.Domain.AssetFSM` lifecycle. Each row tracks the asset's current
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

  See `Rindle.Domain.AssetFSM` for valid state transitions.
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
    "ready",
    "degraded",
    "quarantined",
    "deleted"
  ]

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

    has_many :attachments, Rindle.Domain.MediaAttachment, foreign_key: :asset_id
    has_many :variants, Rindle.Domain.MediaVariant, foreign_key: :asset_id
    has_many :upload_sessions, Rindle.Domain.MediaUploadSession, foreign_key: :asset_id
    has_many :processing_runs, Rindle.Domain.MediaProcessingRun, foreign_key: :asset_id

    timestamps()
  end

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
      :profile
    ])
    |> validate_required([:state, :storage_key, :profile])
    |> validate_inclusion(:state, @states)
    |> unique_constraint(:storage_key)
  end
end
