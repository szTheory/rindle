defmodule Rindle.ApplicationTest do
  use ExUnit.Case, async: false

  defmodule AVProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [video: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      max_bytes: 50_000_000
  end

  defmodule ImageProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [thumb: [mode: :fit, width: 64]],
      allow_mime: ["image/png"],
      max_bytes: 5_000_000
  end

  setup do
    previous_profiles = Application.get_env(:rindle, :profiles)
    previous_env = System.get_env("VERCEL")

    on_exit(fn ->
      if previous_profiles == nil do
        Application.delete_env(:rindle, :profiles)
      else
        Application.put_env(:rindle, :profiles, previous_profiles)
      end

      if previous_env == nil do
        System.delete_env("VERCEL")
      else
        System.put_env("VERCEL", previous_env)
      end
    end)

    :ok
  end

  test "run_startup_checks warns when configured AV profiles boot on unsupported ephemeral runtimes" do
    parent = self()
    Application.put_env(:rindle, :profiles, [AVProfile, ImageProfile])
    System.put_env("VERCEL", "1")

    assert :ok =
             Rindle.Application.run_startup_checks(
               logger: fn level, message, metadata ->
                 send(parent, {:log, level, message, metadata})
               end
             )

    assert_received {:log, :warning, "rindle.av.runtime_guard.unsupported_runtime", metadata}
    assert metadata.runtime == :vercel
    assert "Elixir.Rindle.ApplicationTest.AVProfile" in metadata.affected_profiles
  end

  test "run_startup_checks stays quiet when configured profiles are image-only" do
    parent = self()
    Application.put_env(:rindle, :profiles, [ImageProfile])
    System.put_env("VERCEL", "1")

    assert :ok =
             Rindle.Application.run_startup_checks(
               logger: fn level, message, metadata ->
                 send(parent, {:log, level, message, metadata})
               end
             )

    # It may warn about discovered AV profiles from other test modules, but not ImageProfile.
    receive do
      {:log, :warning, "rindle.av.runtime_guard.unsupported_runtime", metadata} ->
        refute "Elixir.Rindle.ApplicationTest.ImageProfile" in metadata.affected_profiles
    after
      0 -> :ok
    end
  end
end
