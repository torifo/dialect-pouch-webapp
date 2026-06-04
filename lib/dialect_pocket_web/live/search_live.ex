defmodule DialectPocketWeb.SearchLive do
  use DialectPocketWeb, :live_view

  alias DialectPocket.Dictionary.Search

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="search-page" class="mx-auto max-w-2xl space-y-6 py-6 px-4">
        <h1 class="text-xl font-semibold">気になる方言をさがす</h1>

        <form
          id="search-form"
          phx-change="search"
          phx-submit="search"
          class="flex gap-2"
        >
          <input
            id="search-input"
            type="search"
            name="q"
            value={@q}
            phx-debounce="300"
            placeholder="方言・読み・意味でさがす（例: なまら）"
            autocomplete="off"
            class="flex-1 rounded border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
          />
          <button
            type="submit"
            class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700"
          >
            検索
          </button>
        </form>

        <div id="search-results" data-query={@q}>
          <%= cond do %>
            <% @q == "" -> %>
              <p id="search-empty-prompt" class="text-sm text-gray-500">
                キーワードを入力してください。
              </p>
            <% @results == [] -> %>
              <div id="search-no-results" class="space-y-1">
                <p class="text-sm text-gray-700">「<strong>{@q}</strong>」に一致する項目はありませんでした。</p>
                <p class="text-xs text-gray-500">
                  別のキーワード・ひらがな・カタカナでお試しください。
                </p>
              </div>
            <% true -> %>
              <ul id="search-result-list" class="divide-y divide-gray-100">
                <li
                  :for={entry <- @results}
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

                    <div class="flex flex-wrap items-center gap-2 mt-0.5">
                      <span
                        :if={entry.entry_regions != []}
                        id={"entry-#{entry.slug}-regions"}
                        class="text-xs text-gray-400"
                      >
                        {entry.entry_regions |> Enum.map(& &1.region.name) |> Enum.join("・")}
                      </span>

                      <span
                        :if={entry.provenance && entry.provenance.reliability != :verified}
                        id={"entry-#{entry.slug}-unverified"}
                        class="text-xs text-amber-600"
                      >
                        真偽未確認
                      </span>
                    </div>
                  </.link>
                </li>
              </ul>
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
