defmodule Rindle.ApiSurfaceBoundaryTest do
  use ExUnit.Case, async: true

  @public_modules [
    Rindle,
    Rindle.Error,
    Rindle.Profile,
    Rindle.Profile.Presets.Web,
    Rindle.Upload.Broker,
    Rindle.Delivery,
    Rindle.Storage,
    Rindle.Storage.Local,
    Rindle.Storage.S3,
    Rindle.Storage.GCS,
    Rindle.Streaming,
    Rindle.Streaming.Provider,
    Rindle.Upload.TusPlug,
    Rindle.LiveView,
    Rindle.HTML,
    Rindle.Authorizer,
    Rindle.Analyzer,
    Rindle.Scanner,
    Rindle.Processor,
    Rindle.Processor.Image,
    Mix.Tasks.Rindle.AbortIncompleteUploads,
    Mix.Tasks.Rindle.BackfillMetadata,
    Mix.Tasks.Rindle.BatchOwnerErasure,
    Mix.Tasks.Rindle.CleanupOrphans,
    Mix.Tasks.Rindle.RegenerateVariants,
    Mix.Tasks.Rindle.RuntimeStatus,
    Mix.Tasks.Rindle.VerifyStorage,
    Rindle.Workers.AbortIncompleteUploads,
    Rindle.Workers.CleanupOrphans,
    Rindle.Domain.MediaAsset,
    Rindle.Domain.MediaAttachment,
    Rindle.Domain.MediaUploadSession,
    Rindle.Domain.MediaVariant,
    Rindle.Domain.MediaProcessingRun
  ]

  @helper_hidden_modules [
    Rindle.Config,
    Rindle.Internal.VariantFailureLogger,
    Rindle.Repo,
    Rindle.Security.Filename,
    Rindle.Security.Mime,
    Rindle.Security.StorageKey,
    Rindle.Security.UploadValidation,
    Rindle.Profile.Validator,
    Rindle.Profile.Digest,
    Rindle.Storage.Capabilities
  ]

  @domain_hidden_modules [
    Rindle.Domain.AssetFSM,
    Rindle.Domain.UploadSessionFSM,
    Rindle.Domain.VariantFSM,
    Rindle.Domain.StalePolicy
  ]

  @ops_hidden_modules [
    Rindle.Ops.LifecycleRepair,
    Rindle.Ops.MetadataBackfill,
    Rindle.Ops.RuntimeStatus,
    Rindle.Ops.UploadMaintenance,
    Rindle.Ops.VariantMaintenance,
    Rindle.Workers.PromoteAsset,
    Rindle.Workers.ProcessVariant,
    Rindle.Workers.PurgeStorage
  ]

  describe "compiled docs boundary" do
    test "D-03 reconciliation keeps storage adapters public alongside the facade allowlist" do
      for module <- @public_modules do
        assert visible_module?(module),
               "#{inspect(module)} should stay visible in compiled docs"
      end
    end

    test "D-05 helper modules resolve to hidden module docs" do
      for module <- @helper_hidden_modules do
        assert hidden_module?(module),
               "#{inspect(module)} should be hidden from compiled docs"
      end
    end

    test "D-05 domain invariants resolve to hidden module docs" do
      for module <- @domain_hidden_modules do
        assert hidden_module?(module),
               "#{inspect(module)} should be hidden from compiled docs"
      end
    end

    test "D-06 ops and internal workers resolve to hidden module docs" do
      for module <- @ops_hidden_modules do
        assert hidden_module?(module),
               "#{inspect(module)} should be hidden from compiled docs"
      end
    end
  end

  describe "facade export and shim expectations" do
    test "preferred and compatibility facade entrypoints remain callable" do
      assert function_exported?(Rindle, :verify_completion, 2)
      assert function_exported?(Rindle, :verify_upload, 2)
      assert function_exported?(Rindle, :complete_multipart_upload, 3)
      assert function_exported?(Rindle, :preview_owner_erasure, 2)
      assert function_exported?(Rindle, :erase_owner, 2)
      assert function_exported?(Rindle, :preview_batch_owner_erasure, 2)
      assert function_exported?(Rindle, :erase_batch_owner_erasure, 2)
      assert function_exported?(Rindle, :cancel_processing, 1)
      assert function_exported?(Rindle, :reprobe, 1)
      assert function_exported?(Rindle, :requeue_variants, 2)
      assert function_exported?(Rindle, :runtime_status, 1)
      assert function_exported?(Rindle, :log_variant_processing_failure, 3)
    end

    test "preferred verify_completion/2 is documented on the facade" do
      assert visible_function_doc?(Rindle, :verify_completion, 2),
             "Rindle.verify_completion/2 should be publicly documented"
    end

    test "owner-erasure facade entrypoints stay publicly documented" do
      assert visible_function_doc?(Rindle, :preview_owner_erasure, 2),
             "Rindle.preview_owner_erasure/2 should be publicly documented"

      assert visible_function_doc?(Rindle, :erase_owner, 2),
             "Rindle.erase_owner/2 should be publicly documented"
    end

    test "batch owner-erasure facade entrypoints stay publicly documented" do
      assert visible_function_doc?(Rindle, :preview_batch_owner_erasure, 2)
      assert visible_function_doc?(Rindle, :erase_batch_owner_erasure, 2)
    end

    test "legacy verify_upload/2 stays documented with an explicit deprecation marker" do
      assert visible_function_doc?(Rindle, :verify_upload, 2),
             "Rindle.verify_upload/2 should remain documented during 0.1.x"

      assert deprecated_function_doc?(Rindle, :verify_upload, 2, "Use verify_completion/2"),
             "Rindle.verify_upload/2 should point callers at verify_completion/2"
    end

    test "multipart and logging shim visibility stays aligned with the boundary contract" do
      assert visible_function_doc?(Rindle, :complete_multipart_upload, 3),
             "Rindle.complete_multipart_upload/3 stays public"

      assert hidden_function_doc?(Rindle, :log_variant_processing_failure, 3),
             "Rindle.log_variant_processing_failure/3 should become a hidden compatibility shim"
    end

    test "asset-scoped cancel_processing/1 stays publicly documented on the facade" do
      assert visible_function_doc?(Rindle, :cancel_processing, 1),
             "Rindle.cancel_processing/1 should be publicly documented"
    end

    test "asset-scoped reprobe/1 stays publicly documented on the facade" do
      assert visible_function_doc?(Rindle, :reprobe, 1),
             "Rindle.reprobe/1 should be publicly documented"
    end

    test "asset-scoped requeue_variants/2 stays publicly documented on the facade" do
      assert visible_function_doc?(Rindle, :requeue_variants, 2),
             "Rindle.requeue_variants/2 should be publicly documented"
    end

    test "runtime_status/1 stays publicly documented on the facade" do
      assert visible_function_doc?(Rindle, :runtime_status, 1),
             "Rindle.runtime_status/1 should be publicly documented"
    end

    test "owner-erasure contract wording stays frozen in the facade moduledoc" do
      moduledoc = normalize_whitespace(moduledoc!(Rindle))

      for snippet <- [
            "preview_owner_erasure/2",
            "erase_owner/2",
            "preview_batch_owner_erasure/2",
            "erase_batch_owner_erasure/2",
            "batch",
            "attachments_to_detach",
            "assets_to_purge",
            "retained_shared_assets",
            "cleanup_orphans",
            "maintenance-only",
            "admin UI",
            "force-delete"
          ] do
        assert moduledoc =~ snippet,
               "Rindle moduledoc should mention #{inspect(snippet)}"
      end
    end
  end

  describe "html helper surface" do
    test "video_tag/3 and audio_tag/3 stay publicly documented on Rindle.HTML" do
      assert visible_function_doc?(Rindle.HTML, :video_tag, 3),
             "Rindle.HTML.video_tag/3 should be publicly documented"

      assert visible_function_doc?(Rindle.HTML, :audio_tag, 3),
             "Rindle.HTML.audio_tag/3 should be publicly documented"
    end
  end

  describe "liveview helper surface" do
    test "subscribe/2 and unsubscribe/1 stay publicly documented on Rindle.LiveView" do
      assert visible_function_doc?(Rindle.LiveView, :subscribe, 2),
             "Rindle.LiveView.subscribe/2 should be publicly documented"

      assert visible_function_doc?(Rindle.LiveView, :unsubscribe, 1),
             "Rindle.LiveView.unsubscribe/1 should be publicly documented"
    end
  end

  defp visible_module?(module) do
    case fetch_docs!(module) do
      {:docs_v1, _, _, _, moduledoc, _, _} -> moduledoc not in [:hidden, false, nil]
    end
  end

  defp hidden_module?(module) do
    case fetch_docs!(module) do
      {:docs_v1, _, _, _, moduledoc, _, _} -> moduledoc in [:hidden, false, nil]
    end
  end

  defp visible_function_doc?(module, name, arity) do
    function_doc_state(module, name, arity) not in [:hidden, :none, nil]
  end

  defp hidden_function_doc?(module, name, arity) do
    function_doc_state(module, name, arity) in [:hidden, :none, nil]
  end

  defp deprecated_function_doc?(module, name, arity, message) do
    function_doc_metadata(module, name, arity)
    |> Map.get(:deprecated)
    |> Kernel.==(message)
  end

  defp function_doc_state(module, name, arity) do
    function_doc_entry(module, name, arity)
    |> case do
      nil -> nil
      {_, _, _, doc, _} -> doc
    end
  end

  defp function_doc_metadata(module, name, arity) do
    function_doc_entry(module, name, arity)
    |> case do
      nil -> %{}
      {_, _, _, _, metadata} -> metadata
    end
  end

  defp function_doc_entry(module, name, arity) do
    {:docs_v1, _, _, _, _, _, docs} = fetch_docs!(module)

    docs
    |> Enum.find(fn
      {{:function, doc_name, doc_arity}, _, _, _, _} -> doc_name == name and doc_arity == arity
      _ -> false
    end)
  end

  defp fetch_docs!(module) do
    assert Code.ensure_loaded?(module), "#{inspect(module)} must be loadable for boundary checks"

    case Code.fetch_docs(module) do
      {:error, reason} ->
        flunk("expected compiled docs for #{inspect(module)}, got #{inspect(reason)}")

      docs ->
        docs
    end
  end

  defp moduledoc!(module) do
    case fetch_docs!(module) do
      {:docs_v1, _, _, _, %{"en" => doc}, _, _} when is_binary(doc) -> doc
      {:docs_v1, _, _, _, {_, doc}, _, _} when is_binary(doc) -> doc
      {:docs_v1, _, _, _, doc, _, _} when is_binary(doc) -> doc
      other -> flunk("expected moduledoc for #{inspect(module)}, got #{inspect(other)}")
    end
  end

  defp normalize_whitespace(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
