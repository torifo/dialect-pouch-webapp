defmodule DialectPocketWeb.ProvenanceComponents do
  @moduledoc """
  Components for displaying entry provenance / source attribution.
  """
  use Phoenix.Component

  alias DialectPocket.Dictionary.Provenance

  @doc """
  Renders a provenance badge.

  Shows "確定" for verified entries; otherwise shows source platform,
  optional link, license, and observed author.

  ## Examples

      <.provenance_badge provenance={@entry.provenance} />

  """
  attr :provenance, :any, required: true, doc: "a %Provenance{} struct or nil"

  def provenance_badge(%{provenance: nil} = assigns) do
    ~H"""
    <div class="prov-card">
      <span class="badge badge--source">出典情報なし</span>
    </div>
    """
  end

  def provenance_badge(%{provenance: %Provenance{reliability: :verified}} = assigns) do
    ~H"""
    <div class="prov-card is-ok" data-reliability="verified">
      <div class="row" style="justify-content: space-between; flex-wrap: wrap; gap: 10px;">
        <span class="badge badge--verified">
          <svg
            width="12"
            height="12"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <path d="M20 6 9 17l-5-5" />
          </svg>
          確定
        </span>
      </div>
      <dl class="prov-dl">
        <div>
          <dt>出典</dt>
          <dd><.source_link provenance={@provenance} /></dd>
        </div>
        <div :if={@provenance.source_license && @provenance.source_license != ""}>
          <dt>ライセンス</dt>
          <dd>{@provenance.source_license}</dd>
        </div>
        <div :if={@provenance.observed_author && @provenance.observed_author != ""}>
          <dt>投稿者</dt>
          <dd>{@provenance.observed_author}</dd>
        </div>
        <div>
          <dt>検証状態</dt>
          <dd>確定（出典確認済み）</dd>
        </div>
      </dl>
    </div>
    """
  end

  def provenance_badge(assigns) do
    ~H"""
    <div
      class="prov-card is-warn"
      data-reliability={to_string(@provenance.reliability)}
    >
      <div class="row" style="justify-content: space-between; flex-wrap: wrap; gap: 10px;">
        <span class="badge badge--unverified">
          <svg
            width="12"
            height="12"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <path d="M12 9v4" /><path d="M12 17h.01" /><circle cx="12" cy="12" r="9" />
          </svg>
          真偽未確認
        </span>
      </div>
      <dl class="prov-dl">
        <div>
          <dt>出典</dt>
          <dd><.source_link provenance={@provenance} /></dd>
        </div>
        <div :if={@provenance.source_license && @provenance.source_license != ""}>
          <dt>ライセンス</dt>
          <dd>{@provenance.source_license}</dd>
        </div>
        <div :if={@provenance.observed_author && @provenance.observed_author != ""}>
          <dt>投稿者</dt>
          <dd>{@provenance.observed_author}</dd>
        </div>
        <div>
          <dt>検証状態</dt>
          <dd>真偽未確認（要確認）</dd>
        </div>
      </dl>
    </div>
    """
  end

  @doc """
  Renders the source platform as a link (if `source_url` present) or plain text.
  """
  attr :provenance, :any, required: true

  def source_link(%{provenance: %{source_url: url, source_platform: platform}} = assigns)
      when is_binary(url) and url != "" do
    _ = platform

    ~H"""
    <a
      href={@provenance.source_url}
      target="_blank"
      rel="noopener noreferrer"
      class="ext"
    >
      {if @provenance.source_platform && @provenance.source_platform != "",
        do: @provenance.source_platform,
        else: @provenance.source_url}
      <svg
        width="12"
        height="12"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.5"
        stroke-linecap="round"
        stroke-linejoin="round"
        aria-hidden="true"
      >
        <path d="M10 13a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1 1" /><path d="M14 11a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1-1" />
      </svg>
    </a>
    """
  end

  def source_link(%{provenance: %{source_platform: platform}} = assigns)
      when is_binary(platform) and platform != "" do
    _ = platform

    ~H"""
    <span>{@provenance.source_platform}</span>
    """
  end

  def source_link(assigns) do
    ~H"""
    <span class="muted">不明</span>
    """
  end
end
