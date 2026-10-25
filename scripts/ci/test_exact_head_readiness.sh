#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/rindle-readiness-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
export RINDLE_READINESS_TEST_ROOT="$tmp"
export RINDLE_EXACT_HEAD_LIBRARY_ONLY=1
export ASDF_ERLANG_VERSION="${ASDF_ERLANG_VERSION:-27.3.4.15}"
export ASDF_ELIXIR_VERSION="${ASDF_ELIXIR_VERSION:-1.17.3-otp-27}"
export ASDF_NODEJS_VERSION="${ASDF_NODEJS_VERSION:-20.18.1}"
cat > "$tmp/test.exs" <<'EX'
Code.require_file("scripts/maintainer/validate_exact_head_readiness.exs")
ExUnit.start(seed: 0)

Code.require_file("scripts/ci/readiness_fixture.exs")
Code.require_file("scripts/ci/test_readiness_hex_audit.exs")

defmodule ReadinessPolicyTest do
  use ExUnit.Case, async: false
  alias Rindle.ExactHeadReadiness, as: V
  alias ReadinessFixture, as: F

  test "reviewed Hex versions retain every immutable security and lock gate" do
    locks = Map.new([{"root", "mix.lock"}, {"examples/adoption_demo", "examples/adoption_demo/mix.lock"}], fn {scope, path} -> {scope, File.read!(path)} end)
    for version <- ["2.5.1", "2.6.0"] do
      payloads = Enum.map(F.hex_payloads(), &Map.put(&1, "hex_version", version))
      assert V.validate_hex(payloads, locks) == %{"ok" => true}
      for {field, value} <- [{"online", false}, {"https_verified", false}, {"registry_signature_verification", false}, {"lock_sha256", String.duplicate("0", 64)}, {"packages", []}, {"database", []}] do
        [first | rest] = payloads
        assert V.validate_hex([Map.put(first, field, value) | rest], locks)["ok"] == false
      end
      [first | rest] = payloads
      retired = update_in(first, ["packages"], fn [p | ps] -> [Map.put(p, "retired", true) | ps] end)
      refute V.validate_hex([retired | rest], locks)["ok"]
    end
    for version <- ["2.5.0", "2.6.1", "2.6.0-dev", "3.0.0", nil] do
      payloads = Enum.map(F.hex_payloads(), &Map.put(&1, "hex_version", version))
      refute V.validate_hex(payloads, locks)["ok"]
    end
  end

  test "complete immutable fixture passes through actual CLI and writes scope without requirement credit" do
    {root, m} = F.fixture()
    F.put(root, "manifest.json", m)
    {output, status} = System.cmd("mix", ["run", "--no-start", "scripts/maintainer/validate_exact_head_readiness.exs", "--manifest", Path.join(root, "manifest.json"), "--root", root, "--verdict", Path.join(root, "verdict.json")], env: [{"RINDLE_EXACT_HEAD_LIBRARY_ONLY", nil}], stderr_to_stdout: true)
    assert status == 0, output
    verdict = root |> Path.join("verdict.json") |> File.read!() |> Jason.decode!()
    assert verdict["verdict"] == "ready"
    assert verdict["evidence_scope"] == "fixture"
    refute verdict["requirements_credit"]
  end

  for {name, path, value, reason} <- [
    {"unfinished", ["state"], "running", "unfinished_attempt"},
    {"unknown schema", ["schema_version"], 2, "schema"},
    {"main changed", ["remote_main_after"], String.duplicate("b", 40), "main_changed"},
    {"short SHA", ["subject_sha"], "abc", "subject"},
    {"bad repo", ["repository"], "foreign", "repository"},
    {"foreign tool", ["validator_sha256"], String.duplicate("0", 64), "tool_identity"},
    {"unsupported toolchain", ["toolchain", "otp"], "28", "toolchain"},
    {"unknown policy", ["policy"], "v0", "policy"},
    {"independent credit", ["adoption", "independent_pilot_credit"], true, "adoption_inflation"},
    {"pilot closed", ["adoption", "pilot_01"], "complete", "adoption_inflation"},
    {"1.0 authority", ["adoption", "one_point_zero_authority"], true, "adoption_inflation"},
    {"cleanup unobserved", ["cleanup", "state"], "called", "cleanup_unobserved"}
  ] do
    test "rejects #{name}" do
      {root, m} = F.fixture()
      context = F.context(root, m)
      m = put_in(m, unquote(path), unquote(value))
      assert [%{"id" => unquote(reason)}] = V.validate_contract(m, context)["reasons"]
    end
  end

  for {name, mutate} <- [
    {"missing", :missing}, {"duplicate", :duplicate}, {"unknown", :unknown}, {"null", :null}, {"single", :single}
  ] do
    test "rejects #{name} proof inventory" do
      {root, m} = F.fixture()
      refs = case unquote(mutate) do
        :missing -> tl(m["proofs"])
        :duplicate -> m["proofs"] ++ [hd(m["proofs"])]
        :unknown -> [Map.put(hd(m["proofs"]), "id", "unknown") | tl(m["proofs"])]
        :null -> nil
        :single -> [hd(m["proofs"])]
      end
      assert V.validate_contract(Map.put(m, "proofs", refs), F.context(root, m))["verdict"] == "not_ready"
    end
  end

  for {name, path, value} <- [
    {"wrong receipt SHA", ["subject_sha"], String.duplicate("b", 40)},
    {"wrong receipt repo", ["repository"], "another/repo"},
    {"wrong package", ["package_identity", "package_tar_sha256"], String.duplicate("f", 64)},
    {"skipped green", ["outcome"], "skipped"},
    {"timeout", ["command", "state"], "timeout"},
    {"forged success", ["command", "exit_code"], 1},
    {"unregistered command", ["command", "argv"], ["true"]},
    {"missing tool input", ["tool_identity"], %{}},
    {"stale observation", ["observation_interval", "started_at"], "2026-10-21T00:00:00Z"}
  ] do
    test "rejects #{name}" do
      {root, m} = F.fixture()
      m = F.change(root, m, "format", &put_in(&1, unquote(path), unquote(Macro.escape(value))))
      assert V.validate_contract(m, F.context(root, m))["verdict"] == "not_ready"
    end
  end

  test "rejects corruption and unapproved residue" do
    {root, m} = F.fixture()
    File.write!(Path.join(root, "logs/format.txt"), "corrupt")
    assert V.validate_contract(m, F.context(root, m))["verdict"] == "not_ready"
    {root, m} = F.fixture()
    m = update_in(m, ["cleanup", "inventories"], fn [first | rest] -> [Map.put(first, "after", ["unowned"]) | rest] end)
    assert [%{"id" => "residue_present"}] = V.validate_contract(m, F.context(root, m))["reasons"]
  end

  test "valid refresh binds original and all five new immutable receipts" do
    {root, m} = F.fixture()
    e = F.refresh(root, m)
    assert V.validate_contract(m, F.context(root, m, e))["verdict"] == "ready"
    for e <- [Map.put(e, "manifest_sha256", String.duplicate("f", 64)), Map.put(e, "subject_sha", String.duplicate("b", 40)), Map.put(e, "proofs", tl(e["proofs"])), Map.delete(e, "adoption"), Map.put(e, "policy", "foreign"), Map.put(e, "validator_sha256", String.duplicate("f", 64)), Map.put(e, "observation_interval", F.interval()), Map.put(e, "verdict", "not_ready")] do
      assert V.validate_contract(m, F.context(root, m, e))["verdict"] == "not_ready"
    end
    File.write!(Path.join(root, "refresh/protection.json"), "corrupt")
    assert V.validate_contract(m, F.context(root, m, e))["verdict"] == "not_ready"
  end

  for {name, path, value} <- [
    {"wrong event", ["event"], "pull_request"}, {"wrong workflow", ["workflow"], "other.yml"},
    {"partial rerun", ["jobs"], []}, {"changed attempt", ["rechecked_attempt"], 3},
    {"newer run", ["latest_run_id"], 11}, {"pending run", ["state"], "in_progress"},
    {"unknown topology", ["topology_resolved"], false}
  ] do
    test "rejects #{name}" do
      {root, m} = F.fixture()
      m = F.change(root, m, "ci-main", &put_in(&1, ["source", "normalized"] ++ unquote(path), unquote(Macro.escape(value))))
      assert V.validate_contract(m, F.context(root, m))["verdict"] == "not_ready"
    end
  end

  test "a help-only command cannot earn a gate result" do
    {root, m} = F.fixture()
    m = F.change(root, m, "format", &update_in(&1, ["command", "argv"], fn argv -> argv ++ ["--help"] end))
    assert V.validate_contract(m, F.context(root, m))["verdict"] == "not_ready"
  end

  test "tracked changes cannot be declared tool caches" do
    {root, m} = F.fixture()
    m = update_in(m, ["cleanup", "inventories"], fn [first | rest] ->
      [Map.merge(first, %{"after" => ["mix.exs"], "allowed" => [%{"path" => "mix.exs", "class" => "tool_cache", "reason" => "arbitrary declaration"}]}) | rest]
    end)
    assert V.validate_contract(m, F.context(root, m))["verdict"] == "not_ready"
  end

  test "source observations need their own invocation interval" do
    {root, m} = F.fixture()
    m = F.change(root, m, "ci-main", &put_in(&1, ["source", "observation_interval"], F.interval(10)))
    assert V.validate_contract(m, F.context(root, m))["verdict"] == "not_ready"
  end

  for {id, path, value, reason} <- [
    {"ci-main", ["event"], "pull_request", "workflow_identity"},
    {"nightly-scheduled", ["event"], "workflow_dispatch", "workflow_identity"},
    {"ci-main", ["jobs"], [], "job_inventory"},
    {"ci-main", ["rechecked_attempt"], 3, "attempt_changed"},
    {"ci-main", ["latest_run_id"], 11, "attempt_changed"},
    {"ci-main", ["topology_resolved"], false, "unknown_topology"},
    {"protection", ["classic_visible"], false, "protection_unavailable"},
    {"protection", ["organization_visible"], false, "protection_unavailable"},
    {"protection", ["effective_checks"], [], "protection_drift"},
    {"protection", ["bypass_actors"], ["unexpected"], "protection_drift"},
    {"remote-inventory", ["sources", "advisories", "authorized"], false, "remote_inventory"},
    {"remote-inventory", ["sources", "dependabot", "changed"], true, "remote_inventory"},
    {"remote-inventory", ["sources", "hex", "database_sha256"], nil, "hex_identity"},
    {"adoption-parity", ["adoption", "pilot_02"], "complete", "adoption_inflation"},
    {"adoption-parity", ["authoritative_inputs", "mix.exs"], String.duplicate("0", 64), "adoption_authority"},
    {"adoption-parity", ["adoption_policy"], "foreign", "adoption_authority"}
  ] do
    test "bound source policy rejects #{id} #{inspect(path)}" do
      {root, m} = F.fixture()
      m = F.change_source(root, m, unquote(id), &put_in(&1, unquote(path), unquote(Macro.escape(value))))
      assert [%{"id" => unquote(reason)}] = V.validate_contract(m, F.context(root, m))["reasons"]
    end
  end

  test "actual runtime bytes cannot be replaced by declared supported versions" do
    for {name, bytes} <- [{"elixir", "1.18.0\n28.0\n"}, {"node", "v22.0.0\n"}] do
      {root, m} = F.fixture()
      ref = F.put(root, "runtime/#{name}.txt", bytes)
      m = put_in(m, ["runtime_evidence", name], ref)
      assert [%{"id" => "tool_identity"}] = V.validate_contract(m, F.context(root, m))["reasons"]
    end
  end

  test "extracted baseline landing source is a required byte-bound policy input" do
    {root, m} = F.fixture()
    path = "scripts/maintainer/land_release_train_baseline.py"
    assert path in V.input_paths()
    assert m["input_identity"][path] == V.sha256(File.read!(path))
    m = put_in(m, ["input_identity", path], String.duplicate("0", 64))
    assert [%{"id" => "tool_identity", "detail" => "baseline landing evaluator differs"}] =
      V.validate_contract(m, F.context(root, m))["reasons"]
  end

  test "CLI rejects duplicate JSON keys before choosing any claimed state" do
    {root, m} = F.fixture()
    bytes = Jason.encode!(m)
    File.write!(Path.join(root, "manifest.json"), String.replace_prefix(bytes, "{", "{\"state\":\"running\","))
    assert {:error, verdict} = V.run(["--manifest", Path.join(root, "manifest.json"), "--root", root, "--verdict", Path.join(root, "verdict.json")])
    assert [%{"id" => "duplicate_json_key"}] = verdict["reasons"]
  end

  test "opaque policy JSON is data rather than a receipt graph edge" do
    {root, m} = F.fixture()
    path = "config/ci_required_checks.json"
    ref = F.put(root, "inputs/#{path}", %{"path" => "/foreign/data", "sha256" => String.duplicate("f", 64)})
    m = put_in(m, ["input_files", path], ref)
    m = put_in(m, ["input_identity", path], ref["sha256"])
    m = Enum.reduce(V.required_proofs(), m, fn id, current ->
      F.change(root, current, id, &Map.put(&1, "input_identity", m["input_identity"]))
    end)
    F.put(root, "manifest.json", m)
    assert :ok = V.run(["--manifest", Path.join(root, "manifest.json"), "--root", root, "--verdict", Path.join(root, "verdict.json")])
  end

  test "CLI rejects symlink, traversal, absolute reference and missing byte" do
    for type <- [:symlink, :traversal, :absolute, :missing] do
      {root, m} = F.fixture()
      m = case type do
        :symlink ->
          File.rm!(Path.join(root, "logs/format.txt"))
          File.ln_s!("../logs/compile.txt", Path.join(root, "logs/format.txt"))
          m
        :missing -> File.rm!(Path.join(root, "logs/format.txt")); m
        :traversal -> update_in(m, ["proofs"], fn [r | rest] -> [Map.put(r, "path", "../escape.json") | rest] end)
        :absolute -> update_in(m, ["proofs"], fn [r | rest] -> [Map.put(r, "path", Path.join(root, r["path"])) | rest] end)
      end
      F.put(root, "manifest.json", m)
      assert {:error, verdict} = V.run(["--manifest", Path.join(root, "manifest.json"), "--root", root, "--verdict", Path.join(root, "verdict.json")])
      assert verdict["verdict"] == "not_ready"
    end
  end
end
EX
mix run --no-start "$tmp/test.exs"
printf 'PASS: exact-head readiness CLI, immutable graph, negative-case count >= 40; refresh graph and path confinement\n'
