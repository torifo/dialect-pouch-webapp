defmodule DialectPocketWeb.AdminLive.Moderation do
  @moduledoc """
  Curator moderation queue. Lists unmoderated (`:draft`) entries — user
  contributions and any LLM-assisted drafts — and lets the curator approve
  (publish) or reject them. Mounted behind `:require_authenticated_admin`.
  """
  use DialectPocketWeb, :live_view

  alias DialectPocket.Dictionary

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "モデレーション")
     |> assign(:pending, Dictionary.list_pending())}
  end

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    {:ok, _} = id |> Dictionary.get_entry!() |> Dictionary.publish_entry()
    {:noreply, socket |> put_flash(:info, "承認して公開しました") |> reload()}
  end

  def handle_event("reject", %{"id" => id}, socket) do
    {:ok, _} = id |> Dictionary.get_entry!() |> Dictionary.reject_entry()
    {:noreply, socket |> put_flash(:info, "却下しました（非公開のまま保持）") |> reload()}
  end

  defp reload(socket), do: assign(socket, :pending, Dictionary.list_pending())

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="moderation-page" class="wrap wrap-narrow" style="padding:32px 24px 72px">
        <h1 class="page-title">モデレーション（未承認の投稿）</h1>
        <p class="help" style="margin-top:6px">
          承認すると公開されます。却下しても削除はせず非公開で保持します。
        </p>

        <p :if={@pending == []} id="moderation-empty" class="empty muted" style="margin-top:24px">
          未承認の投稿はありません。
        </p>

        <ul
          id="moderation-list"
          class="card-grid"
          style="list-style:none;margin:24px 0 0;padding:0"
        >
          <li
            :for={entry <- @pending}
            id={"pending-#{entry.id}"}
            data-id={entry.id}
            class="card"
            style="padding:18px 20px"
          >
            <div class="entry__top">
              <span class="entry__word">{entry.headword}</span>
              <span :if={entry.reading && entry.reading != ""} class="entry__reading">
                【{entry.reading}】
              </span>
              <span :if={entry.provenance} class="badge badge--user">
                {entry.provenance.kind}{provenance_author(entry.provenance)}
              </span>
            </div>
            <p :if={entry.senses != []} class="entry__gloss">{hd(entry.senses).gloss}</p>
            <div class="entry__meta">
              <span :if={entry.entry_regions != []} class="entry__region">
                <.icon name="hero-map-pin" class="size-3" />
                {entry.entry_regions |> Enum.map(& &1.region.name) |> Enum.join("・")}
              </span>
            </div>
            <div class="row" style="gap:8px;margin-top:14px">
              <button
                id={"approve-#{entry.id}"}
                phx-click="approve"
                phx-value-id={entry.id}
                data-confirm="このエントリを公開しますか？"
                class="btn btn--primary"
              >
                承認して公開
              </button>
              <button
                id={"reject-#{entry.id}"}
                phx-click="reject"
                phx-value-id={entry.id}
                data-confirm="このエントリを却下しますか？（非公開のまま保持）"
                class="btn btn--ghost"
              >
                却下
              </button>
            </div>
          </li>
        </ul>
      </div>
    </Layouts.app>
    """
  end

  defp provenance_author(%{observed_author: a}) when is_binary(a) and a != "", do: " / 投稿者: #{a}"
  defp provenance_author(_), do: ""
end
