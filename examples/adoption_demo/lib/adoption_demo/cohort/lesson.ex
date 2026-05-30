defmodule AdoptionDemo.Cohort.Lesson do
  @moduledoc false
  use Ecto.Schema

  alias AdoptionDemo.Cohort.Course

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "lessons" do
    field :title, :string
    field :position, :integer, default: 1

    belongs_to :course, Course, type: :binary_id

    timestamps(type: :utc_datetime_usec)
  end
end
