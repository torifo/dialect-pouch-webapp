defmodule DialectPocket.Dictionary.Example do
  @moduledoc "A usage example for a dialect entry."
  use Ecto.Schema
  import Ecto.Changeset

  schema "examples" do
    field :text, :string
    field :translation, :string
    belongs_to :entry, DialectPocket.Dictionary.Entry
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(example, attrs) do
    example
    |> cast(attrs, [:text, :translation])
    |> validate_required([:text])
  end
end
