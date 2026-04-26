defmodule Mix.Tasks.Rindle.RegenerateVariants do
  @shortdoc "Requeue stale or missing variants for regeneration"

  @moduledoc """
  Enqueues `ProcessVariant` Oban jobs for all stale or missing variants,
  optionally filtered by profile module or variant name.

  ## Usage

      mix rindle.regenerate_variants [--profile PROFILE] [--variant VARIANT_NAME]

  ## Options

    * `--profile` — Restrict to variants whose asset has this profile module name.
      Example: `--profile Elixir.MyApp.AvatarProfile`

    * `--variant` — Restrict to variants with this name.
      Example: `--variant thumb`

  ## Exit codes

    * `0` — Operation completed (even if 0 variants were enqueued).
    * `1` — Query or job-insertion error.

  ## Targeting rules

  Only variants in `stale` or `missing` states are eligible for re-enqueueing.
  Variants that are `queued`, `processing`, or `ready` are counted as skipped
  and will not generate duplicate Oban jobs.

  The `stale` state means the variant's `recipe_digest` no longer matches the
  profile's current recipe — the variant was generated from an outdated
  configuration. The `missing` state means the storage object is absent (as
  detected by a prior `mix rindle.verify_storage` run).

  ## Output

  The task emits a deterministic summary:

      Rindle: scanning for stale/missing variants...
        enqueued: 12
        skipped:  3
      Done.

  ## Examples

      # Requeue all stale/missing variants
      mix rindle.regenerate_variants

      # Requeue only thumb variants
      mix rindle.regenerate_variants --variant thumb

      # Requeue only stale/missing variants for a specific profile
      mix rindle.regenerate_variants --profile Elixir.MyApp.ImageProfile

  The task reports the number of enqueued and skipped variants on completion.
  """

  use Mix.Task

  alias Rindle.Ops.VariantMaintenance

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [profile: :string, variant: :string]
      )

    filters =
      %{}
      |> maybe_put(:profile, Keyword.get(opts, :profile))
      |> maybe_put(:variant_name, Keyword.get(opts, :variant))

    Mix.shell().info("Rindle: scanning for stale/missing variants...")

    case VariantMaintenance.regenerate_variants(filters) do
      {:ok, %{enqueued: enqueued, skipped: skipped}} ->
        Mix.shell().info("  enqueued: #{enqueued}")
        Mix.shell().info("  skipped:  #{skipped}")
        Mix.shell().info("Done.")

      {:error, reason} ->
        Mix.shell().error("Rindle.RegenerateVariants failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
