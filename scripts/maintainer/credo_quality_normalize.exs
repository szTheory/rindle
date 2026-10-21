defmodule Rindle.CredoQualityNormalize do
  @identity_keys ["check", "file", "trigger", "observed_metric"]

  def run(["compare", actual_path, baseline_path, evidence_path]) do
    actual = actual_path |> File.read!() |> Jason.decode!()
    baseline = baseline_path |> File.read!() |> Jason.decode!()
    evidence = evidence_path |> File.read!() |> Jason.decode!() |> evidence_entries!()
    compare!(actual, baseline, evidence)
  end

  def run([kind]) do
    input = IO.read(:stdio, :eof) |> Jason.decode!()

    normalized =
      case kind do
        "issues" -> normalize_issues(input)
        "baseline" -> normalize_baseline(input)
        _ -> raise ArgumentError, "expected issues or baseline input"
      end

    IO.write(Jason.encode!(normalized))
  end

  def run(_), do: raise(ArgumentError, "expected one normalization kind")

  defp normalize_issues(%{"issues" => issues}) when is_list(issues) do
    issues
    |> Enum.map(&issue_identity/1)
    |> Enum.group_by(&identity/1)
    |> Enum.map(fn {_identity, [issue | duplicates]} ->
      Map.put(issue, "count", length(duplicates) + 1)
    end)
    |> sort_identities()
  end

  defp normalize_issues(_), do: raise(ArgumentError, "Credo JSON must contain an issues array")

  defp issue_identity(issue) do
    check = Map.fetch!(issue, "check")
    message = Map.fetch!(issue, "message")

    %{
      "check" => check,
      "file" => Map.fetch!(issue, "filename"),
      "trigger" => Map.fetch!(issue, "trigger"),
      "observed_metric" => metric(check, message)
    }
    |> validate_identity!()
  end

  defp metric("Credo.Check.Refactor.CyclomaticComplexity", message),
    do: captured_metric(message, ~r/cyclomatic complexity is (?<metric>[0-9]+)/)

  defp metric("Credo.Check.Refactor.Nesting", message),
    do: captured_metric(message, ~r/was (?<metric>[0-9]+)/)

  defp metric(check, _message), do: raise(ArgumentError, "unexpected Credo check: #{check}")

  defp captured_metric(message, expression) when is_binary(message) do
    case Regex.named_captures(expression, message) do
      %{"metric" => metric} -> String.to_integer(metric)
      nil -> raise ArgumentError, "Credo issue did not include an observed metric"
    end
  end

  defp captured_metric(_, _), do: raise(ArgumentError, "Credo issue message must be a string")

  defp normalize_baseline(%{"entries" => entries}) when is_list(entries) do
    entries
    |> Enum.map(&baseline_identity/1)
    |> ensure_unique!()
    |> sort_identities()
  end

  defp normalize_baseline(_), do: raise(ArgumentError, "baseline must contain an entries array")

  defp baseline_identity(entry) when is_map(entry) do
    expected_keys = Enum.sort(@identity_keys ++ ["count", "owner", "removal_trigger"])

    if Enum.sort(Map.keys(entry)) != expected_keys or
         not Enum.all?(
           ["check", "file", "trigger", "owner", "removal_trigger"],
           &(is_binary(entry[&1]) and entry[&1] != "")
         ) or
         not is_integer(entry["observed_metric"]) or entry["observed_metric"] < 0 or
         not is_integer(entry["count"]) or entry["count"] <= 0 do
      raise ArgumentError,
            "baseline entries require stable identity, count, owner, and removal trigger"
    end

    limit =
      case entry["check"] do
        "Credo.Check.Refactor.CyclomaticComplexity" -> 9
        "Credo.Check.Refactor.Nesting" -> 2
        _ -> raise ArgumentError, "unexpected baseline check"
      end

    unless entry["removal_trigger"] == "observed_metric <= #{limit}",
      do: raise(ArgumentError, "baseline removal trigger must be an executable metric predicate")

    Map.take(entry, @identity_keys ++ ["count"])
  end

  defp baseline_identity(_), do: raise(ArgumentError, "baseline entries must be objects")

  defp validate_identity!(identity) do
    if Enum.all?(~w(file trigger), &(is_binary(identity[&1]) and identity[&1] != "")) do
      identity
    else
      raise ArgumentError, "Credo issue identity is malformed"
    end
  end

  defp ensure_unique!(entries) do
    if length(entries) == length(Enum.uniq_by(entries, &identity/1)) do
      entries
    else
      raise ArgumentError, "baseline identities must be unique"
    end
  end

  defp evidence_entries!(%{"entries" => entries}) when is_list(entries) do
    Enum.each(entries, fn entry ->
      keys = ~w(check file trigger before after source_sha behavior_test)

      unless is_map(entry) and Enum.sort(Map.keys(entry)) == Enum.sort(keys) and
               Enum.all?(
                 ~w(check file trigger source_sha behavior_test),
                 &(is_binary(entry[&1]) and entry[&1] != "")
               ) and
               Enum.all?([entry["before"], entry["after"]], &metric_vector?/1) do
        raise ArgumentError, "malformed behavior evidence"
      end
    end)

    if length(entries) != length(Enum.uniq_by(entries, &stable_identity/1)),
      do: raise(ArgumentError, "duplicate behavior evidence")

    entries
  end

  defp evidence_entries!(_), do: raise(ArgumentError, "evidence requires entries array")

  defp metric_vector?(vector),
    do:
      is_list(vector) and Enum.all?(vector, &(is_integer(&1) and &1 >= 0)) and
        vector == Enum.sort(vector, :desc)

  defp compare!(actual, baseline, evidence) do
    live = vectors(actual)
    reviewed = vectors(baseline)

    Enum.each(live, fn {key, vector} ->
      ceiling = Map.get(reviewed, key, [])

      if length(vector) > length(ceiling) or
           Enum.any?(Enum.zip(vector, ceiling), fn {value, max} -> value > max end),
         do: raise(ArgumentError, "complexity baseline growth: #{inspect(key)}")
    end)

    Enum.each(reviewed, fn {key, before} ->
      after_vector = Map.get(live, key, [])
      if before != after_vector, do: prove_reduction!(key, before, after_vector, evidence)
    end)
  end

  defp vectors(entries) do
    entries
    |> Enum.group_by(&stable_identity/1)
    |> Map.new(fn {key, values} ->
      {key,
       values
       |> Enum.flat_map(&List.duplicate(&1["observed_metric"], &1["count"]))
       |> Enum.sort(:desc)}
    end)
  end

  defp stable_identity(entry), do: {entry["check"], entry["file"], entry["trigger"]}

  defp prove_reduction!(key, before, after_vector, evidence) do
    record =
      Enum.find(evidence, &(stable_identity(&1) == key)) ||
        raise ArgumentError, "complexity baseline reduction requires behavior evidence"

    {sha, 0} = System.cmd("git", ["rev-parse", "HEAD"])

    unless record["source_sha"] == String.trim(sha) and record["before"] == before and
             record["after"] == after_vector,
           do: raise(ArgumentError, "stale or mismatched behavior evidence")

    target = record["behavior_test"]
    path = Path.expand(target)
    root = File.cwd!() <> "/"

    unless String.starts_with?(path, root <> "test/") and File.regular?(path) and
             String.ends_with?(target, "_test.exs") and
             not String.contains?(File.read!(path), ["credo_quality", "credo_policy"]) and
             System.get_env("CREDO_QUALITY_BEHAVIOR_RUNNING") != "1",
           do: raise(ArgumentError, "invalid or recursive behavior test")

    {output, status} =
      System.cmd("mix", ["test", target, "--seed", "0"],
        env: [{"CREDO_QUALITY_BEHAVIOR_RUNNING", "1"}, {"MIX_ENV", "test"}],
        stderr_to_stdout: true
      )

    unless status == 0 and Regex.match?(~r/\b[1-9][0-9]* tests?, 0 failures\b/, output) and
             not Regex.match?(~r/\b[1-9][0-9]* (skipped|excluded|invalid)\b/, output),
           do:
             raise(
               ArgumentError,
               "behavior proof must execute all named tests successfully: #{output}"
             )
  end

  defp sort_identities(entries), do: Enum.sort_by(entries, &identity/1)
  defp identity(entry), do: List.to_tuple(Enum.map(@identity_keys, &Map.fetch!(entry, &1)))
end

Rindle.CredoQualityNormalize.run(System.argv())
