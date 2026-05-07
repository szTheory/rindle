defmodule Rindle.Streaming.Provider.Mux.Event do
  @moduledoc false

  # Pure-Elixir webhook event normalizer. NOT wrapped in an optional-dep guard
  # (Pitfall 4) — this module references no Mux SDK symbols, so it is safe to
  # compile in adopter envs without `:mux` loaded. Phase 35 wires this into
  # `Rindle.Delivery.WebhookPlug`; Phase 34 only ships the callback path.

  @doc """
  Normalize a Mux webhook event JSON map (already `Jason.decode!/1`-parsed)
  into the locked Phase 33 `provider_event` shape (see
  `Rindle.Streaming.Provider.@type provider_event`).

  Returns `{:error, :provider_webhook_invalid}` for malformed payloads.

  ## `video.upload.asset_created` typed branch (D-29)

  The `video.upload.asset_created` event ships a different `data` layout from
  the asset-scoped events: `data.id` is the UPLOAD identifier (NOT the
  asset id) and `data.asset_id` is the asset id. Without the typed branch
  below, the generic clause would mis-attribute `data.id` to
  `provider_asset_id` — silent data corruption when Phase 37 enables direct
  creator uploads. Phase 35 lands the typed branch as forward-compat; the
  Phase 35 worker no-ops on `:upload_asset_created` (D-27).
  """
  @spec normalize(map()) :: {:ok, map()} | {:error, term()}
  def normalize(%{"type" => "video.upload.asset_created", "data" => data} = raw)
      when is_map(data) do
    {:ok,
     %{
       type: :upload_asset_created,
       # NB: `data.asset_id` is the asset id; `data.id` is the upload id.
       provider_asset_id: Map.get(data, "asset_id"),
       upload_id: Map.get(data, "id"),
       playback_ids: [],
       state: nil,
       occurred_at: parse_occurred_at(Map.get(raw, "created_at")),
       raw: raw
     }}
  end

  def normalize(%{"type" => type, "data" => data} = raw) when is_map(data) do
    {:ok,
     %{
       type: normalize_type(type),
       provider_asset_id: Map.get(data, "id"),
       playback_ids: extract_playback_ids(data),
       state: normalize_state(Map.get(data, "status")),
       occurred_at: parse_occurred_at(Map.get(raw, "created_at")),
       raw: raw
     }}
  end

  def normalize(_raw), do: {:error, :provider_webhook_invalid}

  defp normalize_type("video.asset.ready"), do: :ready
  defp normalize_type("video.asset.errored"), do: :errored
  defp normalize_type("video.asset.created"), do: :created
  defp normalize_type("video.asset.deleted"), do: :deleted
  defp normalize_type("video.upload.asset_created"), do: :upload_asset_created
  defp normalize_type(other) when is_binary(other), do: :unknown
  defp normalize_type(_), do: :unknown

  # Mux uses "preparing" while transcoding; Phase 33 FSM uses "processing".
  defp normalize_state("preparing"), do: "processing"
  defp normalize_state("ready"), do: "ready"
  defp normalize_state("errored"), do: "errored"
  defp normalize_state(_), do: nil

  # BL-03 fix: `Map.get(data, "playback_ids", [])` returns `nil` (NOT the
  # default) when the key is present with an explicit null value. Mux sends
  # `"playback_ids": null` on `video.asset.created` webhooks (the very first
  # event that fires before transcoding completes), so the previous shape
  # would crash `Enum.map(nil, _)` with `Protocol.UndefinedError` on every
  # real-world `video.asset.created` payload. Mirror the adapter's
  # `extract_playback_id_strings/1` shape: pattern-match `is_list(list)` and
  # fall through to `[]` for `nil`/missing/non-list values.
  defp extract_playback_ids(data) do
    case Map.get(data, "playback_ids") do
      list when is_list(list) ->
        list
        |> Enum.map(fn
          %{"id" => id} -> id
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp parse_occurred_at(nil), do: nil

  defp parse_occurred_at(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp parse_occurred_at(_), do: nil
end
