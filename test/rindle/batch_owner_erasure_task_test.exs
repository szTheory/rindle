defmodule Rindle.BatchOwnerErasureTaskTest do
  use Rindle.DataCase, async: true
  import Mox
  import Rindle.Test.OwnerErasureBatchFixtures

  alias Mix.Tasks.Rindle.BatchOwnerErasure, as: Task
  alias Rindle.Domain.MediaAttachment
  alias Rindle.Test.CountingFailingTxnRepo
  alias Rindle.Test.OwnerErasureBatchFixtures, as: Fixtures
  alias Rindle.Test.OwnerErasureBatchFixtures.User

  @owner_type "Elixir.#{inspect(Fixtures.user_module())}"

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    previous_shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)

    on_exit(fn -> Mix.shell(previous_shell) end)
    :ok
  end

  test "missing --owners-file exits 1" do
    assert catch_exit(Task.run([])) == {:shutdown, 1}

    assert_received {:mix_shell, :error, [msg]}
    assert msg =~ "--owners-file"
  end

  test "default run previews and prints dry run banner" do
    owner = %User{id: Ecto.UUID.generate()}
    asset = insert_asset("assets/task-preview/original.jpg")
    attachment = insert_attachment(asset, owner, "avatar")
    path = write_owners_file!([owner])

    Task.run(["--owners-file", path])

    assert_received {:mix_shell, :info, [header]}
    assert header =~ "[DRY RUN]"
    assert_received {:mix_shell, :info, [_owners_line]}
    assert_received {:mix_shell, :info, [detach_line]}
    assert detach_line =~ "attachments_to_detach"
    assert Repo.get(MediaAttachment, attachment.id)
  end

  test "--execute runs destructive batch" do
    owner = %User{id: Ecto.UUID.generate()}
    asset = insert_asset("assets/task-execute/original.jpg")
    attachment = insert_attachment(asset, owner, "avatar")
    path = write_owners_file!([owner])

    Task.run(["--owners-file", path, "--execute"])

    refute Repo.get(MediaAttachment, attachment.id)

    assert_received {:mix_shell, :info, [line]}
    refute line =~ "[DRY RUN]"
  end

  test "--format json emits batch report" do
    owner = %User{id: Ecto.UUID.generate()}
    asset = insert_asset("assets/task-json/original.jpg")
    insert_attachment(asset, owner, "avatar")
    path = write_owners_file!([owner])

    Task.run(["--owners-file", path, "--format", "json"])

    assert_received {:mix_shell, :info, [output]}
    decoded = Jason.decode!(output)
    assert Map.has_key?(decoded, "attachments_to_detach")
    assert Map.has_key?(decoded, "owners")
  end

  test "invalid owners file exits 1 before facade" do
    path = write_owners_file_content!("[]")

    assert catch_exit(Task.run(["--owners-file", path])) == {:shutdown, 1}

    assert_received {:mix_shell, :error, [msg]}
    assert msg =~ "owner"
  end

  describe "PROOF-06: partial failure" do
    test "execute prints partial report then batch_owner_failed error and exits 1" do
      owner1 = %User{id: Ecto.UUID.generate()}
      owner2 = %User{id: Ecto.UUID.generate()}
      asset1 = insert_asset("assets/task-partial-1/original.jpg")
      asset2 = insert_asset("assets/task-partial-2/original.jpg")
      _attachment1 = insert_attachment(asset1, owner1, "avatar")
      _attachment2 = insert_attachment(asset2, owner2, "banner")
      path = write_owners_file!([owner1, owner2])

      CountingFailingTxnRepo.with_counting_repo(2, fn ->
        assert catch_exit(Task.run(["--owners-file", path, "--execute"])) == {:shutdown, 1}

        assert_received {:mix_shell, :info, ["Batch owner erasure report:"]}
        assert_received {:mix_shell, :info, [owners_line]}
        assert owners_line =~ "owners:"
        assert owners_line =~ "1"
        refute owners_line =~ "[DRY RUN]"

        assert_received {:mix_shell, :info, [detach_line]}
        assert detach_line =~ "attachments_to_detach"

        owner_line = "  - #{@owner_type}:#{owner1.id}"
        assert_received {:mix_shell, :info, [^owner_line]}

        assert_received {:mix_shell, :error, [error_msg]}
        assert error_msg =~ "Batch owner erasure stopped because owner"
        assert error_msg =~ "#{@owner_type}:#{owner2.id}"
        assert error_msg =~ "1 owner(s) completed successfully"
        assert error_msg =~ "partial_report"
        assert error_msg =~ "Completed owners remain committed"
      end)
    end
  end

  test "unknown owner_type module exits 1" do
    path =
      write_owners_file_content!([
        %{
          "owner_type" => "Elixir.Nonexistent.Module",
          "owner_id" => Ecto.UUID.generate()
        }
      ])

    assert catch_exit(Task.run(["--owners-file", path])) == {:shutdown, 1}

    assert_received {:mix_shell, :error, [msg]}
    assert msg =~ "owner_type" or msg =~ "Unknown" or msg =~ "atom"
  end

  defp write_owners_file!(owners) do
    entries =
      Enum.map(owners, fn owner ->
        %{"owner_type" => @owner_type, "owner_id" => owner.id}
      end)

    write_owners_file_content!(entries)
  end

  defp write_owners_file_content!(entries) do
    path =
      Path.join(System.tmp_dir!(), "rindle-owners-#{System.unique_integer([:positive])}.json")

    File.write!(path, Jason.encode!(entries))

    on_exit(fn -> File.rm(path) end)

    path
  end
end
