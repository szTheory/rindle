defmodule Rindle.Ops.RuntimeChecks.IntegrationChecks.GCS do
  @moduledoc false

  @gcs_dep_missing_fix ~s(Add {:goth, "~> 1.4", optional: true}, {:finch, "~> 0.21", optional: true}, and {:gcs_signed_url, "~> 0.6", optional: true} to your deps and run mix deps.get.)

  @gcs_goth_fix """
  Add {Goth, name: MyApp.Goth, source: {:service_account, creds}} to your supervision tree, then set config :rindle, Rindle.Storage.GCS, goth: MyApp.Goth.
  """

  @gcs_bucket_fix """
  Verify config :rindle, Rindle.Storage.GCS, bucket: "my-bucket" matches a bucket your service account can access.
  """

  @gcs_signing_key_fix """
  Verify the signing_key config is either a decoded service-account JSON map (preferred) or a raw PEM string with `client_email:` configured separately. File-path loading is not supported here; decode the service-account JSON at boot via `Jason.decode!(File.read!("path/to/key.json"))` and pass the resulting map.
  """

  @gcs_precondition_fix """
  Start `MyApp.Finch` and `MyApp.Goth` in your application supervision tree, then set config :rindle, Rindle.Storage.GCS, finch: MyApp.Finch, goth: MyApp.Goth.
  """

  @gcs_resumable_cors_fix """
  Configure bucket CORS for your app origins with `PUT` and `PATCH`, and allow `Content-Range` plus `x-goog-resumable` in the browser-facing response/header policy. Keep `session_uri` secret because it is a bearer credential, expect resumable sessions to expire within one week, and treat region pinning as normal when you choose the bucket location.
  """

  @doc false
  def schedule([], _opts, _config_reader), do: []

  def schedule(gcs_profiles, opts, config_reader) do
    checks = [
      fn -> check_gcs_goth_running(config_reader.()) end,
      fn -> check_gcs_bucket_reachable(config_reader.()) end,
      fn -> check_gcs_signing_key(config_reader.()) end
    ]

    if resumable_gcs_profiles(gcs_profiles) == [] do
      checks
    else
      checks ++ [fn -> check_gcs_resumable_cors(opts, config_reader.()) end]
    end
  end

  defp resumable_gcs_profiles(gcs_profiles) do
    Enum.filter(gcs_profiles, fn profile ->
      case profile.storage_adapter() do
        adapter when is_atom(adapter) ->
          function_exported?(adapter, :capabilities, 0) and
            :resumable_upload_session in adapter.capabilities()

        _other ->
          false
      end
    end)
  end

  defp check_gcs_goth_running(app_env) do
    if Code.ensure_loaded?(Goth) do
      goth_name = app_env[:goth]
      goth_result(fetch_gcs_goth_token(goth_name), goth_name)
    else
      error_result(
        "doctor.gcs_goth_running",
        :gcs,
        "GCS-enabled profile detected but :goth dep is not loaded.",
        @gcs_dep_missing_fix
      )
    end
  end

  defp goth_result(:ok, goth_name) do
    ok_result(
      "doctor.gcs_goth_running",
      :gcs,
      "Goth instance #{inspect(goth_name)} is running and minting tokens.",
      @gcs_goth_fix
    )
  end

  defp goth_result({:error, :no_goth_configured}, _goth_name) do
    error_result(
      "doctor.gcs_goth_running",
      :gcs,
      "config :rindle, Rindle.Storage.GCS, goth: ... is not set.",
      @gcs_goth_fix
    )
  end

  defp goth_result({:error, reason}, goth_name) do
    error_result(
      "doctor.gcs_goth_running",
      :gcs,
      "Goth instance #{inspect(goth_name)} is not minting tokens: #{inspect(reason)}.",
      @gcs_goth_fix
    )
  end

  defp fetch_gcs_goth_token(nil), do: {:error, :no_goth_configured}

  defp fetch_gcs_goth_token(name) do
    case Goth.fetch(name) do
      {:ok, _token} -> :ok
      {:error, exception} when is_struct(exception) -> {:error, exception.__struct__}
      {:error, reason} -> {:error, reason}
    end
  rescue
    ArgumentError -> {:error, :argument_error}
  catch
    :exit, _reason -> {:error, :noproc}
  end

  defp check_gcs_bucket_reachable(app_env) do
    if Code.ensure_loaded?(Finch) do
      check_configured_bucket(app_env[:bucket], app_env)
    else
      error_result(
        "doctor.gcs_bucket_reachable",
        :gcs,
        "GCS-enabled profile detected but :finch dep is not loaded.",
        @gcs_dep_missing_fix
      )
    end
  end

  defp check_configured_bucket(nil, _app_env) do
    error_result(
      "doctor.gcs_bucket_reachable",
      :gcs,
      "config :rindle, Rindle.Storage.GCS, bucket: \"...\" is not set.",
      @gcs_bucket_fix
    )
  end

  defp check_configured_bucket(bucket, app_env) do
    result = probe_gcs_bucket(bucket, app_env[:finch], app_env[:goth], probe_opts(app_env))
    bucket_result(result, bucket)
  end

  defp probe_opts(app_env) do
    [base_url: app_env[:base_url], token: app_env[:token]]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp bucket_result(:ok, bucket) do
    ok_result(
      "doctor.gcs_bucket_reachable",
      :gcs,
      "Bucket #{inspect(bucket)} is reachable (HTTP 200/403 from /storage/v1/b/$BUCKET).",
      @gcs_bucket_fix
    )
  end

  defp bucket_result({:precondition_missing, which}, _bucket) do
    error_result(
      "doctor.gcs_bucket_reachable",
      :gcs,
      "GCS bucket reachability could not be probed (#{which}). Start Finch + Goth in your supervision tree and configure their names.",
      @gcs_precondition_fix
    )
  end

  defp bucket_result({:bucket_missing, _status}, bucket) do
    error_result(
      "doctor.gcs_bucket_reachable",
      :gcs,
      "GCS bucket #{inspect(bucket)} not found (404).",
      @gcs_bucket_fix
    )
  end

  defp bucket_result({:unexpected_status, status}, bucket) do
    error_result(
      "doctor.gcs_bucket_reachable",
      :gcs,
      "GCS API returned unexpected status #{status} for bucket #{inspect(bucket)}.",
      @gcs_bucket_fix
    )
  end

  # Probe failures expose only transport reasons or exception module names;
  # response bodies and bearer tokens never enter this result.
  defp bucket_result({:probe_error, reason}, bucket) do
    error_result(
      "doctor.gcs_bucket_reachable",
      :gcs,
      "GCS bucket #{inspect(bucket)} probe failed: #{inspect(reason)}.",
      @gcs_bucket_fix
    )
  end

  # Real HTTP probe with explicit precondition guards.
  # Public (def) so Bypass-mocked unit tests can exercise it directly.
  # @doc false marks it as not part of the documented public API.
  @doc false
  def probe_gcs_bucket(bucket, finch_name, goth_name, opts \\ []) do
    cond do
      not Code.ensure_loaded?(Finch) ->
        {:precondition_missing, :finch_unavailable}

      finch_name == nil ->
        {:precondition_missing, :finch_not_configured}

      not Code.ensure_loaded?(Goth) ->
        {:precondition_missing, :goth_unavailable}

      goth_name == nil ->
        {:precondition_missing, :goth_not_configured}

      true ->
        do_probe(bucket, finch_name, goth_name, opts)
    end
  end

  # Actual HTTP request issuance. Public for
  # testability; @doc false. `:base_url` opt allows Bypass redirection in unit
  # tests; `:token` opt is a test-only seam that bypasses Goth.fetch/1 (which
  # would otherwise call Google's real OAuth endpoint with the fake fixture
  # credentials and fail). Both seams mirror the GCS client conventions.
  @doc false
  def do_probe(bucket, finch_name, goth_name, opts \\ []) do
    base_url = Keyword.get(opts, :base_url, "https://storage.googleapis.com")
    encoded_bucket = URI.encode(bucket)
    url = "#{base_url}/storage/v1/b/#{encoded_bucket}"

    with {:ok, token} <- probe_token(goth_name, opts),
         req = Finch.build(:get, url, [{"Authorization", "Bearer " <> token}]),
         {:ok, %{__struct__: Finch.Response, status: status}} <- Finch.request(req, finch_name) do
      case status do
        s when s in [200, 403] -> :ok
        404 -> {:bucket_missing, 404}
        s -> {:unexpected_status, s}
      end
    else
      {:error, reason} -> {:probe_error, reason}
    end
  catch
    :exit, reason -> {:probe_error, {:exit, reason}}
  end

  # `:token` is a test-only seam so
  # Bypass-mocked unit tests do not have to round-trip through Google's real
  # OAuth endpoint with fake fixture credentials. Production callers do not
  # set `:token` and the Goth path runs.
  defp probe_token(goth_name, opts) do
    case Keyword.get(opts, :token) do
      token when is_binary(token) ->
        {:ok, token}

      _ ->
        case Goth.fetch(goth_name) do
          {:ok, %{__struct__: Goth.Token, token: token}} -> {:ok, token}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp check_gcs_signing_key(app_env) do
    if Code.ensure_loaded?(GcsSignedUrl.Client) do
      case app_env[:signing_key] do
        nil ->
          error_result(
            "doctor.gcs_signing_key",
            :gcs,
            "config :rindle, Rindle.Storage.GCS, signing_key: ... is not set.",
            @gcs_signing_key_fix
          )

        signing_key ->
          verify_gcs_signing_key(signing_key, app_env)
      end
    else
      error_result(
        "doctor.gcs_signing_key",
        :gcs,
        "GCS-enabled profile detected but :gcs_signed_url dep is not loaded.",
        @gcs_dep_missing_fix
      )
    end
  end

  # Match the Mux signing-key safety rule: emit only the exception module, never
  # Exception.message/1 — so PEM body / JSON content never echo into doctor
  # output even on failure.
  defp verify_gcs_signing_key(%{"private_key" => _, "client_email" => _} = json_map, _app_env) do
    _client = GcsSignedUrl.Client.load(json_map)

    ok_result(
      "doctor.gcs_signing_key",
      :gcs,
      "GCS signing key parses as a valid service-account JSON map.",
      @gcs_signing_key_fix
    )
  rescue
    exception ->
      error_result(
        "doctor.gcs_signing_key",
        :gcs,
        "GCS signing_key parse raised: #{inspect(exception.__struct__)} (malformed service-account JSON).",
        @gcs_signing_key_fix
      )
  end

  defp verify_gcs_signing_key(path, app_env) when is_binary(path) and byte_size(path) > 0 do
    if String.starts_with?(path, "-----BEGIN ") do
      case app_env[:client_email] do
        client_email when is_binary(client_email) and client_email != "" ->
          ok_result(
            "doctor.gcs_signing_key",
            :gcs,
            "GCS signing key is a raw PEM string and client_email is configured separately.",
            @gcs_signing_key_fix
          )

        _missing ->
          error_result(
            "doctor.gcs_signing_key",
            :gcs,
            "GCS signing_key is a raw PEM string but config :rindle, Rindle.Storage.GCS, client_email: ... is not set.",
            @gcs_signing_key_fix
          )
      end
    else
      error_result(
        "doctor.gcs_signing_key",
        :gcs,
        "GCS signing_key is a non-PEM binary. Doctor and the signer accept only a decoded service-account JSON map, or a raw PEM string with client_email configured separately; file-path loading is not supported.",
        @gcs_signing_key_fix
      )
    end
  end

  # Map.get(other, :__struct__) returns the module for a struct and nil for a
  # bare map; the fallback keeps the diagnostic useful for both shapes.
  defp verify_gcs_signing_key(other, _app_env) when is_map(other) do
    error_result(
      "doctor.gcs_signing_key",
      :gcs,
      "GCS signing_key has unexpected shape: #{inspect(Map.get(other, :__struct__) || :map_without_struct)}.",
      @gcs_signing_key_fix
    )
  end

  # Keep the catchall explicit for nil, integers, lists, tuples, and other
  # non-map/non-binary inputs.
  defp verify_gcs_signing_key(_other, _app_env) do
    error_result(
      "doctor.gcs_signing_key",
      :gcs,
      "GCS signing_key has unexpected shape (not a map or binary).",
      @gcs_signing_key_fix
    )
  end

  defp check_gcs_resumable_cors(opts, app_env) do
    bucket = app_env[:bucket]
    finch_name = app_env[:finch]
    goth_name = app_env[:goth]

    cors_source =
      Keyword.get(opts, :gcs_bucket_cors) ||
        extract_bucket_cors(Keyword.get(opts, :gcs_bucket_metadata)) ||
        app_env[:bucket_cors] ||
        extract_bucket_cors(app_env[:bucket_metadata]) ||
        app_env[:cors]

    result =
      case cors_source do
        nil ->
          fetch_gcs_bucket_cors(bucket, finch_name, goth_name, app_env, opts)

        cors_rules ->
          {:ok, cors_rules}
      end

    build_gcs_resumable_cors_result(result)
  end

  defp build_gcs_resumable_cors_result({:ok, cors_rules}) do
    issues = gcs_resumable_cors_issues(cors_rules)

    if issues == [] do
      ok_result(
        "doctor.gcs_resumable_cors",
        :gcs,
        "Bucket CORS metadata includes app origins plus resumable browser requirements for `PUT`, `PATCH`, `Content-Range`, and `x-goog-resumable`.",
        @gcs_resumable_cors_fix
      )
    else
      warn_result(
        "doctor.gcs_resumable_cors",
        :gcs,
        "Bucket CORS metadata looks incomplete for browser resumable uploads: #{Enum.join(issues, "; ")}.",
        @gcs_resumable_cors_fix
      )
    end
  end

  defp build_gcs_resumable_cors_result({:error, reason}) do
    warn_result(
      "doctor.gcs_resumable_cors",
      :gcs,
      "Bucket CORS metadata could not be inspected automatically: #{format_gcs_cors_reason(reason)}.",
      @gcs_resumable_cors_fix
    )
  end

  defp fetch_gcs_bucket_cors(nil, _finch_name, _goth_name, _app_env, _opts),
    do: {:error, :bucket_not_configured}

  defp fetch_gcs_bucket_cors(bucket, finch_name, goth_name, app_env, opts) do
    with :ok <- cors_dependencies(finch_name, goth_name),
         {:ok, token} <- probe_token(goth_name, opts),
         url = bucket_cors_url(bucket, app_env, opts),
         request = Finch.build(:get, url, [{"Authorization", "Bearer " <> token}]),
         {:ok, response} <- Finch.request(request, finch_name) do
      decode_bucket_cors(response)
    end
  catch
    :exit, reason -> {:error, {:exit, reason}}
  end

  defp cors_dependencies(finch_name, goth_name) do
    cond do
      not Code.ensure_loaded?(Finch) -> {:error, :finch_unavailable}
      not Code.ensure_loaded?(Goth) -> {:error, :goth_unavailable}
      is_nil(finch_name) -> {:error, :finch_not_configured}
      is_nil(goth_name) -> {:error, :goth_not_configured}
      not Code.ensure_loaded?(Jason) -> {:error, :json_unavailable}
      true -> :ok
    end
  end

  defp bucket_cors_url(bucket, app_env, opts) do
    base_url =
      Keyword.get(opts, :gcs_bucket_base_url) || app_env[:base_url] ||
        "https://storage.googleapis.com"

    "#{base_url}/storage/v1/b/#{URI.encode(bucket)}?fields=cors"
  end

  defp decode_bucket_cors(%{__struct__: Finch.Response, status: 200, body: body}) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        {:ok, extract_bucket_cors(decoded) || []}

      {:error, %Jason.DecodeError{} = error} ->
        {:error, {:decode_error, inspect(error.__struct__)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_bucket_cors(%{__struct__: Finch.Response, status: status}),
    do: {:error, {:unexpected_status, status}}

  defp extract_bucket_cors(%{"cors" => cors}) when is_list(cors), do: cors
  defp extract_bucket_cors(%{cors: cors}) when is_list(cors), do: cors
  defp extract_bucket_cors(_other), do: nil

  defp gcs_resumable_cors_issues(cors_rules) when is_list(cors_rules) do
    rules =
      Enum.filter(cors_rules, fn
        rule when is_map(rule) -> true
        _other -> false
      end)

    []
    |> maybe_add_cors_issue(cors_origins_present?(rules), "missing app origins")
    |> maybe_add_cors_issue(
      cors_methods_present?(rules, ["put", "patch"]),
      "missing `PUT`/`PATCH`"
    )
    |> maybe_add_cors_issue(
      cors_headers_present?(rules, ["content-range", "x-goog-resumable"]),
      "missing `Content-Range`/`x-goog-resumable`"
    )
  end

  defp gcs_resumable_cors_issues(_other),
    do: ["bucket CORS metadata is not a list of rules"]

  defp maybe_add_cors_issue(issues, true, _message), do: issues
  defp maybe_add_cors_issue(issues, false, message), do: issues ++ [message]

  defp cors_origins_present?(rules) do
    Enum.any?(rules, fn rule ->
      rule
      |> cors_rule_values(["origin", :origin])
      |> Enum.any?(&(&1 != ""))
    end)
  end

  defp cors_methods_present?(rules, required) do
    Enum.any?(rules, fn rule ->
      values = cors_rule_values(rule, ["method", :method])
      wildcard_or_superset?(values, required)
    end)
  end

  defp cors_headers_present?(rules, required) do
    Enum.any?(rules, fn rule ->
      values = cors_rule_values(rule, ["responseHeader", :responseHeader, :response_header])
      wildcard_or_superset?(values, required)
    end)
  end

  defp wildcard_or_superset?(values, required) do
    normalized =
      values
      |> Enum.map(&String.downcase/1)
      |> MapSet.new()

    MapSet.member?(normalized, "*") or
      Enum.all?(required, &MapSet.member?(normalized, &1))
  end

  defp cors_rule_values(rule, keys) do
    keys
    |> Enum.flat_map(fn key ->
      case Map.get(rule, key) do
        values when is_list(values) -> values
        value when is_binary(value) -> [value]
        _other -> []
      end
    end)
    |> Enum.map(&String.trim/1)
  end

  defp format_gcs_cors_reason({:unexpected_status, status}),
    do: "GCS bucket metadata returned status #{status}"

  defp format_gcs_cors_reason({:decode_error, detail}),
    do: "GCS bucket metadata returned unreadable JSON (#{detail})"

  defp format_gcs_cors_reason({:exit, reason}),
    do: "bucket metadata request exited: #{inspect(reason)}"

  defp format_gcs_cors_reason(reason), do: inspect(reason)

  defp ok_result(id, component, summary, fix) do
    {:runtime_check, :ok, id, component, summary, fix, %{}}
  end

  defp warn_result(id, component, summary, fix) do
    {:runtime_check, :warn, id, component, summary, fix, %{}}
  end

  defp error_result(id, component, summary, fix) do
    {:runtime_check, :error, id, component, summary, fix, %{}}
  end
end
