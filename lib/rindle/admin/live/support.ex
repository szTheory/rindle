if Code.ensure_loaded?(Phoenix.LiveView) and Code.ensure_loaded?(Phoenix.PubSub) do
  defmodule Rindle.Admin.Live.Support do
    @moduledoc false

    @default_base_path "/admin/rindle"
    @admin_lifecycle_topic "rindle:admin:lifecycle"

    def assign_admin_context(socket, %{"rindle_admin" => config}) when is_map(config) do
      Phoenix.Component.assign(
        socket,
        :admin_base_path,
        normalize_base_path(Map.get(config, "base_path"))
      )
    end

    def assign_admin_context(socket, _session) do
      Phoenix.Component.assign(socket, :admin_base_path, @default_base_path)
    end

    def subscribe(socket, topic) when is_binary(topic) do
      if Phoenix.LiveView.connected?(socket) do
        Phoenix.PubSub.subscribe(pubsub_server(), topic)
      else
        :ok
      end
    end

    def subscribe_admin_lifecycle(socket), do: subscribe(socket, @admin_lifecycle_topic)

    def admin_lifecycle_topic, do: @admin_lifecycle_topic

    def pubsub_server do
      Application.get_env(:rindle, :pubsub_server, Rindle.PubSub)
    end

    defp normalize_base_path(path) when is_binary(path) and path != "" do
      if String.starts_with?(path, "/"), do: path, else: "/" <> path
    end

    defp normalize_base_path(_path), do: @default_base_path
  end
end
