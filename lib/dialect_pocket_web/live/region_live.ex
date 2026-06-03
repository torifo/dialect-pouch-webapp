defmodule DialectPocketWeb.RegionLive do
  use DialectPocketWeb, :live_view

  alias DialectPocket.Regions
  alias DialectPocket.Dictionary

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"region_path" => path}, _uri, socket) do
    region = Regions.get_region_by_path(path)

    if is_nil(region) do
      raise Ecto.NoResultsError, queryable: DialectPocket.Regions.Region
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
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div
        id="region-page"
        data-region-path={@region.path}
        data-region-level={@region.level}
        class="mx-auto max-w-2xl space-y-6 py-6 px-4"
      >
        <%!-- Breadcrumb --%>
        <nav id="region-breadcrumb" aria-label="パンくずリスト" class="text-sm text-gray-500">
          <ol class="flex flex-wrap items-center gap-1">
            <li>
              <.link navigate={~p"/regions"} class="text-blue-600 hover:underline">
                地域一覧
              </.link>
            </li>
            <li :for={{crumb_name, crumb_path} <- @breadcrumbs} class="flex items-center gap-1">
              <span aria-hidden="true">&rsaquo;</span>
              <.link navigate={~p"/r/#{crumb_path}"} class="text-blue-600 hover:underline">
                {crumb_name}
              </.link>
            </li>
          </ol>
        </nav>

        <%!-- 見出し --%>
        <header id="region-header">
          <h1 class="text-2xl font-bold">{@region.name}</h1>
        </header>

        <%!-- ドリルダウン: データのある子地域がある場合のみ表示 --%>
        <section
          :if={@children_with_counts != []}
          id="region-drilldown"
          aria-label="絞り込む"
          class="space-y-2"
        >
          <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-400">絞り込む</h2>
          <ul class="grid grid-cols-2 gap-2 sm:grid-cols-3">
            <li
              :for={{child, count} <- @children_with_counts}
              id={"region-child-#{child.path}"}
              data-region-path={child.path}
            >
              <.link
                navigate={~p"/r/#{child.path}"}
                class="block rounded border border-gray-200 px-3 py-2 text-sm hover:bg-blue-50 hover:border-blue-300 transition-colors"
              >
                <span class="font-medium text-blue-700">{child.name}</span>
                <span class="ml-1 text-gray-400 text-xs">({count}件)</span>
              </.link>
            </li>
          </ul>
        </section>

        <%!-- エントリ一覧 --%>
        <section id="region-entries" aria-label="この地域の方言" class="space-y-2">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-400">
            この地域の方言
          </h2>

          <p :if={@entries == []} id="region-entries-empty" class="text-sm text-gray-500">
            この地域の登録はまだありません。
          </p>

          <ul :if={@entries != []} id="region-entries-list" class="divide-y divide-gray-100">
            <li
              :for={entry <- @entries}
              id={"entry-#{entry.slug}"}
              data-slug={entry.slug}
              class="py-3"
            >
              <.link navigate={~p"/e/#{entry.slug}"} class="group block space-y-0.5">
                <div class="flex items-baseline gap-2">
                  <span
                    id={"entry-#{entry.slug}-headword"}
                    class="text-base font-semibold text-blue-700 group-hover:underline"
                  >
                    {entry.headword}
                  </span>
                  <span
                    :if={entry.reading && entry.reading != ""}
                    id={"entry-#{entry.slug}-reading"}
                    class="text-sm text-gray-500"
                  >
                    【{entry.reading}】
                  </span>
                </div>

                <p
                  :if={entry.senses != []}
                  id={"entry-#{entry.slug}-gloss"}
                  class="text-sm text-gray-700"
                >
                  {hd(entry.senses).gloss}
                </p>

                <span
                  :if={entry.provenance && entry.provenance.reliability != :verified}
                  id={"entry-#{entry.slug}-unverified"}
                  class="text-xs text-amber-600"
                >
                  真偽未確認
                </span>
              </.link>
            </li>
          </ul>
        </section>
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
