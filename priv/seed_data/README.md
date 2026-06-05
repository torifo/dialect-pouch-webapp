# 初期デフォルトシードデータ

検索・変換・地図が「そのまま動く」ための初期方言データ。Task 4.6 の `priv/repo/seeds.exs` が読み込み、Region ツリー＋Entry＋Provenance を投入する。

## ファイル
- `regions_seed.json` … 地域ツリー（国 > 都道府県 >(一部)地域)。`parent_path` で親解決。
- `dialect/<region_path>.json` … 地域ごとの方言エントリ。ファイル単位で `source` を共有。

## エントリ形式
```json
{
  "region_path": "jp.aomori.tsugaru",
  "region_name": "津軽",
  "source": { "platform": "wikipedia", "url": "...",
    "license": "CC BY-SA 4.0", "kind": "community",
    "reliability": "unverified", "observed_at": "2026-06-03" },
  "entries": [ {"headword":"...","reading":"...","meaning":"...","example":"..."} ]
}
```

## 方針・出典
- 現行シードの背骨は **Wikipedia 各方言記事（CC BY-SA 4.0)**。引用・継承表示の前提で採用し、各ファイルに `source.url` を保持。**本文の丸ごと転載はせず**、語・意味・例の事実＋出典リンクのみ。
- `reliability: unverified`（真偽未確認)。UI では「出典:Wikipedia(真偽未確認)」相当のバッジで確定情報と区別する想定（[[要確認バッジ]]）。
- 規約が明確でない情報源(SNS/まとめ)は `kind: community` ＋出典ポインタで今後追加（`docs/research/sources-community.json` 参照)。
- アニメ・漫画・ドラマ由来の表現は、作品名・話数/巻数・公開元 URL などの出典を `source`/provenance に残す。作中台詞を `example` に入れる場合は、出典明記だけでなく、方言用例を説明するために必要な短い引用に限定し、長い台詞・会話全体・歌詞は入れない。語彙だけ確認できれば、原則は `example` 空欄で登録する。

## 現状（2026-06-04）
- 36 地域・740 エントリ（地域ノード42: 国+34都道府県/広域/エリア系ノード)。沖縄・大阪・関西・仙台・津軽・北海道をコミュニティ/公共系出典で大きく補完。
- `jp.kansai` は日本直下の `area` として追加し、大阪・京都・播州など複数地域で共有される関西弁の横断カテゴリとして扱う。
- 地域の `geom`(ポリゴン)は未設定。CODH Geoshape(CC BY 4.0)/国土数値情報 N03 で後付け予定。

## 拡充の進め方
1. `dialect/<jp.xxx[.area]>.json` を追加（既存と同形式・`source` 必須)。
2. 新しい地域は `regions_seed.json` にノード追加（`parent_path` 必須、path ラベルは `[a-z0-9-]`)。
3. `mix run priv/repo/seeds.exs` で再投入（冪等運用は seeds 実装側で担保)。
