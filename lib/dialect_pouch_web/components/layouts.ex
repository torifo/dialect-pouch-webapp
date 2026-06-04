defmodule DialectPouchWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use DialectPouchWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :active_tab, :atom,
    default: nil,
    doc: "mobile bottom-tab highlight: :home | :search | :regions | :convert"

  attr :mobile_title, :string,
    default: nil,
    doc: "when set, the mobile top bar becomes a back+title page bar (detail screens)"

  attr :mobile_back, :string, default: nil, doc: "path the mobile back button navigates to"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="app">
      <input type="checkbox" id="nav-toggle" class="nav__toggle" hidden />
      <header class="nav">
        <div class="wrap nav__inner">
          <.link navigate={~p"/"} class="brand">
            <.brand_mark />
            <span class="brand__name">
              <span class="brand__ja">方言ポーチ</span>
              <span class="brand__en">dialect-pouch</span>
            </span>
          </.link>
          <div class="nav__spacer"></div>
          <nav class="nav__links">
            <.link navigate={~p"/search"} class="nav__link">検索</.link>
            <.link navigate={~p"/regions"} class="nav__link">地域から探す</.link>
            <.link navigate={~p"/convert"} class="nav__link">変換</.link>
            <.link navigate={~p"/contribute"} class="nav__link nav__link--quiet">投稿</.link>
            <.link navigate={~p"/search"} class="nav__cta">
              <.icon name="hero-magnifying-glass" class="size-4" /> 方言を検索
            </.link>
          </nav>
          <label for="nav-toggle" class="nav__burger" aria-label="メニュー">
            <span></span><span></span><span></span>
          </label>
        </div>
        <div class="nav__sheet" id="nav-sheet">
          <div class="wrap nav__sheet-inner">
            <.link navigate={~p"/search"}>方言を検索</.link>
            <.link navigate={~p"/regions"}>地域から探す</.link>
            <.link navigate={~p"/convert"}>変換</.link>
            <.link navigate={~p"/contribute"}>方言を投稿</.link>
          </div>
        </div>
      </header>

      <%!-- mobile top bar: back+title on detail screens, app bar otherwise --%>
      <div :if={@mobile_title} class="m-bar m-bar--page">
        <.link navigate={@mobile_back || ~p"/"} class="m-bar__back" aria-label="戻る">
          <.icon name="hero-arrow-left" class="size-5" />
        </.link>
        <span class="m-bar__pagetitle">{@mobile_title}</span>
      </div>
      <div :if={is_nil(@mobile_title)} class="m-bar">
        <.link navigate={~p"/"} class="m-bar__brand">
          <.brand_mark />
          <span class="m-bar__title">方言ポーチ</span>
        </.link>
        <span class="m-bar__spacer"></span>
        <.link navigate={~p"/search"} class="m-bar__icon" aria-label="検索">
          <.icon name="hero-magnifying-glass" class="size-5" />
        </.link>
        <.link navigate={~p"/contribute"} class="m-bar__icon" aria-label="投稿">
          <.icon name="hero-pencil-square" class="size-5" />
        </.link>
      </div>

      <main style="flex:1">
        {render_slot(@inner_block)}
      </main>

      <.app_footer />

      <%!-- mobile bottom tab bar (home / search / regions / convert) --%>
      <nav class="m-tabs">
        <.link navigate={~p"/"} class={["m-tab", @active_tab == :home && "is-active"]}>
          <.icon name="hero-book-open" class="size-6" />
          <span class="m-tab__label">ホーム</span>
        </.link>
        <.link navigate={~p"/search"} class={["m-tab", @active_tab == :search && "is-active"]}>
          <.icon name="hero-magnifying-glass" class="size-6" />
          <span class="m-tab__label">検索</span>
        </.link>
        <.link navigate={~p"/regions"} class={["m-tab", @active_tab == :regions && "is-active"]}>
          <.icon name="hero-map" class="size-6" />
          <span class="m-tab__label">地域</span>
        </.link>
        <.link navigate={~p"/convert"} class={["m-tab", @active_tab == :convert && "is-active"]}>
          <.icon name="hero-arrows-right-left" class="size-6" />
          <span class="m-tab__label">変換</span>
        </.link>
      </nav>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc "Brand pouch mark (navy)."
  def brand_mark(assigns) do
    ~H"""
    <svg class="brand__mark" width="34" height="34" viewBox="0 0 40 40" fill="none" aria-hidden="true">
      <rect x="3" y="9" width="34" height="28" rx="5" fill="var(--color-brand-primary)" />
      <path
        d="M3 14 L20 22 L37 14 V11 a2 2 0 0 0-2-2 H5 a2 2 0 0 0-2 2 Z"
        fill="var(--color-brand-primary-dark)"
      />
      <rect x="11" y="25" width="18" height="3.2" rx="1.6" fill="#fff" opacity="0.92" />
      <rect x="11" y="30" width="11" height="3.2" rx="1.6" fill="var(--color-accent-info-bright)" />
    </svg>
    """
  end

  @doc "Site footer (navy)."
  def app_footer(assigns) do
    ~H"""
    <footer class="footer">
      <div class="wrap footer__inner">
        <div style="max-width:300px">
          <div class="brand" style="filter:brightness(0) invert(1)">
            <.brand_mark />
            <span class="brand__name">
              <span class="brand__ja" style="color:#fff">方言ポーチ</span>
              <span class="brand__en" style="color:rgba(255,255,255,.6)">dialect-pouch</span>
            </span>
          </div>
          <p style="color:rgba(255,255,255,.7);font-size:var(--fs-sm);margin-top:16px;line-height:1.7">
            日本各地の方言を、気軽に調べて・眺めて・遊ぶ。出典をはっきり示し、「それっぽい嘘」を出さないことを大切にしています。
          </p>
        </div>
        <div class="footer__col">
          <h4>さがす</h4>
          <ul>
            <li><.link navigate={~p"/search"}>方言を検索</.link></li>
            <li><.link navigate={~p"/regions"}>地域から探す</.link></li>
            <li><.link navigate={~p"/convert"}>標準語を変換</.link></li>
          </ul>
        </div>
        <div class="footer__col">
          <h4>参加する</h4>
          <ul>
            <li><.link navigate={~p"/contribute"}>方言を投稿</.link></li>
          </ul>
        </div>
      </div>
      <div class="footer__bar wrap" style="max-width:var(--page-w)">
        <span>© 2026 dialect-pouch</span>
        <span>方言データは各エントリの出典に従います（一部 CC BY-SA 4.0）</span>
      </div>
    </footer>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
