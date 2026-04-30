defmodule Rindle.InstallSmoke.HexReleaseExistsTest do
  use ExUnit.Case, async: false

  @repo_root Path.expand("../..", __DIR__)
  @probe_script Path.join(@repo_root, "scripts/hex_release_exists.sh")
  @shim_factory Path.join(@repo_root, "test/install_smoke/support/fake_hex_bin.sh")

  test "published version emits already_published=true as the only stdout line" do
    {stdout, stderr, exit_code} =
      run_probe(%{
        "SHIM_MIX_EXIT" => "0",
        "SHIM_MIX_STDERR" => "mix says published",
        "SHIM_CURL_HTTP_STATUS" => "404"
      })

    assert exit_code == 0
    assert stdout == "already_published=true\n"
    assert stderr =~ "mix hex.info rindle 0.1.4 exited 0"
  end

  test "missing version emits already_published=false when mix returns 1 and curl returns 404" do
    {stdout, stderr, exit_code} =
      run_probe(%{
        "SHIM_MIX_EXIT" => "1",
        "SHIM_MIX_STDERR" => "mix says missing",
        "SHIM_CURL_HTTP_STATUS" => "404"
      })

    assert exit_code == 0
    assert stdout == "already_published=false\n"
    assert stderr =~ "mix exit 1 + curl 404"
  end

  test "curl fallback emits already_published=true when mix is inconclusive and curl returns 200" do
    {stdout, stderr, exit_code} =
      run_probe(%{
        "SHIM_MIX_EXIT" => "2",
        "SHIM_MIX_STDERR" => "mix transport failed",
        "SHIM_CURL_HTTP_STATUS" => "200"
      })

    assert exit_code == 0
    assert stdout == "already_published=true\n"
    assert stderr =~ "curl returned HTTP 200"
  end

  test "inconclusive probe fails loud when both mix and curl are inconclusive" do
    {stdout, stderr, exit_code} =
      run_probe(%{
        "SHIM_MIX_EXIT" => "2",
        "SHIM_MIX_STDERR" => "mix transport failed",
        "SHIM_CURL_EXIT" => "7",
        "SHIM_CURL_STDERR" => "curl connect failed"
      })

    assert exit_code != 0
    assert stdout == ""
    assert stderr =~ "::error::hex_release_exists: both probes inconclusive"
    assert stderr =~ "mix hex.info"
  end

  test "probe honors RINDLE_PROJECT_ROOT before invoking mix" do
    tmp_root = Path.join(System.tmp_dir!(), "hex_probe_root_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_root)
    on_exit(fn -> File.rm_rf!(tmp_root) end)

    pwd_file = Path.join(tmp_root, "mix_pwd.txt")

    {_stdout, stderr, exit_code} =
      run_probe(%{
        "RINDLE_PROJECT_ROOT" => tmp_root,
        "RINDLE_PROBE_DEBUG" => "1",
        "SHIM_MIX_EXIT" => "0",
        "SHIM_RECORD_MIX_PWD" => "1",
        "SHIM_MIX_PWD_FILE" => pwd_file
      })

    assert exit_code == 0
    assert File.read!(pwd_file) == tmp_root <> "\n"
    assert stderr =~ "hex_release_exists: cd: #{tmp_root}"
  end

  test "probe script never invokes auth-required hex commands" do
    script = File.read!(@probe_script)
    refute script =~ "hex.user"
    refute script =~ "hex.owner"
  end

  test "probe appends identical result to GITHUB_OUTPUT when set" do
    tmp_dir = Path.join(System.tmp_dir!(), "hex_probe_output_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    github_output = Path.join(tmp_dir, "github_output.txt")

    {stdout, _stderr, exit_code} =
      run_probe(%{
        "SHIM_MIX_EXIT" => "0",
        "GITHUB_OUTPUT" => github_output
      })

    assert exit_code == 0
    assert stdout == "already_published=true\n"
    assert File.read!(github_output) == "already_published=true\n"
  end

  defp run_probe(env_overrides) do
    shim_dir = Path.join(System.tmp_dir!(), "hex_probe_shim_#{System.unique_integer([:positive])}")
    File.mkdir_p!(shim_dir)
    on_exit(fn -> File.rm_rf!(shim_dir) end)

    {_, 0} = System.cmd("bash", [@shim_factory, shim_dir], cd: @repo_root)

    io_dir = Path.join(System.tmp_dir!(), "hex_probe_io_#{System.unique_integer([:positive])}")
    File.mkdir_p!(io_dir)
    on_exit(fn -> File.rm_rf!(io_dir) end)

    stdout_path = Path.join(io_dir, "stdout.txt")
    stderr_path = Path.join(io_dir, "stderr.txt")

    env =
      [
        {"MIX_ENV", "test"},
        {"PATH", shim_dir <> ":" <> System.get_env("PATH", "")},
        {"RINDLE_PROJECT_ROOT", @repo_root},
        {"VERSION", "0.1.4"}
      ] ++ Enum.to_list(env_overrides)

    {_, exit_code} =
      System.cmd(
        "bash",
        ["-c", "$0 > \"$1\" 2> \"$2\"", @probe_script, stdout_path, stderr_path],
        cd: @repo_root,
        env: env
      )

    stdout = read_optional(stdout_path)
    stderr = read_optional(stderr_path)
    {stdout, stderr, exit_code}
  end

  defp read_optional(path) do
    if File.exists?(path), do: File.read!(path), else: ""
  end
end
