defmodule DialectPocket.Dictionary.SearchTest do
  use DialectPocket.DataCase, async: true

  alias DialectPocket.Dictionary
  alias DialectPocket.Dictionary.Search

  defp pub!(overrides) do
    base = %{
      headword: "X",
      reading: "x",
      senses: [%{gloss: "意味", standard_lemma: "意味"}],
      provenance: %{kind: :community, reliability: :unverified}
    }

    {:ok, e} = Dictionary.create_entry(Map.merge(base, overrides), [])
    {:ok, e} = Dictionary.publish_entry(e)
    e
  end

  test "blank query returns []" do
    pub!(%{})
    assert Search.search("") == []
    assert Search.search("   ") == []
  end

  test "matches by headword" do
    pub!(%{headword: "なまら", reading: "なまら", slug: "なまら-hokkaido"})
    assert [e] = Search.search("なまら")
    assert e.headword == "なまら"
  end

  test "matches by sense gloss (standard meaning)" do
    pub!(%{
      headword: "だんだん",
      slug: "だんだん-ehime",
      senses: [%{gloss: "ありがとう", standard_lemma: "ありがとう"}]
    })

    assert [e] = Search.search("ありがとう")
    assert e.headword == "だんだん"
  end

  test "excludes unpublished (draft) entries" do
    {:ok, _draft} =
      Dictionary.create_entry(
        %{
          headword: "ひみつ",
          slug: "ひみつ-x",
          senses: [%{gloss: "秘密"}],
          provenance: %{kind: :community, reliability: :unverified}
        },
        []
      )

    assert Search.search("ひみつ") == []
  end

  test "LIKE wildcards in the query are escaped (no match-everything)" do
    pub!(%{headword: "あ", slug: "あ-x"})
    pub!(%{headword: "い", slug: "い-x"})
    assert Search.search("%") == []
    assert Search.search("_") == []
  end

  test "respects the limit option" do
    for n <- 1..5, do: pub!(%{headword: "わや#{n}", slug: "わや#{n}-x"})
    assert length(Search.search("わや", limit: 3)) == 3
  end
end
