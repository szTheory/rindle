defmodule Rindle.Migration do
  @moduledoc """
  Versioned migrations for Rindle-owned database tables.

  Create a normal migration in your Phoenix or Ecto application and call
  `Rindle.Migration` from that host migration:

      defmodule MyApp.Repo.Migrations.InstallRindle do
        use Ecto.Migration

        def up, do: Rindle.Migration.up(version: 1)
        def down, do: Rindle.Migration.down(version: 1)
      end

  Rindle's migration creates and rolls back only Rindle-owned tables. Host
  applications install and own shared infrastructure such as `oban_jobs`
  separately through `Oban.Migration`.

  The default `:prefix` is `"public"`. Pass an explicit prefix only when your
  host migration and runtime configuration are prepared for that schema.
  """

  use Ecto.Migration

  alias Rindle.Migration.Options
  alias Rindle.Migration.V1

  @doc """
  Runs Rindle migrations up to the requested version.

  ## Options

    * `:version` - supported migration version. Defaults to `1`.
    * `:prefix` - Postgres schema prefix. Defaults to `"public"`.

  """
  @spec up(keyword()) :: :ok
  def up(opts \\ []) when is_list(opts) do
    opts
    |> Options.validate!()
    |> dispatch(:up)
  end

  @doc """
  Rolls Rindle migrations down for the requested version.

  This is destructive and removes only Rindle-owned tables and marker state.
  It never drops host-owned tables such as `oban_jobs`.
  """
  @spec down(keyword()) :: :ok
  def down(opts \\ []) when is_list(opts) do
    opts
    |> Options.validate!()
    |> dispatch(:down)
  end

  defp dispatch(%{version: 1} = opts, :up), do: V1.up(opts)
  defp dispatch(%{version: 1} = opts, :down), do: V1.down(opts)
end
