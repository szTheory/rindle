defmodule Mix.Tasks.Rindle.RuntimeStatus.Formatter do
  @moduledoc false

  @doc false
  @spec format_error(term()) :: String.t()
  def format_error({:setup_incomplete, :rindle_schema}) do
    "Rindle.RuntimeStatus failed: setup_incomplete rindle_schema; no report queries ran. Run `mix rindle.doctor`, then apply a host migration that calls `Rindle.Migration.up(version: 1)` and rerun `mix ecto.migrate`."
  end

  def format_error({:setup_incomplete, :oban_jobs}) do
    "Rindle.RuntimeStatus failed: setup_incomplete oban_jobs; no report queries ran. Run `mix rindle.doctor`. Install Oban through a host-owned migration using `Oban.Migration`. Rindle no longer manages `oban_jobs`."
  end

  def format_error({:rindle_prefix_mismatch, _details} = reason) do
    details = error_details(reason)

    "Rindle.RuntimeStatus failed: rindle_prefix_mismatch; no report queries ran. Run `mix rindle.doctor`. Expected Rindle prefix #{details.expected_prefix}, observed #{details.observed_prefix}. Schedule the host-owned maintenance-window migration, then deploy the matching Rindle prefix."
  end

  def format_error({:oban_binding_drift, _details} = reason) do
    details = error_details(reason)

    "Rindle.RuntimeStatus failed: oban_binding_drift; no report queries ran. Run `mix rindle.doctor`. Expected host Oban prefix #{details.expected_prefix}, observed #{details.observed_prefix}. Align the host-owned default Oban binding and `:rindle, :oban_prefix`, then deploy matching configuration."
  end

  def format_error({:inspection_failed, _details}) do
    "Rindle.RuntimeStatus failed: inspection_failed; no report queries ran. Run `mix rindle.doctor` to verify the bounded ownership diagnostics before retrying."
  end

  def format_error({:invalid_format, _value}) do
    "Rindle.RuntimeStatus failed: invalid_format; no report queries ran. Run `mix rindle.doctor` before retrying with `--format text` or `--format json`."
  end

  def format_error(_reason),
    do:
      "Rindle.RuntimeStatus failed: unknown; no report queries ran. Run `mix rindle.doctor` before retrying."

  @doc false
  @spec format_json_error(term()) :: map()
  def format_json_error(reason) do
    %{status: "error"}
    |> Map.merge(error_details(reason))
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp error_details({:setup_incomplete, :rindle_schema}),
    do: %{
      classification: "setup_incomplete",
      component: "rindle",
      owner: "rindle",
      next_action: "mix rindle.doctor"
    }

  defp error_details({:setup_incomplete, :oban_jobs}),
    do: %{
      classification: "setup_incomplete",
      component: "oban",
      owner: "host",
      next_action: "mix rindle.doctor"
    }

  defp error_details({:rindle_prefix_mismatch, details}) when is_map(details) do
    %{
      classification: "rindle_prefix_mismatch",
      component: "rindle",
      expected_prefix: safe_prefix(:rindle, Map.get(details, :expected_prefix)),
      observed_prefix: safe_prefix(:rindle, Map.get(details, :observed_prefix)),
      owner: "rindle",
      next_action: "mix rindle.doctor"
    }
  end

  defp error_details({:oban_binding_drift, details}) when is_map(details) do
    %{
      classification: "oban_binding_drift",
      component: "oban",
      expected_prefix: safe_prefix(:oban, Map.get(details, :expected_prefix)),
      observed_prefix: safe_prefix(:oban, Map.get(details, :observed_prefix)),
      owner: "host",
      next_action: "mix rindle.doctor"
    }
  end

  defp error_details({:inspection_failed, details}) when is_map(details),
    do: %{
      classification: "inspection_failed",
      component: details |> Map.get(:component) |> atom_string(),
      owner: details |> Map.get(:owner) |> atom_string(),
      next_action: "mix rindle.doctor"
    }

  defp error_details({:invalid_format, _value}),
    do: %{classification: "invalid_format", next_action: "mix rindle.doctor"}

  defp error_details(_reason), do: %{classification: "unknown", next_action: "mix rindle.doctor"}

  defp safe_prefix(:rindle, prefix) when prefix in ["rindle", "public"], do: prefix

  defp safe_prefix(:oban, prefix) when is_binary(prefix) do
    if Regex.match?(~r/\A[a-zA-Z_][a-zA-Z0-9_$]*\z/, prefix), do: prefix, else: "unknown"
  end

  defp safe_prefix(_component, _prefix), do: "unknown"

  defp atom_string(value) when value in [:rindle, :oban, :host], do: Atom.to_string(value)
  defp atom_string(_value), do: nil

  @doc false
  @spec format_text_report(Rindle.Ops.RuntimeStatus.report()) :: [String.t()]
  def format_text_report(report) do
    [
      "Rindle: runtime status report...",
      "  generated_at: #{DateTime.to_iso8601(report.generated_at)}",
      "  profile:      #{report.filters.profile || "all"}",
      "  older_than:   #{report.filters.older_than || "any"}",
      "  limit:        #{report.filters.limit}",
      "  format:       text"
    ] ++
      format_section("runtime_checks", report.runtime_checks.counts) ++
      format_section("assets", report.assets.counts) ++
      format_section("variants", report.variants.counts) ++
      format_findings(report.runtime_checks.findings) ++
      format_findings(report.variants.findings) ++
      format_upload_findings(report.upload_sessions.findings) ++
      format_upload_sessions(report.upload_sessions) ++
      format_provider_findings(report.provider_assets.findings) ++
      format_recommendations(report.recommendations) ++ ["Done."]
  end

  defp format_section(name, counts) do
    total = Map.get(counts, :total, 0)

    ["#{String.capitalize(String.replace(name, "_", " "))}:", "  total: #{total}"] ++
      (counts
       |> Enum.reject(fn {key, _value} -> key == :total end)
       |> Enum.sort_by(fn {key, _value} -> Atom.to_string(key) end)
       |> Enum.map(fn {key, value} -> "  #{key}: #{value}" end))
  end

  defp format_upload_sessions(upload_sessions) do
    format_section("upload_sessions", upload_sessions.counts) ++
      (upload_sessions.resumable
       |> Enum.sort_by(fn {key, _value} -> Atom.to_string(key) end)
       |> Enum.map(fn {key, value} -> "  #{key}: #{value}" end))
  end

  defp format_findings([]), do: ["Findings:", "  none"]

  defp format_findings(findings) do
    ["Findings:"] ++
      Enum.flat_map(findings, fn finding ->
        [
          "  #{finding.class}: #{finding.count} (oldest_age_seconds=#{finding.oldest_age_seconds})"
        ] ++
          Enum.map(finding.samples, fn sample ->
            "    - #{Map.get(sample, :variant_name) || Map.get(sample, :asset_id)}: #{sample.reason}"
          end)
      end)
  end

  defp format_upload_findings([]), do: ["Upload session findings:", "  none"]

  defp format_upload_findings(findings) do
    ["Upload session findings:"] ++
      Enum.flat_map(findings, fn finding ->
        [
          "  #{finding.state}: #{finding.count} (oldest_age_seconds=#{finding.oldest_age_seconds})"
        ] ++
          Enum.map(finding.samples, fn sample ->
            "    - #{sample.session_id}: #{sample.failure_reason || "operator attention required"}"
          end)
      end)
  end

  @doc false
  @spec format_provider_findings([map()]) :: [String.t()]
  def format_provider_findings([]), do: ["Provider asset findings:", "  none"]

  def format_provider_findings(findings) do
    ["Provider asset findings:"] ++
      Enum.flat_map(findings, fn finding ->
        [
          "  #{finding.class}: #{finding.count} (oldest_age_seconds=#{finding.oldest_age_seconds})"
        ] ++
          Enum.map(finding.samples, fn sample ->
            "    - #{sample.asset_id} (#{sample.provider_asset_id}): #{sample.reason}"
          end)
      end)
  end

  defp format_recommendations([]), do: ["Recommendations:", "  none"]

  defp format_recommendations(recommendations) do
    ["Recommendations:"] ++
      Enum.map(recommendations, fn recommendation ->
        "  #{recommendation.action} via #{recommendation.surface} — #{recommendation.summary}"
      end)
  end
end
