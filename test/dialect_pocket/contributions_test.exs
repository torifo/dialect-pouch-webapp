defmodule DialectPocket.ContributionsTest do
  use DialectPocket.DataCase, async: true

  alias DialectPocket.{Contributions, Regions}
  alias DialectPocket.Dictionary.Entry

  setup do
    {:ok, jp} = Regions.create_region(%{name: "日本", level: :country, path: "jp"})

    {:ok, hok} =
      Regions.create_region(%{
        name: "北海道",
        level: :prefecture,
        path: "jp.hokkaido",
        parent_id: jp.id
      })

    %{hok: hok}
  end

  defp valid(over \\ %{}) do
    Map.merge(
      %{
        "headword" => "なまら",
        "reading" => "なまら",
        "meaning" => "とても",
        "region_path" => "jp.hokkaido",
        "example" => "なまら寒い",
        "nickname" => "どさんこ"
      },
      over
    )
  end

  test "saves a valid submission as an unpublished :user entry" do
    assert {:ok, %Entry{} = entry} = Contributions.create_submission(valid(), "k-ok")
    assert entry.status == :draft

    loaded = DialectPocket.Dictionary.get_by_slug_admin(entry.slug)
    assert loaded.provenance.kind == :user
    assert loaded.provenance.observed_author == "どさんこ"
    assert [%{region: %{path: "jp.hokkaido"}}] = loaded.entry_regions
    # not public until approved
    assert DialectPocket.Dictionary.get_published_by_slug(entry.slug) == nil
  end

  test "rejects missing required fields" do
    assert {:error, :invalid, missing} =
             Contributions.create_submission(%{"headword" => "x"}, "k-missing")

    assert :meaning in missing
    assert :region_path in missing
  end

  test "rejects an unknown region path" do
    attrs = valid(%{"region_path" => "jp.nowhere"})
    assert {:error, :invalid, [:region_path]} = Contributions.create_submission(attrs, "k-region")
  end

  test "rate limits after the per-window maximum" do
    key = "k-rate-#{System.unique_integer([:positive])}"
    results = for _ <- 1..6, do: Contributions.create_submission(valid(), key)
    assert Enum.count(results, &match?({:ok, _}, &1)) == 5
    assert List.last(results) == {:error, :rate_limited}
  end
end
