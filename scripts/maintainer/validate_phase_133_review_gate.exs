defmodule Rindle.ValidatePhase133ReviewGate do
  @moduledoc false
  @phase ".planning/phases/133-evidence-charter-and-live-truth"

  def main(argv) do
    with {:ok, root, subject} <- options(argv),
         :ok <- validate(root, subject) do
      IO.puts("phase 133 independent review gate valid for #{subject}")
      0
    else
      {:error, message} ->
        IO.puts(:stderr, "[validate-phase-133-review-gate] #{message}")
        1
    end
  end

  defp options(argv) do
    case OptionParser.parse(argv, strict: [root: :string, subject: :string]) do
      {[root: root, subject: subject], [], []} ->
        if Regex.match?(~r/\A[0-9a-f]{40}\z/, subject),
          do: {:ok, Path.expand(root), subject},
          else: {:error, "subject must be a lowercase 40-character commit SHA"}

      _ ->
        {:error, "expected --root ROOT --subject SHA"}
    end
  end

  defp validate(root, subject) do
    census_path = Path.join(root, Path.join(@phase, "133-EVIDENCE-CENSUS.json"))
    summary_path = Path.join(root, Path.join(@phase, "133-47-SUMMARY.md"))

    with {:ok, census} <- read(census_path),
         {:ok, census_data} <- Jason.decode(census),
         true <- census_data["subject_sha"] == subject or {:error, "census subject mismatch"},
         census_digest <- :crypto.hash(:sha256, census) |> Base.encode16(case: :lower),
         {:ok, summary} <- read(summary_path),
         :ok <- bound_metadata(summary, subject, census_digest, "Plan 47 summary"),
         :ok <- check_report(root, "133-REVIEW.md", subject, census_digest, :review),
         :ok <- check_report(root, "133-VALIDATION.md", subject, census_digest, :validation),
         :ok <- check_report(root, "133-SECURITY.md", subject, census_digest, :security) do
      :ok
    else
      {:error, message} -> {:error, message}
      false -> {:error, "census subject mismatch"}
      _ -> {:error, "malformed census"}
    end
  end

  defp check_report(root, name, subject, digest, kind) do
    path = Path.join(root, Path.join(@phase, name))

    with {:ok, body} <- read(path),
         :ok <- bound_metadata(body, subject, digest, name),
         :ok <- sign_off(body, kind),
         :ok <- report_contract(body, kind) do
      :ok
    end
  end

  defp bound_metadata(body, subject, digest, label) do
    frontmatter =
      case Regex.run(~r/\A---\s*\n(.*?)\n---/s, body, capture: :all_but_first) do
        [value] -> value
        _ -> ""
      end

    subject_fields = Regex.scan(~r/^subject_sha:\s*([0-9a-f]{40})\s*$/m, frontmatter)
    digest_fields = Regex.scan(~r/^census_sha256:\s*([0-9a-f]{64})\s*$/m, frontmatter)

    if subject_fields == [["subject_sha: #{subject}", subject]] and
         digest_fields == [["census_sha256: #{digest}", digest]] and
         length(Regex.scan(~r/^\*\*Subject SHA:\*\* #{Regex.escape(subject)}\s*$/m, body)) == 1 and
         length(Regex.scan(~r/^\*\*Census SHA-256:\*\* #{Regex.escape(digest)}\s*$/m, body)) == 1 do
      :ok
    else
      {:error,
       "#{label} has absent, stale, self-referential, or mismatched subject/census binding"}
    end
  end

  defp sign_off(body, kind) do
    expected = %{
      review: "No blocking findings",
      validation: "Production path mutation proof passed",
      security: "All 23 audited findings are closed or explicitly dispositioned"
    }

    case Regex.run(~r/^## Sign-Off\s*\n(.*?)(?=^## |\z)/ms, body, capture: :all_but_first) do
      [section] ->
        if Regex.match?(~r/^- \[x\] #{Regex.escape(Map.fetch!(expected, kind))}\s*$/mi, section),
          do: :ok,
          else: {:error, "#{kind} sign-off is incomplete"}

      _ ->
        {:error, "#{kind} sign-off section is missing or ambiguous"}
    end
  end

  defp report_contract(body, :review) do
    finding_ids = ~w(CR-01 CR-02 CR-03 CR-04 CR-05 CR-06 WR-01 WR-02)

    cond do
      not String.contains?(body, "status: approved") ->
        {:error, "review is not approved"}

      not String.contains?(body, "blocking: 0") ->
        {:error, "review has blocking findings"}

      not Enum.all?(
        finding_ids,
        &(String.contains?(body, &1) and
              Regex.match?(~r/#{&1}[^\n]*(?:closed|fixed|dispositioned)/i, body))
      ) ->
        {:error, "review dispositions are incomplete"}

      true ->
        :ok
    end
  end

  defp report_contract(body, :validation) do
    if Regex.match?(~r/nyquist_compliant:\s*true\b/, body) and
         String.contains?(body, "production_path_mutation_proof: passed") do
      :ok
    else
      {:error, "validation lacks Nyquist compliance or production-path mutation proof"}
    end
  end

  defp report_contract(body, :security) do
    high_ids = ~w(T-133-32 T-133-53 T-133-74 T-133-85 T-133-91 T-133-105 T-133-39-03 T-133-42-03)

    disposition_rows =
      Regex.scan(
        ~r/^\|\s*(T-133-[^|]+)\|[^\n]*\|\s*(?:closed|dispositioned|accepted)\s*\|\s*$/im,
        body,
        capture: :all_but_first
      )
      |> List.flatten()

    unresolved_rows =
      Regex.scan(~r/^\|\s*T-133-[^|]+\|[^\n]*\|\s*(?:open|unresolved)\s*\|/im, body)

    distinct_dispositions = Enum.uniq(disposition_rows)

    cond do
      not Regex.match?(~r/threats_open:\s*0\b/, body) ->
        {:error, "security report has open threats"}

      not String.contains?(body, "status: verified") ->
        {:error, "security report is not verified"}

      Enum.any?(
        high_ids,
        &(not Regex.match?(
            ~r/^\|\s*#{Regex.escape(&1)}\s*\|[^\n]*\|\s*(?:closed|dispositioned)\s*\|/im,
            body
          ))
      ) ->
        {:error, "security dispositions are incomplete for a named high threat"}

      length(unresolved_rows) > 0 ->
        {:error, "security report retains unresolved threat rows"}

      length(distinct_dispositions) < 23 ->
        {:error, "security report must explicitly disposition 23 distinct findings"}

      true ->
        :ok
    end
  end

  defp read(path) do
    case File.read(path) do
      {:ok, body} -> {:ok, body}
      _ -> {:error, "required report is missing or unreadable: #{Path.basename(path)}"}
    end
  end
end

System.halt(Rindle.ValidatePhase133ReviewGate.main(System.argv()))
