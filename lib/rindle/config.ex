defmodule Rindle.Config do
  @moduledoc """
  Centralized accessors for foundational runtime configuration.
  """

  @spec queue_name() :: atom()
  def queue_name do
    Application.fetch_env!(:rindle, :queue)
  end

  @spec repo() :: module()
  def repo do
    Application.get_env(:rindle, :repo, Rindle.Repo)
  end

  @spec signed_url_ttl_seconds() :: pos_integer()
  def signed_url_ttl_seconds do
    Application.get_env(:rindle, :signed_url_ttl_seconds, 900)
  end

  @spec upload_session_ttl_seconds() :: pos_integer()
  def upload_session_ttl_seconds do
    Application.get_env(:rindle, :upload_session_ttl_seconds, 86_400)
  end
end
