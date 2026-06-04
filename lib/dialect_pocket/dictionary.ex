defmodule DialectPocket.Dictionary do
  @moduledoc """
  The Dictionary context: dialect entries, their senses/examples, region links,
  and provenance.

  Every entry is created together with its provenance (a hard requirement — no
  entry exists without a recorded source). Only `:published` entries are public;
  `get_published_*` enforces that gate, while the `*_admin` variants see all
  statuses for moderation.
  """
  import Ecto.Query, warn: false

  alias DialectPocket.Repo
  alias DialectPocket.Regions
  alias DialectPocket.Dictionary.{Entry, EntryRegion}

  @preloads [:senses, :examples, :provenance, entry_regions: :region]

  @doc """
  Create an entry with its senses/examples/provenance (in `attrs`) and link it
  to the given region ids, atomically.

  `attrs` must include a `provenance` map (enforced by the changeset). A unique
  slug is derived from `attrs.slug` (or the headword) — collisions get a numeric
  suffix so homographs across regions each get a stable permalink.

  Returns `{:ok, entry}` or `{:error, reason}`.
  """
  def create_entry(attrs, region_ids \\ []) do
    attrs = Map.put(attrs, :slug, unique_slug(slug_base(attrs)))

    Repo.transaction(fn ->
      entry =
        %Entry{}
        |> Entry.changeset(attrs)
        |> Repo.insert()
        |> unwrap!()

      Enum.each(region_ids, fn region_id ->
        %EntryRegion{}
        |> EntryRegion.changeset(%{entry_id: entry.id, region_id: region_id})
        |> Repo.insert()
        |> unwrap!()
      end)

      entry
    end)
  end

  defp unwrap!({:ok, struct}), do: struct
  defp unwrap!({:error, changeset}), do: Repo.rollback(changeset)

  defp slug_base(attrs) do
    (attrs[:slug] || attrs["slug"] || attrs[:headword] || attrs["headword"] || "")
    |> to_string()
    |> String.trim()
    |> String.replace(~r/\s+/u, "-")
  end

  defp unique_slug(base) when base in [nil, ""], do: Ecto.UUID.generate()

  defp unique_slug(base) do
    if Repo.exists?(from e in Entry, where: e.slug == ^base) do
      # base contains no LIKE wildcards in practice (headword + [a-z0-9-] hint).
      n = Repo.one(from e in Entry, where: like(e.slug, ^(base <> "-%")), select: count())
      "#{base}-#{n + 2}"
    else
      base
    end
  end

  @doc "Mark an entry published."
  def publish_entry(%Entry{} = entry) do
    entry |> Ecto.Changeset.change(status: :published) |> Repo.update()
  end

  @doc "Mark an entry rejected (kept, not deleted)."
  def reject_entry(%Entry{} = entry) do
    entry |> Ecto.Changeset.change(status: :rejected) |> Repo.update()
  end

  @doc "Public lookup: only returns a `:published` entry."
  def get_published_by_slug(slug) do
    Repo.one(
      from e in Entry,
        where: e.slug == ^slug and e.status == :published,
        preload: ^@preloads
    )
  end

  @doc "Admin lookup: any status."
  def get_by_slug_admin(slug) do
    Repo.one(from e in Entry, where: e.slug == ^slug, preload: ^@preloads)
  end

  @doc "Admin lookup by id (any status), preloaded."
  def get_entry!(id), do: Entry |> Repo.get!(id) |> Repo.preload(@preloads)

  @doc "List published entries (most recent first)."
  def list_published(limit \\ 50) do
    Repo.all(
      from e in Entry,
        where: e.status == :published,
        order_by: [desc: e.inserted_at],
        limit: ^limit,
        preload: ^@preloads
    )
  end

  @doc "List unmoderated (draft) entries for curators."
  def list_pending(limit \\ 100) do
    Repo.all(
      from e in Entry,
        where: e.status == :draft,
        order_by: [asc: e.inserted_at],
        limit: ^limit,
        preload: ^@preloads
    )
  end

  def count_published,
    do: Repo.one(from e in Entry, where: e.status == :published, select: count())

  @doc "Lightweight list of published slugs + update times for the sitemap."
  def published_slugs do
    Repo.all(
      from e in Entry,
        where: e.status == :published,
        select: %{slug: e.slug, updated_at: e.updated_at},
        order_by: [asc: e.slug]
    )
  end

  @doc """
  Published entries linked to `region_path` or any of its descendants
  (e.g. a prefecture page includes its area sub-regions). `[]` for unknown paths.
  """
  def list_published_in_subtree(region_path, limit \\ 200) do
    case Regions.subtree_ids(region_path) do
      [] ->
        []

      ids ->
        Repo.all(
          from e in Entry,
            join: er in EntryRegion,
            on: er.entry_id == e.id,
            where: er.region_id in ^ids and e.status == :published,
            distinct: true,
            order_by: [asc: e.headword],
            limit: ^limit,
            preload: ^@preloads
        )
    end
  end

  @doc "Count of published entries in `region_path` and its descendants."
  def count_published_in_subtree(region_path) do
    case Regions.subtree_ids(region_path) do
      [] ->
        0

      ids ->
        Repo.one(
          from e in Entry,
            join: er in EntryRegion,
            on: er.entry_id == e.id,
            where: er.region_id in ^ids and e.status == :published,
            select: count(e.id, :distinct)
        )
    end
  end
end
