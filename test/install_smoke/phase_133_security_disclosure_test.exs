defmodule Rindle.InstallSmoke.Phase133SecurityDisclosureTest do
  use ExUnit.Case, async: true

  @phase Path.expand("../../.planning/phases/133-evidence-charter-and-live-truth", __DIR__)
  @credential_patterns [
    ~r/gh[pousr]_[A-Za-z0-9]{20,}/,
    ~r/github_pat_[A-Za-z0-9_]{20,}/,
    ~r/AKIA[0-9A-Z]{16}/,
    ~r/(?i)authorization:\s*bearer\s+\S+/,
    ~r/(?i)(?:client[_-]?secret|access[_-]?token)\s*[:=]\s*\S+/
  ]
  @raw_log_patterns [
    ~r/(?m)^##\[(?:error|warning|group|endgroup)\]/,
    ~r/(?m)^::(?:debug|error|warning)::/,
    ~r/(?i)gh\s+run\s+view[^\n]*--log/,
    ~r/\x1b\[[0-9;]*m/
  ]

  test "T-133-102: Plan 26 documentation contains no credential canary" do
    body = File.read!(Path.join(@phase, "133-26-PLAN.md"))
    canary = "Authorization: Bearer phase133-secret-canary"

    assert credential_free?(body)
    refute credential_free?(body <> "\n" <> canary)
  end

  test "T-133-36-05 and T-133-41-05: checkpoint records expose only safe public text" do
    for plan <- [36, 41] do
      summary = File.read!(Path.join(@phase, "133-#{plan}-SUMMARY.md"))

      assert checkpoint_record_safe?(summary),
             "Plan #{plan} checkpoint disclosure contract failed"

      canary = "Authorization: Bearer phase133-secret-canary"

      unsafe_summary =
        String.replace(
          summary,
          "**Human response:** exact `authorize`",
          "**Human response:** exact `authorize`\n#{canary}",
          global: false
        )

      refute checkpoint_record_safe?(unsafe_summary)

      raw_log_summary =
        String.replace(
          summary,
          "**Human response:** exact `authorize`",
          "**Human response:** exact `authorize`\n```text\ngh run view --log\n```",
          global: false
        )

      refute checkpoint_record_safe?(raw_log_summary)
    end
  end

  defp checkpoint_record_safe?(summary) do
    case Regex.run(~r/## Authorization Record\s*(.*?)(?:\n## |\z)/s, summary,
           capture: :all_but_first
         ) do
      [record] ->
        credential_free?(record) and Enum.all?(@raw_log_patterns, &(not Regex.match?(&1, record)))

      _ ->
        false
    end
  end

  defp credential_free?(body),
    do: Enum.all?(@credential_patterns, &(not Regex.match?(&1, body)))
end
