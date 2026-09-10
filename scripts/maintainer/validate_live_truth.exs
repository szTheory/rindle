defmodule Rindle.ValidateLiveTruth do
  @moduledoc false

  @schema_version 1
  @ci_file ".github/workflows/ci.yml"
  @nightly_file ".github/workflows/nightly.yml"
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
  @package_receipt_schema "rindle-package-consumer-v1"
  @package_receipt_fields ~w(
    schema_version evidence_type subject_sha package_name package_version package_sha256
    unpacked_tree_sha256 generated_app_tree_sha256 dependency_lock_sha256 dependency_source
    commands results
  )
  @generated_tree_exclusions [".git", "_build", "deps", "tmp"]

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
    assert!(workflow["name"] == "CI", "ci workflow name mismatch")

    assert!(
      trigger_names(workflow) == ["pull_request", "push", "workflow_dispatch"],
      "ci trigger mismatch"
    )

    jobs = Map.fetch!(workflow, "jobs")

    summary =
      Map.get(jobs, "ci-summary") || raise ArgumentError, "required check identity mismatch"

    summary_names = Enum.filter(jobs, fn {_id, job} -> job["name"] == @required_check end)

    assert!(summary["name"] == @required_check, "required check identity mismatch")
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
    sole_required_check = sole_required_check?(root)
    assert!(release_coupling, "exact-SHA release coupling mismatch")
    assert!(sole_required_check, "sole required check mismatch")

    %{
      workflow_file: @ci_file,
      workflow_name: workflow["name"],
      triggers: trigger_names(workflow),
      required_check: @required_check,
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

      type when type in [:package, "package", :adoption, "adoption"] ->
        validate_package_claim!(model, claim)

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
        package_root: field(evidence_context, :package_root),
        generated_app_root: field(evidence_context, :generated_app_root),
        results_path: field(evidence_context, :results_path)
      })

    validate_adoption_scope!(claim)
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

    assert!(
      package_version!(package_mix) == receipt["package_version"],
      "package version mismatch"
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
      "unpacked_tree_sha256" => unpacked_tree_sha256
    }

    assert!(receipt["dependency_source"] == expected_source, "dependency source mismatch")
    assert!(generated_mix_uses_path?(generated_mix, package_root), "dependency source mismatch")

    assert!(
      not File.exists?(Path.join(generated_app_root, "deps/rindle")),
      "generated deps/rindle fallback is forbidden"
    )

    expected_commands = package_commands!(generated_app_root)
    assert!(receipt["commands"] == expected_commands, "package command argv mismatch")

    persisted_results = results_path |> File.read!() |> Jason.decode!()
    assert!(receipt["results"] == persisted_results, "package command results mismatch")
    verify_command_results!(persisted_results)

    %{
      schema_version: @package_receipt_schema,
      evidence_type: "maintainer-operated-package-consumer",
      subject_sha: receipt["subject_sha"],
      lifecycle_proved: true,
      authorizes_independent_adoption: false,
      authorizes_1_0: false
    }
  rescue
    Jason.DecodeError -> raise ArgumentError, "malformed command result receipt"
  end

  def verify_package_evidence!(_receipt, _context),
    do: raise(ArgumentError, "package proof is not a canonical generated consumer receipt")

  defp validate_adoption_scope!(claim) do
    case field(claim, :type) do
      type when type in [:adoption, "adoption"] ->
        evidence_kind = field(claim, :evidence_kind)
        authorizes_1_0 = field(claim, :authorizes_1_0)

        cond do
          evidence_kind == "maintainer-operated-synthetic" and authorizes_1_0 == true ->
            raise ArgumentError, "synthetic evidence cannot authorize 1.0"

          evidence_kind == "maintainer-operated-synthetic" and authorizes_1_0 == false ->
            :ok

          evidence_kind == "independent-adopter" and
              not (is_binary(field(claim, :adopter_name)) and field(claim, :adopter_name) != "") ->
            raise ArgumentError,
                  "independent adopter claim requires named independent evidence"

          evidence_kind == "independent-adopter" and authorizes_1_0 in [true, false] ->
            :ok

          true ->
            raise ArgumentError, "unclassified adoption evidence"
        end

      _ ->
        :ok
    end
  end

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
      "smoke" => ["mix", "test", "test/rindle_install_smoke_test.exs"],
      "lifecycle" => ["mix", "test", "test/rindle_install_smoke_test.exs"]
    }
  end

  defp verify_command_results!(results) do
    expected_names = ~w(boot compile lifecycle smoke)

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

    :ok
  end

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

  defp exact_sha_release_coupling?(root) do
    release = Path.join(root, ".github/workflows/release.yml") |> File.read!()

    release =~ "workflow_id: 'ci.yml'" and
      release =~ "head_sha: sha" and
      release =~ "run.head_sha === sha" and
      release =~ "latest.conclusion !== 'success'"
  end

  defp sole_required_check?(root) do
    branch_protection = Path.join(root, "scripts/setup_branch_protection.sh") |> File.read!()

    case Regex.run(~r/REQUIRED_CHECKS=\(\s*"([^"]+)"\s*\)/s, branch_protection,
           capture: :all_but_first
         ) do
      [@required_check] -> true
      _ -> false
    end
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

  defp assert!(true, _message), do: :ok
  defp assert!(false, message), do: raise(ArgumentError, message)
end

if Mix.env() != :test do
  Rindle.ValidateLiveTruth.run(System.argv())
end
