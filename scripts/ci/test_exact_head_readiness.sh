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

defmodule ReadinessFixture do
  alias Rindle.ExactHeadReadiness, as: V

  def put(root, path, value) do
    bytes = if is_binary(value), do: value, else: Jason.encode!(value)
    File.mkdir_p!(Path.dirname(Path.join(root, path)))
    File.write!(Path.join(root, path), bytes)
    %{"path" => path, "sha256" => V.sha256(bytes)}
  end

  def cleanup do
    %{"state" => "observed", "errors" => [], "inventories" =>
      Enum.map(V.resource_kinds(), &%{"kind" => &1, "before" => [], "after" => [], "allowed" => []})}
  end

  def adoption do
    %{"class" => "maintainer_operated_synthetic", "independent_pilot_credit" => false,
      "pilot_01" => "open", "pilot_02" => "open", "one_point_zero_authority" => false}
  end

  def interval(n \\ 0) do
    %{"started_at" => "2026-10-22T10:#{String.pad_leading(to_string(n), 2, "0")}:00Z",
      "completed_at" => "2026-10-22T10:#{String.pad_leading(to_string(n + 1), 2, "0")}:00Z"}
  end

  def fixture do
    root = Path.join(System.fetch_env!("RINDLE_READINESS_TEST_ROOT"), "case-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    input_files = Map.new(V.input_paths(), &{&1, put(root, "inputs/#{&1}", "fixture committed input #{&1}")})
    package_files = Map.new(~w(package_tar_sha256 package_metadata_sha256 package_tree_sha256), &{&1, put(root, "package/#{&1}", "fixture bytes #{&1}")})
    manifest = %{
      "schema_version" => 1, "repository" => "szTheory/rindle", "subject_sha" => String.duplicate("a", 40),
      "remote_main_before" => String.duplicate("a", 40), "remote_main_after" => String.duplicate("a", 40),
      "policy" => V.policy(), "validator_sha256" => V.sha256(File.read!("scripts/maintainer/validate_exact_head_readiness.exs")),
      "state" => "complete", "evidence_mode" => "fixture", "toolchain" => V.toolchain(),
      "input_identity" => Map.new(input_files, fn {p, r} -> {p, r["sha256"]} end), "input_files" => input_files,
      "package_identity" => Map.new(package_files, fn {p, r} -> {p, r["sha256"]} end), "package_files" => package_files,
      "observation_interval" => interval(), "cleanup" => cleanup(), "adoption" => adoption()
    }
    proofs = Enum.map(V.required_proofs(), fn id ->
      receipt = Map.take(manifest, ~w(repository subject_sha policy validator_sha256 toolchain input_identity package_identity observation_interval evidence_mode))
      receipt = Map.merge(receipt, %{"schema_version" => 1, "id" => id, "state" => "complete", "outcome" => "passed", "applicability" => "required", "references" => []})
      receipt = if id in V.mutable_proofs() do
        n = normalized(id, manifest)
        observations = Enum.map(["before", "after"], &put(root, "observations/#{id}-#{&1}.json", n))
        Map.merge(receipt, %{"references" => observations, "source" => %{
          "complete" => true, "authenticated" => true, "query" => "fixture/#{id}", "pages" => 1,
          "before_sha256" => hd(observations)["sha256"], "after_sha256" => List.last(observations)["sha256"],
          "observations" => observations, "policy" => V.policy(), "normalized" => n}})
      else
        output = put(root, "logs/#{id}.txt", "fixture command completed: #{id}\n")
        Map.merge(receipt, %{"references" => [output], "cleanup" => cleanup(), "tool_identity" => %{"mix" => V.sha256("fixture tool")},
          "command" => %{"state" => "completed", "exit_code" => 0, "duration_ms" => 1, "argv" => V.command_prefix(id), "output" => output}})
      end
      Map.put(put(root, "receipts/#{id}.json", receipt), "id", id)
    end)
    manifest = Map.put(manifest, "proofs", proofs)
    {root, manifest}
  end

  def normalized(id, manifest) do
    base = Map.take(manifest, ~w(repository subject_sha))
    specific = case id do
      "ci-main" -> run("CI", "push", "ci.yml")
      "nightly-scheduled" -> run("Nightly", "schedule", "nightly.yml")
      "protection" -> %{"classic_visible" => true, "rulesets_visible" => true, "organization_visible" => true, "enforced" => true, "bypass_actors" => [], "effective_checks" => [%{"context" => "CI Summary", "app_id" => 15368}]}
      "adoption-parity" -> %{"adoption" => adoption()}
      "remote-inventory" -> %{"sources" => Map.new(~w(issues pulls checks statuses advisories dependabot hex protection absent), fn source ->
        {source, %{"complete" => true, "authorized" => true, "reconciled" => true, "changed" => false, "count" => 0, "identity_sha256" => V.sha256("fixture inventory"), "database_sha256" => V.sha256("fixture Hex database")}}
      end)}
    end
    Map.merge(base, specific)
  end

  def run(name, event, workflow) do
    %{"name" => name, "event" => event, "workflow" => workflow, "branch" => "main", "run_id" => 10,
      "attempt" => 2, "latest_run_id" => 10, "rechecked_attempt" => 2, "state" => "completed", "conclusion" => "success",
      "expected_jobs" => ["Required (1.17, 27)", "Main only"], "topology_sha256" => V.sha256("committed workflow"), "topology_resolved" => true,
      "jobs" => [%{"id" => 100, "name" => "Required (1.17, 27)", "state" => "completed", "conclusion" => "success"}, %{"id" => 101, "name" => "Main only", "state" => "completed", "conclusion" => "success"}]}
  end

  def context(root, manifest, envelope \\ nil) do
    files = Path.wildcard(Path.join(root, "**/*"), match_dot: true) |> Enum.filter(&File.regular?/1)
    %{objects: Map.new(files, &{Path.relative_to(&1, root), File.read!(&1)}),
      manifest_sha256: V.sha256(Jason.encode!(manifest)), validator_sha256: manifest["validator_sha256"], refresh_envelope: envelope}
  end

  def change(root, m, id, fun) do
    refs = Enum.map(m["proofs"], fn ref ->
      if ref["id"] == id do
        value = root |> Path.join(ref["path"]) |> File.read!() |> Jason.decode!() |> fun.()
        Map.put(put(root, ref["path"], value), "id", id)
      else
        ref
      end
    end)
    Map.put(m, "proofs", refs)
  end

  def refresh(root, m) do
    refs = m["proofs"] |> Enum.filter(&(&1["id"] in V.mutable_proofs())) |> Enum.map(fn ref ->
      value = root |> Path.join(ref["path"]) |> File.read!() |> Jason.decode!() |> Map.put("observation_interval", interval(2))
      Map.put(put(root, "refresh/#{ref["id"]}.json", value), "id", ref["id"])
    end)
    Map.merge(Map.take(m, ~w(repository subject_sha policy validator_sha256 remote_main_before remote_main_after adoption)),
      %{"schema_version" => 1, "manifest_sha256" => V.sha256(Jason.encode!(m)), "observation_interval" => interval(2), "proofs" => refs, "verdict" => "ready"})
  end
end

defmodule ReadinessPolicyTest do
  use ExUnit.Case, async: false
  alias Rindle.ExactHeadReadiness, as: V
  alias ReadinessFixture, as: F

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
