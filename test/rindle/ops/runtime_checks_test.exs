defmodule Rindle.Ops.RuntimeChecksTest do
  use ExUnit.Case, async: true

  alias Rindle.Ops.RuntimeChecks
  alias Rindle.Storage.Local

  defmodule ImageProfile do
    use Rindle.Profile,
      storage: Rindle.Storage.S3,
      variants: [thumb: [mode: :fit, width: 64, height: 64]]
  end

  defmodule VideoProfile do
    use Rindle.Profile.Presets.Web,
      storage: Rindle.Storage.S3,
      allow_mime: ["video/mp4"],
      max_bytes: 10_000_000
  end

  defmodule PrivateLocalImageProfile do
    use Rindle.Profile,
      storage: Local,
      variants: [thumb: [mode: :fit, width: 64, height: 64]]
  end

  defmodule PublicLocalVideoProfile do
    use Rindle.Profile,
      storage: Local,
      delivery: [public: true],
      variants: [web: [kind: :video, preset: :web_720p]]
  end

  describe "run/2" do
    test "returns deterministic stable check ids" do
      report =
        RuntimeChecks.run([],
          probe: fn -> :ok end,
          env: %{},
          profiles: [ImageProfile, VideoProfile],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1,
              rindle_media: 1
            ]
          ],
          migration_statuses: [],
          local_playback_route: [base_url: "http://example.test/rindle/local", secret_key_base: "secret"]
        )

      assert Enum.map(report.checks, & &1.id) == [
               "doctor.delivery_support",
               "doctor.ffmpeg_runtime",
               "doctor.local_playback",
               "doctor.migrations.pending",
               "doctor.migrations.unresolved",
               "doctor.oban_default_instance",
               "doctor.oban_required_queues",
               "doctor.profile_runtime_fit"
             ]

      assert report.success?
      assert report.failed == 0
    end

    test "does not require rindle_media for image-only profiles" do
      report =
        RuntimeChecks.run([],
          probe: fn -> :ok end,
          env: %{},
          profiles: [ImageProfile],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1
            ]
          ],
          migration_statuses: []
        )

      assert report.success?

      queues_check = fetch_check(report, "doctor.oban_required_queues")
      assert queues_check.status == :ok
      refute queues_check.summary =~ "rindle_media"
    end

    test "requires rindle_media when AV-capable profiles are present" do
      report =
        RuntimeChecks.run([],
          probe: fn -> :ok end,
          env: %{},
          profiles: [VideoProfile],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1
            ]
          ],
          migration_statuses: []
        )

      refute report.success?

      queues_check = fetch_check(report, "doctor.oban_required_queues")
      assert queues_check.status == :error
      assert queues_check.summary =~ "rindle_media"
      assert queues_check.fix =~ "config"
    end

    test "flags private delivery on adapters without signed_url support" do
      report =
        RuntimeChecks.run([],
          probe: fn -> :ok end,
          env: %{},
          profiles: [PrivateLocalImageProfile],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1
            ]
          ],
          migration_statuses: []
        )

      check = fetch_check(report, "doctor.delivery_support")
      assert check.status == :error
      assert check.summary =~ "PrivateLocalImageProfile"
      assert check.fix =~ "signed_url"
    end

    test "flags local playback route drift only for local AV profiles" do
      report =
        RuntimeChecks.run([],
          probe: fn -> :ok end,
          env: %{},
          profiles: [PublicLocalVideoProfile],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1,
              rindle_media: 1
            ]
          ],
          migration_statuses: [],
          local_playback_route: nil
        )

      check = fetch_check(report, "doctor.local_playback")
      assert check.status == :error
      assert check.summary =~ "PublicLocalVideoProfile"
      assert check.fix =~ "local_playback_route"
      assert check.fix =~ "Rindle.Delivery.LocalPlug"
    end

    test "distinguishes pending and unresolved migration drift" do
      report =
        RuntimeChecks.run([],
          probe: fn -> :ok end,
          env: %{},
          profiles: [],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1
            ]
          ],
          migration_statuses: [
            {:down, 20_260_502_120_000, "extend_media_for_av.exs"},
            {:up, 20_260_425_090_000, "** FILE NOT FOUND **"}
          ]
        )

      pending = fetch_check(report, "doctor.migrations.pending")
      unresolved = fetch_check(report, "doctor.migrations.unresolved")

      assert pending.status == :error
      assert pending.summary =~ "20260502120000"
      assert pending.fix =~ "mix ecto.migrate"

      assert unresolved.status == :error
      assert unresolved.summary =~ "20260425090000"
      assert unresolved.fix =~ "missing from local code"
    end
  end

  defp fetch_check(report, id) do
    Enum.find(report.checks, &(&1.id == id)) ||
      flunk("expected check #{inspect(id)} to be present")
  end
end
