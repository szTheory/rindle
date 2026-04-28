defmodule Rindle.Config.ConfigTest do
  use ExUnit.Case, async: false

  test "returns queue and ttl defaults from application config" do
    assert :rindle == Rindle.Config.queue_name()
    assert 900 == Rindle.Config.signed_url_ttl_seconds()
    assert 86_400 == Rindle.Config.upload_session_ttl_seconds()
  end

  test "supports per-test configuration overrides" do
    previous_queue = Application.get_env(:rindle, :queue)
    previous_signed_ttl = Application.get_env(:rindle, :signed_url_ttl_seconds)
    previous_upload_ttl = Application.get_env(:rindle, :upload_session_ttl_seconds)
    previous_repo = Application.get_env(:rindle, :repo)

    on_exit(fn ->
      restore_env(:queue, previous_queue)
      restore_env(:signed_url_ttl_seconds, previous_signed_ttl)
      restore_env(:upload_session_ttl_seconds, previous_upload_ttl)
      restore_env(:repo, previous_repo)
    end)

    Application.put_env(:rindle, :queue, :rindle_override)
    Application.put_env(:rindle, :signed_url_ttl_seconds, 1200)
    Application.put_env(:rindle, :upload_session_ttl_seconds, 43_200)

    assert :rindle_override == Rindle.Config.queue_name()
    assert 1200 == Rindle.Config.signed_url_ttl_seconds()
    assert 43_200 == Rindle.Config.upload_session_ttl_seconds()
  end

  test "repo/0 returns the configured repo module" do
    previous_repo = Application.get_env(:rindle, :repo)

    on_exit(fn ->
      restore_env(:repo, previous_repo)
    end)

    Application.put_env(:rindle, :repo, Rindle.Adopter.CanonicalApp.Repo)

    assert Rindle.Adopter.CanonicalApp.Repo == Rindle.Config.repo()
  end

  test "repo/0 falls back to the harness default when unset" do
    previous_repo = Application.get_env(:rindle, :repo)

    on_exit(fn ->
      restore_env(:repo, previous_repo)
    end)

    Application.delete_env(:rindle, :repo)

    assert Rindle.Repo == Rindle.Config.repo()
  end

  defp restore_env(key, nil), do: Application.delete_env(:rindle, key)
  defp restore_env(key, value), do: Application.put_env(:rindle, key, value)
end
