# Keep the contributor-facing Elixir entrypoint aligned with the shared receipt contract.
root = Path.expand("../..", __DIR__)

args =
  case System.argv() do
    ["--" | rest] -> rest
    rest -> rest
  end

{output, status} =
  System.cmd(
    "python3",
    [Path.join(root, "scripts/maintainer/phase136_evidence.py"), "coverage", root | args],
    stderr_to_stdout: true
  )

IO.binwrite(output)
System.halt(status)
