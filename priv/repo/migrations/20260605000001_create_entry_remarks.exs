defmodule DialectPouch.Repo.Migrations.CreateEntryRemarks do
  use Ecto.Migration

  def change do
    create table(:entry_remarks) do
      add :entry_id, references(:entries, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :body, :text, null: false
      add :author_nickname, :string
      add :author_kind, :string, null: false, default: "nickname"
      add :status, :string, null: false, default: "visible"
      add :report_count, :integer, null: false, default: 0
      timestamps(type: :utc_datetime)
    end

    create index(:entry_remarks, [:entry_id])
    create index(:entry_remarks, [:status])
  end
end
