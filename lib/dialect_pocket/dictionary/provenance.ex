defmodule DialectPocket.Dictionary.Provenance do
  @moduledoc """
  Where an entry's information comes from — a first-class citizen.

  `kind` distinguishes the source type; `:community` covers SNS / aggregator /
  individual posts adopted with a pointer (`source_url` + optional
  `observed_author`) rather than republished content. `reliability` drives the
  UI "出典:○○(真偽未確認)" badge: anything other than `:verified` is shown as
  unconfirmed and visually separated from confirmed data.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @kinds [:open_data, :manual, :user, :llm_assisted, :community]
  @reliabilities [:verified, :unverified, :community]

  schema "provenances" do
    field :kind, Ecto.Enum, values: @kinds
    field :reliability, Ecto.Enum, values: @reliabilities, default: :unverified
    field :verified, :boolean, default: false
    field :source_platform, :string
    field :source_url, :string
    field :source_license, :string
    field :observed_author, :string
    field :observed_at, :date
    belongs_to :entry, DialectPocket.Dictionary.Entry
    timestamps(type: :utc_datetime)
  end

  def kinds, do: @kinds
  def reliabilities, do: @reliabilities

  @doc false
  def changeset(provenance, attrs) do
    provenance
    |> cast(attrs, [
      :kind,
      :reliability,
      :verified,
      :source_platform,
      :source_url,
      :source_license,
      :observed_author,
      :observed_at
    ])
    |> validate_required([:kind, :reliability])
  end
end
