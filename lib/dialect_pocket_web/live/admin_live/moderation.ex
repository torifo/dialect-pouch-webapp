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
      <div id="moderation-page" class="mx-auto max-w-3xl space-y-6 py-6 px-4">
        <header class="space-y-1">
          <h1 class="text-xl font-semibold">モデレーション（未承認の投稿）</h1>
          <p class="text-xs text-gray-500">承認すると公開されます。却下しても削除はせず非公開で保持します。</p>
        </header>

        <p :if={@pending == []} id="moderation-empty" class="text-sm text-gray-500">
          未承認の投稿はありません。
        </p>

        <ul id="moderation-list" class="divide-y divide-gray-100">
          <li
            :for={entry <- @pending}
            id={"pending-#{entry.id}"}
            data-id={entry.id}
            class="py-4 space-y-1"
          >
            <div class="flex items-baseline gap-2">
              <span class="text-base font-semibold">{entry.headword}</span>
              <span :if={entry.reading && entry.reading != ""} class="text-sm text-gray-500">
                【{entry.reading}】
              </span>
            </div>
            <p :if={entry.senses != []} class="text-sm text-gray-700">{hd(entry.senses).gloss}</p>
            <div class="flex flex-wrap gap-2 text-xs text-gray-400">
              <span :if={entry.entry_regions != []}>
                {entry.entry_regions |> Enum.map(& &1.region.name) |> Enum.join("・")}
              </span>
              <span :if={entry.provenance}>
                出典種別: {entry.provenance.kind}{provenance_author(entry.provenance)}
              </span>
            </div>
            <div class="flex gap-2 pt-1">
              <button
                id={"approve-#{entry.id}"}
                phx-click="approve"
                phx-value-id={entry.id}
                data-confirm="このエントリを公開しますか？"
                class="rounded bg-green-600 px-3 py-1 text-sm text-white hover:bg-green-700"
              >
                承認して公開
              </button>
              <button
                id={"reject-#{entry.id}"}
                phx-click="reject"
                phx-value-id={entry.id}
                data-confirm="このエントリを却下しますか？（非公開のまま保持）"
                class="rounded bg-gray-200 px-3 py-1 text-sm text-gray-700 hover:bg-gray-300"
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
