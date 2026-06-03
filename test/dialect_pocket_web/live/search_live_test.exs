defmodule DialectPocketWeb.SearchLiveTest do
  use DialectPocketWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias DialectPocket.Dictionary

  defp pub!(overrides) do
    base = %{
      headword: "X",
      senses: [%{gloss: "意味", standard_lemma: "意味"}],
      provenance: %{kind: :community, reliability: :unverified}
    }

    {:ok, e} = Dictionary.create_entry(Map.merge(base, overrides), [])
    {:ok, e} = Dictionary.publish_entry(e)
    e
  end

  test "SSR renders matching results for ?q=", %{conn: conn} do
    pub!(%{headword: "わや", slug: "わや-hiroshima", senses: [%{gloss: "めちゃくちゃ"}]})

    {:ok, _lv, html} = live(conn, ~p"/search?q=わや")
    assert html =~ "わや"
    assert html =~ "search-result-list"
  end

  test "blank query shows the input prompt", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/search")
    assert html =~ "search-empty-prompt"
  end

  test "no matches shows the no-results state", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/search?q=存在しない語xyz")
    assert html =~ "search-no-results"
  end

  test "typing in the form updates results live", %{conn: conn} do
    pub!(%{headword: "なまら", slug: "なまら-hokkaido", senses: [%{gloss: "とても"}]})

    {:ok, lv, _html} = live(conn, ~p"/search")
    html = lv |> form("#search-form", %{q: "なまら"}) |> render_change()
    assert html =~ "なまら"
  end
end
