defmodule DialectPocketWeb.ConvertLive do
  use DialectPocketWeb, :live_view

  alias DialectPocket.Conversion
  alias DialectPocket.Regions

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "標準語→方言 変換")
     |> assign(:mode, :word)
     |> assign(:region_path, nil)
     |> assign(:region_options, region_options())
     |> assign(:word, "")
     |> assign(:candidates, [])
     |> assign(:word_searched?, false)
     |> assign(:sentence, "")
     |> assign(:segments, [])
     |> assign(:sentence_searched?, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="convert-page" class="mx-auto max-w-2xl space-y-6 py-6 px-4">
        <header class="space-y-1">
          <h1 class="text-xl font-semibold">標準語を方言に変換</h1>
          <p class="text-xs text-gray-500">
            辞書に登録された方言のみを表示します。該当データが無い場合は推測せず「データなし」と表示します。
          </p>
        </header>

        <%!-- Mode tabs --%>
        <div id="convert-tabs" class="flex gap-1 border-b border-gray-200" role="tablist">
          <button
            id="convert-tab-word"
            type="button"
            role="tab"
            aria-selected={@mode == :word}
            phx-click="set_mode"
            phx-value-mode="word"
            class={[
              "px-4 py-2 text-sm font-medium -mb-px border-b-2",
              @mode == :word && "border-blue-600 text-blue-700",
              @mode != :word && "border-transparent text-gray-500 hover:text-gray-700"
            ]}
          >
            語変換
          </button>
          <button
            id="convert-tab-sentence"
            type="button"
            role="tab"
            aria-selected={@mode == :sentence}
            phx-click="set_mode"
            phx-value-mode="sentence"
            class={[
              "px-4 py-2 text-sm font-medium -mb-px border-b-2",
              @mode == :sentence && "border-blue-600 text-blue-700",
              @mode != :sentence && "border-transparent text-gray-500 hover:text-gray-700"
            ]}
          >
            文章変換
          </button>
        </div>

        <%!-- Word mode --%>
        <section :if={@mode == :word} id="convert-word" aria-label="語変換">
          <form
            id="convert-word-form"
            phx-change="convert_word"
            phx-submit="convert_word"
            class="space-y-3"
          >
            <div class="flex gap-2">
              <input
                id="convert-word-input"
                type="text"
                name="word"
                value={@word}
                phx-debounce="300"
                placeholder="標準語を入力（例: かわいい）"
                autocomplete="off"
                class="flex-1 rounded border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
              />
              <select
                id="convert-word-region"
                name="region_path"
                class="rounded border border-gray-300 px-2 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
              >
                <option
                  :for={{label, value} <- @region_options}
                  value={value}
                  selected={@region_path == nilify(value)}
                >
                  {label}
                </option>
              </select>
            </div>
          </form>

          <div id="convert-word-results" data-word={@word} class="mt-4">
            <%= cond do %>
              <% @word == "" -> %>
                <p id="convert-word-prompt" class="text-sm text-gray-500">
                  標準語を入力してください。
                </p>
              <% @candidates == [] -> %>
                <div id="convert-word-none" class="space-y-1 rounded bg-gray-50 px-4 py-3">
                  <p class="text-sm text-gray-700">
                    「<strong>{@word}</strong>」に対応する方言データはありません。
                  </p>
                  <p class="text-xs text-gray-500">
                    このアプリは登録済みの方言だけを表示します。推測した方言は出しません。
                  </p>
                </div>
              <% true -> %>
                <ul id="convert-word-list" class="divide-y divide-gray-100">
                  <li
                    :for={c <- @candidates}
                    id={"convert-candidate-#{c.slug}"}
                    data-slug={c.slug}
                    class="py-3"
                  >
                    <.link navigate={~p"/e/#{c.slug}"} class="group block space-y-0.5">
                      <div class="flex items-baseline gap-2">
                        <span class="text-base font-semibold text-blue-700 group-hover:underline">
                          {c.headword}
                        </span>
                        <span :if={c.reading && c.reading != ""} class="text-sm text-gray-500">
                          【{c.reading}】
                        </span>
                      </div>
                      <p :if={c.gloss} class="text-sm text-gray-700">{c.gloss}</p>
                      <div class="flex flex-wrap items-center gap-2 mt-0.5">
                        <span :if={c.regions != []} class="text-xs text-gray-400">
                          {Enum.join(c.regions, "・")}
                        </span>
                        <span
                          :if={c.provenance && c.provenance.source_platform}
                          class="text-xs text-gray-400"
                        >
                          出典: {c.provenance.source_platform}
                        </span>
                        <span
                          :if={c.provenance && c.provenance.reliability != :verified}
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
        </section>

        <%!-- Sentence mode --%>
        <section :if={@mode == :sentence} id="convert-sentence" aria-label="文章変換">
          <form
            id="convert-sentence-form"
            phx-change="convert_sentence"
            phx-submit="convert_sentence"
            class="space-y-3"
          >
            <select
              id="convert-sentence-region"
              name="region_path"
              class="rounded border border-gray-300 px-2 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
            >
              <option
                :for={{label, value} <- @region_options}
                value={value}
                selected={@region_path == nilify(value)}
              >
                {label}
              </option>
            </select>
            <textarea
              id="convert-sentence-input"
              name="sentence"
              rows="4"
              phx-debounce="400"
              placeholder="文章を入力すると、含まれる標準語を方言に置き換えます。"
              class="w-full rounded border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
            >{@sentence}</textarea>
          </form>

          <div id="convert-sentence-result" class="mt-4">
            <%= cond do %>
              <% @sentence == "" -> %>
                <p id="convert-sentence-prompt" class="text-sm text-gray-500">
                  文章を入力してください。
                </p>
              <% not match_present?(@segments) -> %>
                <div id="convert-sentence-none" class="space-y-2">
                  <p class="text-xs text-gray-500">
                    一致する標準語が見つかりませんでした（原文をそのまま表示しています）。
                  </p>
                  <p class="whitespace-pre-wrap rounded bg-gray-50 px-4 py-3 text-sm text-gray-700">
                    {@sentence}
                  </p>
                </div>
              <% true -> %>
                <p
                  id="convert-sentence-output"
                  class="whitespace-pre-wrap rounded bg-gray-50 px-4 py-3 text-sm leading-7 text-gray-800"
                >
                  <%= for {seg, idx} <- Enum.with_index(@segments) do %>
                    <%= case seg do %>
                      <% {:plain, text} -> %>
                        <span id={"convert-seg-#{idx}"}>{text}</span>
                      <% {:match, m} -> %>
                        <span
                          id={"convert-seg-#{idx}"}
                          data-standard={m.standard}
                          title={"標準語: #{m.standard}" <> dialects_hint(m)}
                          class="rounded bg-amber-100 px-1 font-semibold text-amber-900 ring-1 ring-inset ring-amber-300"
                        >
                          {m.chosen}
                        </span>
                    <% end %>
                  <% end %>
                </p>
            <% end %>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("set_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :mode, parse_mode(mode))}
  end

  def handle_event("convert_word", params, socket) do
    word = params |> Map.get("word", "") |> String.trim()
    region_path = params |> Map.get("region_path", "") |> nilify()
    candidates = if word == "", do: [], else: Conversion.convert_word(word, region_path)

    {:noreply,
     socket
     |> assign(:word, word)
     |> assign(:region_path, region_path)
     |> assign(:candidates, candidates)
     |> assign(:word_searched?, true)}
  end

  def handle_event("convert_sentence", params, socket) do
    sentence = Map.get(params, "sentence", "")
    region_path = params |> Map.get("region_path", "") |> nilify()

    segments =
      if String.trim(sentence) == "",
        do: [],
        else: Conversion.convert_sentence(sentence, region_path)

    {:noreply,
     socket
     |> assign(:sentence, sentence)
     |> assign(:region_path, region_path)
     |> assign(:segments, segments)
     |> assign(:sentence_searched?, true)}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp parse_mode("sentence"), do: :sentence
  defp parse_mode(_), do: :word

  # Region <select> options: "全国" (no filter) + each root/prefecture path.
  defp region_options do
    roots = Regions.roots()

    prefectures =
      roots
      |> Enum.flat_map(&Regions.children/1)
      |> Enum.map(&{&1.name, &1.path})

    root_opts = Enum.map(roots, &{&1.name, &1.path})

    [{"全国", ""}] ++ root_opts ++ prefectures
  end

  defp nilify(""), do: nil
  defp nilify(nil), do: nil
  defp nilify(value) when is_binary(value), do: value

  defp match_present?(segments) do
    Enum.any?(segments, fn
      {:match, _} -> true
      _ -> false
    end)
  end

  defp dialects_hint(%{dialects: dialects}) when length(dialects) > 1 do
    " / 候補: " <> Enum.join(dialects, "、")
  end

  defp dialects_hint(_), do: ""
end
