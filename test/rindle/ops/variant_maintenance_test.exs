defmodule Rindle.Ops.VariantMaintenanceTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Rindle.Ops.VariantMaintenance
  alias Rindle.Domain.{MediaAsset, MediaVariant}

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [
        thumb: [mode: :crop, width: 100, height: 100],
        large: [mode: :fit, width: 1200, height: 900]
      ],
      allow_mime: ["image/jpeg"],
      max_bytes: 10_485_760
  end

  defp insert_asset do
    %MediaAsset{}
    |> MediaAsset.changeset(%{
      state: "available",
      profile: to_string(TestProfile),
      storage_key: "test/asset.jpg"
    })
    |> Rindle.Repo.insert!()
  end

  defp insert_variant(asset, name, state, storage_key \\ nil) do
    attrs = %{
      asset_id: asset.id,
      name: to_string(name),
      state: state,
      recipe_digest: TestProfile.recipe_digest(name),
      storage_key: storage_key
    }

    %MediaVariant{}
    |> MediaVariant.changeset(attrs)
    |> Rindle.Repo.insert!()
  end

  # -----------------------------------------------------------------------
  # regenerate_variants/1
  # -----------------------------------------------------------------------

  describe "regenerate_variants/1" do
    test "enqueues jobs for stale variants" do
      asset = insert_asset()
      _stale = insert_variant(asset, :thumb, "stale")

      {:ok, result} = VariantMaintenance.regenerate_variants(%{})

      assert result.enqueued == 1
      assert result.skipped == 0
      assert result.errors == 0
      assert_enqueued(worker: Rindle.Workers.ProcessVariant, args: %{"asset_id" => asset.id, "variant_name" => "thumb"})
    end

    test "enqueues jobs for missing variants" do
      asset = insert_asset()
      _missing = insert_variant(asset, :thumb, "missing")

      {:ok, result} = VariantMaintenance.regenerate_variants(%{})

      assert result.enqueued == 1
      assert result.errors == 0
      assert_enqueued(worker: Rindle.Workers.ProcessVariant, args: %{"asset_id" => asset.id, "variant_name" => "thumb"})
    end

    test "skips ready variants" do
      asset = insert_asset()
      _ready = insert_variant(asset, :thumb, "ready", "variants/thumb.jpg")

      {:ok, result} = VariantMaintenance.regenerate_variants(%{})

      assert result.enqueued == 0
      assert result.skipped == 1
      assert result.errors == 0
      refute_enqueued(worker: Rindle.Workers.ProcessVariant)
    end

    test "filters by variant name when specified" do
      asset = insert_asset()
      _thumb_stale = insert_variant(asset, :thumb, "stale")
      _large_stale = insert_variant(asset, :large, "stale")

      {:ok, result} = VariantMaintenance.regenerate_variants(%{variant_name: "thumb"})

      assert result.enqueued == 1
      assert result.errors == 0
      assert_enqueued(worker: Rindle.Workers.ProcessVariant, args: %{"variant_name" => "thumb"})
      refute_enqueued(worker: Rindle.Workers.ProcessVariant, args: %{"variant_name" => "large"})
    end

    test "filters by profile when specified" do
      asset = insert_asset()
      _stale = insert_variant(asset, :thumb, "stale")

      # Filter for a different profile — should enqueue nothing
      {:ok, result} = VariantMaintenance.regenerate_variants(%{profile: "Elixir.SomeOtherProfile"})

      assert result.enqueued == 0
      assert result.errors == 0
    end

    test "returns enqueued and skipped counts" do
      asset = insert_asset()
      _stale = insert_variant(asset, :thumb, "stale")
      _missing = insert_variant(asset, :large, "missing")

      {:ok, result} = VariantMaintenance.regenerate_variants(%{})

      assert result.enqueued == 2
      assert result.skipped == 0
      assert result.errors == 0
    end

    test "rejects unknown filter keys instead of silently ignoring them" do
      # WR-08: typo'd filter keys (`prof` instead of `profile`, `variant`
      # instead of `variant_name`) must surface as errors so a destructive
      # caller does not accidentally target every variant in the system.
      assert {:error, {:unknown_filters, [:prof]}} =
               VariantMaintenance.regenerate_variants(%{prof: "X"})

      assert {:error, {:unknown_filters, [:variant]}} =
               VariantMaintenance.regenerate_variants(%{variant: "thumb"})

      assert {:error, {:unknown_filters, [:prof]}} =
               VariantMaintenance.verify_storage(%{prof: "X"})
    end

    test "second call does not enqueue duplicate jobs (Oban uniqueness)" do
      # CR-03 regression: back-to-back runs must not double-enqueue
      # ProcessVariant work for the same (asset_id, variant_name).
      asset = insert_asset()
      _stale = insert_variant(asset, :thumb, "stale")

      {:ok, first} = VariantMaintenance.regenerate_variants(%{})
      assert first.enqueued == 1
      assert first.skipped == 0

      # Second call: the previous job is still :available — uniqueness
      # should detect the conflict and skip rather than enqueue again.
      {:ok, second} = VariantMaintenance.regenerate_variants(%{})
      assert second.enqueued == 0
      assert second.skipped >= 1
      assert second.errors == 0

      # Verify only ONE job is in the queue for this (asset, variant) pair.
      jobs =
        Rindle.Repo.all(
          Ecto.Query.from(j in Oban.Job,
            where: j.worker == "Rindle.Workers.ProcessVariant",
            where: fragment("?->>'asset_id' = ?", j.args, ^asset.id),
            where: fragment("?->>'variant_name' = ?", j.args, "thumb")
          )
        )

      assert length(jobs) == 1
    end
  end

  # -----------------------------------------------------------------------
  # verify_storage/1
  # -----------------------------------------------------------------------

  describe "verify_storage/1" do
    test "marks variants missing when HEAD check fails" do
      asset = insert_asset()
      variant = insert_variant(asset, :thumb, "ready", "variants/thumb.jpg")

      expect(Rindle.StorageMock, :head, fn _key, _opts ->
        {:error, :not_found}
      end)

      {:ok, result} = VariantMaintenance.verify_storage(%{})

      assert result.missing == 1
      assert result.present == 0
      assert result.errors == 0
      assert result.checked == 1

      updated = Rindle.Repo.get!(MediaVariant, variant.id)
      assert updated.state == "missing"
    end

    test "preserves present variants" do
      asset = insert_asset()
      variant = insert_variant(asset, :thumb, "ready", "variants/thumb.jpg")

      expect(Rindle.StorageMock, :head, fn _key, _opts ->
        {:ok, %{content_length: 1024}}
      end)

      {:ok, result} = VariantMaintenance.verify_storage(%{})

      assert result.present == 1
      assert result.missing == 0
      assert result.errors == 0

      updated = Rindle.Repo.get!(MediaVariant, variant.id)
      assert updated.state == "ready"
    end

    test "counts errors separately from missing" do
      asset = insert_asset()
      _variant = insert_variant(asset, :thumb, "ready", "variants/thumb.jpg")

      expect(Rindle.StorageMock, :head, fn _key, _opts ->
        {:error, :connection_refused}
      end)

      {:ok, result} = VariantMaintenance.verify_storage(%{})

      # Connection errors differ from not_found — recorded as errors
      assert result.errors == 1
      assert result.missing == 0
    end

    test "skips variants without storage_key" do
      asset = insert_asset()
      _planned = insert_variant(asset, :thumb, "planned", nil)

      {:ok, result} = VariantMaintenance.verify_storage(%{})

      assert result.checked == 0
      assert result.present == 0
      assert result.missing == 0
    end

    test "filters by variant name when specified" do
      asset = insert_asset()
      _thumb = insert_variant(asset, :thumb, "ready", "variants/thumb.jpg")
      _large = insert_variant(asset, :large, "ready", "variants/large.jpg")

      expect(Rindle.StorageMock, :head, fn "variants/thumb.jpg", _opts ->
        {:ok, %{content_length: 1024}}
      end)

      {:ok, result} = VariantMaintenance.verify_storage(%{variant_name: "thumb"})

      assert result.checked == 1
    end

    test "does not silently flip a failed variant to missing (FSM forbids)" do
      # CR-07 regression: VariantFSM allows ready -> missing but NOT
      # failed -> missing. The verifier must classify a failed variant
      # whose object disappeared as :error, leaving its state untouched.
      asset = insert_asset()
      variant = insert_variant(asset, :thumb, "failed", "variants/thumb.jpg")

      expect(Rindle.StorageMock, :head, fn _key, _opts ->
        {:error, :not_found}
      end)

      {:ok, result} = VariantMaintenance.verify_storage(%{})

      assert result.checked == 1
      assert result.missing == 0
      assert result.errors == 1

      preserved = Rindle.Repo.get!(MediaVariant, variant.id)
      assert preserved.state == "failed"
    end

    test "does not silently flip a stale variant to missing (FSM forbids)" do
      # Same invariant: stale -> missing is not in VariantFSM allowed
      # transitions, so a not_found HEAD on a stale variant must surface
      # as an error rather than rewriting state.
      asset = insert_asset()
      variant = insert_variant(asset, :thumb, "stale", "variants/thumb.jpg")

      expect(Rindle.StorageMock, :head, fn _key, _opts ->
        {:error, :not_found}
      end)

      {:ok, result} = VariantMaintenance.verify_storage(%{})

      assert result.missing == 0
      assert result.errors == 1

      preserved = Rindle.Repo.get!(MediaVariant, variant.id)
      assert preserved.state == "stale"
    end

    test "reports summary with all counts" do
      asset = insert_asset()
      _present = insert_variant(asset, :thumb, "ready", "variants/thumb.jpg")
      _ready_large = insert_variant(asset, :large, "ready", "variants/large.jpg")

      # Use stub to handle both variants regardless of DB row order
      stub(Rindle.StorageMock, :head, fn
        "variants/thumb.jpg", _opts -> {:ok, %{}}
        "variants/large.jpg", _opts -> {:error, :not_found}
      end)

      {:ok, result} = VariantMaintenance.verify_storage(%{})

      assert result.checked == 2
      assert result.present == 1
      assert result.missing == 1
      assert result.errors == 0
    end
  end
end
