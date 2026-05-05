defmodule Rindle.Domain.MigrationTest do
  use Rindle.DataCase, async: false

  alias Rindle.Repo

  describe "extend_media_for_av migration (Phase 24)" do
    test "media_assets has the new AV columns" do
      {:ok, %{rows: rows}} =
        Repo.query("""
        SELECT column_name FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'media_assets'
        """)

      column_names = Enum.map(rows, fn [name] -> name end) |> MapSet.new()

      for required <- ~w(kind width height duration_ms has_video_track has_audio_track error_reason) do
        assert required in column_names,
               "missing column #{required} on media_assets after Phase 24 migration"
      end
    end

    test "media_variants has the new AV columns" do
      {:ok, %{rows: rows}} =
        Repo.query("""
        SELECT column_name FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'media_variants'
        """)

      column_names = Enum.map(rows, fn [name] -> name end) |> MapSet.new()

      for required <- ~w(output_kind duration_ms width height) do
        assert required in column_names,
               "missing column #{required} on media_variants after Phase 24 migration"
      end
    end

    test "media_assets.kind defaults to 'image' for new rows" do
      {:ok, %{rows: [[default]]}} =
        Repo.query("""
        SELECT column_default FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'media_assets'
          AND column_name = 'kind'
        """)

      assert default =~ "image"
    end

    test "media_variants.output_kind defaults to 'image' for new rows" do
      {:ok, %{rows: [[default]]}} =
        Repo.query("""
        SELECT column_default FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'media_variants'
          AND column_name = 'output_kind'
        """)

      assert default =~ "image"
    end

    test "media_assets has an index on (kind)" do
      {:ok, %{rows: rows}} =
        Repo.query("""
        SELECT indexname FROM pg_indexes
        WHERE schemaname = 'public' AND tablename = 'media_assets'
        """)

      indexes = Enum.map(rows, fn [name] -> name end)
      assert Enum.any?(indexes, &String.contains?(&1, "kind"))
    end
  end
end
