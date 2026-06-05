defmodule DialectPouchWeb.EntryLiveTest do
  use DialectPouchWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias DialectPouch.Dictionary
  alias DialectPouch.Feedback

  defp pub!(overrides) do
    base = %{
      headword: "あずましい",
      reading: "あずましい",
      slug: "あずましい-tsugaru",
      senses: [%{gloss: "気持ち良い・落ち着く", standard_lemma: "気持ち良い"}],
      examples: [%{text: "あずましぃ〜", translation: "落ち着く〜"}],
      provenance: %{
        kind: :community,
        reliability: :unverified,
        source_platform: "wikipedia",
        source_url: "https://ja.wikipedia.org/wiki/津軽弁"
      }
    }

    {:ok, e} = Dictionary.create_entry(Map.merge(base, overrides), [])
    {:ok, e} = Dictionary.publish_entry(e)
    e
  end

  test "renders a published entry with meaning, example and JSON-LD", %{conn: conn} do
    e = pub!(%{})
    {:ok, _lv, html} = live(conn, ~p"/e/#{e.slug}")

    assert html =~ "あずましい"
    assert html =~ "気持ち良い"
    assert html =~ "application/ld+json"
    assert html =~ "DefinedTerm"
    # unverified provenance must surface the badge text
    assert html =~ "真偽未確認"
  end

  test "a draft entry is not reachable (404)", %{conn: conn} do
    {:ok, draft} =
      Dictionary.create_entry(
        %{
          headword: "みっと",
          slug: "みっと-x",
          senses: [%{gloss: "秘密"}],
          provenance: %{kind: :community, reliability: :unverified}
        },
        []
      )

    assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/e/#{draft.slug}") end
  end

  test "an unknown slug raises (404)", %{conn: conn} do
    assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/e/does-not-exist") end
  end

  test "submitting a remark shows it immediately", %{conn: conn} do
    entry = published_entry_fixture()

    {:ok, lv, _html} = live(conn, ~p"/e/#{entry.slug}")

    lv
    |> form("#remark-form", %{
      "kind" => "obsolete",
      "body" => "今はあまり使いません",
      "nickname" => "どさんこ"
    })
    |> render_submit()

    assert render(lv) =~ "今はあまり使いません"
    assert render(lv) =~ "どさんこ"
    assert [%{body: "今はあまり使いません"}] = Feedback.list_remarks(entry.id)
  end

  test "submitting a remark without a nickname shows an error", %{conn: conn} do
    entry = published_entry_fixture()
    {:ok, lv, _html} = live(conn, ~p"/e/#{entry.slug}")

    html =
      lv
      |> form("#remark-form", %{"kind" => "meaning", "body" => "違う", "nickname" => ""})
      |> render_submit()

    assert html =~ "ニックネーム"
    assert Feedback.list_remarks(entry.id) == []
  end

  defp published_entry_fixture do
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

    entry
  end
end
