defmodule Rindle.Repo.Migrations.AddMuxPassthroughToMediaProviderAssets do
  use Ecto.Migration

  def change do
    alter table(:media_provider_assets) do
      add :mux_passthrough, :string
    end

    create unique_index(:media_provider_assets, [:provider_name, :mux_passthrough],
             where: "mux_passthrough IS NOT NULL",
             name: :media_provider_assets_provider_name_mux_passthrough_index
           )
  end
end
