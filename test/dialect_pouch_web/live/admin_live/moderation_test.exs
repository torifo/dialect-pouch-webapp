defmodule DialectPouchWeb.AdminLive.ModerationTest do
  use DialectPouchWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias DialectPouch.{Dictionary, Regions, Feedback}

  defp draft! do
    {:ok, jp} = Regions.create_region(%{name: "日本", level: :country, path: "jp"})

    {:ok, hok} =
      Regions.create_region(%{
        name: "北海道",
        level: :prefecture,
        path: "jp.hokkaido",
        parent_id: jp.id
      })

    {:ok, e} =
      Dictionary.create_entry(
        %{
          headword: "なまら",
          slug: "なまら-hokkaido",
          senses: [%{gloss: "とても"}],
          provenance: %{kind: :user, reliability: :community, observed_author: "どさんこ"}
        },
        [hok.id]
      )

    e
  end

  describe "unauthenticated" do
    test "redirects to the admin login", %{conn: conn} do
      assert {:error, {:redirect, %{to: to}}} = live(conn, ~p"/admin/moderation")
      assert to =~ "/admins/log-in"
    end
  end

  describe "authenticated curator" do
    setup :register_and_log_in_admin

    test "shows empty state when nothing is pending", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/moderation")
      assert html =~ "moderation-empty"
    end

    test "lists a pending submission and approves it (publishes)", %{conn: conn} do
      e = draft!()
      {:ok, lv, html} = live(conn, ~p"/admin/moderation")
      assert html =~ "なまら"
      assert html =~ "pending-#{e.id}"

      lv |> element("#approve-#{e.id}") |> render_click()

      assert %Dictionary.Entry{status: :published} = Dictionary.get_published_by_slug(e.slug)
      refute render(lv) =~ "pending-#{e.id}"
    end

    test "rejects a submission (kept non-public)", %{conn: conn} do
      e = draft!()
      {:ok, lv, _html} = live(conn, ~p"/admin/moderation")

      lv |> element("#reject-#{e.id}") |> render_click()

      assert Dictionary.get_published_by_slug(e.slug) == nil
      assert Dictionary.get_entry!(e.id).status == :rejected
    end

    test "lists reported remarks and can hide them", %{conn: conn} do
      entry = published_entry_with_remark_fixture()
      [remark] = Feedback.list_remarks(entry.id)
      {:ok, _} = Feedback.report_remark(remark.id)

      {:ok, lv, html} = live(conn, ~p"/admin/moderation")
      assert html =~ "通報された指摘"
      assert html =~ remark.body

      lv |> element("#hide-remark-#{remark.id}") |> render_click()

      assert Feedback.list_remarks(entry.id) == []
    end
  end

  defp published_entry_with_remark_fixture do
    {:ok, jp} = DialectPouch.Regions.create_region(%{name: "日本", level: :country, path: "jp"})

    {:ok, entry} =
      DialectPouch.Dictionary.create_entry(
        %{
          headword: "なまら",
          slug: "なまら",
          status: :published,
          senses: [%{gloss: "とても", standard_lemma: "とても"}],
          provenance: %{kind: :manual, reliability: :verified}
        },
        [jp.id]
      )

    {:ok, _} =
      Feedback.create_remark(
        %{
          "entry_id" => entry.id,
          "kind" => "meaning",
          "body" => "違うと思います",
          "author_kind" => "nickname",
          "author_nickname" => "通報対象"
        },
        "mod-fix"
      )

    entry
  end
end
