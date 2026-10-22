defmodule Twin.Router do
  use Plug.Router
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
