defmodule Rindle.Processor.AV.RuntimeGuardTest do
  use ExUnit.Case, async: true

  alias Rindle.Processor.AV.RuntimeGuard

  describe "check!/2" do
    test "refuses video work on unsupported ephemeral runtimes" do
      assert {:error, {:unsupported_ephemeral_runtime, :lambda}} =
               RuntimeGuard.check!(
                 %{kind: :video, max_output_bytes: 100},
                 env: %{"LAMBDA_TASK_ROOT" => "/tmp/lambda"}
               )
    end

    test "allows non-video work on ephemeral runtimes" do
      assert :ok =
               RuntimeGuard.check!(%{kind: :image}, env: %{"VERCEL" => "1"})
    end

    test "refuses AV work when free disk is below twice max output bytes" do
      assert {:error, {:insufficient_disk_headroom, %{free_bytes: 199, required_bytes: 200}}} =
               RuntimeGuard.check!(
                 %{kind: :audio, max_output_bytes: 100},
                 env: %{},
                 disk_free_bytes: 199
               )
    end

    test "permits AV work when free disk meets the hard floor" do
      assert :ok =
               RuntimeGuard.check!(
                 %{kind: :video, max_output_bytes: 100},
                 env: %{},
                 disk_free_bytes: 200
               )
    end
  end

  describe "warn_unsupported_runtime/2" do
    test "warns exactly when AV-capable profiles are configured on unsupported ephemeral hosts" do
      parent = self()

      av_profiles = [
        %{name: "VideoProfile", variants: [%{kind: :video}, %{kind: :image}]},
        %{name: "AudioProfile", variants: [%{kind: :audio}]}
      ]

      assert :ok =
               RuntimeGuard.warn_unsupported_runtime(av_profiles,
                 env: %{"VERCEL" => "1"},
                 logger: fn level, message, metadata ->
                   send(parent, {:log, level, message, metadata})
                 end
               )

      assert_received {:log, :warning, "rindle.av.runtime_guard.unsupported_runtime", metadata}
      assert metadata.runtime == :vercel
      assert metadata.affected_profiles == ["AudioProfile", "VideoProfile"]
    end

    test "does not warn when only image profiles are configured" do
      parent = self()

      assert :ok =
               RuntimeGuard.warn_unsupported_runtime(
                 [%{name: "ImageOnly", variants: [%{kind: :image}]}],
                 env: %{"LAMBDA_TASK_ROOT" => "/tmp/lambda"},
                 logger: fn level, message, metadata ->
                   send(parent, {:log, level, message, metadata})
                 end
               )

      refute_received {:log, _, _, _}
    end
  end
end
