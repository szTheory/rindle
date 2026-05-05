defmodule Rindle.Application do
  @moduledoc false

  use Application

  alias Rindle.Config
  alias Rindle.Processor.AV.RuntimeGuard

  @impl true
  def start(_type, _args) do
    run_startup_checks()

    children = [
      ExMarcel.TableWrapper
    ]

    opts = [strategy: :one_for_one, name: Rindle.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc false
  def run_startup_checks(opts \\ []) do
    logger = Keyword.get(opts, :logger)

    Config.profile_modules()
    |> Enum.map(fn module -> %{name: module, variants: module.variants()} end)
    |> runtime_guard_warn(logger)
  end

  defp runtime_guard_warn(profiles, nil), do: RuntimeGuard.warn_unsupported_runtime(profiles)

  defp runtime_guard_warn(profiles, logger),
    do: RuntimeGuard.warn_unsupported_runtime(profiles, logger: logger)
end
