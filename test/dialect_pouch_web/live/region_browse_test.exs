defmodule DialectPouchWeb.RegionBrowseTest do
  use DialectPouchWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias DialectPouch.{Dictionary, Regions}

  defp region!(path, name, level, parent_id \\ nil) do
    {:ok, r} =
      Regions.create_region(%{name: name, level: level, path: path, parent_id: parent_id})

    r
  end

  defp pub!(headword, slug, region_ids) do
    {:ok, e} =
      Dictionary.create_entry(
        %{
          headword: headword,
          slug: slug,
          senses: [%{gloss: "意味"}],
          provenance: %{kind: :community, reliability: :unverified}
        },
        region_ids
      )

    {:ok, e} = Dictionary.publish_entry(e)
    e
  end

  describe "/regions index" do
    test "lists prefectures that have data, with links", %{conn: conn} do
      jp = region!("jp", "日本", :country)
      hiro = region!("jp.hiroshima", "広島県", :prefecture, jp.id)
      _empty = region!("jp.kyoto", "京都府", :prefecture, jp.id)
      pub!("わや", "わや-hiroshima", [hiro.id])

      {:ok, _lv, html} = live(conn, ~p"/regions")
      assert html =~ "region-index-list"
      assert html =~ "広島県"
      assert html =~ "/r/jp.hiroshima"
      # prefecture with no data is not listed
      refute html =~ "京都府"
    end

    test "shows empty state when no region has data", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/regions")
      assert html =~ "region-index-empty"
    end
  end

  describe "/r/:region_path" do
    test "shows a prefecture with its entries", %{conn: conn} do
      jp = region!("jp", "日本", :country)
      hiro = region!("jp.hiroshima", "広島県", :prefecture, jp.id)
      pub!("ぶち", "ぶち-hiroshima", [hiro.id])

      {:ok, _lv, html} = live(conn, ~p"/r/jp.hiroshima")
      assert html =~ "region-header"
      assert html =~ "広島県"
      assert html =~ "ぶち"
    end

    test "offers drilldown to child regions that have data", %{conn: conn} do
      jp = region!("jp", "日本", :country)
      aomori = region!("jp.aomori", "青森県", :prefecture, jp.id)
      tsugaru = region!("jp.aomori.tsugaru", "津軽", :area, aomori.id)
      pub!("あずましい", "あずましい-tsugaru", [tsugaru.id])

      {:ok, _lv, html} = live(conn, ~p"/r/jp.aomori")
      assert html =~ "region-drilldown"
      assert html =~ "/r/jp.aomori.tsugaru"
      # subtree includes the area entry
      assert html =~ "あずましい"
    end

    test "hides drilldown when no child region has data", %{conn: conn} do
      jp = region!("jp", "日本", :country)
      hiro = region!("jp.hiroshima", "広島県", :prefecture, jp.id)
      pub!("ぶち", "ぶち-hiroshima", [hiro.id])

      {:ok, _lv, html} = live(conn, ~p"/r/jp.hiroshima")
      refute html =~ "region-drilldown"
    end

    test "shows empty state for a region without entries", %{conn: conn} do
      jp = region!("jp", "日本", :country)
      _kyoto = region!("jp.kyoto", "京都府", :prefecture, jp.id)

      {:ok, _lv, html} = live(conn, ~p"/r/jp.kyoto")
      assert html =~ "region-entries-empty"
    end

    test "unknown region path returns 404", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/r/jp.nowhere") end
    end
  end
end
