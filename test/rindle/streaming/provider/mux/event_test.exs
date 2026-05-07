defmodule Rindle.Streaming.Provider.Mux.EventTest do
  use ExUnit.Case, async: true

  alias Rindle.Streaming.Provider.Mux.Event

  # Existing :ready / :errored / :created (BL-03) regression coverage lives
  # in `test/rindle/streaming/provider/mux/mux_test.exs` (the
  # `verify_webhook/3` end-to-end paths exercise normalize/1 transitively).
  # This file owns the D-29 typed-branch contract: `video.upload.asset_created`
  # must read `data.asset_id` for `provider_asset_id` and `data.id` for
  # `upload_id` — not the other way around (silent data corruption).

  describe "normalize/1 — video.upload.asset_created (D-29 typed branch)" do
    test "reads data.asset_id for provider_asset_id, NOT data.id" do
      upload_id = "upload-id-fixture-aaaa1111"
      asset_id = "asset-id-fixture-bbbb2222"

      raw = %{
        "type" => "video.upload.asset_created",
        "id" => "evt-fixture-upload-asset-created-0001",
        "data" => %{
          "id" => upload_id,
          "asset_id" => asset_id
        },
        "created_at" => "2026-05-06T00:00:00.000Z"
      }

      assert {:ok, evt} = Event.normalize(raw)
      assert evt.type == :upload_asset_created
      assert evt.provider_asset_id == asset_id, "MUST be data.asset_id (D-29)"
      assert evt.upload_id == upload_id, "MUST be data.id (D-29)"

      refute evt.provider_asset_id == upload_id,
             "MUST NOT mis-attribute upload-id to provider_asset_id (silent corruption)"

      assert evt.playback_ids == []
      assert evt.state == nil
      assert evt.raw == raw
      assert %DateTime{} = evt.occurred_at
    end

    test "reads fixture file end-to-end" do
      path =
        Path.join([
          File.cwd!(),
          "test",
          "fixtures",
          "mux",
          "webhook_video_upload_asset_created.json"
        ])

      raw = path |> File.read!() |> Jason.decode!()

      assert {:ok, evt} = Event.normalize(raw)
      assert evt.type == :upload_asset_created
      # `provider_asset_id` and `upload_id` are realistic 36-char Mux-style
      # ids in the fixture (Plan 03 — D-36); they MUST be distinct.
      assert is_binary(evt.provider_asset_id)
      assert is_binary(evt.upload_id)
      refute evt.provider_asset_id == evt.upload_id
      assert evt.provider_asset_id == raw["data"]["asset_id"]
      assert evt.upload_id == raw["data"]["id"]
    end

    test "typed branch wins over generic clause when both could match" do
      # If pattern-match ordering were reversed, the generic clause would match
      # first and assign `data.id` (the upload-id) to `provider_asset_id`. This
      # test documents the dispatch contract: the typed branch is positioned
      # BEFORE the generic clause and therefore takes precedence.
      raw = %{
        "type" => "video.upload.asset_created",
        "data" => %{
          "id" => "should-not-leak-into-provider_asset_id",
          "asset_id" => "must-be-the-asset-id"
        }
      }

      assert {:ok, %{provider_asset_id: "must-be-the-asset-id", upload_id: "should-not-leak-into-provider_asset_id"}} =
               Event.normalize(raw)
    end
  end

  describe "normalize/1 — generic clause (regression for non-upload events)" do
    test "video.asset.ready still maps data.id to provider_asset_id" do
      raw = %{
        "type" => "video.asset.ready",
        "data" => %{
          "id" => "asset-ready-id",
          "status" => "ready",
          "playback_ids" => [%{"id" => "pb-1", "policy" => "signed"}]
        }
      }

      assert {:ok, evt} = Event.normalize(raw)
      assert evt.type == :ready
      assert evt.provider_asset_id == "asset-ready-id"
      assert evt.playback_ids == ["pb-1"]
      assert evt.state == "ready"
      refute Map.has_key?(evt, :upload_id) and Map.get(evt, :upload_id) != nil
    end

    test "video.asset.deleted still maps data.id to provider_asset_id" do
      raw = %{
        "type" => "video.asset.deleted",
        "data" => %{"id" => "asset-deleted-id", "status" => "deleted"}
      }

      assert {:ok, evt} = Event.normalize(raw)
      assert evt.type == :deleted
      assert evt.provider_asset_id == "asset-deleted-id"
    end
  end

  describe "normalize/1 — invalid payloads" do
    test "missing type or data returns {:error, :provider_webhook_invalid}" do
      assert {:error, :provider_webhook_invalid} = Event.normalize(%{})
      assert {:error, :provider_webhook_invalid} = Event.normalize(%{"type" => "x"})
      assert {:error, :provider_webhook_invalid} = Event.normalize("not a map")
    end
  end
end
