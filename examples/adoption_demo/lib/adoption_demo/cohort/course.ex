defmodule AdoptionDemo.Cohort.Course do
  @moduledoc false
  use Ecto.Schema

  alias AdoptionDemo.Accounts.Member
  alias AdoptionDemo.Cohort.Lesson

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "courses" do
    field :title, :string
    field :slug, :string

    belongs_to :instructor, Member, type: :binary_id
    has_many :lessons, Lesson

    timestamps(type: :utc_datetime_usec)
  end
end
