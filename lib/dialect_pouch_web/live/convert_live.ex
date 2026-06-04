defmodule DialectPouchWeb.ConvertLive do
  use DialectPouchWeb, :live_view

  alias DialectPouch.Conversion
  alias DialectPouch.Regions

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
    <Layouts.app flash={@flash} current_scope={@current_scope} active_tab={:convert}>
      <div class="pc-only">
      <div class="wrap wrap-narrow">
        <div id="convert-page" class="section" style="padding-top: 40px; padding-bottom: 72px;">
          <h1 class="page-title">標準語を方言に変換</h1>
          <p class="help" style="margin-top: 6px;">
            登録されている方言だけを表示します。見つからなければ推測せず「データなし」と出します。
          </p>

          <%!-- タブ + 地域セレクト --%>
          <div
            class="row"
            style="justify-content: space-between; margin-top: 22px; flex-wrap: wrap; gap: 12px;"
          >
            <div id="convert-tabs" class="tabs" role="tablist">
              <button
                id="convert-tab-word"
                type="button"
                role="tab"
                aria-selected={@mode == :word}
                phx-click="set_mode"
                phx-value-mode="word"
                class={"tab#{if @mode == :word, do: " is-active", else: ""}"}
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
                class={"tab#{if @mode == :sentence, do: " is-active", else: ""}"}
              >
                文章変換
              </button>
            </div>
          </div>

          <%!-- 語変換モード --%>
          <section
            :if={@mode == :word}
            id="convert-word"
            aria-label="語変換"
            style="margin-top: 20px;"
          >
            <form
              id="convert-word-form"
              phx-change="convert_word"
              phx-submit="convert_word"
            >
              <div class="row" style="gap: 10px; flex-wrap: wrap;">
                <input
                  id="convert-word-input"
                  type="text"
                  name="word"
                  value={@word}
                  phx-debounce="300"
                  placeholder="標準語を入力（例: かわいい）"
                  autocomplete="off"
                  class="field"
                  style="flex: 1; min-width: 200px;"
                />
                <div class="select-wrap" id="convert-word-region">
                  <.icon name="hero-map-pin" />
                  <select
                    name="region_path"
                    class="select"
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
              </div>
            </form>

            <div id="convert-word-results" data-word={@word} style="margin-top: 22px;">
              <%= cond do %>
                <% @word == "" -> %>
                  <div class="empty">
                    <p id="convert-word-prompt" class="muted">標準語を入力してください。</p>
                  </div>
                <% @candidates == [] -> %>
                  <div id="convert-word-none" class="convert-none">
                    <p>「<strong>{@word}</strong>」に対応する方言データはありません。</p>
                    <p class="tiny muted" style="margin-top: 4px;">
                      このアプリは登録済みの方言だけを表示します。推測した方言は出しません。
                    </p>
                  </div>
                <% true -> %>
                  <p class="tiny muted" style="margin-bottom: 12px;">
                    「{@word}」→ {length(@candidates)}件の方言
                  </p>
                  <ul
                    id="convert-word-list"
                    class="card-grid"
                    style="list-style: none; margin: 0; padding: 0;"
                  >
                    <li
                      :for={c <- @candidates}
                      id={"convert-candidate-#{c.slug}"}
                      data-slug={c.slug}
                    >
                      <.link navigate={~p"/e/#{c.slug}"} class="entry">
                        <div class="entry__top">
                          <span class="entry__word">{c.headword}</span>
                          <span :if={c.reading && c.reading != ""} class="entry__reading">
                            【{c.reading}】
                          </span>
                          <span
                            :if={c.provenance && c.provenance.reliability != :verified}
                            class="badge badge--unverified"
                          >
                            真偽未確認
                          </span>
                        </div>
                        <p :if={c.gloss} class="entry__gloss">{c.gloss}</p>
                        <div class="entry__meta">
                          <span :if={c.regions != []} class="entry__region">
                            <.icon name="hero-map-pin" />
                            {Enum.join(c.regions, "・")}
                          </span>
                          <span
                            :if={c.provenance && c.provenance.source_platform}
                            class="badge badge--source"
                          >
                            出典: {c.provenance.source_platform}
                          </span>
                        </div>
                      </.link>
                    </li>
                  </ul>
              <% end %>
            </div>
          </section>

          <%!-- 文章変換モード --%>
          <section
            :if={@mode == :sentence}
            id="convert-sentence"
            aria-label="文章変換"
            style="margin-top: 20px;"
          >
            <form
              id="convert-sentence-form"
              phx-change="convert_sentence"
              phx-submit="convert_sentence"
              class="stack"
            >
              <div class="select-wrap" id="convert-sentence-region">
                <.icon name="hero-map-pin" />
                <select
                  name="region_path"
                  class="select"
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
              <textarea
                id="convert-sentence-input"
                name="sentence"
                rows="4"
                phx-debounce="400"
                placeholder="文章を入力すると、含まれる標準語を方言に置き換えます。"
                class="field"
                style="resize: vertical;"
              >{@sentence}</textarea>
            </form>

            <div id="convert-sentence-result" style="margin-top: 22px;">
              <%= cond do %>
                <% @sentence == "" -> %>
                  <div class="empty">
                    <p id="convert-sentence-prompt" class="muted">文章を入力してください。</p>
                  </div>
                <% not match_present?(@segments) -> %>
                  <div id="convert-sentence-none">
                    <p class="tiny muted">
                      一致する標準語が見つかりませんでした（原文をそのまま表示しています）。
                    </p>
                    <p class="convert-out" style="margin-top: 8px;">{@sentence}</p>
                  </div>
                <% true -> %>
                  <div>
                    <p class="tiny muted" style="margin-bottom: 10px;">
                      ハイライト部分が方言に置き換わっています（カーソルで標準語を表示）
                    </p>
                    <p
                      id="convert-sentence-output"
                      class="convert-out"
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
                              class="conv-token"
                            >
                              {m.chosen}
                            </span>
                        <% end %>
                      <% end %>
                    </p>
                  </div>
              <% end %>
            </div>
          </section>
        </div>
      </div>
      </div>
      <%!-- /pc-only --%>

      <%!-- ===== MOBILE CONVERT ===== --%>
      <div class="m-app sp-only">
        <div class="m-pad">
          <h1 class="m-h2" style="font-size:22px">標準語を方言に変換</h1>
          <p class="m-help" style="margin-top:6px">
            登録済みの方言のみ表示。該当が無ければ推測せず「データなし」と出します。
          </p>

          <div style="display:flex;flex-direction:column;gap:10px;margin-top:16px">
            <div class="m-segtabs" style="align-self:flex-start">
              <button
                type="button"
                phx-click="set_mode"
                phx-value-mode="word"
                class={"m-segtab#{if @mode == :word, do: " is-active", else: ""}"}
              >
                語変換
              </button>
              <button
                type="button"
                phx-click="set_mode"
                phx-value-mode="sentence"
                class={"m-segtab#{if @mode == :sentence, do: " is-active", else: ""}"}
              >
                文章変換
              </button>
            </div>
          </div>

          <%= if @mode == :word do %>
            <form
              id="m-convert-word-form"
              phx-change="convert_word"
              phx-submit="convert_word"
              style="margin-top:14px"
            >
              <div class="m-selectwrap" style="margin-bottom:10px">
                <.icon name="hero-map-pin" class="size-4" style="color:var(--color-text-muted)" />
                <select name="region_path" class="m-select">
                  <option
                    :for={{label, value} <- @region_options}
                    value={value}
                    selected={@region_path == nilify(value)}
                  >
                    {label}
                  </option>
                </select>
              </div>
              <input
                id="m-convert-word-input"
                class="m-field"
                type="text"
                name="word"
                value={@word}
                phx-debounce="300"
                placeholder="標準語を入力（例: とても）"
                autocomplete="off"
              />
            </form>
            <div style="margin-top:16px">
              <%= cond do %>
                <% @word == "" -> %>
                  <div class="m-chips" style="flex-wrap:wrap;overflow:visible">
                    <button :for={t <- ["とても", "かわいい", "ありがとう", "だめ"]} phx-click="convert_word" phx-value-word={t} class="m-chip">{t}</button>
                  </div>
                <% @candidates == [] -> %>
                  <div class="m-convnone">
                    <p>「<strong>{@word}</strong>」に対応する方言データはありません。</p>
                    <p class="m-tiny m-muted" style="margin-top:5px">推測した方言は出しません。</p>
                  </div>
                <% true -> %>
                  <p class="m-tiny m-muted" style="margin-bottom:10px">
                    「{@word}」→ {length(@candidates)}件
                  </p>
                  <div class="m-list">
                    <.link :for={c <- @candidates} navigate={~p"/e/#{c.slug}"} class="m-entry">
                      <div class="m-entry__top">
                        <span class="m-entry__word">{c.headword}</span>
                        <span :if={c.reading && c.reading != ""} class="m-entry__reading">
                          【{c.reading}】
                        </span>
                        <span
                          :if={c.provenance && c.provenance.reliability != :verified}
                          class="m-badge m-badge--unverified"
                        >
                          真偽未確認
                        </span>
                      </div>
                      <p :if={c.gloss} class="m-entry__gloss">{c.gloss}</p>
                      <div :if={c.regions != []} class="m-entry__meta">
                        <span class="m-entry__region">
                          <.icon name="hero-map-pin" class="size-3" />{Enum.join(c.regions, "・")}
                        </span>
                      </div>
                    </.link>
                  </div>
              <% end %>
            </div>
          <% else %>
            <form
              id="m-convert-sentence-form"
              phx-change="convert_sentence"
              phx-submit="convert_sentence"
              style="margin-top:14px"
            >
              <div class="m-selectwrap" style="margin-bottom:10px">
                <.icon name="hero-map-pin" class="size-4" style="color:var(--color-text-muted)" />
                <select name="region_path" class="m-select">
                  <option
                    :for={{label, value} <- @region_options}
                    value={value}
                    selected={@region_path == nilify(value)}
                  >
                    {label}
                  </option>
                </select>
              </div>
              <textarea
                id="m-convert-sentence-input"
                class="m-field"
                name="sentence"
                rows="3"
                phx-debounce="400"
                placeholder="文章を入力（例: とてもかわいい）"
              >{@sentence}</textarea>
            </form>
            <div style="margin-top:16px">
              <%= cond do %>
                <% @sentence == "" -> %>
                  <div class="m-chips" style="flex-wrap:wrap;overflow:visible">
                    <button :for={t <- ["とてもかわいい", "本当にありがとう", "それはだめ"]} phx-click="convert_sentence" phx-value-sentence={t} class="m-chip">{t}</button>
                  </div>
                <% not match_present?(@segments) -> %>
                  <div class="m-convnone">
                    <p class="m-tiny m-muted">一致する標準語が見つかりませんでした。</p>
                    <p class="m-convout" style="margin-top:8px">{@sentence}</p>
                  </div>
                <% true -> %>
                  <p class="m-tiny m-muted" style="margin-bottom:8px">
                    ハイライト部分が方言に置き換わりました
                  </p>
                  <p class="m-convout">
                    <%= for {seg, idx} <- Enum.with_index(@segments) do %>
                      <%= case seg do %>
                        <% {:plain, text} -> %>
                          <span id={"m-convert-seg-#{idx}"}>{text}</span>
                        <% {:match, m} -> %>
                          <span id={"m-convert-seg-#{idx}"} class="m-conv-token">{m.chosen}</span>
                      <% end %>
                    <% end %>
                  </p>
              <% end %>
            </div>
          <% end %>
        </div>
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
