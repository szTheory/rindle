defmodule Rindle.Repo.Migrations.AddProviderUploadIdToMediaProviderAssets do
  use Ecto.Migration

  def change do
    alter table(:media_provider_assets) do
      add :provider_upload_id, :string
    end

    create unique_index(:media_provider_assets, [:provider_name, :provider_upload_id],
             where: "provider_upload_id IS NOT NULL",
             name: :media_provider_assets_provider_name_provider_upload_id_index
           )
  end
end
