defmodule DialectPocket.Dictionary.Search do
  @moduledoc """
  Full-text search over published dictionary entries.

  Uses PostgreSQL's pg_bigm GIN index on `entries.norm` and `senses.gloss`
  via LIKE pattern matching. Wildcards in user input are escaped before use.
  """

  import Ecto.Query, warn: false

  alias DialectPocket.Repo
  alias DialectPocket.Dictionary.Entry

  @preloads [:senses, :examples, :provenance, entry_regions: :region]

  @doc """
  Search published entries whose `norm` or any sense `gloss` contains `query`.

  Returns `[]` for blank queries. Options:
  - `:limit` – maximum number of results (default `50`)
  """
  @spec search(String.t(), keyword()) :: [Entry.t()]
  def search(query, opts \\ []) do
    trimmed = String.trim(query)

    if trimmed == "" do
      []
    else
      limit = Keyword.get(opts, :limit, 50)
      pattern = "%" <> escape_like(trimmed) <> "%"

      Repo.all(
        from e in Entry,
          where:
            e.status == :published and
              (like(e.norm, ^pattern) or
                 fragment(
                   "EXISTS (SELECT 1 FROM senses s WHERE s.entry_id = ? AND s.gloss LIKE ?)",
                   e.id,
                   ^pattern
                 )),
          order_by: [asc: e.headword],
          limit: ^limit,
          preload: ^@preloads
      )
    end
  end

  # Escape LIKE wildcard and backslash characters so pg_bigm uses them literally.
  # PostgreSQL's default LIKE escape character is backslash.
  defp escape_like(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end
end
