defmodule Mix.Tasks.Rindle.VerifyStorage do
  @shortdoc "Reconcile DB variant records against storage objects"

  @moduledoc """
  Walks variant records that have a `storage_key` and HEAD-checks the storage
  object via the profile's configured storage adapter.

  Variants where the object is absent (`{:error, :not_found}`) are flipped to
  `missing` state. Other error types (network errors, auth failures) are counted
  separately without mutating the record.

  ## Usage

      mix rindle.verify_storage [--profile PROFILE] [--variant VARIANT_NAME]

  ## Options

    * `--profile` — Restrict to variants whose asset has this profile module name.
      Example: `--profile Elixir.MyApp.AvatarProfile`

    * `--variant` — Restrict to variants with this name.
      Example: `--variant thumb`

  ## Exit codes

    * `0` — Reconciliation completed cleanly (zero storage errors). Missing
      variants do not affect the exit code — they are an expected, recoverable
      outcome that gets reflected in the next regenerate run.
    * `1` — Query failure, OR one or more non-`:not_found` storage errors
      occurred during HEAD checks (e.g. connection refused, auth failure).
      The summary is still printed before halting so operators can see the
      partial counts.

  ## Output

  The task emits a deterministic summary that is script-friendly:

      Rindle: verifying storage for variants...
        checked:  10
        present:  8
        missing:  2
        errors:   0
      Done.

  The summary is stable and pipe-friendly (no progress bars or spinners).

  ## Reconciliation behavior

  Variants are eligible for verification when they have a non-nil `storage_key`
  and are in one of the following states: `ready`, `stale`, `missing`, or
  `failed`. Variants without a `storage_key` (e.g., `planned`, `queued`) are
  skipped entirely.

  On each HEAD call:

    * `{:ok, _}` — object is present; variant state is left unchanged.
    * `{:error, :not_found}` — object is absent; variant is flipped to `missing`.
    * `{:error, other}` — unexpected error (network, auth); counted as an error
      but the variant state is not mutated. Investigate manually if error count
      is non-zero.

  ## Examples

      # Verify all variants
      mix rindle.verify_storage

      # Verify only thumb variants
      mix rindle.verify_storage --variant thumb

      # Verify only variants for a specific profile
      mix rindle.verify_storage --profile Elixir.MyApp.AvatarProfile
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

    Mix.shell().info("Rindle: verifying storage for variants...")

    case VariantMaintenance.verify_storage(filters) do
      {:ok, %{checked: checked, present: present, missing: missing, errors: errors}} ->
        Mix.shell().info("  checked:  #{checked}")
        Mix.shell().info("  present:  #{present}")
        Mix.shell().info("  missing:  #{missing}")
        Mix.shell().info("  errors:   #{errors}")
        Mix.shell().info("Done.")

        if errors > 0 do
          # Documented exit code: 1 — Query or storage connection failure.
          # Non-:not_found storage errors during HEAD checks (network, auth,
          # adapter resolution) need to surface so cron / CI alerts fire.
          Mix.shell().error("#{errors} storage error(s) during verification")
          System.halt(1)
        end

      {:error, reason} ->
        Mix.shell().error("Rindle.VerifyStorage failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
