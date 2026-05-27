defmodule Rindle.OwnerErasureBatchBoundaryTest do
  use ExUnit.Case, async: true

  defmodule User do
    defstruct [:id]
  end

  test "empty owners returns empty_batch" do
    assert {:error, :empty_batch} = Rindle.preview_batch_owner_erasure([])
    assert {:error, :empty_batch} = Rindle.erase_batch_owner_erasure([])
  end

  test "over-limit unique owners returns batch_too_large with detail map" do
    owners =
      for _ <- 1..101 do
        %User{id: Ecto.UUID.generate()}
      end

    assert {:error, {:batch_too_large, %{requested: 101, max: 100}}} =
             Rindle.preview_batch_owner_erasure(owners)

    assert {:error, {:batch_too_large, %{requested: 101, max: 100}}} =
             Rindle.erase_batch_owner_erasure(owners)
  end

  test "duplicate owner structs dedupe before limit check" do
    owner = %User{id: Ecto.UUID.generate()}
    owners = List.duplicate(owner, 101)

    assert {:error, :not_implemented} =
             Rindle.preview_batch_owner_erasure(owners)
  end

  test "max_owners opt overrides default" do
    owners =
      for _ <- 1..3 do
        %User{id: Ecto.UUID.generate()}
      end

    assert {:error, {:batch_too_large, %{requested: 3, max: 2}}} =
             Rindle.preview_batch_owner_erasure(owners, max_owners: 2)
  end

  test "in-limit batch returns not_implemented stub" do
    owner = %User{id: Ecto.UUID.generate()}

    assert {:error, :not_implemented} =
             Rindle.preview_batch_owner_erasure([owner])

    assert {:error, :not_implemented} =
             Rindle.erase_batch_owner_erasure([owner])
  end
end
