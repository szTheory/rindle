defmodule Rindle.OwnerErasureBatchErrorTest do
  use ExUnit.Case, async: true

  alias Rindle.Error

  test "renders empty_batch message" do
    message = Error.message(%Error{action: :preview_batch_owner_erasure, reason: :empty_batch})

    assert message =~ "at least one owner struct"
    assert message =~ "preview_owner_erasure/2"
  end

  test "renders batch_too_large message with counts" do
    message =
      Error.message(%Error{
        action: :preview_batch_owner_erasure,
        reason: {:batch_too_large, %{requested: 150, max: 100}}
      })

    assert message =~ "requested: 150"
    assert message =~ "max: 100"
    assert message =~ "max_owners"
  end

  test "renders batch_owner_failed message with owner ref and completed count" do
    owner_ref = {"Elixir.Rindle.OwnerErasureBatchBoundaryTest.User", Ecto.UUID.generate()}

    message =
      Error.message(%Error{
        action: :erase_batch_owner_erasure,
        reason: {
          :batch_owner_failed,
          %{
            owner: owner_ref,
            reason: :simulated,
            partial_report: %{owners: [%{owner: owner_ref, report: %{}}]}
          }
        }
      })

    assert message =~ elem(owner_ref, 0)
    assert message =~ "1 owner(s) completed"
    assert message =~ "partial_report"
  end
end
