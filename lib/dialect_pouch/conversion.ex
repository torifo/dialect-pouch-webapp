defmodule DialectPouch.Conversion do
  @moduledoc """
  Standard-Japanese → dialect conversion, by **dictionary lookup only**.

  This module never *generates* dialect: every result is backed by a published
  entry with recorded provenance. When nothing matches, the conversion returns
  an empty result rather than a plausible-sounding guess — that "no lies"
  property is the whole point of the app.

  Two entry points:

    * `convert_word/2`   – the primary feature: a standard term → ranked dialect
      candidates (each with regions + provenance).
    * `convert_sentence/2` – a secondary feature: greedy longest-match
      replacement of standard lemmas inside free text, returned as segments.

  Both optionally narrow to a region subtree via a materialized `region_path`.
  """

  import Ecto.Query, warn: false

  alias DialectPouch.Repo
  alias DialectPouch.Regions
  alias DialectPouch.Dictionary.Entry

  @typedoc "A dialect candidate for a standard word."
  @type candidate :: %{
          headword: String.t(),
          reading: String.t() | nil,
          slug: String.t(),
          gloss: String.t() | nil,
          regions: [String.t()],
          provenance: provenance_info() | nil
        }

  @type provenance_info :: %{
          kind: atom() | nil,
          reliability: atom() | nil,
          source_platform: String.t() | nil,
          source_url: String.t() | nil,
          source_license: String.t() | nil,
          observed_at: Date.t() | nil
        }

  @typedoc "A segment produced by `convert_sentence/2`."
  @type segment ::
          {:plain, binary()}
          | {:match, %{standard: binary(), dialects: [binary()], chosen: binary()}}

  @doc """
  Normalize a standard-Japanese term for comparison/lookup.

  Trims surrounding whitespace, drops a leading "〜" (a common lemma marker),
  and lowercases (matters only for embedded latin characters).
  """
  @spec normalize(String.t() | nil) :: String.t()
  def normalize(nil), do: ""

  def normalize(input) when is_binary(input) do
    input
    |> String.trim()
    |> String.replace_leading("〜", "")
    |> String.trim()
    |> String.downcase()
  end

  @doc """
  Standard word → dialect candidates (primary feature).

  Matches **published** entries that have a sense whose `standard_lemma` equals
  the normalized term, or whose `gloss` contains it (LIKE, wildcards escaped).
  When `region_path` is non-nil, results are limited to entries linked to a
  region in that path's subtree (`Regions.subtree_ids/1`); an empty/invalid
  subtree yields `[]`.

  Returns a (deduplicated) list of `t:candidate/0`. Returns `[]` for a blank
  term or when nothing matches — no generation.
  """
  @spec convert_word(String.t() | nil, String.t() | nil) :: [candidate()]
  def convert_word(standard, region_path \\ nil) do
    term = normalize(standard)

    cond do
      term == "" ->
        []

      true ->
        case region_filter(region_path) do
          :no_filter -> run_word_query(term, nil)
          {:ids, []} -> []
          {:ids, ids} -> run_word_query(term, ids)
        end
    end
  end

  defp run_word_query(term, region_ids) do
    pattern = "%" <> escape_like(term) <> "%"

    base =
      from e in Entry,
        where: e.status == :published,
        join: s in assoc(e, :senses),
        on: s.standard_lemma == ^term or like(s.gloss, ^pattern),
        distinct: true,
        order_by: [asc: e.headword],
        preload: [:senses, :provenance, entry_regions: :region]

    query =
      case region_ids do
        nil ->
          base

        ids ->
          from [e, _s] in base,
            join: er in assoc(e, :entry_regions),
            on: er.region_id in ^ids
      end

    query
    |> Repo.all()
    |> Enum.map(&to_candidate(&1, term))
  end

  defp to_candidate(%Entry{} = entry, term) do
    %{
      headword: entry.headword,
      reading: entry.reading,
      slug: entry.slug,
      gloss: pick_gloss(entry.senses, term),
      regions: entry.entry_regions |> Enum.map(& &1.region.name) |> Enum.uniq(),
      provenance: provenance_info(entry.provenance)
    }
  end

  # Prefer the sense whose standard_lemma matches; otherwise the first gloss.
  defp pick_gloss(senses, term) when is_list(senses) and term != "" do
    case Enum.find(senses, &(normalize(&1.standard_lemma) == term)) do
      %{gloss: gloss} -> gloss
      _ -> first_gloss(senses)
    end
  end

  defp pick_gloss(senses, _term) when is_list(senses), do: first_gloss(senses)
  defp pick_gloss(_, _), do: nil

  defp first_gloss([]), do: nil
  defp first_gloss([%{gloss: gloss} | _]), do: gloss
  defp first_gloss(_), do: nil

  defp provenance_info(nil), do: nil

  defp provenance_info(p) do
    %{
      kind: p.kind,
      reliability: p.reliability,
      source_platform: p.source_platform,
      source_url: p.source_url,
      source_license: p.source_license,
      observed_at: p.observed_at
    }
  end

  @doc """
  Replace standard lemmas inside free text by greedy longest match (secondary
  feature). Morphology-free: scans by codepoint position and, at each position,
  takes the longest `standard_lemma` that starts there.

  Returns a list of `t:segment/0`. Matched spans become
  `{:match, %{standard, dialects, chosen}}` (`dialects` = all candidate
  headwords, `chosen` = the first); everything else stays `{:plain, _}`,
  unchanged. A blank text or an empty lemma set yields `[{:plain, text}]`.
  """
  @spec convert_sentence(String.t() | nil, String.t() | nil) :: [segment()]
  def convert_sentence(text, region_path \\ nil)

  def convert_sentence(nil, _region_path), do: [{:plain, ""}]

  def convert_sentence(text, region_path) when is_binary(text) do
    lemma_map = lemma_headwords(region_path)

    if text == "" or map_size(lemma_map) == 0 do
      [{:plain, text}]
    else
      lemmas_desc =
        lemma_map
        |> Map.keys()
        |> Enum.sort_by(&String.length/1, :desc)

      text
      |> scan(lemmas_desc, lemma_map, [], "")
      |> Enum.reverse()
    end
  end

  # Greedy longest-match scan. `acc` is the reversed segment list, `pending`
  # is the accumulated (unmatched) plain run preceding the cursor.
  defp scan("", _lemmas, _map, acc, pending) do
    flush(acc, pending)
  end

  defp scan(rest, lemmas, map, acc, pending) do
    case longest_prefix(rest, lemmas) do
      nil ->
        # No lemma starts here: consume one grapheme into the pending run.
        {grapheme, tail} = next_grapheme(rest)
        scan(tail, lemmas, map, acc, pending <> grapheme)

      lemma ->
        dialects = Map.fetch!(map, lemma)
        match = {:match, %{standard: lemma, dialects: dialects, chosen: hd(dialects)}}
        acc = [match | flush(acc, pending)]
        tail = binary_part(rest, byte_size(lemma), byte_size(rest) - byte_size(lemma))
        scan(tail, lemmas, map, acc, "")
    end
  end

  defp flush(acc, ""), do: acc
  defp flush(acc, pending), do: [{:plain, pending} | acc]

  defp longest_prefix(rest, lemmas) do
    Enum.find(lemmas, fn lemma -> String.starts_with?(rest, lemma) end)
  end

  defp next_grapheme(rest) do
    case String.next_grapheme(rest) do
      {g, tail} -> {g, tail}
      nil -> {rest, ""}
    end
  end

  # Build %{standard_lemma => [headword, ...]} for published entries, optionally
  # narrowed to a region subtree. Empty/invalid subtree → empty map.
  defp lemma_headwords(region_path) do
    case region_filter(region_path) do
      :no_filter -> run_lemma_query(nil)
      {:ids, []} -> %{}
      {:ids, ids} -> run_lemma_query(ids)
    end
  end

  defp run_lemma_query(region_ids) do
    base =
      from e in Entry,
        where: e.status == :published,
        join: s in assoc(e, :senses),
        on: not is_nil(s.standard_lemma) and s.standard_lemma != "",
        distinct: true,
        select: {s.standard_lemma, e.headword}

    query =
      case region_ids do
        nil ->
          base

        ids ->
          from [e, _s] in base,
            join: er in assoc(e, :entry_regions),
            on: er.region_id in ^ids
      end

    query
    |> Repo.all()
    |> Enum.reduce(%{}, fn {lemma, headword}, acc ->
      Map.update(acc, lemma, [headword], fn list ->
        if headword in list, do: list, else: list ++ [headword]
      end)
    end)
  end

  # nil path → no region restriction; otherwise resolve the subtree ids.
  defp region_filter(nil), do: :no_filter
  defp region_filter(""), do: :no_filter
  defp region_filter(path) when is_binary(path), do: {:ids, Regions.subtree_ids(path)}

  # Escape LIKE wildcard and backslash characters so they match literally.
  # PostgreSQL's default LIKE escape character is backslash.
  defp escape_like(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end
end
