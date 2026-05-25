defmodule Rindle.Config do
  @moduledoc false

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

  @spec profile_modules() :: [module()]
  def profile_modules do
    configured =
      Application.get_env(:rindle, :profiles, [])
      |> Enum.filter(&profile_module?/1)

    discovered =
      :application.loaded_applications()
      |> Enum.flat_map(fn {app, _description, _version} ->
        Application.spec(app, :modules) || []
      end)
      |> Enum.filter(&profile_module?/1)

    (configured ++ discovered)
    |> Enum.uniq()
  end

  @spec local_playback_route() :: keyword() | nil
  def local_playback_route do
    case Application.get_env(:rindle, :local_playback_route) do
      route when is_list(route) -> route
      route when is_map(route) -> Enum.to_list(route)
      _ -> nil
    end
  end

  @spec migrations_path() :: String.t()
  def migrations_path do
    Application.app_dir(:rindle, "priv/repo/migrations")
  end

  @spec tus_resume_authorizer() :: module() | nil
  def tus_resume_authorizer do
    case Application.get_env(:rindle, :tus_resume_authorizer) do
      module when is_atom(module) -> module
      _ -> nil
    end
  end

  @spec tus_profiles() :: [module()]
  def tus_profiles do
    Application.get_env(:rindle, :tus_profiles, [])
    |> List.wrap()
    |> Enum.filter(&profile_module?/1)
  end

  defp profile_module?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and
      function_exported?(module, :__rindle_profile__, 0) and
      function_exported?(module, :variants, 0)
  end

  defp profile_module?(_module), do: false
end
