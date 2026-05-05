defmodule Rindle.AV.TempRunDir do
  @moduledoc false

  @spec create() :: {:ok, Path.t()} | {:error, term()}
  def create do
    path = Path.join(root_dir(), Ecto.UUID.generate())

    case File.mkdir_p(path) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec child(Path.t(), Path.t()) :: Path.t()
  def child(run_dir, filename), do: Path.join(run_dir, filename)

  @spec cleanup(Path.t()) :: :ok | {:error, term()}
  def cleanup(run_dir) do
    case File.rm_rf(run_dir) do
      {:ok, _paths} -> :ok
      {:error, reason, _path} -> {:error, reason}
    end
  end

  @spec root_dir() :: Path.t()
  def root_dir do
    Application.get_env(:rindle, :tmp_dir, System.tmp_dir!())
    |> Path.join("Rindle.tmp")
  end
end
