defmodule CensusPilotFormatter do
  use GenServer
  def init(_options), do: {:ok, []}
  def handle_cast({:test_finished, test}, tests) do
    row = %{name: test.name, module: test.module, line: test.tags[:line],
      time_us: test.time, state: if(test.state == nil, do: "passed", else: "failed")}
    {:noreply, [row | tests]}
  end
  def handle_cast({:suite_finished, _timing}, tests) do
    File.write!(System.fetch_env!("CENSUS_PILOT_RECORD"), Jason.encode!(Enum.reverse(tests)))
    {:noreply, tests}
  end
  def handle_cast(_event, tests), do: {:noreply, tests}
end
ExUnit.start(seed: 173, max_cases: 8, formatters: [CensusPilotFormatter])
Code.require_file("test/install_smoke/evidence_census_test.exs")
