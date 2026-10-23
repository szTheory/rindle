defmodule Twin.Repo do
  use Ecto.Repo, otp_app: :twin, adapter: Ecto.Adapters.Postgres
end
