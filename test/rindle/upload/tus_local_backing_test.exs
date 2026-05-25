defmodule Rindle.Upload.TusLocalBackingTest do
  @moduledoc """
  Proves the Local tmp-append → atomic-rename → UNCHANGED `verify_completion/2`
  promotion lane that `TusPlug` completion converges into (D-08): append grows the
  `.part` file, `tus_complete/3` atomic-renames it into the final key, and the
  existing `verify_completion/2` promotes the asset (byte_size set, PromoteAsset
  enqueued) via the legal `signed → verifying → completed` FSM edge.
  """

  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Adopter.CanonicalApp.Repo

  alias Ecto.Adapters.SQL.Sandbox
  alias Rindle.Adopter.CanonicalApp.Repo, as: AdopterRepo
  alias Rindle.Domain.MediaUploadSession
  alias Rindle.Storage.Local
  alias Rindle.Upload.Broker

  defmodule TusProfile do
    use Rindle.Profile,
      storage: Local,
      variants: [thumb: [mode: :crop, width: 100, height: 100]],
      allow_mime: ["image/jpeg"],
      max_bytes: 10_485_760
  end

  setup do
    case start_supervised(AdopterRepo) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    Sandbox.checkout(AdopterRepo)
    Sandbox.mode(AdopterRepo, {:shared, self()})

    previous_repo = Application.get_env(:rindle, :repo)
    Application.put_env(:rindle, :repo, AdopterRepo)

    root =
      Path.join(System.tmp_dir!(), "rindle-tus-backing-#{System.unique_integer([:positive])}")

    File.mkdir_p!(root)

    on_exit(fn ->
      File.rm_rf(root)

      case previous_repo do
        nil -> Application.delete_env(:rindle, :repo)
        value -> Application.put_env(:rindle, :repo, value)
      end
    end)

    {:ok, root: root}
  end

  test "append → atomic-rename → verify_completion promotes with byte_size set", %{root: root} do
    opts = [root: root]
    {:ok, %{session: session}} = Broker.initiate_tus_upload(TusProfile)
    body = "0123456789abcdef"

    # 1. Append two chunks to the tmp .part file (never buffered whole).
    assert :ok = Local.tus_append(session.id, "01234567", opts)
    assert :ok = Local.tus_append(session.id, "89abcdef", opts)
    part_path = Local.tus_part_path(session.id, opts)
    assert File.stat!(part_path).size == byte_size(body)

    # 2. Atomic same-filesystem rename into the final storage key.
    assert {:ok, final_path} = Local.tus_complete(session.id, session.upload_key, opts)
    refute File.exists?(part_path)
    assert File.exists?(final_path)
    assert File.stat!(final_path).size == byte_size(body)
    assert File.read!(final_path) == body

    # 3. Converge into the UNCHANGED verify_completion/2 lane (signed → verifying → completed).
    assert {:ok, %{session: completed, asset: promoted}} =
             Broker.verify_completion(session.id, opts)

    assert completed.state == "completed"
    assert promoted.state == "validating"
    assert promoted.byte_size == byte_size(body)

    # Persisted state reflects the convergence (the session never sat in "resuming").
    assert AdopterRepo.get!(MediaUploadSession, session.id).state == "completed"
  end
end
