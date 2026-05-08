defmodule Rindle.Domain.MediaUploadSessionTest do
  use ExUnit.Case, async: true

  alias Rindle.Domain.MediaUploadSession

  describe "changeset/2" do
    test "casts resumable persistence fields without widening required fields" do
      expires_at = ~U[2026-05-07 20:00:00.000000Z]
      session_uri_expires_at = ~U[2026-05-07 21:00:00.000000Z]

      attrs = %{
        asset_id: Ecto.UUID.generate(),
        state: "signed",
        upload_key: "uploads/media/asset-1",
        upload_strategy: "presigned_put",
        expires_at: expires_at,
        session_uri: "https://storage.googleapis.com/upload/resumable/session-123",
        session_uri_expires_at: session_uri_expires_at,
        last_known_offset: 1024,
        region_hint: "us-east1"
      }

      changeset = MediaUploadSession.changeset(%MediaUploadSession{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :session_uri) == attrs.session_uri

      assert Ecto.Changeset.get_change(changeset, :session_uri_expires_at) ==
               session_uri_expires_at

      assert Ecto.Changeset.get_change(changeset, :last_known_offset) == 1024
      assert Ecto.Changeset.get_change(changeset, :region_hint) == "us-east1"
    end
  end

  describe "redact_session_uri/1" do
    test "returns nil for nil" do
      assert MediaUploadSession.redact_session_uri(nil) == nil
    end

    test "redacts populated session URIs" do
      assert MediaUploadSession.redact_session_uri(
               "https://storage.googleapis.com/upload/resumable/session-123"
             ) == "[REDACTED]"
    end
  end

  describe "Inspect implementation" do
    test "redacts the raw session_uri from inspect output" do
      raw_session_uri = "https://storage.googleapis.com/upload/resumable/session-123"

      session = %MediaUploadSession{
        asset_id: Ecto.UUID.generate(),
        state: "signed",
        upload_key: "uploads/media/asset-1",
        upload_strategy: "resumable",
        expires_at: ~U[2026-05-07 20:00:00.000000Z],
        session_uri: raw_session_uri
      }

      inspected = inspect(session)

      assert inspected =~ "[REDACTED]"
      refute inspected =~ raw_session_uri
    end
  end
end
