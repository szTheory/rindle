defmodule Rindle.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :rindle,
    adapter: Ecto.Adapters.Postgres
end
