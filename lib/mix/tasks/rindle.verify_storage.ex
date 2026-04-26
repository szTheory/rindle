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

    * `0` — Reconciliation completed (even when missing variants are found).
    * `1` — Query or storage connection failure.

  ## Output

  The task emits a deterministic summary that is script-friendly:

      Rindle: verifying storage for variants...
        checked:  10
        present:  8
        missing:  2
        errors:   0
      Done.

  The summary is stable and pipe-friendly (no progress bars or spinners).

  ## Examples

      # Verify all variants
      mix rindle.verify_storage

      # Verify only thumb variants
      mix rindle.verify_storage --variant thumb
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

      {:error, reason} ->
        Mix.shell().error("Rindle.VerifyStorage failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
