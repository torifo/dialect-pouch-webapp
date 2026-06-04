defmodule DialectPouchWeb.RegionIndexLive do
  use DialectPouchWeb, :live_view

  alias DialectPouch.Regions
  alias DialectPouch.Dictionary

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
     |> assign(:tiles, DialectPouchWeb.MapData.tiles())
     |> assign(:regions, DialectPouchWeb.MapData.regions())
     |> assign(:page_title, "地域から探す")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active_tab={:regions}>
      <div class="pc-only">
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
      </div>
      <%!-- /pc-only --%>

      <%!-- ===== MOBILE REGIONS ===== --%>
      <div class="m-app sp-only">
        <div class="m-pad">
          <h1 class="m-h2" style="font-size:22px">地域から探す</h1>
          <p class="m-help" style="margin-top:6px">
            色の濃い地域ほど件数が多め。タップでその地域の方言へ。
          </p>

          <div class="m-mapcard m-map" style="margin-top:14px">
            <div class="jmap">
              <div class="jmap__scroll">
                <div
                  class="jmap__board"
                  style="grid-template-columns:repeat(13,1fr);grid-template-rows:repeat(13,1fr)"
                >
                  <%= for t <- @tiles do %>
                    <%= if t.count > 0 do %>
                      <.link
                        navigate={~p"/r/#{t.path}"}
                        class="jtile"
                        data-len={String.length(t.name)}
                        style={"grid-column:#{t.col};grid-row:#{t.row};#{t.heat}"}
                        aria-label={"#{t.name} #{t.count}件"}
                      >
                        <span class="jtile__name">{t.name}</span>
                        <span class="jtile__count">{t.count}</span>
                      </.link>
                    <% else %>
                      <div
                        class="jtile"
                        data-len={String.length(t.name)}
                        style={"grid-column:#{t.col};grid-row:#{t.row};#{t.heat};cursor:default"}
                      >
                        <span class="jtile__name">{t.name}</span>
                        <span class="jtile__count">{t.count}</span>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              </div>
              <div class="jmap__key">
                <span :for={r <- @regions} class="jmap__key-item">
                  <i style={"background:#{r.color}"}></i>{r.region}
                </span>
              </div>
            </div>
          </div>
          <div class="m-mapinfo">
            <p class="m-help">
              タイルをタップすると、その地域の方言一覧を開きます。色が濃いほど登録件数が多めです。
            </p>
          </div>

          <p class="m-dsec__label" style="margin-top:22px">都道府県（件数順）</p>
          <div :if={@prefectures_with_counts == []} class="m-empty">
            <p class="m-muted">登録されている地域データはありません。</p>
          </div>
          <div class="m-regrid">
            <.link
              :for={
                {region, count} <-
                  @prefectures_with_counts
                  |> Enum.sort_by(fn {_r, c} -> c end, :desc)
                  |> Enum.take(12)
              }
              navigate={~p"/r/#{region.path}"}
              class="m-regrid__item"
            >
              <span class="m-regrid__name">{region.name}</span>
              <span class="m-regrid__count">{count}件</span>
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
