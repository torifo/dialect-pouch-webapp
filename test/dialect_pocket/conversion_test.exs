defmodule DialectPocket.ConversionTest do
  use DialectPocket.DataCase, async: true

  alias DialectPocket.{Conversion, Dictionary, Regions}

  setup do
    {:ok, jp} = Regions.create_region(%{name: "日本", level: :country, path: "jp"})

    {:ok, hiro} =
      Regions.create_region(%{
        name: "広島県",
        level: :prefecture,
        path: "jp.hiroshima",
        parent_id: jp.id
      })

    {:ok, hok} =
      Regions.create_region(%{
        name: "北海道",
        level: :prefecture,
        path: "jp.hokkaido",
        parent_id: jp.id
      })

    %{jp: jp, hiro: hiro, hok: hok}
  end

  defp pub!(headword, lemma, slug, region_ids) do
    {:ok, e} =
      Dictionary.create_entry(
        %{
          headword: headword,
          slug: slug,
          senses: [%{gloss: lemma, standard_lemma: lemma}],
          provenance: %{kind: :community, reliability: :unverified, source_platform: "wikipedia"}
        },
        region_ids
      )

    {:ok, e} = Dictionary.publish_entry(e)
    e
  end

  describe "convert_word/2" do
    test "returns dialect candidates across regions for a standard word", %{hiro: hiro, hok: hok} do
      pub!("わや", "とても", "わや-hiroshima", [hiro.id])
      pub!("なまら", "とても", "なまら-hokkaido", [hok.id])

      candidates = Conversion.convert_word("とても")
      headwords = candidates |> Enum.map(& &1.headword) |> Enum.sort()
      assert headwords == ["なまら", "わや"]
      # each candidate carries provenance + region
      assert Enum.all?(candidates, &(&1.provenance != nil and &1.regions != []))
    end

    test "filters by region subtree", %{hiro: hiro, hok: hok} do
      pub!("わや", "とても", "わや-hiroshima", [hiro.id])
      pub!("なまら", "とても", "なまら-hokkaido", [hok.id])

      assert [%{headword: "わや"}] = Conversion.convert_word("とても", "jp.hiroshima")
    end

    test "returns [] when no data (never invents)", %{} do
      assert Conversion.convert_word("そんざいしない語") == []
    end

    test "returns [] for blank input" do
      assert Conversion.convert_word("") == []
      assert Conversion.convert_word("   ") == []
    end

    test "normalizes a leading 〜", %{hiro: hiro} do
      pub!("じゃけえ", "だから", "じゃけえ-hiroshima", [hiro.id])
      assert [%{headword: "じゃけえ"}] = Conversion.convert_word("〜だから")
    end
  end

  describe "convert_sentence/2" do
    test "replaces matched standard words and leaves the rest intact", %{hiro: hiro} do
      pub!("わや", "とても", "わや-hiroshima", [hiro.id])

      segments = Conversion.convert_sentence("とてもうまい")
      assert Enum.any?(segments, &match?({:match, %{standard: "とても"}}, &1))
      assert Enum.any?(segments, &match?({:plain, "うまい"}, &1))
    end

    test "no lemma match returns the text as a single plain segment", %{hiro: _} do
      assert [{:plain, "なにもない"}] = Conversion.convert_sentence("なにもない")
    end

    test "blank text yields a single empty plain segment" do
      assert [{:plain, ""}] = Conversion.convert_sentence("")
    end
  end
end
