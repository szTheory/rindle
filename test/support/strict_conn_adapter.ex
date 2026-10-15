defmodule Rindle.StrictConnAdapter do
  @moduledoc false
  # Wraps `Plug.Adapters.Test.Conn` with the stale-conn check Bandit >= 1.13
  # enforces: every adapter call must use the conn most recently returned by
  # `read_body/2` (or a send). A plug that reads the body and then responds on
  # the pre-read conn raises here, as it does over a real Bandit socket.
  #
  #     conn(:patch, "/path", body) |> Rindle.StrictConnAdapter.wrap() |> MyPlug.call(opts)

  @behaviour Plug.Conn.Adapter

  alias Plug.Adapters.Test.Conn, as: TestConn

  @spec wrap(Plug.Conn.t()) :: Plug.Conn.t()
  def wrap(%Plug.Conn{adapter: {TestConn, inner}} = conn) do
    key = {__MODULE__, make_ref()}
    Process.put(key, 0)
    %{conn | adapter: {__MODULE__, {inner, key, 0}}}
  end

  @impl true
  def send_resp(state, status, headers, body) do
    {inner, key, gen} = validate!(state)
    {:ok, sent, inner} = TestConn.send_resp(inner, status, headers, body)
    {:ok, sent, bump(inner, key, gen)}
  end

  @impl true
  def send_file(state, status, headers, path, offset, length) do
    {inner, key, gen} = validate!(state)
    {:ok, sent, inner} = TestConn.send_file(inner, status, headers, path, offset, length)
    {:ok, sent, bump(inner, key, gen)}
  end

  @impl true
  def send_chunked(state, status, headers) do
    {inner, key, gen} = validate!(state)
    {:ok, sent, inner} = TestConn.send_chunked(inner, status, headers)
    {:ok, sent, bump(inner, key, gen)}
  end

  @impl true
  def chunk(state, body) do
    {inner, key, gen} = validate!(state)

    case TestConn.chunk(inner, body) do
      {:ok, sent, inner} -> {:ok, sent, bump(inner, key, gen)}
      other -> other
    end
  end

  @impl true
  def read_req_body(state, opts) do
    {inner, key, gen} = validate!(state)

    case TestConn.read_req_body(inner, opts) do
      {:ok, data, inner} -> {:ok, data, bump(inner, key, gen)}
      {:more, data, inner} -> {:more, data, bump(inner, key, gen)}
      {:error, _} = error -> error
    end
  end

  @impl true
  def inform({inner, _key, _gen}, status, headers), do: TestConn.inform(inner, status, headers)

  @impl true
  def upgrade({inner, key, gen}, protocol, opts) do
    case TestConn.upgrade(inner, protocol, opts) do
      {:ok, inner} -> {:ok, {inner, key, gen}}
      other -> other
    end
  end

  @impl true
  def push({inner, _key, _gen}, path, headers), do: TestConn.push(inner, path, headers)

  @impl true
  def get_peer_data({inner, _key, _gen}), do: TestConn.get_peer_data(inner)

  @impl true
  def get_sock_data({inner, _key, _gen}), do: TestConn.get_sock_data(inner)

  @impl true
  def get_ssl_data({inner, _key, _gen}), do: TestConn.get_ssl_data(inner)

  @impl true
  def get_http_protocol({inner, _key, _gen}), do: TestConn.get_http_protocol(inner)

  defp validate!({_inner, key, gen} = state) do
    current = Process.get(key)

    if gen != current do
      raise "Stale conn passed to a Plug.Conn function (generation #{gen}, current #{current})"
    end

    state
  end

  defp bump(inner, key, gen) do
    Process.put(key, gen + 1)
    {inner, key, gen + 1}
  end
end
