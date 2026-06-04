defmodule DialectPouchWeb.ConvertLiveTest do
  use DialectPouchWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias DialectPouch.{Dictionary, Regions}

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

  test "mounts with word and sentence modes", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/convert")
    assert html =~ "convert-tab-word"
    assert html =~ "convert-tab-sentence"
    assert html =~ "convert-word-prompt"
  end

  test "word conversion shows dialect candidates", %{conn: conn} do
    {:ok, jp} = Regions.create_region(%{name: "日本", level: :country, path: "jp"})

    {:ok, hiro} =
      Regions.create_region(%{
        name: "広島県",
        level: :prefecture,
        path: "jp.hiroshima",
        parent_id: jp.id
      })

    pub!("わや", "とても", "わや-hiroshima", [hiro.id])

    {:ok, lv, _html} = live(conn, ~p"/convert")
    html = lv |> form("#convert-word-form", %{word: "とても", region_path: ""}) |> render_change()
    assert html =~ "convert-word-list"
    assert html =~ "わや"
  end

  test "word conversion with no data shows データなし (no invention)", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/convert")
    html = lv |> form("#convert-word-form", %{word: "存在しない語", region_path: ""}) |> render_change()
    assert html =~ "convert-word-none"
    assert html =~ "推測した方言は出しません"
  end
end
