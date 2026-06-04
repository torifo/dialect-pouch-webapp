defmodule DialectPouchWeb.PageControllerTest do
  use DialectPouchWeb.ConnCase

  test "GET / shows the dialect-pouch landing with feature links", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)
    assert body =~ "dialect-pouch"
    assert body =~ "home-link-search"
    assert body =~ "home-link-convert"
  end
end
