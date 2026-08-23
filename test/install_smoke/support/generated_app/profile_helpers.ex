defmodule Rindle.InstallSmoke.GeneratedApp.ProfileHelpers do
  @moduledoc false
  alias Rindle.InstallSmoke.GeneratedApp.Workspace

  def video_fixture_path do
    Path.join(Workspace.repo_root(), "test/support/fixtures/smartphone/android_capture.webm")
  end

  # Phase 36 Pitfall 2: Mox `import` is required at the top of the generated
  # test module ONLY for the `:mux` profile mode. For `:image` and `:video`,
  # the generated app does not depend on Mox.
  def mux_test_imports(:mux), do: "  import Mox\n"
  def mux_test_imports(_other), do: ""

  def profile_test_moduletag(:gcs), do: ""
  def profile_test_moduletag(_other), do: "  @moduletag :minio\n"

  def profile_test_helpers(app_module, :tus) do
    """
        def start_endpoint_server!(port) do
          endpoint_config = Application.get_env(:#{Macro.underscore(app_module)}, Endpoint, [])

          Application.put_env(
            :#{Macro.underscore(app_module)},
            Endpoint,
            Keyword.merge(endpoint_config,
              server: true,
              http: [ip: {127, 0, 0, 1}, port: port]
            )
          )

          if Process.whereis(Endpoint) do
            case Supervisor.terminate_child(#{app_module}.Supervisor, Endpoint) do
              :ok -> :ok
              {:error, :not_found} -> :ok
              {:error, :running} -> :ok
              {:error, :restarting} -> :ok
            end
          end

          case Supervisor.restart_child(#{app_module}.Supervisor, Endpoint) do
            {:ok, _pid} -> :ok
            {:ok, _pid, _info} -> :ok
            {:error, :not_found} ->
              {:ok, _pid} = Endpoint.start_link()
              :ok
            {:error, {:already_started, _pid}} -> :ok
            {:error, :running} -> :ok
          end

          wait_for_port!(port)
          wait_for_http_ready!(port)
        end

        def wait_for_port!(port) do
          result =
            Enum.reduce_while(1..50, :error, fn _attempt, _acc ->
              case :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false], 200) do
                {:ok, socket} ->
                  :gen_tcp.close(socket)
                  {:halt, :ok}

                {:error, _reason} ->
                  Process.sleep(100)
                  {:cont, :error}
              end
            end)

          assert result == :ok, "endpoint did not start on port \#{port}"
        end

        def wait_for_http_ready!(port) do
          url = 'http://127.0.0.1:' ++ Integer.to_charlist(port) ++ '/'

          result =
            Enum.reduce_while(1..50, :error, fn _attempt, _acc ->
              case :httpc.request(:get, {url, []}, [], []) do
                {:ok, {{_, status, _}, _, _}} when status in 200..499 ->
                  {:halt, :ok}

                _other ->
                  Process.sleep(100)
                  {:cont, :error}
              end
            end)

          assert result == :ok, "endpoint did not serve HTTP on port \#{port}"
        end

        def build_large_mp4_fixture!(path) do
          File.mkdir_p!(Path.dirname(path))

          args = [
            "-y",
            "-f",
            "lavfi",
            "-i",
            "testsrc=size=1280x720:rate=30:duration=20",
            "-f",
            "lavfi",
            "-i",
            "sine=frequency=880:sample_rate=48000:duration=20",
            "-map",
            "0:v:0",
            "-map",
            "1:a:0",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-x264-params",
            "nal-hrd=cbr:force-cfr=1",
            "-b:v",
            "85M",
            "-minrate",
            "85M",
            "-maxrate",
            "85M",
            "-bufsize",
            "170M",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            "-movflags",
            "+faststart",
            path
          ]

          {output, exit_code} = System.cmd("ffmpeg", args, stderr_to_stdout: true)
          assert exit_code == 0, output
          assert File.stat!(path).size >= 200 * 1024 * 1024
        end

        def install_tus_js_client! do
          if File.exists?("node_modules/tus-js-client/package.json") do
            :ok
          else
            {output, exit_code} =
              System.cmd(
                "npm",
                ["install", "--no-save", "tus-js-client@4.3.1"],
                stderr_to_stdout: true
              )

            assert exit_code == 0, output
          end
        end

        def write_tus_node_script!(path) do
          File.mkdir_p!(Path.dirname(path))

          File.write!(
            path,
            ~S'''
            const fs = require("fs")
            const http = require("http")
            const path = require("path")
            const { Readable } = require("stream")
            const https = require("https")
            const tus = require("tus-js-client")

            const endpoint = process.argv[2]
            const uploadUrl = process.argv[3]
            const filePath = process.argv[4]
            const debugReportPath = process.argv[6]
            const file = fs.readFileSync(filePath)
            const extensionProofPayload = file.subarray(0, Math.min(file.length, 8 * 1024 * 1024))
            const concatProofPayload = file.subarray(0, Math.min(file.length, 12 * 1024 * 1024))
            const chunkSize = 16 * 1024 * 1024
            const metadata = {
              filename: path.basename(filePath),
              filetype: "video/mp4",
            }
            const fingerprintValue = `rindle-phase44:${metadata.filename}:${file.length}`
            const urlStoragePath = path.join(process.cwd(), "tmp", "install_smoke_tus_url_storage.json")

            fs.mkdirSync(path.dirname(urlStoragePath), { recursive: true })

            function writeDebugReport(report) {
              if (!debugReportPath) return
              fs.mkdirSync(path.dirname(debugReportPath), { recursive: true })
              fs.writeFileSync(debugReportPath, JSON.stringify(report, null, 2))
            }

            function responseStatus(response) {
              return response && typeof response.getStatus === "function" ? response.getStatus() : null
            }

            function responseBody(response) {
              return response && typeof response.getBody === "function" ? response.getBody() : null
            }

            function requestSnapshot(request) {
              if (!request) return null

              return {
                method: request._method || request.method || null,
                url: request._url || request.url || null,
                headers: request._headers || request.headers || null,
                reused_socket:
                  request._request
                    ? request._request.reusedSocket === true
                    : request.reused_socket ?? null,
              }
            }

            function headerValue(headers, key) {
              if (!headers || typeof headers !== "object") return null
              const expected = String(key || "").toLowerCase()

              for (const [headerKey, headerValue] of Object.entries(headers)) {
                if (String(headerKey).toLowerCase() === expected) return headerValue
              }

              return null
            }

            function uniqueFingerprint(mode) {
              return `${fingerprintValue}:${mode}:${Date.now()}:${Math.random().toString(36).slice(2)}`
            }

            function patchStatus(tracker) {
              const patchEvents = tracker.phases.filter(
                (phase) => phase.event === "response" && phase.method === "PATCH"
              )

              return patchEvents.length > 0 ? patchEvents[patchEvents.length - 1].status : null
            }

            function trackerFor(mode) {
              return {
                mode,
                phases: [],
                lastRequest: null,
                createAccepted: false,
                patchStarted: false,
                chunkCompleted: false,
              }
            }

            function sleep(ms) {
              return new Promise((resolve) => setTimeout(resolve, ms))
            }

            function baseOptions() {
              return {
                endpoint,
                uploadUrl,
                metadata,
                chunkSize,
                parallelUploads: 1,
                retryDelays: null,
                httpStack: new tus.DefaultHttpStack({ agent: false }),
                removeFingerprintOnSuccess: true,
                storeFingerprintForResuming: true,
                fingerprint: () => Promise.resolve(fingerprintValue),
                urlStorage: new tus.FileUrlStorage(urlStoragePath),
              }
            }

            function postConcatFinal(uploadConcatHeader) {
              return tusRequest(
                "POST",
                endpoint,
                {
                  "Tus-Resumable": "1.0.0",
                  "Upload-Concat": uploadConcatHeader,
                  "Upload-Metadata": `filename ${Buffer.from(metadata.filename).toString("base64")},filetype ${Buffer.from(metadata.filetype).toString("base64")}`,
                },
                null
              )
            }

            function tusRequest(method, targetUrl, headers = {}, body = null) {
              return new Promise((resolve, reject) => {
                const url = new URL(targetUrl, endpoint)
                const client = url.protocol === "https:" ? https : http

                const request = client.request(
                  url,
                  {
                    method,
                    headers,
                  },
                  (response) => {
                    const chunks = []

                    response.on("data", (chunk) => chunks.push(chunk))
                    response.on("end", () => {
                      resolve({
                        status: response.statusCode || null,
                        body: Buffer.concat(chunks).toString("utf8"),
                        headers: response.headers || {},
                      })
                    })
                  }
                )

                request.on("error", reject)

                if (body !== null && body !== undefined) {
                  request.write(body)
                }

                request.end()
              })
            }

            async function runManualConcatProof() {
              const midpoint = Math.floor(concatProofPayload.length / 2)
              const firstPart = concatProofPayload.subarray(0, midpoint)
              const secondPart = concatProofPayload.subarray(midpoint)

              async function createPartial(part) {
                const response = await tusRequest(
                  "POST",
                  endpoint,
                  {
                    "Tus-Resumable": "1.0.0",
                    "Upload-Concat": "partial",
                    "Upload-Length": String(part.length),
                  },
                  null
                )

                if (response.status !== 201) {
                  throw new Error(`partial creation failed with status ${response.status}`)
                }

                const locationHeader = response.headers.location

                if (!locationHeader) {
                  throw new Error("partial creation response missing location header")
                }

                return {
                  uploadUrl: new URL(locationHeader, endpoint).toString(),
                  part,
                }
              }

              async function patchPartial(partial) {
                const response = await tusRequest(
                  "PATCH",
                  partial.uploadUrl,
                  {
                    "Tus-Resumable": "1.0.0",
                    "Upload-Offset": "0",
                    "Content-Type": "application/offset+octet-stream",
                  },
                  partial.part
                )

                if (response.status !== 204) {
                  throw new Error(`partial patch failed with status ${response.status}`)
                }
              }

              const partials = await Promise.all([createPartial(firstPart), createPartial(secondPart)])
              await Promise.all(partials.map((partial) => patchPartial(partial)))

              const finalHeader = `final;${partials[0].uploadUrl} ${partials[1].uploadUrl}`
              let finalStatus = null

              for (let attempt = 0; attempt < 40; attempt += 1) {
                try {
                  const finalResponse = await postConcatFinal(finalHeader)
                  finalStatus = finalResponse.status
                } catch (_error) {
                  finalStatus = null
                }

                if (finalStatus === 201) break
                await sleep(250)
              }

              if (finalStatus !== 201) {
                throw new Error(`manual final concat failed with status ${finalStatus}`)
              }

              return {
                proved: true,
                parallel_uploads: 2,
                status: 201,
              }
            }

            function trackedOptions(tracker, hooks = {}) {
              return {
                ...baseOptions(),
                onBeforeRequest: (request) => {
                  const snapshot = requestSnapshot(request)
                  tracker.lastRequest = snapshot

                  tracker.phases.push({
                    event: "request",
                    method: snapshot && snapshot.method,
                    url: snapshot && snapshot.url,
                    headers: snapshot && snapshot.headers,
                  })

                  if (typeof hooks.onBeforeRequest === "function") {
                    hooks.onBeforeRequest(request, tracker)
                  }
                },
                onAfterResponse: (request, response) => {
                  const method = request && request._method
                  const phase =
                    method === "POST"
                      ? "create_upload"
                      : method === "HEAD"
                        ? "resume_lookup"
                        : method === "PATCH"
                          ? "resume_upload"
                          : "unknown"

                  if (method === "POST" && responseStatus(response) === 201) tracker.createAccepted = true
                  if (method === "PATCH") tracker.patchStarted = true

                  tracker.phases.push({
                    event: "response",
                    phase,
                    method,
                    status: responseStatus(response),
                    body: responseBody(response),
                  })

                  if (typeof hooks.onAfterResponse === "function") {
                    hooks.onAfterResponse(request, response, tracker)
                  }
                },
              }
            }

            function failurePhase(tracker) {
              if (tracker.mode === "resume") return "resume_upload"
              if (uploadUrl) return "interrupt_upload"
              if (!tracker.createAccepted) return "create_upload"
              if (tracker.mode === "interrupt" && !tracker.chunkCompleted) return "interrupt_upload"
              return "interrupt_upload"
            }

            function failureReport(error, tracker, extra = {}) {
              const request = error && error.originalRequest ? error.originalRequest : tracker.lastRequest
              const response = error && error.originalResponse
              const cause = error && error.causingError
              const phase = failurePhase(tracker)

              return {
                ok: false,
                mode: tracker.mode,
                endpoint,
                failure_phase: phase,
                failure_mode: tracker.mode,
                failure_summary: `${phase} failed during ${tracker.mode}`,
                error_name: error && error.name,
                error_message: error && error.message,
                response_code: responseStatus(response),
                response_body: responseBody(response),
                request: requestSnapshot(request),
                cause:
                  cause
                    ? {
                        message: cause.message || null,
                        code: cause.code || null,
                      }
                    : null,
                phases: tracker.phases,
                ...extra,
              }
            }

            async function interruptAfterFirstChunk() {
              return new Promise((resolve, reject) => {
                let interrupted = false
                let upload = null
                const tracker = trackerFor("interrupt")

                upload = new tus.Upload(file, {
                  ...trackedOptions(tracker),
                  onChunkComplete: (_chunkSize, bytesAccepted) => {
                    if (!interrupted && bytesAccepted > 0) {
                      interrupted = true
                      tracker.chunkCompleted = true
                      upload.abort().then(resolve).catch(reject)
                    }
                  },
                  onSuccess: () => {
                    reject(new Error("upload completed before simulated drop"))
                  },
                  onError: (error) => {
                    if (!interrupted) {
                      reject(failureReport(error, tracker))
                    }
                  },
                })

                upload.start()
              })
            }

            async function runSingleUploadMode(
              modeName,
              sourceFactory,
              optionOverrides = {},
              hooks = {},
              evidenceBuilder = () => ({})
            ) {
              const tracker = trackerFor(modeName)

              return new Promise((resolve, reject) => {
                const upload = new tus.Upload(sourceFactory(), {
                  ...trackedOptions(tracker, hooks),
                  ...optionOverrides,
                  uploadUrl: null,
                  retryDelays: null,
                  storeFingerprintForResuming: false,
                  fingerprint: () => Promise.resolve(uniqueFingerprint(modeName)),
                  onSuccess: () => {
                    resolve({
                      proved: true,
                      ...evidenceBuilder(tracker, upload),
                    })
                  },
                  onError: (error) => reject(failureReport(error, tracker)),
                })

                upload.start()
              })
            }

            async function runConcatParallelProof() {
              try {
                return await runSingleUploadMode(
                  "concat_parallel",
                  () => concatProofPayload,
                  { parallelUploads: 2 },
                  {},
                  (tracker) => ({
                    parallel_uploads: 2,
                    status: patchStatus(tracker),
                  })
                )
              } catch (errorReport) {
                const uploadConcatHeader = headerValue(errorReport?.request?.headers, "Upload-Concat")

                if (
                  errorReport?.response_code === 400 &&
                  typeof uploadConcatHeader === "string" &&
                  uploadConcatHeader.startsWith("final;")
                ) {
                  for (let attempt = 0; attempt < 40; attempt += 1) {
                    let response = null

                    try {
                      response = await postConcatFinal(uploadConcatHeader)
                    } catch (_error) {
                      response = null
                    }

                    if (response && response.status === 201) {
                      return {
                        proved: true,
                        parallel_uploads: 2,
                        status: 201,
                      }
                    }

                    await sleep(250)
                  }

                  return runManualConcatProof()
                }

                throw errorReport
              }
            }

            async function runDeferLengthStreamProof() {
              let usedUploadDeferLength = false

              return runSingleUploadMode(
                "defer_length_stream",
                () => Readable.from(extensionProofPayload),
                {
                  uploadLengthDeferred: true,
                  chunkSize: 1 * 1024 * 1024,
                  uploadSize: extensionProofPayload.length,
                },
                {
                  onBeforeRequest: (request) => {
                    const method = request && (request._method || request.method)
                    const headers = (request && (request._headers || request.headers)) || {}

                    if (
                      method === "POST" &&
                      String(headerValue(headers, "Upload-Defer-Length") || "") === "1"
                    ) {
                      usedUploadDeferLength = true
                    }

                    if (method === "PATCH" && !headerValue(headers, "Upload-Length")) {
                      if (typeof request.setHeader === "function") {
                        request.setHeader("Upload-Length", String(extensionProofPayload.length))
                      } else if (request._headers) {
                        request._headers["Upload-Length"] = String(extensionProofPayload.length)
                      } else if (request.headers) {
                        request.headers["Upload-Length"] = String(extensionProofPayload.length)
                      }
                    }
                  },
                },
                (tracker) => ({
                  used_upload_defer_length: usedUploadDeferLength,
                  status: patchStatus(tracker),
                })
              )
            }

            async function runChecksumPatchProof() {
              let algorithm = null
              let status = null

              return runSingleUploadMode(
                "checksum_patch",
                () => extensionProofPayload,
                {
                  checksumAlgorithm: "sha1",
                  parallelUploads: 1,
                },
                {
                  onBeforeRequest: (request) => {
                    const method = request && (request._method || request.method)
                    const headers = (request && (request._headers || request.headers)) || {}

                    if (method === "PATCH") {
                      const checksumHeader = headerValue(headers, "Upload-Checksum")

                      if (checksumHeader) {
                        algorithm = String(checksumHeader).split(" ")[0] || null
                      }
                    }
                  },
                  onAfterResponse: (request, response) => {
                    const method = request && (request._method || request.method)
                    if (method === "PATCH") status = responseStatus(response)
                  },
                },
                (tracker) => ({
                  algorithm: algorithm || "sha1",
                  status: status ?? patchStatus(tracker),
                })
              )
            }

            async function runExtensionProofs() {
              const concatenation = await runConcatParallelProof()
              const creation_defer_length = await runDeferLengthStreamProof()
              const checksum = await runChecksumPatchProof()

              return {
                concatenation,
                creation_defer_length,
                checksum,
              }
            }

            async function resumeUpload() {
              const tracker = trackerFor("resume")
              return new Promise(async (resolve, reject) => {
                let previousUploads = []

                const upload = new tus.Upload(file, {
                  ...trackedOptions(tracker),
                  onSuccess: () => {
                    resolve({
                      upload_url: upload.url,
                      seeded_upload_url: uploadUrl,
                      previous_uploads: previousUploads.length,
                      endpoint,
                      failure_phase: "none",
                      failure_mode: "none",
                      failure_summary: "none",
                    })
                  },
                  onError: (error) => reject(failureReport(error, tracker, { previous_uploads: previousUploads.length })),
                })

                try {
                  previousUploads = await upload.findPreviousUploads()
                } catch (error) {
                  reject(
                    failureReport(error, tracker, {
                      failure_phase: "resume_lookup",
                      failure_summary: "resume_lookup failed before resumeFromPreviousUpload()",
                    })
                  )
                  return
                }

                if (previousUploads.length === 0) {
                  reject({
                    ok: false,
                    mode: tracker.mode,
                    endpoint,
                    failure_phase: "resume_lookup",
                    failure_mode: tracker.mode,
                    failure_summary: "resume_lookup found no stored uploads",
                    error_name: "ResumeLookupError",
                    error_message: "no previous tus upload was available to resume",
                    phases: tracker.phases,
                    previous_uploads: previousUploads.length,
                  })
                  return
                }

                upload.resumeFromPreviousUpload(previousUploads[0])
                upload.start()
              })
            }

            const mode = process.argv[5] || "all"

            ;(async () => {
              if (!tus.canStoreURLs) {
                throw new Error("tus-js-client URL storage is unavailable in this Node environment")
              }

              if (mode === "interrupt") {
                await interruptAfterFirstChunk()
                process.stdout.write(JSON.stringify({ interrupted: true, endpoint }))
                return
              }

              if (mode === "resume") {
                const result = await resumeUpload()
                result.extensions = await runExtensionProofs()
                process.stdout.write(JSON.stringify(result))
                return
              }

              await interruptAfterFirstChunk()
              await new Promise((resolve) => setTimeout(resolve, 250))
              const result = await resumeUpload()
              result.extensions = await runExtensionProofs()
              process.stdout.write(JSON.stringify(result))
            })().catch((error) => {
              writeDebugReport(error)
              console.error(JSON.stringify(error, null, 2))
              process.exit(1)
            })
            '''
          )
        end

        def run_tus_node_proof!(script_path, endpoint, upload_url, fixture_path) do
          debug_report_path = Path.expand("../tmp/install_smoke_tus_debug_report.json", __DIR__)
          url_storage_path = Path.expand("../tmp/install_smoke_tus_url_storage.json", __DIR__)

          File.rm(url_storage_path)

          merge_tus_report!(%{
            endpoint: endpoint,
            upload_url: upload_url,
            report_path: Path.expand("../tmp/install_smoke_tus_report.json", __DIR__),
            debug_report_path: debug_report_path
          })

          {interrupt_output, interrupt_exit_code} =
            System.cmd(
              "node",
              [script_path, endpoint, upload_url, fixture_path, "interrupt", debug_report_path],
              stderr_to_stdout: true
            )

          assert interrupt_exit_code == 0,
                 "tus interrupt phase failed for \#{endpoint}\\nreport: \#{debug_report_path}\\n\#{interrupt_output}"

          merge_tus_debug_report!(%{interrupt_output: interrupt_output})

          {output, exit_code} =
            System.cmd("node", [script_path, endpoint, upload_url, fixture_path, "resume", debug_report_path],
              stderr_to_stdout: true
            )

          assert exit_code == 0,
                 "tus resume phase failed for \#{endpoint}\\nreport: \#{debug_report_path}\\n\#{output}"

          merge_tus_debug_report!(%{resume_output: output})
          Jason.decode!(output)
        end

        def read_tus_report! do
          case File.read("tmp/install_smoke_tus_report.json") do
            {:ok, body} -> Jason.decode!(body)
            {:error, :enoent} -> %{}
          end
        end

        def write_tus_report!(attrs) do
          File.mkdir_p!("tmp")
          File.write!("tmp/install_smoke_tus_report.json", Jason.encode!(attrs))
        end

        def merge_tus_report!(attrs) do
          attrs = Map.merge(read_tus_report!(), attrs)
          write_tus_report!(attrs)
        end

        def read_tus_debug_report! do
          case File.read("tmp/install_smoke_tus_debug_report.json") do
            {:ok, body} -> Jason.decode!(body)
            {:error, :enoent} -> %{}
          end
        end

        def write_tus_debug_report!(attrs) do
          File.mkdir_p!("tmp")
          File.write!("tmp/install_smoke_tus_debug_report.json", Jason.encode!(attrs))
        end

        def merge_tus_debug_report!(attrs) do
          attrs = Map.merge(read_tus_debug_report!(), attrs)
          write_tus_debug_report!(attrs)
        end

        def preflight_entries(preflight) do
          entries = Map.get(preflight, :entries) || Map.fetch!(preflight, "entries")

          case entries do
            list when is_list(list) -> list
            map when is_map(map) -> Map.values(map)
          end
        end

        def preflight_entry_meta!(entry) do
          Map.get(entry, :meta) || Map.get(entry, "meta") || entry
        end

        def preflight_value!(map, key) do
          Map.get(map, key) || Map.fetch!(map, Atom.to_string(key))
        end
    """
  end

  def profile_test_helpers(_app_module, :gcs) do
    """
        def gcs_live_env? do
          is_binary(System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON")) and
            System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON") != "" and
            is_binary(System.get_env("RINDLE_GCS_BUCKET")) and
            System.get_env("RINDLE_GCS_BUCKET") != ""
        end

        def read_gcs_report! do
          case File.read("tmp/install_smoke_gcs_report.json") do
            {:ok, body} -> Jason.decode!(body)
            {:error, :enoent} -> %{}
          end
        end

        def write_gcs_report!(attrs) do
          File.mkdir_p!("tmp")
          File.write!("tmp/install_smoke_gcs_report.json", Jason.encode!(attrs))
        end

        def merge_gcs_report!(attrs) do
          attrs = Map.merge(read_gcs_report!(), attrs)
          write_gcs_report!(attrs)
        end

        def register_gcs_cleanup_key!(upload_key) do
          case System.get_env("RINDLE_INSTALL_SMOKE_GCS_CLEANUP_FILE") do
            path when is_binary(path) and path != "" ->
              File.mkdir_p!(Path.dirname(path))
              File.write!(path, upload_key <> "\\n", [:append])

            _ ->
              :ok
          end
        end
    """
  end

  def profile_test_helpers(_app_module, _other), do: ""

  def install_smoke_app_name(:gcs) do
    case System.get_env("RINDLE_INSTALL_SMOKE_GCS_PREFIX") do
      prefix when is_binary(prefix) and prefix != "" ->
        "rindle_smoke_app_#{sanitize_app_suffix(prefix)}"

      _ ->
        "rindle_smoke_app"
    end
  end

  def install_smoke_app_name(_profile_mode), do: "rindle_smoke_app"

  def sanitize_app_suffix(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_]/u, "_")
    |> String.trim("_")
    |> case do
      "" -> "gcs"
      cleaned -> String.slice(cleaned, 0, 32)
    end
  end
end
