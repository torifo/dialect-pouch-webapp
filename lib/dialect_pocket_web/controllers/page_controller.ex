defmodule DialectPocketWeb.PageController do
  use DialectPocketWeb, :controller

  alias DialectPocket.{Dictionary, Regions}

  def home(conn, _params) do
    prefectures =
      Regions.roots()
      |> Enum.flat_map(&Regions.children/1)
      |> Enum.map(fn r -> {r, Dictionary.count_published_in_subtree(r.path)} end)
      |> Enum.filter(fn {_r, count} -> count > 0 end)
      |> Enum.sort_by(fn {_r, count} -> -count end)

    render(conn, :home,
      entry_count: Dictionary.count_published(),
      region_count: length(prefectures),
      prefectures: prefectures
    )
  end
end
