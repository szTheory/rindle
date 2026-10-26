# Test-only worker: load the actual validator once, but reload every evidence graph.
System.put_env("RINDLE_EXACT_HEAD_LIBRARY_ONLY", "1")
Code.require_file("../maintainer/validate_exact_head_readiness.exs", __DIR__)

for line <- IO.stream(:stdio, :line) do
  argv = Jason.decode!(line)
  true = is_list(argv) and Enum.all?(argv, &is_binary/1)
  result = Rindle.ExactHeadReadiness.run(argv)
  code = if result == :ok, do: 0, else: 1
  IO.puts("RINDLE_TEST_VALIDATOR_RESPONSE " <> Jason.encode!(%{code: code}))
end
