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
      <div id="region-index-page" class="wrap wrap-narrow" style="padding: 40px 24px 72px;">
        <h1 class="page-title">地域から探す</h1>
        <p class="muted" style="margin-top: 6px;">
          方言が登録されている地域です。クリックで一覧を開きます。
        </p>

        <div
          :if={@prefectures_with_counts == []}
          id="region-index-empty"
          class="empty"
        >
          <p class="muted">現在、登録されている地域データはありません。</p>
        </div>

        <div
          :if={@prefectures_with_counts != []}
          id="region-index-list"
          class="regrid"
          style="margin-top: 28px;"
        >
          <.link
            :for={{region, count} <- @prefectures_with_counts}
            navigate={~p"/r/#{region.path}"}
            id={"region-item-#{region.path}"}
            data-region-path={region.path}
            data-region-level={region.level}
            class="regrid__item"
          >
            <span class="regrid__name">{region.name}</span>
            <span class="regrid__count">{count}件</span>
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
