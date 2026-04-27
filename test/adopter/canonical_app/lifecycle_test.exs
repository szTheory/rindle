defmodule Rindle.Adopter.CanonicalApp.LifecycleTest do
  @moduledoc """
  Canonical adopter lane: full lifecycle exercised by an adopter-shaped
  consumer of Rindle. Runs against MinIO (via Rindle.Storage.S3) and the
  shared test PostgreSQL.

  This file is the source of truth for `guides/getting_started.md` (D-16).
  The snippet shown in that guide must match the public API calls below;
  drift between this file and the guide breaks DOC-01 acceptance.

  # TODO(adopter-repo): `Rindle.Repo` is hard-coded inside `lib/rindle.ex`
  # at lines 91, 101, 123, 130, and 211 (in `attach/4`, `detach/3`, and
  # `upload/3`). Per D-09 in `.planning/phases/05-ci-1-0-readiness/05-CONTEXT.md`
  # and Open Question 1 in `05-RESEARCH.md`, this leak is documented as a
  # v1.1 follow-up: introduce `config :rindle, :repo` runtime resolution so
  # the public facade respects the adopter-repo-first stance (D-01 in
  # `01-CONTEXT.md`). The adopter test currently still funnels through
  # `Rindle.Repo` via the shared Sandbox-wrapped test DB (Assumption A3 in
  # `05-RESEARCH.md`); this works in CI but leaves the runtime contract
  # unenforced. Track in v1.1.
  """

  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo

  alias Ecto.Adapters.SQL.Sandbox
  alias Rindle.Adopter.CanonicalApp.Profile, as: AdopterProfile
  alias Rindle.Domain.{MediaAsset, MediaVariant}
  alias Rindle.Upload.Broker
  alias Rindle.Workers.{ProcessVariant, PromoteAsset, PurgeStorage}

  @moduletag :adopter

  # 1×1 transparent PNG — matches the fixture used in the proxied integration
  # test (test/rindle/upload/lifecycle_integration_test.exs L9-13).
  @png_1x1 <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
             0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00,
             0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x08,
             0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0x44, 0x74,
             0x06, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82>>

  defmodule Owner do
    @moduledoc false
    defstruct [:id]
  end

  setup do
    # Start :inets so :httpc is available for the presigned PUT step.
    # In some Elixir releases :inets is started by default; this call is
    # idempotent and ensures we don't crash if it isn't.
    case :inets.start() do
      :ok -> :ok
      {:error, {:already_started, :inets}} -> :ok
    end

    # Start the adopter Repo (Sandbox-wrapped). Uses the same test DB as
    # Rindle.Repo per A3 in 05-RESEARCH.md. start_supervised handles
    # cleanup automatically on test exit.
    case start_supervised(Rindle.Adopter.CanonicalApp.Repo) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    Sandbox.checkout(Rindle.Adopter.CanonicalApp.Repo)
    Sandbox.mode(Rindle.Adopter.CanonicalApp.Repo, {:shared, self()})

    # Configure the S3 adapter for MinIO from env vars (CI sets these; locally
    # they default to a localhost MinIO at :9000 with the published default
    # credentials).
    minio_url = System.get_env("RINDLE_MINIO_URL", "http://localhost:9000")
    bucket = System.get_env("RINDLE_MINIO_BUCKET", "rindle-test")
    access_key = System.get_env("RINDLE_MINIO_ACCESS_KEY", "minioadmin")
    secret_key = System.get_env("RINDLE_MINIO_SECRET_KEY", "minioadmin")
    region = System.get_env("RINDLE_MINIO_REGION", "us-east-1")

    %URI{host: host, port: port, scheme: scheme} = URI.parse(minio_url)

    previous_s3 = Application.get_env(:rindle, Rindle.Storage.S3)
    previous_ex_aws = Application.get_env(:ex_aws, :s3)

    Application.put_env(:rindle, Rindle.Storage.S3, bucket: bucket)

    Application.put_env(:ex_aws, :s3,
      scheme: "#{scheme}://",
      host: host,
      port: port,
      region: region,
      access_key_id: access_key,
      secret_access_key: secret_key
    )

    on_exit(fn ->
      case previous_s3 do
        nil -> Application.delete_env(:rindle, Rindle.Storage.S3)
        value -> Application.put_env(:rindle, Rindle.Storage.S3, value)
      end

      case previous_ex_aws do
        nil -> Application.delete_env(:ex_aws, :s3)
        value -> Application.put_env(:ex_aws, :s3, value)
      end
    end)

    :ok
  end

  describe "canonical adopter lifecycle" do
    test "direct upload through MinIO promotes asset, generates ready variant, and serves signed URL" do
      # ── Step 1: Adopter initiates an upload session ──────────────────────
      {:ok, session} = Broker.initiate_session(AdopterProfile, filename: "adopter.png")
      assert session.state == "initialized"

      # ── Step 2: Adopter requests a presigned PUT URL ─────────────────────
      {:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)
      assert signed.state == "signed"
      assert is_binary(presigned.url)
      assert String.starts_with?(presigned.url, "http")

      # ── Step 3: Client PUTs the file BYTES to the presigned URL ──────────
      # Per Blocker 5 / D-08: this MUST exercise the actual presigned PUT
      # path, NOT bypass it via Rindle.Storage.S3.store/3. The adopter's
      # production app does an HTTPS PUT directly from the client to the
      # presigned URL; we mirror that here using Erlang's :httpc.
      :ok = put_to_presigned_url(presigned.url, @png_1x1)

      # ── Step 4: Verify completion — transitions session, promotes asset ──
      {:ok, %{session: completed, asset: asset}} = Broker.verify_completion(session.id)
      assert completed.state == "completed"
      assert asset.state == "validating"
      assert_enqueued(worker: PromoteAsset, args: %{"asset_id" => asset.id})

      # ── Step 5: Run promotion synchronously ──────────────────────────────
      assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

      asset = Rindle.Repo.get!(MediaAsset, asset.id)
      assert asset.state in ["available", "processing", "ready"]

      # ── Step 6: Run any enqueued ProcessVariant jobs ─────────────────────
      # ProcessVariant takes %{"asset_id", "variant_name"} (NOT variant_id);
      # see lib/rindle/workers/process_variant.ex:14.
      variants =
        Rindle.Repo.all(Ecto.Query.from(v in MediaVariant, where: v.asset_id == ^asset.id))

      assert variants != []

      for variant <- variants do
        assert :ok =
                 perform_job(ProcessVariant, %{
                   "asset_id" => asset.id,
                   "variant_name" => variant.name
                 })
      end

      # Reload variants to confirm they reached :ready.
      ready_variants =
        Rindle.Repo.all(Ecto.Query.from(v in MediaVariant, where: v.asset_id == ^asset.id))

      assert Enum.all?(ready_variants, &(&1.state == "ready"))

      # ── Step 7: Adopter requests a signed delivery URL ───────────────────
      {:ok, signed_url} = Rindle.Delivery.url(AdopterProfile, asset.storage_key)
      assert is_binary(signed_url)
      assert String.contains?(signed_url, asset.storage_key)

      # ── Step 8: Adopter attaches the asset to an owner ───────────────────
      # Public signature (lib/rindle.ex:63):
      #   Rindle.attach(asset_or_id, owner, slot, _opts \\ [])
      #   → {:ok, %MediaAttachment{}} | {:error, term()}
      owner = %Owner{id: Ecto.UUID.generate()}
      {:ok, _attachment} = Rindle.attach(asset.id, owner, "primary")

      # ── Step 9: Adopter detaches and triggers async purge ────────────────
      # Public signature (lib/rindle.ex:112):
      #   Rindle.detach(owner, slot, _opts \\ [])
      #   → :ok | {:error, term()}
      assert :ok = Rindle.detach(owner, "primary")
      assert_enqueued(worker: PurgeStorage, args: %{"asset_id" => asset.id})
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # Helpers
  # ─────────────────────────────────────────────────────────────────────────

  # PUT the body to the presigned URL using Erlang's :httpc (no extra dep).
  # Per Blocker 5 / D-08: the adopter-facing path uses HTTP PUT to the
  # presigned URL the broker issued; we MUST exercise that here, not
  # bypass via Rindle.Storage.S3.store/3.
  #
  # If the adopter lane discovers MinIO presigned PUT semantics differ
  # enough to require workarounds (e.g., specific signature-version
  # header behaviors), document the gap explicitly in the SUMMARY as
  # "DEFERRED to v1.1: full presigned PUT verification requires X" rather
  # than silently falling back to the S3 adapter store path.
  defp put_to_presigned_url(presigned_url, body)
       when is_binary(presigned_url) and is_binary(body) do
    url_charlist = String.to_charlist(presigned_url)
    headers = []
    content_type = ~c"application/octet-stream"
    request = {url_charlist, headers, content_type, body}

    case :httpc.request(:put, request, [], []) do
      {:ok, {{_http_version, status, _reason}, _resp_headers, _resp_body}}
      when status in 200..299 ->
        :ok

      {:ok, {{_http_version, status, reason}, _resp_headers, resp_body}} ->
        raise "Presigned PUT failed with status #{status} #{reason}: #{inspect(resp_body)}"

      {:error, reason} ->
        raise "Presigned PUT to MinIO failed: #{inspect(reason)}"
    end
  end
end
