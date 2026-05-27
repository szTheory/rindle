defmodule Mix.Tasks.Rindle.BatchOwnerErasure do
  @shortdoc "Preview or execute batch owner-erasure for a JSON owners file"

  @moduledoc """
  Operator CLI for batch owner/account erasure across multiple owners.

  Thin wrapper over `Rindle.preview_batch_owner_erasure/2` and
  `Rindle.erase_batch_owner_erasure/2` — no new orchestration logic.

  ## Usage

      mix rindle.batch_owner_erasure --owners-file PATH [--dry-run | --no-dry-run | --execute] [--format text|json] [--max-owners N]

  ## Options

    * `--owners-file PATH` — **required** JSON file with an array of owner entries
    * `--dry-run` — explicitly request preview mode (also the default when no
      destructive flag is given)
    * `--no-dry-run` — perform destructive batch erasure
    * `--execute` — alias for destructive batch erasure (same as `--no-dry-run`)
    * `--format` — `text` (default) or `json`
    * `--max-owners N` — per-call owner limit passed to the batch facade

  ## Owners file format

  JSON array of objects with string keys `owner_type` and `owner_id`:

      [
        {"owner_type": "Elixir.MyApp.User", "owner_id": "11111111-2222-3333-4444-555555555555"}
      ]

  `owner_type` must be a fully-qualified module name that already exists in the
  VM (`String.to_existing_atom/1`). `owner_id` must be a valid UUID. Each entry
  becomes `struct(Module, id: uuid)` with no database fetch.

  ## Exit codes

    * `0` — batch completed successfully (preview or execute)
    * `1` — any error, including partial batch failure after printing the partial report

  ## Safety default

  Preview (dry-run) unless `--no-dry-run` or `--execute` is given. Destructive
  batch erasure always requires an explicit opt-in flag.

  ## Examples

      # Preview what would be detached/purged (safe default)
      mix rindle.batch_owner_erasure --owners-file owners.json

      # Explicit preview
      mix rindle.batch_owner_erasure --owners-file owners.json --dry-run

      # Destructive execute
      mix rindle.batch_owner_erasure --owners-file owners.json --execute

      # Machine-readable preview report
      mix rindle.batch_owner_erasure --owners-file owners.json --format json

  See also `guides/operations.md` and `guides/user_flows.md` for operator workflows.
  """

  use Mix.Task

  alias Rindle.Error

  @requirements ["app.start"]

  @impl Mix.Task
  def run(argv) do
    {opts, _args, _invalid} =
      OptionParser.parse(argv,
        strict: [
          owners_file: :string,
          dry_run: :boolean,
          no_dry_run: :boolean,
          execute: :boolean,
          format: :string,
          max_owners: :integer
        ]
      )

    unless owners_file = Keyword.get(opts, :owners_file) do
      Mix.shell().error("--owners-file PATH is required. See `mix help rindle.batch_owner_erasure`.")
      exit({:shutdown, 1})
    end

    dry_run? = resolve_dry_run?(opts)
    format = resolve_format!(opts)
    batch_opts = maybe_max_owners_opts(opts)

    owners =
      owners_file
      |> File.read!()
      |> parse_owners_entries()

    runner =
      if dry_run?, do: &Rindle.preview_batch_owner_erasure/2, else: &Rindle.erase_batch_owner_erasure/2

    case runner.(owners, batch_opts) do
      {:ok, report} ->
        print_report(report, format, dry_run?)
        :ok

      {:error, {:batch_owner_failed, detail}} ->
        print_report(detail.partial_report, format, dry_run?)
        Mix.shell().error(Error.message(%{reason: {:batch_owner_failed, detail}}))
        exit({:shutdown, 1})

      {:error, reason} ->
        Mix.shell().error(Error.message(%{reason: reason}))
        exit({:shutdown, 1})
    end
  end

  @doc false
  def parse_owners_entries(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, decoded} when is_list(decoded) ->
        owners = Enum.map(decoded, &parse_owner_entry/1)

        if owners == [] do
          Mix.shell().error("Owners file must contain at least one owner entry.")
          exit({:shutdown, 1})
        end

        owners

      {:ok, _} ->
        Mix.shell().error("Owners file must be a JSON array of owner entries.")
        exit({:shutdown, 1})

      {:error, reason} ->
        Mix.shell().error("Owners file is not valid JSON: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  @doc false
  def format_text_report(report, dry_run?) do
    prefix = if dry_run?, do: "[DRY RUN] ", else: ""

    header = [
      "#{prefix}Batch owner erasure report:",
      "  owners:                    #{length(report.owners)}",
      "  attachments_to_detach:     #{report.attachments_to_detach.count}",
      "  assets_to_purge:           #{report.assets_to_purge.count}",
      "  retained_shared_assets:    #{report.retained_shared_assets.count}"
    ]

    owner_lines =
      Enum.map(report.owners, fn %{owner: {owner_type, owner_id}} ->
        "  - #{owner_type}:#{owner_id}"
      end)

    header ++ owner_lines
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp resolve_dry_run?(opts) do
    case Keyword.fetch(opts, :dry_run) do
      {:ok, value} -> value
      :error -> not (Keyword.get(opts, :execute, false) || Keyword.get(opts, :no_dry_run, false))
    end
  end

  defp resolve_format!(opts) do
    case Keyword.get(opts, :format, "text") do
      format when format in ["text", "json"] ->
        format

      other ->
        Mix.shell().error("Unknown --format #{inspect(other)}; use text or json.")
        exit({:shutdown, 1})
    end
  end

  defp maybe_max_owners_opts(opts) do
    case Keyword.get(opts, :max_owners) do
      nil -> []
      n -> [max_owners: n]
    end
  end

  defp parse_owner_entry(%{"owner_type" => owner_type, "owner_id" => owner_id}) do
    case Ecto.UUID.cast(owner_id) do
      {:ok, uuid} ->
        mod = resolve_owner_module(owner_type)
        struct(mod, id: uuid)

      :error ->
        Mix.shell().error("Invalid owner_id UUID in owners file: #{inspect(owner_id)}")
        exit({:shutdown, 1})
    end
  end

  defp parse_owner_entry(entry) do
    Mix.shell().error(
      "Each owners file entry must have string keys owner_type and owner_id; got: #{inspect(entry)}"
    )

    exit({:shutdown, 1})
  end

  defp resolve_owner_module(owner_type) do
    mod =
      try do
        String.to_existing_atom(owner_type)
      rescue
        ArgumentError ->
          Mix.shell().error(
            "Unknown owner_type module #{owner_type} (atom does not exist). Load the module before running this task."
          )

          exit({:shutdown, 1})
      end

    case Code.ensure_loaded(mod) do
      {:module, ^mod} ->
        mod

      {:error, reason} ->
        Mix.shell().error("Could not load owner_type module #{owner_type}: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp print_report(report, "json", _dry_run?) do
    Mix.shell().info(Jason.encode!(report, pretty: true))
  end

  defp print_report(report, "text", dry_run?) do
    Enum.each(format_text_report(report, dry_run?), fn line -> Mix.shell().info(line) end)
  end
end
