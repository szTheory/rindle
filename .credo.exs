%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "lib/",
          "test/"
        ],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      plugins: [],
      requires: [],
      strict: true,
      parse_timeout: 5000,
      color: true,
      checks: %{
        enabled: [
          {Credo.Check.Consistency.ExceptionNames, []},
          {Credo.Check.Consistency.LineEndings, []},
          {Credo.Check.Consistency.ParameterPatternMatching, []},
          {Credo.Check.Consistency.SpaceAroundOperators, []},
          {Credo.Check.Consistency.SpaceInParentheses, []},
          {Credo.Check.Consistency.TabsOrSpaces, []},
          {Credo.Check.Design.AliasUsage, [priority: :low, if_nested_deeper_than: 2, if_called_more_often_than: 0]},
          {Credo.Check.Design.TagTODO, [exit_status: 2]},
          {Credo.Check.Design.TagFIXME, []},
          {Credo.Check.Readability.AliasOrder, []},
          {Credo.Check.Readability.FunctionNames, []},
          {Credo.Check.Readability.LargeNumbers, []},
          {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
          {Credo.Check.Readability.ModuleAttributeNames, []},
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.ModuleNames, []},
          {Credo.Check.Readability.ParenthesesInCondition, []},
          {Credo.Check.Readability.PredicateFunctionNames, []},
          {Credo.Check.Readability.PreferImplicitTry, []},
          {Credo.Check.Readability.RedundantBlankLines, []},
          {Credo.Check.Readability.Semicolons, []},
          {Credo.Check.Readability.SpaceAfterCommas, []},
          {Credo.Check.Readability.StringSigils, []},
          {Credo.Check.Readability.TrailingBlankLine, []},
          {Credo.Check.Readability.TrailingWhiteSpace, []},
          {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
          {Credo.Check.Readability.VariableNames, []},
          {Credo.Check.Refactor.CondStatements, []},
          {Credo.Check.Refactor.CyclomaticComplexity, []},
          {Credo.Check.Refactor.FunctionArity, []},
          {Credo.Check.Refactor.LongQuoteBlocks, []},
          {Credo.Check.Refactor.MatchInCondition, []},
          {Credo.Check.Refactor.NegatedConditionsInUnless, []},
          {Credo.Check.Refactor.NegatedConditionsWithElse, []},
          {Credo.Check.Refactor.Nesting, []},
          {Credo.Check.Refactor.UnlessWithElse, []},
          {Credo.Check.Refactor.WithClauses, []},
          {Credo.Check.Warning.BoolOperationOnSameValues, []},
          {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
          {Credo.Check.Warning.IExPry, []},
          {Credo.Check.Warning.IoInspect, []},
          {Credo.Check.Warning.OperationOnSameValues, []},
          {Credo.Check.Warning.OperationWithConstantResult, []},
          {Credo.Check.Warning.RaiseInsideRescue, []},
          {Credo.Check.Warning.UnusedEnumOperation, []},
          {Credo.Check.Warning.UnusedFileOperation, []},
          {Credo.Check.Warning.UnusedKeywordOperation, []},
          {Credo.Check.Warning.UnusedListOperation, []},
          {Credo.Check.Warning.UnusedPathOperation, []},
          {Credo.Check.Warning.UnusedRegexOperation, []},
          {Credo.Check.Warning.UnusedStringOperation, []},
          {Credo.Check.Warning.UnusedTupleOperation, []},
          {Credo.Check.Warning.UnsafeExec, []}
        ]
      }
    },
    %{
      name: "blocking_warnings",
      files: %{included: ["lib/", "test/"]},
      plugins: [],
      requires: [],
      strict: true,
      parse_timeout: 5000,
      color: false,
      checks: %{
        enabled: [
          {Credo.Check.Warning.BoolOperationOnSameValues, []},
          {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
          {Credo.Check.Warning.IExPry, []},
          {Credo.Check.Warning.IoInspect, []},
          {Credo.Check.Warning.OperationOnSameValues, []},
          {Credo.Check.Warning.OperationWithConstantResult, []},
          {Credo.Check.Warning.RaiseInsideRescue, []},
          {Credo.Check.Warning.UnusedEnumOperation, []},
          {Credo.Check.Warning.UnusedFileOperation, []},
          {Credo.Check.Warning.UnusedKeywordOperation, []},
          {Credo.Check.Warning.UnusedListOperation, []},
          {Credo.Check.Warning.UnusedPathOperation, []},
          {Credo.Check.Warning.UnusedRegexOperation, []},
          {Credo.Check.Warning.UnusedStringOperation, []},
          {Credo.Check.Warning.UnusedTupleOperation, []},
          {Credo.Check.Warning.UnsafeExec, []}
        ]
      }
    },
    %{
      name: "public_contract",
      # This is the explicit ExDoc/public-processor boundary, not a namespace glob.
      files: %{
        included: [
          "lib/rindle.ex",
          "lib/rindle/error.ex",
          "lib/rindle/profile.ex",
          "lib/rindle/profile/presets/web.ex",
          "lib/rindle/upload/broker.ex",
          "lib/rindle/delivery.ex",
          "lib/rindle/storage.ex",
          "lib/rindle/storage/local.ex",
          "lib/rindle/storage/s3.ex",
          "lib/rindle/storage/gcs.ex",
          "lib/rindle/streaming.ex",
          "lib/rindle/streaming/provider.ex",
          "lib/rindle/live_view.ex",
          "lib/rindle/html.ex",
          "lib/rindle/admin/router.ex",
          "lib/rindle/authorizer.ex",
          "lib/rindle/analyzer.ex",
          "lib/rindle/scanner.ex",
          "lib/rindle/processor.ex",
          "lib/rindle/processor/image.ex",
          "lib/rindle/processor/av.ex",
          "lib/rindle/migration.ex",
          "lib/mix/tasks/rindle.abort_incomplete_uploads.ex",
          "lib/mix/tasks/rindle.backfill_metadata.ex",
          "lib/mix/tasks/rindle.batch_owner_erasure.ex",
          "lib/mix/tasks/rindle.cleanup_orphans.ex",
          "lib/mix/tasks/rindle.doctor.ex",
          "lib/mix/tasks/rindle.regenerate_variants.ex",
          "lib/mix/tasks/rindle.runtime_status.ex",
          "lib/mix/tasks/rindle.sweep_orphaned_temp_files.ex",
          "lib/mix/tasks/rindle.verify_storage.ex",
          "lib/rindle/workers/abort_incomplete_uploads.ex",
          "lib/rindle/workers/cleanup_orphans.ex",
          "lib/rindle/domain/media_asset.ex",
          "lib/rindle/domain/media_attachment.ex",
          "lib/rindle/domain/media_upload_session.ex",
          "lib/rindle/domain/media_variant.ex",
          "lib/rindle/domain/media_processing_run.ex",
          "lib/rindle/domain/media_provider_asset.ex",
          "lib/rindle/schema.ex"
        ]
      },
      plugins: [],
      requires: [],
      strict: true,
      parse_timeout: 5000,
      color: false,
      checks: %{
        enabled: [
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.Specs, []}
        ]
      }
    },
    %{
      name: "complexity_inventory",
      files: %{included: ["lib/", "test/"]},
      plugins: [],
      requires: [],
      strict: true,
      parse_timeout: 5000,
      color: false,
      checks: %{
        enabled: [
          {Credo.Check.Refactor.CyclomaticComplexity, [max_complexity: 9]},
          {Credo.Check.Refactor.Nesting, [max_nesting: 2]}
        ]
      }
    }
  ]
}
