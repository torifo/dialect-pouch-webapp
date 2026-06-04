defmodule DialectPocketWeb.ContributeLiveTest do
  use DialectPocketWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias DialectPocket.{Dictionary, Regions}

  defp setup_region do
    {:ok, jp} = Regions.create_region(%{name: "日本", level: :country, path: "jp"})

    {:ok, _hok} =
      Regions.create_region(%{
        name: "北海道",
        level: :prefecture,
        path: "jp.hokkaido",
        parent_id: jp.id
      })

    :ok
  end

  test "renders the contribution form", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/contribute")
    assert html =~ "contribute-form"
    assert html =~ "見出し語"
  end

  test "a valid submission is saved as a draft and shows success", %{conn: conn} do
    setup_region()
    {:ok, lv, _html} = live(conn, ~p"/contribute")

    html =
      lv
      |> form("#contribute-form", %{
        headword: "なまら",
        reading: "なまら",
        meaning: "とても",
        region_path: "jp.hokkaido",
        example: "なまら寒い",
        nickname: "どさんこ"
      })
      |> render_submit()

    assert html =~ "contribute-success"
    assert Dictionary.count_published() == 0
    assert DialectPocket.Repo.aggregate(Dictionary.Entry, :count) == 1
  end

  test "missing required fields shows the error block", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/contribute")

    html =
      lv
      |> form("#contribute-form", %{headword: "x", meaning: "", region_path: ""})
      |> render_submit()

    assert html =~ "contribute-errors"
  end
end
