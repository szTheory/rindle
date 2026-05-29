# Script for populating the adoption demo database.
#
#     mix run priv/repo/seeds.exs
#
alias AdoptionDemo.{Accounts, Media, RindleProfile}
alias Rindle.Upload.Broker

ensure_inets = fn ->
  case :inets.start() do
    :ok -> :ok
    {:error, {:already_started, :inets}} -> :ok
  end
end

put_bytes = fn url, body ->
  request = {String.to_charlist(url), [], ~c"image/png", body}

  case :httpc.request(:put, request, [], []) do
    {:ok, {{_version, status, _reason}, _headers, _body}} when status in 200..299 ->
      :ok

    other ->
      {:error, other}
  end
end

:ok = ensure_inets.()

for {email, name} <- [
      {"alice@acme.test", "Alice Acme"},
      {"bob@globex.test", "Bob Globex"},
      {"ops@acme.test", "Ops Operator"}
    ] do
  Accounts.seed_user!(%{email: email, name: name})
end

alice = Accounts.list_users() |> Enum.find(&(&1.email == "alice@acme.test"))
avatar_path = Path.join(:code.priv_dir(:adoption_demo), "fixtures/avatar.png")

if alice && File.exists?(avatar_path) do
  png = File.read!(avatar_path)

  with {:ok, session} <- Broker.initiate_session(RindleProfile, filename: "avatar.png"),
       {:ok, %{presigned: presigned}} <- Broker.sign_url(session.id),
       :ok <- put_bytes.(presigned.url, png),
       {:ok, %{asset: asset}} <- Broker.verify_completion(session.id) do
    Media.attach!(alice, asset.id, :avatar)
    IO.puts("Seeded avatar for #{alice.email}")
  else
    error -> IO.warn("Could not seed avatar: #{inspect(error)}")
  end
end
