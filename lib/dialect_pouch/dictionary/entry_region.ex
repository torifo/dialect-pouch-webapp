defmodule DialectPouch.Dictionary.EntryRegion do
  @moduledoc "Join between an entry and a region. An entry may attach at any node of the region tree (country/prefecture/area)."
  use Ecto.Schema
  import Ecto.Changeset

  schema "entry_regions" do
    belongs_to :entry, DialectPouch.Dictionary.Entry
    belongs_to :region, DialectPouch.Regions.Region
  end

  @doc false
  def changeset(entry_region, attrs) do
    entry_region
    |> cast(attrs, [:entry_id, :region_id])
    |> validate_required([:entry_id, :region_id])
    |> unique_constraint([:entry_id, :region_id])
    |> foreign_key_constraint(:region_id)
  end
end
