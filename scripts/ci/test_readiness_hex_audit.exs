Code.require_file("../maintainer/readiness_hex_audit.exs", __DIR__)

defmodule ReadinessHexAuditTest do
  use ExUnit.Case, async: false
  alias Rindle.ReadinessHexAudit, as: Audit

  setup do
    root =
      Path.join(
        System.fetch_env!("RINDLE_READINESS_TEST_ROOT"),
        "hex-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, root: root}
  end

  defp objects do
    [
      {:version, 5},
      {{:versions, "hexpm", "sample"}, ["1.0.0"]},
      {{:outer_checksum, "hexpm", "sample", "1.0.0"}, <<0::256>>},
      {{:advisories, "hexpm", "sample", "1.0.0"}, []},
      {:last_update, ~U[2026-10-25 00:00:00Z]},
      {{:timestamp, "hexpm", "sample", "1.0.0"}, ~U[2026-10-25 00:00:00Z]}
    ]
  end

  defp legacy(root, objects) do
    table = :ets.new(:readiness_cache_test, [])
    :ets.insert(table, objects)

    :ok =
      :ets.tab2file(table, String.to_charlist(Path.join(root, "cache.ets")),
        extended_info: [:object_count, :md5sum]
      )

    :ets.delete(table)
  end

  defp current(root, objects) do
    # Real reviewed Hex writer/reader, including its header and CRC check.
    assert Code.ensure_loaded?(Hex.Registry.Server)
    table = :ets.new(:readiness_cache_test, [])
    :ets.insert(table, objects)
    :ok = Hex.Registry.Server.write_cache(table, Path.join(root, "cache.bin"))
    :ets.delete(table)
  end

  test "verified old and CRC new persistence produce the same normalized snapshot", %{root: root} do
    legacy(root, objects())
    old = Audit.cache_snapshot(root, "2.5.1")
    current(root, objects())
    File.rm!(Path.join(root, "cache.ets"))
    assert Audit.cache_snapshot(root, "2.6.0") == old
    assert length(old) == 4
    assert Enum.any?(old, &(&1["key"] == ["outer_checksum", "hexpm", "sample", "1.0.0"]))
    assert old == Enum.sort_by(old, & &1["key"])
  end

  test "timestamps cannot change snapshot identity", %{root: root} do
    current(root, objects())
    first = Audit.cache_snapshot(root, "2.6.0")

    current(
      root,
      Enum.reverse(
        Enum.map(objects(), fn {key, value} ->
          {key,
           if(key == :last_update or (is_tuple(key) and elem(key, 0) == :timestamp),
             do: :changed,
             else: value
           )}
        end)
      )
    )

    assert Audit.cache_snapshot(root, "2.6.0") == first
  end

  test "missing and corrupt caches fail instead of becoming an empty database", %{root: root} do
    for {version, name} <- [{"2.5.1", "cache.ets"}, {"2.6.0", "cache.bin"}] do
      assert_raise MatchError, fn -> Audit.cache_snapshot(root, version) end
      File.write!(Path.join(root, name), "broken")
      assert_raise MatchError, fn -> Audit.cache_snapshot(root, version) end
      File.rm!(Path.join(root, name))
    end
  end

  test "CRC mismatch, truncated data and valid-CRC invalid terms fail closed", %{root: root} do
    path = Path.join(root, "cache.bin")

    for bytes <- [
          "HEX REGISTRY CACHE 1" <> <<0::32>> <> "invalid",
          "HEX REGISTRY CACHE 1" <> <<1>>,
          crc("invalid"),
          crc(:erlang.term_to_binary(:not_objects))
        ] do
      File.write!(path, bytes)
      assert_raise MatchError, fn -> Audit.cache_snapshot(root, "2.6.0") end
    end
  end

  defp crc(data), do: "HEX REGISTRY CACHE 1" <> <<:erlang.crc32(data)::32>> <> data

  test "new version never falls back to a stale legacy file", %{root: root} do
    legacy(root, objects())
    assert_raise MatchError, fn -> Audit.cache_snapshot(root, "2.6.0") end
  end

  test "changed registry data changes identity and failed projections release tables", %{
    root: root
  } do
    current(root, objects())
    first = Audit.cache_snapshot(root, "2.6.0")
    current(root, [{:version, 6} | tl(objects())])
    refute Audit.cache_snapshot(root, "2.6.0") == first
    current(root, [{:bad, :shape, :record}])
    before_tables = MapSet.new(:ets.all())
    assert_raise FunctionClauseError, fn -> Audit.cache_snapshot(root, "2.6.0") end
    assert MapSet.new(:ets.all()) == before_tables
  end

  test "unsupported versions fail even with valid files", %{root: root} do
    legacy(root, objects())
    current(root, objects())

    for version <- ["2.5.0", "2.6.1", "2.6.0-dev", "3.0.0", nil] do
      assert_raise ArgumentError, fn -> Audit.cache_snapshot(root, version) end
    end
  end
end
