{:ok, _} = Rindle.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(Rindle.Repo, :manual)

case ExMarcel.TableWrapper.start_link([]) do
  {:ok, _pid} -> :ok
  {:error, {:already_started, _pid}} -> :ok
end

case Rindle.Adopter.CanonicalApp.Repo.start_link() do
  {:ok, _pid} -> :ok
  {:error, {:already_started, _pid}} -> :ok
end

Ecto.Adapters.SQL.Sandbox.mode(Rindle.Adopter.CanonicalApp.Repo, :manual)
{:ok, _} = Oban.start_link(repo: Rindle.Repo, queues: false, testing: :manual)

targeted_adopter_or_integration? =
  System.argv()
  |> Enum.any?(fn arg ->
    String.contains?(arg, "test/adopter/") or
      String.ends_with?(arg, "lifecycle_integration_test.exs")
  end)

exclude_tags =
  if targeted_adopter_or_integration? do
    [:minio, :contract]
  else
    [:integration, :minio, :contract, :adopter]
  end

# Only emit JUnit XML in CI to keep local runs quiet (CI sets the CI env var).
formatters =
  if System.get_env("CI") do
    [ExUnit.CLIFormatter, JUnitFormatter]
  else
    [ExUnit.CLIFormatter]
  end

# Deterministic, upload-friendly report location.
junit_report_dir = "_build/test/junit"
Application.put_env(:junit_formatter, :report_dir, junit_report_dir)
Application.put_env(:junit_formatter, :report_file, "rindle-junit.xml")
Application.put_env(:junit_formatter, :print_report_file, true)
Application.put_env(:junit_formatter, :include_filename?, true)

# junit_formatter does not create its report_dir; ensure it exists before writing (CI only).
if System.get_env("CI"), do: File.mkdir_p!(junit_report_dir)

ExUnit.start(exclude: exclude_tags, formatters: formatters)

unless Code.ensure_loaded?(Rindle.StorageMock) do
  Code.require_file("support/mocks.ex", __DIR__)
end
