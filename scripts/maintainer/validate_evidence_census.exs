defmodule Rindle.ValidateEvidenceCensus do
  @moduledoc false

  @dimensions [
    "correctness",
    "maintainability",
    "security",
    "performance",
    "reliability",
    "compatibility",
    "testing",
    "documentation/accessibility",
    "packaging",
    "CI/CD",
    "release engineering",
    "repository hygiene"
  ]
  @dispositions ["fix", "retain", "defer"]
  @inapplicable_dimensions %{
    "performance" => "not exercised by the minimal tracer fixture"
  }
  @detector_registry [
    {"default-exunit", "correctness", "mix test", ["mix.exs"]},
    {"credo-quality", "maintainability", "mix credo_quality",
     ["scripts/maintainer/credo_complexity_baseline.json", "scripts/maintainer/credo_quality.sh"]},
    {"mix-audit", "security", "mix deps.audit", ["mix.exs", "mix.lock"]},
    {"pr-timing", "performance", "validate accepted PR timing receipt",
     [
       ".planning/milestones/v1.25-phases/132-measured-closure/132-02-SUMMARY.md"
     ]},
    {"nightly-policy", "reliability", "evaluate Nightly evidence",
     [".github/workflows/nightly.yml"]},
    {"supported-toolchain", "compatibility", "verify supported toolchain matrix",
     [".tool-versions", ".github/workflows/nightly.yml"]},
    {"automation-first", "testing", "./scripts/maintainer/automation_first_contract.sh",
     ["RUNNING.md", "scripts/maintainer/automation_first_contract.sh"]},
    {"docs-accessibility", "documentation/accessibility", "mix doctor --full --raise",
     ["RUNNING.md", "scripts/maintainer/refactor_contract.sh"]},
    {"package-consumer", "packaging", "mix hex.build --unpack",
     ["mix.exs", "test/install_smoke/package_metadata_test.exs"]},
    {"workflow-topology", "CI/CD", "validate CI workflow topology",
     [".github/workflows/ci.yml", ".github/workflows/nightly.yml"]},
    {"release-authority", "release engineering", "validate exact-SHA release coupling",
     [".release-please-manifest.json", ".github/workflows/release.yml", "mix.exs"]},
    {"repository-hygiene", "repository hygiene", "./scripts/maintainer/repo_hygiene_check.sh",
     ["scripts/maintainer/repo_hygiene_check.sh"]}
  ]

  def run(argv) do
    with {:ok, options} <- parse_options(argv),
         {:ok, ledger} <- decode_json(options.ledger, "ledger"),
         {:ok, receipt} <- decode_json(options.receipt, "receipt"),
         {:ok, head} <- git(options.root, ["rev-parse", "HEAD"]),
         :ok <- validate_schema(ledger, receipt),
         :ok <- validate_authority(ledger, receipt, head),
         :ok <- validate_taxonomy(ledger),
         :ok <- validate_observation_locations(ledger, options.root),
         :ok <- validate_detectors(ledger),
         :ok <- validate_transition_contract(ledger),
         :ok <- validate_candidates(ledger, options.root),
         :ok <- validate_receipt(ledger, receipt, options.root) do
      IO.puts("evidence census valid for #{head}")
      :ok
    end
  end

  def validate_ledger_contract(ledger, root) when is_map(ledger) do
    with :ok <- validate_schema(ledger, %{"schema_version" => 1}),
         :ok <- validate_taxonomy(ledger),
         :ok <- validate_observation_locations(ledger, root),
         :ok <- validate_detectors(ledger),
         :ok <- validate_transition_contract(ledger),
         :ok <- validate_candidates(ledger, root) do
      :ok
    end
  end

  def validate_ledger_contract(_ledger, _root), do: {:error, "ledger must be an object"}

  defp parse_options(argv) do
    case OptionParser.parse(argv, strict: [root: :string, ledger: :string, receipt: :string]) do
      {options, [], []} ->
        values = Map.new(options)

        with {:ok, root} <- required(values, :root),
             {:ok, ledger} <- required(values, :ledger),
             {:ok, receipt} <- required(values, :receipt) do
          {:ok,
           %{root: Path.expand(root), ledger: Path.expand(ledger), receipt: Path.expand(receipt)}}
        end

      {_options, positional, invalid} ->
        {:error, "unexpected arguments: #{inspect(positional ++ invalid)}"}
    end
  end

  defp required(values, key) do
    case Map.get(values, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "missing required --#{key}"}
    end
  end

  defp decode_json(path, label) do
    with {:ok, contents} <- File.read(path),
         {:ok, value} when is_map(value) <- Jason.decode(contents) do
      {:ok, value}
    else
      {:error, reason} -> {:error, "cannot read #{label} #{path}: #{inspect(reason)}"}
      _ -> {:error, "#{label} must contain one JSON object"}
    end
  end

  defp git(root, args) do
    case System.cmd("git", args, cd: root, stderr_to_stdout: true) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _} -> {:error, "git command failed: #{String.trim(output)}"}
    end
  end

  defp validate_schema(%{"schema_version" => 1}, %{"schema_version" => 1}), do: :ok
  defp validate_schema(_ledger, _receipt), do: {:error, "unsupported schema_version"}

  defp validate_authority(ledger, receipt, head) do
    cond do
      not sha?(head) ->
        {:error, "repository HEAD is not an immutable commit SHA"}

      ledger["subject_sha"] != head ->
        {:error, "ledger subject SHA does not match repository HEAD"}

      receipt["source_sha"] != head ->
        {:error, "receipt source SHA does not match repository HEAD"}

      receipt["dirty"] != false ->
        {:error, "diagnostic dirty receipt is not authoritative"}

      true ->
        :ok
    end
  end

  defp validate_taxonomy(%{"taxonomy" => taxonomy}) when is_list(taxonomy) do
    ids = Enum.map(taxonomy, & &1["id"])

    cond do
      Enum.sort(ids) != Enum.sort(@dimensions) ->
        {:error, "taxonomy must contain exactly the twelve locked dimensions"}

      length(ids) != length(Enum.uniq(ids)) ->
        {:error, "taxonomy contains duplicate dimensions"}

      not Enum.all?(taxonomy, &valid_taxonomy_shape?/1) ->
        {:error, "taxonomy applicability record is incomplete"}

      not Enum.all?(taxonomy, &authorized_applicability?/1) ->
        {:error, "taxonomy inapplicability is not repository-authorized"}

      true ->
        :ok
    end
  end

  defp validate_taxonomy(_), do: {:error, "taxonomy must be an array"}

  defp valid_taxonomy_shape?(%{"applicable" => true, "detectors" => detectors}),
    do: nonempty_unique_strings?(detectors)

  defp valid_taxonomy_shape?(%{
         "applicable" => false,
         "detectors" => []
       }),
       do: true

  defp valid_taxonomy_shape?(_), do: false

  defp authorized_applicability?(%{"applicable" => true}), do: true

  defp authorized_applicability?(%{
         "id" => dimension,
         "applicable" => false,
         "rationale" => rationale
       }),
       do: Map.get(@inapplicable_dimensions, dimension) == rationale

  defp authorized_applicability?(_), do: false

  defp validate_detectors(%{"taxonomy" => taxonomy, "detectors" => detectors})
       when is_list(detectors) and is_list(taxonomy) do
    detector_ids = Enum.map(detectors, & &1["id"])
    declared_ids = Enum.flat_map(taxonomy, & &1["detectors"])
    applicable = taxonomy |> Enum.filter(& &1["applicable"]) |> Map.new(&{&1["id"], true})
    raw_observations = Enum.flat_map(detectors, &(&1["observations"] || []))

    cond do
      detectors == [] ->
        {:error, "at least one detector is required"}

      not nonempty_unique_strings?(detector_ids) ->
        {:error, "detector IDs must be unique non-empty strings"}

      length(raw_observations) != length(Enum.uniq_by(raw_observations, &canonical_json/1)) ->
        {:error, "normalized observations contain duplicates"}

      not Enum.all?(raw_observations, &integer_count_attributes?(&1["attributes"])) ->
        {:error, "observation count attributes must be integers"}

      not valid_dimension_authority?(taxonomy, detectors) ->
        {:error, "detector authority differs from repository-owned registry"}

      Enum.sort(detector_ids) != Enum.sort(declared_ids) ->
        {:error, "taxonomy detector assignment is not bijective"}

      not Enum.all?(detectors, &valid_detector?(&1, applicable)) ->
        {:error, "detector record is incomplete or assigned to an inapplicable dimension"}

      true ->
        :ok
    end
  end

  defp validate_detectors(_), do: {:error, "detectors must be an array"}

  defp valid_detector?(detector, applicable) do
    nonempty_string?(detector["id"]) and Map.get(applicable, detector["dimension"], false) and
      nonempty_string?(detector["command"]) and nonempty_unique_strings?(detector["inputs"]) and
      is_list(detector["observations"]) and detector["observations"] != [] and
      Enum.all?(detector["observations"], &valid_observation?/1)
  end

  defp valid_dimension_authority?(taxonomy, detectors) do
    detector_by_dimension = Map.new(detectors, &{&1["dimension"], &1})

    registry_by_dimension =
      Map.new(@detector_registry, fn {_id, dimension, _command, _inputs} = row ->
        {dimension, row}
      end)

    Enum.all?(taxonomy, fn
      %{"applicable" => false} ->
        true

      %{"id" => dimension, "applicable" => true, "detectors" => declared_ids} ->
        case {Map.get(registry_by_dimension, dimension),
              Map.get(detector_by_dimension, dimension)} do
          {{id, ^dimension, command, inputs}, detector} when is_map(detector) ->
            declared_ids == [id] and
              canonical_detector_authority(detector) == %{
                "id" => id,
                "dimension" => dimension,
                "command" => command,
                "inputs" => Enum.sort(inputs)
              }

          _ ->
            false
        end

      _ ->
        false
    end)
  end

  defp canonical_detector_authority(detector) do
    detector
    |> Map.take(["id", "dimension", "command", "inputs"])
    |> Map.update("inputs", [], &Enum.sort/1)
  end

  defp valid_observation?(observation) do
    nonempty_string?(observation["id"]) and nonempty_string?(observation["kind"]) and
      nonempty_string?(observation["location"]) and
      Path.type(observation["location"]) == :relative and
      nonempty_string?(observation["status"]) and is_map(observation["attributes"])
  end

  defp integer_count_attributes?(attributes) when is_map(attributes) do
    Enum.all?(attributes, fn {key, value} ->
      if key == "count" or String.ends_with?(key, "_count") do
        is_integer(value)
      else
        integer_count_attributes?(value)
      end
    end)
  end

  defp integer_count_attributes?(attributes) when is_list(attributes),
    do: Enum.all?(attributes, &integer_count_attributes?/1)

  defp integer_count_attributes?(_value), do: true

  defp validate_transition_contract(%{
         "candidate_baseline" => baseline,
         "candidates" => candidates,
         "phase_133_transitions" => transitions
       })
       when is_list(baseline) and is_list(candidates) and is_list(transitions) do
    baseline_ids = Enum.map(baseline, & &1["id"])
    candidate_ids = Enum.map(candidates, & &1["id"])
    transition_ids = Enum.map(transitions, & &1["candidate_id"])

    changed_ids =
      Enum.flat_map(candidates, fn candidate ->
        baseline_entry = Enum.find(baseline, &(&1["id"] == candidate["id"]))

        if baseline_entry &&
             baseline_entry["observations_digest"] !=
               observations_digest(candidate["observations"] || []) do
          [candidate["id"]]
        else
          []
        end
      end)

    cond do
      not nonempty_unique_strings?(baseline_ids) ->
        {:error, "candidate baseline IDs must be unique non-empty strings"}

      not nonempty_unique_strings?(candidate_ids) ->
        {:error, "candidate IDs must be unique non-empty strings"}

      Enum.sort(baseline_ids) != Enum.sort(candidate_ids) ->
        {:error, "candidate set differs from the reviewed baseline"}

      transition_ids != Enum.uniq(transition_ids) ->
        {:error, "candidate transition IDs must be unique"}

      Enum.sort(transition_ids) != Enum.sort(changed_ids) ->
        {:error, "changed candidate requires one Phase 133 transition"}

      not Enum.all?(transitions, &valid_transition?(&1, baseline, candidates)) ->
        {:error, "Phase 133 transition record is incomplete or inconsistent"}

      true ->
        :ok
    end
  end

  defp validate_transition_contract(_),
    do: {:error, "candidate baseline and Phase 133 transitions are required"}

  defp valid_transition?(transition, baseline, candidates) do
    candidate_id = transition["candidate_id"]
    baseline_entry = Enum.find(baseline, &(&1["id"] == candidate_id))
    candidate = Enum.find(candidates, &(&1["id"] == candidate_id))

    (baseline_entry && candidate &&
       transition["before_observations_digest"] == baseline_entry["observations_digest"]) and
      transition["after_observations_digest"] ==
        observations_digest(candidate["observations"] || []) and
      nonempty_string?(transition["reason"]) and
      Regex.match?(~r/\A133-[0-9]{2}\z/, transition["implementing_plan"] || "")
  end

  defp observations_digest(observations) do
    observations
    |> Enum.sort()
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp validate_candidates(%{"detectors" => detectors, "candidates" => candidates}, root)
       when is_list(candidates) do
    observations = normalized_observations(detectors, root)
    observation_ids = Enum.map(observations, & &1["id"])
    candidate_ids = Enum.map(candidates, & &1["id"])
    assigned = Enum.flat_map(candidates, &(&1["observations"] || []))

    cond do
      candidates == [] ->
        {:error, "at least one candidate is required"}

      not nonempty_unique_strings?(observation_ids) ->
        {:error, "normalized observation IDs must be unique"}

      not nonempty_unique_strings?(candidate_ids) ->
        {:error, "candidate IDs must be unique non-empty strings"}

      assigned != Enum.uniq(assigned) ->
        {:error, "an observation is assigned to multiple candidates"}

      Enum.sort(assigned) != Enum.sort(observation_ids) ->
        {:error, "every observation must be assigned to exactly one candidate"}

      not Enum.all?(candidates, &valid_candidate?/1) ->
        {:error, "candidate disposition record is incomplete"}

      true ->
        :ok
    end
  end

  defp validate_candidates(_, _root), do: {:error, "candidates must be an array"}

  defp valid_candidate?(candidate) do
    base =
      nonempty_string?(candidate["id"]) and nonempty_unique_strings?(candidate["observations"]) and
        candidate["disposition"] in @dispositions and nonempty_string?(candidate["rationale"]) and
        nonempty_unique_strings?(candidate["evidence"])

    case candidate["disposition"] do
      "defer" -> base and valid_trigger?(candidate["trigger"])
      disposition when disposition in ["fix", "retain"] -> base and is_nil(candidate["trigger"])
      _ -> false
    end
  end

  defp valid_trigger?(%{"command" => command, "expected_transition" => transition}),
    do: nonempty_string?(command) and nonempty_string?(transition)

  defp valid_trigger?(_), do: false

  defp validate_receipt(ledger, receipt, root) do
    expected_dimensions =
      ledger["taxonomy"]
      |> Enum.map(&Map.update(&1, "detectors", [], fn ids -> Enum.sort(ids) end))
      |> Enum.sort_by(fn record ->
        Enum.find_index(@dimensions, &(&1 == record["id"]))
      end)

    expected_observations = normalized_observations(ledger["detectors"], root)
    expected_digest = candidate_contract_digest(ledger)

    with :ok <-
           require_equal(
             receipt["dimensions"],
             expected_dimensions,
             "receipt dimensions differ from ledger"
           ),
         :ok <-
           require_equal(
             receipt["observations"],
             expected_observations,
             "receipt observations differ from ledger"
           ),
         :ok <-
           require_equal(
             receipt["candidates_digest"],
             expected_digest,
             "receipt candidate digest differs from ledger"
           ),
         :ok <- validate_toolchain(receipt["toolchain"]),
         {:ok, expected_inputs} <- input_digests(ledger["detectors"], root),
         :ok <-
           require_equal(
             receipt["inputs"],
             expected_inputs,
             "receipt input digests differ from repository"
           ) do
      :ok
    end
  end

  defp validate_toolchain(%{"elixir" => elixir, "otp" => otp})
       when is_binary(elixir) and elixir != "" and is_binary(otp) and otp != "",
       do: :ok

  defp validate_toolchain(_), do: {:error, "receipt toolchain metadata is incomplete"}

  defp input_digests(detectors, root) do
    detectors
    |> Enum.flat_map(fn detector -> Enum.map(detector["inputs"], &{detector["id"], &1}) end)
    |> Enum.sort()
    |> Enum.reduce_while({:ok, []}, fn {detector_id, path}, {:ok, acc} ->
      with :ok <- safe_relative_path(path),
           {:ok, full_path} <- contained_input_file(path, root),
           {:ok, contents} <- File.read(full_path) do
        digest = :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)

        {:cont,
         {:ok, [%{"detector_id" => detector_id, "path" => path, "sha256" => digest} | acc]}}
      else
        {:error, reason} ->
          {:halt, {:error, "detector input #{inspect(path)}: #{reason}"}}
      end
    end)
    |> case do
      {:ok, inputs} -> {:ok, Enum.reverse(inputs)}
      error -> error
    end
  end

  defp safe_relative_path(path) when is_binary(path) and path != "" do
    expanded = Path.expand(path, "/evidence-root")

    if Path.type(path) == :relative and String.starts_with?(expanded, "/evidence-root/"),
      do: :ok,
      else: {:error, "detector input path must remain repository-relative"}
  end

  defp safe_relative_path(_),
    do: {:error, "detector input path must be a non-empty string"}

  defp contained_input_file(path, root) do
    root = Path.expand(root)
    expanded = Path.expand(path, root)

    with true <- contained_path?(expanded, root),
         {:ok, physical_root} <- resolve_input_physical_path(root),
         {:ok, resolved} <- resolve_input_physical_path(expanded),
         true <- contained_path?(resolved, physical_root),
         {:ok, %File.Stat{type: :regular}} <- File.lstat(resolved) do
      {:ok, resolved}
    else
      {:error, :eloop} ->
        {:error, "detector input physical path contains a symlink loop"}

      {:error, :enoent} ->
        {:error, "detector input physical path is missing or dangling"}

      _ ->
        {:error, "detector input must resolve to a regular file within repository root"}
    end
  end

  defp resolve_input_physical_path(path) do
    [root | segments] = path |> Path.expand() |> Path.split()
    resolve_input_components(root, segments, MapSet.new())
  end

  defp resolve_input_components(current, [], _seen), do: {:ok, current}

  defp resolve_input_components(current, [segment | rest], seen) do
    candidate = Path.join(current, segment)

    case File.lstat(candidate) do
      {:ok, %File.Stat{type: :symlink}} ->
        if MapSet.member?(seen, candidate) do
          {:error, :eloop}
        else
          with {:ok, target} <- File.read_link(candidate),
               {:ok, resolved} <-
                 resolve_input_physical_path(
                   Path.expand(target, Path.dirname(candidate)),
                   MapSet.put(seen, candidate)
                 ) do
            resolve_input_components(resolved, rest, seen)
          end
        end

      {:ok, _stat} ->
        resolve_input_components(candidate, rest, seen)

      error ->
        error
    end
  end

  defp resolve_input_physical_path(path, seen) do
    [root | segments] = path |> Path.expand() |> Path.split()
    resolve_input_components(root, segments, seen)
  end

  defp validate_observation_locations(%{"detectors" => detectors}, root)
       when is_list(detectors) do
    detectors
    |> Enum.flat_map(&(&1["observations"] || []))
    |> Enum.reduce_while(:ok, fn observation, :ok ->
      case contained_observation_location(observation["location"], root) do
        {:ok, _location} -> {:cont, :ok}
        {:error, message} -> {:halt, {:error, message}}
      end
    end)
  end

  defp validate_observation_locations(_ledger, _root),
    do: {:error, "detectors must be an array"}

  defp normalized_observations(detectors, root) do
    detectors
    |> Enum.flat_map(fn detector ->
      Enum.map(detector["observations"], fn observation ->
        observation
        |> Map.take(["id", "kind", "location", "signal", "status", "attributes"])
        |> Map.put("detector_id", detector["id"])
        |> Map.put("dimension", detector["dimension"])
        |> Map.update!("location", fn location ->
          {:ok, normalized} = contained_observation_location(location, root)
          normalized
        end)
      end)
    end)
    |> Enum.uniq_by(&canonical_json/1)
    |> Enum.sort_by(& &1["id"])
  end

  defp contained_observation_location(location, root)
       when is_binary(location) and location != "" do
    root = Path.expand(root)
    expanded = Path.expand(location, root)

    if Path.type(location) == :relative and contained_path?(expanded, root) and
         physically_contained?(expanded, root) do
      {:ok, Path.relative_to(expanded, root)}
    else
      {:error, "observation location must remain within repository root"}
    end
  end

  defp contained_observation_location(_location, _root),
    do: {:error, "observation location must remain within repository root"}

  defp physically_contained?(path, root) do
    path
    |> Path.relative_to(root)
    |> Path.split()
    |> Enum.reduce_while(root, fn segment, current ->
      candidate = Path.join(current, segment)

      case resolve_symlink(candidate, MapSet.new()) do
        {:ok, resolved} ->
          if contained_path?(resolved, root), do: {:cont, resolved}, else: {:halt, false}

        {:error, :enoent} ->
          {:cont, candidate}

        {:error, _reason} ->
          {:halt, false}
      end
    end)
    |> is_binary()
  end

  defp resolve_symlink(path, seen) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :symlink}} ->
        if MapSet.member?(seen, path) do
          {:error, :eloop}
        else
          with {:ok, target} <- File.read_link(path) do
            resolved = Path.expand(target, Path.dirname(path))
            resolve_symlink(resolved, MapSet.put(seen, path))
          end
        end

      {:ok, _stat} ->
        {:ok, path}

      error ->
        error
    end
  end

  defp contained_path?(path, root) do
    relative = Path.relative_to(path, root)

    Path.type(relative) == :relative and relative != ".." and
      not String.starts_with?(relative, "../")
  end

  defp candidate_contract_digest(ledger) do
    %{
      "candidates" =>
        ledger["candidates"]
        |> Enum.map(fn candidate ->
          candidate
          |> Map.update("observations", [], &Enum.sort/1)
          |> Map.update("evidence", [], &Enum.sort/1)
        end)
        |> Enum.sort_by(& &1["id"]),
      "candidate_baseline" => Enum.sort_by(ledger["candidate_baseline"] || [], & &1["id"]),
      "phase_133_transitions" =>
        Enum.sort_by(ledger["phase_133_transitions"] || [], & &1["candidate_id"])
    }
    |> canonical_json()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp canonical_json(value), do: encode_canonical(value) <> "\n"

  defp encode_canonical(value) when is_map(value) do
    value
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.map_join(",", fn {key, nested} ->
      Jason.encode!(key) <> ":" <> encode_canonical(nested)
    end)
    |> then(&("{" <> &1 <> "}"))
  end

  defp encode_canonical(value) when is_list(value),
    do: "[" <> Enum.map_join(value, ",", &encode_canonical/1) <> "]"

  defp encode_canonical(value), do: Jason.encode!(value)

  defp sha?(value), do: is_binary(value) and Regex.match?(~r/\A[0-9a-f]{40}\z/, value)
  defp nonempty_string?(value), do: is_binary(value) and String.trim(value) != ""

  defp nonempty_unique_strings?(values) when is_list(values),
    do: values != [] and Enum.all?(values, &nonempty_string?/1) and values == Enum.uniq(values)

  defp nonempty_unique_strings?(_), do: false

  defp require_equal(value, value, _message), do: :ok
  defp require_equal(_left, _right, message), do: {:error, message}
end

unless System.get_env("RINDLE_EVIDENCE_CENSUS_VALIDATOR_LIBRARY_ONLY") == "1" do
  case Rindle.ValidateEvidenceCensus.run(System.argv()) do
    :ok ->
      :ok

    {:error, message} ->
      IO.puts(:stderr, "[validate-evidence-census] #{message}")
      System.halt(1)
  end
end
