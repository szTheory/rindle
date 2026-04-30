defmodule Rindle.ApiSurfaceBoundaryTest do
  use ExUnit.Case, async: true

  @public_modules [
    Rindle,
    Rindle.Profile,
    Rindle.Upload.Broker,
    Rindle.Delivery,
    Rindle.Storage,
    Rindle.Storage.Local,
    Rindle.Storage.S3,
    Rindle.LiveView,
    Rindle.HTML,
    Rindle.Authorizer,
    Rindle.Analyzer,
    Rindle.Scanner,
    Rindle.Processor,
    Mix.Tasks.Rindle.AbortIncompleteUploads,
    Mix.Tasks.Rindle.BackfillMetadata,
    Mix.Tasks.Rindle.CleanupOrphans,
    Mix.Tasks.Rindle.RegenerateVariants,
    Mix.Tasks.Rindle.VerifyStorage,
    Rindle.Workers.AbortIncompleteUploads,
    Rindle.Workers.CleanupOrphans,
    Rindle.Domain.MediaAsset,
    Rindle.Domain.MediaAttachment,
    Rindle.Domain.MediaUploadSession,
    Rindle.Domain.MediaVariant,
    Rindle.Domain.MediaProcessingRun
  ]

  @hidden_modules [
    Rindle.Config,
    Rindle.Repo,
    Rindle.Security.Filename,
    Rindle.Security.Mime,
    Rindle.Security.StorageKey,
    Rindle.Security.UploadValidation,
    Rindle.Profile.Validator,
    Rindle.Profile.Digest,
    Rindle.Storage.Capabilities,
    Rindle.Domain.AssetFSM,
    Rindle.Domain.UploadSessionFSM,
    Rindle.Domain.VariantFSM,
    Rindle.Domain.StalePolicy,
    Rindle.Ops.MetadataBackfill,
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

    test "D-05 and D-06 internal namespaces resolve to hidden module docs" do
      for module <- @hidden_modules do
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
      assert function_exported?(Rindle, :log_variant_processing_failure, 3)
    end

    test "preferred verify_completion/2 is documented on the facade" do
      assert visible_function_doc?(Rindle, :verify_completion, 2),
             "Rindle.verify_completion/2 should be publicly documented"
    end

    test "legacy and shim functions stay callable but disappear from the docs contract" do
      assert hidden_function_doc?(Rindle, :verify_upload, 2),
             "Rindle.verify_upload/2 should become a hidden compatibility shim"

      assert visible_function_doc?(Rindle, :complete_multipart_upload, 3),
             "Rindle.complete_multipart_upload/3 stays public"

      assert hidden_function_doc?(Rindle, :log_variant_processing_failure, 3),
             "Rindle.log_variant_processing_failure/3 should become a hidden compatibility shim"
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

  defp function_doc_state(module, name, arity) do
    {:docs_v1, _, _, _, _, _, docs} = fetch_docs!(module)

    docs
    |> Enum.find(fn
      {{:function, doc_name, doc_arity}, _, _, _, _} -> doc_name == name and doc_arity == arity
      _ -> false
    end)
    |> case do
      nil -> nil
      {_, _, _, doc, _} -> doc
    end
  end

  defp fetch_docs!(module) do
    assert Code.ensure_loaded?(module), "#{inspect(module)} must be loadable for boundary checks"

    case Code.fetch_docs(module) do
      {:error, reason} -> flunk("expected compiled docs for #{inspect(module)}, got #{inspect(reason)}")
      docs -> docs
    end
  end
end
