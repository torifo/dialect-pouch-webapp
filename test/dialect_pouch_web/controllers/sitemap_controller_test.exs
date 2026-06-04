defmodule DialectPouchWeb.SitemapControllerTest do
  use DialectPouchWeb.ConnCase, async: true

  alias DialectPouch.{Dictionary, Regions}

  test "GET /sitemap.xml lists static pages, regions and published entries", %{conn: conn} do
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
          provenance: %{kind: :community, reliability: :unverified}
        },
        [hok.id]
      )

    {:ok, _} = Dictionary.publish_entry(e)

    conn = get(conn, ~p"/sitemap.xml")

    assert response_content_type(conn, :xml)
    body = response(conn, 200)
    assert body =~ "<urlset"
    assert body =~ "/search"
    assert body =~ "/r/jp.hokkaido"
    # published entry present (slug is URL-encoded in the loc)
    assert body =~ "/e/"
  end
end
