defmodule DialectPouchWeb.EntryLive do
  use DialectPouchWeb, :live_view

  import DialectPouchWeb.ProvenanceComponents

  alias DialectPouch.Dictionary
  alias DialectPouch.Feedback

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    entry = Dictionary.get_published_by_slug(slug)

    if is_nil(entry) do
      raise Ecto.NoResultsError, queryable: DialectPouch.Dictionary.Entry
    end

    rate_key =
      if connected?(socket) do
        case get_connect_info(socket, :peer_data) do
          %{address: address} -> address |> :inet.ntoa() |> to_string()
          _ -> "anon"
        end
      else
        "anon"
      end

    {:ok,
     socket
     |> assign(:entry, entry)
     |> assign(:page_title, entry.headword)
     |> assign(:rate_key, rate_key)
     |> assign(:remark_error, nil)
     |> assign(:remarks, Feedback.list_remarks(entry.id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      mobile_title="方言の詳細"
      mobile_back={~p"/search"}
    >
      <div class="pc-only">
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
              id={"entry-header-region-#{er.region.name}"}
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

        <%!-- Remarks (物申す) --%>
        <section id="entry-remarks" aria-label="この言葉への声" class="dsec">
          <h2 class="dsec__label">この言葉への声</h2>

          <ul
            :if={@remarks != []}
            id="remark-list"
            style="list-style:none;margin:0 0 18px;padding:0;display:grid;gap:10px;"
          >
            <li :for={r <- @remarks} id={"remark-#{r.id}"} class="card" style="padding:12px 14px;">
              <div class="row" style="gap:8px;align-items:center;flex-wrap:wrap;">
                <span class="badge badge--user">{remark_kind_label(r.kind)}</span>
                <span class="tiny muted">— {r.author_nickname}</span>
                <button
                  type="button"
                  phx-click="report_remark"
                  phx-value-id={r.id}
                  data-confirm="この投稿を通報しますか？"
                  class="tiny muted"
                  style="margin-left:auto;background:none;border:none;cursor:pointer;"
                >
                  通報
                </button>
              </div>
              <p style="margin:6px 0 0;">{r.body}</p>
            </li>
          </ul>

          <p :if={@remarks == []} class="muted tiny" style="margin:0 0 14px;">
            まだ声はありません。違いや今の言い方があれば教えてください。
          </p>

          <div
            :if={@remark_error}
            id="remark-error"
            class="note note--err"
            style="margin-bottom:12px;"
          >
            <.icon name="hero-exclamation-circle" /> {@remark_error}
          </div>

          <form id="remark-form" phx-submit="submit_remark" class="form-card card">
            <div class="form-2col">
              <div class="fieldset">
                <label class="label" for="remark-kind">種別</label>
                <div class="select-wrap select-wrap--block">
                  <select id="remark-kind" name="kind" class="select">
                    <option :for={{label, value} <- remark_kind_options()} value={value}>
                      {label}
                    </option>
                  </select>
                </div>
              </div>
              <div class="fieldset">
                <label class="label" for="remark-nickname">
                  ニックネーム<span class="req">*</span>
                </label>
                <input
                  id="remark-nickname"
                  name="nickname"
                  class="field"
                  placeholder="匿名では送れません"
                />
              </div>
            </div>
            <div class="fieldset">
              <label class="label" for="remark-body">コメント<span class="req">*</span></label>
              <textarea
                id="remark-body"
                name="body"
                class="field"
                rows="3"
                placeholder="例: 今はあまり使いません / 意味は「すごく」に近いです"
              ></textarea>
            </div>
            <div class="form-foot">
              <p class="tiny muted">ニックネーム付きで即時に公開されます。</p>
              <button type="submit" class="btn btn--primary">
                <.icon name="hero-chat-bubble-left-right" /> 物申す
              </button>
            </div>
          </form>
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
      </div>
      <%!-- /pc-only --%>

      <%!-- ===== MOBILE ENTRY DETAIL ===== --%>
      <div class="m-app sp-only">
        <div class="m-detail">
          <h1 class="m-detail__word">{@entry.headword}</h1>
          <p :if={@entry.reading && @entry.reading != ""} class="m-detail__reading">
            【{@entry.reading}】
          </p>
          <div class="m-detail__tags">
            <span :for={er <- @entry.entry_regions} class="m-chiptag">{er.region.name}</span>
            <span
              :if={@entry.provenance && @entry.provenance.reliability == :verified}
              class="m-badge m-badge--verified"
            >
              <.icon name="hero-check" class="size-3" /> 確定
            </span>
            <span
              :if={!@entry.provenance || @entry.provenance.reliability != :verified}
              class="m-badge m-badge--unverified"
            >
              真偽未確認
            </span>
          </div>

          <div class="m-dsec">
            <p class="m-dsec__label">意味</p>
            <div :for={{sense, idx} <- Enum.with_index(@entry.senses, 1)} class="m-sense">
              <span class="m-sense__num">{idx}</span>
              <div>
                <p class="m-sense__gloss">{sense.gloss}</p>
                <p :if={sense.standard_lemma} class="m-sense__std">
                  標準語：<strong>{sense.standard_lemma}</strong>
                </p>
                <p :if={sense.note} class="m-sense__note">{sense.note}</p>
              </div>
            </div>
            <p :if={@entry.senses == []} class="m-help">意味情報がありません。</p>
          </div>

          <div :if={@entry.examples != []} class="m-dsec">
            <p class="m-dsec__label">用例</p>
            <div :for={ex <- @entry.examples} class="m-example">
              <span style="flex:none;padding-top:2px">
                <.icon
                  name="hero-chat-bubble-left"
                  class="size-4"
                  style="color:var(--color-brand-primary-soft)"
                />
              </span>
              <div>
                <p class="m-example__text">{ex.text}</p>
                <p :if={ex.translation} class="m-example__tr">{ex.translation}</p>
              </div>
            </div>
          </div>

          <div class="m-dsec">
            <p class="m-dsec__label">出典 / provenance</p>
            <.provenance_badge provenance={@entry.provenance} />
          </div>

          <section id="m-entry-remarks" style="margin-top:24px;">
            <h2 class="m-h2" style="font-size:18px;">この言葉への声</h2>

            <ul
              :if={@remarks != []}
              style="list-style:none;margin:10px 0 14px;padding:0;display:grid;gap:8px;"
            >
              <li :for={r <- @remarks} id={"m-remark-#{r.id}"} class="m-note" style="display:block;">
                <div class="row" style="gap:6px;align-items:center;flex-wrap:wrap;">
                  <span class="m-badge m-badge--user">{remark_kind_label(r.kind)}</span>
                  <span class="tiny muted">— {r.author_nickname}</span>
                  <button
                    type="button"
                    phx-click="report_remark"
                    phx-value-id={r.id}
                    data-confirm="この投稿を通報しますか？"
                    class="tiny muted"
                    style="margin-left:auto;background:none;border:none;"
                  >
                    通報
                  </button>
                </div>
                <p style="margin:6px 0 0;">{r.body}</p>
              </li>
            </ul>

            <div :if={@remark_error} class="m-note m-note--err">
              <.icon name="hero-exclamation-circle" class="size-4" /> {@remark_error}
            </div>

            <form id="m-remark-form" phx-submit="submit_remark">
              <div class="m-fieldset">
                <label class="m-label">種別</label>
                <div class="m-selectwrap">
                  <select class="m-select" name="kind">
                    <option :for={{label, value} <- remark_kind_options()} value={value}>{label}</option>
                  </select>
                </div>
              </div>
              <div class="m-fieldset">
                <label class="m-label">ニックネーム<span class="m-req">*</span></label>
                <input class="m-field" name="nickname" placeholder="匿名では送れません" />
              </div>
              <div class="m-fieldset">
                <label class="m-label">コメント<span class="m-req">*</span></label>
                <textarea class="m-field" name="body" rows="3" placeholder="例: 今はあまり使いません"></textarea>
              </div>
              <button type="submit" class="m-btn m-btn--primary">
                <.icon name="hero-chat-bubble-left-right" class="size-4" /> 物申す
              </button>
            </form>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("submit_remark", params, socket) do
    attrs = %{
      "entry_id" => socket.assigns.entry.id,
      "kind" => params["kind"],
      "body" => params["body"],
      "author_kind" => "nickname",
      "author_nickname" => params["nickname"]
    }

    case Feedback.create_remark(attrs, socket.assigns.rate_key) do
      {:ok, _remark} ->
        {:noreply,
         socket
         |> assign(:remark_error, nil)
         |> assign(:remarks, Feedback.list_remarks(socket.assigns.entry.id))}

      {:error, :rate_limited} ->
        {:noreply, assign(socket, :remark_error, "短時間に送信が多すぎます。少し待ってからお試しください。")}

      {:error, _changeset} ->
        {:noreply,
         assign(socket, :remark_error, "ニックネームとコメントを入力してください（匿名では送れません）。")}
    end
  end

  @impl true
  def handle_event("report_remark", %{"id" => id}, socket) do
    # `id` is client-supplied; a stale/unknown id just no-ops with the same
    # confirmation rather than crashing the LiveView.
    Feedback.report_remark(id)
    {:noreply, put_flash(socket, :info, "通報しました。確認します。")}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp remark_kind_options do
    [
      {"意味が違う", "meaning"},
      {"読みが違う", "reading"},
      {"地域が違う", "region"},
      {"もう使わない", "obsolete"},
      {"その他", "other"}
    ]
  end

  defp remark_kind_label(:meaning), do: "意味が違う"
  defp remark_kind_label(:reading), do: "読みが違う"
  defp remark_kind_label(:region), do: "地域が違う"
  defp remark_kind_label(:obsolete), do: "もう使わない"
  defp remark_kind_label(:other), do: "その他"

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
