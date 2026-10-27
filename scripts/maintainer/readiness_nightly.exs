defmodule Rindle.ReadinessNightly do
  @moduledoc false
  # A finite verifier for this reviewed workflow, not a GitHub expression interpreter.
  # A changed workflow requires a deliberate verifier/control-registry review.
  @workflow "b2e02590c38da533180e40243b2bcd9840d914affcb09fdcbf7a77d796ee741b"
  @controls ~w(.github/workflows/nightly.yml .github/actions/setup-elixir/action.yml
    scripts/ci/eval_nightly_summary.sh scripts/ci/manage_nightly_incident.sh
    scripts/ci/run_nightly_dialyzer.sh scripts/ci/install_apt_packages.sh
    scripts/ci/install_ffmpeg.sh scripts/ci/ensure_phx_new.sh
    scripts/install_smoke.sh scripts/ci/adoption_demo_gcs_live.sh
    .github/actions/repository-credential/action.yml scripts/maintainer/repository_credential.py
    .github/workflows/release-please-automerge.yml .github/workflows/branch-protection-apply.yml)
  def control_paths, do: @controls
  defp sha(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
  defp check(true, _), do: :ok
  defp check(_, reason), do: throw({:invalid, reason, "Nightly liveness policy"})

  defp time(value) do
    {:ok, t, 0} = DateTime.from_iso8601(value)
    DateTime.to_unix(t)
  end

  def qualification!(n, yaml) do
    check(sha(yaml) == @workflow, "nightly_control_review_required")

    check(
      n["event"] in ["workflow_dispatch", "schedule"] and n["attempt"] == 1,
      "nightly_attempt_unsupported"
    )

    Enum.each(n["jobs"], fn job ->
      if job["conclusion"] != "skipped" do
        steps = job["steps"]
        check(is_list(steps) and steps != [], "nightly_steps_missing")
        names = Enum.map(steps, & &1["name"])
        check(length(names) == length(Enum.uniq(names)), "nightly_steps_duplicate")
        numbers = Enum.map(steps, & &1["number"])

        check(
          numbers == Enum.sort(Enum.uniq(numbers)) and
            Enum.all?(numbers, &(is_integer(&1) and &1 > 0)),
          "nightly_steps_order"
        )

        Enum.each(steps, fn s ->
          check(
            s["status"] == "completed" and s["conclusion"] in ["success", "skipped", "failure"],
            "nightly_step_outcome"
          )

          # Only the explicitly advisory canary may fail; unknown failed steps fail closed.
          check(
            s["conclusion"] != "failure" or
              s["name"] == "Subprocess :epipe cleanup canary (advisory)",
            "nightly_step_outcome"
          )
        end)

        validate_steps!(job["name"], steps)
      end
    end)
  end

  defp require_steps!(steps, names, outcome \\ "success") do
    Enum.each(names, fn name ->
      check(
        Enum.count(steps, &(&1["name"] == name and &1["conclusion"] == outcome)) == 1,
        "nightly_required_step"
      )
    end)

    positions = Enum.map(names, fn name -> Enum.find_index(steps, &(&1["name"] == name)) end)
    check(positions == Enum.sort(positions), "nightly_steps_order")
  end

  defp validate_steps!("Compat Matrix" <> _, steps) do
    require_steps!(steps, [
      "Checkout",
      "Set up Elixir",
      "Install libvips",
      "Install FFmpeg",
      "Install dependencies",
      "Compile (warnings as errors)",
      "Run tests with coverage",
      "Publish Nightly evidence"
    ])
  end

  defp validate_steps!("Dialyzer", steps) do
    require_steps!(steps, [
      "Checkout",
      "Set up Elixir",
      "Install libvips",
      "Install dependencies",
      "Dialyzer (fresh PLT)",
      "Save PLT cache",
      "Remove fresh PLT before restore proof",
      "Restore exact PLT cache",
      "Dialyzer (restored PLT)",
      "Publish Nightly evidence"
    ])

    require_steps!(steps, ["Require exact PLT restore"], "skipped")
  end

  defp validate_steps!("Nightly Summary", steps),
    do:
      require_steps!(steps, [
        "Checkout",
        "Evaluate strict Nightly verdict",
        "Enforce strict Nightly verdict"
      ])

  defp validate_steps!(name, steps)
       when name in ["GCS Soak (real bucket)", "Package Consumer GCS Live Proof"] do
    require_steps!(steps, [
      "Checkout",
      "Determine live GCS applicability",
      "Publish Nightly evidence"
    ])

    skip =
      if name == "GCS Soak (real bucket)",
        do: "Skip live GCS soak when secrets are unavailable",
        else: "Skip live package-consumer GCS proof when secrets are unavailable"

    live =
      if name == "GCS Soak (real bucket)",
        do: [
          "Set up Elixir",
          "Install libvips",
          "Install dependencies",
          "Run GCS integration tests"
        ],
        else: [
          "Set up Elixir",
          "Install libvips",
          "Install dependencies",
          "Authenticate for live GCS proof cleanup",
          "Set up gcloud for live GCS cleanup",
          "Run live package-consumer GCS resumable proof without logging raw session_uri values",
          "Adoption demo GCS live companion (documented lane; install_smoke is canonical)",
          "Always clean up live package-consumer GCS objects for this prefix"
        ]

    branch = Enum.find(steps, &(&1["name"] == skip))

    check(
      is_map(branch) and branch["conclusion"] in ["success", "skipped"],
      "nightly_applicability"
    )

    require_steps!(
      steps,
      live,
      if(branch["conclusion"] == "success", do: "skipped", else: "success")
    )
  end

  defp validate_steps!("Persist Nightly Incident Verdict", steps),
    do:
      require_steps!(steps, [
        "Write immutable Nightly verdict event",
        "Upload immutable Nightly verdict event"
      ])

  defp validate_steps!("Nightly Incident Lifecycle", steps),
    do:
      require_steps!(steps, [
        "Checkout",
        "Resolve current remote default-branch SHA",
        "Manage scheduled Nightly incident",
        "Upload authenticated Nightly replay checkpoint"
      ])

  defp validate_steps!(_, _), do: check(false, "nightly_unknown_job")

  # jq -cS JSON is the existing checkpoint's canonicalization (including newline).
  defp sorted_json(v) when is_map(v),
    do:
      "{" <>
        (v
         |> Enum.sort()
         |> Enum.map_join(",", fn {k, x} -> Jason.encode!(k) <> ":" <> sorted_json(x) end)) <> "}"

  defp sorted_json(v) when is_list(v), do: "[" <> Enum.map_join(v, ",", &sorted_json/1) <> "]"
  defp sorted_json(v), do: Jason.encode!(v)
  defp jq_digest(v), do: sha(sorted_json(v) <> "\n")

  def health!(n, inputs) do
    run = n["health_run"]

    check(
      is_map(run) and run["repository"] == n["repository"] and
        is_binary(run["subject_sha"]) and Regex.match?(~r/\A[0-9a-f]{40}\z/, run["subject_sha"]) and
        run["event"] == "schedule" and run["attempt"] == 1,
      "scheduled_health_identity"
    )

    check(
      n["control_identity"] == Map.new(@controls, &{&1, sha(Map.fetch!(inputs, &1))}),
      "scheduled_health_control_mismatch"
    )

    check(
      n["health_control_identity"] == n["control_identity"],
      "scheduled_health_control_mismatch"
    )

    observed = time(n["observed_at"])
    # Cover the previous daily slot until today's finite creation grace elapses.
    {:ok, date, _} = DateTime.from_iso8601(n["observed_at"])
    slot = DateTime.new!(DateTime.to_date(date), ~T[07:27:00], "Etc/UTC") |> DateTime.to_unix()
    required_slot = if observed >= slot + 3600, do: slot, else: slot - 86_400
    created = time(run["created_at"])
    check(created >= required_slot and created <= observed, "scheduled_health_stale")

    check(
      time(run["completed_at"]) >= created and time(run["completed_at"]) <= created + 7200 and
        time(run["completed_at"]) <= observed,
      "scheduled_health_stalled"
    )

    Enum.each(
      [run["incident_artifact_expires_at"], n["checkpoint_artifact_expires_at"]],
      fn expiry ->
        check(time(expiry) >= observed + 3600, "incident_artifact_expiring")
      end
    )

    checkpoint = n["checkpoint"]

    check(
      checkpoint["schema"] == "rindle-nightly-incident-checkpoint-v1" and
        checkpoint["repository"] == n["repository"] and
        checkpoint["workflow_ref"] ==
          n["repository"] <> "/.github/workflows/nightly.yml@refs/heads/main" and
        checkpoint["last_run_id"] == run["run_id"] and
        checkpoint["last_run_attempt"] == run["attempt"],
      "scheduled_checkpoint_identity"
    )

    check(checkpoint["event_digest"] == jq_digest(run["incident"]), "scheduled_checkpoint_event")

    keys =
      ~w(previous_chain_digest last_run_id last_run_attempt event_digest issue_digest issue_number issue_state)

    check(
      is_binary(checkpoint["previous_chain_digest"]) and
        Regex.match?(~r/\A[0-9a-f]{64}\z/, checkpoint["previous_chain_digest"]) and
        checkpoint["chain_digest"] == jq_digest(Map.take(checkpoint, keys)),
      "scheduled_checkpoint_chain"
    )

    issues = n["incidents"]

    check(
      is_list(issues) and
        Enum.all?(issues, &(&1["title"] == "Nightly CI failure" and &1["state"] == "CLOSED")),
      "scheduled_incident_open"
    )

    # gh embeds viewerDidAuthor in comments. The producer is github-actions;
    # replay from a maintainer credential must compare the producer's view of this
    # one relative boolean, never alter authors, content, order or issue state.
    producer_view =
      Enum.map(issues, fn issue ->
        Map.update!(issue, "comments", fn comments ->
          Enum.map(comments, fn comment ->
            Map.put(
              comment,
              "viewerDidAuthor",
              get_in(comment, ["author", "login"]) == "github-actions"
            )
          end)
        end)
      end)

    check(
      length(issues) == length(Enum.uniq_by(issues, & &1["number"])) and
        checkpoint["issue_digest"] == jq_digest(producer_view),
      "scheduled_checkpoint_issues"
    )

    last = Enum.max_by(issues, & &1["number"], fn -> nil end)

    check(
      checkpoint["issue_number"] == (last && last["number"]) and
        checkpoint["issue_state"] == (last && last["state"]),
      "scheduled_checkpoint_issues"
    )

    :ok
  end
end
