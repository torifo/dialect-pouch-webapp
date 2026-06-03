defmodule DialectPocketWeb.RegionIndexLive do
  use DialectPocketWeb, :live_view

  alias DialectPocket.Regions
  alias DialectPocket.Dictionary

  @impl true
  def mount(_params, _session, socket) do
    prefectures_with_counts =
      Regions.roots()
      |> Enum.flat_map(fn root -> Regions.children(root) end)
      |> Enum.map(fn region ->
        count = Dictionary.count_published_in_subtree(region.path)
        {region, count}
      end)
      |> Enum.filter(fn {_region, count} -> count > 0 end)
      |> Enum.sort_by(fn {region, _count} -> region.path end)

    {:ok,
     socket
     |> assign(:prefectures_with_counts, prefectures_with_counts)
     |> assign(:page_title, "地域から探す")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="region-index-page" class="mx-auto max-w-2xl space-y-6 py-6 px-4">
        <header id="region-index-header">
          <h1 class="text-xl font-semibold">地域から探す</h1>
          <p class="mt-1 text-sm text-gray-500">
            方言が登録されている地域を一覧表示しています。
          </p>
        </header>

        <%!-- ※ 将来的に日本地図UIに置き換え予定（claude design GUIで調整） --%>

        <div
          :if={@prefectures_with_counts == []}
          id="region-index-empty"
          class="text-sm text-gray-500"
        >
          現在、登録されている地域データはありません。
        </div>

        <ul
          :if={@prefectures_with_counts != []}
          id="region-index-list"
          class="grid grid-cols-2 gap-2 sm:grid-cols-3"
        >
          <li
            :for={{region, count} <- @prefectures_with_counts}
            id={"region-item-#{region.path}"}
            data-region-path={region.path}
            data-region-level={region.level}
          >
            <.link
              navigate={~p"/r/#{region.path}"}
              class="block rounded border border-gray-200 px-3 py-2 text-sm hover:bg-blue-50 hover:border-blue-300 transition-colors"
            >
              <span class="font-medium text-blue-700">{region.name}</span>
              <span class="ml-1 text-gray-400 text-xs">({count}件)</span>
            </.link>
          </li>
        </ul>
      </div>
    </Layouts.app>
    """
  end
end
