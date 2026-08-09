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

  The default `:prefix` is `"rindle"`. Pass `prefix: "public"` only for the
  documented compatibility pairing with a public-compiled runtime.
  """

  use Ecto.Migration

  alias Rindle.Migration.Options
  alias Rindle.Migration.V1

  @doc """
  Runs Rindle migrations up to the requested version.

  ## Options

    * `:version` - supported migration version. Defaults to `1`.
    * `:prefix` - Postgres schema prefix. Defaults to `"rindle"`; only
      `"rindle"` and `"public"` are supported.

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

  @doc """
  Moves the fixed V1 Rindle relation set from `public` to `rindle`.

  Call this only from an adopter-owned Ecto migration after preparing a
  maintenance window. The operation preflights the complete Rindle-owned
  state before it mutates anything and never touches host relations such as
  `oban_jobs` or `schema_migrations`.

  ## Options

    * `:version` - required pinned migration version; only `1` is supported.

  """
  @spec move_public_to_rindle(keyword()) :: :ok
  def move_public_to_rindle(opts \\ []) when is_list(opts) do
    opts
    |> validate_directional_move!(:move_public_to_rindle)
    |> V1.move_public_to_rindle()
  end

  @doc """
  Moves the fixed V1 Rindle relation set from `rindle` back to `public`.

  Use only from a quiesced host migration down path while state is exactly
  reversible. It never drops the `rindle` schema and is distinct from the
  destructive `down/1` teardown.

  ## Options

    * `:version` - required pinned migration version; only `1` is supported.
  """
  @spec move_rindle_to_public(keyword()) :: :ok
  def move_rindle_to_public(opts \\ []) when is_list(opts) do
    opts
    |> validate_directional_move!(:move_rindle_to_public)
    |> V1.move_rindle_to_public()
  end

  defp dispatch(%{version: 1} = opts, :up), do: V1.up(opts)
  defp dispatch(%{version: 1} = opts, :down), do: V1.down(opts)

  defp validate_directional_move!(opts, function) do
    case opts do
      [version: 1] ->
        %{version: 1}

      [] ->
        raise ArgumentError, "#{function}/1 requires version: 1"

      _ ->
        raise ArgumentError,
              "#{function}/1 accepts only version: 1; :prefix, :from, and :to are not supported"
    end
  end
end
