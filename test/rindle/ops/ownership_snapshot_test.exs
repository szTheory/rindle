defmodule Rindle.Ops.OwnershipSnapshotTest do
  use ExUnit.Case, async: true

  alias Rindle.Ops.OwnershipSnapshot

  @relations Rindle.Migration.V1.owned_relations()

  test "classifies a complete marker-backed other prefix when public is expected" do
    snapshot =
      OwnershipSnapshot.inspect(
        expected_prefix: "public",
        catalogs: %{
          "public" => incomplete_catalog(),
          "rindle" => complete_catalog()
        },
        oban_jobs_catalog: %{exists?: true, prefix: "public"}
      )

    assert snapshot.rindle.classification == :rindle_prefix_mismatch
    assert snapshot.rindle.expected_prefix == "public"
    assert snapshot.rindle.observed_prefix == "rindle"
    assert snapshot.rindle.owner == :rindle
  end

  test "classifies a complete marker-backed other prefix when rindle is expected" do
    snapshot =
      OwnershipSnapshot.inspect(
        expected_prefix: "rindle",
        catalogs: %{
          "public" => complete_catalog(),
          "rindle" => incomplete_catalog()
        },
        oban_jobs_catalog: %{exists?: true, prefix: "public"}
      )

    assert snapshot.rindle.classification == :rindle_prefix_mismatch
    assert snapshot.rindle.expected_prefix == "rindle"
    assert snapshot.rindle.observed_prefix == "public"
    assert snapshot.rindle.owner == :rindle
  end

  defp complete_catalog do
    %{marker_versions: [1], relations: @relations}
  end

  defp incomplete_catalog do
    %{marker_versions: [], relations: @relations -- ["media_variants"]}
  end
end
