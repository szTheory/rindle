defmodule Rindle.EvidenceCensus do
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
         {:ok, head} <- git(options.root, ["rev-parse", "HEAD"]),
         :ok <-
           require_equal(options.source_sha, head, "source SHA does not match repository HEAD"),
         :ok <-
           require_equal(ledger["subject_sha"], options.source_sha, "ledger subject SHA mismatch"),
         {:ok, dirty?} <- dirty?(options.root),
         :ok <- authorize_dirty(dirty?, options.allow_dirty_diagnostic),
         {:ok, receipt} <- build_receipt(ledger, options, dirty?),
         :ok <- write_receipt(options.output, receipt) do
      if dirty?, do: IO.puts("wrote non-authoritative diagnostic census receipt")
      :ok
    end
  end

  def dimensions, do: @dimensions
  def detector_registry, do: @detector_registry

  def canonical_json(value), do: encode_canonical(value) <> "\n"

  def candidates_digest(candidates) do
    candidates
    |> sort_by_id()
    |> canonical_json()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  def candidate_contract_digest(ledger) do
    %{
      "candidates" =>
        ledger["candidates"]
        |> Enum.map(fn candidate ->
          candidate
          |> Map.update("observations", [], &Enum.sort/1)
          |> Map.update("evidence", [], &Enum.sort/1)
        end)
        |> sort_by_id(),
      "candidate_baseline" => sort_by_id(ledger["candidate_baseline"] || []),
      "phase_133_transitions" =>
        Enum.sort_by(ledger["phase_133_transitions"] || [], & &1["candidate_id"])
    }
    |> canonical_json()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  def normalized_observations(detectors, root) when is_list(detectors) do
    detectors
    |> Enum.flat_map(fn detector ->
      Enum.map(detector["observations"] || [], fn observation ->
        observation
        |> Map.take(["id", "kind", "location", "signal", "status", "attributes"])
        |> Map.put("detector_id", detector["id"])
        |> Map.put("dimension", detector["dimension"])
      end)
    end)
    |> Enum.reduce_while({:ok, []}, fn observation, {:ok, normalized} ->
      case contained_observation_location(observation["location"], root) do
        {:ok, location} ->
          {:cont, {:ok, [Map.put(observation, "location", location) | normalized]}}

        {:error, message} ->
          {:halt, {:error, message}}
      end
    end)
    |> case do
      {:ok, observations} ->
        observations =
          observations
          |> Enum.uniq_by(&canonical_json/1)
          |> sort_by_id()

        {:ok, observations}

      error ->
        error
    end
  end

  defp parse_options(argv) do
    switches = [
      root: :string,
      ledger: :string,
      output: :string,
      source_sha: :string,
      allow_dirty_diagnostic: :boolean
    ]

    case OptionParser.parse(argv, strict: switches) do
      {options, [], []} ->
        values = Map.new(options)

        with {:ok, root} <- required(values, :root),
             {:ok, ledger} <- required(values, :ledger),
             {:ok, output} <- required(values, :output),
             {:ok, source_sha} <- required(values, :source_sha) do
          {:ok,
           %{
             root: Path.expand(root),
             ledger: Path.expand(ledger),
             output: Path.expand(output),
             source_sha: source_sha,
             allow_dirty_diagnostic: Map.get(values, :allow_dirty_diagnostic, false)
           }}
        end

      {_options, positional, invalid} ->
        {:error, "unexpected arguments: #{inspect(positional ++ invalid)}"}
    end
  end

  defp required(values, key) do
    case Map.get(values, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "missing required --#{key |> Atom.to_string() |> String.replace("_", "-")}"}
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
      {output, _status} -> {:error, "git #{Enum.join(args, " ")} failed: #{String.trim(output)}"}
    end
  end

  defp dirty?(root) do
    case git(root, ["status", "--porcelain", "--untracked-files=all"]) do
      {:ok, ""} -> {:ok, false}
      {:ok, _output} -> {:ok, true}
      error -> error
    end
  end

  defp authorize_dirty(false, _allow?), do: :ok
  defp authorize_dirty(true, true), do: :ok

  defp authorize_dirty(true, false),
    do: {:error, "authoritative census requires a clean worktree"}

  defp build_receipt(ledger, options, dirty?) do
    with {:ok, taxonomy} <- taxonomy(ledger["taxonomy"]),
         {:ok, detectors} <- detectors(ledger["detectors"]),
         {:ok, inputs} <- input_digests(detectors, options.root),
         {:ok, observations} <- normalized_observations(detectors, options.root) do
      {:ok,
       %{
         "schema_version" => ledger["schema_version"],
         "source_sha" => options.source_sha,
         "dirty" => dirty?,
         "toolchain" => %{
           "elixir" => System.version(),
           "otp" => :erlang.system_info(:otp_release) |> List.to_string()
         },
         "inputs" => inputs,
         "dimensions" => taxonomy,
         "observations" => observations,
         "candidates_digest" => candidate_contract_digest(ledger)
       }}
    end
  end

  defp taxonomy(records) when is_list(records) do
    ids = Enum.map(records, & &1["id"])

    if Enum.sort(ids) == Enum.sort(@dimensions) and length(ids) == length(Enum.uniq(ids)) do
      canonical =
        records
        |> Enum.map(&Map.update(&1, "detectors", [], fn ids -> Enum.sort(ids) end))
        |> Enum.sort_by(&Enum.find_index(@dimensions, fn id -> id == &1["id"] end))

      {:ok, canonical}
    else
      {:error, "taxonomy must contain exactly the twelve locked dimensions"}
    end
  end

  defp taxonomy(_), do: {:error, "taxonomy must be an array"}

  defp detectors(records) when is_list(records), do: {:ok, sort_by_id(records)}
  defp detectors(_), do: {:error, "detectors must be an array"}

  defp input_digests(detectors, root) do
    detectors
    |> Enum.flat_map(fn detector ->
      Enum.map(detector["inputs"] || [], &{detector["id"], &1})
    end)
    |> Enum.sort()
    |> Enum.reduce_while({:ok, []}, fn {detector_id, path}, {:ok, inputs} ->
      with :ok <- safe_relative_path(path),
           full_path <- Path.join(root, path),
           {:ok, contents} <- File.read(full_path) do
        digest = :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
        input = %{"detector_id" => detector_id, "path" => path, "sha256" => digest}
        {:cont, {:ok, [input | inputs]}}
      else
        {:error, reason} ->
          {:halt, {:error, "detector input #{inspect(path)}: #{inspect(reason)}"}}
      end
    end)
    |> case do
      {:ok, inputs} -> {:ok, Enum.reverse(inputs)}
      error -> error
    end
  end

  defp safe_relative_path(path) when is_binary(path) and path != "" do
    expanded = Path.expand(path, "/evidence-root")

    if Path.type(path) == :relative and
         (expanded == "/evidence-root" or String.starts_with?(expanded, "/evidence-root/")) do
      :ok
    else
      {:error, "input path must remain repository-relative"}
    end
  end

  defp safe_relative_path(_), do: {:error, "input path must be a non-empty string"}

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

  defp write_receipt(path, receipt) do
    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, canonical_json(receipt)) do
      :ok
    else
      {:error, reason} -> {:error, "cannot write receipt #{path}: #{inspect(reason)}"}
    end
  end

  defp require_equal(value, value, _message), do: :ok
  defp require_equal(_left, _right, message), do: {:error, message}

  defp sort_by_id(values), do: Enum.sort_by(values, &Map.get(&1, "id", ""))

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
end

case Rindle.EvidenceCensus.run(System.argv()) do
  :ok ->
    :ok

  {:error, message} ->
    IO.puts(:stderr, "[evidence-census] #{message}")
    System.halt(1)
end
