defmodule Rindle.CredoQualityNormalize do
  @identity_keys ["check", "file", "trigger", "observed_metric"]

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
    if length(entries) != 31 or Enum.sum(Enum.map(entries, &Map.get(&1, "count", 0))) != 35 do
      raise ArgumentError, "baseline must contain 31 identities and 35 occurrences"
    end

    entries
    |> Enum.map(&baseline_identity/1)
    |> ensure_unique!()
    |> sort_identities()
  end

  defp normalize_baseline(_), do: raise(ArgumentError, "baseline must contain an entries array")

  defp baseline_identity(entry) when is_map(entry) do
    expected_keys = Enum.sort(@identity_keys ++ ["count", "owner", "removal_trigger"])

    if Enum.sort(Map.keys(entry)) != expected_keys or
         not Enum.all?(["check", "file", "trigger", "owner", "removal_trigger"], &(is_binary(entry[&1]) and entry[&1] != "")) or
         not is_number(entry["observed_metric"]) or
         not is_integer(entry["count"]) or entry["count"] <= 0 do
      raise ArgumentError, "baseline entries require stable identity, count, owner, and removal trigger"
    end

    Map.take(entry, @identity_keys ++ ["count"])
  end

  defp baseline_identity(_), do: raise(ArgumentError, "baseline entries must be objects")

  defp validate_identity!(identity) do
    if is_binary(identity["file"]) and is_binary(identity["trigger"]) do
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

  defp sort_identities(entries), do: Enum.sort_by(entries, &identity/1)
  defp identity(entry), do: List.to_tuple(Enum.map(@identity_keys, &Map.fetch!(entry, &1)))
end

Rindle.CredoQualityNormalize.run(System.argv())
