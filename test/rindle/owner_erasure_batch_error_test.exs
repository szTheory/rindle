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
end
