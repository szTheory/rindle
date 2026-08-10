defmodule Rindle.TestSupport.HostObanMigration do
  @moduledoc false

  use Ecto.Migration

  # The test application is the host here. Keep its Oban schema bootstrap
  # separate from Rindle's packaged migrations, which intentionally no longer
  # own `public.oban_jobs`.
  def up, do: Oban.Migration.up()
  def down, do: Oban.Migration.down(version: 1)
end
