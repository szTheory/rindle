defmodule Rindle.ExactHeadReadiness do
  @moduledoc false
  @policy "rindle-exact-head-v1"
  @local ~w(format compile credo dialyzer-fresh dialyzer-restored doctor coverage security docs contracts package generated-consumer twin-recovery hygiene inbox-ledger contributor-bootstrap async-isolation release-truth)
  @mutable ~w(ci-main nightly-scheduled protection remote-inventory adoption-parity)
  @inputs ~w(mix.exs mix.lock RUNNING.md .github/workflows/ci.yml .github/workflows/nightly.yml .github/workflows/release.yml config/ci_required_checks.json .planning/PROJECT.md .planning/REQUIREMENTS.md)
  @commands %{
    "format" => ["mix", "format", "--check-formatted"],
    "compile" => ["mix", "compile", "--warnings-as-errors"],
    "credo" => ["mix", "credo_quality"],
    "dialyzer-fresh" => ["bash", "scripts/ci/run_nightly_dialyzer.sh", "fresh"],
    "dialyzer-restored" => ["bash", "scripts/ci/run_nightly_dialyzer.sh", "restored"],
    "doctor" => ["mix", "rindle.doctor"],
    "coverage" => ["mix", "coveralls.multiple", "--type", "local", "--type", "json"],
    "security" => ["mix", "deps.audit"],
    "docs" => ["mix", "doctor", "--full", "--raise"],
    "contracts" => ["mix", "refactor_contract"],
    "package" => ["mix", "hex.build"],
    "generated-consumer" => ["mix", "test", "test/install_smoke/generated_app_smoke_test.exs"],
    "twin-recovery" => ["python3", "scripts/maintainer/built_package_twin.py", "run"],
    "hygiene" => ["bash", "scripts/maintainer/repo_hygiene_check.sh", "--release-prep"],
    "inbox-ledger" => ["bash", "scripts/maintainer/validate_inbox_ledger.sh"],
    "contributor-bootstrap" => [
      "bash",
      "scripts/maintainer/verify_contributor_bootstrap.sh",
      "--run",
      "--full"
    ],
    "async-isolation" => ["bash", "scripts/maintainer/async_isolation_evidence.sh"],
    "release-truth" => ["bash", "scripts/maintainer/check_adoption_proof_matrix.sh"]
  }
  @resources ~w(tracked untracked ignored generated database jobs objects provider multipart temporary)
  @digests ~w(package_tar_sha256 package_metadata_sha256 package_tree_sha256)
  @toolchain %{"otp" => "27.3.4.15", "elixir" => "1.17.3-otp-27", "node" => "20.18.1"}

  def input_paths, do: @inputs
  def command_prefix(id), do: Map.fetch!(@commands, id)
  def policy, do: @policy
  def required_proofs, do: @local ++ @mutable
  def mutable_proofs, do: @mutable
  def resource_kinds, do: @resources
  def toolchain, do: @toolchain
  def sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

  # Pure policy consumes already loaded objects; I/O belongs to the CLI loader.
  def validate_contract(m, context) do
    validate_manifest!(m, context)
    Enum.each(m["proofs"], &validate_proof!(&1, m, context, m["observation_interval"]))
    envelope = context[:refresh_envelope]
    if envelope, do: validate_refresh!(envelope, m, context)

    %{
      "schema_version" => 1,
      "verdict" => "ready",
      "repository" => m["repository"],
      "subject_sha" => m["subject_sha"],
      "manifest_sha256" => context[:manifest_sha256],
      "policy" => @policy,
      "validator_sha256" => context[:validator_sha256],
      "evidence_scope" => m["evidence_mode"],
      "requirements_credit" => false,
      "observation_interval" => (envelope || m)["observation_interval"],
      "reasons" => []
    }
  rescue
    _error -> not_ready("malformed_contract", "invalid JSON shape or type", m)
  catch
    {:invalid, id, detail} -> not_ready(id, detail, m)
  end

  def run(argv) do
    {opts, rest, invalid} =
      OptionParser.parse(argv,
        strict: [manifest: :string, root: :string, verdict: :string, refresh_envelope: :string]
      )

    with true <- rest == [] and invalid == [],
         true <- Enum.all?([:manifest, :root, :verdict], &is_binary(opts[&1])),
         {:ok, manifest, context} <- load(opts) do
      verdict = validate_contract(manifest, context)
      write_verdict!(opts[:verdict], verdict)
      IO.puts("#{verdict["verdict"]}: #{verdict["subject_sha"] || "unknown"}")
      if verdict["verdict"] == "ready", do: :ok, else: {:error, verdict}
    else
      {:error, id, detail} -> cli_failure(opts, id, detail)
      _other -> cli_failure(opts, "invalid_options", "--manifest --root --verdict required")
    end
  rescue
    _error -> cli_failure([], "io_failure", "could not load or write evidence")
  end

  defp validate_manifest!(m, c) do
    ensure!(is_map(m) and m["schema_version"] == 1, "schema", "manifest schema_version must be 1")
    ensure!(m["policy"] == @policy, "policy", "unknown validator policy")

    ensure!(
      m["validator_sha256"] == c[:validator_sha256],
      "tool_identity",
      "validator bytes differ"
    )

    ensure!(sha?(c[:manifest_sha256]), "manifest_identity", "manifest byte digest absent")
    ensure!(m["state"] == "complete", "unfinished_attempt", "attempt is not complete")

    ensure!(
      m["evidence_mode"] in ["execution", "fixture"],
      "evidence_mode",
      "unknown evidence mode"
    )

    ensure!(
      is_binary(m["repository"]) and
        Regex.match?(~r/\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\z/, m["repository"]),
      "repository",
      "repository identity malformed"
    )

    ensure!(
      is_binary(m["subject_sha"]) and Regex.match?(~r/\A[0-9a-f]{40}\z/, m["subject_sha"]),
      "subject",
      "full subject SHA required"
    )

    ensure!(
      m["remote_main_before"] == m["subject_sha"] and m["remote_main_after"] == m["subject_sha"],
      "main_changed",
      "main differs from subject"
    )

    ensure!(m["toolchain"] == @toolchain, "toolchain", "unsupported resolved toolchain")
    validate_interval!(m["observation_interval"])
    validate_identity!(m["input_identity"], "input_identity")

    ensure!(
      Enum.sort(Map.keys(m["input_identity"])) == Enum.sort(@inputs),
      "input_identity",
      "committed policy input inventory differs"
    )

    validate_refs!(m["input_files"], c)

    ensure!(
      Enum.sort(Map.keys(m["input_files"])) == Enum.sort(@inputs),
      "input_identity",
      "policy input objects absent"
    )

    Enum.each(@inputs, fn path ->
      ensure!(
        m["input_files"][path]["sha256"] == m["input_identity"][path],
        "input_identity",
        "input object digest differs"
      )
    end)

    ensure!(
      is_map(m["package_identity"]) and
        Enum.sort(Map.keys(m["package_identity"])) == Enum.sort(@digests),
      "package_identity",
      "three named package digests required"
    )

    Enum.each(
      @digests,
      &ensure!(sha?(m["package_identity"][&1]), "package_identity", "invalid #{&1}")
    )

    validate_refs!(m["package_files"], c)

    ensure!(
      Enum.sort(Map.keys(m["package_files"])) == Enum.sort(@digests),
      "package_identity",
      "missing package objects"
    )

    Enum.each(@digests, fn kind ->
      ensure!(
        m["package_files"][kind]["sha256"] == m["package_identity"][kind],
        "package_identity",
        "package digest kind differs"
      )
    end)

    refs = m["proofs"]
    ensure!(is_list(refs), "proof_inventory", "proof inventory unavailable")

    ensure!(
      Enum.sort(Enum.map(refs, & &1["id"])) == Enum.sort(required_proofs()),
      "proof_inventory",
      "required/duplicate/unknown proof IDs"
    )

    ensure!(unique_paths?(refs), "proof_reference", "duplicate proof object")
    validate_cleanup!(m["cleanup"])
    validate_adoption!(m["adoption"])
  end

  defp validate_proof!(ref, m, c, interval) do
    r = decode!(object!(ref, c))
    id = ref["id"]

    ensure!(
      r["schema_version"] == 1 and r["id"] == id,
      "receipt_identity",
      "receipt schema or ID differs"
    )

    Enum.each(~w(repository subject_sha policy toolchain input_identity evidence_mode), fn key ->
      ensure!(r[key] == m[key], "receipt_identity", "#{id}: #{key} differs")
    end)

    ensure!(
      r["validator_sha256"] == c[:validator_sha256],
      "tool_identity",
      "#{id}: wrong validator"
    )

    ensure!(
      r["state"] == "complete" and r["outcome"] == "passed" and r["applicability"] == "required",
      "proof_outcome",
      "#{id}: unfinished, skipped or failed proof"
    )

    ensure!(
      r["package_identity"] == m["package_identity"],
      "package_identity",
      "#{id}: foreign package"
    )

    validate_interval!(r["observation_interval"])

    ensure!(
      contained?(r["observation_interval"], interval),
      "stale_observation",
      "#{id}: observation outside invocation"
    )

    validate_refs!(r["references"], c)
    if id in @local, do: validate_command!(r, c), else: validate_source!(r, c)
  end

  defp validate_command!(r, c) do
    command = r["command"]

    ensure!(
      is_map(command) and command["state"] == "completed" and command["exit_code"] === 0,
      "command_failed",
      "#{r["id"]}: terminal zero exit required"
    )

    ensure!(
      is_list(command["argv"]) and command["argv"] != [] and
        Enum.all?(command["argv"], &is_binary/1),
      "command_identity",
      "argv absent"
    )

    ensure!(
      is_integer(command["duration_ms"]) and command["duration_ms"] >= 0,
      "command_identity",
      "duration absent"
    )

    prefix = command_prefix(r["id"])

    ensure!(
      Enum.take(command["argv"], length(prefix)) == prefix,
      "command_identity",
      "command does not execute the registered gate"
    )

    ensure!(
      valid_command_args?(r["id"], command["argv"]),
      "command_identity",
      "unregistered command arguments"
    )

    object!(command["output"], c)
    ensure!(command["output"] in r["references"], "unbound_reference", "command output not bound")
    validate_identity!(r["tool_identity"], "tool_identity")
    validate_cleanup!(r["cleanup"])
  end

  defp valid_command_args?(id, argv) do
    suffix = Enum.drop(argv, length(command_prefix(id)))

    case {id, suffix} do
      {_id, []} ->
        true

      {"twin-recovery", ["--evidence-dir", path, "--cleanup"]} ->
        absolute_argument?(path)

      {"contributor-bootstrap", ["--receipt", path]} ->
        absolute_argument?(path)

      {"async-isolation", ["--report", path]} ->
        absolute_argument?(path)

      {"inbox-ledger", ["--ledger", ".planning/INBOX-LEDGER.json", "--inventory", path]} ->
        absolute_argument?(path)

      _other ->
        false
    end
  end

  defp absolute_argument?(path), do: is_binary(path) and Path.type(path) == :absolute

  defp validate_source!(r, c) do
    s = r["source"]

    ensure!(
      is_map(s) and s["complete"] === true and s["authenticated"] === true,
      "source_unavailable",
      "#{r["id"]}: incomplete source or visibility"
    )

    ensure!(is_binary(s["query"]) and s["query"] != "", "source_identity", "query policy absent")

    ensure!(
      s["before_sha256"] == s["after_sha256"] and sha?(s["before_sha256"]),
      "source_changed",
      "#{r["id"]}: observations differ"
    )

    ensure!(
      is_integer(s["pages"]) and s["pages"] > 0,
      "source_unavailable",
      "complete pages absent"
    )

    ensure!(
      s["policy"] == @policy and is_map(s["normalized"]),
      "source_identity",
      "normalized source absent"
    )

    validate_interval!(s["observation_interval"])

    ensure!(
      contained?(s["observation_interval"], r["observation_interval"]),
      "stale_observation",
      "source observations outside receipt invocation"
    )

    n = s["normalized"]

    ensure!(
      n["repository"] == r["repository"] and n["subject_sha"] == r["subject_sha"],
      "source_identity",
      "foreign normalized source"
    )

    observations = s["observations"]

    ensure!(
      is_list(observations) and length(observations) == 2 and unique_paths?(observations),
      "source_identity",
      "two distinct bounded source observations required"
    )

    Enum.zip(observations, [s["before_sha256"], s["after_sha256"]])
    |> Enum.each(fn {ref, digest} ->
      ensure!(
        ref["sha256"] == digest and decode!(object!(ref, c)) == n and ref in r["references"],
        "source_identity",
        "observation bytes not bound to normalized source"
      )
    end)

    case r["id"] do
      "ci-main" -> validate_run!(n, "CI", "push", "ci.yml")
      "nightly-scheduled" -> validate_run!(n, "Nightly", "schedule", "nightly.yml")
      "protection" -> validate_protection!(n)
      "remote-inventory" -> validate_inventory!(n)
      "adoption-parity" -> validate_adoption!(n["adoption"])
    end
  end

  defp validate_run!(r, name, event, workflow) do
    ensure!(
      r["workflow"] == workflow and r["name"] == name and r["event"] == event and
        r["branch"] == "main",
      "workflow_identity",
      "wrong workflow/event/branch"
    )

    ensure!(
      positive?(r["run_id"]) and positive?(r["attempt"]),
      "attempt_identity",
      "run/attempt absent"
    )

    ensure!(
      r["state"] == "completed" and r["conclusion"] == "success" and
        r["latest_run_id"] == r["run_id"] and r["rechecked_attempt"] == r["attempt"],
      "attempt_changed",
      "latest complete attempt not successful"
    )

    expected = r["expected_jobs"]
    jobs = r["jobs"]

    ensure!(
      is_list(expected) and expected != [] and is_list(jobs),
      "job_inventory",
      "topology unavailable"
    )

    ensure!(
      Enum.sort(Enum.map(jobs, & &1["name"])) == Enum.sort(expected),
      "job_inventory",
      "missing/duplicate/unexpected matrix job"
    )

    ensure!(
      length(Enum.uniq(Enum.map(jobs, & &1["id"]))) == length(jobs),
      "job_inventory",
      "duplicate job ID"
    )

    Enum.each(jobs, fn j ->
      ensure!(
        positive?(j["id"]) and j["state"] == "completed" and j["conclusion"] == "success",
        "job_outcome",
        "required job did not succeed"
      )
    end)

    ensure!(
      sha?(r["topology_sha256"]) and r["topology_resolved"] === true,
      "unknown_topology",
      "committed topology not resolved"
    )
  end

  defp validate_protection!(p) do
    ensure!(
      p["classic_visible"] === true and p["rulesets_visible"] === true and
        p["organization_visible"] === true,
      "protection_unavailable",
      "effective protection unavailable"
    )

    ensure!(
      p["effective_checks"] == [%{"context" => "CI Summary", "app_id" => 15368}],
      "protection_drift",
      "effective required check/app differs"
    )

    ensure!(
      p["enforced"] === true and p["bypass_actors"] == [],
      "protection_drift",
      "unexpected enforcement/bypass"
    )
  end

  defp validate_inventory!(i) do
    sources = i["sources"]

    ensure!(
      is_map(sources) and
        Enum.sort(Map.keys(sources)) ==
          Enum.sort(~w(issues pulls checks statuses advisories dependabot hex protection absent)),
      "remote_inventory",
      "separate complete sources required"
    )

    Enum.each(sources, fn {name, s} ->
      ensure!(
        s["complete"] === true and s["authorized"] === true and s["reconciled"] === true and
          s["changed"] === false,
        "remote_inventory",
        "#{name}: unavailable, changed or undispositioned"
      )

      ensure!(
        is_integer(s["count"]) and s["count"] >= 0 and sha?(s["identity_sha256"]),
        "remote_inventory",
        "#{name}: malformed inventory"
      )
    end)

    ensure!(
      sha?(sources["hex"]["database_sha256"]),
      "hex_identity",
      "Hex database identity absent"
    )
  end

  defp validate_refresh!(e, m, c) do
    ensure!(is_map(e) and e["schema_version"] == 1, "refresh_schema", "refresh envelope schema")

    ensure!(
      e["manifest_sha256"] == c[:manifest_sha256],
      "refresh_manifest",
      "original manifest bytes differ"
    )

    Enum.each(~w(repository subject_sha policy validator_sha256), fn key ->
      ensure!(e[key] == m[key], "refresh_identity", "#{key}: refresh identity differs")
    end)

    ensure!(
      e["remote_main_before"] == m["subject_sha"] and e["remote_main_after"] == m["subject_sha"],
      "main_changed",
      "refresh main advanced"
    )

    validate_interval!(e["observation_interval"])

    ensure!(
      time!(e["observation_interval"]["started_at"]) >=
        time!(m["observation_interval"]["completed_at"]),
      "stale_observation",
      "refresh predates manifest"
    )

    refs = e["proofs"]

    ensure!(
      is_list(refs) and Enum.sort(Enum.map(refs, & &1["id"])) == Enum.sort(@mutable),
      "refresh_inventory",
      "all mutable proofs required exactly once"
    )

    ensure!(unique_paths?(refs), "refresh_inventory", "duplicate refreshed object")

    ensure!(
      MapSet.disjoint?(
        MapSet.new(Enum.map(refs, & &1["path"])),
        MapSet.new(Enum.map(m["proofs"], & &1["path"]))
      ),
      "refresh_inventory",
      "refresh must use separate immutable objects"
    )

    Enum.each(refs, &validate_proof!(&1, m, c, e["observation_interval"]))
    validate_adoption!(e["adoption"])
    ensure!(e["verdict"] == "ready", "refresh_outcome", "refresh attempt not ready")
  end

  defp validate_cleanup!(cleanup) do
    ensure!(
      is_map(cleanup) and cleanup["state"] == "observed" and cleanup["errors"] == [],
      "cleanup_unobserved",
      "cleanup was not observed successfully"
    )

    inventory = cleanup["inventories"]

    ensure!(
      is_list(inventory) and
        Enum.sort(Enum.map(inventory, & &1["kind"])) == Enum.sort(@resources),
      "residue_inventory",
      "all resource kinds must be inventoried"
    )

    Enum.each(inventory, fn entry ->
      ensure!(
        is_list(entry["before"]) and is_list(entry["after"]) and is_list(entry["allowed"]),
        "residue_inventory",
        "resource observation unavailable"
      )

      ensure!(
        Enum.all?(entry["allowed"], fn cache ->
          is_map(cache) and cache["class"] in ["tool_cache", "evidence_output"] and
            is_binary(cache["path"]) and is_binary(cache["reason"]) and cache["reason"] != ""
        end),
        "residue_inventory",
        "unclassified allowed residue"
      )

      ensure!(
        entry["allowed"] == [] or entry["kind"] in ["ignored", "generated", "temporary"],
        "residue_inventory",
        "only build caches and external evidence may be excepted"
      )

      ensure!(
        entry["after"] -- Enum.map(entry["allowed"], & &1["path"]) == [],
        "residue_present",
        "unapproved #{entry["kind"]} residue"
      )
    end)
  end

  defp validate_adoption!(a) do
    ensure!(
      is_map(a) and a["class"] == "maintainer_operated_synthetic" and
        a["independent_pilot_credit"] === false and a["pilot_01"] == "open" and
        a["pilot_02"] == "open" and a["one_point_zero_authority"] === false,
      "adoption_inflation",
      "synthetic evidence cannot grant independent pilot or 1.0 authority"
    )
  end

  defp validate_identity!(identity, reason) do
    ensure!(is_map(identity) and map_size(identity) > 0, reason, "identity absent")

    Enum.each(identity, fn {key, value} ->
      ensure!(is_binary(key) and key != "" and sha?(value), reason, "identity digest invalid")
    end)
  end

  defp validate_interval!(i) do
    ensure!(is_map(i), "observation_interval", "interval absent")

    ensure!(
      time!(i["started_at"]) <= time!(i["completed_at"]),
      "observation_interval",
      "interval reversed"
    )
  end

  defp contained?(i, parent),
    do:
      time!(i["started_at"]) >= time!(parent["started_at"]) and
        time!(i["completed_at"]) <= time!(parent["completed_at"])

  defp time!(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, 0} -> DateTime.to_unix(dt, :microsecond)
      _other -> reject!("observation_interval", "UTC timestamp required")
    end
  end

  defp unique_paths?(refs), do: length(Enum.uniq(Enum.map(refs, & &1["path"]))) == length(refs)
  defp positive?(v), do: is_integer(v) and v > 0

  defp object!(ref, c) do
    ensure!(
      is_map(ref) and is_binary(ref["path"]) and sha?(ref["sha256"]),
      "object_reference",
      "path and SHA-256 required"
    )

    bytes = c[:objects][ref["path"]]

    ensure!(
      is_binary(bytes) and sha256(bytes) == ref["sha256"],
      "object_digest",
      "missing or corrupt #{ref["path"]}"
    )

    bytes
  end

  defp validate_refs!(refs, c) when is_list(refs), do: Enum.each(refs, &object!(&1, c))
  defp validate_refs!(refs, c) when is_map(refs), do: refs |> Map.values() |> validate_refs!(c)
  defp validate_refs!(_refs, _c), do: reject!("object_reference", "object inventory absent")

  defp decode!(bytes) do
    case Jason.decode(bytes) do
      {:ok, value} when is_map(value) -> value
      _other -> reject!("malformed_json", "receipt must be a JSON object")
    end
  end

  defp sha?(v), do: is_binary(v) and Regex.match?(~r/\A[0-9a-f]{64}\z/, v)
  defp ensure!(true, _id, _detail), do: :ok
  defp ensure!(_false, id, detail), do: reject!(id, detail)
  defp reject!(id, detail), do: throw({:invalid, id, detail})

  defp not_ready(id, detail, m) do
    %{
      "schema_version" => 1,
      "verdict" => "not_ready",
      "subject_sha" => if(is_map(m), do: m["subject_sha"], else: nil),
      "requirements_credit" => false,
      "reasons" => [
        %{
          "id" => id,
          "detail" => detail,
          "repair_command" =>
            "bash scripts/maintainer/exact_head_readiness.sh close --repo OWNER/REPO --output NEW_EXTERNAL_DIRECTORY"
        }
      ]
    }
  end

  defp load(opts) do
    root = Path.expand(opts[:root])
    ensure!(File.lstat!(root).type == :directory, "unsafe_path", "root must be a real directory")
    manifest_path = relative!(root, opts[:manifest])
    bytes = safe_read!(root, manifest_path)
    m = decode!(bytes)

    envelope =
      if opts[:refresh_envelope],
        do: decode!(safe_read!(root, relative!(root, opts[:refresh_envelope])))

    visited = MapSet.new([manifest_path])
    objects = load_objects!(m, root, %{}, visited, 0)
    objects = if envelope, do: load_objects!(envelope, root, objects, visited, 0), else: objects

    {:ok, m,
     %{
       objects: objects,
       manifest_sha256: sha256(bytes),
       validator_sha256: sha256(File.read!(__ENV__.file)),
       refresh_envelope: envelope
     }}
  rescue
    _error -> {:error, "io_failure", "missing, unreadable or malformed evidence"}
  catch
    {:invalid, id, detail} -> {:error, id, detail}
  end

  defp load_objects!(value, root, objects, visited, depth) do
    ensure!(
      depth < 12 and map_size(objects) <= 2000,
      "graph_limit",
      "graph exceeds bounded policy"
    )

    Enum.reduce(references(value), objects, fn ref, acc ->
      path = ref["path"]
      ensure!(not MapSet.member?(visited, path), "cyclic_reference", "cyclic/self reference")
      bytes = safe_read!(root, path)
      ensure!(sha256(bytes) == ref["sha256"], "object_digest", "corrupt #{path}")
      acc = Map.put(acc, path, bytes)

      case Jason.decode(bytes) do
        {:ok, nested} -> load_objects!(nested, root, acc, MapSet.put(visited, path), depth + 1)
        _other -> acc
      end
    end)
  end

  defp references(%{"path" => _path, "sha256" => _sha} = value), do: [value]

  defp references(value) when is_map(value),
    do: value |> Map.values() |> Enum.flat_map(&references/1)

  defp references(value) when is_list(value), do: Enum.flat_map(value, &references/1)
  defp references(_value), do: []

  defp relative!(root, path) do
    expanded = Path.expand(path)
    relative = Path.relative_to(expanded, root)
    ensure!(relative != expanded and relative != ".", "unsafe_path", "file must be beneath root")
    relative
  end

  defp safe_read!(root, path) do
    ensure!(
      is_binary(path) and path != "" and not String.contains?(path, ["\0", "\\"]) and
        Path.type(path) == :relative and Enum.all?(Path.split(path), &(&1 not in [".", ".."])),
      "unsafe_path",
      "relative confined path required"
    )

    target =
      Enum.reduce(Path.split(path), root, fn part, parent ->
        child = Path.join(parent, part)

        ensure!(
          File.lstat!(child).type in [:directory, :regular],
          "unsafe_path",
          "symlinks and special files forbidden"
        )

        child
      end)

    ensure!(File.stat!(target).size <= 256_000_000, "object_limit", "object too large")
    File.read!(target)
  end

  defp write_verdict!(path, verdict) do
    {:ok, file} = File.open(path, [:write, :exclusive])

    try do
      IO.binwrite(file, Jason.encode!(verdict, pretty: true) <> "\n")
    after
      File.close(file)
    end
  end

  defp cli_failure(opts, id, detail) do
    verdict = not_ready(id, detail, %{})

    if opts[:verdict] && not File.exists?(opts[:verdict]),
      do: write_verdict!(opts[:verdict], verdict)

    IO.puts(:stderr, "not_ready: #{id}: #{detail}")
    {:error, verdict}
  end
end

unless System.get_env("RINDLE_EXACT_HEAD_LIBRARY_ONLY") == "1" do
  case Rindle.ExactHeadReadiness.run(System.argv()) do
    :ok -> :ok
    {:error, _verdict} -> System.halt(1)
  end
end
