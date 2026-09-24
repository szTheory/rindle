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
  @independent_adopter_schema "rindle-independent-adopter-v1"
  @independent_adopter_fields ~w(
    schema_version evidence_type authority_id subject_sha evidence_sha256 authorization_scope
  )
  @independent_adopter_authorities %{}

  def run(argv) do
    {options, claim_paths} = parse_options!(argv)
    model = derive!(options.root, historical_markers: options.historical_markers)
    claims = Enum.flat_map(claim_paths, &read_claims!/1)
    claims = consume_package_receipt_argument!(options.package_receipt, claims)
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
    cache_key = {__MODULE__, :package_proof_cache}
    prior_cache = Process.get(cache_key, :missing)
    Process.put(cache_key, %{})

    try do
      Enum.each(claims, &validate_claim!(model, &1))
      :ok
    after
      if prior_cache == :missing do
        Process.delete(cache_key)
      else
        Process.put(cache_key, prior_cache)
      end
    end
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
    receipt = field(claim, :receipt)
    assert!(not is_nil(receipt), "package claim requires a package receipt")

    _proof =
      normalize_package_receipt!(receipt, %{
        repository_root: model.authority_root,
        expected_package_version: model.version
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
            expected_package_version: model.version
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

  def normalize_package_receipt!(receipt, context) do
    cache_key = {__MODULE__, :package_proof_cache}

    case Process.get(cache_key) do
      cache when is_map(cache) ->
        cache_entry = sha256(:erlang.term_to_binary({receipt, context}))

        case Map.fetch(cache, cache_entry) do
          {:ok, proof} ->
            proof

          :error ->
            proof = verify_package_evidence!(receipt, context)
            Process.put(cache_key, Map.put(cache, cache_entry, proof))
            proof
        end

      _ ->
        verify_package_evidence!(receipt, context)
    end
  end

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
    subject_sha = git_head!(repository_root)
    assert!(subject_sha == receipt["subject_sha"], "package subject SHA mismatch")
    assert!(receipt["package_name"] == "rindle", "package name mismatch")

    assert!(
      receipt["package_version"] == expected_package_version,
      "package version authority mismatch"
    )

    reject_duplicate_command_evidence!(receipt["commands"], receipt["results"])
    _diagnostic_results = verify_command_results!(receipt["results"])

    trusted = rebuild_package_authority!(repository_root, subject_sha, receipt)
    package = trusted["receipt"]

    assert!(package["package_name"] == "rindle", "package name mismatch")

    assert!(
      package["package_version"] == expected_package_version,
      "package version authority mismatch"
    )

    assert!(receipt["package_sha256"] == package["package_sha256"], "package digest mismatch")

    assert!(
      receipt["unpacked_tree_sha256"] == package["unpacked_tree_sha256"],
      "unpacked package content mismatch"
    )

    expected_source = %{
      "type" => "path",
      "package_name" => "rindle",
      "package_version" => expected_package_version,
      "unpacked_tree_sha256" => package["unpacked_tree_sha256"]
    }

    assert!(receipt["dependency_source"] == expected_source, "dependency source mismatch")
    assert!(receipt["commands"] == package["commands"], "package command argv mismatch")

    assert!(
      receipt["generated_app_tree_sha256"] == package["generated_app_tree_sha256"],
      "generated app tree digest mismatch"
    )

    assert!(
      receipt["dependency_lock_sha256"] == package["dependency_lock_sha256"],
      "dependency lock digest mismatch"
    )

    assert!(
      is_binary(receipt["generated_app_tree_sha256"]) and
        Regex.match?(~r/\A[0-9a-f]{64}\z/, receipt["generated_app_tree_sha256"]),
      "generated app tree digest mismatch"
    )

    assert!(trusted["lifecycle_proved"] == true, "package command failed: smoke_lifecycle")

    lifecycle_proved = true

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

  defp verify_command_results!(results) do
    expected_names = ~w(compile boot smoke_lifecycle)

    assert!(
      Map.keys(results) |> Enum.sort() == Enum.sort(expected_names),
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

  defp rebuild_package_authority!(repository_root, subject_sha, claimed_receipt) do
    workspace_root =
      Path.join(
        System.tmp_dir!(),
        "rindle-live-truth-package-#{subject_sha}-#{System.unique_integer([:positive])}"
      )

    package_root = Path.join(workspace_root, "package")
    File.mkdir_p!(workspace_root)

    try do
      git = absolute_executable!("git")
      mix = absolute_executable!("mix")
      elixir = absolute_executable!("elixir")
      erl = absolute_executable!("erl")

      assert_package_inputs_match_subject!(git, repository_root, subject_sha)

      {build_output, build_exit} =
        run_private_mix!(
          mix,
          repository_root,
          [
            "hex.build",
            "--unpack",
            "--output",
            package_root
          ],
          private_package_env("dev", package_root, mix, git, elixir, erl)
        )

      assert!(
        build_exit == 0,
        "subject package build failed via #{mix}: #{String.slice(build_output, 0, 2500)}"
      )

      assert!(
        File.regular?(Path.join(package_root, "mix.exs")),
        "package subject snapshot failed"
      )

      assert!(
        File.regular?(Path.join(package_root, "hex_metadata.config")),
        "package subject snapshot failed"
      )

      assert_package_matches_subject!(git, repository_root, subject_sha, package_root)

      assert!(
        package_version!(Path.join(package_root, "mix.exs")) ==
          claimed_receipt["package_version"],
        "package version mismatch"
      )

      actual_tree_sha256 = tree_sha256!(package_root, [])

      assert!(
        claimed_receipt["package_sha256"] ==
          file_sha256!(Path.join(package_root, "hex_metadata.config")),
        "package digest mismatch"
      )

      assert!(
        claimed_receipt["unpacked_tree_sha256"] == actual_tree_sha256,
        "unpacked package content mismatch"
      )

      helper_script =
        """
        Code.require_file(#{inspect(Path.join(repository_root, "test/install_smoke/support/generated_app_helper.ex"))})
        report = Rindle.InstallSmoke.GeneratedAppHelper.prove_package_install!(:image)
        try do
          IO.puts("__RINDLE_PACKAGE_AUTHORITY__" <> Jason.encode!(%{
            receipt: report.package_evidence_receipt,
            lifecycle_proved: report.lifecycle_proved? and report.smoke_exit_code == 0
          }))
        after
          Rindle.InstallSmoke.GeneratedAppHelper.cleanup(report)
        end
        """

      {output, helper_exit} =
        run_private_mix!(
          mix,
          repository_root,
          [
            "run",
            "--no-compile",
            "--no-deps-check",
            "-e",
            helper_script
          ],
          private_package_env("test", package_root, mix, git, elixir, erl, true) ++
            [{"RINDLE_INSTALL_SMOKE_PACKAGE_ROOT", package_root}]
        )

      assert!(
        helper_exit == 0,
        "package lifecycle rebuild failed: #{String.slice(output, 0, 500)}"
      )

      proof_line =
        output
        |> String.split("\n", trim: true)
        |> Enum.find(&String.starts_with?(&1, "__RINDLE_PACKAGE_AUTHORITY__"))

      assert!(is_binary(proof_line), "package authority rebuild failed")
      encoded = String.replace_prefix(proof_line, "__RINDLE_PACKAGE_AUTHORITY__", "")
      Jason.decode!(encoded)
    rescue
      error ->
        raise ArgumentError, "package authority rebuild failed: #{Exception.message(error)}"
    after
      File.rm_rf(workspace_root)
    end
  end

  defp run_private_mix!(mix, cwd, args, environment) do
    System.cmd(mix, args,
      cd: cwd,
      env: environment,
      stderr_to_stdout: true
    )
  end

  defp private_package_env(
         mix_env,
         _package_root,
         mix,
         git,
         elixir,
         erl,
         include_test_services \\ false
       ) do
    keys = ~w(HOME MIX_HOME HEX_HOME)

    service_keys =
      if include_test_services,
        do:
          ~w(RINDLE_MINIO_URL RINDLE_MINIO_BUCKET RINDLE_MINIO_ACCESS_KEY RINDLE_MINIO_SECRET_KEY RINDLE_MINIO_REGION),
        else: []

    inherited =
      (keys ++ service_keys)
      |> Enum.flat_map(fn key ->
        case System.get_env(key) do
          value when is_binary(value) -> [{key, value}]
          _ -> []
        end
      end)

    path =
      [
        Path.dirname(erl),
        Path.dirname(elixir),
        Path.dirname(mix),
        Path.dirname(git),
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin"
      ]
      |> Enum.uniq()
      |> Enum.join(":")

    unset = System.get_env() |> Map.keys() |> Enum.map(&{&1, nil})

    unset ++
      inherited ++
      [
        {"PATH", path},
        {"MIX_ENV", mix_env},
        {"RINDLE_AV_USE_CGROUPS", "false"}
      ]
  end

  defp absolute_executable!(name) do
    case System.find_executable(name) do
      path when is_binary(path) -> Path.expand(path)
      _ -> raise ArgumentError, "package authority rebuild failed"
    end
  end

  # Keep this list aligned with the package `files` declaration in mix.exs. The
  # manifest itself is checked against the authenticated commit before use.
  @package_paths ~w(lib priv/repo/migrations priv/static/rindle_admin mix.exs README.md RUNNING.md CHANGELOG.md LICENSE guides)

  defp assert_package_inputs_match_subject!(git, repository_root, subject_sha) do
    manifest = git_show!(git, repository_root, subject_sha, "mix.exs")

    assert!(
      File.read!(Path.join(repository_root, "mix.exs")) == manifest,
      "package subject snapshot failed"
    )

    subject_files = git_package_paths!(git, repository_root, subject_sha)
    assert!(subject_files != [], "package subject snapshot failed")

    Enum.each(subject_files, fn relative ->
      current = Path.join(repository_root, relative)
      assert!(File.regular?(current), "package subject snapshot failed")

      assert!(
        File.read!(current) == git_show!(git, repository_root, subject_sha, relative),
        "package subject snapshot failed"
      )
    end)
  end

  defp assert_package_matches_subject!(git, repository_root, subject_sha, package_root) do
    expected = git_package_paths!(git, repository_root, subject_sha) |> MapSet.new()

    actual =
      package_root
      |> Path.join("**/*")
      |> Path.wildcard(match_dot: true)
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(&Path.relative_to(&1, package_root))
      |> Enum.reject(&(&1 == "hex_metadata.config"))
      |> MapSet.new()

    assert!(actual == expected, "unpacked package content mismatch")

    Enum.each(expected, fn relative ->
      expected_bytes = git_show!(git, repository_root, subject_sha, relative)
      actual_bytes = File.read!(Path.join(package_root, relative))
      assert!(actual_bytes == expected_bytes, "unpacked package content mismatch")
    end)
  end

  defp git_package_paths!(git, repository_root, subject_sha) do
    args = [
      "-C",
      repository_root,
      "ls-tree",
      "-r",
      "-z",
      "--name-only",
      subject_sha,
      "--" | @package_paths
    ]

    case System.cmd(git, args, stderr_to_stdout: true) do
      {output, 0} -> output |> String.split(<<0>>, trim: true) |> Enum.sort()
      _ -> raise ArgumentError, "package subject snapshot failed"
    end
  end

  defp git_show!(git, repository_root, subject_sha, relative) do
    case System.cmd(git, ["-C", repository_root, "show", "#{subject_sha}:#{relative}"],
           stderr_to_stdout: true
         ) do
      {content, 0} -> content
      _ -> raise ArgumentError, "package subject snapshot failed"
    end
  end

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
      content = File.read!(Path.join(root, relative)) |> canonical_generated_app_content(relative)
      relative <> "\0" <> sha256(content) <> "\n"
    end)
    |> IO.iodata_to_binary()
    |> sha256()
  end

  defp canonical_generated_app_content(content, relative) do
    if relative in ["config/dev.exs", "config/test.exs", "config/config.exs"] or
         String.ends_with?(relative, "_web/endpoint.ex") do
      content =
        Regex.replace(~r/(secret_key_base:\s*)"[^"]+"/, content, "\\1\"<generated-secret>\"")

      Regex.replace(~r/(signing_salt:\s*)"[^"]+"/, content, "\\1\"<generated-salt>\"")
    else
      content
    end
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

  defp consume_package_receipt_argument!(nil, claims) do
    if Enum.any?(claims, &package_receipt_argument_consumer?/1) do
      raise ArgumentError, "package receipt consumer requires --package-receipt"
    end

    claims
  end

  defp consume_package_receipt_argument!(path, claims) do
    receipt = read_package_receipt!(path)

    consumers =
      Enum.with_index(claims)
      |> Enum.filter(fn {claim, _index} -> package_receipt_argument_consumer?(claim) end)

    assert!(
      length(consumers) == 1,
      "package receipt argument must be consumed exactly once"
    )

    [{consumer, index}] = consumers
    validate_package_receipt_consumer!(consumer, receipt)

    List.update_at(claims, index, fn claim ->
      claim |> Map.delete(:receipt) |> Map.put("receipt", receipt)
    end)
  end

  defp package_receipt_argument_consumer?(claim) when is_map(claim),
    do: field(claim, :receipt_source) == "package-receipt-argument"

  defp package_receipt_argument_consumer?(_claim), do: false

  defp validate_package_receipt_consumer!(claim, receipt) do
    type = field(claim, :type)

    assert!(
      type in [:package, "package", :adoption, "adoption"],
      "package receipt argument consumer type mismatch"
    )

    inline_receipt = field(claim, :receipt)

    if not is_nil(inline_receipt) and
         stringify_keys!(inline_receipt, "package receipt") != receipt do
      raise ArgumentError, "package receipt argument disagrees with inline receipt"
    end

    evidence_context = field(claim, :evidence_context)

    assert!(
      is_map(evidence_context) and
        Enum.all?(
          [:package_root, :generated_app_root, :results_path, :execution_env],
          &has_field?(evidence_context, &1)
        ),
      "package receipt consumer requires complete evidence context"
    )

    if type in [:adoption, "adoption"] do
      assert!(
        field(receipt, :schema_version) == @package_receipt_schema,
        "package receipt argument adoption consumer requires maintainer package evidence"
      )
    end

    :ok
  end

  defp read_package_receipt!(path) when is_binary(path) and path != "" do
    receipt = path |> File.read!() |> Jason.decode!()
    assert!(is_map(receipt), "package receipt JSON must be an object")
    stringify_keys!(receipt, "package receipt")
  rescue
    Jason.DecodeError -> raise ArgumentError, "malformed package receipt JSON"
    File.Error -> raise ArgumentError, "package receipt could not be read"
  end

  defp read_package_receipt!(_path),
    do: raise(ArgumentError, "package receipt path is required")

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
