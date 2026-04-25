defmodule Rindle.Repo.Migrations.AddMetadataToMediaVariants do
  use Ecto.Migration

  def change do
    alter table(:media_variants) do
      add :byte_size, :bigint
      add :content_type, :string
    end
  end
end
