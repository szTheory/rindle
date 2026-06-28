defmodule Rindle.Config do
  @moduledoc false

  @repo_override_key {__MODULE__, :repo_override}

  @spec queue_name() :: atom()
  def queue_name do
    Application.fetch_env!(:rindle, :queue)
  end

  @spec repo() :: module()
  def repo do
    with nil <- repo_override(self()) do
      Application.get_env(:rindle, :repo, Rindle.Repo)
    end
  end

  # Test-only seam (no global state). Sets/clears the per-process repo override
  # read by repo/0; never used by production code.
  @doc false
  @spec put_repo_override(module()) :: module() | nil
  def put_repo_override(mod), do: Process.put(@repo_override_key, mod)

  @doc false
  @spec delete_repo_override() :: module() | nil
  def delete_repo_override, do: Process.delete(@repo_override_key)

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

  # Walk self() then the $callers chain (Task/async, Oban inline) so a repo override
  # set in the test process is visible to processes it spawned. The walk runs only when
  # an override is present; with no override the production path is a single Process.get
  # returning nil then the unchanged Application.get_env fallback above.
  defp repo_override(pid) do
    case process_get(pid, @repo_override_key) do
      nil -> caller_repo_override(pid)
      mod -> mod
    end
  end

  defp caller_repo_override(pid) do
    pid
    |> process_get(:"$callers")
    |> List.wrap()
    |> Enum.find_value(fn caller -> caller != pid && repo_override(caller) end)
  end

  defp process_get(pid, key) when pid == self(), do: Process.get(key)

  defp process_get(pid, key) do
    # The override key is a tuple ({Rindle.Config, :repo_override}), so the raw process
    # dictionary cannot be read with Keyword.get/3 (its key must be an atom) — use a
    # tuple-safe keyfind over the {key, value} pairs Process.info/2 returns.
    case Process.info(pid, :dictionary) do
      {:dictionary, dict} ->
        case List.keyfind(dict, key, 0) do
          {^key, value} -> value
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp profile_module?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and
      function_exported?(module, :__rindle_profile__, 0) and
      function_exported?(module, :variants, 0)
  end

  defp profile_module?(_module), do: false
end
