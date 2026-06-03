defmodule DialectPocket.Regions do
  @moduledoc """
  The Regions context: the hierarchical region tree (country > prefecture > area).

  Subtree queries use the materialized `path` with prefix matching, so
  "this region and everything beneath it" is a single indexed query.
  """
  import Ecto.Query, warn: false

  alias DialectPocket.Repo
  alias DialectPocket.Regions.Region

  @doc "Create a region."
  def create_region(attrs) do
    %Region{}
    |> Region.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Fetch a region by id (raises if missing)."
  def get_region!(id), do: Repo.get!(Region, id)

  @doc "Fetch a region by its materialized path."
  def get_region_by_path(path), do: Repo.get_by(Region, path: path)

  @doc "Top-level regions (no parent)."
  def roots do
    Repo.all(from r in Region, where: is_nil(r.parent_id), order_by: r.name)
  end

  @doc "Direct children of the given region."
  def children(%Region{id: id}) do
    Repo.all(from r in Region, where: r.parent_id == ^id, order_by: r.name)
  end

  @doc """
  The region with the given path and all of its descendants.

  Safe because path labels are `[a-z0-9-]` only — the prefix cannot contain
  `LIKE` wildcards.
  """
  def subtree(path) when is_binary(path) do
    descendant_prefix = path <> ".%"

    Repo.all(
      from r in Region,
        where: r.path == ^path or like(r.path, ^descendant_prefix),
        order_by: r.path
    )
  end

  def subtree(%Region{path: path}), do: subtree(path)

  @doc "All descendants of the region (excluding the region itself)."
  def descendants(%Region{path: path}) do
    Repo.all(from r in Region, where: like(r.path, ^(path <> ".%")), order_by: r.path)
  end

  @doc "Returns the ids of `path` and all of its descendants (for joins/filters)."
  def subtree_ids(path) when is_binary(path) do
    descendant_prefix = path <> ".%"

    Repo.all(
      from r in Region,
        where: r.path == ^path or like(r.path, ^descendant_prefix),
        select: r.id
    )
  end
end
