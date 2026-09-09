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

  def canonical_json(value), do: encode_canonical(value) <> "\n"

  def candidates_digest(candidates) do
    candidates
    |> sort_by_id()
    |> canonical_json()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  def normalized_observations(detectors) when is_list(detectors) do
    detectors
    |> Enum.flat_map(fn detector ->
      Enum.map(detector["observations"] || [], fn observation ->
        observation
        |> Map.take(["id", "kind", "location", "signal", "status", "attributes"])
        |> Map.put("detector_id", detector["id"])
        |> Map.put("dimension", detector["dimension"])
        |> reject_absolute_location()
      end)
    end)
    |> Enum.uniq_by(&canonical_json/1)
    |> sort_by_id()
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
         {:ok, inputs} <- input_digests(detectors, options.root) do
      observations = normalized_observations(detectors)

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
         "candidates_digest" => candidates_digest(ledger["candidates"] || [])
       }}
    end
  end

  defp taxonomy(records) when is_list(records) do
    ids = Enum.map(records, & &1["id"])

    if Enum.sort(ids) == Enum.sort(@dimensions) and length(ids) == length(Enum.uniq(ids)) do
      {:ok, Enum.sort_by(records, &Enum.find_index(@dimensions, fn id -> id == &1["id"] end))}
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

  defp reject_absolute_location(%{"location" => location} = observation)
       when is_binary(location) do
    if Path.type(location) == :absolute,
      do: raise(ArgumentError, "observation locations must be repository-relative"),
      else: observation
  end

  defp reject_absolute_location(observation), do: observation

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
