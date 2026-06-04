defmodule DialectPouchWeb.MapData do
  @moduledoc """
  Japan prefecture tile-map data + region-image coloring.

  All 47 prefectures placed on a 13x13 tile board so the whole reads as
  Japan's arc (北海道 top-right → 沖縄 bottom-left). Each 地方 (region) carries
  its own image color (土地のイメージカラー); a few prefectures override it.
  Tiles are tinted toward warm cream by entry count — fewer = paler wash,
  more = saturated — so the board reads as "土地のグラデーション".
  """

  alias DialectPouch.Dictionary

  # {name, path, col, row, region}
  @prefectures [
    {"北海道", "jp.hokkaido", 12, 1, "北海道"},
    {"青森", "jp.aomori", 11, 3, "東北"},
    {"岩手", "jp.iwate", 12, 4, "東北"},
    {"秋田", "jp.akita", 11, 4, "東北"},
    {"宮城", "jp.miyagi", 12, 5, "東北"},
    {"山形", "jp.yamagata", 11, 5, "東北"},
    {"福島", "jp.fukushima", 12, 6, "東北"},
    {"茨城", "jp.ibaraki", 13, 7, "関東"},
    {"栃木", "jp.tochigi", 12, 7, "関東"},
    {"群馬", "jp.gunma", 11, 7, "関東"},
    {"埼玉", "jp.saitama", 12, 8, "関東"},
    {"東京", "jp.tokyo", 13, 8, "関東"},
    {"千葉", "jp.chiba", 13, 9, "関東"},
    {"神奈川", "jp.kanagawa", 12, 9, "関東"},
    {"新潟", "jp.niigata", 10, 6, "中部"},
    {"長野", "jp.nagano", 11, 8, "中部"},
    {"山梨", "jp.yamanashi", 11, 9, "中部"},
    {"富山", "jp.toyama", 9, 7, "中部"},
    {"石川", "jp.ishikawa", 8, 7, "中部"},
    {"福井", "jp.fukui", 8, 8, "中部"},
    {"岐阜", "jp.gifu", 10, 8, "中部"},
    {"愛知", "jp.aichi", 10, 9, "中部"},
    {"静岡", "jp.shizuoka", 11, 10, "中部"},
    {"三重", "jp.mie", 9, 10, "近畿"},
    {"滋賀", "jp.shiga", 8, 9, "近畿"},
    {"京都", "jp.kyoto", 7, 9, "近畿"},
    {"大阪", "jp.osaka", 7, 10, "近畿"},
    {"兵庫", "jp.hyogo", 6, 9, "近畿"},
    {"奈良", "jp.nara", 8, 10, "近畿"},
    {"和歌山", "jp.wakayama", 7, 11, "近畿"},
    {"鳥取", "jp.tottori", 5, 8, "中国"},
    {"島根", "jp.shimane", 4, 8, "中国"},
    {"岡山", "jp.okayama", 5, 9, "中国"},
    {"広島", "jp.hiroshima", 4, 9, "中国"},
    {"山口", "jp.yamaguchi", 3, 9, "中国"},
    {"徳島", "jp.tokushima", 6, 11, "四国"},
    {"香川", "jp.kagawa", 5, 10, "四国"},
    {"愛媛", "jp.ehime", 4, 11, "四国"},
    {"高知", "jp.kochi", 5, 11, "四国"},
    {"福岡", "jp.fukuoka", 2, 9, "九州"},
    {"佐賀", "jp.saga", 1, 9, "九州"},
    {"長崎", "jp.nagasaki", 1, 10, "九州"},
    {"熊本", "jp.kumamoto", 2, 10, "九州"},
    {"大分", "jp.oita", 3, 10, "九州"},
    {"宮崎", "jp.miyazaki", 2, 11, "九州"},
    {"鹿児島", "jp.kagoshima", 1, 11, "九州"},
    {"沖縄", "jp.okinawa", 1, 13, "沖縄"}
  ]

  # 土地のイメージカラー — one hue per 地方.
  @region_colors %{
    "北海道" => "#5B82A6",
    "東北" => "#6E7A41",
    "関東" => "#34507A",
    "中部" => "#C28A33",
    "近畿" => "#E0772E",
    "中国" => "#B0533A",
    "四国" => "#8E9B33",
    "九州" => "#D45C6E",
    "沖縄" => "#1F9E92"
  }

  # A few prefectures get their own signature hue.
  @pref_colors %{
    "jp.kyoto" => "#8E79B3",
    "jp.osaka" => "#E2742B",
    "jp.tokyo" => "#34507A",
    "jp.hiroshima" => "#B0503A"
  }

  @region_order ["北海道", "東北", "関東", "中部", "近畿", "中国", "四国", "九州", "沖縄"]

  @cream "#FBF7F1"
  @ink "#2B231C"

  @doc "Tile list with live counts and computed heat-tone style string."
  def tiles do
    Enum.map(@prefectures, fn {name, path, col, row, region} ->
      count = Dictionary.count_published_in_subtree(path)

      %{
        name: name,
        path: path,
        col: col,
        row: row,
        count: count,
        region: region,
        heat: heat_tone(pref_color(path, region), count)
      }
    end)
  end

  @doc "Region legend: ordered [%{region, color}] for the map key."
  def regions do
    Enum.map(@region_order, fn r -> %{region: r, color: Map.fetch!(@region_colors, r)} end)
  end

  def pref_color(path, region),
    do: Map.get(@pref_colors, path) || Map.get(@region_colors, region) || "#B6542E"

  # Tint the region color toward warm cream by entry count.
  def heat_tone(_color, 0),
    do:
      "background:var(--color-surface-subtle);color:var(--color-text-disabled);border-color:var(--color-surface-border)"

  def heat_tone(color, count) do
    cream =
      cond do
        count <= 5 -> 0.80
        count <= 10 -> 0.58
        count <= 17 -> 0.30
        true -> 0.08
      end

    bg = mix(color, @cream, cream)
    fg = if cream >= 0.5, do: mix(color, @ink, 0.5), else: "#fff"
    border = mix(bg, color, 0.45)
    "background:#{bg};color:#{fg};border-color:#{border}"
  end

  # ---- hex color helpers ----
  defp mix(a, b, t) do
    {ar, ag, ab} = hex2rgb(a)
    {br, bg, bb} = hex2rgb(b)
    rgb2hex(ar + (br - ar) * t, ag + (bg - ag) * t, ab + (bb - ab) * t)
  end

  defp hex2rgb("#" <> h) do
    {
      String.to_integer(String.slice(h, 0, 2), 16),
      String.to_integer(String.slice(h, 2, 2), 16),
      String.to_integer(String.slice(h, 4, 2), 16)
    }
  end

  defp rgb2hex(r, g, b), do: "#" <> hex2(r) <> hex2(g) <> hex2(b)

  defp hex2(v) do
    v = v |> round() |> max(0) |> min(255)
    v |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(2, "0")
  end
end
