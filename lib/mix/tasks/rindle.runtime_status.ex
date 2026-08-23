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

  alias Mix.Tasks.Rindle.RuntimeStatus.Formatter

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

    json? = Keyword.get(opts, :format) == "json"

    case Rindle.runtime_status(filters) do
      {:ok, report} ->
        case report.filters.format do
          :json ->
            Mix.shell().info(Jason.encode!(report, pretty: true))

          :text ->
            print_text_report(report)
        end

      {:error, reason} ->
        print_error(reason, json?)
        exit({:shutdown, 1})
    end
  end

  @doc false
  @spec format_error(term()) :: String.t()
  def format_error(reason), do: Formatter.format_error(reason)

  @doc false
  @spec format_json_error(term()) :: map()
  def format_json_error(reason), do: Formatter.format_json_error(reason)

  defp print_error(reason, true),
    do: Mix.shell().info(Jason.encode!(Formatter.format_json_error(reason)))

  defp print_error(reason, false), do: Mix.shell().error(Formatter.format_error(reason))

  @doc false
  @spec format_text_report(Rindle.Ops.RuntimeStatus.report()) :: [String.t()]
  def format_text_report(report), do: Formatter.format_text_report(report)

  defp print_text_report(report) do
    Enum.each(Formatter.format_text_report(report), fn line -> Mix.shell().info(line) end)
  end

  @doc false
  @spec format_provider_findings([map()]) :: [String.t()]
  def format_provider_findings(findings), do: Formatter.format_provider_findings(findings)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
