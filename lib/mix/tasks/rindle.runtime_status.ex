defmodule Mix.Tasks.Rindle.RuntimeStatus do
  @shortdoc "Reports bounded runtime diagnostics for assets, variants, and upload sessions"

  @moduledoc """
  Reports bounded runtime diagnostics for Rindle lifecycle work.

  The public API surface is `Rindle.runtime_status/1`; this Mix task is the
  operator-facing text/JSON wrapper over that read-only report.

  ## Usage

      mix rindle.runtime_status [--profile PROFILE] [--older-than-sec N] [--limit N] [--format text|json]

  ## Options

    * `--profile` — restrict findings and counts to a profile module name.
    * `--older-than-sec` — restrict findings to rows older than the given age in seconds.
    * `--limit` — cap the number of samples shown per finding bucket.
    * `--format` — `text` (default) or `json`.
    * `--provider-stuck` — surface streaming-provider rows stuck in `:uploading`
      or `:processing` past the configured threshold (default 7200s;
      `--older-than-sec` OVERRIDES the default when provided). Each sample
      includes the full `MediaAsset` UUID and the REDACTED last-4-char
      `provider_asset_id` tag (security invariant 14).
  """

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [
          profile: :string,
          older_than_sec: :integer,
          limit: :integer,
          format: :string,
          provider_stuck: :boolean
        ]
      )

    filters =
      %{}
      |> maybe_put(:profile, Keyword.get(opts, :profile))
      |> maybe_put(:older_than, Keyword.get(opts, :older_than_sec))
      |> maybe_put(:limit, Keyword.get(opts, :limit))
      |> maybe_put(:format, Keyword.get(opts, :format))
      |> maybe_put(:provider_stuck, Keyword.get(opts, :provider_stuck))

    case Rindle.runtime_status(filters) do
      {:ok, report} ->
        case report.filters.format do
          :json ->
            Mix.shell().info(Jason.encode!(report, pretty: true))

          :text ->
            print_text_report(report)
        end

      {:error, reason} ->
        Mix.shell().error("Rindle.RuntimeStatus failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  @doc false
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

  defp print_text_report(report) do
    Enum.each(format_text_report(report), fn line -> Mix.shell().info(line) end)
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
            "    - #{sample.variant_name || sample.asset_id}: #{sample.reason}"
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

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
