defmodule AdoptionDemoWeb.AdminLifecycleDisplayTest do
  @moduledoc """
  Locks in the Phase 91 deliverable: edge-case lifecycle states (quarantined and
  degraded assets, failed/expired/aborted upload sessions) render gracefully in
  the admin console — no 500, no error state.

  Discharges UAT checkpoint "Admin Console Lifecycle Display" (formerly human-
  verified in 91-HUMAN-UAT.md). Rows are inserted directly (no MinIO upload), so
  the test stays in the fast, storage-free ExUnit lane.
  """
  use AdoptionDemoWeb.ConnCase

  import Phoenix.LiveViewTest

  alias AdoptionDemo.Repo
  alias Rindle.Domain.{MediaAsset, MediaUploadSession}

  @asset_states ~w(quarantined degraded ready processing)
  @session_states ~w(failed expired aborted completed)

  setup do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    expires = DateTime.utc_now() |> DateTime.truncate(:microsecond) |> DateTime.add(3600)

    assets =
      for {state, idx} <- Enum.with_index(@asset_states) do
        Repo.insert!(%MediaAsset{
          state: state,
          storage_key: "seed/test/asset_#{state}_#{idx}",
          profile: "AdoptionDemo.DocumentProfile",
          kind: "image",
          content_type: "application/pdf",
          filename: "asset_#{state}.ext",
          byte_size: 1024,
          inserted_at: now,
          updated_at: now
        })
      end

    primary = hd(assets)

    for {state, idx} <- Enum.with_index(@session_states) do
      Repo.insert!(%MediaUploadSession{
        asset_id: primary.id,
        state: state,
        upload_key: "seed/test/upload_#{state}_#{idx}",
        upload_strategy: "presigned_put",
        expires_at: expires,
        inserted_at: now,
        updated_at: now
      })
    end

    :ok
  end

  test "quarantined and degraded assets render without an error state", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/rindle/assets")

    assert html =~ "quarantined"
    assert html =~ "degraded"
    refute html =~ "data-rindle-admin-error-state"
  end

  test "failed and expired upload sessions render without an error state", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/rindle/upload-sessions")

    assert html =~ "failed"
    assert html =~ "expired"
    refute html =~ "data-rindle-admin-error-state"
  end
end
