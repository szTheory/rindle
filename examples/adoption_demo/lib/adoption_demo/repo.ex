defmodule AdoptionDemo.Repo do
  use Ecto.Repo,
    otp_app: :adoption_demo,
    adapter: Ecto.Adapters.Postgres

  @impl true
  def init(_type, config) do
    {:ok, Keyword.merge(config, migration_primary_key: [type: :binary_id], migration_timestamps: [type: :utc_datetime_usec])}
  end
end
