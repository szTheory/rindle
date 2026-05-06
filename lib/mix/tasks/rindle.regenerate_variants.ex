defmodule Mix.Tasks.Rindle.RegenerateVariants do
  @shortdoc "Broadly requeue stale or missing variants for regeneration"

  @moduledoc """
  Enqueues `ProcessVariant` Oban jobs for broad stale/missing variant
  regeneration, optionally filtered by profile module or variant name.

  This is the explicit maintenance lane for preset/profile drift and
  storage-verified missing derivatives. It is intentionally Mix-task-first and
  is not a single-asset public repair facade.

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
  Variants in `queued`, `processing`, `ready`, `failed`, or `cancelled` states
  are not part of this broad maintenance lane and will not generate duplicate
  Oban jobs.

  The `stale` state means the variant's `recipe_digest` no longer matches the
  profile's current recipe — the variant was generated from an outdated
  configuration. The `missing` state means the storage object is absent (as
  detected by a prior `mix rindle.verify_storage` run).

  ## Output

  The task emits a deterministic summary:

      Rindle: broad regeneration scan for stale/missing variants...
        enqueued: 12
        skipped:  3
        errors:   0
      Done.

  When `errors` is non-zero the task halts with exit 1 after printing the
  summary so cron / CI pipelines surface the failure.

  ## Examples

      # Requeue all stale/missing variants
      mix rindle.regenerate_variants

      # Requeue only thumb variants
      mix rindle.regenerate_variants --variant thumb

      # Requeue only stale/missing variants for a specific profile
      mix rindle.regenerate_variants --profile Elixir.MyApp.ImageProfile

  Use asset-scoped repair surfaces for one-off failed/cancelled recovery. Use
  this task when you need auditable broad maintenance after recipe drift or
  after `mix rindle.verify_storage` has marked variants as `missing`.
  """

  use Mix.Task

  alias Rindle.Ops.VariantMaintenance

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [profile: :string, variant: :string]
      )

    filters =
      %{}
      |> maybe_put(:profile, Keyword.get(opts, :profile))
      |> maybe_put(:variant_name, Keyword.get(opts, :variant))

    Mix.shell().info("Rindle: broad regeneration scan for stale/missing variants...")

    case VariantMaintenance.regenerate_variants(filters) do
      {:ok, %{enqueued: enqueued, skipped: skipped, errors: errors}} ->
        Mix.shell().info("  enqueued: #{enqueued}")
        Mix.shell().info("  skipped:  #{skipped}")
        Mix.shell().info("  errors:   #{errors}")
        Mix.shell().info("Done.")

        if errors > 0 do
          # Documented exit code: 1 — Query or job-insertion error.
          Mix.shell().error("#{errors} job insertion error(s)")
          System.halt(1)
        end

      {:error, reason} ->
        Mix.shell().error("Rindle.RegenerateVariants failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
