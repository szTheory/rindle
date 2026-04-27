defmodule Rindle.Domain.MediaProcessingRun do
  @moduledoc """
  Ecto schema recording the outcome of a single processing or maintenance
  operation against a media asset or variant.

  A `MediaProcessingRun` is the audit trail for background work — variant
  generation outcomes, purge results, scanner verdicts, and metadata
  backfill runs. Each row captures the worker module, the affected
  record, the outcome (`:queued`, `:processing`, `:succeeded`, `:failed`),
  and any structured detail emitted by the operation.

  Processing runs are not consulted for delivery decisions; they exist
  for operator visibility, retry diagnostics, and Day-2 cleanup queries.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @states ["queued", "processing", "succeeded", "failed"]

  @type t :: %__MODULE__{}

  schema "media_processing_runs" do
    field :variant_name, :string
    field :worker, :string
    field :state, :string
    field :attempt, :integer, default: 1
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec
    field :error_reason, :string

    belongs_to :asset, Rindle.Domain.MediaAsset

    timestamps()
  end

  @spec changeset(t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(processing_run, attrs) do
    processing_run
    |> cast(attrs, [:asset_id, :variant_name, :worker, :state, :attempt, :started_at, :finished_at, :error_reason])
    |> validate_required([:asset_id, :variant_name, :worker, :state, :attempt])
    |> validate_inclusion(:state, @states)
    |> validate_number(:attempt, greater_than_or_equal_to: 1)
    |> foreign_key_constraint(:asset_id)
  end
end
