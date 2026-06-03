defmodule DialectPocket.Regions.Region do
  @moduledoc """
  A node in the region hierarchy (country > prefecture > area/dialect-zone).

  `path` is a materialized path of dot-separated labels, e.g. `"jp.aomori.tsugaru"`.
  Labels are restricted to `[a-z0-9-]` so the path is safe to use directly as a
  `LIKE` prefix for subtree queries (no `_`/`%` wildcards can sneak in).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @levels [:country, :prefecture, :area]

  @type t :: %__MODULE__{}

  schema "regions" do
    field :name, :string
    field :level, Ecto.Enum, values: @levels
    field :code, :string
    field :path, :string
    belongs_to :parent, __MODULE__

    timestamps(type: :utc_datetime)
  end

  @path_format ~r/^[a-z0-9-]+(\.[a-z0-9-]+)*$/

  def levels, do: @levels

  @doc """
  Whether a string is a structurally valid region path
  (dot-separated `[a-z0-9-]` labels). Use this to guard raw, externally
  supplied path arguments before they reach a `LIKE` query.
  """
  def valid_path?(path) when is_binary(path), do: Regex.match?(@path_format, path)
  def valid_path?(_), do: false

  @doc false
  def changeset(region, attrs) do
    region
    |> cast(attrs, [:name, :level, :code, :path, :parent_id])
    |> validate_required([:name, :level, :path])
    |> validate_format(:path, @path_format, message: "must be dot-separated [a-z0-9-] labels")
    |> unique_constraint(:path)
    |> foreign_key_constraint(:parent_id)
  end
end
