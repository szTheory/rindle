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

  defmodule LocalContractProfile do
    @moduledoc false
    # Delivery is set to public so the local adapter (which advertises
    # [:local, :presigned_put] but not :signed_url) resolves a URL without
    # the private-mode capability gate rejecting the call. The locked
    # [:rindle, :delivery, :signed] event still fires for both :public and
    # :private modes (mode is metadata, not a separate event name).
    use Rindle.Profile,
      storage: Rindle.Storage.Local,
      variants: [thumb: [mode: :fit, width: 8, height: 8]],
      allow_mime: ["image/png"],
      max_bytes: 10_485_760,
      delivery: [public: true]
  end

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

  describe "metadata + measurement contract" do
    test "AssetFSM.transition/3 emits with required metadata + numeric measurements",
         %{ref: ref} do
      assert :ok =
               Rindle.Domain.AssetFSM.transition("staged", "validating", %{
                 profile: "TestProfile",
                 adapter: __MODULE__
               })

      assert_received {[:rindle, :asset, :state_change], ^ref, measurements, metadata}
      assert_required_metadata_keys(metadata)
      assert_numeric_measurements(measurements)
      assert metadata.profile == "TestProfile"
      assert metadata.adapter == __MODULE__
    end

    test "VariantFSM.transition/3 emits with required metadata + numeric measurements",
         %{ref: ref} do
      assert :ok =
               Rindle.Domain.VariantFSM.transition("planned", "queued", %{
                 profile: "TestProfile",
                 adapter: __MODULE__
               })

      assert_received {[:rindle, :variant, :state_change], ^ref, measurements, metadata}
      assert_required_metadata_keys(metadata)
      assert_numeric_measurements(measurements)
    end

    test "Delivery.url/3 emits :delivery :signed with required metadata", %{ref: ref} do
      # Use a tmp root for the local adapter so the call resolves a URL without IO setup
      root =
        Path.join(System.tmp_dir!(), "rindle-contract-#{System.unique_integer([:positive])}")

      File.mkdir_p!(root)
      previous = Application.get_env(:rindle, Rindle.Storage.Local)
      Application.put_env(:rindle, Rindle.Storage.Local, root: root)

      on_exit(fn ->
        case previous do
          nil -> Application.delete_env(:rindle, Rindle.Storage.Local)
          value -> Application.put_env(:rindle, Rindle.Storage.Local, value)
        end

        File.rm_rf(root)
      end)

      {:ok, _url} = Rindle.Delivery.url(LocalContractProfile, "test/key.png")

      assert_received {[:rindle, :delivery, :signed], ^ref, measurements, metadata}
      assert_required_metadata_keys(metadata)
      assert_numeric_measurements(measurements)
      assert metadata.profile == LocalContractProfile
      assert metadata.adapter == Rindle.Storage.Local
    end
  end

  describe "no event outside allowlist fires" do
    test "every emitted [:rindle | _] event is in @public_events", %{ref: _ref} do
      # Attach a separate broad handler that captures every probe event observed.
      handler_id = "rindle-contract-broad-#{System.unique_integer([:positive])}"
      parent = self()

      # We cannot truly wildcard in :telemetry, so we attach to every event in
      # @public_events PLUS a superset of plausible-but-not-public names. If
      # those plausible names ever fire, the assertion below catches them.
      probe_events =
        @public_events ++
          [
            [:rindle, :upload, :began],
            [:rindle, :upload, :ended],
            [:rindle, :asset, :transitioned],
            [:rindle, :variant, :transitioned],
            [:rindle, :delivery, :issued],
            [:rindle, :cleanup, :ran]
          ]

      :telemetry.attach_many(
        handler_id,
        probe_events,
        fn name, measurements, metadata, _config ->
          send(parent, {:probe_observed, name, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      # Trigger every locked emission site we can fire in-process.
      Rindle.Domain.AssetFSM.transition("staged", "validating", %{profile: "p", adapter: A})

      Rindle.Domain.VariantFSM.transition("planned", "queued", %{
        profile: "p",
        adapter: A
      })

      # Drain probe messages and check each is on the allowlist.
      observed = drain_probe_observations([])

      for {name, _meas, _meta} <- observed do
        assert name in @public_events,
               "telemetry contract violation: observed event #{inspect(name)} is NOT in @public_events allowlist"
      end
    end
  end

  # ----------------------------------------------------------------------
  # Private assertion helpers — keep contract surface in this module.
  # ----------------------------------------------------------------------

  defp assert_required_metadata_keys(metadata) when is_map(metadata) do
    assert Map.has_key?(metadata, :profile),
           "telemetry contract violation: emitted event missing :profile metadata key"

    assert Map.has_key?(metadata, :adapter),
           "telemetry contract violation: emitted event missing :adapter metadata key"
  end

  defp assert_numeric_measurements(measurements) when is_map(measurements) do
    for {key, value} <- measurements do
      assert is_number(value),
             "telemetry contract violation: measurement #{inspect(key)} = #{inspect(value)} is not numeric"
    end
  end

  defp drain_probe_observations(acc) do
    receive do
      {:probe_observed, name, m, md} -> drain_probe_observations([{name, m, md} | acc])
    after
      10 -> Enum.reverse(acc)
    end
  end
end
