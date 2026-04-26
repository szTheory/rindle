defmodule Mix.Tasks.Rindle.BackfillMetadata do
  @shortdoc "Reanalyze existing assets and persist updated metadata"

  @moduledoc """
  Reruns the configured analyzer for assets in `ready`, `available`, or
  `degraded` states and persists the updated metadata to the database.

  This is the recovery path when analyzer output changes (new fields added,
  bug fixes in analysis logic, or assets promoted before analysis ran).

  The CLI is a thin wrapper around `Rindle.Ops.MetadataBackfill.backfill_metadata/1`
  (T-04-09 mitigation: arguments cannot bypass the analyzer or persistence rules).

  ## Usage

      mix rindle.backfill_metadata [--storage MODULE] [--analyzer MODULE] [--profile PROFILE]

  ## Options

    * `--storage MODULE` — fully-qualified storage adapter module used to
      download asset source files. Defaults to the `:default_storage` configured
      in the `:rindle` application environment.
    * `--analyzer MODULE` — fully-qualified analyzer module. Defaults to
      `:default_analyzer` in the `:rindle` application environment.
    * `--profile PROFILE` — restrict backfill to assets with this profile string
      (e.g. `Elixir.MyApp.AvatarProfile`). When omitted, all eligible assets
      are processed.

  ## Exit codes

    * `0` — backfill completed with no failures.
    * `1` — one or more asset failures occurred (errors are logged and counted).

  ## Examples

      # Backfill all eligible assets using configured defaults
      mix rindle.backfill_metadata

      # Backfill with a specific storage adapter
      mix rindle.backfill_metadata --storage Rindle.Storage.Local

      # Restrict to a specific profile
      mix rindle.backfill_metadata --profile Elixir.MyApp.AvatarProfile

      # Full override (useful for one-off operations with a test adapter)
      mix rindle.backfill_metadata \\
        --storage Rindle.Storage.S3 \\
        --analyzer Rindle.Analyzer.Image

  ## Notes

  Only `ready`, `available`, and `degraded` assets are processed. Assets in
  terminal or in-progress states are skipped automatically.

  Failures in individual assets are counted and reported but do not abort
  the run; the task exits non-zero only if the total failure count is greater
  than zero.
  """

  use Mix.Task

  alias Rindle.Ops.MetadataBackfill

  @requirements ["app.start"]

  @impl Mix.Task
  def run(argv) do
    {opts, _args, _invalid} =
      OptionParser.parse(argv,
        strict: [storage: :string, analyzer: :string, profile: :string]
      )

    storage_mod = resolve_module(opts, :storage, :default_storage)
    analyzer_mod = resolve_module(opts, :analyzer, :default_analyzer)

    unless storage_mod do
      Mix.shell().error(
        "No storage adapter configured. Provide --storage MODULE or set config :rindle, :default_storage."
      )

      exit({:shutdown, 1})
    end

    unless analyzer_mod do
      Mix.shell().error(
        "No analyzer configured. Provide --analyzer MODULE or set config :rindle, :default_analyzer."
      )

      exit({:shutdown, 1})
    end

    backfill_opts =
      [storage: storage_mod, analyzer: analyzer_mod]
      |> maybe_put_profile(opts)

    Mix.shell().info("Starting metadata backfill...")

    case MetadataBackfill.backfill_metadata(backfill_opts) do
      {:ok, report} ->
        print_report(report)
        maybe_exit_nonzero(report.failures)
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp resolve_module(opts, opt_key, app_config_key) do
    case Keyword.get(opts, opt_key) do
      nil ->
        Application.get_env(:rindle, app_config_key)

      module_str ->
        load_module(module_str, opt_key)
    end
  end

  # Use String.to_existing_atom/1 so untrusted operator input cannot exhaust
  # the atom table (T-04-09). After loading, validate the resolved module
  # implements the expected callback for its role.
  defp load_module(module_str, opt_key) do
    mod =
      try do
        String.to_existing_atom(module_str)
      rescue
        ArgumentError ->
          Mix.shell().error(
            "Module #{module_str} is not a known atom (load order or typo?)."
          )

          exit({:shutdown, 1})
      end

    case Code.ensure_loaded(mod) do
      {:module, ^mod} ->
        unless implements_expected_callback?(mod, opt_key) do
          Mix.shell().error(
            "Module #{module_str} does not implement the expected #{opt_key} behaviour."
          )

          exit({:shutdown, 1})
        end

        mod

      {:error, reason} ->
        Mix.shell().error("Could not load module #{module_str}: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp implements_expected_callback?(mod, :storage), do: function_exported?(mod, :download, 3)
  defp implements_expected_callback?(mod, :analyzer), do: function_exported?(mod, :analyze, 1)

  defp maybe_put_profile(opts, argv_opts) do
    case Keyword.get(argv_opts, :profile) do
      nil -> opts
      profile -> Keyword.put(opts, :profile, profile)
    end
  end

  defp print_report(report) do
    Mix.shell().info("""
    Metadata backfill complete:
      Assets found:   #{report.assets_found}
      Assets updated: #{report.assets_updated}
      Failures:       #{report.failures}
    """)
  end

  defp maybe_exit_nonzero(0), do: :ok

  defp maybe_exit_nonzero(failure_count) do
    Mix.shell().error("#{failure_count} asset(s) could not be backfilled.")
    exit({:shutdown, 1})
  end
end
