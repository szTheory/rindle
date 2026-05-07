defmodule Rindle.Delivery.WebhookBodyReaderTest do
  use ExUnit.Case, async: true

  alias Plug.Test
  alias Rindle.Delivery.WebhookBodyReader

  describe "read_body/2" do
    test "returns body and caches in assigns for small payload" do
      body = ~s({"hello":"world"})
      conn = Test.conn(:post, "/", body)

      assert {:ok, ^body, conn} = WebhookBodyReader.read_body(conn, [])
      assert conn.assigns[:raw_body] == [body]
    end

    test "drains chunked reads (body > 8KB default chunk size)" do
      body = String.duplicate("x", 100_000)
      conn = Test.conn(:post, "/", body)

      assert {:ok, ^body, conn} = WebhookBodyReader.read_body(conn, [])
      assert WebhookBodyReader.raw_body(conn) == body
    end

    test "rejects body just over 1 MiB" do
      body = String.duplicate("x", 1_048_577)
      conn = Test.conn(:post, "/", body)

      assert {:error, :too_large} = WebhookBodyReader.read_body(conn, [])
    end

    test "accepts body exactly at 1 MiB" do
      body = String.duplicate("x", 1_048_576)
      conn = Test.conn(:post, "/", body)

      assert {:ok, ^body, _conn} = WebhookBodyReader.read_body(conn, [])
    end
  end

  describe "raw_body/1" do
    test "returns nil when assign is missing" do
      conn = Test.conn(:post, "/", "")
      assert WebhookBodyReader.raw_body(conn) == nil
    end

    test "returns single binary when list has one element" do
      conn = Test.conn(:post, "/", "") |> Plug.Conn.assign(:raw_body, ["one"])
      assert WebhookBodyReader.raw_body(conn) == "one"
    end

    test "returns reversed iodata-joined binary for multi-chunk list" do
      conn =
        Test.conn(:post, "/", "")
        |> Plug.Conn.assign(:raw_body, ["c", "b", "a"])

      # most-recent-first → reverse to original order: "a" "b" "c"
      assert WebhookBodyReader.raw_body(conn) == "abc"
    end
  end
end
