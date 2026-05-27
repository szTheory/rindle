defmodule Rindle.Upload.TusPlugTest do
  @moduledoc """
  Contract test for the tus protocol edge `Rindle.Upload.TusPlug` (Plan 02 — the
  create/read half). The path-segment token extraction under `forward` (Landmine 1)
  is de-risked FIRST, via a real `Plug.Router` `forward` so the prefix-strip is
  exercised, not assumed.
  """

  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Adopter.CanonicalApp.Repo

  import Plug.Test
  import Plug.Conn
  import Mox

  alias Ecto.Adapters.SQL.Sandbox
  alias Rindle.Adopter.CanonicalApp.Repo, as: AdopterRepo
  alias Rindle.Domain.{MediaAsset, MediaUploadSession}
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

  # Mox-backed profile to prove the PATCH/completion path dispatches through the
  # behaviour (adapter.upload_part_stream/5 + adapter.complete_part_stream/4),
  # not a hard-wired Local call. The mock advertises :tus_upload so init/1 passes.
  defmodule MockTusProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [thumb: [mode: :crop, width: 100, height: 100]],
      allow_mime: ["image/jpeg"],
      max_bytes: 10_485_760
  end

  # Probe repo for the WR-02 update-failure path: delegates reads to AdopterRepo
  # (so load_active_session/1 still resolves the row) but forces the lifecycle
  # `update/1` to return {:error, changeset}. Swapped in only for the WR-02 test
  # so the DELETE handler exercises the {:error, _} update branch deterministically
  # without depending on a contrived DB constraint violation.
  defmodule DeleteFailRepo do
    @inner Rindle.Adopter.CanonicalApp.Repo

    def get(schema, id), do: @inner.get(schema, id)
    def get(schema, id, opts), do: @inner.get(schema, id, opts)
    def get!(schema, id), do: @inner.get!(schema, id)

    def update(%Ecto.Changeset{} = changeset) do
      {:error, %{changeset | valid?: false, action: :update}}
    end
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
    previous_tus_resume_authorizer = Application.get_env(:rindle, :tus_resume_authorizer)
    Application.put_env(:rindle, :repo, AdopterRepo)

    root = Path.join(System.tmp_dir!(), "rindle-tus-plug-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)

    on_exit(fn ->
      File.rm_rf(root)

      case previous_repo do
        nil -> Application.delete_env(:rindle, :repo)
        value -> Application.put_env(:rindle, :repo, value)
      end

      case previous_tus_resume_authorizer do
        nil -> Application.delete_env(:rindle, :tus_resume_authorizer)
        value -> Application.put_env(:rindle, :tus_resume_authorizer, value)
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

  # Plan-03 direct-call helpers — drive TusPlug.call/2 with opts bound to the
  # test's tmp root so PATCH/completion file IO is isolated per test.
  defp opts_for(root) do
    TusPlug.init(
      profile: TusProfile,
      secret_key_base: @secret_key_base,
      max_size: @max_size,
      root: root
    )
  end

  defp create(opts, length) do
    conn =
      conn(:post, "/uploads/tus")
      |> put_req_header("upload-length", Integer.to_string(length))
      |> put_req_header("upload-metadata", "filename Y2xpcC5qcGc=")
      |> TusPlug.call(opts)

    [location] = get_resp_header(conn, "location")
    token = location |> String.split("/") |> List.last()
    {:ok, payload} = Plug.Crypto.verify(@secret_key_base, @tus_url_salt, token)
    {token, payload["session_id"]}
  end

  defp patch(opts, token, offset, body) do
    conn(:patch, "/uploads/tus/" <> token, body)
    |> put_req_header("content-type", "application/offset+octet-stream")
    |> put_req_header("upload-offset", Integer.to_string(offset))
    |> TusPlug.call(opts)
  end

  defp head(opts, token) do
    conn(:head, "/uploads/tus/" <> token) |> TusPlug.call(opts)
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
      assert opts[:resume_authorizer] == nil
    end

    test "a non-tus method returns 405" do
      conn = conn(:get, "/uploads/tus/anything") |> route()
      assert conn.status == 405
    end

    test "GET with Tus-Resumable is treated as forwarded HEAD for Phoenix endpoints", %{
      root: root
    } do
      opts = opts_for(root)
      {token, _session_id} = create(opts, 32)

      conn =
        conn(:get, "/uploads/tus/" <> token)
        |> put_req_header("tus-resumable", "1.0.0")
        |> TusPlug.call(opts)

      assert conn.status == 204
      assert get_resp_header(conn, "upload-offset") == ["0"]
      assert get_resp_header(conn, "tus-resumable") == ["1.0.0"]
    end
  end

  describe "Task 2 — OPTIONS advertisement + POST Creation" do
    test "OPTIONS advertises exactly the implemented extensions" do
      conn = conn(:options, "/uploads/tus") |> route()

      assert conn.status == 204
      assert get_resp_header(conn, "tus-version") == ["1.0.0"]
      assert get_resp_header(conn, "tus-resumable") == ["1.0.0"]

      assert get_resp_header(conn, "tus-extension") == [
               "creation,expiration,termination,checksum,creation-defer-length,concatenation"
             ]

      assert get_resp_header(conn, "tus-max-size") == ["1000000"]
      assert get_resp_header(conn, "tus-checksum-algorithm") == ["sha1,sha256"]
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

  describe "Phase 44 — optional resume authorizer" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      Application.put_env(:rindle, :tus_resume_authorizer, Rindle.TusResumeAuthorizerMock)
      :ok
    end

    test "HEAD rejects when the configured resume authorizer returns :reject", %{root: root} do
      opts = opts_for(root)
      {token, sid} = create(opts, 100)
      session = AdopterRepo.get!(MediaUploadSession, sid)

      expect(Rindle.TusResumeAuthorizerMock, :authorize, fn "anonymous", :resume, subject ->
        assert subject.token_actor == "anonymous"
        assert subject.session.id == session.id
        assert subject.profile == TusProfile
        assert subject.method == :head
        :reject
      end)

      conn = head(opts, token)

      assert conn.status == 401
      refute conn.status == 200
    end

    test "PATCH allows the request when the configured resume authorizer returns :ok", %{
      root: root
    } do
      opts = opts_for(root)
      {token, sid} = create(opts, 100)

      expect(Rindle.TusResumeAuthorizerMock, :authorize, fn "anonymous", :resume, subject ->
        assert subject.session.id == sid
        assert subject.method == :patch
        :ok
      end)

      conn = patch(opts, token, 0, "0123456789")

      assert conn.status == 204
      assert AdopterRepo.get!(MediaUploadSession, sid).last_known_offset == 10
    end
  end

  describe "Plan 03 Task 1 — PATCH gates (415/409/413) + streaming append" do
    test "PATCH with the wrong Content-Type returns 415 without reading the body", %{root: root} do
      opts = opts_for(root)
      {token, sid} = create(opts, 100)

      conn =
        conn(:patch, "/uploads/tus/" <> token, "0123456789")
        |> put_req_header("content-type", "text/plain")
        |> put_req_header("upload-offset", "0")
        |> TusPlug.call(opts)

      assert conn.status == 415
      assert AdopterRepo.get!(MediaUploadSession, sid).last_known_offset == 0
    end

    test "PATCH at the wrong offset returns 409, body NOT consumed, offset unchanged", %{
      root: root
    } do
      opts = opts_for(root)
      {token, sid} = create(opts, 100)
      part_path = Local.tus_part_path(sid, root: root)

      conn = patch(opts, token, 5, "0123456789")

      assert conn.status == 409
      assert AdopterRepo.get!(MediaUploadSession, sid).last_known_offset == 0
      # body not consumed: stream_append was never reached, so no part file was opened
      refute File.exists?(part_path)
    end

    test "PATCH at the correct offset streams to the tmp file and advances the offset", %{
      root: root
    } do
      opts = opts_for(root)
      {token, sid} = create(opts, 100)
      part_path = Local.tus_part_path(sid, root: root)

      conn = patch(opts, token, 0, "0123456789")

      assert conn.status == 204
      assert get_resp_header(conn, "upload-offset") == ["10"]
      assert get_resp_header(conn, "tus-resumable") == ["1.0.0"]
      assert File.stat!(part_path).size == 10
      assert AdopterRepo.get!(MediaUploadSession, sid).last_known_offset == 10
    end

    test "PATCH that would exceed the declared Upload-Length returns 413", %{root: root} do
      opts = opts_for(root)
      {token, _sid} = create(opts, 5)

      conn = patch(opts, token, 0, "0123456789")

      assert conn.status == 413
    end
  end

  describe "Plan 03 Task 2 — DELETE termination" do
    test "DELETE with a valid token returns 204, aborts the session AND removes the Local backing part (CR-01)",
         %{root: root} do
      # CR-01 (Plan 09): DELETE now ACTIVELY aborts the backing store before the
      # state transition — for a Local-backed session that means the per-session
      # tmp part file is removed by the DELETE itself, not left for the reaper.
      opts = opts_for(root)
      {token, sid} = create(opts, 100)
      assert patch(opts, token, 0, "0123456789").status == 204
      part_path = Local.tus_part_path(sid, root: root)
      assert File.exists?(part_path)

      conn = conn(:delete, "/uploads/tus/" <> token) |> TusPlug.call(opts)

      assert conn.status == 204
      assert get_resp_header(conn, "tus-resumable") == ["1.0.0"]
      assert AdopterRepo.get!(MediaUploadSession, sid).state == "aborted"
      # The backing part file is gone — DELETE aborted the backing, not the reaper.
      refute File.exists?(part_path)
    end

    test "DELETE with a tampered token returns 404, never 200", %{root: root} do
      opts = opts_for(root)
      {token, _sid} = create(opts, 100)

      conn = conn(:delete, "/uploads/tus/" <> token <> "tamper") |> TusPlug.call(opts)

      assert conn.status == 404
      refute conn.status == 200
    end
  end

  describe "Plan 09 — DELETE aborts the backing store BEFORE the transition (CR-01) + honours update (WR-02)" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup %{root: root} do
      # init/1 probes adapter.capabilities() via Capabilities.require_upload; stub
      # so the :tus_upload gate passes for the Mox adapter.
      stub(Rindle.StorageMock, :capabilities, fn -> [:tus_upload, :head] end)

      opts =
        TusPlug.init(
          profile: MockTusProfile,
          secret_key_base: @secret_key_base,
          max_size: @max_size,
          root: root
        )

      {:ok, mock_opts: opts}
    end

    # Mint a signed token AND stamp a multipart_upload_id on the row so the
    # DELETE path treats the session as S3-backed (upload_id present => the
    # polymorphic abort routes to adapter.abort_multipart_upload/3).
    defp mock_create_s3(opts, length) do
      conn =
        conn(:post, "/uploads/tus")
        |> put_req_header("upload-length", Integer.to_string(length))
        |> put_req_header("upload-metadata", "filename Y2xpcC5qcGc=")
        |> TusPlug.call(opts)

      [location] = get_resp_header(conn, "location")
      token = location |> String.split("/") |> List.last()
      {:ok, payload} = Plug.Crypto.verify(@secret_key_base, @tus_url_salt, token)
      sid = payload["session_id"]

      {:ok, session} =
        AdopterRepo.get!(MediaUploadSession, sid)
        |> MediaUploadSession.changeset(%{multipart_upload_id: "mpu-#{sid}"})
        |> AdopterRepo.update()

      {token, session}
    end

    test "DELETE on an S3-backed session aborts the multipart upload then returns 204 + aborted (CR-01 success path)",
         %{mock_opts: opts} do
      {token, session} = mock_create_s3(opts, 100)
      upload_key = session.upload_key
      upload_id = session.multipart_upload_id

      # The load-bearing CR-01 assertion: DELETE invokes the backing abort with
      # the session's upload_key + multipart upload id (idempotent {:ok,_}).
      expect(Rindle.StorageMock, :abort_multipart_upload, fn key, id, _opts ->
        assert key == upload_key
        assert id == upload_id
        {:ok, %{}}
      end)

      conn = conn(:delete, "/uploads/tus/" <> token) |> TusPlug.call(opts)

      assert conn.status == 204
      assert get_resp_header(conn, "tus-resumable") == ["1.0.0"]
      assert AdopterRepo.get!(MediaUploadSession, session.id).state == "aborted"
    end

    test "DELETE returns 5xx (not 204) when the state update fails AND the backing abort already fired (WR-02 + CR-01 ordering)",
         %{mock_opts: opts} do
      {token, session} = mock_create_s3(opts, 100)
      upload_key = session.upload_key

      # Swap in a probe repo that forces the lifecycle update/1 to fail, so the
      # DELETE handler exercises its {:error, _} update branch deterministically.
      Application.put_env(:rindle, :repo, DeleteFailRepo)
      on_exit(fn -> Application.put_env(:rindle, :repo, AdopterRepo) end)

      # CR-01 ordering proof: even though the DB update will fail, the backing
      # abort MUST already have fired — proving the abort precedes the update at
      # runtime, not merely in source order. verify_on_exit! enforces this.
      expect(Rindle.StorageMock, :abort_multipart_upload, fn key, _id, _opts ->
        assert key == upload_key
        {:ok, %{}}
      end)

      conn = conn(:delete, "/uploads/tus/" <> token) |> TusPlug.call(opts)

      assert conn.status >= 500
      refute conn.status == 204

      # The row stays in its prior state — the client was NOT falsely told 204.
      Application.put_env(:rindle, :repo, AdopterRepo)
      assert AdopterRepo.get!(MediaUploadSession, session.id).state == "signed"
    end

    test "a tampered token returns 404 and NEVER invokes abort_multipart_upload (auth not weakened, CR-01 negative)",
         %{mock_opts: opts} do
      {token, _session} = mock_create_s3(opts, 100)

      # No Mox expectation set: if the abort were invoked before token
      # verification, Mox would raise on the unexpected call.
      conn = conn(:delete, "/uploads/tus/" <> token <> "tamper") |> TusPlug.call(opts)

      assert conn.status == 404
      refute conn.status == 200
    end

    # -------------------------------------------------------------------------
    # CR-01 (Plug half): a DELETE whose backing abort fails transiently must
    # persist a retryable `tus_abort_failed:%` marker on the row (so the Task-1
    # reaper query re-aborts the orphaned multipart) while STILL returning 204 to
    # the client (the cancel is accepted; the cost-leak compensation is the
    # reaper's job). Pre-fix `abort_delete_backing/2` swallows the {:error,_} and
    # returns :ok, so failure_reason stays nil and the orphan leaks forever (RED).
    # -------------------------------------------------------------------------

    test "DELETE persists the tus_abort_failed marker (and still returns 204) when the backing abort fails (CR-01 Plug half)",
         %{mock_opts: opts} do
      {token, session} = mock_create_s3(opts, 100)

      expect(Rindle.StorageMock, :abort_multipart_upload, fn _key, _id, _opts ->
        {:error, :transport}
      end)

      conn = conn(:delete, "/uploads/tus/" <> token) |> TusPlug.call(opts)

      # Client-facing cancel semantics preserved — the reaper compensates.
      assert conn.status == 204

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "aborted"
      # The retryable marker the reaper's like(..., "tus_abort_failed:%") matches.
      assert String.starts_with?(updated.failure_reason, "tus_abort_failed:")
    end

    test "DELETE leaves failure_reason nil on a clean abort (no marker => never re-selected by the reaper)",
         %{mock_opts: opts} do
      {token, session} = mock_create_s3(opts, 100)

      expect(Rindle.StorageMock, :abort_multipart_upload, fn _key, _id, _opts ->
        {:ok, %{}}
      end)

      conn = conn(:delete, "/uploads/tus/" <> token) |> TusPlug.call(opts)

      assert conn.status == 204

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "aborted"
      assert updated.failure_reason == nil
    end
  end

  describe "Plan 04 — polymorphic adapter dispatch (TUS-06/08, RED until Plan 04)" do
    # These specs prove TusPlug routes PATCH/completion through the storage
    # behaviour rather than the hard-wired Local helpers. EXPECTED RED until
    # Plan 04 replaces the Local.tus_part_path/Local.tus_complete calls with
    # adapter.upload_part_stream/5 + adapter.complete_part_stream/4. Today the
    # Plug never touches the adapter for PATCH bytes, so the Mox expectations go
    # unsatisfied -> verify_on_exit! fails (RED).
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup %{root: root} do
      # init/1 calls adapter.capabilities() through Capabilities.require_upload;
      # stub it so the gate passes for the Mox adapter.
      stub(Rindle.StorageMock, :capabilities, fn -> [:tus_upload, :head] end)

      opts =
        TusPlug.init(
          profile: MockTusProfile,
          secret_key_base: @secret_key_base,
          max_size: @max_size,
          root: root
        )

      {:ok, mock_opts: opts}
    end

    # POST through the plug (mock_opts) to mint a signed token, exactly like the
    # create/2 helper does for the Local profile.
    defp mock_create(opts, length \\ 10, upload_metadata \\ "filename Y2xpcC5qcGc=") do
      conn =
        conn(:post, "/uploads/tus")
        |> put_req_header("upload-length", Integer.to_string(length))
        |> put_req_header("upload-metadata", upload_metadata)
        |> TusPlug.call(opts)

      [location] = get_resp_header(conn, "location")
      token = location |> String.split("/") |> List.last()
      {:ok, payload} = Plug.Crypto.verify(@secret_key_base, @tus_url_salt, token)
      {token, payload["session_id"]}
    end

    test "a PATCH dispatches to adapter.upload_part_stream/5 (no Local hard-wiring)", %{
      mock_opts: opts
    } do
      # Length 100 so a 10-byte PATCH advances to offset 10 < length and does NOT
      # trigger completion — this spec isolates the PATCH dispatch from the
      # completion dispatch (which is exercised separately below).
      # The load-bearing expectation: the adapter callback is invoked with the
      # session's upload_key, a drained temp file path, the base offset, the
      # prior part-state map, and call opts.
      expect(Rindle.StorageMock, :upload_part_stream, fn key,
                                                         temp_path,
                                                         base_offset,
                                                         state,
                                                         call_opts ->
        assert is_binary(key)
        assert is_binary(temp_path)
        assert base_offset == 0
        assert is_map(state)
        assert call_opts[:content_type] == "video/mp4"
        {:ok, %{offset: 10}}
      end)

      {token, _sid} =
        mock_create(opts, 100, "filename Y2xpcC5qcGc=,filetype dmlkZW8vbXA0")

      _conn = patch(opts, token, 0, "0123456789")
    end

    test "the final PATCH calls adapter.complete_part_stream/4 then converges into verify_completion",
         %{mock_opts: opts} do
      {token, _sid} = mock_create(opts)

      stub(Rindle.StorageMock, :upload_part_stream, fn _key,
                                                       _temp_path,
                                                       base_offset,
                                                       _state,
                                                       _opts ->
        {:ok, %{offset: base_offset + 10}}
      end)

      # The final PATCH (offset reaches Upload-Length) MUST call the symmetric
      # completion callback polymorphically, not Local.tus_complete.
      expect(Rindle.StorageMock, :complete_part_stream, fn key, _temp_path, state, _opts ->
        assert is_binary(key)
        assert is_map(state)
        {:ok, %{upload_key: key}}
      end)

      # verify_completion/2 is the unchanged trust gate; head/2 backs it.
      stub(Rindle.StorageMock, :head, fn _key, _opts -> {:ok, %{size: 10, content_type: nil}} end)

      _conn = patch(opts, token, 0, "0123456789")
    end
  end

  describe "Plan 03 Task 3 — full tus-js-client-shaped resume contract flow" do
    # Phase 42 proves the tus wire sequence via Plug.Test synthetic conns; the live
    # Node tus-js-client + MinIO proof is Phase 44 (RESEARCH Open Question 3) — the
    # verifier should NOT expect a Node harness here.
    test "POST -> HEAD -> PATCH(partial) -> drop(409) -> HEAD -> PATCH(resume) -> completion -> validating",
         %{root: root} do
      opts = opts_for(root)
      total = 16
      {token, sid} = create(opts, total)

      # 1. HEAD -> offset 0
      assert get_resp_header(head(opts, token), "upload-offset") == ["0"]

      # 2. PATCH the first 8 bytes
      p1 = patch(opts, token, 0, "01234567")
      assert p1.status == 204
      assert get_resp_header(p1, "upload-offset") == ["8"]

      # 3. Simulated network drop: client retries the already-applied chunk at offset 0
      stale = patch(opts, token, 0, "01234567")
      assert stale.status == 409
      assert AdopterRepo.get!(MediaUploadSession, sid).last_known_offset == 8

      # 4. Client re-HEADs for the authoritative offset
      assert get_resp_header(head(opts, token), "upload-offset") == ["8"]

      # 5. PATCH the remaining 8 bytes at offset 8 -> completion
      p2 = patch(opts, token, 8, "89abcdef")
      assert p2.status == 204
      assert get_resp_header(p2, "upload-offset") == ["16"]

      # 6. Convergence into the UNCHANGED verify_completion/2 lane
      session = AdopterRepo.get!(MediaUploadSession, sid)
      assert session.state == "completed"

      asset = AdopterRepo.get!(MediaAsset, session.asset_id)
      assert asset.state in ["validating", "ready"]
      assert asset.byte_size == total

      # 7. The reassembled file landed at the final key; the tmp part is gone
      final_path = Local.path_for(session.upload_key, root: root)
      assert File.exists?(final_path)
      assert File.stat!(final_path).size == total
      assert File.read!(final_path) == "0123456789abcdef"
      refute File.exists?(Local.tus_part_path(sid, root: root))
    end
  end

  describe "Phase 57 — Checksum & Defer Length" do
    test "POST with Upload-Defer-Length: 1 creates a session without length" do
      conn =
        conn(:post, "/uploads/tus")
        |> put_req_header("upload-defer-length", "1")
        |> put_req_header("upload-metadata", "filename Y2xpcC5qcGc=")
        |> route()

      assert conn.status == 201
      [location] = get_resp_header(conn, "location")
      token = location |> String.split("/") |> List.last()

      {:ok, payload} = Plug.Crypto.verify(@secret_key_base, @tus_url_salt, token)
      assert payload["length"] == "deferred"

      session = AdopterRepo.get!(MediaUploadSession, payload["session_id"])
      assert session.upload_length == nil
    end

    test "PATCH sets deferred length and proceeds", %{root: root} do
      opts = opts_for(root)

      conn =
        conn(:post, "/uploads/tus")
        |> put_req_header("upload-defer-length", "1")
        |> put_req_header("upload-metadata", "filename Y2xpcC5qcGc=")
        |> TusPlug.call(opts)

      [location] = get_resp_header(conn, "location")
      token = location |> String.split("/") |> List.last()

      {:ok, payload} = Plug.Crypto.verify(@secret_key_base, @tus_url_salt, token)
      sid = payload["session_id"]

      p1 =
        conn(:patch, "/uploads/tus/" <> token, "01234")
        |> put_req_header("content-type", "application/offset+octet-stream")
        |> put_req_header("upload-offset", "0")
        |> put_req_header("upload-length", "10")
        |> TusPlug.call(opts)

      assert p1.status == 204
      assert get_resp_header(p1, "upload-offset") == ["5"]

      session = AdopterRepo.get!(MediaUploadSession, sid)
      assert session.upload_length == 10
    end

    test "PATCH fails if deferred length is missing", %{root: root} do
      opts = opts_for(root)

      conn =
        conn(:post, "/uploads/tus")
        |> put_req_header("upload-defer-length", "1")
        |> put_req_header("upload-metadata", "filename Y2xpcC5qcGc=")
        |> TusPlug.call(opts)

      [location] = get_resp_header(conn, "location")
      token = location |> String.split("/") |> List.last()

      p1 =
        conn(:patch, "/uploads/tus/" <> token, "01234")
        |> put_req_header("content-type", "application/offset+octet-stream")
        |> put_req_header("upload-offset", "0")
        |> TusPlug.call(opts)

      assert p1.status == 400
    end

    test "PATCH verifies valid sha256 checksum", %{root: root} do
      opts = opts_for(root)
      {token, _sid} = create(opts, 10)

      body = "0123456789"
      hash = :crypto.hash(:sha256, body) |> Base.encode64()

      p1 =
        conn(:patch, "/uploads/tus/" <> token, body)
        |> put_req_header("content-type", "application/offset+octet-stream")
        |> put_req_header("upload-offset", "0")
        |> put_req_header("upload-checksum", "sha256 #{hash}")
        |> TusPlug.call(opts)

      assert p1.status == 204
      assert get_resp_header(p1, "upload-offset") == ["10"]
    end

    test "PATCH rejects invalid sha256 checksum with 460", %{root: root} do
      opts = opts_for(root)
      {token, sid} = create(opts, 10)

      body = "0123456789"
      hash = :crypto.hash(:sha256, "wrong data") |> Base.encode64()

      p1 =
        conn(:patch, "/uploads/tus/" <> token, body)
        |> put_req_header("content-type", "application/offset+octet-stream")
        |> put_req_header("upload-offset", "0")
        |> put_req_header("upload-checksum", "sha256 #{hash}")
        |> TusPlug.call(opts)

      assert p1.status == 460
      # Offset should not advance
      session = AdopterRepo.get!(MediaUploadSession, sid)
      assert session.last_known_offset == 0
    end
  end

  describe "Phase 58 - Concatenation" do
    test "POST with Upload-Concat: partial creates session with is_partial: true", %{root: root} do
      opts = opts_for(root)
      
      conn =
        conn(:post, "/uploads/tus")
        |> put_req_header("upload-concat", "partial")
        |> put_req_header("upload-length", "10")
        |> put_req_header("upload-metadata", "filename Y2xpcC5qcGc=")
        |> TusPlug.call(opts)

      assert conn.status == 201
      [location] = get_resp_header(conn, "location")
      token = location |> String.split("/") |> List.last()

      {:ok, payload} = Plug.Crypto.verify(@secret_key_base, @tus_url_salt, token)
      sid = payload["session_id"]
      
      session = AdopterRepo.get!(MediaUploadSession, sid)
      assert session.multipart_parts["is_partial"] == true
    end

    test "POST with Upload-Concat: final successfully concatenates partial uploads", %{root: root} do
      opts = opts_for(root)

      # Create partial 1
      p1 = conn(:post, "/uploads/tus")
           |> put_req_header("upload-concat", "partial")
           |> put_req_header("upload-length", "4")
           |> TusPlug.call(opts)
      [l1] = get_resp_header(p1, "location")
      t1 = l1 |> String.split("/") |> List.last()
      patch(opts, t1, 0, "1234")

      # Create partial 2
      p2 = conn(:post, "/uploads/tus")
           |> put_req_header("upload-concat", "partial")
           |> put_req_header("upload-length", "4")
           |> TusPlug.call(opts)
      [l2] = get_resp_header(p2, "location")
      t2 = l2 |> String.split("/") |> List.last()
      patch(opts, t2, 0, "5678")

      # Final concat
      final = conn(:post, "/uploads/tus")
              |> put_req_header("upload-concat", "final;#{l1} #{l2}")
              |> TusPlug.call(opts)

      assert final.status == 201
      [location] = get_resp_header(final, "location")
      token = location |> String.split("/") |> List.last()

      {:ok, payload} = Plug.Crypto.verify(@secret_key_base, @tus_url_salt, token)
      sid = payload["session_id"]

      session = AdopterRepo.get!(MediaUploadSession, sid)
      assert session.upload_length == 8
      assert session.state == "completed"

      asset = AdopterRepo.get!(MediaAsset, session.asset_id)
      assert asset.byte_size == 8

      final_path = Local.path_for(session.upload_key, root: root)
      assert File.read!(final_path) == "12345678"
    end

    test "POST with Upload-Concat: final fails if a partial is incomplete", %{root: root} do
      opts = opts_for(root)

      # Create incomplete partial
      p1 = conn(:post, "/uploads/tus")
           |> put_req_header("upload-concat", "partial")
           |> put_req_header("upload-length", "4")
           |> TusPlug.call(opts)
      [l1] = get_resp_header(p1, "location")

      final = conn(:post, "/uploads/tus")
              |> put_req_header("upload-concat", "final;#{l1}")
              |> TusPlug.call(opts)

      assert final.status == 400
    end
    
    test "POST with Upload-Concat: final fails with invalid URL", %{root: root} do
      opts = opts_for(root)

      final = conn(:post, "/uploads/tus")
              |> put_req_header("upload-concat", "final;http://example.com/invalid_token")
              |> TusPlug.call(opts)

      assert final.status == 400
    end
  end
end
