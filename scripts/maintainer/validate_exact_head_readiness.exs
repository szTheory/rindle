unless Code.ensure_loaded?(Rindle.ReadinessHexAudit),
  do: Code.require_file("readiness_hex_audit.exs", __DIR__)

unless Code.ensure_loaded?(Rindle.ReadinessWorkflow),
  do: Code.require_file("readiness_workflow.exs", __DIR__)

defmodule Rindle.ExactHeadReadiness do
  @moduledoc false
  @policy "rindle-exact-head-v1"
  @snapshot_policy "rindle-snapshot-v2"
  @snapshot_controls ~w(scripts/maintainer/readiness_subject.py
    scripts/maintainer/validate_exact_head_readiness.exs
    scripts/maintainer/exact_head_readiness.py
    scripts/maintainer/readiness_acceptance.py
    scripts/maintainer/readiness_closure.py
    scripts/maintainer/readiness_retention.py
    scripts/maintainer/readiness_adoption.py
    scripts/maintainer/collect_readiness_runs.py
    scripts/maintainer/collect_readiness_remote.py
    scripts/maintainer/readiness_github.py
    scripts/maintainer/readiness_workflow.exs
    scripts/maintainer/readiness_process.py
    scripts/maintainer/readiness_hex_audit.exs
    scripts/maintainer/exact_head_readiness.sh
    scripts/maintainer/retain_readiness_bundle.sh
    scripts/maintainer/qualify_generated_consumer.exs
    .github/workflows/readiness-retention.yml)
  @snapshot_control_digests Map.new(@snapshot_controls, fn path ->
                              {path,
                               :crypto.hash(
                                 :sha256,
                                 File.read!(Path.expand("../..", __DIR__) <> "/" <> path)
                               )
                               |> Base.encode16(case: :lower)}
                            end)
  @workflow_helper_sha :crypto.hash(
                         :sha256,
                         File.read!(Path.join(__DIR__, "readiness_workflow.exs"))
                       )
                       |> Base.encode16(case: :lower)
  @hex_helper_sha :crypto.hash(:sha256, File.read!(Path.join(__DIR__, "readiness_hex_audit.exs")))
                  |> Base.encode16(case: :lower)
  @baseline_helper_sha :crypto.hash(
                         :sha256,
                         File.read!(Path.join(__DIR__, "land_release_train_baseline.py"))
                       )
                       |> Base.encode16(case: :lower)
  @credential_inputs ~w(.github/actions/repository-credential/action.yml
    scripts/maintainer/repository_credential.py
    .github/workflows/release-please-automerge.yml .github/workflows/branch-protection-apply.yml)
  @credential_digests Map.new(@credential_inputs, fn path ->
                        {path,
                         :crypto.hash(
                           :sha256,
                           File.read!(Path.expand("../..", __DIR__) <> "/" <> path)
                         )
                         |> Base.encode16(case: :lower)}
                      end)
  @ci_guard "90f8baf94a3d997994f917240b77866d219061ff20fe6df35f81c1cdda1a6238"
  @release_guard "198172f4e655c3b25990943329c38382a6fe753134d58fe378e1afdb66acb8c2"
  @local ~w(format compile credo dialyzer-fresh dialyzer-restored doctor coverage security docs contracts package generated-consumer twin-recovery hygiene inbox-ledger contributor-bootstrap async-isolation release-truth)
  @mutable ~w(ci-main nightly-scheduled protection remote-inventory adoption-parity)
  @inputs ~w(scripts/maintainer/readiness_subject.py scripts/maintainer/validate_exact_head_readiness.exs) ++
            @credential_inputs ++
            ~w(mix.exs mix.lock RUNNING.md .dialyzer_ignore.exs
    .github/workflows/ci.yml .github/workflows/nightly.yml .github/workflows/release.yml
    config/ci_required_checks.json .planning/PROJECT.md .planning/REQUIREMENTS.md .planning/INBOX-LEDGER.json
    scripts/maintainer/credo_complexity_baseline.json scripts/maintainer/phase136_evidence_contract.json
    scripts/maintainer/artifact_ledger.json scripts/maintainer/refactor_contract.sh
    scripts/maintainer/exact_head_readiness.py scripts/maintainer/qualify_generated_consumer.exs
    scripts/maintainer/readiness_workflow.exs scripts/maintainer/readiness_github.py
    scripts/maintainer/land_release_train_baseline.py
    scripts/maintainer/collect_readiness_runs.py scripts/maintainer/collect_readiness_remote.py scripts/maintainer/readiness_closure.py scripts/maintainer/readiness_process.py
    .release-please-manifest.json release-please-config.json
    .github/workflows/readiness-retention.yml
    scripts/maintainer/readiness_adoption.py scripts/maintainer/readiness_retention.py
    scripts/maintainer/readiness_acceptance.py scripts/maintainer/retain_readiness_bundle.sh
    scripts/maintainer/exact_head_readiness.sh
    .planning/phases/139-exact-head-readiness-closure/139-preflight.sh
    scripts/maintainer/readiness_hex_audit.exs scripts/maintainer/validate_inbox_ledger.sh
    examples/adoption_demo/mix.lock
    scripts/ci/run_nightly_dialyzer.sh scripts/maintainer/verify_contributor_bootstrap.sh
    scripts/maintainer/async_isolation_evidence.sh scripts/maintainer/built_package_twin.py
    scripts/maintainer/twin_receipt.py scripts/maintainer/twin_cleanup.py
    test/install_smoke/support/generated_app_helper.ex test/install_smoke/support/generated_app/workspace.ex)
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
    "generated-consumer" => [
      "mix",
      "run",
      "--no-start",
      "scripts/maintainer/qualify_generated_consumer.exs"
    ],
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

  def snapshot_controls, do: @snapshot_controls
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
      "policy" => m["policy"],
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

  defp subject_sha?(value), do: is_binary(value) and Regex.match?(~r/\A[0-9a-f]{40}\z/, value)

  defp validate_snapshot_subjects!(record, m, c) do
    refs = record["snapshot_subjects"]

    ensure!(
      is_list(refs) and length(refs) == 2 and unique_paths?(refs),
      "snapshot_identity",
      "two candidate observations required"
    )

    Enum.zip(refs, [record["remote_main_before"], record["remote_main_after"]])
    |> Enum.each(fn {ref, current} ->
      value = decode!(object!(ref, c))
      push = value["push_run"]
      comparison = value["comparison"]

      ensure!(
        subject_sha?(current) and value["schema"] == "rindle-readiness-snapshot-subject-v2" and
          value["authenticated"] === true and value["requirements_credit"] === false and
          value["repository"] == m["repository"] and value["subject_sha"] == m["subject_sha"] and
          value["current_main_sha"] == current and
          value["protected_main"] == %{"name" => "main", "protected" => true, "sha" => current},
        "snapshot_identity",
        "protected-main candidate observation differs"
      )

      ensure!(
        is_map(comparison) and comparison["status"] in ["ahead", "identical"] and
          comparison["base"] == m["subject_sha"] and comparison["merge_base"] == m["subject_sha"] and
          comparison["head"] == current,
        "snapshot_ancestry",
        "candidate must remain reachable from main"
      )

      ensure!(
        is_map(push) and positive?(push["id"]) and positive?(push["run_attempt"]) and
          push["head_sha"] == m["subject_sha"] and push["head_branch"] == "main" and
          push["event"] == "push" and push["name"] == "CI" and
          push["path"] == ".github/workflows/ci.yml" and
          push["status"] == "completed" and push["conclusion"] == "success",
        "snapshot_provenance",
        "candidate needs actual push-main provenance"
      )

      ensure!(
        value["control_identity"] == @snapshot_control_digests and
          value["control_identity"] == Map.take(m["input_identity"], @snapshot_controls) and
          Enum.all?(@snapshot_controls, &sha?(value["control_identity"][&1])),
        "snapshot_policy",
        "candidate control bytes differ"
      )

      ensure!(
        time!(value["observed_at"]) >= time!(record["observation_interval"]["started_at"]) and
          time!(value["observed_at"]) <= time!(record["observation_interval"]["completed_at"]),
        "stale_observation",
        "candidate observation outside invocation"
      )
    end)
  end

  defp validate_manifest!(m, c) do
    ensure!(is_map(m) and m["schema_version"] == 1, "schema", "manifest schema_version must be 1")
    ensure!(m["policy"] in [@policy, @snapshot_policy], "policy", "unknown validator policy")

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

    if m["policy"] == @snapshot_policy do
      validate_snapshot_subjects!(m, m, c)
    else
      ensure!(
        m["remote_main_before"] == m["subject_sha"] and
          m["remote_main_after"] == m["subject_sha"],
        "main_changed",
        "main differs from subject"
      )
    end

    ensure!(m["toolchain"] == @toolchain, "toolchain", "unsupported resolved toolchain")

    ensure!(
      is_map(m["runtime_evidence"]) and
        Enum.sort(Map.keys(m["runtime_evidence"])) == ["elixir", "node"],
      "tool_identity",
      "actual runtime probes required"
    )

    ensure!(
      String.split(String.trim(object!(m["runtime_evidence"]["elixir"], c)), "\n") == [
        "1.17.3",
        "27.3.4.15"
      ],
      "tool_identity",
      "observed Elixir/OTP unsupported"
    )

    ensure!(
      String.trim(object!(m["runtime_evidence"]["node"], c)) == "v20.18.1",
      "tool_identity",
      "observed Node unsupported"
    )

    validate_interval!(m["observation_interval"])
    validate_identity!(m["input_identity"], "input_identity")

    ensure!(
      Enum.sort(Map.keys(m["input_identity"])) == Enum.sort(@inputs),
      "input_identity",
      "committed policy input inventory differs"
    )

    ensure!(
      m["input_identity"]["scripts/maintainer/readiness_workflow.exs"] == @workflow_helper_sha,
      "tool_identity",
      "topology evaluator differs"
    )

    ensure!(
      m["input_identity"]["scripts/maintainer/readiness_hex_audit.exs"] == @hex_helper_sha,
      "tool_identity",
      "Hex evaluator differs"
    )

    ensure!(
      m["input_identity"]["scripts/maintainer/land_release_train_baseline.py"] ==
        @baseline_helper_sha,
      "tool_identity",
      "baseline landing evaluator differs"
    )

    Enum.each(@credential_digests, fn {path, expected} ->
      ensure!(
        m["input_identity"][path] == expected,
        "tool_identity",
        "credential policy input differs"
      )
    end)

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
    if id in @local, do: validate_command!(r, c), else: validate_source!(r, c, m)
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

      {"package", ["--output", path]} ->
        absolute_argument?(path)

      {"inbox-ledger", ["--ledger", ".planning/INBOX-LEDGER.json", "--offline"]} ->
        true

      {"twin-recovery", ["--evidence-dir", path, "--cleanup"]} ->
        absolute_argument?(path)

      {"contributor-bootstrap", ["--receipt", path, "--subject-sha", sha]} ->
        absolute_argument?(path) and is_binary(sha) and Regex.match?(~r/\A[0-9a-f]{40}\z/, sha)

      {"async-isolation", ["--report", path]} ->
        absolute_argument?(path)

      {"inbox-ledger", ["--ledger", ".planning/INBOX-LEDGER.json", "--inventory", path]} ->
        absolute_argument?(path)

      _other ->
        false
    end
  end

  defp absolute_argument?(path), do: is_binary(path) and Path.type(path) == :absolute

  defp validate_source!(r, c, m) do
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
      s["policy"] == r["policy"] and is_map(s["normalized"]),
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

    if r["id"] == "nightly-scheduled" do
      nref = n["incident_artifact"]

      ensure!(
        nref in r["references"] and nref["sha256"] == n["incident_artifact_sha256"],
        "incident_identity",
        "archive reference absent"
      )

      archive = object!(nref, c)

      case :zip.list_dir(archive) do
        {:ok, [{:zip_comment, _}, {:zip_file, ~c"nightly-incident-verdict.json", info, _, _, _}]} ->
          stat = File.Stat.from_record(info)

          ensure!(
            stat.size <= 1_048_576 and stat.type == :regular,
            "incident_identity",
            "archive size or type invalid"
          )

        _ ->
          throw({:invalid, "incident_identity", "archive inventory differs"})
      end

      case :zip.extract(archive, [:memory]) do
        {:ok, [{~c"nightly-incident-verdict.json", bytes}]} ->
          ensure!(decode!(bytes) == n["incident"], "incident_identity", "archive verdict differs")

        _ ->
          throw({:invalid, "incident_identity", "archive shape differs"})
      end
    end

    case r["id"] do
      "ci-main" ->
        validate_workflow_guards!(
          object!(m["input_files"][".github/workflows/ci.yml"], c),
          object!(m["input_files"][".github/workflows/release.yml"], c)
        )

        validate_run!(
          n,
          "CI",
          "push",
          "ci.yml",
          object!(m["input_files"][".github/workflows/ci.yml"], c)
        )

      "nightly-scheduled" ->
        validate_run!(
          n,
          "Nightly",
          "schedule",
          "nightly.yml",
          object!(m["input_files"][".github/workflows/nightly.yml"], c)
        )

      "protection" ->
        validate_protection!(n)

      "remote-inventory" ->
        validate_inventory!(n, m, c, r["references"])

      "adoption-parity" ->
        validate_adoption!(n["adoption"])

        paths =
          ~w(.planning/REQUIREMENTS.md .planning/PROJECT.md mix.exs .release-please-manifest.json release-please-config.json)

        expected =
          if m["policy"] == @snapshot_policy do
            files = n["authoritative_files"]

            ensure!(
              is_map(files) and Enum.sort(Map.keys(files)) == Enum.sort(paths) and
                subject_sha?(n["authority_main_sha"]),
              "adoption_authority",
              "live authority absent"
            )

            Map.new(files, fn {path, ref} ->
              ensure!(
                ref in r["references"],
                "adoption_authority",
                "live authority reference absent"
              )

              object!(ref, c)
              {path, ref["sha256"]}
            end)
          else
            Map.take(m["input_identity"], paths)
          end

        ensure!(
          n["adoption_policy"] == "rindle-synthetic-adoption-v1" and
            n["authoritative_inputs"] == expected,
          "adoption_authority",
          "adoption observations must bind every authoritative input"
        )
    end
  end

  defp validate_workflow_guards!(ci, release) do
    ensure!(
      Rindle.ReadinessWorkflow.guard_identity(ci) == @ci_guard and
        sha256(release) == @release_guard,
      "workflow_policy_drift",
      "approved fork-safe CI or exact-SHA release behavior changed"
    )
  end

  def validate_remote(id, normalized, inputs) do
    validate_workflow_guards!(
      inputs[".github/workflows/ci.yml"],
      inputs[".github/workflows/release.yml"]
    )

    case id do
      "ci-main" ->
        validate_run!(normalized, "CI", "push", "ci.yml", inputs[".github/workflows/ci.yml"])

      "nightly-scheduled" ->
        validate_run!(
          normalized,
          "Nightly",
          "schedule",
          "nightly.yml",
          inputs[".github/workflows/nightly.yml"]
        )

      "protection" ->
        validate_protection!(normalized)
    end

    %{"ok" => true}
  rescue
    _ -> %{"ok" => false, "reason" => "malformed_remote_contract"}
  catch
    {:invalid, id, _detail} -> %{"ok" => false, "reason" => id}
  end

  defp validate_run!(r, name, event, workflow, yaml) do
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

    topology =
      case Rindle.ReadinessWorkflow.derive(yaml, %{
             "repository" => r["repository"],
             "event" => event,
             "branch" => "main"
           }) do
        {:ok, value} -> value
        _ -> throw({:invalid, "unknown_topology", "committed topology unavailable"})
      end

    expected = Enum.map(topology["jobs"], & &1["name"])

    ensure!(
      topology["name"] == name and r["expected_jobs"] == expected and
        r["topology_sha256"] == topology["workflow_sha256"],
      "unknown_topology",
      "unbound topology"
    )

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
        positive?(j["id"]) and j["state"] == "completed" and
          j["conclusion"] ==
            if(Enum.find(topology["jobs"], &(&1["name"] == j["name"]))["applicable"],
              do: "success",
              else: "skipped"
            ),
        "job_outcome",
        "required job did not succeed"
      )
    end)

    if event == "schedule", do: validate_incident!(r, topology)

    ensure!(
      sha?(r["topology_sha256"]) and r["topology_resolved"] === true,
      "unknown_topology",
      "committed topology not resolved"
    )
  end

  defp validate_incident!(r, topology) do
    incident = r["incident"]

    ensure!(
      is_map(incident) and incident["schema"] == "rindle-nightly-incident-verdict-v1" and
        incident["repository"] == r["repository"] and incident["sha"] == r["subject_sha"] and
        incident["workflow_name"] == "Nightly" and incident["event"] == "schedule" and
        incident["workflow_ref"] ==
          r["repository"] <> "/.github/workflows/nightly.yml@refs/heads/main" and
        incident["url"] ==
          "https://github.com/" <> r["repository"] <> "/actions/runs/" <> to_string(r["run_id"]) and
        incident["ref"] == "refs/heads/main" and incident["run_id"] == r["run_id"] and
        incident["run_attempt"] == r["attempt"],
      "incident_identity",
      "wrong scheduled verdict identity"
    )

    verdict = incident["verdict"]
    ids = ~w(compat-matrix dialyzer gcs-soak package-consumer-gcs-live)

    ensure!(
      verdict["verdict"] == "green" and verdict["errors"] == [] and
        Enum.sort(Enum.map(verdict["jobs"], & &1["name"])) == Enum.sort(ids),
      "incident_policy",
      "strict verdict inventory"
    )

    Enum.each(verdict["jobs"], fn j ->
      optional = j["name"] in ~w(gcs-soak package-consumer-gcs-live)

      allowed =
        if j["applicable"] === true do
          j["execution"] == "passed" and j["reason"] == "" and j["status"] == "passed" and
            j["result"] == "success"
        else
          optional and j["applicable"] === false and j["execution"] == "not-run" and
            j["reason"] == "required-secrets-unavailable" and j["status"] == "not-run" and
            j["result"] == "success"
        end

      rule = if optional, do: "upstream-repository-and-required-secrets", else: "always"
      descriptors = Enum.filter(topology["jobs"], &(&1["job_id"] == j["name"]))

      ensure!(
        allowed and j["applicability_rule"] == rule and j["errors"] == [] and descriptors != [] and
          Enum.all?(descriptors, fn d ->
            Enum.any?(r["jobs"], &(&1["name"] == d["name"] and &1["conclusion"] == j["result"]))
          end),
        "incident_policy",
        "invalid applicability or unbound result"
      )
    end)

    ensure!(
      sha?(r["incident_artifact_sha256"]) and positive?(r["incident_artifact_id"]),
      "incident_identity",
      "artifact identity missing"
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
      p["enforced"] === true and p["strict"] === true and p["classic_admin_enforced"] === false and
        p["bypass_actors"] == [] and is_list(p["active_rulesets"]),
      "protection_drift",
      "unexpected enforcement/bypass"
    )

    rulesets = p["active_rulesets"]
    effective = p["effective_rules"] || []

    ensure!(
      is_list(effective) and
        Enum.sort(Enum.map(rulesets, & &1["id"])) ==
          Enum.sort(Enum.uniq(Enum.map(effective, & &1["ruleset_id"]))),
      "protection_drift",
      "effective ruleset coverage differs"
    )

    Enum.each(rulesets, fn ruleset ->
      ensure!(
        positive?(ruleset["id"]) and ruleset["enforcement"] == "active" and
          ruleset["bypass_actors"] == [] and
          is_list(ruleset["rules"]) and ruleset["rules"] != [],
        "protection_drift",
        "ruleset enforcement or bypass changed"
      )

      Enum.each(ruleset["rules"], &validate_required_rule!/1)
    end)

    Enum.each(effective, &validate_required_rule!/1)
  end

  defp validate_required_rule!(rule) do
    parameters = rule["parameters"]

    ensure!(
      rule["type"] == "required_status_checks" and is_map(parameters) and
        parameters["strict_required_status_checks_policy"] === true and
        parameters["required_status_checks"] == [
          %{"context" => "CI Summary", "integration_id" => 15368}
        ],
      "protection_drift",
      "incompatible effective rule"
    )
  end

  defp validate_inventory!(i, m, c, references) do
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

    if m["policy"] == @snapshot_policy do
      ref = i["ledger_file"]

      ensure!(
        is_map(ref) and ref in references and ref["sha256"] == i["ledger_sha256"] and
          subject_sha?(i["authority_main_sha"]),
        "remote_inventory",
        "live ledger identity absent"
      )

      ensure!(
        decode!(object!(ref, c))["repo"] == m["repository"],
        "remote_inventory",
        "live ledger repository differs"
      )
    else
      ensure!(
        i["ledger_sha256"] == m["input_identity"][".planning/INBOX-LEDGER.json"],
        "remote_inventory",
        "ledger identity differs"
      )
    end

    database = sources["hex"]["database"]

    ensure!(
      is_map(database) and database in references and
        database["sha256"] == sources["hex"]["database_sha256"],
      "hex_identity",
      "Hex database reference absent"
    )

    payloads = decode!(object!(database, c))["audits"]

    locks = %{
      "root" => object!(m["input_files"]["mix.lock"], c),
      "examples/adoption_demo" => object!(m["input_files"]["examples/adoption_demo/mix.lock"], c)
    }

    validate_hex_payloads!(payloads, locks)
  end

  def validate_hex(payloads, locks) do
    validate_hex_payloads!(payloads, locks)
    %{"ok" => true}
  rescue
    _ -> %{"ok" => false, "reason" => "hex_identity"}
  catch
    {:invalid, id, _detail} -> %{"ok" => false, "reason" => id}
  end

  defp validate_hex_payloads!(payloads, locks) do
    ensure!(
      is_list(payloads) and
        Enum.sort(Enum.map(payloads, & &1["scope"])) == ~w(examples/adoption_demo root),
      "hex_identity",
      "separate root/demo audits required"
    )

    Enum.each(payloads, fn audit ->
      lock = locks[audit["scope"]]
      {:ok, expected} = Rindle.ReadinessHexAudit.lock_packages(lock)

      ensure!(
        audit["schema"] == "rindle-readiness-hex-v1" and
          Rindle.ReadinessHexAudit.supported_version?(audit["hex_version"]) and
          audit["online"] === true and
          audit["registry_signature_verification"] === true and audit["https_verified"] === true and
          audit["lock_sha256"] == sha256(lock),
        "hex_identity",
        "unverified registry or foreign lock"
      )

      packages = audit["packages"]

      ensure!(
        is_list(packages) and
          Enum.sort(Enum.map(packages, &Map.take(&1, ~w(package version)))) ==
            Enum.sort(Enum.map(expected, &Map.take(&1, ~w(package version)))),
        "hex_identity",
        "partial lock coverage"
      )

      Enum.each(packages, fn p ->
        ensure!(
          p["retired"] === false and is_list(p["advisories"]),
          "hex_identity",
          "retired or unavailable package"
        )
      end)

      records = audit["database"]

      ensure!(
        is_list(records) and length(records) in 1..200_000 and
          length(Enum.uniq_by(records, & &1["key"])) == length(records),
        "hex_identity",
        "invalid database inventory"
      )

      Enum.each(records, fn record ->
        ensure!(
          is_list(record["key"]) and sha?(record["value_sha256"]),
          "hex_identity",
          "invalid database identity"
        )
      end)

      values = Map.new(records, &{&1["key"], &1["value_sha256"]})

      Enum.each(expected, fn package ->
        key = ["outer_checksum", "hexpm", package["package"], package["version"]]
        outer = Base.decode16!(package["outer_checksum"], case: :lower)

        ensure!(
          values[key] == sha256(:erlang.term_to_binary(outer)) and
            sha?(values[["advisories", "hexpm", package["package"], package["version"]]]) and
            sha?(values[["versions", "hexpm", package["package"]]]),
          "hex_identity",
          "database lacks a locked package record"
        )
      end)
    end)
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

    if m["policy"] == @snapshot_policy do
      validate_snapshot_subjects!(e, m, c)
    else
      ensure!(
        e["remote_main_before"] == m["subject_sha"] and
          e["remote_main_after"] == m["subject_sha"],
        "main_changed",
        "refresh main advanced"
      )
    end

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
    ensure!(byte_size(bytes) <= 8_000_000, "object_limit", "JSON object too large")

    case Jason.decode(bytes, objects: :ordered_objects) do
      {:ok, value} ->
        value = normalize_json!(value)
        ensure!(is_map(value), "malformed_json", "receipt must be a JSON object")
        value

      _other ->
        reject!("malformed_json", "receipt must be a JSON object")
    end
  end

  defp normalize_json!(%Jason.OrderedObject{values: values}) do
    keys = Enum.map(values, &elem(&1, 0))

    ensure!(
      length(keys) == length(Enum.uniq(keys)),
      "duplicate_json_key",
      "duplicate JSON object key"
    )

    Map.new(values, fn {key, value} -> {key, normalize_json!(value)} end)
  end

  defp normalize_json!(values) when is_list(values), do: Enum.map(values, &normalize_json!/1)
  defp normalize_json!(value), do: value

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
      ensure!(map_size(acc) < 2000, "graph_limit", "too many evidence objects")
      used = Enum.reduce(acc, 0, fn {_path, bytes}, total -> total + byte_size(bytes) end)
      ensure!(used <= 512_000_000, "graph_limit", "aggregate evidence limit")
      path = ref["path"]
      ensure!(not MapSet.member?(visited, path), "cyclic_reference", "cyclic/self reference")
      bytes = safe_read!(root, path)
      ensure!(used + byte_size(bytes) <= 512_000_000, "graph_limit", "aggregate evidence limit")
      ensure!(sha256(bytes) == ref["sha256"], "object_digest", "corrupt #{path}")
      acc = Map.put(acc, path, bytes)

      # Only readiness proof receipts carry graph edges. Committed policy,
      # package data, logs and upstream JSON remain opaque byte objects.
      if ref["id"] in required_proofs() do
        load_objects!(decode!(bytes), root, acc, MapSet.put(visited, path), depth + 1)
      else
        acc
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
