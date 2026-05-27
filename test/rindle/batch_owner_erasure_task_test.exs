defmodule Rindle.BatchOwnerErasureTaskTest do
  use Rindle.DataCase, async: false
  import Mox

  alias Mix.Tasks.Rindle.BatchOwnerErasure, as: Task
  alias Rindle.Domain.{MediaAsset, MediaAttachment}

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [],
      allow_mime: ["image/jpeg"],
      max_bytes: 10_485_760
  end

  defmodule User do
    defstruct [:id]
  end

  @owner_type "Elixir.Rindle.BatchOwnerErasureTaskTest.User"

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
    path = Path.join(System.tmp_dir!(), "rindle-owners-#{System.unique_integer([:positive])}.json")
    File.write!(path, Jason.encode!(entries))

    on_exit(fn -> File.rm(path) end)

    path
  end

  defp insert_asset(storage_key) do
    %MediaAsset{}
    |> MediaAsset.changeset(%{
      state: "available",
      profile: to_string(TestProfile),
      storage_key: storage_key
    })
    |> Repo.insert!()
  end

  defp insert_attachment(asset, owner, slot) do
    %MediaAttachment{}
    |> MediaAttachment.changeset(%{
      asset_id: asset.id,
      owner_type: @owner_type,
      owner_id: owner.id,
      slot: slot
    })
    |> Repo.insert!()
  end
end
