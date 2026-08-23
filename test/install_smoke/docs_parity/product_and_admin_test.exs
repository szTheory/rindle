Code.require_file("support.ex", __DIR__)

defmodule Rindle.InstallSmoke.DocsParity.ProductAndAdminTest do
  import Rindle.InstallSmoke.DocsParity.Support
  use ExUnit.Case, async: true

  @readme_path Path.expand("../../../README.md", __DIR__)
  @guide_path Path.expand("../../../guides/getting_started.md", __DIR__)
  @user_flows_path Path.expand("../../../guides/user_flows.md", __DIR__)
  @admin_console_path Path.expand("../../../guides/admin_console.md", __DIR__)
  @mix_exs_path Path.expand("../../../mix.exs", __DIR__)

  setup_all do
    {:ok,
     load_docs!(%{
       readme: @readme_path,
       guide: @guide_path,
       user_flows: @user_flows_path
     })}
  end

  test "user flows guide freezes the canonical owner-erasure support truth", %{
    user_flows: user_flows
  } do
    normalized =
      user_flows
      |> String.replace(~r/\n>\s*/, " ")
      |> String.downcase()

    for snippet <- [
          "preview_owner_erasure/2",
          "erase_owner/2",
          "attachments_to_detach",
          "assets_to_purge",
          "retained shared assets",
          "rindle-managed",
          "detach now, purge later",
          "cleanup_orphans",
          "maintenance-only",
          # TRUTH-07: user_flows now affirms the mountable admin console instead
          # of denying "an admin UI". The old required `"admin ui"` snippet was
          # replaced with the truthful "admin console" token (asserted below);
          # leaving it here would relock the scope-reversed denial (T-93-05).
          "admin console",
          "preview_batch_owner_erasure",
          "erase_batch_owner_erasure",
          "batch owner erasure",
          "batch_owner_erasure",
          "batch_owner_failed",
          "partial_report",
          "force-delete"
        ] do
      assert normalized =~ snippet
    end

    refute normalized =~ "bulk orchestration"

    refute user_flows =~
             "Today you detach each of an owner's slots, then let `mix rindle.cleanup_orphans` purge the now-unattached assets."

    refute Regex.match?(
             ~r/Today you detach each of an owner's slots, then let `mix rindle\.cleanup_orphans` purge/is,
             user_flows
           )

    refute user_flows =~ "being standardized for `v1.10`"
    refute user_flows =~ "The full executable facade lands in later `v1.10` phase work"

    # TRUTH-07: the JTBD admin-UI exclusion is reversed. user_flows must not
    # carry the old denial phrasings now that the mountable console ships.
    refute Regex.match?(~r/\ban admin UI\b/i, user_flows),
           "user_flows.md must not deny an admin UI (scope reversed in v1.18)"

    refute user_flows =~ "Admin UI, force-delete",
           "user_flows.md must not list the admin UI among deferred work"
  end

  test "admin console truth is locked across facade, guide, extras, and README", %{
    readme: readme
  } do
    # (1) Facade moduledoc: affirm the mountable console, deny no admin UI.
    facade_moduledoc =
      Rindle
      |> moduledoc!()
      |> normalize_whitespace()

    assert facade_moduledoc =~ "rindle_admin",
           "Rindle facade moduledoc must reference the rindle_admin router macro (TRUTH-07)"

    assert facade_moduledoc =~ "admin console",
           "Rindle facade moduledoc must affirm the mountable admin console (TRUTH-07)"

    refute Regex.match?(~r/no admin ui/i, facade_moduledoc),
           "Rindle facade moduledoc must not deny an admin UI (scope reversed in v1.18)"

    # Retain the deferred owner-erasure truths the facade still promises.
    assert facade_moduledoc =~ "force-delete"
    assert facade_moduledoc =~ "scheduler/cron erasure"

    # (2) admin_console guide exists, is in extras, and names the router macro.
    assert File.exists?(@admin_console_path),
           "guides/admin_console.md must exist (created by Plan 03)"

    admin_guide = File.read!(@admin_console_path)

    assert admin_guide =~ "rindle_admin",
           "admin_console.md must document the rindle_admin router macro"

    mix_exs = File.read!(@mix_exs_path)

    assert mix_exs =~ "guides/admin_console.md",
           "mix.exs must wire admin_console.md into docs extras"

    # (3) README links the rendered guide.
    assert readme =~ "admin_console.html",
           "README must link the admin console guide (admin_console.html)"
  end

  test "user flows roadmap does not regress tus or mux to near-term", %{user_flows: user_flows} do
    normalized = String.downcase(user_flows)

    assert normalized =~ "initiate_tus_upload"
    assert normalized =~ "shipped since 0.1.8"
    assert normalized =~ "resumable uploads"

    refute Regex.match?(~r/near-term.{0,80}tus/u, normalized)
    refute Regex.match?(~r/tus.{0,80}near-term/u, normalized)
    refute Regex.match?(~r/near-term.{0,80}mux/u, normalized)
    refute Regex.match?(~r/browser.{0,40}mux.{0,80}near-term/u, normalized)
  end

  test "user flows and operations document batch erasure without duplicating mix task contract",
       %{
         user_flows: user_flows
       } do
    operations = File.read!(Path.expand("../../../guides/operations.md", __DIR__))
    normalized_flows = String.downcase(user_flows)
    normalized_ops = String.downcase(operations)

    assert normalized_flows =~ "preview_batch_owner_erasure"
    assert normalized_flows =~ "batch_owner_erasure"
    assert normalized_ops =~ "batch_owner_erasure"
    assert normalized_ops =~ "user_flows.html"

    refute normalized_ops =~ "--owners-file"
    refute normalized_ops =~ "owner_type"
  end

  test "getting-started and operations stay thin while pointing to the canonical owner-erasure flow",
       %{
         guide: guide
       } do
    operations = File.read!(Path.expand("../../../guides/operations.md", __DIR__))

    assert guide =~ "[User Flows](user_flows.html)"
    assert guide =~ "account deletion / owner erasure"
    assert guide =~ "Batch owner erasure"
    assert guide =~ "user_flows.html"

    assert operations =~ "[User Flows](user_flows.html)"
    assert operations =~ "supported account-deletion surface"
    assert operations =~ "cleanup_orphans"
    assert operations =~ "maintenance-only"

    refute guide =~ "detach each of an owner"
    refute operations =~ "detach each of an owner"
  end
end
