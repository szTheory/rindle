defmodule Rindle.Streaming.Provider.Mux.Event do
  @moduledoc false

  # Pure-Elixir webhook event normalizer. NOT wrapped in an optional-dep guard:
  # this module references no Mux SDK symbols, so it is safe to compile in
  # adopter environments without `:mux` loaded. `Rindle.Delivery.WebhookPlug`
  # uses it at the webhook boundary.

  @doc """
  Normalize a Mux webhook event JSON map (already `Jason.decode!/1`-parsed)
  into Rindle's `provider_event` shape (see
  `Rindle.Streaming.Provider.@type provider_event`).

  Returns `{:error, :provider_webhook_invalid}` for malformed payloads.

  ## `video.upload.asset_created` typed branch

  The `video.upload.asset_created` event ships a different `data` layout from
  the asset-scoped events: `data.id` is the UPLOAD identifier (NOT the
  asset id) and `data.asset_id` is the asset id. Without the typed branch
  below, the generic clause would mis-attribute `data.id` to
  `provider_asset_id` — silent data corruption when direct-creator-upload links
  creator uploads. The typed event keeps the upload identifier distinct from
  the provider asset identifier for downstream webhook handling.
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

  # Mux uses "preparing" while transcoding; Rindle's FSM uses "processing".
  defp normalize_state("preparing"), do: "processing"
  defp normalize_state("ready"), do: "ready"
  defp normalize_state("errored"), do: "errored"
  defp normalize_state("deleted"), do: "deleted"

  defp normalize_state(other) when is_binary(other) do
    require Logger
    Logger.warning("rindle.mux.unknown_status", status: other)
    nil
  end

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

  # Defensive Unix-string created_at parsing remains for non-webhook callers;
  # parse; no live caller feeds Mux REST created_at into Event normalization
  # (webhooks use ISO8601). Kept belt-and-suspenders; no behavior change.
  defp parse_occurred_at(nil), do: nil

  defp parse_occurred_at(time_str) when is_binary(time_str) do
    case DateTime.from_iso8601(time_str) do
      {:ok, dt, _offset} ->
        dt

      _ ->
        case Integer.parse(time_str) do
          {seconds, ""} -> DateTime.from_unix!(seconds, :second)
          _ -> nil
        end
    end
  end

  defp parse_occurred_at(_), do: nil
end
