{:defmodule, _, [_name, [do: {:__block__, _, statements}]]} =
  "test/install_smoke/evidence_census_test.exs" |> File.read!() |> Code.string_to_quoted!()
{:defp, meta, args} = Enum.find(statements, fn
  {:defp, _, [{:run_script, _, _}, _]} -> true
  _ -> false
end)
Code.compile_quoted(quote do
  defmodule CensusScopeProbe do
    @repo_root unquote(File.cwd!())
    unquote({:def, meta, args})
  end
end)
values = fn ->
  %{flags: System.get_env("ERL_FLAGS"), normal: System.schedulers_online(),
    dirty_cpu: :erlang.system_info(:dirty_cpu_schedulers_online),
    dirty_io: :erlang.system_info(:dirty_io_schedulers)}
end
parent_before = values.()
script = Path.join(System.tmp_dir!(), "census-scope-#{System.unique_integer([:positive])}.exs")
try do
  File.write!(script, ~S"""
  IO.puts(Jason.encode!(%{flags: System.get_env("ERL_FLAGS"), normal: System.schedulers_online(),
    dirty_cpu: :erlang.system_info(:dirty_cpu_schedulers_online),
    dirty_io: :erlang.system_info(:dirty_io_schedulers)}))
  """)
  {output, status} = CensusScopeProbe.run_script(script, [])
  0 = status
  child = output |> String.split("\n", trim: true) |> List.last() |> Jason.decode!()
  parent_after = values.()
  true = parent_after == parent_before
  IO.puts("CENSUS_SCOPED_PROBE " <> Jason.encode!(%{parent_before: parent_before,
    child: child, parent_after: parent_after}))
after
  File.rm!(script)
end
