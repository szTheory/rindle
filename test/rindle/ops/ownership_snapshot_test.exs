defmodule Rindle.Ops.OwnershipSnapshotTest do
  use ExUnit.Case, async: true

  alias Rindle.Ops.OwnershipSnapshot

  @relations Rindle.Migration.V1.owned_relations()

  test "classifies a complete marker-backed other prefix when public is expected" do
    snapshot =
      OwnershipSnapshot.inspect(
        expected_prefix: "public",
        catalogs: %{
          "public" => empty_catalog(),
          "rindle" => complete_catalog()
        },
        oban_binding: valid_oban_binding(),
        compatibility_oban_prefix: "public",
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
          "rindle" => empty_catalog()
        },
        oban_binding: valid_oban_binding(prefix: "public"),
        compatibility_oban_prefix: "public",
        oban_jobs_catalog: %{exists?: true, prefix: "public"}
      )

    assert snapshot.rindle.classification == :rindle_prefix_mismatch
    assert snapshot.rindle.expected_prefix == "rindle"
    assert snapshot.rindle.observed_prefix == "public"
    assert snapshot.rindle.owner == :rindle
  end

  test "uses the valid default Oban binding as the only canonical prefix source" do
    snapshot =
      OwnershipSnapshot.inspect(
        catalogs: healthy_catalogs("public"),
        oban_binding: valid_oban_binding(),
        compatibility_oban_prefix: "public",
        oban_jobs_catalog: %{exists?: true, prefix: "public"}
      )

    assert snapshot.oban.classification == :ready
    assert snapshot.oban.expected_prefix == "public"
    assert snapshot.oban.observed_prefix == "public"
  end

  test "accepts a safe explicit host Oban prefix" do
    snapshot =
      OwnershipSnapshot.inspect(
        catalogs: healthy_catalogs("public"),
        oban_binding: valid_oban_binding(prefix: "host_oban"),
        compatibility_oban_prefix: "host_oban",
        oban_jobs_catalog: %{exists?: true, prefix: "host_oban"}
      )

    assert snapshot.oban.classification == :ready
    assert snapshot.oban.expected_prefix == "host_oban"
  end

  test "refuses binding drift before invoking either catalog seam" do
    parent = self()

    snapshot =
      OwnershipSnapshot.inspect(
        oban_binding: valid_oban_binding(prefix: "host_oban"),
        compatibility_oban_prefix: "public",
        catalog_reader: fn _prefix ->
          send(parent, :catalog_read)
          complete_catalog()
        end,
        oban_jobs_catalog: fn _prefix ->
          send(parent, :oban_catalog_read)
          %{exists?: true}
        end
      )

    assert snapshot.oban.classification == :oban_binding_drift
    assert snapshot.oban.expected_prefix == "host_oban"
    assert snapshot.oban.observed_prefix == "public"
    refute_received :catalog_read
    refute_received :oban_catalog_read
  end

  for {name, binding} <- [
        {"missing", nil},
        {"false prefix", [repo: Rindle.Repo, prefix: false]},
        {"empty prefix", [repo: Rindle.Repo, prefix: ""]},
        {"unsafe prefix", [repo: Rindle.Repo, prefix: "public; DROP TABLE oban_jobs"]},
        {"alternate repo", [repo: OtherRepo]},
        {"named instance", [repo: Rindle.Repo, name: OtherOban]}
      ] do
    test "refuses #{name} Oban binding before catalog inspection" do
      parent = self()

      snapshot =
        OwnershipSnapshot.inspect(
          oban_binding: unquote(Macro.escape(binding)),
          compatibility_oban_prefix: "public",
          catalog_reader: fn _prefix ->
            send(parent, :catalog_read)
            complete_catalog()
          end,
          oban_jobs_catalog: fn _prefix ->
            send(parent, :oban_catalog_read)
            %{exists?: true}
          end
        )

      assert snapshot.oban.classification == :oban_binding_unavailable
      refute_received :catalog_read
      refute_received :oban_catalog_read
    end
  end

  test "does not infer a mismatch from partial, invalid-marker, or both-complete catalogs" do
    for catalogs <- [
          %{"public" => incomplete_catalog(), "rindle" => complete_catalog()},
          %{
            "public" => %{complete_catalog() | marker_versions: [2]},
            "rindle" => complete_catalog()
          },
          %{"public" => complete_catalog(), "rindle" => complete_catalog()}
        ] do
      snapshot =
        OwnershipSnapshot.inspect(
          expected_prefix: "public",
          catalogs: catalogs,
          oban_binding: valid_oban_binding(),
          compatibility_oban_prefix: "public",
          oban_jobs_catalog: %{exists?: true, prefix: "public"}
        )

      refute snapshot.rindle.classification == :rindle_prefix_mismatch
    end
  end

  test "bounds catalog failures without retaining adapter data" do
    snapshot =
      OwnershipSnapshot.inspect(
        oban_binding: valid_oban_binding(),
        compatibility_oban_prefix: "public",
        catalog_reader: fn _prefix -> raise "postgres://user:credential@host SQL sentinel" end,
        oban_jobs_catalog: %{exists?: true, prefix: "public"}
      )

    assert snapshot.rindle.classification == :inspection_failed
    refute inspect(snapshot) =~ "credential"
    refute inspect(snapshot) =~ "SQL sentinel"
  end

  defp complete_catalog do
    %{marker_versions: [1], relations: @relations}
  end

  defp incomplete_catalog do
    %{marker_versions: [], relations: @relations -- ["media_variants"]}
  end

  defp empty_catalog, do: %{marker_versions: [], relations: []}

  defp healthy_catalogs(prefix) do
    other_prefix = if prefix == "public", do: "rindle", else: "public"
    %{prefix => complete_catalog(), other_prefix => incomplete_catalog()}
  end

  defp valid_oban_binding(overrides \\ []) do
    Keyword.merge([repo: Rindle.Repo], overrides)
  end

  defmodule OtherRepo do
  end

  defmodule OtherOban do
  end
end
