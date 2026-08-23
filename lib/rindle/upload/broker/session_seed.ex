defmodule Rindle.Upload.Broker.SessionSeed do
  @moduledoc false

  alias Rindle.Security.StorageKey

  @type seed :: %{
          asset_id: String.t(),
          profile_name: String.t(),
          storage_key: String.t(),
          filename: String.t(),
          expires_at: DateTime.t()
        }

  @doc false
  @spec build(module(), keyword()) :: seed()
  def build(profile_module, opts) do
    profile_name = to_string(profile_module)
    filename = Keyword.get(opts, :filename, "unknown")
    asset_id = Ecto.UUID.generate()
    storage_key = StorageKey.generate(profile_name, asset_id, Path.extname(filename))
    expires_at = DateTime.add(DateTime.utc_now(), Keyword.get(opts, :expires_in, 3600), :second)

    %{
      asset_id: asset_id,
      profile_name: profile_name,
      storage_key: storage_key,
      filename: filename,
      expires_at: expires_at
    }
  end
end
