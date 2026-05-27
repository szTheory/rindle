defmodule Rindle.Domain.ProviderAssetFSMTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Rindle.Domain.ProviderAssetFSM

  describe "transition matrix — nominal happy path (D-13)" do
    test "pending → uploading → processing → ready" do
      assert :ok == ProviderAssetFSM.transition("pending", "uploading")
      assert :ok == ProviderAssetFSM.transition("uploading", "processing")
      assert :ok == ProviderAssetFSM.transition("processing", "ready")
    end
  end

  describe "transition matrix — errored branches (D-13)" do
    test "pending → errored is allowed (create_asset failure before upload)" do
      assert :ok == ProviderAssetFSM.transition("pending", "errored")
    end

    test "uploading → errored is allowed" do
      assert :ok == ProviderAssetFSM.transition("uploading", "errored")
    end

    test "processing → errored is allowed" do
      assert :ok == ProviderAssetFSM.transition("processing", "errored")
    end

    test "ready → errored is allowed" do
      assert :ok == ProviderAssetFSM.transition("ready", "errored")
    end
  end

  describe "transition matrix — terminal-delete (D-13)" do
    test "ready → deleted is allowed" do
      assert :ok == ProviderAssetFSM.transition("ready", "deleted")
    end

    test "errored → deleted is allowed" do
      assert :ok == ProviderAssetFSM.transition("errored", "deleted")
    end

    test "deleted is terminal — rejects every other state" do
      for target <- ~w(pending uploading processing ready errored) do
        assert {:error, {:invalid_transition, "deleted", ^target}} =
                 ProviderAssetFSM.transition("deleted", target)
      end
    end
  end

  describe "transition matrix — direct-upload cancel (Phase 64)" do
    test "pending → deleted is allowed" do
      assert :ok == ProviderAssetFSM.transition("pending", "deleted")
    end

    test "uploading → deleted is allowed" do
      assert :ok == ProviderAssetFSM.transition("uploading", "deleted")
    end

    test "processing → deleted is rejected" do
      assert {:error, {:invalid_transition, "processing", "deleted"}} =
               ProviderAssetFSM.transition("processing", "deleted")
    end
  end

  describe "transition matrix — re-ingest re-entry edge (D-13 critical)" do
    test "errored → processing is allowed (Phase 34 MuxIngestVariant retry path)" do
      assert :ok == ProviderAssetFSM.transition("errored", "processing")
    end
  end

  describe "transition matrix — rejection coverage (D-13)" do
    test "pending → ready (skips intermediate states) is rejected" do
      assert {:error, {:invalid_transition, "pending", "ready"}} =
               ProviderAssetFSM.transition("pending", "ready")
    end

    test "pending → processing (skips uploading) is rejected" do
      assert {:error, {:invalid_transition, "pending", "processing"}} =
               ProviderAssetFSM.transition("pending", "processing")
    end

    test "ready → uploading (no backward to in-flight) is rejected" do
      assert {:error, {:invalid_transition, "ready", "uploading"}} =
               ProviderAssetFSM.transition("ready", "uploading")
    end

    test "ready → pending (no backward) is rejected" do
      assert {:error, {:invalid_transition, "ready", "pending"}} =
               ProviderAssetFSM.transition("ready", "pending")
    end

    test "processing → uploading (no backward) is rejected" do
      assert {:error, {:invalid_transition, "processing", "uploading"}} =
               ProviderAssetFSM.transition("processing", "uploading")
    end

    test "uploading → ready (skips processing) is rejected" do
      assert {:error, {:invalid_transition, "uploading", "ready"}} =
               ProviderAssetFSM.transition("uploading", "ready")
    end

    test "unknown source state returns invalid_transition" do
      assert {:error, {:invalid_transition, "garbage", "ready"}} =
               ProviderAssetFSM.transition("garbage", "ready")
    end
  end

  describe "telemetry on accepted transitions (D-12)" do
    setup do
      handler = String.to_atom("provider_asset_fsm_test_#{:erlang.unique_integer([:positive])}")
      parent = self()

      :telemetry.attach(
        handler,
        [:rindle, :provider_asset, :state_change],
        fn event, measurements, metadata, _config ->
          send(parent, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler) end)
      :ok
    end

    test "fires [:rindle, :provider_asset, :state_change] with metadata on success" do
      assert :ok ==
               ProviderAssetFSM.transition("pending", "uploading", %{
                 profile: Rindle.TestProfile,
                 provider: :mux,
                 asset_id: "asset-uuid-123"
               })

      assert_received {:telemetry, [:rindle, :provider_asset, :state_change], measurements,
                       metadata}

      assert is_integer(measurements.system_time)
      assert metadata.profile == Rindle.TestProfile
      assert metadata.provider == :mux
      assert metadata.asset_id == "asset-uuid-123"
      assert metadata.from == "pending"
      assert metadata.to == "uploading"
    end

    test "metadata defaults to :unknown when context omits keys" do
      assert :ok == ProviderAssetFSM.transition("pending", "uploading")

      assert_received {:telemetry, [:rindle, :provider_asset, :state_change], _meas, metadata}

      assert metadata.profile == :unknown
      assert metadata.provider == :unknown
      assert metadata.from == "pending"
      assert metadata.to == "uploading"
    end

    test "does NOT fire telemetry on rejected transitions" do
      assert {:error, {:invalid_transition, _, _}} =
               ProviderAssetFSM.transition("pending", "ready")

      refute_received {:telemetry, [:rindle, :provider_asset, :state_change], _, _}
    end
  end

  describe "logger on rejected transitions" do
    test "writes Logger.warning with rindle.provider_asset.transition_failed key" do
      log =
        capture_log(fn ->
          assert {:error, {:invalid_transition, "pending", "ready"}} =
                   ProviderAssetFSM.transition("pending", "ready", %{
                     asset_id: "asset-99",
                     provider: :mux
                   })
        end)

      assert log =~ "rindle.provider_asset.transition_failed"
    end
  end

  describe "introspection" do
    test "allowed_transitions/0 returns the locked D-13 map" do
      transitions = ProviderAssetFSM.allowed_transitions()

      assert transitions["pending"] == ["uploading", "errored", "deleted"]
      assert transitions["uploading"] == ["processing", "errored", "deleted"]
      assert transitions["processing"] == ["ready", "errored"]
      assert transitions["ready"] == ["errored", "deleted"]
      assert transitions["errored"] == ["deleted", "processing"]
      assert transitions["deleted"] == []
    end
  end
end
