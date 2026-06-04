# コントリビューションガイド

dialect-pouch への貢献ありがとうございます。本プロジェクトの生命線は
**provenance(出典・素性)** と **「それっぽい嘘を出さない」** ことです。
データもコードも、この原則を守る形で貢献してください。

## 大原則: provenance を必ず付ける
- 追加するすべての方言データに、**どこ由来か(出典)**を必ず添える。
- 出典が確認できないもの・生成 AI が創作したものは**追加しない**。
- 規約が不明な情報源(SNS/まとめ等)は、本文を複製せず**「出典リンク + 事実(語・意味・地域)」**のポインタ形式で扱い、`reliability` を未確認として記録する。
- 詳細なライセンス方針は `docs/research/open-data-sources.md` を参照。

## シードデータの追加手順

シードは `priv/seed_data/` 配下にある:
- `regions_seed.json` … 地域ツリー(`parent_path` で親を解決。path ラベルは `[a-z0-9-]`)
- `dialect/<region_path>.json` … 地域ごとの方言エントリ(ファイル単位で `source` を共有)

### 1. 地域ノードを追加(新しい地域の場合)
`regions_seed.json` にノードを追加する。`parent_path` は必須。

### 2. 方言エントリファイルを追加
`dialect/<jp.xxx[.area]>.json` を既存と同じ形式で作る。`source` は必須:

```json
{
  "region_path": "jp.aomori.tsugaru",
  "region_name": "津軽",
  "source": {
    "platform": "wikipedia",
    "url": "https://ja.wikipedia.org/wiki/...",
    "license": "CC BY-SA 4.0",
    "kind": "community",
    "reliability": "unverified",
    "observed_at": "2026-06-03"
  },
  "entries": [
    { "headword": "...", "reading": "...", "meaning": "...", "example": "..." }
  ]
}
```

- `source.url` … 出典 URL(必須)。
- `source.license` … CC BY-SA 4.0 等。Wikipedia 由来は本文丸ごと転載をせず、語・意味・例の事実 + 出典リンクのみ。
- `source.reliability` … `verified` / `unverified` / `community`。真偽未確認は `unverified`(UI で「真偽未確認」バッジ表示)。
- NINJAL 等の再配布制限ソースは**シードに取り込まず**、出典・検証参照に留める。

### 3. 投入して確認
```bash
mix run priv/repo/seeds.exs   # 再投入(冪等運用は seeds 実装側で担保)
```

または DB ごとやり直す場合は `mix ecto.reset`。

## コード規約
- **フォーマット**: コミット前に必ず `mix format`。
- **コミット前チェック**: `mix precommit` を通す(compile --warnings-as-errors + deps.unlock --unused + format + test)。
- **テスト必須**: 振る舞いを変える変更にはテストを追加・更新する。`mix test` が緑であること。
- 変換は DB ルックアップ限定。推測生成を行うコードは入れない。

## PR の流れ
1. ブランチを切る(`main` へ直接コミットしない)。
2. 変更を実装し、データ追加なら provenance(出典)を必ず付ける。
3. `mix format` → `mix precommit` を実行して緑にする。
4. PR を作成し、変更内容と(データ追加時は)出典・ライセンスを説明に記載する。
5. レビュー・モデレーション後にマージ/公開。
