defmodule DialectPocketWeb.PageControllerTest do
  use DialectPocketWeb.ConnCase

  test "GET / shows the dialect-pocket landing with feature links", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)
    assert body =~ "dialect-pocket"
    assert body =~ "home-link-search"
    assert body =~ "home-link-convert"
  end
end
