# Test-only worker: load actual policy code once, but reload every request/graph.
System.put_env("RINDLE_EXACT_HEAD_LIBRARY_ONLY", "1")
Code.require_file("../maintainer/validate_exact_head_readiness.exs", __DIR__)

defmodule Rindle.ReadinessFixturePolicy do
  def run(%{"operation" => "topology"} = request) do
    case Rindle.ReadinessWorkflow.derive(request["yaml"], request["context"]) do
      {:ok, value} -> %{"ok" => true, "value" => value}
      {:error, reason} -> %{"ok" => false, "reason" => reason}
    end
  end

  def run(%{"operation" => "nightly-controls"}),
    do: %{"ok" => true, "value" => Rindle.ReadinessNightly.control_paths()}

  def run(%{"operation" => "hex"} = request),
    do: Rindle.ExactHeadReadiness.validate_hex(request["payloads"], request["locks"])

  def run(%{"operation" => "validate"} = request),
    do:
      Rindle.ExactHeadReadiness.validate_remote(
        request["id"],
        request["normalized"],
        request["inputs"]
      )
end

for line <- IO.stream(:stdio, :line) do
  response =
    case Jason.decode!(line) do
      %{"policy" => request} when is_map(request) ->
        result = Rindle.ReadinessFixturePolicy.run(request)
        %{policy: result, policy_bytes: byte_size(Jason.encode!(result)) + 1}

      argv when is_list(argv) ->
        true = Enum.all?(argv, &is_binary/1)
        result = Rindle.ExactHeadReadiness.run(argv)
        %{code: if(result == :ok, do: 0, else: 1)}
    end

  IO.puts("RINDLE_TEST_VALIDATOR_RESPONSE " <> Jason.encode!(response))
end
