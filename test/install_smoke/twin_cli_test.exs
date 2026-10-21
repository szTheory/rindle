defmodule Rindle.TwinCliTest do
  use ExUnit.Case, async: true
  @root Path.expand("../..", __DIR__)
  @script "scripts/maintainer/built_package_twin.py"
  test "single entrypoint documents explicit authorities and all four operations" do
    assert {help, 0} =
             System.cmd("python3", ["-B", @script, "--help"], cd: @root, stderr_to_stdout: true)

    for name <- ~w(check run verify cleanup), do: assert(help =~ name)

    assert {_, 2} =
             System.cmd("python3", ["-B", @script, "verify"], cd: @root, stderr_to_stdout: true)

    assert {output, 1} =
             System.cmd(
               "python3",
               [
                 "-B",
                 @script,
                 "verify",
                 "--inputs",
                 "/missing/inputs",
                 "--receipt",
                 "/missing/receipt",
                 "--json"
               ],
               cd: @root,
               stderr_to_stdout: true
             )

    result = Jason.decode!(output)
    assert result["outcome"] == "failed"
    assert result["independent_pilot_credit"] == false
    assert result["kind"] == "maintainer-operated-synthetic"
  end

  @tag :tmp_dir
  test "missing Docker is nonzero labeled JSON without raw child output", %{tmp_dir: dir} do
    fake = Path.join(dir, "docker")
    File.write!(fake, "#!/bin/sh\nprintf 'SECRET_CANARY\\n'\nexit 1\n")
    File.chmod!(fake, 0o700)

    assert {output, 1} =
             System.cmd("python3", ["-B", @script, "check", "--json"],
               cd: @root,
               env: [{"PATH", dir}],
               stderr_to_stdout: true
             )

    result = Jason.decode!(output)
    assert result["outcome"] == "blocked"
    assert result["stage"] == "initialization"
    refute output =~ "SECRET_CANARY"
  end

  test "runtime source guard rejects private and manual ingress" do
    code = """
    import sys
    sys.path.insert(0,'scripts/maintainer')
    from built_package_twin import validate_host_surface,Refused
    validate_host_surface('Rindle.ready_variants_for(id); Repo.get(Rindle.Domain.MediaAsset,id)')
    for s in ['Rindle.Workers.PurgeStorage.perform(job)', 'Rindle.Config.repo()', 'Oban.Testing.perform_job(x)', 'Repo.update!(asset)', 'File.read!("/checkout/lib/rindle.ex")', 'testing: :inline', ':beam_lib.chunks(file,[])']:
        try:validate_host_surface(s)
        except Refused:pass
        else:raise AssertionError('unsupported ingress accepted')
    """

    assert {_, 0} = System.cmd("python3", ["-B", "-c", code], cd: @root, stderr_to_stdout: true)
  end
end
