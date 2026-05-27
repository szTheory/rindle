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

      for required <-
            ~w(kind width height duration_ms has_video_track has_audio_track error_reason) do
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

  describe "extend_media_upload_sessions_for_resumable migration (Phase 38)" do
    test "media_upload_sessions has the resumable columns" do
      {:ok, %{rows: rows}} =
        Repo.query("""
        SELECT column_name FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'media_upload_sessions'
        """)

      column_names = Enum.map(rows, fn [name] -> name end) |> MapSet.new()

      for required <- ~w(session_uri session_uri_expires_at last_known_offset region_hint) do
        assert required in column_names,
               "missing column #{required} on media_upload_sessions after Phase 38 migration"
      end
    end

    test "media_upload_sessions.last_known_offset is bigint not null with default 0" do
      {:ok, %{rows: [[data_type, is_nullable, default]]}} =
        Repo.query("""
        SELECT data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'media_upload_sessions'
          AND column_name = 'last_known_offset'
        """)

      assert data_type == "bigint"
      assert is_nullable == "NO"
      assert default =~ "0"
    end

    test "media_upload_sessions.session_uri uses text" do
      {:ok, %{rows: [[data_type]]}} =
        Repo.query("""
        SELECT data_type
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'media_upload_sessions'
          AND column_name = 'session_uri'
        """)

      assert data_type == "text"
    end

    test "media_upload_sessions has a resumable expiry partial index" do
      {:ok, %{rows: rows}} =
        Repo.query("""
        SELECT indexdef FROM pg_indexes
        WHERE schemaname = 'public' AND tablename = 'media_upload_sessions'
        """)

      index_defs = Enum.map(rows, fn [indexdef] -> indexdef end)

      assert Enum.any?(index_defs, fn indexdef ->
               String.contains?(indexdef, "session_uri_expires_at") and
                 (String.contains?(indexdef, "WHERE ((upload_strategy = 'resumable'::text))") or
                    String.contains?(indexdef, "WHERE (upload_strategy = 'resumable'::text)") or
                    String.contains?(
                      indexdef,
                      "WHERE ((upload_strategy)::text = 'resumable'::text)"
                    ))
             end)
    end
  end

  describe "add_provider_upload_id_to_media_provider_assets migration (Phase 64)" do
    test "media_provider_assets has provider_upload_id column" do
      {:ok, %{rows: rows}} =
        Repo.query("""
        SELECT column_name FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'media_provider_assets'
          AND column_name = 'provider_upload_id'
        """)

      assert length(rows) == 1
    end

    test "media_provider_assets has partial unique index on provider_upload_id" do
      {:ok, %{rows: rows}} =
        Repo.query("""
        SELECT indexdef FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'media_provider_assets'
          AND indexname = 'media_provider_assets_provider_name_provider_upload_id_index'
        """)

      assert length(rows) == 1
      [[indexdef]] = rows
      assert indexdef =~ "provider_upload_id IS NOT NULL"
    end
  end
end
