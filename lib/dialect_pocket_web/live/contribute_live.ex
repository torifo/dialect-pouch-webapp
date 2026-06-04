defmodule DialectPocketWeb.ContributeLive do
  use DialectPocketWeb, :live_view

  alias DialectPocket.{Contributions, Regions}

  @impl true
  def mount(_params, _session, socket) do
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
     |> assign(:page_title, "方言を投稿する")
     |> assign(:rate_key, rate_key)
     |> assign(:region_options, region_options())
     |> assign(:status, nil)
     |> assign(:errors, [])
     |> assign(:form, empty_form())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="contribute-page" class="mx-auto max-w-xl space-y-6 py-6 px-4">
        <header class="space-y-1">
          <h1 class="text-xl font-semibold">方言を投稿する</h1>
          <p class="text-xs text-gray-500">
            投稿は確認のうえ公開されます（公開まで未承認の状態で保存されます）。
          </p>
        </header>

        <div
          :if={@status == :ok}
          id="contribute-success"
          class="rounded bg-green-50 px-4 py-3 text-sm text-green-800"
        >
          投稿ありがとうございます。承認後に公開されます。
        </div>

        <div
          :if={@status == :rate_limited}
          id="contribute-rate-limited"
          class="rounded bg-amber-50 px-4 py-3 text-sm text-amber-800"
        >
          短時間に投稿が多すぎます。少し待ってから再度お試しください。
        </div>

        <div
          :if={@errors != []}
          id="contribute-errors"
          class="rounded bg-red-50 px-4 py-3 text-sm text-red-800"
        >
          次の項目を入力してください: {@errors |> Enum.map(&field_label/1) |> Enum.join("、")}
        </div>

        <form id="contribute-form" phx-submit="submit" class="space-y-4">
          <div>
            <label class="block text-sm font-medium" for="c-headword">
              見出し語（方言）<span class="text-red-500">*</span>
            </label>
            <input
              id="c-headword"
              name="headword"
              value={@form["headword"]}
              class={input_class()}
              placeholder="例: なまら"
            />
          </div>
          <div>
            <label class="block text-sm font-medium" for="c-reading">読み（かな）</label>
            <input id="c-reading" name="reading" value={@form["reading"]} class={input_class()} />
          </div>
          <div>
            <label class="block text-sm font-medium" for="c-meaning">
              意味（標準語）<span class="text-red-500">*</span>
            </label>
            <input
              id="c-meaning"
              name="meaning"
              value={@form["meaning"]}
              class={input_class()}
              placeholder="例: とても"
            />
          </div>
          <div>
            <label class="block text-sm font-medium" for="c-region">
              地域<span class="text-red-500">*</span>
            </label>
            <select id="c-region" name="region_path" class={input_class()}>
              <option value="">選択してください</option>
              <option
                :for={{label, value} <- @region_options}
                value={value}
                selected={@form["region_path"] == value}
              >
                {label}
              </option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium" for="c-example">用例</label>
            <input id="c-example" name="example" value={@form["example"]} class={input_class()} />
          </div>
          <div>
            <label class="block text-sm font-medium" for="c-nickname">ニックネーム（任意）</label>
            <input
              id="c-nickname"
              name="nickname"
              value={@form["nickname"]}
              class={input_class()}
              placeholder="匿名で投稿する場合は空欄"
            />
          </div>

          <button
            type="submit"
            class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700"
          >
            投稿する
          </button>
        </form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("submit", params, socket) do
    case Contributions.create_submission(params, socket.assigns.rate_key) do
      {:ok, _entry} ->
        {:noreply,
         socket |> assign(:status, :ok) |> assign(:errors, []) |> assign(:form, empty_form())}

      {:error, :rate_limited} ->
        {:noreply,
         socket
         |> assign(:status, :rate_limited)
         |> assign(:errors, [])
         |> assign(:form, keep(params))}

      {:error, :invalid, fields} ->
        {:noreply,
         socket |> assign(:status, nil) |> assign(:errors, fields) |> assign(:form, keep(params))}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:status, nil)
         |> assign(:errors, [:headword])
         |> assign(:form, keep(params))}
    end
  end

  # -- helpers --------------------------------------------------------------

  defp empty_form,
    do: %{
      "headword" => "",
      "reading" => "",
      "meaning" => "",
      "region_path" => "",
      "example" => "",
      "nickname" => ""
    }

  defp keep(params) do
    for k <- ~w(headword reading meaning region_path example nickname), into: %{} do
      {k, Map.get(params, k, "")}
    end
  end

  defp region_options do
    roots = Regions.roots()
    prefectures = roots |> Enum.flat_map(&Regions.children/1) |> Enum.map(&{&1.name, &1.path})
    Enum.map(roots, &{&1.name, &1.path}) ++ prefectures
  end

  defp input_class,
    do:
      "mt-1 w-full rounded border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"

  defp field_label(:headword), do: "見出し語"
  defp field_label(:meaning), do: "意味"
  defp field_label(:region_path), do: "地域"
  defp field_label(other), do: to_string(other)
end
