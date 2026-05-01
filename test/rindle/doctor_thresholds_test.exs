defmodule Rindle.DoctorThresholdsTest do
  @moduledoc """
  D-23 ratchet harness: asserts `.doctor.exs` configures the D-07 target thresholds.

  This test ships RED in Plan 18-01 (because `.doctor.exs` ships at baseline thresholds).
  It turns green in Plan 18-05 when thresholds ratchet to the locked target values
  (100/100/100/95/95).

  See: .planning/phases/18-documentation-and-typespec-coverage/18-CONTEXT.md (D-07, D-22, D-23).
  """

  use ExUnit.Case, async: true

  @doctor_config_path Path.expand("../../.doctor.exs", __DIR__)

  setup_all do
    {config, _bindings} = Code.eval_file(@doctor_config_path)
    {:ok, config: config}
  end

  test "min_module_doc_coverage is at the D-07 target", %{config: config} do
    assert config.min_module_doc_coverage == 100,
           "Expected min_module_doc_coverage == 100 (D-07 target), got #{inspect(config.min_module_doc_coverage)}. " <>
             "Plan 18-05 ratchets this from baseline."
  end

  test "min_overall_doc_coverage is at the D-07 target", %{config: config} do
    assert config.min_overall_doc_coverage == 100,
           "Expected min_overall_doc_coverage == 100 (D-07 target), got #{inspect(config.min_overall_doc_coverage)}."
  end

  test "min_overall_moduledoc_coverage is at the D-07 target", %{config: config} do
    assert config.min_overall_moduledoc_coverage == 100,
           "Expected min_overall_moduledoc_coverage == 100 (D-07 target), got #{inspect(config.min_overall_moduledoc_coverage)}."
  end

  test "min_module_spec_coverage is at the D-07 target", %{config: config} do
    assert config.min_module_spec_coverage == 95,
           "Expected min_module_spec_coverage == 95 (D-07 target), got #{inspect(config.min_module_spec_coverage)}."
  end

  test "min_overall_spec_coverage is at the D-07 target", %{config: config} do
    assert config.min_overall_spec_coverage == 95,
           "Expected min_overall_spec_coverage == 95 (D-07 target), got #{inspect(config.min_overall_spec_coverage)}."
  end
end
