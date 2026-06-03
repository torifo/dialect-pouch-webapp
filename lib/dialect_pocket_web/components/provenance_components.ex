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
    <span class="text-xs text-gray-400">出典情報なし</span>
    """
  end

  def provenance_badge(%{provenance: %Provenance{reliability: :verified}} = assigns) do
    ~H"""
    <span
      class="inline-flex items-center gap-1 rounded-full bg-green-50 px-2 py-0.5 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20"
      data-reliability="verified"
    >
      確定
    </span>
    """
  end

  def provenance_badge(assigns) do
    ~H"""
    <span
      class="inline-flex flex-wrap items-center gap-1 text-xs text-amber-700"
      data-reliability={to_string(@provenance.reliability)}
    >
      出典: <.source_link provenance={@provenance} />
      <span class="text-amber-600">(真偽未確認)</span>
      <span :if={@provenance.source_license} class="text-gray-400">
        / {@provenance.source_license}
      </span>
      <span :if={@provenance.observed_author} class="text-gray-500">
        by {@provenance.observed_author}
      </span>
    </span>
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
      class="underline hover:text-amber-800"
    >
      {if @provenance.source_platform && @provenance.source_platform != "",
        do: @provenance.source_platform,
        else: @provenance.source_url}
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
    <span class="text-gray-400">不明</span>
    """
  end
end
