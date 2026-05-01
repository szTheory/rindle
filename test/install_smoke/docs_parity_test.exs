defmodule Rindle.InstallSmoke.DocsParityTest do
  use ExUnit.Case, async: true

  @readme_path Path.expand("../../README.md", __DIR__)
  @guide_path Path.expand("../../guides/getting_started.md", __DIR__)

  setup_all do
    {:ok,
     %{
       readme: File.read!(@readme_path),
       guide: File.read!(@guide_path)
     }}
  end

  test "README and getting-started guide teach the facade-first lifecycle and handoff", %{
    readme: readme,
    guide: guide
  } do
    for doc <- [readme, guide] do
      assert doc =~ "Rindle.Profile"
      assert doc =~ "Rindle.initiate_upload"
      assert doc =~ "Rindle.verify_completion"
      assert doc =~ "Rindle.attach"
      assert doc =~ "Rindle.url"
    end

    assert readme =~ "guides/getting_started.md"
    assert readme =~ "canonical deep adopter guide"
    assert guide =~ "[`README.md`](../README.md)"
  end

  test "introductory sections keep Rindle and Rindle.Profile as the first-tier concepts", %{
    readme: readme,
    guide: guide
  } do
    for {doc, name} <- [{readme, "README"}, {guide, "getting-started"}] do
      intro = introductory_section(doc)

      assert intro =~ "Rindle", "#{name} intro should mention Rindle"
      assert intro =~ "Rindle.Profile", "#{name} intro should mention Rindle.Profile"

      refute intro =~ "Rindle.Upload.Broker",
             "#{name} intro should not present Rindle.Upload.Broker as the default entrypoint"
    end
  end

  test "docs call out adopter-owned Repo, default Oban ownership, and explicit migrations", %{
    readme: readme,
    guide: guide
  } do
    for doc <- [readme, guide] do
      assert doc =~ "adopter-owned Repo"
      assert doc =~ "default Oban"
      assert doc =~ ~s(config :rindle, :repo, MyApp.Repo)
      assert doc =~ ~s(config :my_app, Oban)
      assert doc =~ "Application.app_dir(:rindle, \"priv/repo/migrations\")"
      assert doc =~ "docs snippet"
      assert doc =~ "mix rindle.*"
    end
  end

  test "docs keep presigned PUT first-run and multipart advanced-only", %{
    readme: readme,
    guide: guide
  } do
    for doc <- [readme, guide] do
      assert doc =~ "presigned PUT"
      assert doc =~ "first-run path"
      assert doc =~ "Multipart upload is"
      assert doc =~ "advanced"

      refute Regex.match?(~r/first-run path is multipart/i, doc)
      refute Regex.match?(~r/default onboarding story is multipart/i, doc)
      refute Regex.match?(~r/multipart upload is the default/i, doc)
      refute Regex.match?(~r/Rindle\.Upload\.Broker.+default first-run entrypoint/is, doc)
      refute Regex.match?(~r/Broker\.(initiate_session|verify_completion).+first-run/is, doc)
    end
  end

  defp introductory_section(doc) do
    case Regex.split(~r/^##\s+/m, doc, parts: 2) do
      [intro] -> intro
      [intro, _rest] -> intro
    end
  end
end
