defmodule DialectPouchWeb.EntryLive do
  use DialectPouchWeb, :live_view

  import DialectPouchWeb.ProvenanceComponents

  alias DialectPouch.Dictionary

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    entry = Dictionary.get_published_by_slug(slug)

    if is_nil(entry) do
      raise Ecto.NoResultsError, queryable: DialectPouch.Dictionary.Entry
    end

    {:ok,
     socket
     |> assign(:entry, entry)
     |> assign(:page_title, entry.headword)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div
        id="entry-page"
        data-slug={@entry.slug}
        class="wrap wrap-narrow"
        style="padding: 32px 24px 72px;"
      >
        <%!-- JSON-LD structured data --%>
        {Phoenix.HTML.raw(json_ld(@entry))}

        <%!-- Navigation --%>
        <div id="entry-nav-back">
          <.link navigate={~p"/search"} class="link-back">
            <.icon name="hero-arrow-left" class="w-4 h-4" />検索に戻る
          </.link>
        </div>

        <%!-- Headword hero --%>
        <header id="entry-header" class="entry-hero">
          <div class="row" style="gap: 12px; flex-wrap: wrap;">
            <h1 id="entry-headword" class="entry-hero__word">
              {@entry.headword}
            </h1>
            <%= if @entry.provenance && @entry.provenance.reliability == :verified do %>
              <span class="badge badge--verified">
                <.icon name="hero-check" class="w-3 h-3" />確定
              </span>
            <% else %>
              <span
                :if={@entry.provenance && @entry.provenance.reliability != :verified}
                class="badge badge--unverified"
              >
                <.icon name="hero-exclamation-circle" class="w-3 h-3" />真偽未確認
              </span>
            <% end %>
          </div>
          <p
            :if={@entry.reading && @entry.reading != ""}
            id="entry-reading"
            class="entry-hero__reading"
          >
            【{@entry.reading}】
          </p>
          <div class="row" style="gap: 8px; margin-top: 14px; flex-wrap: wrap;">
            <span
              :for={er <- @entry.entry_regions}
              id={"entry-region-#{er.region.name}"}
              data-region-level={er.region.level}
              class="chip"
            >
              {er.region.name}
            </span>
          </div>
        </header>

        <%!-- Senses --%>
        <section id="entry-senses" aria-label="意味" class="dsec">
          <h2 class="dsec__label">意味</h2>
          <ol class="senses" style="list-style: none; margin: 0; padding: 0;">
            <li
              :for={{sense, idx} <- Enum.with_index(@entry.senses, 1)}
              id={"entry-sense-#{idx}"}
              class="sense"
            >
              <span class="sense__num">{idx}</span>
              <div>
                <p class="sense__gloss">{sense.gloss}</p>
                <p :if={sense.standard_lemma} class="sense__std">
                  標準語：<strong>{sense.standard_lemma}</strong>
                </p>
                <p :if={sense.note} class="sense__note">{sense.note}</p>
              </div>
            </li>
          </ol>
          <p :if={@entry.senses == []} class="muted tiny" style="margin: 0;">
            意味情報がありません。
          </p>
        </section>

        <%!-- Examples --%>
        <section
          :if={@entry.examples != []}
          id="entry-examples"
          aria-label="用例"
          class="dsec"
        >
          <h2 class="dsec__label">用例</h2>
          <ul class="examples" style="list-style: none; margin: 0; padding: 0;">
            <li
              :for={{ex, idx} <- Enum.with_index(@entry.examples, 1)}
              id={"entry-example-#{idx}"}
              class="example"
            >
              <span class="example__q">
                <.icon
                  name="hero-chat-bubble-left"
                  class="w-4 h-4"
                  style="color: var(--color-brand-primary-soft);"
                />
              </span>
              <div>
                <p class="example__text">{ex.text}</p>
                <p :if={ex.translation} class="example__tr muted">{ex.translation}</p>
              </div>
            </li>
          </ul>
        </section>

        <%!-- Regions --%>
        <section
          :if={@entry.entry_regions != []}
          id="entry-regions"
          aria-label="地域"
          class="dsec"
        >
          <h2 class="dsec__label">地域</h2>
          <div class="row" style="flex-wrap: wrap; gap: 8px;">
            <span
              :for={er <- @entry.entry_regions}
              id={"entry-region-#{er.region.name}"}
              data-region-level={er.region.level}
              class="chip"
            >
              {er.region.name}
            </span>
          </div>
        </section>

        <%!-- Provenance --%>
        <section id="entry-provenance" aria-label="出典" class="dsec">
          <h2 class="dsec__label">出典 / provenance</h2>
          <.provenance_badge provenance={@entry.provenance} />
        </section>
      </div>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp json_ld(entry) do
    description =
      case entry.senses do
        [first | _] -> first.gloss
        [] -> nil
      end

    data =
      %{
        "@context" => "https://schema.org",
        "@type" => "DefinedTerm",
        "name" => entry.headword,
        "inLanguage" => "ja"
      }
      |> then(fn m ->
        if description, do: Map.put(m, "description", description), else: m
      end)

    ~s(<script type="application/ld+json">#{Jason.encode!(data)}</script>)
  end
end
