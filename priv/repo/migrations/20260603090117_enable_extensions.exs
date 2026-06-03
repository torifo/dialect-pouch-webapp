defmodule DialectPocket.Repo.Migrations.EnableExtensions do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS ltree")
    execute("CREATE EXTENSION IF NOT EXISTS postgis")
    execute("CREATE EXTENSION IF NOT EXISTS pg_bigm")
  end

  def down do
    execute("DROP EXTENSION IF EXISTS pg_bigm")
    execute("DROP EXTENSION IF EXISTS postgis")
    execute("DROP EXTENSION IF EXISTS ltree")
  end
end
