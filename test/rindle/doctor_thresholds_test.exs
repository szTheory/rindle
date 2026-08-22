defmodule Rindle.DoctorThresholdsTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Doctor.{CLI, ReportUtils}

  @doctor_config_path Path.expand("../../.doctor.exs", __DIR__)

  setup_all do
    {config, _bindings} = Code.eval_file(@doctor_config_path)

    reports =
      config
      |> CLI.generate_module_report_list()
      |> Enum.filter(&String.starts_with?(&1.file, "lib/"))

    {:ok, config: config, reports: reports}
  end

  test "the configured Doctor ratchet remains at the D-07 target", %{config: config} do
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
           "Doctor omitted an ExDoc-grouped public module"

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
end
