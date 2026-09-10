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
    proof = normalize_package_receipt!(receipt)

    case proof.install_mode do
      "package" ->
        assert!(
          proof.install_source == proof.unpacked_path,
          "install source does not match unpacked package"
        )

        assert!(proof.deps_rindle_present == false, "generated deps/rindle fallback is forbidden")

      "network" ->
        assert!(
          proof.install_source == "hex:#{model.version}",
          "install source does not match current Hex release"
        )

        assert!(
          String.ends_with?(proof.unpacked_path, "/deps/rindle"),
          "network package proof did not inspect fetched deps/rindle"
        )
    end

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

  defp normalize_package_receipt!(receipt) when is_map(receipt) do
    assert!(
      field(receipt, :proof_origin) == "generated-app-helper",
      "package proof is not a generated consumer report"
    )

    provenance = field(receipt, :package_root_provenance)
    install_mode = normalize_install_mode(field(receipt, :install_mode))
    install_source = field(receipt, :install_source)
    unpacked_path = field(provenance || %{}, :path)
    unpacked = field(provenance || %{}, :unpacked?)
    provenance_repository_fallback = field(provenance || %{}, :repository_path_fallback?)

    complete? =
      is_map(provenance) and install_mode in ["package", "network"] and
        is_binary(install_source) and install_source != "" and is_binary(unpacked_path) and
        unpacked_path != "" and is_binary(field(receipt, :generated_app_root)) and
        is_boolean(unpacked) and is_boolean(provenance_repository_fallback) and
        is_boolean(field(receipt, :repository_path_fallback)) and
        is_boolean(field(receipt, :prebuilt_local_fallback)) and
        is_boolean(field(receipt, :deps_rindle_present)) and
        is_integer(field(receipt, :compile_exit_code)) and
        is_integer(field(receipt, :boot_exit_code)) and
        is_integer(field(receipt, :smoke_exit_code)) and
        is_boolean(field(receipt, :lifecycle_proved))

    assert!(complete?, "generated consumer proof is incomplete")

    assert!(
      field(receipt, :repository_path_fallback) == false,
      "repository source fallback is forbidden"
    )

    assert!(provenance_repository_fallback == false, "repository source fallback is forbidden")

    assert!(
      field(receipt, :prebuilt_local_fallback) == false,
      "prebuilt local fallback is forbidden"
    )

    assert!(unpacked == true, "unpacked package evidence is required")
    assert!(File.dir?(unpacked_path), "unpacked package path does not exist")

    assert!(
      File.dir?(field(receipt, :generated_app_root)),
      "generated consumer root does not exist"
    )

    assert!(field(receipt, :compile_exit_code) == 0, "generated consumer compile failed")
    assert!(field(receipt, :boot_exit_code) == 0, "generated consumer boot failed")
    assert!(field(receipt, :smoke_exit_code) == 0, "generated consumer smoke failed")

    assert!(
      field(receipt, :lifecycle_proved) == true,
      "generated consumer lifecycle proof failed"
    )

    if install_mode == "package" do
      assert!(
        File.regular?(Path.join(unpacked_path, "hex_metadata.config")),
        "unpacked package metadata is missing"
      )

      assert!(
        File.regular?(Path.join(unpacked_path, "mix.exs")),
        "unpacked package mix.exs is missing"
      )

      assert!(
        not File.exists?(Path.join(unpacked_path, ".git")),
        "repository source fallback is forbidden"
      )

      assert!(
        not File.exists?(Path.join(unpacked_path, ".planning")),
        "repository source fallback is forbidden"
      )
    end

    %{
      install_mode: install_mode,
      install_source: install_source,
      unpacked: unpacked,
      unpacked_path: unpacked_path,
      repository_path_fallback: false,
      prebuilt_local_fallback: false,
      deps_rindle_present: field(receipt, :deps_rindle_present)
    }
  end

  defp normalize_package_receipt!(_receipt),
    do: raise(ArgumentError, "package proof is not a generated consumer report")

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

  defp normalize_install_mode(:package), do: "package"
  defp normalize_install_mode(:network), do: "network"
  defp normalize_install_mode("package"), do: "package"
  defp normalize_install_mode("network"), do: "network"
  defp normalize_install_mode(_mode), do: nil

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
