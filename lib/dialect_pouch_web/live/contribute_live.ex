defmodule DialectPouchWeb.ContributeLive do
  use DialectPouchWeb, :live_view

  alias DialectPouch.{Contributions, Regions}

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
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      mobile_title="方言を投稿"
      mobile_back={~p"/"}
    >
      <div class="pc-only">
      <div class="wrap wrap-narrow">
        <div
          id="contribute-page"
          class="section"
          style="padding-top: 40px; padding-bottom: 72px; max-width: 680px;"
        >
          <h1 class="page-title">方言を投稿する</h1>
          <p class="help" style="margin-top: 6px;">
            ニックネームを入れた投稿はそのまま公開されます。匿名の場合は確認のうえ公開されます。
          </p>

          <div
            :if={@status == :ok}
            id="contribute-success"
            class="note note--ok"
            style="margin-top: 20px;"
          >
            <.icon name="hero-check-circle" /> 投稿ありがとうございます。ニックネーム付きの投稿はそのまま公開されます。
          </div>

          <div
            :if={@status == :rate_limited}
            id="contribute-rate-limited"
            class="note note--err"
            style="margin-top: 20px;"
          >
            <.icon name="hero-exclamation-circle" /> 短時間に投稿が多すぎます。少し待ってから再度お試しください。
          </div>

          <div
            :if={@errors != []}
            id="contribute-errors"
            class="note note--err"
            style="margin-top: 20px;"
          >
            <.icon name="hero-exclamation-circle" />
            次の項目を入力してください: {@errors |> Enum.map(&field_label/1) |> Enum.join("、")}
          </div>

          <form id="contribute-form" phx-submit="submit" class="form-card card">
            <div class="fieldset">
              <label class="label" for="c-headword">
                見出し語（方言）<span class="req">*</span>
              </label>
              <input
                id="c-headword"
                name="headword"
                value={@form["headword"]}
                class="field"
                placeholder="例: なまら"
              />
            </div>

            <div class="form-2col">
              <div class="fieldset">
                <label class="label" for="c-reading">読み（かな）</label>
                <input
                  id="c-reading"
                  name="reading"
                  value={@form["reading"]}
                  class="field"
                  placeholder="例: なまら"
                />
              </div>
              <div class="fieldset">
                <label class="label" for="c-region">
                  地域<span class="req">*</span>
                </label>
                <div class="select-wrap select-wrap--block">
                  <select id="c-region" name="region_path" class="select">
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
              </div>
            </div>

            <div class="fieldset">
              <label class="label" for="c-meaning">
                意味（標準語）<span class="req">*</span>
              </label>
              <input
                id="c-meaning"
                name="meaning"
                value={@form["meaning"]}
                class="field"
                placeholder="例: とても"
              />
            </div>

            <div class="fieldset">
              <label class="label" for="c-example">用例</label>
              <input
                id="c-example"
                name="example"
                value={@form["example"]}
                class="field"
                placeholder="例: 今日はなまら寒い"
              />
            </div>

            <div class="fieldset">
              <label class="label" for="c-nickname">ニックネーム（任意）</label>
              <input
                id="c-nickname"
                name="nickname"
                value={@form["nickname"]}
                class="field"
                placeholder="匿名で投稿する場合は空欄"
              />
            </div>

            <div class="form-foot">
              <p class="tiny muted">
                投稿データは <span class="badge badge--user" style="vertical-align: middle;">ユーザー投稿</span>
                として出典が記録され、承認後に「真偽未確認」バッジ付きで公開されます。
              </p>
              <button type="submit" class="btn btn--primary btn--lg">
                <.icon name="hero-pencil" /> 投稿する
              </button>
            </div>
          </form>
        </div>
      </div>
      </div>
      <%!-- /pc-only --%>

      <%!-- ===== MOBILE CONTRIBUTE ===== --%>
      <div class="m-app sp-only">
        <div class="m-pad">
          <h1 class="m-h2" style="font-size:22px">方言を投稿する</h1>
          <p class="m-help" style="margin-top:6px;margin-bottom:16px">
            ニックネーム付きは即時公開、匿名は確認のうえ公開されます。
          </p>

          <div :if={@status == :ok} class="m-note m-note--ok">
            <.icon name="hero-check-circle" class="size-4" /> 投稿ありがとうございます。ニックネーム付きの投稿はそのまま公開されます。
          </div>
          <div :if={@status == :rate_limited} class="m-note m-note--err">
            <.icon name="hero-exclamation-circle" class="size-4" /> 短時間に投稿が多すぎます。少し待ってからお試しください。
          </div>
          <div :if={@errors != []} class="m-note m-note--err">
            <.icon name="hero-exclamation-circle" class="size-4" /> 次を入力してください：{@errors
            |> Enum.map(&field_label/1)
            |> Enum.join("、")}
          </div>

          <form id="m-contribute-form" phx-submit="submit">
            <div class="m-fieldset">
              <label class="m-label">見出し語（方言）<span class="m-req">*</span></label>
              <input class="m-field" name="headword" value={@form["headword"]} placeholder="例: なまら" />
            </div>
            <div class="m-fieldset">
              <label class="m-label">読み（かな）</label>
              <input class="m-field" name="reading" value={@form["reading"]} placeholder="例: なまら" />
            </div>
            <div class="m-fieldset">
              <label class="m-label">地域<span class="m-req">*</span></label>
              <div class="m-selectwrap">
                <select class="m-select" name="region_path">
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
            </div>
            <div class="m-fieldset">
              <label class="m-label">意味（標準語）<span class="m-req">*</span></label>
              <input class="m-field" name="meaning" value={@form["meaning"]} placeholder="例: とても" />
            </div>
            <div class="m-fieldset">
              <label class="m-label">用例</label>
              <input
                class="m-field"
                name="example"
                value={@form["example"]}
                placeholder="例: 今日はなまら寒い"
              />
            </div>
            <div class="m-fieldset">
              <label class="m-label">ニックネーム（任意）</label>
              <input
                class="m-field"
                name="nickname"
                value={@form["nickname"]}
                placeholder="匿名の場合は空欄"
              />
            </div>

            <p class="m-help" style="margin-bottom:12px">
              投稿は
              <span class="m-badge m-badge--user" style="vertical-align:middle">ユーザー投稿</span>
              として記録され、承認後に「真偽未確認」付きで公開されます。
            </p>
            <button type="submit" class="m-btn m-btn--primary">
              <.icon name="hero-pencil-square" class="size-4" /> 投稿する
            </button>
          </form>
        </div>
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

  defp field_label(:headword), do: "見出し語"
  defp field_label(:meaning), do: "意味"
  defp field_label(:region_path), do: "地域"
  defp field_label(other), do: to_string(other)
end
