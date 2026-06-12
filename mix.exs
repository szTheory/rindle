defmodule Rindle.MixProject do
  use Mix.Project

  @version "0.1.10"
  @source_url "https://github.com/szTheory/rindle"

  def project do
    [
      app: :rindle,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      package: package(),
      name: "Rindle",
      description: "Phoenix/Ecto-native media lifecycle library. Media, made durable.",
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix, :ex_unit, :mux, :jose, :goth, :finch, :gcs_signed_url],
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Rindle.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "test/adopter"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core
      {:ecto_sql, "~> 3.11"},
      {:postgrex, "~> 0.18"},
      {:jason, "~> 1.4"},
      {:muontrap, "~> 1.7"},

      # Background processing
      {:oban, "~> 2.21"},

      # Image processing
      {:image, "~> 0.65"},

      # LiveView integration (optional — Rindle.LiveView helpers are no-op without it)
      {:phoenix_live_view, "~> 1.0", optional: true},

      # Streaming providers (optional — Mux adapter only loads when these are present)
      {:mux, "~> 3.2", optional: true},
      {:jose, "~> 1.11", optional: true},

      # GCS adapter (optional — Rindle.Storage.GCS only loads when these are present)
      {:goth, "~> 1.4", optional: true},
      {:finch, "~> 0.21", optional: true},
      {:gcs_signed_url, "~> 0.4.6", optional: true},

      # Configuration validation
      {:nimble_options, "~> 1.1"},

      # Security
      {:ex_marcel, "~> 0.2"},
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},
      # ExAws optional HTTP client — needed for the integration + adopter
      # CI lanes to actually talk to MinIO/S3. Declared optional so adopters
      # pick their own HTTP client (hackney, req, or finch via ex_aws_*) at
      # runtime without a forced transitive dep from Rindle. Optional rather
      # than `only: :test` because the optional `gcs_signed_url ~> 0.4.6` dep
      # (Phase 37) pulls `httpoison ~> 2.0` whose hackney requirement is
      # `optional: false` — mix's `:only` calculation requires consistency
      # across all paths reaching hackney. See `.planning/phases/37-gcs-adapter-foundation/37-01-PLAN.md` Task 1.
      {:hackney, "~> 1.20", optional: true},

      # Observability
      {:telemetry, "~> 1.2"},

      # Plug — required by :image (color visualizer) and phoenix_live_view transitively
      {:plug, "~> 1.16"},

      # Dev/Test
      {:lazy_html, ">= 0.1.0", only: :test},
      {:mox, "~> 1.2", only: :test},
      {:bypass, "~> 2.1", only: :test},
      {:ex_machina, "~> 2.7", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.22.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:test, :dev], runtime: false},
      json_polyfill_dep(),
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp json_polyfill_dep do
    otp_major = System.otp_release() |> String.to_integer()

    if otp_major < 27 do
      {:json_polyfill, "~> 0.2", only: [:test, :dev]}
    end
  end

  defp docs do
    [
      main: "Rindle",
      source_url: @source_url,
      logo: "brandbook/assets/logo/rindle-mark-dark.svg",
      favicon: "brandbook/assets/logo/favicon.svg",
      extras: [
        "README.md",
        "RUNNING.md",
        "guides/user_flows.md",
        "guides/getting_started.md",
        "guides/upgrading.md",
        "guides/core_concepts.md",
        "guides/storage_capabilities.md",
        "guides/storage_gcs.md",
        "guides/profiles.md",
        "guides/secure_delivery.md",
        "guides/resumable_uploads.md",
        "guides/streaming_providers.md",
        "guides/background_processing.md",
        "guides/operations.md",
        "guides/troubleshooting.md",
        "guides/release_publish.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/(?!release_publish).*\.md$/,
        Maintainer: ~r/guides\/release_publish\.md$/
      ],
      groups_for_modules: [
        Facade: [
          Rindle,
          Rindle.Error
        ],
        Profiles: [
          Rindle.Profile
        ],
        Upload: [
          Rindle.Upload.Broker
        ],
        Delivery: [
          Rindle.Delivery
        ],
        "Optional Integrations": [
          Rindle.LiveView,
          Rindle.HTML
        ],
        "Extension Points": [
          Rindle.Authorizer,
          Rindle.Analyzer,
          Rindle.Scanner,
          Rindle.Processor
        ],
        "Storage and Processor Adapters": [
          Rindle.Storage,
          Rindle.Storage.Local,
          Rindle.Storage.S3,
          Rindle.Storage.GCS,
          Rindle.Processor.Image
        ],
        Operations: [
          Mix.Tasks.Rindle.AbortIncompleteUploads,
          Mix.Tasks.Rindle.BackfillMetadata,
          Mix.Tasks.Rindle.CleanupOrphans,
          Mix.Tasks.Rindle.RegenerateVariants,
          Mix.Tasks.Rindle.VerifyStorage,
          Rindle.Workers.AbortIncompleteUploads,
          Rindle.Workers.CleanupOrphans
        ],
        "Data Types": [
          Rindle.Domain.MediaAsset,
          Rindle.Domain.MediaAttachment,
          Rindle.Domain.MediaUploadSession,
          Rindle.Domain.MediaVariant,
          Rindle.Domain.MediaProcessingRun
        ]
      ],
      before_closing_head_tag: &before_closing_head_tag/1
    ]
  end

  # Mermaid CDN injection so ```mermaid fences in guides and @moduledoc blocks
  # render as interactive SVG diagrams in the generated HexDocs HTML.
  # Only the :html target needs this; :epub returns an empty string.
  defp before_closing_head_tag(:html) do
    """
    <script defer src="https://cdn.jsdelivr.net/npm/mermaid@10.2.3/dist/mermaid.min.js"></script>
    <script>
      let initialized = false;
      window.addEventListener("exdoc:loaded", () => {
        if (!initialized) {
          mermaid.initialize({
            startOnLoad: false,
            theme: document.body.className.includes("dark") ? "dark" : "default"
          });
          initialized = true;
        }
        let id = 0;
        for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
          const preEl = codeEl.parentElement;
          const graphDefinition = codeEl.textContent;
          const graphEl = document.createElement("div");
          const graphId = "mermaid-graph-" + id++;
          mermaid.render(graphId, graphDefinition).then(({svg, bindFunctions}) => {
            graphEl.innerHTML = svg;
            bindFunctions?.(graphEl);
            preEl.insertAdjacentElement("afterend", graphEl);
            preEl.remove();
          });
        }
      });
    </script>
    """
  end

  defp before_closing_head_tag(:epub), do: ""

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      files:
        ~w(lib priv/repo/migrations priv/static/rindle_admin mix.exs README.md RUNNING.md CHANGELOG.md LICENSE guides)
    ]
  end

  defp aliases do
    [
      "gsd.clean": ["cmd bash scripts/gsd_cleanup.sh"],
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
