defmodule DialectPouch.Repo.Migrations.CreateRegions do
  use Ecto.Migration

  def change do
    create table(:regions) do
      add :name, :string, null: false
      add :level, :string, null: false
      add :code, :string
      # Materialized path of dot-separated labels, e.g. "jp.aomori.tsugaru".
      # (ltree extension is available but we use text-path to avoid Postgrex friction
      #  at MVP scale; subtree queries use prefix matching.)
      add :path, :string, null: false
      add :parent_id, references(:regions, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    # PostGIS geometry column kept for future map-polygon rendering.
    # Not mapped in the Ecto schema at MVP (no read/write from Elixir yet).
    execute(
      "ALTER TABLE regions ADD COLUMN geom geometry(Geometry, 4326)",
      "ALTER TABLE regions DROP COLUMN geom"
    )

    create unique_index(:regions, [:path])
    create index(:regions, [:parent_id])
    create index(:regions, [:level])
    # Prefix-search index for subtree queries (path LIKE 'ancestor.%').
    execute(
      "CREATE INDEX regions_path_prefix ON regions (path text_pattern_ops)",
      "DROP INDEX regions_path_prefix"
    )

    execute(
      "CREATE INDEX regions_geom_gist ON regions USING gist (geom)",
      "DROP INDEX regions_geom_gist"
    )
  end
end
