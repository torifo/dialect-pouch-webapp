defmodule DialectPocket.Regions do
  @moduledoc """
  The Regions context: the hierarchical region tree (country > prefecture > area).

  Subtree queries use the materialized `path` with prefix matching, so
  "this region and everything beneath it" is a single indexed query.
  """
  import Ecto.Query, warn: false

  alias DialectPocket.Repo
  alias DialectPocket.Regions.Region

  @doc """
  Create a region.

  When a `parent_id` is given, the new `path` must be exactly one label below
  the parent's path (e.g. parent `jp.aomori` → child `jp.aomori.tsugaru`). This
  keeps the two ways of walking the tree — `parent_id` (`children/1`) and the
  materialized `path` (`subtree/1`) — from ever disagreeing.
  """
  def create_region(attrs) do
    %Region{}
    |> Region.changeset(attrs)
    |> enforce_parent_path()
    |> Repo.insert()
  end

  defp enforce_parent_path(changeset) do
    parent_id = Ecto.Changeset.get_field(changeset, :parent_id)
    path = Ecto.Changeset.get_field(changeset, :path)

    cond do
      not changeset.valid? -> changeset
      is_nil(parent_id) or is_nil(path) -> changeset
      true -> validate_path_under_parent(changeset, parent_id, path)
    end
  end

  defp validate_path_under_parent(changeset, parent_id, path) do
    parent_prefix = path |> String.split(".") |> Enum.drop(-1) |> Enum.join(".")

    case Repo.get(Region, parent_id) do
      # Unknown parent: let the FK constraint produce the error on insert.
      nil ->
        changeset

      %Region{path: ^parent_prefix} ->
        changeset

      %Region{path: parent_path} ->
        Ecto.Changeset.add_error(
          changeset,
          :path,
          "must be exactly one label below the parent path (#{parent_path})"
        )
    end
  end

  @doc "Fetch a region by id (raises if missing)."
  def get_region!(id), do: Repo.get!(Region, id)

  @doc """
  Fetch a region by its materialized path. Returns `nil` for structurally
  invalid paths (guards against wildcard/garbage input from request params).
  """
  def get_region_by_path(path) do
    if Region.valid_path?(path), do: Repo.get_by(Region, path: path), else: nil
  end

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

  Structurally invalid paths return `[]` — this guards the `LIKE` query against
  `%`/`_` wildcards smuggled in via request params (e.g. `/r/:region_path`).
  Valid paths contain only `[a-z0-9-]` labels, so the prefix is wildcard-free.
  """
  def subtree(path) when is_binary(path) do
    if Region.valid_path?(path) do
      descendant_prefix = path <> ".%"

      Repo.all(
        from r in Region,
          where: r.path == ^path or like(r.path, ^descendant_prefix),
          order_by: r.path
      )
    else
      []
    end
  end

  def subtree(%Region{path: path}), do: subtree(path)

  @doc "All descendants of the region (excluding the region itself)."
  def descendants(%Region{path: path}) do
    Repo.all(from r in Region, where: like(r.path, ^(path <> ".%")), order_by: r.path)
  end

  @doc """
  Returns the ids of `path` and all of its descendants (for joins/filters).
  Structurally invalid paths return `[]` (same wildcard guard as `subtree/1`).
  """
  def subtree_ids(path) when is_binary(path) do
    if Region.valid_path?(path) do
      descendant_prefix = path <> ".%"

      Repo.all(
        from r in Region,
          where: r.path == ^path or like(r.path, ^descendant_prefix),
          select: r.id
      )
    else
      []
    end
  end
end
