defmodule Rindle.OwnerErasureBatchOptsTest do
  use ExUnit.Case, async: true

  defmodule User do
    defstruct [:id]
  end

  test "per_owner_erasure_opts/1 strips batch-only keys" do
    assert Rindle.per_owner_erasure_opts(max_owners: 2, force: false) == [force: false]
    assert Rindle.per_owner_erasure_opts([]) == []
  end
end

defmodule Rindle.OwnerErasureBatchOptsIntegrationTest do
  use Rindle.DataCase, async: false

  defmodule User do
    defstruct [:id]
  end

  test "batch preview forwards per-owner opts without changing preview output" do
    owner = %User{id: Ecto.UUID.generate()}

    assert {:ok, baseline} = Rindle.preview_batch_owner_erasure([owner])
    assert {:ok, with_opts} = Rindle.preview_batch_owner_erasure([owner], life06_prep_probe: true)

    assert with_opts.mode == baseline.mode
    assert with_opts.attachments_to_detach == baseline.attachments_to_detach
    assert with_opts.assets_to_purge == baseline.assets_to_purge
    assert with_opts.retained_shared_assets == baseline.retained_shared_assets
  end

  test "max_owners remains a batch boundary opt and is not forwarded" do
    owners =
      for _ <- 1..3 do
        %User{id: Ecto.UUID.generate()}
      end

    assert {:error, {:batch_too_large, %{requested: 3, max: 2}}} =
             Rindle.preview_batch_owner_erasure(owners, max_owners: 2, life06_prep_probe: true)
  end
end
