defmodule Rindle.Telemetry.EmissionTest do
  @moduledoc """
  FSM-level telemetry emission tests for AssetFSM and VariantFSM.

  Broker, delivery, and worker telemetry coverage lives alongside their
  existing unit-test files (per Plan 05-01 Step 4 — keep cross-cutting
  emission proofs here, but do not re-stub broker/delivery/worker tests).
  """

  use ExUnit.Case, async: false

  alias Rindle.Domain.AssetFSM
  alias Rindle.Domain.VariantFSM

  @asset_event [:rindle, :asset, :state_change]
  @variant_event [:rindle, :variant, :state_change]

  setup do
    ref =
      :telemetry_test.attach_event_handlers(self(), [
        @asset_event,
        @variant_event
      ])

    on_exit(fn -> :telemetry.detach(ref) end)
    {:ok, ref: ref}
  end

  describe "AssetFSM.transition/3" do
    test "emits state_change with required metadata on valid transition", %{ref: ref} do
      assert :ok =
               AssetFSM.transition("staged", "validating", %{
                 profile: "MyProfile",
                 adapter: __MODULE__
               })

      assert_received {@asset_event, ^ref, measurements, metadata}
      assert is_integer(measurements.system_time)
      assert metadata.profile == "MyProfile"
      assert metadata.adapter == __MODULE__
      assert metadata.from == "staged"
      assert metadata.to == "validating"
    end

    test "uses :unknown fallback when profile/adapter absent from context", %{ref: ref} do
      assert :ok = AssetFSM.transition("staged", "validating", %{})

      assert_received {@asset_event, ^ref, _measurements, metadata}
      assert metadata.profile == :unknown
      assert metadata.adapter == :unknown
    end

    test "does NOT emit on invalid transition", %{ref: ref} do
      assert {:error, {:invalid_transition, "staged", "ready"}} =
               AssetFSM.transition("staged", "ready", %{})

      refute_received {@asset_event, ^ref, _measurements, _metadata}
    end
  end

  describe "VariantFSM.transition/3" do
    test "emits state_change on valid transition", %{ref: ref} do
      assert :ok =
               VariantFSM.transition("planned", "queued", %{
                 profile: "MyProfile",
                 adapter: __MODULE__
               })

      assert_received {@variant_event, ^ref, measurements, metadata}
      assert is_integer(measurements.system_time)
      assert metadata.profile == "MyProfile"
      assert metadata.adapter == __MODULE__
      assert metadata.from == "planned"
      assert metadata.to == "queued"
    end

    test "uses :unknown fallback when profile/adapter absent from context", %{ref: ref} do
      assert :ok = VariantFSM.transition("planned", "queued", %{})

      assert_received {@variant_event, ^ref, _measurements, metadata}
      assert metadata.profile == :unknown
      assert metadata.adapter == :unknown
    end

    test "does NOT emit on invalid transition", %{ref: ref} do
      assert {:error, _} = VariantFSM.transition("planned", "ready", %{})
      refute_received {@variant_event, ^ref, _, _}
    end
  end
end
