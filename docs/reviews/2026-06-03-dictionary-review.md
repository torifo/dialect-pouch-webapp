# Dictionary 中核 (Task 3.1) レビュー

> 注: Opus サブエージェントによるレビューを2回試みたが、セッション上限/スキルループで未完。
> 本レビューは本体コンテキストでのインライン静的レビュー。実機では 136 tests green・
> シード 372 件投入・変換/検索クエリ動作を確認済み。

## Blocker: 0 件
## High: 0 件

## Medium
- **M-1 provenance 必須は changeset 層のみで DB 保証がない** (`dictionary.ex` create_entry / `entry.ex:38` cast_assoc required)。
  `Entry.changeset` 経由なら必須だが、`Repo.insert(%Entry{})` 直書きすると provenance 無しのエントリを作れる。
  対応: 公開 API を `create_entry/2` に限定する規約で運用（現状そうなっている)。将来 DB トリガ/制約は過剰なので見送り。テストで「changeset が provenance を要求する」ことを担保済み。
- **M-2 standard_lemma の正規化が粗い** (`seeds.exs` primary_lemma: 先頭区切りで分割＋「〜」除去のみ)。
  複数語義・活用・助詞付き(例「〜だから（理由)」→「だから」)は拾えるが、句の意味(「気持ち良い・落ち着く」→「気持ち良い」)は完全一致変換で取りこぼす。
  対応: **Wave 4.3(変換)** で alias/正規化(かな統一・記号除去・複数lemma)を実装する前提。MVPシードとしては許容。

## Low
- **L-1 unique_slug の LIKE プレフィックス** (`dictionary.ex` unique_slug)。
  `base` は headword(任意の日本語)＋"-"＋region ラベル。headword に `%`/`_` が含まれると LIKE が誤動作し得る。
  現実のシード見出しには出現しないが、UGC投稿で混入の可能性。対応: base の `%`/`_` をエスケープ、または slug 生成を区切り固定の連番に。**Wave 4.4(投稿)で対応**。
- **L-2 count+2 連番** はギャップがあっても衝突しないが（count が既存数に追従)、厳密な「最小空き番号」ではない。実害なし。

## Nit
- preload は `@preloads` に集約済みで N+1 なし。`get_published_by_slug` は単一行＋assoc別クエリで適切。
- `norm` は headword+reading を下げて結合。読みが空でも安全。

## 追加したテスト（本レビューで実装)
- 不存在 slug で `get_published_by_slug/1` が nil。
- 1エントリを複数地域にリンクできる。
- 同一 entry+region の二重リンクは一意制約で `{:error, _}`（トランザクション巻き戻し)。

## 総合評価
中核として健全。Blocker/High なし。データ層は実データ372件で end-to-end 動作（検索 bigm・変換 standard_lemma とも実証)。

## Wave 4 への申し送り
- **4.1 検索**: `entries.norm` の pg_bigm GIN を `LIKE '%q%'` で活用。`senses.gloss` も GIN 済み。ランキングは bigm 類似度 or 一致位置で。
- **4.3 変換**: `standard_lemma` の正規化強化(かな/記号/複数lemma/alias)。0件は「データなし」、生成しない。reliability!=verified は「要確認」バッジ。
- **4.2 地図/エントリページ**: slug は日本語を含む → ルーティングは URL エンコード前提。Regions.subtree_ids で「県＋配下」のエントリを JOIN 取得(巨大IN回避)。
- **4.4 投稿**: L-1(slug エスケープ)・provenance kind=:user/ニックネーム・レート制限。
