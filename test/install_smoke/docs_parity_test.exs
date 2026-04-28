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

  test "README and getting-started guide share the canonical lifecycle and handoff", %{
    readme: readme,
    guide: guide
  } do
    for doc <- [readme, guide] do
      assert doc =~ "Broker.initiate_session"
      assert doc =~ "Broker.sign_url"
      assert doc =~ "Broker.verify_completion"
      assert doc =~ "Rindle.Delivery.url"
    end

    assert readme =~ "guides/getting_started.md"
    assert readme =~ "canonical deep adopter guide"
    assert guide =~ "[`README.md`](../README.md)"
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
    end
  end
end
