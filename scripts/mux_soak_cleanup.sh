#!/usr/bin/env bash
# Belt-and-suspenders cleanup for the `mux-soak` CI lane (Phase 36 D-22 layer 3).
#
# Mux's free tier caps stored on-demand assets at 10 (external research Topic 2),
# so the soak lane MUST delete the assets it creates. There are three cleanup
# layers:
#   1. Elixir `try/after` inside `lifecycle_test_source(_, :mux)` — runs on
#      both pass and fail, but only knows about the asset it created.
#   2. The lifecycle test's normal-path delete on success.
#   3. THIS script — invoked from the workflow's `if: always()` step. Lists
#      every asset tagged `passthrough == "rindle_soak"` in the test Mux
#      account and deletes them. Idempotent: re-runs are safe; deleted-or-
#      missing assets do not produce a non-zero exit. Logs redact
#      `provider_asset_id` to last-4 chars (security invariant 14) via
#      `Rindle.Domain.MediaProviderAsset.redact_id/1`.
#
# Phase 36 CR-01: the producer side (`Rindle.Workers.MuxIngestVariant`)
# stamps `passthrough: "rindle_soak"` on every create-asset request when
# the `RINDLE_MUX_PASSTHROUGH_TAG` env var is set in the soak lane. The
# filter below MUST stay in lock-step with that producer tag — the
# regression test
# `test/rindle/streaming/provider/mux/mux_test.exs#"create_asset/3 forwards :passthrough to the SDK request body (Phase 36 CR-01 cleanup contract)"`
# pins the contract.
#
# Exits 0 (no-op) when `RINDLE_MUX_TOKEN_ID` or `RINDLE_MUX_TOKEN_SECRET`
# resolve to empty strings — fork PRs labeled `streaming` cannot reach secrets,
# and the `if: always()` cleanup step MUST NOT fail in that case.
#
# Usage:
#   bash scripts/mux_soak_cleanup.sh           # list + delete tagged assets
#   bash scripts/mux_soak_cleanup.sh --dry-run # list only; skip delete

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR="${RINDLE_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

if [ -z "${RINDLE_MUX_TOKEN_ID:-}" ] || [ -z "${RINDLE_MUX_TOKEN_SECRET:-}" ]; then
  echo "mux_soak_cleanup: RINDLE_MUX_TOKEN_ID/SECRET unset — fork-PR safe no-op (exit 0)"
  exit 0
fi

cd "$ROOT_DIR"

export RINDLE_MUX_SOAK_CLEANUP_DRY_RUN="$DRY_RUN"

mix run --no-start -e '
dry_run? = System.get_env("RINDLE_MUX_SOAK_CLEANUP_DRY_RUN") == "1"

unless Code.ensure_loaded?(Mux.Video.Assets) do
  IO.puts("mux_soak_cleanup: :mux dep not loaded — exit 0 (no-op)")
  System.halt(0)
end

token_id = System.get_env("RINDLE_MUX_TOKEN_ID")
token_secret = System.get_env("RINDLE_MUX_TOKEN_SECRET")
client = Mux.Base.new(token_id, token_secret)

redact = fn id ->
  if function_exported?(Rindle.Domain.MediaProviderAsset, :redact_id, 1) do
    Rindle.Domain.MediaProviderAsset.redact_id(id)
  else
    case id do
      nil -> nil
      id when is_binary(id) and byte_size(id) >= 4 ->
        "..." <> binary_part(id, byte_size(id) - 4, 4)
      _ -> "...redacted"
    end
  end
end

case Mux.Video.Assets.list(client, %{limit: 100}) do
  {:ok, assets, _env} when is_list(assets) ->
    soak_assets =
      Enum.filter(assets, fn asset ->
        passthrough = Map.get(asset, "passthrough") || Map.get(asset, :passthrough)
        passthrough == "rindle_soak"
      end)

    if soak_assets == [] do
      IO.puts("mux_soak_cleanup: no soak assets found (passthrough=rindle_soak) — exit 0")
    else
      IO.puts("mux_soak_cleanup: found #{length(soak_assets)} soak asset(s)")

      Enum.each(soak_assets, fn asset ->
        id = Map.get(asset, "id") || Map.get(asset, :id)
        tag = redact.(id)

        if dry_run? do
          IO.puts("  [dry-run] would delete asset #{tag}")
        else
          case Mux.Video.Assets.delete(client, id) do
            {:ok, _, _} ->
              IO.puts("  deleted asset #{tag}")

            {:error, %{"error" => %{"messages" => msgs}}, _env} ->
              IO.puts("  skip asset #{tag} (error: #{inspect(msgs)})")

            {:error, reason, _env} ->
              IO.puts("  skip asset #{tag} (error: #{inspect(reason)})")

            other ->
              IO.puts("  skip asset #{tag} (unexpected: #{inspect(other)})")
          end
        end
      end)
    end

  {:error, reason, _env} ->
    IO.puts("mux_soak_cleanup: list failed (#{inspect(reason)}) — exit 0 (idempotent)")

  other ->
    IO.puts("mux_soak_cleanup: unexpected list result (#{inspect(other)}) — exit 0 (idempotent)")
end

System.halt(0)
'
