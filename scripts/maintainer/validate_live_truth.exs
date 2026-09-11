defmodule Rindle.ValidateLiveTruth do
  @moduledoc false

  @schema_version 1
  @ci_file ".github/workflows/ci.yml"
  @nightly_file ".github/workflows/nightly.yml"
  @required_check_policy_file "config/ci_required_checks.json"
  @required_check_policy_schema "rindle-required-checks-v1"
  @required_check "CI Summary"
  @required_needs [
    "quality",
    "optional-dependencies",
    "integration",
    "contract",
    "proof",
    "package-consumer",
    "adoption-demo-unit",
    "adoption-demo-e2e-smoke",
    "adopter",
    "brandbook-tokens",
    "ci-script-tests"
  ]
  @off_critical_path ["adoption-demo-e2e", "cohort-demo-smoke", "package-consumer-full"]
  @nightly_needs ["compat-matrix", "dialyzer", "gcs-soak", "package-consumer-gcs-live"]
  @historical_start "<!-- rindle:historical-receipt:start -->"
  @historical_end "<!-- rindle:historical-receipt:end -->"
  @package_receipt_schema "rindle-package-consumer-v2"
  @package_receipt_fields ~w(
    schema_version evidence_type subject_sha package_name package_version package_sha256
    unpacked_tree_sha256 generated_app_tree_sha256 dependency_lock_sha256 dependency_source
    commands results
  )
  @generated_tree_exclusions [".git", "_build", "deps", "tmp"]
  @independent_adopter_schema "rindle-independent-adopter-v1"
  @independent_adopter_fields ~w(
    schema_version evidence_type authority_id subject_sha evidence_sha256 authorization_scope
  )
  @independent_adopter_authorities %{}

  def run(argv) do
    {options, claim_paths} = parse_options!(argv)
    model = derive!(options.root, historical_markers: options.historical_markers)

    model =
      case options.package_receipt do
        nil -> model
        path -> put_package_proof!(model, path |> File.read!() |> Jason.decode!())
      end

    claims = Enum.flat_map(claim_paths, &read_claims!/1)
    validate_claims!(model, claims)

    if options.format == "json" do
      IO.puts(Jason.encode!(model))
    else
      IO.puts("live truth valid for release #{model.version}")
    end

    :ok
  end

  def derive!(root, options) do
    root = Path.expand(root)
    mix_version = mix_version!(root)
    manifest_version = manifest_version!(root)

    assert!(mix_version == manifest_version, "release authority mismatch")

    ci = root |> workflow!(@ci_file) |> derive_ci!(root)
    nightly = root |> workflow!(@nightly_file) |> derive_nightly!()

    %{
      schema_version: @schema_version,
      version: mix_version,
      version_authorities: %{
        mix_exs: mix_version,
        release_please_manifest: manifest_version
      },
      ci: ci,
      nightly: nightly,
      package_proof: nil,
      authority_root: root,
      historical_boundaries: %{
        archived_prefix: ".planning/milestones/",
        markers: historical_markers(options)
      }
    }
  end

  def validate_claims!(model, claims) when is_list(claims) do
    Enum.each(claims, &validate_claim!(model, &1))
    :ok
  end

  def validate_claims!(model, %{"claims" => claims}), do: validate_claims!(model, claims)
  def validate_claims!(model, %{claims: claims}), do: validate_claims!(model, claims)

  def validate_claims!(_model, _claims) do
    raise ArgumentError, "claims must be a list or a map containing claims"
  end

  defp derive_ci!(workflow, root) do
    policy = required_check_policy!(root)
    required_check = hd(policy.contexts)

    assert!(workflow["name"] == policy.workflow_name, "ci workflow name mismatch")

    assert!(
      trigger_names(workflow) == ["pull_request", "push", "workflow_dispatch"],
      "ci trigger mismatch"
    )

    jobs = Map.fetch!(workflow, "jobs")

    summary =
      Map.get(jobs, policy.job_id) || raise ArgumentError, "required check identity mismatch"

    summary_names = Enum.filter(jobs, fn {_id, job} -> job["name"] == required_check end)

    assert!(summary["name"] == required_check, "required check identity mismatch")
    assert!(length(summary_names) == 1, "required check identity mismatch")
    assert!(summary["if"] == "always()", "required check condition mismatch")
    assert!(summary["needs"] == @required_needs, "CI Summary needs mismatch")

    for job_id <- @off_critical_path do
      job =
        Map.get(jobs, job_id) || raise ArgumentError, "missing off-critical-path lane #{job_id}"

      assert!(
        job["if"] =~ "github.event_name != 'pull_request'",
        "off-critical-path condition mismatch: #{job_id}"
      )

      assert!(
        job_id not in summary["needs"],
        "off-critical-path lane is merge-blocking: #{job_id}"
      )
    end

    for job_id <- ["adoption-demo-e2e-smoke", "package-consumer"] do
      job = Map.fetch!(jobs, job_id)
      assert!(is_nil(job["if"]), "fork safety mismatch: #{job_id}")
      assert!(job_id in summary["needs"], "fork safety mismatch: #{job_id}")
    end

    release_coupling = exact_sha_release_coupling?(root)
    sole_required_check = sole_required_check?(root, policy)
    assert!(release_coupling, "exact-SHA release coupling mismatch")
    assert!(sole_required_check, "sole required check mismatch")

    %{
      workflow_file: @ci_file,
      workflow_name: workflow["name"],
      triggers: trigger_names(workflow),
      required_check: required_check,
      required_check_policy: policy,
      required_needs: summary["needs"],
      off_critical_path: @off_critical_path,
      fork_safe_pr_lanes: ["adoption-demo-e2e-smoke", "package-consumer"],
      exact_sha_release_coupling: release_coupling,
      sole_required_check: sole_required_check
    }
  end

  defp derive_nightly!(workflow) do
    assert!(workflow["name"] == "Nightly", "nightly workflow name mismatch")

    assert!(
      trigger_names(workflow) == ["schedule", "workflow_dispatch"],
      "nightly trigger mismatch"
    )

    jobs = Map.fetch!(workflow, "jobs")
    summary = Map.get(jobs, "nightly-summary") || raise ArgumentError, "missing Nightly Summary"

    assert!(summary["name"] == "Nightly Summary", "nightly required check identity mismatch")
    assert!(summary["if"] == "always()", "nightly summary condition mismatch")
    assert!(summary["needs"] == @nightly_needs, "Nightly Summary needs mismatch")

    assert!(
      Map.keys(summary["outputs"] || %{}) |> Enum.sort() == ["verdict", "verdict-json"],
      "nightly output mismatch"
    )

    applicability =
      Map.new(@nightly_needs, fn job_id ->
        job = Map.fetch!(jobs, job_id)
        outputs = job["outputs"] || %{}

        for output <- ["applicable", "applicability-rule", "execution", "inapplicability-reason"] do
          assert!(
            Map.has_key?(outputs, output),
            "nightly applicability output mismatch: #{job_id}.#{output}"
          )
        end

        rule =
          if job_id in ["gcs-soak", "package-consumer-gcs-live"],
            do: "upstream-repository-and-required-secrets",
            else: "always"

        if rule != "always" do
          steps = job["steps"] || []
          config = Enum.find(steps, &(&1["name"] == "Determine live GCS applicability"))

          assert!(
            config && config["run"] =~ "applicability-rule=#{rule}",
            "nightly applicability rule mismatch: #{job_id}"
          )
        end

        {job_id, rule}
      end)

    %{
      workflow_file: @nightly_file,
      workflow_name: workflow["name"],
      triggers: trigger_names(workflow),
      required_needs: summary["needs"],
      applicability: applicability
    }
  end

  defp validate_claim!(model, claim) when is_map(claim) do
    case field(claim, :type) do
      type when type in [:lane, "lane"] ->
        validate_lane_claim!(model, claim)

      type when type in [:nightly, "nightly"] ->
        validate_nightly_claim!(model, claim)

      type when type in [:package, "package"] ->
        validate_package_claim!(model, claim)

      type when type in [:adoption, "adoption"] ->
        validate_adoption_claim!(model, claim)

      nil ->
        validate_document!(model, claim)

      type ->
        raise ArgumentError, "unclassified claim type: #{inspect(type)}"
    end
  end

  defp validate_claim!(_model, claim),
    do: raise(ArgumentError, "claim must be a map: #{inspect(claim)}")

  defp validate_lane_claim!(model, claim) do
    lane = field(claim, :lane)
    severity = field(claim, :severity)

    expected =
      cond do
        lane in model.ci.required_needs -> "merge-blocking"
        lane in model.ci.off_critical_path -> "off-critical-path"
        true -> raise ArgumentError, "unclassified CI lane: #{inspect(lane)}"
      end

    assert!(
      severity == expected,
      "lane severity mismatch for #{lane}: expected #{expected}, got #{severity}"
    )
  end

  defp validate_nightly_claim!(model, claim) do
    lane = field(claim, :lane)
    applicable = field(claim, :applicable)
    result = field(claim, :result)

    rule =
      model.nightly.applicability[lane] ||
        raise ArgumentError, "unclassified Nightly lane: #{inspect(lane)}"

    valid? =
      case {applicable, result, rule} do
        {true, "passed", _} -> true
        {false, "not-run", "upstream-repository-and-required-secrets"} -> true
        _ -> false
      end

    assert!(valid?, "nightly result mismatch for #{lane}")
  end

  defp validate_package_claim!(model, claim) do
    receipt = field(claim, :receipt) || model.package_proof
    assert!(not is_nil(receipt), "package claim requires a package receipt")
    evidence_context = field(claim, :evidence_context) || %{}

    _proof =
      normalize_package_receipt!(receipt, %{
        repository_root: model.authority_root,
        expected_package_version: model.version,
        package_root: field(evidence_context, :package_root),
        generated_app_root: field(evidence_context, :generated_app_root),
        results_path: field(evidence_context, :results_path)
      })

    :ok
  end

  defp validate_adoption_claim!(model, claim) do
    for key <- [:evidence_kind, :adopter_name, :authorizes_1_0] do
      assert!(
        not has_field?(claim, key),
        "caller-controlled adoption authority is forbidden: #{key}"
      )
    end

    receipt = field(claim, :receipt)
    assert!(is_map(receipt), "adoption claim requires an evidence receipt")
    evidence_context = field(claim, :evidence_context) || %{}

    case field(receipt, :schema_version) do
      @package_receipt_schema ->
        _proof =
          normalize_package_receipt!(receipt, %{
            repository_root: model.authority_root,
            expected_package_version: model.version,
            package_root: field(evidence_context, :package_root),
            generated_app_root: field(evidence_context, :generated_app_root),
            results_path: field(evidence_context, :results_path)
          })

        :ok

      @independent_adopter_schema ->
        _authority = verify_independent_adopter_evidence!(receipt, evidence_context)
        :ok

      _ ->
        raise ArgumentError, "adoption evidence schema mismatch"
    end
  end

  defp validate_document!(model, claim) do
    path = field(claim, :path)
    content = field(claim, :content)

    assert!(is_binary(path) and is_binary(content), "document claim requires path and content")

    unless String.starts_with?(path, model.historical_boundaries.archived_prefix) do
      active_content = active_content!(content, model.historical_boundaries.markers)
      stale_versions = ["0.4.5", "0.4.6"] -- [model.version]

      Enum.each(stale_versions, fn stale ->
        if Regex.match?(~r/(?<![0-9])#{Regex.escape(stale)}(?![0-9])/, active_content) do
          raise ArgumentError, "unmarked stale version #{stale} in #{path}"
        end
      end)
    end
  end

  defp active_content!(content, %{start: start_marker, end: end_marker}) do
    {lines, depth} =
      content
      |> String.split("\n")
      |> Enum.reduce({[], 0}, fn line, {active, depth} ->
        case String.trim(line) do
          ^start_marker when depth == 0 ->
            {active, 1}

          ^start_marker ->
            raise ArgumentError, "malformed historical boundary: nested start marker"

          ^end_marker when depth == 1 ->
            {active, 0}

          ^end_marker ->
            raise ArgumentError, "malformed historical boundary: unmatched end marker"

          _ when depth == 0 ->
            {[line | active], depth}

          _ ->
            {active, depth}
        end
      end)

    assert!(depth == 0, "malformed historical boundary: unmatched start marker")
    lines |> Enum.reverse() |> Enum.join("\n")
  end

  defp put_package_proof!(model, receipt) do
    %{model | package_proof: receipt}
  end

  def normalize_package_receipt!(receipt, context),
    do: verify_package_evidence!(receipt, context)

  def verify_package_evidence!(receipt, context) when is_map(receipt) and is_map(context) do
    receipt = stringify_keys!(receipt, "package receipt")
    context = stringify_keys!(context, "package evidence context")

    assert!(
      Map.keys(receipt) |> Enum.sort() == Enum.sort(@package_receipt_fields),
      "package receipt fields mismatch"
    )

    assert!(
      receipt["schema_version"] == @package_receipt_schema,
      "package receipt schema mismatch"
    )

    assert!(
      receipt["evidence_type"] == "maintainer-operated-package-consumer",
      "package evidence type mismatch"
    )

    repository_root = required_directory!(context["repository_root"], "repository root")
    expected_package_version = required_version_authority!(context["expected_package_version"])
    package_root = required_directory!(context["package_root"], "unpacked package root")
    generated_app_root = required_directory!(context["generated_app_root"], "generated app root")
    results_path = required_file!(context["results_path"], "command result receipt")

    assert!(git_head!(repository_root) == receipt["subject_sha"], "package subject SHA mismatch")
    assert!(receipt["package_name"] == "rindle", "package name mismatch")

    package_mix = required_file!(Path.join(package_root, "mix.exs"), "unpacked package mix.exs")

    package_metadata =
      required_file!(Path.join(package_root, "hex_metadata.config"), "unpacked package metadata")

    assert!(
      not File.exists?(Path.join(package_root, ".git")),
      "repository source fallback is forbidden"
    )

    assert!(
      not File.exists?(Path.join(package_root, ".planning")),
      "repository source fallback is forbidden"
    )

    package_version = package_version!(package_mix)
    assert!(package_version == receipt["package_version"], "package version mismatch")

    assert!(
      receipt["package_version"] == expected_package_version,
      "package version authority mismatch"
    )

    assert!(
      file_sha256!(package_metadata) == receipt["package_sha256"],
      "package digest mismatch"
    )

    unpacked_tree_sha256 = tree_sha256!(package_root, [])

    assert!(
      unpacked_tree_sha256 == receipt["unpacked_tree_sha256"],
      "unpacked tree digest mismatch"
    )

    generated_tree_sha256 = tree_sha256!(generated_app_root, @generated_tree_exclusions)

    assert!(
      generated_tree_sha256 == receipt["generated_app_tree_sha256"],
      "generated app tree digest mismatch"
    )

    generated_mix = required_file!(Path.join(generated_app_root, "mix.exs"), "generated mix.exs")
    dependency_lock = required_file!(Path.join(generated_app_root, "mix.lock"), "dependency lock")

    assert!(
      file_sha256!(dependency_lock) == receipt["dependency_lock_sha256"],
      "dependency lock digest mismatch"
    )

    expected_source = %{
      "type" => "path",
      "package_name" => "rindle",
      "package_version" => expected_package_version,
      "unpacked_tree_sha256" => unpacked_tree_sha256
    }

    assert!(receipt["dependency_source"] == expected_source, "dependency source mismatch")
    assert!(generated_mix_uses_path?(generated_mix, package_root), "dependency source mismatch")

    assert!(
      not File.exists?(Path.join(generated_app_root, "deps/rindle")),
      "generated deps/rindle fallback is forbidden"
    )

    persisted_results = results_path |> File.read!() |> Jason.decode!()
    assert!(receipt["results"] == persisted_results, "package command results mismatch")

    reject_duplicate_command_evidence!(receipt["commands"], persisted_results)

    expected_commands = package_commands!(generated_app_root)
    assert!(receipt["commands"] == expected_commands, "package command argv mismatch")

    verified_results = verify_command_results!(persisted_results)
    lifecycle_proved = command_succeeded?(verified_results["smoke_lifecycle"])

    %{
      schema_version: @package_receipt_schema,
      evidence_type: "maintainer-operated-package-consumer",
      subject_sha: receipt["subject_sha"],
      lifecycle_proved: lifecycle_proved,
      authorizes_independent_adoption: false,
      authorizes_1_0: false
    }
  rescue
    Jason.DecodeError -> raise ArgumentError, "malformed command result receipt"
  end

  def verify_package_evidence!(_receipt, _context),
    do: raise(ArgumentError, "package proof is not a canonical generated consumer receipt")

  def verify_independent_adopter_evidence!(receipt, context)
      when is_map(receipt) and is_map(context) do
    receipt = stringify_keys!(receipt, "independent adopter receipt")
    context = stringify_keys!(context, "independent adopter evidence context")

    assert!(
      Map.keys(receipt) |> Enum.sort() == Enum.sort(@independent_adopter_fields),
      "independent adopter receipt fields mismatch"
    )

    assert!(
      receipt["schema_version"] == @independent_adopter_schema,
      "independent adopter schema mismatch"
    )

    assert!(
      receipt["evidence_type"] == "independent-adopter",
      "independent adopter evidence type mismatch"
    )

    authority =
      Map.get(@independent_adopter_authorities, receipt["authority_id"]) ||
        raise ArgumentError, "independent adopter authority is not allowlisted"

    evidence_path = required_file!(context["evidence_path"], "independent adopter evidence")

    expected = %{
      "subject_sha" => authority.subject_sha,
      "evidence_sha256" => file_sha256!(evidence_path),
      "authorization_scope" => authority.authorization_scope
    }

    assert!(
      receipt["subject_sha"] == expected["subject_sha"],
      "independent adopter subject mismatch"
    )

    assert!(
      receipt["evidence_sha256"] == expected["evidence_sha256"],
      "independent adopter evidence digest mismatch"
    )

    assert!(
      receipt["authorization_scope"] == expected["authorization_scope"],
      "independent adopter authorization scope mismatch"
    )

    %{
      authority_id: receipt["authority_id"],
      subject_sha: expected["subject_sha"],
      evidence_sha256: expected["evidence_sha256"],
      independent_adoption: "independent-adoption" in expected["authorization_scope"],
      authorizes_1_0: "1.0" in expected["authorization_scope"]
    }
  end

  def verify_independent_adopter_evidence!(_receipt, _context),
    do: raise(ArgumentError, "independent adopter evidence must be a receipt and context")

  defp package_version!(mix_path) do
    case Regex.run(~r/@version\s+"([^"]+)"/, File.read!(mix_path), capture: :all_but_first) do
      [version] when version != "" -> version
      _ -> raise ArgumentError, "malformed unpacked package version"
    end
  end

  defp generated_mix_uses_path?(mix_path, package_root) do
    File.read!(mix_path) =~ "{:rindle, path: #{inspect(package_root)}}"
  end

  defp package_commands!(generated_app_root) do
    app_module = generated_app_root |> Path.basename() |> Macro.camelize()
    app_name = Macro.underscore(app_module)

    %{
      "compile" => ["mix", "compile"],
      "boot" => [
        "mix",
        "run",
        "--no-start",
        "-e",
        "Application.ensure_all_started(:#{app_name}); repo = Application.fetch_env!(:rindle, :repo); oban_repo = Application.fetch_env!(:#{app_name}, Oban)[:repo]; if repo != #{app_module}.Repo or oban_repo != #{app_module}.Repo, do: raise(\"boot wiring invalid\"); IO.puts(\"boot ok\")"
      ],
      "smoke_lifecycle" => ["mix", "test", "test/rindle_install_smoke_test.exs"]
    }
  end

  defp verify_command_results!(results) do
    expected_names = ~w(boot compile smoke_lifecycle)

    assert!(
      Map.keys(results) |> Enum.sort() == expected_names,
      "package command result set mismatch"
    )

    Enum.each(expected_names, fn name ->
      result = results[name]

      assert!(
        is_map(result) and
          Map.keys(result) |> Enum.sort() ==
            ~w(captured_bytes exit_code stderr_merged_into_stdout stderr_sha256 stdout_sha256 truncated),
        "package command result fields mismatch: #{name}"
      )

      assert!(result["exit_code"] == 0, "package command failed: #{name}")

      assert!(
        is_binary(result["stdout_sha256"]) and byte_size(result["stdout_sha256"]) == 64,
        "package command stdout digest mismatch: #{name}"
      )

      assert!(
        result["stderr_sha256"] == sha256(""),
        "package command stderr digest mismatch: #{name}"
      )

      assert!(
        result["stderr_merged_into_stdout"] == true,
        "package command capture mode mismatch: #{name}"
      )

      assert!(
        is_integer(result["captured_bytes"]) and result["captured_bytes"] >= 0,
        "package command byte count mismatch: #{name}"
      )

      assert!(
        is_boolean(result["truncated"]),
        "package command truncation marker mismatch: #{name}"
      )
    end)

    results
  end

  defp reject_duplicate_command_evidence!(commands, results)
       when is_map(commands) and is_map(results) do
    separate_slots? =
      Map.has_key?(commands, "smoke") and Map.has_key?(commands, "lifecycle") and
        Map.has_key?(results, "smoke") and Map.has_key?(results, "lifecycle")

    if separate_slots? and
         (commands["smoke"] == commands["lifecycle"] or
            results["smoke"] == results["lifecycle"]) do
      raise ArgumentError,
            "duplicate package command evidence cannot prove smoke and lifecycle independently"
    end

    :ok
  end

  defp reject_duplicate_command_evidence!(_commands, _results), do: :ok

  defp command_succeeded?(result), do: is_map(result) and result["exit_code"] == 0

  defp required_version_authority!(version) when is_binary(version) and version != "", do: version

  defp required_version_authority!(_version),
    do: raise(ArgumentError, "expected package version authority is required")

  defp required_directory!(path, label) do
    assert!(is_binary(path) and path != "" and File.dir?(path), "#{label} does not exist")
    Path.expand(path)
  end

  defp required_file!(path, label) do
    assert!(is_binary(path) and path != "" and File.regular?(path), "#{label} does not exist")
    Path.expand(path)
  end

  defp file_sha256!(path), do: path |> File.read!() |> sha256()

  defp tree_sha256!(root, excluded_roots) do
    entries =
      root
      |> Path.join("**/*")
      |> Path.wildcard(match_dot: true)
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(&Path.relative_to(&1, root))
      |> Enum.reject(fn relative ->
        first = relative |> Path.split() |> List.first()
        first in excluded_roots
      end)
      |> Enum.sort()

    entries
    |> Enum.map(fn relative ->
      relative <> "\0" <> file_sha256!(Path.join(root, relative)) <> "\n"
    end)
    |> IO.iodata_to_binary()
    |> sha256()
  end

  defp git_head!(root) do
    case System.cmd("git", ["-C", root, "rev-parse", "HEAD"], stderr_to_stdout: true) do
      {sha, 0} -> String.trim(sha)
      {_output, _exit_code} -> raise ArgumentError, "package subject repository is not Git"
    end
  end

  defp sha256(content),
    do: :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)

  defp stringify_keys!(map, label) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      string_key = if is_atom(key), do: Atom.to_string(key), else: key
      assert!(is_binary(string_key), "#{label} contains a non-string key")
      assert!(not Map.has_key?(acc, string_key), "#{label} contains duplicate keys")

      normalized =
        cond do
          is_map(value) -> stringify_keys!(value, label)
          is_list(value) -> Enum.map(value, &stringify_value!(&1, label))
          true -> value
        end

      Map.put(acc, string_key, normalized)
    end)
  end

  defp stringify_value!(value, label) when is_map(value), do: stringify_keys!(value, label)

  defp stringify_value!(value, label) when is_list(value),
    do: Enum.map(value, &stringify_value!(&1, label))

  defp stringify_value!(value, _label), do: value

  defp mix_version!(root) do
    path = Path.join(root, "mix.exs")
    assert!(File.regular?(path), "missing release authority: mix.exs")

    if Path.expand(Mix.Project.project_file()) == Path.expand(path) do
      case Mix.Project.config()[:version] do
        version when is_binary(version) and version != "" -> version
        _ -> raise ArgumentError, "malformed release authority: mix.exs"
      end
    else
      case Regex.run(~r/@version\s+"([^"]+)"/, File.read!(path), capture: :all_but_first) do
        [version] when version != "" -> version
        _ -> raise ArgumentError, "malformed release authority: mix.exs"
      end
    end
  end

  defp manifest_version!(root) do
    path = Path.join(root, ".release-please-manifest.json")
    assert!(File.regular?(path), "missing release authority: .release-please-manifest.json")

    case path |> File.read!() |> Jason.decode!() do
      %{"." => version} when is_binary(version) and version != "" -> version
      _ -> raise ArgumentError, "malformed release authority: .release-please-manifest.json"
    end
  rescue
    Jason.DecodeError ->
      raise ArgumentError, "malformed release authority: .release-please-manifest.json"
  end

  defp workflow!(root, path) do
    full_path = Path.join(root, path)
    assert!(File.regular?(full_path), "missing workflow authority: #{path}")
    YamlElixir.read_from_file!(full_path)
  rescue
    error ->
      raise ArgumentError, "malformed workflow authority #{path}: #{Exception.message(error)}"
  end

  defp trigger_names(workflow), do: workflow |> Map.fetch!("on") |> Map.keys() |> Enum.sort()

  def release_run_qualifies?(run, release_sha) when is_map(run) and is_binary(release_sha) do
    field(run, :head_sha) == release_sha and
      field(run, :status) == "completed" and
      field(run, :conclusion) == "success"
  end

  def release_run_qualifies?(_run, _release_sha), do: false

  defp exact_sha_release_coupling?(root) do
    release = workflow!(root, ".github/workflows/release.yml")
    jobs = Map.fetch!(release, "jobs")

    recovery = exact_named_job!(jobs, "recovery-validation", "Validate Recovery Ref")

    assert!(
      recovery["if"] == "${{ github.event_name == 'workflow_dispatch' }}",
      "release recovery condition mismatch"
    )

    assert!(
      recovery["outputs"] == %{
        "checkout_ref" => "${{ steps.validate.outputs.checkout_ref }}",
        "release_tag" => "${{ steps.validate.outputs.release_tag }}"
      },
      "release recovery outputs mismatch"
    )

    validate_step = exact_active_step!(recovery, "validate")

    assert_script_lines!(
      validate_step["run"],
      [
        "echo \"release_tag=$recovery_ref\" >> \"$GITHUB_OUTPUT\""
      ],
      "release recovery step mismatch"
    )

    gate = exact_named_job!(jobs, "gate-ci-green", "Gate on Exact-SHA Green CI")
    assert!(gate["needs"] == ["recovery-validation"], "release gate needs mismatch")

    assert!(
      gate["if"] ==
        "${{ github.event_name == 'workflow_dispatch' && needs.recovery-validation.result == 'success' }}",
      "release gate condition mismatch"
    )

    assert!(
      Map.take(gate["outputs"] || %{}, ["checkout_ref", "release_sha", "ci_run_url"]) == %{
        "checkout_ref" => "${{ steps.resolve.outputs.checkout_ref }}",
        "release_sha" => "${{ steps.resolve.outputs.release_sha }}",
        "ci_run_url" => "${{ steps.ci.outputs.ci_run_url }}"
      },
      "release gate outputs mismatch"
    )

    resolve_step = exact_active_step!(gate, "resolve")

    assert_script_lines!(
      resolve_step["with"]["script"],
      [
        "const ref = '${{ needs.recovery-validation.outputs.checkout_ref }}';",
        "core.setOutput('checkout_ref', ref);",
        "core.setOutput('release_sha', commit.data.sha);"
      ],
      "release SHA resolution mismatch"
    )

    checkout_step =
      exact_active_step_by_name!(gate, "Checkout release target for version resolution")

    assert!(
      checkout_step["with"]["ref"] == "${{ steps.resolve.outputs.checkout_ref }}",
      "release checkout ref mismatch"
    )

    ci_step = exact_active_step!(gate, "ci")

    assert_script_lines!(
      ci_step["with"]["script"],
      [
        "const sha = '${{ steps.resolve.outputs.release_sha }}';",
        "workflow_id: 'ci.yml',",
        "head_sha: sha,",
        "const runs = data.workflow_runs.filter((run) => run.head_sha === sha);",
        "if (latest.conclusion !== 'success') {"
      ],
      "release CI run selection mismatch"
    )

    publish = exact_named_job!(jobs, "publish", "Publish to Hex")

    assert!(
      publish["needs"] == ["recovery-validation", "gate-ci-green"],
      "release publish needs mismatch"
    )

    assert!(
      publish["if"] ==
        "${{ github.event_name == 'workflow_dispatch' && needs.recovery-validation.result == 'success' && needs.gate-ci-green.result == 'success' }}",
      "release publish condition mismatch"
    )

    source_step = exact_active_step!(publish, "release_source")

    assert_script_lines!(
      source_step["run"],
      [
        "git worktree add --detach \"$RELEASE_ROOT\" \"${{ needs.gate-ci-green.outputs.checkout_ref }}\"",
        "echo \"project_root=$RELEASE_ROOT\" >> \"$GITHUB_OUTPUT\""
      ],
      "release source materialization mismatch"
    )

    release_step =
      exact_active_step_by_name!(publish, "Ensure GitHub release exists for dispatch publish")

    assert_script_lines!(
      release_step["run"],
      [
        "--target \"${{ needs.gate-ci-green.outputs.release_sha }}\" \\"
      ],
      "release target SHA mismatch"
    )

    sample_sha = String.duplicate("a", 40)

    assert!(
      release_run_qualifies?(
        %{"head_sha" => sample_sha, "status" => "completed", "conclusion" => "success"},
        sample_sha
      ),
      "release CI evaluator rejected matching SHA"
    )

    assert!(
      not release_run_qualifies?(
        %{
          "head_sha" => String.duplicate("b", 40),
          "status" => "completed",
          "conclusion" => "success"
        },
        sample_sha
      ),
      "release CI evaluator accepted mismatched SHA"
    )

    true
  end

  defp exact_named_job!(jobs, job_id, expected_name) do
    job = Map.get(jobs, job_id) || raise ArgumentError, "missing release job #{job_id}"

    matching_names =
      Enum.filter(jobs, fn {_id, candidate} -> candidate["name"] == expected_name end)

    assert!(length(matching_names) == 1, "duplicate release job #{job_id}")
    assert!(job["name"] == expected_name, "release job name mismatch: #{job_id}")
    job
  end

  defp exact_active_step!(job, step_id) do
    matching = Enum.filter(job["steps"] || [], &(&1["id"] == step_id))
    assert!(length(matching) == 1, "release step cardinality mismatch: #{step_id}")
    [step] = matching
    assert_active_step!(step, step_id)
  end

  defp exact_active_step_by_name!(job, name) do
    matching = Enum.filter(job["steps"] || [], &(&1["name"] == name))
    assert!(length(matching) == 1, "release step cardinality mismatch: #{name}")
    [step] = matching
    assert_active_step!(step, name)
  end

  defp assert_active_step!(step, label) do
    condition = step["if"]

    assert!(
      condition not in [false, "false", "${{ false }}"],
      "release step is unreachable: #{label}"
    )

    step
  end

  defp assert_script_lines!(script, expected_lines, message) when is_binary(script) do
    lines = script |> String.split("\n") |> Enum.map(&String.trim/1)

    Enum.each(expected_lines, fn expected ->
      assert!(Enum.count(lines, fn line -> line == expected end) == 1, message)
    end)

    :ok
  end

  defp assert_script_lines!(_script, _expected_lines, message),
    do: raise(ArgumentError, message)

  defp required_check_policy!(root) do
    path = Path.join(root, @required_check_policy_file)
    assert!(File.regular?(path), "missing required check policy")
    policy = path |> File.read!() |> Jason.decode!()

    assert!(
      Map.keys(policy) |> Enum.sort() == ["contexts", "schema_version", "workflow"],
      "required check policy fields mismatch"
    )

    assert!(
      policy["schema_version"] == @required_check_policy_schema,
      "required check policy schema mismatch"
    )

    workflow = policy["workflow"]

    assert!(
      is_map(workflow) and Map.keys(workflow) |> Enum.sort() == ["file", "job_id", "name"],
      "required check policy workflow fields mismatch"
    )

    assert!(
      workflow["file"] == Path.basename(@ci_file) and workflow["name"] == "CI",
      "required check policy workflow mismatch"
    )

    assert!(workflow["job_id"] == "ci-summary", "required check policy job mismatch")

    assert!(
      policy["contexts"] == [@required_check],
      "required check policy contexts mismatch"
    )

    %{
      schema_version: policy["schema_version"],
      workflow_file: workflow["file"],
      workflow_name: workflow["name"],
      job_id: workflow["job_id"],
      contexts: policy["contexts"]
    }
  rescue
    Jason.DecodeError -> raise ArgumentError, "malformed required check policy"
  end

  defp sole_required_check?(root, policy) do
    script = Path.join(root, "scripts/setup_branch_protection.sh")

    case System.cmd("bash", [script, "--print-expected-json"],
           cd: root,
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        expected = %{
          "required_status_checks" => %{
            "strict" => true,
            "contexts" => policy.contexts
          },
          "enforce_admins" => false,
          "required_pull_request_reviews" => nil,
          "restrictions" => nil,
          "allow_force_pushes" => false,
          "allow_deletions" => false,
          "block_creations" => false,
          "required_conversation_resolution" => false,
          "lock_branch" => false,
          "allow_fork_syncing" => false
        }

        assert!(Jason.decode!(output) == expected, "branch protection policy output mismatch")
        true

      {_output, _status} ->
        raise ArgumentError, "branch protection policy output mismatch"
    end
  rescue
    Jason.DecodeError -> raise ArgumentError, "branch protection policy output mismatch"
  end

  defp historical_markers(options) do
    case Keyword.get(options, :historical_markers, []) do
      [] -> %{start: @historical_start, end: @historical_end}
      [markers] -> markers
      _ -> raise ArgumentError, "only one historical marker pair is supported"
    end
  end

  defp parse_options!(argv) do
    switches = [
      root: :string,
      format: :string,
      package_receipt: :string,
      claims: :keep,
      historical_marker: :keep
    ]

    case OptionParser.parse(argv, strict: switches) do
      {parsed, [], []} ->
        root = parsed |> Keyword.get(:root, File.cwd!()) |> Path.expand()
        format = Keyword.get(parsed, :format, "text")
        assert!(format in ["text", "json"], "format must be text or json")

        markers =
          parsed
          |> Keyword.get_values(:historical_marker)
          |> Enum.map(fn value ->
            case String.split(value, ":", parts: 2) do
              [start_marker, end_marker] when start_marker != "" and end_marker != "" ->
                %{start: start_marker, end: end_marker}

              _ ->
                raise ArgumentError, "historical marker must be START:END"
            end
          end)

        options = %{
          root: root,
          format: format,
          package_receipt: Keyword.get(parsed, :package_receipt),
          historical_markers: markers
        }

        {options, Keyword.get_values(parsed, :claims)}

      {_parsed, positional, invalid} ->
        raise ArgumentError, "invalid arguments: #{inspect(positional ++ invalid)}"
    end
  end

  defp read_claims!(path) do
    content = File.read!(path)

    if Path.extname(path) == ".json" do
      case Jason.decode!(content) do
        claims when is_list(claims) -> claims
        %{"claims" => claims} when is_list(claims) -> claims
        _ -> raise ArgumentError, "claims JSON must be a list or contain claims"
      end
    else
      [%{path: path, content: content}]
    end
  end

  defp field(map, key), do: Map.get(map, key, Map.get(map, Atom.to_string(key)))

  defp has_field?(map, key),
    do: Map.has_key?(map, key) or Map.has_key?(map, Atom.to_string(key))

  defp assert!(true, _message), do: :ok
  defp assert!(false, message), do: raise(ArgumentError, message)
end

if Mix.env() != :test do
  Rindle.ValidateLiveTruth.run(System.argv())
end
