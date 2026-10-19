defmodule Rindle.Test.PublicSurface do
  @moduledoc false

  # Renders the public surface of the :rindle application as sorted text lines:
  #
  #   module Mod                 every lib module whose moduledoc is not hidden
  #   fun Mod.name/arity         every exported function with a non-hidden doc entry
  #   macro Mod.name/arity       every exported macro with a non-hidden doc entry
  #   callback Mod.name/arity    every behaviour callback of a public module
  #   migration file sha256      every file under priv/repo/migrations
  #
  # Exports come from __info__/1 so each default-argument arity is listed; the docs chunk
  # decides visibility (an export with no doc entry, or a hidden one, is not public).
  #
  # Regenerate the fixture only for a deliberate, separately approved API change:
  #
  #   MIX_ENV=test mix run --no-start -e 'File.write!("test/fixtures/public_surface.txt", Rindle.Test.PublicSurface.render())'

  @fixture "test/fixtures/public_surface.txt"
  @migrations_dir "priv/repo/migrations"
  @canonical_minor {1, 17}
  @regenerate_command ~s|MIX_ENV=test mix run --no-start -e 'File.write!("test/fixtures/public_surface.txt", Rindle.Test.PublicSurface.render())'|

  def fixture_path, do: @fixture

  def regenerate_command, do: @regenerate_command

  # True when `version` is the Elixir minor the committed fixture is pinned to.
  def canonical_lane?(version) when is_binary(version) do
    case Version.parse(version) do
      {:ok, %Version{major: major, minor: minor}} -> {major, minor} == @canonical_minor
      :error -> false
    end
  end

  def render do
    render(modules: lib_modules(), migrations_dir: @migrations_dir)
  end

  def render(opts) when is_list(opts) do
    modules = Keyword.fetch!(opts, :modules)
    migrations_dir = Keyword.fetch!(opts, :migrations_dir)

    lines =
      Enum.flat_map(modules, &module_lines/1) ++ migration_lines(migrations_dir)

    lines
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map_join("", &(&1 <> "\n"))
  end

  # Lines only in `expected` are prefixed "- ", lines only in `actual` "+ ".
  def diff(expected, actual) do
    exp = String.split(expected, "\n", trim: true)
    act = String.split(actual, "\n", trim: true)

    Enum.map(exp -- act, &("- " <> &1)) ++ Enum.map(act -- exp, &("+ " <> &1))
  end

  def lib_modules do
    :ok = load_app()
    lib_dir = Path.join(File.cwd!(), "lib") <> "/"

    :rindle
    |> Application.spec(:modules)
    |> Enum.filter(fn mod ->
      source = mod.module_info(:compile) |> Keyword.get(:source, ~c"") |> to_string()
      String.starts_with?(source, lib_dir)
    end)
  end

  defp load_app do
    case Application.load(:rindle) do
      :ok -> :ok
      {:error, {:already_loaded, :rindle}} -> :ok
    end
  end

  defp module_lines(mod) do
    case Code.fetch_docs(mod) do
      {:docs_v1, _anno, _lang, _format, moduledoc, _meta, entries} when moduledoc != :hidden ->
        name = inspect(mod)

        ["module " <> name] ++
          export_lines(mod, name, entries, :function, "fun") ++
          export_lines(mod, name, entries, :macro, "macro") ++
          callback_lines(mod, name)

      _ ->
        []
    end
  end

  defp export_lines(mod, name, entries, kind, label) do
    visible =
      for {{^kind, fun, arity}, _anno, _sig, doc, meta} <- entries, doc != :hidden do
        {fun, arity, Map.get(meta, :defaults, 0)}
      end

    info_key = if kind == :function, do: :functions, else: :macros

    for {fun, arity} <- mod.__info__(info_key),
        Enum.any?(visible, fn {vf, va, vd} -> vf == fun and arity <= va and arity >= va - vd end) do
      "#{label} #{name}.#{fun}/#{arity}"
    end
  end

  defp callback_lines(mod, name) do
    if function_exported?(mod, :behaviour_info, 1) do
      for {fun, arity} <- mod.behaviour_info(:callbacks), do: "callback #{name}.#{fun}/#{arity}"
    else
      []
    end
  end

  defp migration_lines(dir) do
    dir
    |> File.ls!()
    |> Enum.sort()
    |> Enum.map(fn file ->
      digest = :crypto.hash(:sha256, File.read!(Path.join(dir, file)))
      "migration #{file} #{Base.encode16(digest, case: :lower)}"
    end)
  end
end

defmodule Rindle.Test.PublicSurface.DriftSample do
  @moduledoc "Not part of the :rindle surface; used to prove an extra export shows up as drift."

  def extra(value), do: value

  @doc false
  def hidden_helper, do: :ok
end
