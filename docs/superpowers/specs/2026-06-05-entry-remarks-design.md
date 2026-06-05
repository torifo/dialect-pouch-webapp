# 既存エントリへの「物申す」（指摘）＋ 投稿フローの即時公開化 — 設計

- 日付: 2026-06-05
- 対象: dialect-pouch
- ステータス: 設計確定（実装計画はこのあと writing-plans で作成）

## 1. 背景と目的

既存の方言データに「意味が違う」「読みが違う」「今はこう言う」といった**誤りや時代変化の指摘**を、
ユーザーが**ニックネームなど素性を明かしたうえで**残せるようにする。

あわせて、既存の「投稿（contribute）」フローを見直し、**素性があるなら事前承認（draft）を経ずに即公開**する。

## 2. 設計思想（最重要・判断の軸）

> **素性（ニックネーム or 将来の Google ログイン）＝抑止力。コンテンツは即公開。
> スパム/不正の「検知」は公開を止める事前ゲートではなく、別の役割として事後に切り出す。**

現状の「`:draft` → モデレーションで承認して公開」という*事前ゲート*を、*事後検知*へ反転させる。
これが本作業を貫く一貫した方針であり、以下のすべての選定はこの軸に従う。

## 3. スコープ（今回やること / やらないこと）

| 区分 | 内容 | 今回 |
|---|---|---|
| A | 既存エントリへの「物申す」（種別タグ＋コメント＋素性、即公開） | ✅ 実装 |
| B | 投稿フロー変更（素性あり→即 `:published` / 素性なし→従来 `:draft`） | ✅ 実装 |
| C | 検知の役割（事後にスパム/不正を拾う別系統） | ⚠️ 受け皿のみ（通報ボタン＋count、`:hidden` 化UI）。自動検知は後回し |
| Google ログイン | 認証基盤 | ⛔ 接続点（seam）として enum 値だけ用意。フロント/機能への落とし込みは今回見送り |

Google のクライアントID/シークレットは用意可能だが、フロント＋機能に落とし込むボリュームを考慮し今回は見送る。

## 4. データモデル

### 新スキーマ `DialectPouch.Feedback.Remark`（テーブル `entry_remarks`）

| カラム | 型 | 説明 |
|---|---|---|
| `entry_id` | FK → entries | 対象の既存エントリ。`belongs_to :entry` / entry 側 `has_many :remarks` |
| `kind` | `Ecto.Enum` | 種別タグ: `:meaning`(意味が違う) / `:reading`(読みが違う) / `:region`(地域が違う) / `:obsolete`(もう使わない) / `:other`(その他) |
| `body` | text | コメント本文（必須） |
| `author_nickname` | string nullable | 未ログイン時は必須。将来 Google ログイン時は null 可 |
| `author_kind` | `Ecto.Enum` | `:nickname` / `:google`（将来）。素性の種別 |
| `status` | `Ecto.Enum` | `:visible`（既定・即公開）/ `:hidden`（C で隠した時） |
| `report_count` | integer | 通報数（C の受け皿。既定 0） |
| `inserted_at` | utc_datetime | |

- 検証（changeset）: `body` 必須、`kind` 必須、`status`/`author_kind` 必須。
  **`author_kind == :nickname` なら `author_nickname` 必須**（＝匿名禁止を changeset で担保）。
- `:google` は enum 値だけ用意し、今回は発行経路なし（seam）。
- enum 実装は既存 `Provenance` に倣い `Ecto.Enum` + 文字列カラム。

### Context `DialectPouch.Feedback`

- `create_remark(attrs, rate_key)` — 既存 `RateLimiter`（投稿と同じ throttle）→ `status: :visible` で即保存。
  返り値は `{:ok, remark}` | `{:error, :rate_limited}` | `{:error, changeset}`。
- `list_remarks(entry_id)` — `:visible` のみ新しい順。
- `report_remark(id)` — `report_count` を +1（C の最小受け皿）。
- `hide_remark/1` / `unhide_remark/1` — `status` を `:hidden` / `:visible`（モデレーション用）。

## 5. フロー

### A. 指摘（即公開）

```
エントリページ /e/:slug
  └─ [この言葉に物申す] フォーム（種別タグ＋コメント＋ニックネーム）
       └─ Feedback.create_remark  → status :visible で即保存
            └─ 同ページに即時表示（事前承認なし）
```

素性の判定:
- `current_scope` に Google ユーザーがいれば `author_kind: :google`（nickname 任意）
- いなければ `author_kind: :nickname`（**nickname 空欄はバリデーションエラー**）
- 今回の実経路は後者のみ。

### B. 投稿フローの即時公開化（`Contributions.do_create` 改修）

```
素性あり（nickname あり or 将来Google）→ status: :published で作成（即公開）
素性なし（匿名）              → 従来どおり status: :draft（モデレーション行き）
```

→ モデレーションキューは「匿名 draft ＋ 通報フラグ」の*事後*処理場へ役割が変わる。

### C. 検知の受け皿（中身は後回し）

- 指摘カードに「通報」ボタン → `report_remark`（count++）だけ。
- `/admin/moderation` に「通報された指摘」セクションを足し、`:hidden` 化／復元ボタンを置く最小UI。
- 自動スパム判定・しきい値・通知は作らない。

## 6. UI（エントリページ `/e/:slug`）

`entry_live.ex` は `pc-only` ブロックがあるため、PC/モバイル両レイアウトに配置する。
既存 provenance 表示の下に新セクション。

- **「この言葉への声」一覧**: 指摘カード = 種別タグのバッジ＋コメント＋`— ニックネーム`＋日付。
  `:visible` のみ新しい順。0件なら控えめな空表示。
- **「物申す」フォーム**（LiveView `phx-submit`）:
  - 種別タグ: セレクト/チップ（5種）
  - コメント: textarea（必須）
  - ニックネーム: text（未ログイン時必須・プレースホルダで「匿名不可」を明示）。将来 Google ログイン時は隠す。
  - 送信後その場でリストに追加＋フラッシュ。レート制限／バリデーションはインラインエラー。
- **通報リンク**: 各カードに小さく「通報」。`phx-click="report"` で count++（控えめ）。
- daisyUI/Tailwind の既存 `badge`/`card`/`btn` 系を踏襲。

## 7. テスト

- **Feedback context**: `create_remark` 正常系（即 `:visible`）/ `:nickname` で nickname 空欄→エラー /
  レート制限 / `report_remark` / `list_remarks` が `:hidden` を除外。
- **Contributions（B）**: nickname あり→`:published` / nickname なし→`:draft` の分岐。
- **EntryLive**: フォーム送信で指摘が即表示 / 通報でカウント増。
- 既存の `mix test`（ExUnit + LiveView test）パターンに準拠。

## 8. マイグレーション

- `entry_remarks` テーブル新規（上記カラム）。`entry_id` に index、`status` に index（一覧の絞り込み用）。

## 9. 設計判断の記録（なぜこの案か）

| 論点 | 採用 | 退けた案 | 理由 |
|---|---|---|---|
| 指摘の中身 | 種別タグ＋コメント | 自由記述のみ / 構造化修正提案 | 集計・優先度づけがしやすく、将来の構造化提案へ発展可能。自由記述のみは仕分け不能、構造化提案は入力が重すぎ初速を削ぐ |
| 公開タイミング | 即時公開 | 事前承認後に公開 | **素性＝抑止力**の思想。非匿名なら調査可能なので止めない。検知は役割を分けて事後に |
| データモデル | 独立スキーマ `entry_remarks`（案1） | 汎用 `reports` 多態テーブル（案2） | 「ユーザーの声」と「モデレーション通報」を混ぜない＝*役割を分ける*思想に整合。ライフサイクルが綺麗で集計しやすく Entry/Provenance を汚さない |
| 非匿名の担保 | 場合分け（Google ログイン時は匿名可 / それ以外は nickname 必須） | 一律 nickname 必須 / 一律ログイン必須 | Google が素性を担保するなら nickname 不要。基盤未整備の現状は nickname 必須で実用に足る |
| 投稿フロー B | 素性あり→即公開 / 素性なし→draft | 一律即公開 / 現状維持 | A と同じ思想で一貫。匿名投稿だけ従来の事後レビューに残し、モデレーション画面の存在意義も保つ |
| C・Google の今回範囲 | C は受け皿のみ / Google は seam | 全部実装 | フロント＋機能への落とし込みボリュームを考慮し、1スペックの粒度に収める |
