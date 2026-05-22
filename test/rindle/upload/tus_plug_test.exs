defmodule Rindle.Upload.TusPlugTest do
  @moduledoc """
  Contract test for the tus protocol edge `Rindle.Upload.TusPlug` (Plan 02 — the
  create/read half). The path-segment token extraction under `forward` (Landmine 1)
  is de-risked FIRST, via a real `Plug.Router` `forward` so the prefix-strip is
  exercised, not assumed.
  """

  use Rindle.DataCase, async: false

  import Plug.Test
  import Plug.Conn

  alias Ecto.Adapters.SQL.Sandbox
  alias Rindle.Adopter.CanonicalApp.Repo, as: AdopterRepo
  alias Rindle.Domain.MediaUploadSession
  alias Rindle.Storage.Local
  alias Rindle.Upload.{Broker, TusPlug}

  @secret_key_base "tus-test-secret-key-base-0123456789abcdef"
  @tus_url_salt "rindle:tus:url"
  @max_size 1_000_000

  defmodule TusProfile do
    use Rindle.Profile,
      storage: Local,
      variants: [thumb: [mode: :crop, width: 100, height: 100]],
      allow_mime: ["image/jpeg"],
      max_bytes: 10_485_760
  end

  defmodule NoTusStorage do
    @moduledoc false
    def capabilities, do: [:local, :presigned_put]
  end

  defmodule NoTusProfile do
    use Rindle.Profile,
      storage: NoTusStorage,
      variants: [thumb: [mode: :crop, width: 100, height: 100]]
  end

  # Real router so `forward` strips the mount prefix into `script_name` and the
  # token lands in `path_info` exactly as it will in an adopter's app.
  defmodule TusRouter do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    forward("/uploads/tus",
      to: Rindle.Upload.TusPlug,
      init_opts: [
        profile: Rindle.Upload.TusPlugTest.TusProfile,
        secret_key_base: "tus-test-secret-key-base-0123456789abcdef",
        max_size: 1_000_000
      ]
    )
  end

  setup do
    case start_supervised(AdopterRepo) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    Sandbox.checkout(AdopterRepo)
    Sandbox.mode(AdopterRepo, {:shared, self()})

    previous_repo = Application.get_env(:rindle, :repo)
    Application.put_env(:rindle, :repo, AdopterRepo)

    root = Path.join(System.tmp_dir!(), "rindle-tus-plug-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)

    on_exit(fn ->
      File.rm_rf(root)

      case previous_repo do
        nil -> Application.delete_env(:rindle, :repo)
        value -> Application.put_env(:rindle, :repo, value)
      end
    end)

    {:ok, root: root}
  end

  defp route(conn), do: TusRouter.call(conn, [])

  defp create_session(length) do
    conn =
      conn(:post, "/uploads/tus")
      |> put_req_header("upload-length", Integer.to_string(length))
      |> put_req_header("upload-metadata", "filename Y2xpcC5qcGc=")
      |> route()

    [location] = get_resp_header(conn, "location")
    token = location |> String.split("/") |> List.last()
    {conn, location, token}
  end

  describe "Task 1 — Wave-0 de-risk: init/1 capability raise + method guard" do
    test "init/1 raises ArgumentError when the adapter lacks :tus_upload (no silent downgrade)" do
      assert_raise ArgumentError, ~r/:tus_upload/, fn ->
        TusPlug.init(profile: NoTusProfile, secret_key_base: @secret_key_base)
      end
    end

    test "init/1 returns opts for a Local-backed tus profile", %{root: root} do
      opts =
        TusPlug.init(
          profile: TusProfile,
          secret_key_base: @secret_key_base,
          max_size: @max_size,
          root: root
        )

      assert opts[:profile] == TusProfile
      assert opts[:adapter] == Local
      assert opts[:secret_key_base] == @secret_key_base
      assert opts[:max_size] == @max_size
      assert opts[:root] == Path.expand(root)
    end

    test "a non-tus method returns 405" do
      conn = conn(:get, "/uploads/tus/anything") |> route()
      assert conn.status == 405
    end
  end

  describe "Task 2 — OPTIONS advertisement + POST Creation" do
    test "OPTIONS advertises exactly the implemented extensions" do
      conn = conn(:options, "/uploads/tus") |> route()

      assert conn.status == 204
      assert get_resp_header(conn, "tus-version") == ["1.0.0"]
      assert get_resp_header(conn, "tus-resumable") == ["1.0.0"]
      assert get_resp_header(conn, "tus-extension") == ["creation,expiration,termination"]
      assert get_resp_header(conn, "tus-max-size") == ["1000000"]
    end

    test "POST creates a signed, tus-stamped session and returns 201 + Location" do
      {conn, location, token} = create_session(500)

      assert conn.status == 201
      assert location =~ ~r{^/uploads/tus/}
      assert get_resp_header(conn, "tus-resumable") == ["1.0.0"]
      assert [_expires] = get_resp_header(conn, "upload-expires")

      assert {:ok, payload} = Plug.Crypto.verify(@secret_key_base, @tus_url_salt, token)
      assert Map.has_key?(payload, "session_id")
      assert Map.has_key?(payload, "actor")
      assert Map.has_key?(payload, "exp")

      session = AdopterRepo.get!(MediaUploadSession, payload["session_id"])
      assert session.resumable_protocol == "tus"
      assert session.state == "signed"
      assert session.upload_strategy == "resumable"
      # The signed URL is persisted ONLY into session_uri.
      assert session.session_uri == location
    end

    test "POST missing or non-integer Upload-Length returns 400" do
      missing = conn(:post, "/uploads/tus") |> route()
      assert missing.status == 400

      invalid = conn(:post, "/uploads/tus") |> put_req_header("upload-length", "abc") |> route()
      assert invalid.status == 400
    end

    test "POST with Upload-Length over Tus-Max-Size returns 413" do
      conn =
        conn(:post, "/uploads/tus")
        |> put_req_header("upload-length", Integer.to_string(@max_size + 1))
        |> route()

      assert conn.status == 413
    end

    test "Upload-Metadata is opaque — not parsed for filename/path" do
      hostile = Base.encode64("../../etc/passwd")

      conn =
        conn(:post, "/uploads/tus")
        |> put_req_header("upload-length", "10")
        |> put_req_header("upload-metadata", "filename #{hostile}")
        |> route()

      assert conn.status == 201
      [location] = get_resp_header(conn, "location")

      {:ok, payload} =
        Plug.Crypto.verify(
          @secret_key_base,
          @tus_url_salt,
          location |> String.split("/") |> List.last()
        )

      session = AdopterRepo.get!(MediaUploadSession, payload["session_id"])

      refute session.upload_key =~ "passwd"
      refute session.upload_key =~ ".."
    end
  end

  describe "Task 3 — token verify (404/401-never-200) + HEAD authoritative offset" do
    test "HEAD with a valid token resolves from the forward-stripped path_info (Landmine 1)" do
      {_conn, _location, token} = create_session(500)

      conn = conn(:head, "/uploads/tus/" <> token) |> route()

      assert conn.status == 204
      assert get_resp_header(conn, "upload-offset") == ["0"]
      assert get_resp_header(conn, "upload-length") == ["500"]
      assert get_resp_header(conn, "cache-control") == ["no-store"]
      assert get_resp_header(conn, "tus-resumable") == ["1.0.0"]
    end

    test "a tampered token returns 404, never 200" do
      {_conn, _location, token} = create_session(500)

      conn = conn(:head, "/uploads/tus/" <> token <> "tamper") |> route()

      assert conn.status == 404
      refute conn.status == 200
    end

    test "a missing token (empty path_info) returns 404" do
      conn = conn(:head, "/uploads/tus") |> route()
      assert conn.status == 404
    end

    test "a validly-signed but expired token returns 401, never 200" do
      {:ok, %{session: session}} = Broker.initiate_tus_upload(TusProfile)

      token =
        Plug.Crypto.sign(@secret_key_base, @tus_url_salt, %{
          "session_id" => session.id,
          "actor" => "x",
          "exp" => System.system_time(:second) - 60,
          "length" => 10
        })

      conn = conn(:head, "/uploads/tus/" <> token) |> route()

      assert conn.status == 401
      refute conn.status == 200
    end

    test "a session past its expires_at returns 410 Gone" do
      {:ok, %{session: session}} = Broker.initiate_tus_upload(TusProfile)

      {:ok, expired} =
        session
        |> MediaUploadSession.changeset(%{
          expires_at: DateTime.add(DateTime.utc_now(), -60, :second)
        })
        |> AdopterRepo.update()

      token =
        Plug.Crypto.sign(@secret_key_base, @tus_url_salt, %{
          "session_id" => expired.id,
          "actor" => "x",
          "exp" => System.system_time(:second) + 3600,
          "length" => 10
        })

      conn = conn(:head, "/uploads/tus/" <> token) |> route()

      assert conn.status == 410
      assert get_resp_header(conn, "tus-resumable") == ["1.0.0"]
    end

    test "the signed URL is redacted in inspect and never leaked (invariant 14)" do
      {_conn, location, token} = create_session(500)
      {:ok, payload} = Plug.Crypto.verify(@secret_key_base, @tus_url_salt, token)
      session = AdopterRepo.get!(MediaUploadSession, payload["session_id"])

      assert session.session_uri == location
      assert inspect(session) =~ "[REDACTED]"
      refute inspect(session) =~ token
    end
  end
end
