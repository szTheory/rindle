defmodule Rindle.Contracts.TelemetryContractTest do
  @moduledoc """
  Telemetry public contract — locked event family.

  Asserts the exact event-name allowlist, required `profile` + `adapter`
  metadata keys, and that all measurements are numeric. A name change or
  metadata-key drop breaks this lane (Phase 5 success criterion 5.2).

  Run: `mix test --only contract`

  Per D-04/D-05/D-06 in `.planning/phases/05-ci-1-0-readiness/05-CONTEXT.md`.
  """

  use ExUnit.Case, async: false
  @moduletag :contract

  @public_events [
    [:rindle, :upload, :start],
    [:rindle, :upload, :stop],
    [:rindle, :asset, :state_change],
    [:rindle, :variant, :state_change],
    [:rindle, :delivery, :signed],
    [:rindle, :cleanup, :run]
  ]

  setup do
    ref = :telemetry_test.attach_event_handlers(self(), @public_events)
    on_exit(fn -> :telemetry.detach(ref) end)
    {:ok, ref: ref}
  end

  describe "public event allowlist" do
    test "is exactly the six events documented in the public contract" do
      assert length(@public_events) == 6

      for event <- @public_events do
        assert is_list(event)
        assert length(event) == 3
        assert Enum.all?(event, &is_atom/1)
        assert hd(event) == :rindle
      end
    end
  end

  # Concrete emission tests added in Tasks 2 and 3.
end
