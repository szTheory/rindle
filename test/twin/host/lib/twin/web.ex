defmodule Twin.Router do
  use Plug.Router

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["*/*"],
    body_reader: {Rindle.Delivery.WebhookBodyReader, :read_body, []},
    json_decoder: Jason
  )

  plug(:match)
  plug(:dispatch)

  get "/health" do
    send_resp(conn, 200, Jason.encode!(Twin.Tracer.health()))
  end

  forward("/uploads/tus",
    to: Rindle.Upload.TusPlug,
    init_opts: [
      profile: Twin.Profile,
      secret_key_base: String.duplicate("twin-disposable-local-only-", 4)
    ]
  )

  forward("/webhooks/mux",
    to: Rindle.Delivery.WebhookPlug,
    init_opts: [
      provider: Rindle.Streaming.Provider.Mux,
      secrets: ["twin-local-webhook-secret"]
    ]
  )

  post "/video/v1/assets" do
    result = Twin.Tracer.fixture_create(conn)
    conn |> put_resp_content_type("application/json") |> send_resp(201, Jason.encode!(result))
  end

  delete "/video/v1/assets/:provider_id" do
    :ok = Twin.Tracer.fixture_delete(conn, provider_id)
    conn |> put_resp_content_type("application/json") |> send_resp(200, "{}")
  end

  post "/:operation" do
    if Plug.Conn.get_req_header(conn, "x-twin-control") == [System.fetch_env!("TWIN_SECRET")] do
      {:ok, body, conn} = Plug.Conn.read_body(conn, length: 4096, read_timeout: 5000)
      result = Twin.Tracer.execute(operation, Jason.decode!(body))
      send_resp(conn, 200, Jason.encode!(result))
    else
      send_resp(conn, 403, "{}")
    end
  end

  match _ do
    send_resp(conn, 404, "{}")
  end
end

defmodule Twin.Endpoint do
  use Phoenix.Endpoint, otp_app: :twin
  plug(Twin.Router)
end
