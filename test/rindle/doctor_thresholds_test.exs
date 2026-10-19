defmodule Rindle.DoctorThresholdsTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Doctor.{ModuleInformation, ModuleReport, ReportUtils}

  @doctor_config_path Path.expand("../../.doctor.exs", __DIR__)
  @doctor_diagnostic_module Mix.Tasks.Rindle.AbortIncompleteUploads
  @max_diagnostic_path_length 512

  setup_all do
    {config, _bindings} = Code.eval_file(@doctor_config_path)
    {:ok, modules} = :application.get_key(:rindle, :modules)
    Enum.each(modules, &Code.ensure_loaded!/1)

    all_reports =
      modules
      |> Enum.filter(&String.starts_with?(to_string(&1), "Elixir."))
      |> Enum.reject(&undocumented_protocol_implementation?/1)
      |> Enum.reject(&ignored_module?(&1, config.ignore_modules))
      |> Enum.map(&generate_report/1)

    reports =
      all_reports
      |> Enum.filter(&String.starts_with?(&1.file, "lib/"))

    {:ok, config: config, reports: reports}
  end

  test "the configured Doctor ratchet holds full doc and 95% spec coverage", %{config: config} do
    assert config.min_module_doc_coverage == 100
    assert config.min_overall_doc_coverage == 100
    assert config.min_overall_moduledoc_coverage == 100
    assert config.min_module_spec_coverage == 95
    assert config.min_overall_spec_coverage == 95
  end

  test "the compiled public surface satisfies the Doctor ratchet", %{
    config: config,
    reports: reports
  } do
    expected_public_modules =
      Mix.Project.config()
      |> Keyword.fetch!(:docs)
      |> Keyword.fetch!(:groups_for_modules)
      |> Keyword.values()
      |> List.flatten()
      |> Kernel.++([Rindle.Processor.AV])
      |> Enum.map(&inspect/1)

    measured_modules = MapSet.new(reports, & &1.module)

    assert Enum.all?(expected_public_modules, &MapSet.member?(measured_modules, &1)),
           "Doctor omitted ExDoc modules: #{inspect(Enum.reject(expected_public_modules, &MapSet.member?(measured_modules, &1)))}"

    unhealthy_modules =
      Enum.reject(reports, &ReportUtils.module_passed_validation?(&1, config))

    assert unhealthy_modules == [],
           "Doctor found unhealthy checked modules: #{inspect(Enum.map(unhealthy_modules, & &1.module))}"

    assert ReportUtils.doctor_report_passed?(reports, config)

    assert_at_least(
      ReportUtils.calc_overall_doc_coverage(reports),
      config.min_overall_doc_coverage,
      "overall documentation coverage"
    )

    assert_at_least(
      ReportUtils.calc_overall_moduledoc_coverage(reports),
      config.min_overall_moduledoc_coverage,
      "overall moduledoc coverage"
    )

    assert_at_least(
      ReportUtils.calc_overall_spec_coverage(reports),
      config.min_overall_spec_coverage,
      "overall typespec coverage"
    )
  end

  defp assert_at_least(measured, threshold, label) do
    assert Decimal.gte?(measured, Decimal.new(threshold)),
           "expected #{label} to be at least #{threshold}%, got #{Decimal.to_string(measured)}%"
  end

  defp undocumented_protocol_implementation?(module) do
    function_exported?(module, :__impl__, 1) and match?({:error, _}, fetch_module_docs(module))
  end

  defp ignored_module?(module, ignore_modules) do
    Enum.any?(ignore_modules, fn
      %Regex{} = regex -> Regex.match?(regex, inspect(module))
      ignored -> ignored == module
    end)
  end

  defp generate_report(module) do
    module
    |> fetch_module_docs()
    |> ModuleInformation.build(module)
    |> ModuleInformation.load_file_ast()
    |> ModuleInformation.load_user_defined_functions()
    |> ModuleReport.build()
  end

  defp fetch_module_docs(module) do
    beam_path = Application.app_dir(:rindle, "ebin/#{Atom.to_string(module)}.beam")

    provenance =
      if module == @doctor_diagnostic_module do
        capture_doctor_provenance(module, beam_path)
      end

    result = Code.fetch_docs(beam_path)

    if provenance, do: emit_doctor_provenance(provenance, result)

    result
  end

  defp capture_doctor_provenance(module, beam_path) do
    worktree = File.cwd!()

    %{
      "schema_version" => 1,
      "kind" => "rindle_doctor_provenance",
      "module" => inspect(module),
      "app_dir" => diagnostic_path(Application.app_dir(:rindle), worktree),
      "code_lib_dir" => diagnostic_path(:code.lib_dir(:rindle), worktree),
      "code_which" => diagnostic_path(:code.which(module), worktree),
      "beam_path" => diagnostic_path(beam_path, worktree),
      "beam" => beam_file_metadata(beam_path, worktree)
    }
  end

  defp emit_doctor_provenance(fields, docs_result) do
    fields = Map.put(fields, "docs_result_category", docs_result_category(docs_result))

    marker_sha256 =
      fields
      |> Jason.encode!()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    marker = Map.put(fields, "marker_sha256", marker_sha256)
    IO.puts(:stderr, "GSD_DOCTOR_PROVENANCE " <> Jason.encode!(marker))
  end

  defp diagnostic_path(path, worktree) when is_list(path) do
    path
    |> List.to_string()
    |> diagnostic_path(worktree)
  end

  defp diagnostic_path(path, worktree) when is_binary(path) do
    with {:ok, canonical_path} <- canonical_path(path),
         {:ok, canonical_worktree} <- canonical_path(worktree) do
      relative_path = Path.relative_to(canonical_path, canonical_worktree)

      if relative_path == canonical_path or relative_path == ".." or
           String.starts_with?(relative_path, "../") do
        "outside_worktree"
      else
        String.slice(relative_path, 0, @max_diagnostic_path_length)
      end
    else
      _ -> "outside_worktree"
    end
  end

  defp diagnostic_path(:non_existing, _worktree), do: "non_existing"
  defp diagnostic_path({:error, reason}, _worktree) when is_atom(reason), do: "error:#{reason}"
  defp diagnostic_path({:error, _reason}, _worktree), do: "error"
  defp diagnostic_path(_other, _worktree), do: "unavailable"

  defp canonical_path(path), do: canonical_path(path, 0)

  defp canonical_path(path, symlink_hops) when is_list(path) do
    path
    |> List.to_string()
    |> canonical_path(symlink_hops)
  end

  defp canonical_path(path, symlink_hops) when is_binary(path) do
    absolute_path =
      if String.starts_with?(path, "/"), do: path, else: File.cwd!() <> "/" <> path

    case Path.split(absolute_path) do
      ["/" | components] -> canonical_components(components, "/", symlink_hops)
      _ -> {:error, :invalid_path}
    end
  end

  defp canonical_components([], current, _symlink_hops), do: {:ok, current}

  defp canonical_components([component | rest], current, symlink_hops) do
    case component do
      "" -> canonical_components(rest, current, symlink_hops)
      "." -> canonical_components(rest, current, symlink_hops)
      ".." -> canonical_components(rest, Path.dirname(current), symlink_hops)
      _ -> resolve_component(component, rest, current, symlink_hops)
    end
  end

  defp resolve_component(component, rest, current, symlink_hops) do
    candidate = Path.join(current, component)

    case File.lstat(candidate) do
      {:ok, %File.Stat{type: :symlink}} ->
        resolve_symlink(candidate, rest, current, symlink_hops)

      {:ok, _stat} ->
        canonical_components(rest, candidate, symlink_hops)

      {:error, :enoent} ->
        missing_path = Enum.join([component | rest], "/")
        {:ok, Path.expand(Path.join(current, missing_path))}

      {:error, _reason} ->
        {:error, :unresolved_path}
    end
  end

  defp resolve_symlink(_candidate, _rest, _current, symlink_hops) when symlink_hops >= 40,
    do: {:error, :too_many_symlinks}

  defp resolve_symlink(candidate, rest, current, symlink_hops) do
    with {:ok, target} <- File.read_link(candidate) do
      target_path =
        if String.starts_with?(target, "/"), do: target, else: Path.join(current, target)

      resumed_path = Enum.reduce(rest, target_path, &(&2 <> "/" <> &1))
      canonical_path(resumed_path, symlink_hops + 1)
    end
  end

  defp beam_file_metadata(beam_path, worktree) do
    case diagnostic_path(beam_path, worktree) do
      "outside_worktree" ->
        %{
          "presence" => "outside_worktree",
          "type" => "unknown",
          "byte_size" => nil,
          "sha256" => nil
        }

      _relative_path ->
        stat_beam_file(beam_path)
    end
  end

  defp stat_beam_file(beam_path) do
    case File.stat(beam_path) do
      {:ok, %File.Stat{type: :regular, size: size}} ->
        read_beam_file(beam_path, size)

      {:ok, %File.Stat{type: type, size: size}} ->
        %{
          "presence" => "unreadable",
          "type" => Atom.to_string(type),
          "byte_size" => size,
          "sha256" => nil
        }

      {:error, :enoent} ->
        %{
          "presence" => "absent",
          "type" => "missing",
          "byte_size" => nil,
          "sha256" => nil
        }

      {:error, _reason} ->
        %{
          "presence" => "unreadable",
          "type" => "unknown",
          "byte_size" => nil,
          "sha256" => nil
        }
    end
  end

  defp read_beam_file(beam_path, size) do
    case File.read(beam_path) do
      {:ok, contents} ->
        %{
          "presence" => "present",
          "type" => "file",
          "byte_size" => size,
          "sha256" =>
            contents
            |> then(&:crypto.hash(:sha256, &1))
            |> Base.encode16(case: :lower)
        }

      {:error, _reason} ->
        %{
          "presence" => "unreadable",
          "type" => "file",
          "byte_size" => size,
          "sha256" => nil
        }
    end
  end

  defp docs_result_category({:docs_v1, _anno, _lang, _moduledoc, _metadata, _docs}), do: "docs_v1"
  defp docs_result_category({:error, :module_not_found}), do: "module_not_found"
  defp docs_result_category({:error, :chunk_not_found}), do: "chunk_not_found"
  defp docs_result_category({:error, :invalid_beam}), do: "invalid_beam"
  defp docs_result_category({:error, _reason}), do: "other_error"
  defp docs_result_category(_other), do: "other_error"
end
