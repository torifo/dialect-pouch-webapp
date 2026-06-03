defmodule DialectPocket.Dictionary.Sense do
  @moduledoc "A meaning of a dialect entry. `standard_lemma` is the normalized standard-Japanese term used for standard→dialect conversion lookups."
  use Ecto.Schema
  import Ecto.Changeset

  schema "senses" do
    field :gloss, :string
    field :standard_lemma, :string
    field :note, :string
    belongs_to :entry, DialectPocket.Dictionary.Entry
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(sense, attrs) do
    sense
    |> cast(attrs, [:gloss, :standard_lemma, :note])
    |> validate_required([:gloss])
  end
end
