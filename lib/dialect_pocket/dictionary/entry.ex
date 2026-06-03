defmodule DialectPocket.Dictionary.Entry do
  @moduledoc """
  A dialect headword/phrase. `norm` is a normalized search field (headword +
  reading, lowercased) indexed with pg_bigm. `status` gates publication:
  only `:published` entries are public.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias DialectPocket.Dictionary.{Sense, Example, Provenance, EntryRegion}

  @statuses [:draft, :published, :rejected]

  schema "entries" do
    field :slug, :string
    field :headword, :string
    field :reading, :string
    field :norm, :string
    field :status, Ecto.Enum, values: @statuses, default: :draft

    has_many :senses, Sense
    has_many :examples, Example
    has_many :entry_regions, EntryRegion
    has_one :provenance, Provenance

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  @doc false
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:slug, :headword, :reading, :status])
    |> validate_required([:headword])
    |> put_norm()
    |> cast_assoc(:senses, with: &Sense.changeset/2)
    |> cast_assoc(:examples, with: &Example.changeset/2)
    |> cast_assoc(:provenance, required: true, with: &Provenance.changeset/2)
    |> validate_required([:slug, :norm])
    |> unique_constraint(:slug)
  end

  defp put_norm(changeset) do
    headword = get_field(changeset, :headword)
    reading = get_field(changeset, :reading)

    norm =
      [headword, reading]
      |> Enum.reject(&(is_nil(&1) or &1 == ""))
      |> Enum.join(" ")
      |> String.downcase()

    put_change(changeset, :norm, norm)
  end
end
