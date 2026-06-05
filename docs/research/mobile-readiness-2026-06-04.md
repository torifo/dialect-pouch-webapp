# dialect-pouch モバイル対応準備メモ 2026-06-04

目的: 現行コードを確認し、スマートフォン表示を本格対応する前の実装順序・確認項目を整理する。今回はコード変更しない。

## 現状サマリ

- ルート HTML には `<meta name="viewport" content="width=device-width, initial-scale=1" />` があり、モバイル viewport の土台はある。
- 公開ページは `Layouts.app` で共通ナビ/フッターを持つ。ナビは `860px` 以下でハンバーガーに切り替わる。
- CSS は `assets/css/app.css` が本体で、先頭に Tailwind v4 の標準 import/source 構文がある。これは維持する。
- 独自 CSS は主に `assets/css/design/styles.css` と `assets/css/design/screens.css` 由来で、`app.css` に同内容が含まれている。
- 既に `900px`, `860px`, `720px`, `600px` のメディアクエリがあるが、実装は「最低限の折り返し」で、モバイル専用の体験設計までは未完。

## データ量

- 現在 seed 済み: 51 JSON ファイル / 740 entries / 36 region_path。
- `jp.kansai` を日本直下の `area` として追加済み。大阪・京都・播州などで共有される関西弁を横断カテゴリとして扱う。
- 前回作成した増強候補台帳の主要分は seed 化済み。残りは未確認ソース・追加地域・表記ゆれ統合の精査対象。

## 対象画面

| 画面 | ファイル | モバイル準備状況 |
|---|---|---|
| 共通レイアウト | `lib/dialect_pouch_web/components/layouts.ex` | ハンバーガーあり。ただしチェックボックス式の開閉 UI は閉じる導線・フォーカス管理・ARIA が弱い。 |
| トップ | `lib/dialect_pouch_web/controllers/page_html/home.html.heex` | `900px` 以下で hero は 1 カラム。日本タイル地図は横スクロール前提。 |
| 検索 | `lib/dialect_pouch_web/live/search_live.ex` | 横並び searchbar。狭幅では入力とボタンを縦積みにする必要あり。 |
| 地域一覧 | `lib/dialect_pouch_web/live/region_index_live.ex` | `regrid` は自動折り返し。概ね良いが 320px 幅で minmax 150px が詰まる可能性あり。 |
| 地域詳細 | `lib/dialect_pouch_web/live/region_live.ex` | 見出しは 600px 以下で縦積み。パンくずが長い地域名で崩れる可能性あり。 |
| エントリ詳細 | `lib/dialect_pouch_web/live/entry_live.ex` | 語・バッジ・地域 chip は折り返す。出典 dl は `92px 1fr` 固定で狭幅対応が必要。 |
| 変換 | `lib/dialect_pouch_web/live/convert_live.ex` | 入力・select は wrap するが、select 幅とタブの横幅確認が必要。 |
| 投稿 | `lib/dialect_pouch_web/live/contribute_live.ex` | 600px 以下で 1 カラム。フォーム footer のボタン全幅化が必要。 |
| 管理画面 | `lib/dialect_pouch_web/live/admin_live/*` | daisyUI/Tailwind クラスが残る。公開画面より優先度は低いが、認証フォームはスマホ確認対象。 |

## 主なリスク

1. `jmap__board` が `min-width: 480px` 固定。
   - `jmap__scroll` で横スクロールは可能。
   - ただしトップ hero 内で「地図を見る」体験がスマホでは重い。
   - 対応案: 360px 未満では地図を簡略カード/地域一覧 CTA に差し替えるか、`min-width` を `min(480px, calc(100vw - 36px))` 系にする。

2. `.searchbar` が常に `display:flex` 横並び。
   - 検索トップとホームで同じクラスを使う。
   - 対応案: `@media (max-width: 520px) { .searchbar { flex-direction: column; } .searchbar .btn { width: 100%; } }`。

3. inline style が多く、モバイル差分を当てにくい。
   - `home.html.heex`, `search_live.ex`, `region_live.ex`, `entry_live.ex`, `convert_live.ex` に集中。
   - 対応案: `page-shell`, `page-shell--narrow`, `icon-input`, `inline-actions`, `mobile-full` などの共通クラスへ寄せる。

4. フォントスケールが固定寄り。
   - `--fs-*` は読みやすいが、コンパクト画面でやや大きい可能性がある。
   - 対応案: CSS 変数を `clamp()` 化する。ただし「viewport 幅だけで過度にスケールしない」方針で、最小/最大を狭く取る。

5. provenance 表示が狭幅で詰まりやすい。
   - `.prov-dl > div { grid-template-columns: 92px 1fr; }`。
   - 対応案: 520px 以下で `grid-template-columns: 1fr; gap: 4px;` にする。

6. ボタン/リンクのタップターゲットが画面によってばらつく。
   - nav sheet は十分だが、chip や link-arrow は小さい。
   - 対応案: スマホでは最低 44px 高を基準にし、chip は横スクロールまたは wrap とする。

7. daisyUI と独自デザインの混在。
   - `app.css` では daisyUI plugin が読み込まれており、管理系や Phoenix 生成コンポーネントで利用されている。
   - Project guideline では daisyUI を増やさない方針。新規モバイル対応は独自 CSS/Tailwind で行う。

## 実装順序

### Phase 1: 公開画面の崩れ止め

1. `assets/css/design/styles.css` と `assets/css/design/screens.css` にモバイル用の共通クラスを追加し、`app.css` 側も同内容に揃える。
2. `.searchbar`, `.tabs`, `.form-foot`, `.prov-dl`, `.jmap__board`, `.hero__stats` の 320-430px 対応を入れる。
3. inline style のうち、幅・余白・gap に関わるものを共通クラスへ移す。

### Phase 2: ナビゲーションと操作性

1. ハンバーガーの `aria-expanded` 相当を実装し、開閉状態が支援技術に伝わる形へ寄せる。
2. nav sheet のリンク選択後にメニューが閉じる UX を検討する。
3. 検索・変換・投稿の主要フォームで、スマホ時のボタン全幅化と入力順を確認する。

### Phase 3: データ増加後の一覧耐性

1. 検索結果 50 件・地域別 100 件超を想定して、カードの密度を調整する。
2. 長い headword と長い region 名に対して `overflow-wrap:anywhere` を限定適用する。
3. 県別 500 件規模に増えたとき、地域詳細の一覧はページング/検索/見出し索引を検討する。

### Phase 4: 管理画面

1. `AdminLive.Login/Registration/Confirmation/Settings/Moderation` を 320px 幅で確認する。
2. `<.table>` は横スクロール wrapper またはカード表示への切替を検討する。
3. 管理操作ボタンは縦積み・全幅を基本にする。

## 確認 viewport

- iPhone SE 相当: 320 x 568
- 標準スマホ: 390 x 844
- 大型スマホ: 430 x 932
- 小型タブレット: 768 x 1024
- Desktop regression: 1280 x 800

## 目視確認シナリオ

1. `/` を開く。
   - hero の見出しが折り返しで詰まらない。
   - 検索入力と検索ボタンが操作しやすい。
   - 地図が横にはみ出す場合でも、ページ全体に予期しない横スクロールが出ない。

2. `/search?q=なまら` を開く。
   - 入力欄・ボタン・結果カードが 320px 幅で収まる。
   - バッジと読みが entry headword に重ならない。

3. `/regions` と `/r/jp.okinawa` を開く。
   - 地域グリッドが 1-2 カラムで読みやすい。
   - パンくずが折り返しても読める。

4. `/e/:slug` を開く。
   - headword・読み・地域 chip・出典 dl が縦方向に自然に流れる。
   - 長い source URL がカード外へはみ出さない。

5. `/convert` と `/contribute` を開く。
   - select と input が縦積みで操作できる。
   - 送信ボタンが画面下で見切れない。

## テスト準備

- 既存 LiveView tests は DOM 存在確認が中心で、viewport 幅の検証はない。
- モバイル対応実装時は Playwright/Browser でスクリーンショット確認を追加する。
- 最低限の自動確認:
  - 横スクロール幅: `document.documentElement.scrollWidth <= window.innerWidth + 1`
  - 主要 CTA の高さ: 44px 以上
  - `#search-input`, `#convert-word-input`, `#c-headword` が viewport 内に入る

## 先に決めること

- スマホの日本地図を「横スクロールで残す」か「簡略 CTA に差し替える」か。
- 県別 500 件規模になった時の地域詳細一覧を「全件カード表示」のままにするか、「ページング/頭文字索引/検索」にするか。
- 公開画面の inline style 解消を今回のモバイル対応に含めるか、後続の整理タスクに分けるか。
