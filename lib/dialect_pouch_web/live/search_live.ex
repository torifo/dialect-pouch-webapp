defmodule DialectPouchWeb.SearchLive do
  use DialectPouchWeb, :live_view

  alias DialectPouch.Dictionary.Search

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active_tab={:search}>
      <div class="pc-only">
      <div id="search-page" class="wrap wrap-narrow" style="padding: 40px 24px 72px;">
        <h1 class="page-title">方言を検索</h1>
        <p class="muted" style="margin-top: 6px;">見出し語・読み・意味・用例から部分一致で探します。</p>

        <form
          id="search-form"
          phx-change="search"
          phx-submit="search"
          class="searchbar"
          style="margin-top: 22px;"
        >
          <div style="position: relative; flex: 1;">
            <span style="position: absolute; left: 16px; top: 50%; transform: translateY(-50%); pointer-events: none;">
              <.icon name="hero-magnifying-glass" class="w-5 h-5" style="color: var(--ink-soft);" />
            </span>
            <input
              id="search-input"
              type="search"
              name="q"
              value={@q}
              phx-debounce="300"
              placeholder="方言・読み・意味でさがす（例: なまら）"
              autocomplete="off"
              autofocus
              class="field"
              style="padding-left: 46px;"
            />
          </div>
          <button type="submit" class="btn btn--primary">
            検索
          </button>
        </form>

        <div id="search-results" data-query={@q} style="margin-top: 28px;">
          <%= cond do %>
            <% @q == "" -> %>
              <div id="search-empty-prompt" class="empty">
                <p class="muted">キーワードを入力してください。</p>
              </div>
            <% @results == [] -> %>
              <div id="search-no-results" class="empty">
                <p>「<strong>{@q}</strong>」に一致する項目はありませんでした。</p>
                <p class="tiny muted" style="margin-top: 4px;">
                  別のキーワード・ひらがな・カタカナでお試しください。
                </p>
              </div>
            <% true -> %>
              <p class="tiny muted" style="margin-bottom: 12px;">{length(@results)}件 見つかりました</p>
              <ul
                id="search-result-list"
                class="card-grid"
                style="list-style: none; margin: 0; padding: 0;"
              >
                <li
                  :for={entry <- @results}
                  id={"entry-#{entry.slug}"}
                  data-slug={entry.slug}
                >
                  <.link navigate={~p"/e/#{entry.slug}"} class="entry">
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
                      <%= if entry.provenance && entry.provenance.reliability == :verified do %>
                        <span class="badge badge--verified">
                          <.icon name="hero-check" class="w-3 h-3" />確定
                        </span>
                      <% else %>
                        <span
                          :if={entry.provenance && entry.provenance.reliability != :verified}
                          id={"entry-#{entry.slug}-unverified"}
                          class="badge badge--unverified"
                        >
                          <.icon name="hero-exclamation-circle" class="w-3 h-3" />真偽未確認
                        </span>
                      <% end %>
                    </div>

                    <p
                      :if={entry.senses != []}
                      id={"entry-#{entry.slug}-gloss"}
                      class="entry__gloss"
                    >
                      {hd(entry.senses).gloss}
                    </p>

                    <div class="entry__meta">
                      <span
                        :if={entry.entry_regions != []}
                        id={"entry-#{entry.slug}-regions"}
                        class="entry__region"
                      >
                        <.icon name="hero-map-pin" class="w-3 h-3" />
                        {entry.entry_regions |> Enum.map(& &1.region.name) |> Enum.join("・")}
                      </span>
                    </div>
                  </.link>
                </li>
              </ul>
          <% end %>
        </div>
      </div>
      </div>
      <%!-- /pc-only --%>

      <%!-- ===== MOBILE SEARCH ===== --%>
      <div class="m-app sp-only">
        <div class="m-pad">
          <form
            id="m-search-form"
            phx-change="search"
            phx-submit="search"
            class="m-search"
            style="margin-bottom:8px"
          >
            <span class="m-search__icon">
              <.icon name="hero-magnifying-glass" class="size-5" style="color:var(--color-text-muted)" />
            </span>
            <input
              id="m-search-input"
              class="m-field m-field--search"
              type="search"
              name="q"
              value={@q}
              phx-debounce="300"
              placeholder="方言・読み・意味で検索"
              autocomplete="off"
            />
          </form>
          <%= cond do %>
            <% @q == "" -> %>
              <p class="m-tiny m-muted" style="margin-bottom:10px">人気の検索</p>
              <div class="m-chips" style="flex-wrap:wrap;overflow:visible">
                <.link navigate={~p"/search?q=なまら"} class="m-chip">なまら</.link>
                <.link navigate={~p"/search?q=ほんま"} class="m-chip">ほんま</.link>
                <.link navigate={~p"/search?q=めんそーれ"} class="m-chip">めんそーれ</.link>
                <.link navigate={~p"/search?q=かわいい"} class="m-chip">かわいい</.link>
                <.link navigate={~p"/search?q=とても"} class="m-chip">とても</.link>
                <.link navigate={~p"/search?q=だめ"} class="m-chip">だめ</.link>
              </div>
            <% @results == [] -> %>
              <div class="m-empty">
                <p>「<strong>{@q}</strong>」に一致する項目はありません。</p>
                <p class="m-tiny m-muted" style="margin-top:6px">別のキーワードでお試しください。</p>
              </div>
            <% true -> %>
              <p class="m-tiny m-muted" style="margin:4px 0 12px">
                {length(@results)}件 見つかりました
              </p>
              <div class="m-list">
                <.m_entry :for={entry <- @results} entry={entry} />
              </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, q: "", results: [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    q = Map.get(params, "q", "") |> String.trim()
    results = Search.search(q, limit: 50)
    {:noreply, assign(socket, q: q, results: results)}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    trimmed = String.trim(q)
    results = Search.search(trimmed, limit: 50)

    {:noreply,
     socket
     |> assign(q: trimmed, results: results)
     |> push_patch(to: ~p"/search?q=#{trimmed}")}
  end
end
