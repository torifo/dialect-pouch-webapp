defmodule DialectPouchWeb.RegionLive do
  use DialectPouchWeb, :live_view

  alias DialectPouch.Regions
  alias DialectPouch.Dictionary

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"region_path" => path}, _uri, socket) do
    region = Regions.get_region_by_path(path)

    if is_nil(region) do
      raise Ecto.NoResultsError, queryable: DialectPouch.Regions.Region
    end

    entries = Dictionary.list_published_in_subtree(path)

    children_with_counts =
      region
      |> Regions.children()
      |> Enum.map(fn child ->
        count = Dictionary.count_published_in_subtree(child.path)
        {child, count}
      end)
      |> Enum.filter(fn {_child, count} -> count > 0 end)
      |> Enum.sort_by(fn {child, _count} -> child.path end)

    breadcrumbs = build_breadcrumbs(path)

    {:noreply,
     socket
     |> assign(:region, region)
     |> assign(:entries, entries)
     |> assign(:children_with_counts, children_with_counts)
     |> assign(:breadcrumbs, breadcrumbs)
     |> assign(:page_title, region.name)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      active_tab={:regions}
      mobile_title={@region.name <> "の方言"}
      mobile_back={~p"/regions"}
    >
      <div class="pc-only">
      <div
        id="region-page"
        data-region-path={@region.path}
        data-region-level={@region.level}
        class="wrap wrap-narrow"
        style="padding: 32px 24px 72px;"
      >
        <%!-- Breadcrumb --%>
        <nav id="region-breadcrumb" aria-label="パンくずリスト" class="crumbs">
          <.link navigate={~p"/regions"} class="muted" style="color: var(--link);">
            地域一覧
          </.link>
          <span
            :for={{crumb_name, crumb_path} <- @breadcrumbs}
            class="row"
            style="gap: 8px; display: contents;"
          >
            <.icon
              name="hero-chevron-right"
              class="text-gray-400"
              style="width: 13px; height: 13px; color: var(--ink-soft);"
            />
            <.link navigate={~p"/r/#{crumb_path}"} style="color: var(--link);">
              {crumb_name}
            </.link>
          </span>
          <.icon name="hero-chevron-right" style="width: 13px; height: 13px; color: var(--ink-soft);" />
          <span style="color: var(--navy); font-weight: 700;">{@region.name}</span>
        </nav>

        <%!-- 見出し --%>
        <header id="region-header" class="region-hero">
          <div>
            <h1 class="page-title" style="margin-bottom: 4px;">{@region.name}の方言</h1>
            <p class="muted">{length(@entries)}件が登録されています</p>
          </div>
          <div class="region-hero__badge">
            <span class="region-hero__count">{length(@entries)}</span>
            <span class="tiny muted">登録件数</span>
          </div>
        </header>

        <%!-- ドリルダウン: データのある子地域がある場合のみ表示 --%>
        <section
          :if={@children_with_counts != []}
          id="region-drilldown"
          aria-label="絞り込む"
          style="margin-bottom: 28px;"
        >
          <h2 class="dsec__label">エリアで絞り込む</h2>
          <div class="regrid">
            <.link
              :for={{child, count} <- @children_with_counts}
              navigate={~p"/r/#{child.path}"}
              id={"region-child-#{child.path}"}
              data-region-path={child.path}
              class="regrid__item"
            >
              <span class="regrid__name">{child.name}</span>
              <span class="regrid__count">{count}件</span>
            </.link>
          </div>
        </section>

        <%!-- エントリ一覧 --%>
        <section id="region-entries" aria-label="この地域の方言">
          <div class="sec-head">
            <h2 class="dsec__label" style="margin-bottom: 0;">この地域の方言</h2>
          </div>

          <p :if={@entries == []} id="region-entries-empty" class="empty">
            <span class="muted">この地域の登録はまだありません。</span>
          </p>

          <div :if={@entries != []} id="region-entries-list" class="card-grid">
            <.link
              :for={entry <- @entries}
              navigate={~p"/e/#{entry.slug}"}
              id={"entry-#{entry.slug}"}
              data-slug={entry.slug}
              class="entry"
            >
              <div class="entry__top">
                <span id={"entry-#{entry.slug}-headword"} class="entry__word">
                  {entry.headword}
                </span>
                <span
                  :if={entry.reading && entry.reading != ""}
                  id={"entry-#{entry.slug}-reading"}
                  class="entry__reading"
                >
                  【{entry.reading}】
                </span>
                <span
                  :if={entry.provenance && entry.provenance.reliability != :verified}
                  id={"entry-#{entry.slug}-unverified"}
                  class="badge badge--unverified"
                >
                  真偽未確認
                </span>
              </div>

              <p
                :if={entry.senses != []}
                id={"entry-#{entry.slug}-gloss"}
                class="entry__gloss"
              >
                {hd(entry.senses).gloss}
              </p>

              <div class="entry__meta">
                <span class="entry__region">
                  <.icon name="hero-map-pin" style="width: 13px; height: 13px;" />
                  {entry.entry_regions |> Enum.map(& &1.region.name) |> Enum.join("・")}
                </span>
              </div>
            </.link>
          </div>
        </section>
      </div>
      </div>
      <%!-- /pc-only --%>

      <%!-- ===== MOBILE REGION DETAIL ===== --%>
      <div class="m-app sp-only">
        <div class="m-pad">
          <div style="display:flex;align-items:center;justify-content:space-between;gap:12px;padding-bottom:16px;border-bottom:1px solid var(--color-surface-border)">
            <div>
              <h1 class="m-h2" style="font-size:22px">{@region.name}の方言</h1>
              <p class="m-help" style="margin-top:4px">{length(@entries)}件が登録されています</p>
            </div>
            <div style="flex:none;display:flex;flex-direction:column;align-items:center;background:var(--color-brand-primary-pale);border-radius:var(--radius-md);padding:10px 16px">
              <span style="font-family:var(--font-en);font-size:22px;font-weight:800;color:var(--color-brand-primary);line-height:1">
                {length(@entries)}
              </span>
              <span class="m-tiny m-muted" style="margin-top:2px">件</span>
            </div>
          </div>

          <div :if={@children_with_counts != []} style="margin-top:16px">
            <p class="m-dsec__label">エリアで絞り込む</p>
            <div class="m-regrid">
              <.link
                :for={{child, count} <- @children_with_counts}
                navigate={~p"/r/#{child.path}"}
                class="m-regrid__item"
              >
                <span class="m-regrid__name">{child.name}</span>
                <span class="m-regrid__count">{count}件</span>
              </.link>
            </div>
          </div>

          <div class="m-list" style="margin-top:16px">
            <%= if @entries == [] do %>
              <div class="m-empty"><p class="m-muted">この地域の登録はまだありません。</p></div>
            <% else %>
              <.m_entry :for={entry <- @entries} entry={entry} />
            <% end %>
          </div>

          <div class="m-contrib" style="margin-top:20px">
            <span class="m-contrib__t">
              <.icon name="hero-pencil-square" class="size-4" style="color:var(--color-brand-primary)" />
              {@region.name}の言葉、知っていますか？
            </span>
            <.link navigate={~p"/contribute"} class="m-btn m-btn--ghost">投稿する</.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Build breadcrumb list from a materialized path.
  # e.g. "jp.aomori.tsugaru" → [{Japan, "jp"}, {Aomori, "jp.aomori"}]
  # The current region itself is excluded (it's the page heading).
  defp build_breadcrumbs(path) do
    labels = String.split(path, ".")

    labels
    |> Enum.drop(-1)
    |> Enum.with_index(1)
    |> Enum.map(fn {_label, depth} ->
      ancestor_path = labels |> Enum.take(depth) |> Enum.join(".")
      region = Regions.get_region_by_path(ancestor_path)
      name = if region, do: region.name, else: ancestor_path
      {name, ancestor_path}
    end)
  end
end
