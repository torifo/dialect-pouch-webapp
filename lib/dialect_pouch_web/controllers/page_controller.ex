defmodule DialectPouchWeb.PageController do
  use DialectPouchWeb, :controller

  alias DialectPouch.Dictionary

  # All 47 prefectures placed on a 13x13 tile board so the whole reads as
  # Japan's arc (北海道 top-right → 沖縄 bottom-left). Counts are filled from
  # the DB; tiles with 0 are shown greyed and non-clickable.
  @prefectures [
    {"北海道", "jp.hokkaido", 12, 1},
    {"青森", "jp.aomori", 11, 3},
    {"岩手", "jp.iwate", 12, 4},
    {"秋田", "jp.akita", 11, 4},
    {"宮城", "jp.miyagi", 12, 5},
    {"山形", "jp.yamagata", 11, 5},
    {"福島", "jp.fukushima", 12, 6},
    {"茨城", "jp.ibaraki", 13, 7},
    {"栃木", "jp.tochigi", 12, 7},
    {"群馬", "jp.gunma", 11, 7},
    {"埼玉", "jp.saitama", 12, 8},
    {"東京", "jp.tokyo", 13, 8},
    {"千葉", "jp.chiba", 13, 9},
    {"神奈川", "jp.kanagawa", 12, 9},
    {"新潟", "jp.niigata", 10, 6},
    {"長野", "jp.nagano", 11, 8},
    {"山梨", "jp.yamanashi", 11, 9},
    {"富山", "jp.toyama", 9, 7},
    {"石川", "jp.ishikawa", 8, 7},
    {"福井", "jp.fukui", 8, 8},
    {"岐阜", "jp.gifu", 10, 8},
    {"愛知", "jp.aichi", 10, 9},
    {"静岡", "jp.shizuoka", 11, 10},
    {"三重", "jp.mie", 9, 10},
    {"滋賀", "jp.shiga", 8, 9},
    {"京都", "jp.kyoto", 7, 9},
    {"大阪", "jp.osaka", 7, 10},
    {"兵庫", "jp.hyogo", 6, 9},
    {"奈良", "jp.nara", 8, 10},
    {"和歌山", "jp.wakayama", 7, 11},
    {"鳥取", "jp.tottori", 5, 8},
    {"島根", "jp.shimane", 4, 8},
    {"岡山", "jp.okayama", 5, 9},
    {"広島", "jp.hiroshima", 4, 9},
    {"山口", "jp.yamaguchi", 3, 9},
    {"徳島", "jp.tokushima", 6, 11},
    {"香川", "jp.kagawa", 5, 10},
    {"愛媛", "jp.ehime", 4, 11},
    {"高知", "jp.kochi", 5, 11},
    {"福岡", "jp.fukuoka", 2, 9},
    {"佐賀", "jp.saga", 1, 9},
    {"長崎", "jp.nagasaki", 1, 10},
    {"熊本", "jp.kumamoto", 2, 10},
    {"大分", "jp.oita", 3, 10},
    {"宮崎", "jp.miyazaki", 2, 11},
    {"鹿児島", "jp.kagoshima", 1, 11},
    {"沖縄", "jp.okinawa", 1, 13}
  ]

  def home(conn, _params) do
    tiles =
      Enum.map(@prefectures, fn {name, path, col, row} ->
        count = Dictionary.count_published_in_subtree(path)
        %{name: name, path: path, col: col, row: row, count: count, heat: heat(count)}
      end)

    render(conn, :home,
      entry_count: Dictionary.count_published(),
      tiles: tiles,
      featured: Dictionary.list_published(6)
    )
  end

  # Heatmap colors mirroring the design's heatColor() thresholds.
  defp heat(0),
    do:
      "background:var(--color-surface-subtle);color:var(--color-text-disabled);border-color:var(--hair)"

  defp heat(n) when n <= 5,
    do: "background:var(--color-brand-primary-pale);color:var(--navy-dark);border-color:#B6CEEA"

  defp heat(n) when n <= 10,
    do: "background:var(--color-brand-primary-soft);color:#0f3d72;border-color:#6e9fd2"

  defp heat(n) when n <= 17,
    do: "background:var(--color-brand-primary-light);color:#fff;border-color:#4583c4"

  defp heat(_),
    do: "background:var(--color-brand-primary);color:#fff;border-color:var(--navy-dark)"
end
