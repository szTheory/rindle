defmodule AdoptionDemo.Repo.Migrations.CreateCohortDomain do
  use Ecto.Migration

  def change do
    rename table(:users), to: table(:members)

    alter table(:members) do
      add :role, :string, null: false, default: "student"
    end

    create table(:courses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :slug, :string, null: false
      add :instructor_id, references(:members, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:courses, [:slug])

    create table(:lessons, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :position, :integer, null: false, default: 1
      add :course_id, references(:courses, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:lessons, [:course_id])

    create table(:posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :body, :text, null: false
      add :member_id, references(:members, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:posts, [:member_id])
  end
end
