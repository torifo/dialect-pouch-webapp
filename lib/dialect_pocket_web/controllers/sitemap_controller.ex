defmodule DialectPocketWeb.SitemapController do
  @moduledoc "Serves /sitemap.xml listing static pages, published entries and regions."
  use DialectPocketWeb, :controller

  alias DialectPocket.{Dictionary, Regions}

  def index(conn, _params) do
    static = [
      {url(~p"/"), nil},
      {url(~p"/search"), nil},
      {url(~p"/regions"), nil},
      {url(~p"/convert"), nil},
      {url(~p"/contribute"), nil}
    ]

    entries =
      Enum.map(Dictionary.published_slugs(), fn %{slug: slug, updated_at: updated_at} ->
        {url(~p"/e/#{slug}"), lastmod(updated_at)}
      end)

    regions = Enum.map(Regions.all(), fn r -> {url(~p"/r/#{r.path}"), nil} end)

    body = build(static ++ entries ++ regions)

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, body)
  end

  defp build(urls) do
    body =
      Enum.map_join(urls, "\n", fn {loc, lastmod} ->
        lastmod_tag = if lastmod, do: "<lastmod>#{lastmod}</lastmod>", else: ""
        "  <url><loc>#{escape(loc)}</loc>#{lastmod_tag}</url>"
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{body}
    </urlset>
    """
  end

  defp lastmod(%DateTime{} = dt), do: dt |> DateTime.to_date() |> Date.to_iso8601()
  defp lastmod(%NaiveDateTime{} = dt), do: dt |> NaiveDateTime.to_date() |> Date.to_iso8601()
  defp lastmod(_), do: nil

  defp escape(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
