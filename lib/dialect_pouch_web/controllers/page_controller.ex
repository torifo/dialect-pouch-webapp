defmodule DialectPouchWeb.PageController do
  use DialectPouchWeb, :controller

  alias DialectPouch.Dictionary
  alias DialectPouchWeb.MapData

  def home(conn, _params) do
    render(conn, :home,
      entry_count: Dictionary.count_published(),
      tiles: MapData.tiles(),
      regions: MapData.regions(),
      featured: Dictionary.list_published(6)
    )
  end
end
