defmodule DialectPocketWeb.PageController do
  use DialectPocketWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
