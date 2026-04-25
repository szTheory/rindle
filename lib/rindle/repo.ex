defmodule Rindle.Repo do
  use Ecto.Repo,
    otp_app: :rindle,
    adapter: Ecto.Adapters.Postgres
end
