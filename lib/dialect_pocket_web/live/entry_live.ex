defmodule DialectPocketWeb.EntryLive do
  use DialectPocketWeb, :live_view

  import DialectPocketWeb.ProvenanceComponents

  alias DialectPocket.Dictionary

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    entry = Dictionary.get_published_by_slug(slug)

    if is_nil(entry) do
      raise Ecto.NoResultsError, queryable: DialectPocket.Dictionary.Entry
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
      <div id="entry-page" data-slug={@entry.slug} class="mx-auto max-w-2xl space-y-8 py-6 px-4">
        <%!-- JSON-LD structured data --%>
        {Phoenix.HTML.raw(json_ld(@entry))}

        <%!-- Navigation --%>
        <div id="entry-nav-back">
          <.link navigate={~p"/search"} class="text-sm text-blue-600 hover:underline">
            &larr; 検索に戻る
          </.link>
        </div>

        <%!-- Headword --%>
        <header id="entry-header" class="space-y-1">
          <h1 id="entry-headword" class="text-3xl font-bold tracking-tight">
            {@entry.headword}
          </h1>
          <p
            :if={@entry.reading && @entry.reading != ""}
            id="entry-reading"
            class="text-base text-gray-500"
          >
            【{@entry.reading}】
          </p>
        </header>

        <%!-- Senses --%>
        <section id="entry-senses" aria-label="意味" class="space-y-2">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-400">意味</h2>
          <ol class="space-y-3 list-decimal list-inside">
            <li
              :for={{sense, idx} <- Enum.with_index(@entry.senses, 1)}
              id={"entry-sense-#{idx}"}
              class="space-y-0.5"
            >
              <span class="text-base">{sense.gloss}</span>
              <p :if={sense.standard_lemma} class="ml-4 text-sm text-gray-600">
                標準語: {sense.standard_lemma}
              </p>
              <p :if={sense.note} class="ml-4 text-xs text-gray-400 italic">
                {sense.note}
              </p>
            </li>
          </ol>
          <p :if={@entry.senses == []} class="text-sm text-gray-400">
            意味情報がありません。
          </p>
        </section>

        <%!-- Examples --%>
        <section
          :if={@entry.examples != []}
          id="entry-examples"
          aria-label="用例"
          class="space-y-2"
        >
          <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-400">用例</h2>
          <ul class="space-y-3">
            <li
              :for={{ex, idx} <- Enum.with_index(@entry.examples, 1)}
              id={"entry-example-#{idx}"}
              class="rounded bg-gray-50 px-4 py-3 space-y-0.5"
            >
              <p class="text-base">{ex.text}</p>
              <p :if={ex.translation} class="text-sm text-gray-500">{ex.translation}</p>
            </li>
          </ul>
        </section>

        <%!-- Regions --%>
        <section
          :if={@entry.entry_regions != []}
          id="entry-regions"
          aria-label="地域"
          class="space-y-2"
        >
          <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-400">地域</h2>
          <div class="flex flex-wrap gap-2">
            <span
              :for={er <- @entry.entry_regions}
              id={"entry-region-#{er.region.name}"}
              data-region-level={er.region.level}
              class="rounded-full bg-blue-50 px-3 py-0.5 text-sm text-blue-700 ring-1 ring-inset ring-blue-600/20"
            >
              {er.region.name}
            </span>
          </div>
        </section>

        <%!-- Provenance --%>
        <section id="entry-provenance" aria-label="出典" class="pt-2 border-t border-gray-100">
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
