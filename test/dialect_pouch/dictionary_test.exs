defmodule DialectPouch.DictionaryTest do
  use DialectPouch.DataCase, async: true

  alias DialectPouch.Dictionary
  alias DialectPouch.Dictionary.Entry
  alias DialectPouch.Regions

  defp region!(path, name, level, parent_id \\ nil) do
    {:ok, r} =
      Regions.create_region(%{name: name, level: level, path: path, parent_id: parent_id})

    r
  end

  defp valid_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        headword: "わや",
        reading: "わや",
        senses: [%{gloss: "とても・めちゃくちゃ", standard_lemma: "とても"}],
        examples: [%{text: "部屋がわやだ", translation: "部屋がめちゃくちゃだ"}],
        provenance: %{
          kind: :community,
          reliability: :unverified,
          source_platform: "wikipedia",
          source_url: "https://ja.wikipedia.org/wiki/広島弁",
          source_license: "CC BY-SA 4.0"
        }
      },
      overrides
    )
  end

  describe "create_entry/2" do
    test "creates an entry with provenance, sense, example and region link" do
      jp = region!("jp", "日本", :country)
      hiroshima = region!("jp.hiroshima", "広島県", :prefecture, jp.id)

      assert {:ok, %Entry{} = entry} = Dictionary.create_entry(valid_attrs(), [hiroshima.id])

      loaded = Dictionary.get_by_slug_admin(entry.slug)
      assert loaded.provenance.kind == :community
      assert loaded.provenance.reliability == :unverified
      assert [%{gloss: "とても・めちゃくちゃ", standard_lemma: "とても"}] = loaded.senses
      assert [%{text: "部屋がわやだ"}] = loaded.examples
      assert [%{region: %{path: "jp.hiroshima"}}] = loaded.entry_regions
    end

    test "requires provenance (no entry without a source)" do
      attrs = valid_attrs() |> Map.delete(:provenance)
      assert {:error, changeset} = Dictionary.create_entry(attrs, [])
      assert %{provenance: [_]} = errors_on(changeset)
    end

    test "requires a headword" do
      attrs = valid_attrs(%{headword: nil})
      assert {:error, changeset} = Dictionary.create_entry(attrs, [])
      assert %{headword: [_]} = errors_on(changeset)
    end

    test "derives unique slugs for homographs (same headword)" do
      {:ok, a} = Dictionary.create_entry(valid_attrs(%{slug: "わや-hiroshima"}), [])
      {:ok, b} = Dictionary.create_entry(valid_attrs(%{slug: "わや-hiroshima"}), [])
      refute a.slug == b.slug
    end

    test "sets the normalized search field from headword and reading" do
      {:ok, entry} = Dictionary.create_entry(valid_attrs(%{headword: "ナマラ", reading: "なまら"}), [])
      assert entry.norm == "ナマラ なまら" |> String.downcase()
    end
  end

  describe "publication gate" do
    setup do
      {:ok, entry} = Dictionary.create_entry(valid_attrs(), [])
      %{entry: entry}
    end

    test "draft entries are not publicly visible", %{entry: entry} do
      assert Dictionary.get_published_by_slug(entry.slug) == nil
    end

    test "published entries become publicly visible", %{entry: entry} do
      {:ok, _} = Dictionary.publish_entry(entry)
      assert %Entry{} = Dictionary.get_published_by_slug(entry.slug)
      assert Dictionary.count_published() == 1
    end

    test "rejected entries stay non-public", %{entry: entry} do
      {:ok, rejected} = Dictionary.reject_entry(entry)
      assert rejected.status == :rejected
      assert Dictionary.get_published_by_slug(entry.slug) == nil
    end
  end

  describe "lookups and region linking" do
    test "get_published_by_slug/1 returns nil for an unknown slug" do
      assert Dictionary.get_published_by_slug("does-not-exist") == nil
    end

    test "links one entry to multiple regions" do
      jp = region!("jp", "日本", :country)
      a = region!("jp.hiroshima", "広島県", :prefecture, jp.id)
      b = region!("jp.okayama", "岡山県", :prefecture, jp.id)

      {:ok, entry} = Dictionary.create_entry(valid_attrs(), [a.id, b.id])
      loaded = Dictionary.get_by_slug_admin(entry.slug)
      paths = loaded.entry_regions |> Enum.map(& &1.region.path) |> Enum.sort()
      assert paths == ["jp.hiroshima", "jp.okayama"]
    end

    test "duplicate entry+region link is rejected and rolls back" do
      jp = region!("jp", "日本", :country)
      r = region!("jp.hiroshima", "広島県", :prefecture, jp.id)
      assert {:error, _} = Dictionary.create_entry(valid_attrs(), [r.id, r.id])
      # transaction rolled back: no entry persisted
      assert DialectPouch.Repo.aggregate(Entry, :count) == 0
    end
  end
end
