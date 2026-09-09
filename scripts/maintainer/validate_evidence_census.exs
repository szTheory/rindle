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

  def run(argv) do
    with {:ok, options} <- parse_options(argv),
         {:ok, ledger} <- decode_json(options.ledger, "ledger"),
         {:ok, receipt} <- decode_json(options.receipt, "receipt"),
         {:ok, head} <- git(options.root, ["rev-parse", "HEAD"]),
         :ok <- validate_schema(ledger, receipt),
         :ok <- validate_authority(ledger, receipt, head),
         :ok <- validate_taxonomy(ledger),
         :ok <- validate_detectors(ledger),
         :ok <- validate_candidates(ledger),
         :ok <- validate_receipt(ledger, receipt, options.root) do
      IO.puts("evidence census valid for #{head}")
      :ok
    end
  end

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
      ids != @dimensions ->
        {:error, "taxonomy must contain exactly the twelve locked dimensions in canonical order"}

      length(ids) != length(Enum.uniq(ids)) ->
        {:error, "taxonomy contains duplicate dimensions"}

      not Enum.all?(taxonomy, &valid_taxonomy_record?/1) ->
        {:error, "taxonomy applicability record is incomplete"}

      true ->
        :ok
    end
  end

  defp validate_taxonomy(_), do: {:error, "taxonomy must be an array"}

  defp valid_taxonomy_record?(%{"applicable" => true, "detectors" => detectors}),
    do: nonempty_unique_strings?(detectors)

  defp valid_taxonomy_record?(%{
         "applicable" => false,
         "detectors" => [],
         "rationale" => rationale
       }),
       do: nonempty_string?(rationale)

  defp valid_taxonomy_record?(_), do: false

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

  defp valid_observation?(observation) do
    nonempty_string?(observation["id"]) and nonempty_string?(observation["kind"]) and
      nonempty_string?(observation["location"]) and
      Path.type(observation["location"]) == :relative and
      nonempty_string?(observation["status"]) and is_map(observation["attributes"])
  end

  defp validate_candidates(%{"detectors" => detectors, "candidates" => candidates})
       when is_list(candidates) do
    observations = normalized_observations(detectors)
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

  defp validate_candidates(_), do: {:error, "candidates must be an array"}

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
    expected_dimensions = ledger["taxonomy"]
    expected_observations = normalized_observations(ledger["detectors"])
    expected_digest = candidates_digest(ledger["candidates"])

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
           {:ok, contents} <- File.read(Path.join(root, path)) do
        digest = :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)

        {:cont,
         {:ok, [%{"detector_id" => detector_id, "path" => path, "sha256" => digest} | acc]}}
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

    if Path.type(path) == :relative and String.starts_with?(expanded, "/evidence-root/"),
      do: :ok,
      else: {:error, "path must remain repository-relative"}
  end

  defp safe_relative_path(_), do: {:error, "path must be a non-empty string"}

  defp normalized_observations(detectors) do
    detectors
    |> Enum.flat_map(fn detector ->
      Enum.map(detector["observations"], fn observation ->
        observation
        |> Map.take(["id", "kind", "location", "signal", "status", "attributes"])
        |> Map.put("detector_id", detector["id"])
        |> Map.put("dimension", detector["dimension"])
      end)
    end)
    |> Enum.uniq_by(&canonical_json/1)
    |> Enum.sort_by(& &1["id"])
  end

  defp candidates_digest(candidates) do
    candidates
    |> Enum.sort_by(& &1["id"])
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

case Rindle.ValidateEvidenceCensus.run(System.argv()) do
  :ok ->
    :ok

  {:error, message} ->
    IO.puts(:stderr, "[validate-evidence-census] #{message}")
    System.halt(1)
end
