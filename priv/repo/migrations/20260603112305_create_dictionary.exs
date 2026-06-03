defmodule DialectPocket.Repo.Migrations.CreateDictionary do
  use Ecto.Migration

  def change do
    create table(:entries) do
      add :slug, :string, null: false
      add :headword, :string, null: false
      add :reading, :string
      add :norm, :string, null: false
      add :status, :string, null: false, default: "draft"
      timestamps(type: :utc_datetime)
    end

    create unique_index(:entries, [:slug])
    create index(:entries, [:status])

    execute(
      "CREATE INDEX entries_norm_bigm ON entries USING gin (norm gin_bigm_ops)",
      "DROP INDEX entries_norm_bigm"
    )

    execute(
      "CREATE INDEX entries_reading_bigm ON entries USING gin (reading gin_bigm_ops)",
      "DROP INDEX entries_reading_bigm"
    )

    create table(:senses) do
      add :entry_id, references(:entries, on_delete: :delete_all), null: false
      add :gloss, :string, null: false
      add :standard_lemma, :string
      add :note, :string
      timestamps(type: :utc_datetime)
    end

    create index(:senses, [:entry_id])
    create index(:senses, [:standard_lemma])

    execute(
      "CREATE INDEX senses_gloss_bigm ON senses USING gin (gloss gin_bigm_ops)",
      "DROP INDEX senses_gloss_bigm"
    )

    create table(:examples) do
      add :entry_id, references(:entries, on_delete: :delete_all), null: false
      add :text, :string, null: false
      add :translation, :string
      timestamps(type: :utc_datetime)
    end

    create index(:examples, [:entry_id])

    create table(:entry_regions) do
      add :entry_id, references(:entries, on_delete: :delete_all), null: false
      add :region_id, references(:regions, on_delete: :delete_all), null: false
    end

    create unique_index(:entry_regions, [:entry_id, :region_id])
    create index(:entry_regions, [:region_id])

    create table(:provenances) do
      add :entry_id, references(:entries, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :reliability, :string, null: false, default: "unverified"
      add :verified, :boolean, null: false, default: false
      add :source_platform, :string
      add :source_url, :string
      add :source_license, :string
      add :observed_author, :string
      add :observed_at, :date
      timestamps(type: :utc_datetime)
    end

    create unique_index(:provenances, [:entry_id])
    create index(:provenances, [:kind])
  end
end
