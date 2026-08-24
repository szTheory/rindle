defmodule Rindle.UploadMaintenanceCase do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      use Rindle.DataCase, async: false
      import Mox

      import Rindle.UploadMaintenanceCase,
        only: [
          create_asset: 0,
          create_asset: 1,
          create_session: 2,
          create_multipart_session: 2,
          create_resumable_session: 2,
          create_tus_session: 2,
          expired_at: 0
        ]

      alias Ecto.Adapters.SQL.Sandbox
      alias Rindle.Adopter.CanonicalApp.Repo, as: AdopterRepo
      alias Rindle.Domain.{MediaAsset, MediaUploadSession}
      alias Rindle.Domain.UploadSessionFSM
      alias Rindle.Ops.UploadMaintenance
      alias Rindle.UploadMaintenanceCase.{RepoProbe, TestProfile}

      @moduletag async_safety_allow: [:global_repo_swap]

      setup :set_mox_from_context
      setup :verify_on_exit!

      setup do
        previous_repo = Application.get_env(:rindle, :repo)
        previous_probe_owner = Application.get_env(:rindle, :repo_probe_owner)

        case start_supervised(AdopterRepo) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
        end

        Sandbox.checkout(AdopterRepo)
        Sandbox.mode(AdopterRepo, {:shared, self()})

        Application.put_env(:rindle, :repo, RepoProbe)
        Application.put_env(:rindle, :repo_probe_owner, self())

        on_exit(fn ->
          restore_env(:repo, previous_repo)
          restore_env(:repo_probe_owner, previous_probe_owner)
        end)

        :ok
      end

      defp restore_env(key, nil), do: Application.delete_env(:rindle, key)
      defp restore_env(key, value), do: Application.put_env(:rindle, key, value)
    end
  end

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [thumb: [mode: :crop, width: 100, height: 100]],
      allow_mime: ["image/jpeg"],
      max_bytes: 10_485_760
  end

  defmodule RepoProbe do
    @moduledoc false

    alias Rindle.Adopter.CanonicalApp.Repo, as: AdopterRepo

    def all(queryable), do: observe(:all, fn -> AdopterRepo.all(queryable) end)

    def delete(struct),
      do: observe({:delete, struct.__struct__}, fn -> AdopterRepo.delete(struct) end)

    def update(changeset),
      do: observe({:update, changeset.data.__struct__}, fn -> AdopterRepo.update(changeset) end)

    def preload(struct_or_structs, preloads),
      do:
        observe({:preload, preloads}, fn -> AdopterRepo.preload(struct_or_structs, preloads) end)

    defp observe(event, operation) do
      if owner = Application.get_env(:rindle, :repo_probe_owner),
        do: send(owner, {:repo_probe, event})

      operation.()
    end
  end

  alias Rindle.Adopter.CanonicalApp.Repo, as: AdopterRepo
  alias Rindle.Domain.{MediaAsset, MediaUploadSession}

  def create_asset(overrides \\ %{}) do
    %MediaAsset{}
    |> MediaAsset.changeset(
      Map.merge(
        %{
          state: "staged",
          profile: to_string(TestProfile),
          storage_key: "uploads/#{Ecto.UUID.generate()}.jpg"
        },
        overrides
      )
    )
    |> AdopterRepo.insert!()
  end

  def create_session(asset, overrides) do
    %MediaUploadSession{}
    |> MediaUploadSession.changeset(
      Map.merge(
        %{
          asset_id: asset.id,
          state: "initialized",
          upload_key: asset.storage_key,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        },
        overrides
      )
    )
    |> AdopterRepo.insert!()
  end

  def create_multipart_session(asset, overrides) do
    create_session(
      asset,
      Map.merge(
        %{
          upload_strategy: "multipart",
          multipart_upload_id: "upload-#{System.unique_integer([:positive])}"
        },
        overrides
      )
    )
  end

  def create_resumable_session(asset, overrides) do
    create_session(
      asset,
      Map.merge(
        %{
          state: "resuming",
          upload_strategy: "resumable",
          session_uri: "https://storage.example/upload/#{System.unique_integer([:positive])}",
          session_uri_expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        },
        overrides
      )
    )
  end

  def create_tus_session(asset, overrides) do
    create_session(
      asset,
      Map.merge(
        %{
          state: "signed",
          upload_strategy: "resumable",
          resumable_protocol: "tus",
          multipart_upload_id: "tus-upload-#{System.unique_integer([:positive])}"
        },
        overrides
      )
    )
  end

  def expired_at, do: DateTime.add(DateTime.utc_now(), -100, :second)
end
