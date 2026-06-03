# dialect-pocket MVP Tasks

## 前提
- スタック: Elixir / Phoenix LiveView / PostgreSQL(+ltree, PostGIS, pg_bigm) / Oban / Tailwind。
- **UI/UX分離**: UX（挙動・状態・インタラクション)はコードで確定。ビジュアル（配色・余白・装飾)は後工程の「claude design」GUI で調整するため作り込まない。UI系タスクの done 条件は「UX挙動がテストで通る + スタイルは差し替え可能な薄い層」。
- 1 task = 概ね 1 commit 相当。各 Wave 内はタスク間依存なし（並列可)。

---

## Implementation Plan

### Wave 1（依存なし・基盤）
- [ ] **Task 1.1**: プロジェクト scaffold & 基盤整備
  - What: `mix phx.new dialect_pocket`（LiveView/Tailwind 有効)。deps 追加（`oban`, `geo_postgis`, `hammer`)。DB拡張マイグレーション（`ltree`, `postgis`, `pg_bigm` の `CREATE EXTENSION`)。Ltree/Geo の Ecto カスタム型を配線。`Oban` を supervision tree に登録。
  - Files: `mix.exs`, `config/*.exs`, `priv/repo/migrations/*_enable_extensions.exs`, `lib/dialect_pocket/application.ex`
  - Done when: `mix phx.server` 起動、`mix test` グリーン、psql で3拡張が有効、Oban テーブル作成済み。
  - Depends on: none

### Wave 2（基盤の上・並列）
- [ ] **Task 2.1**: Regions コンテキスト
  - What: `Region` スキーマ（`path` ltree, `geom` PostGIS, `level`, `parent_id`)。サブツリー取得 API（`path <@ $1`)、子地域取得、データ有り子地域判定。GiST 索引。
  - Files: `lib/dialect_pocket/regions/*`, `priv/repo/migrations/*_create_regions.exs`
  - Done when: 階層投入→サブツリー絞り込み/子地域取得の Context テストが通る。
  - Depends on: 1.1
- [ ] **Task 2.2**: Accounts（管理者認証)
  - What: `phx.gen.auth` で `AdminUser`。`/admin/*` の `on_mount` 認可、ログイン LiveView。
  - Files: `lib/dialect_pocket/accounts/*`, `lib/dialect_pocket_web/.../admin_*`, `router.ex`
  - Done when: 未認証で `/admin` リダイレクト、認証で到達のテストが通る。
  - Depends on: 1.1

### Wave 3（中核データ)
- [ ] **Task 3.1**: Dictionary スキーマ & コンテキスト
  - What: `Entry`/`Sense`/`Example`/`EntryRegion`/`Provenance`/`Source` のマイグレーションとスキーマ。slug 生成、`status` 公開ゲート（`published` のみ公開)、`norm`/`reading`/`gloss` の bigram GIN 索引、provenance 必須制約。
  - Files: `lib/dialect_pocket/dictionary/*`, `priv/repo/migrations/*`
  - Done when: 作成/公開ゲート/provenance 種別保存の Context テストが通る。未検証 `llm_assisted` が公開対象外であることを検証。
  - Depends on: 2.1

### Wave 4（機能バーティカル・並列)
- [ ] **Task 4.1**: 検索（API + SearchLive)
  - What: pg_bigm で headword/reading/gloss を対象にした検索 API（ランク付・部分一致)。`SearchLive`:入力 debounce で即時反映、ローディング/空状態（候補提示)。スタイルは最小。
  - Files: `lib/dialect_pocket/dictionary/search.ex`, `lib/dialect_pocket_web/live/search_live.ex`
  - Done when: 見出し/意味/0件（候補提示)の LiveView テストが通る。
  - Depends on: 3.1
- [ ] **Task 4.2**: エントリ/地域ページ + 地図ドリルダウン
  - What: `/e/:slug`（SSR・JSON-LD・provenance/出典表示・要確認バッジ)。`/r/:region_path`（47県 静的SVG地図 + クリックでドリルダウン、データ無し地域は非活性、選択ハイライト)。
  - Files: `lib/dialect_pocket_web/live/entry_live.ex`, `region_live.ex`, `components/map_component.ex`, `components/provenance_badge.ex`
  - Done when: slug着地（SSR/JSON-LD)、県クリック→配下表示、データ無し時のドリルダウン非表示の LiveView テストが通る。
  - Depends on: 3.1, 2.1
- [ ] **Task 4.3**: 変換（語/言い回し + 文章内置換)
  - What: `Conversion` コンテキスト。標準語→方言（standard_lemma 正規化・完全一致+近傍候補)、方言→標準語。文章内置換は対象地域配下の lemma 集合に対する**最長一致グリーディスキャン**（形態素解析なし)。`ConvertLive`:ライブプレビュー・候補列挙・0件「データなし」明示・生成なし。
  - Files: `lib/dialect_pocket/conversion/*`, `lib/dialect_pocket_web/live/convert_live.ex`
  - Done when: 候補列挙/出典付与/0件「データなし」/文章内ハイライト置換（未一致無改変)の Unit+LiveView テストが通る。
  - Depends on: 3.1, 2.1
- [ ] **Task 4.4**: 投稿（ContributeLive)
  - What: 投稿フォーム（見出し/意味/地域/用例/ニックネーム)。未承認保存 + provenance `user`。必須バリデーション（インライン)、`Hammer` レート制限、送信中/完了/超過フィードバック。XSS サニタイズ。
  - Files: `lib/dialect_pocket/contributions/*`, `lib/dialect_pocket_web/live/contribute_live.ex`
  - Done when: 正常投稿→未承認保存、必須欠落拒否、レート超過拒否の LiveView テストが通る。
  - Depends on: 3.1
- [ ] **Task 4.5**: 取り込みパイプライン（Oban)
  - What: オープンデータ取り込み Worker（出典 `open_data`+Source 付与・upsert)。重複統合（正規化見出し+地域)。LLM 補完 Worker（`llm_assisted`・未検証・非公開、Provider behaviour 抽象、未設定時スキップ)。進捗/失敗記録・再試行。
  - Files: `lib/dialect_pocket/ingestion/*`, `lib/dialect_pocket/ingestion/workers/*`
  - Done when: 取り込み→出典付き登録、重複統合（二重登録なし)、LLM未設定時スキップの Context テストが通る。
  - Depends on: 3.1
- [ ] **Task 4.6**: シードデータ（高精度・手動)
  - What: 数県分の手動キュレーション seed（出典付き)+ loader。開発/テスト/初期表示の土台。
  - Files: `priv/repo/seeds.exs`, `priv/seed_data/*`
  - Done when: `mix run priv/repo/seeds.exs` で地域・エントリ・出典が投入され検索/地図/変換が動作確認できる。
  - Depends on: 3.1

### Wave 5（連結・横断)
- [ ] **Task 5.1**: モデレーション（admin LiveView)
  - What: 未承認一覧（provenance 種別表示)、承認（公開化 + verified 昇格)、却下（理由保持・非公開維持)。管理者認可。
  - Files: `lib/dialect_pocket_web/live/admin/moderation_live.ex`, `lib/dialect_pocket/contributions/moderation.ex`
  - Done when: 承認→公開、却下→非公開維持、未認証拒否の LiveView テストが通る。
  - Depends on: 4.4, 2.2
- [ ] **Task 5.2**: SEO 仕上げ（sitemap + メタ)
  - What: `/sitemap.xml`（Oban 定期再生成)、全公開ページの title/meta/JSON-LD 整備、404 noindex。
  - Files: `lib/dialect_pocket_web/controllers/sitemap_controller.ex`, `components/seo.ex`, `ingestion/workers/sitemap_worker.ex`
  - Done when: sitemap が公開エントリ/地域を列挙、エントリページに JSON-LD 出力のテストが通る。
  - Depends on: 4.2

### Wave 6（品質・配信)
- [ ] **Task 6.1**: E2E 統合テスト（5シナリオ)
  - What: ①検索→着地(SSR/JSON-LD) ②地図→ドリルダウン ③語変換(候補/出典/0件) ④投稿→承認→公開 ⑤取り込み→重複統合。
  - Files: `test/dialect_pocket_web/integration/*`
  - Done when: 5シナリオが CI でグリーン。
  - Depends on: 5.1, 5.2, 4.3, 4.5
- [ ] **Task 6.2**: 配信（mix release + 運用)
  - What: `mix release` 設定、systemd unit もしくは Dockerfile、NGINX リバースプロキシ設定例、DB 定期バックアップ手順、env/secret 管理。
  - Files: `rel/*`, `Dockerfile`, `deploy/nginx.conf`, `deploy/dialect_pocket.service`, `README.md`(運用節)
  - Done when: ステージング相当で release 起動→NGINX 経由でアクセス可能、バックアップ手順が文書化済み。
  - Depends on: 6.1
- [ ] **Task 6.3**: ドキュメント
  - What: README（概要/セットアップ/データ provenance ポリシー/コントリビュート)、`.kiro` spec へのリンク。
  - Files: `README.md`, `CONTRIBUTING.md`
  - Done when: クローン→起動までの手順が README だけで再現できる。
  - Depends on: 6.2

---

## Progress
- Total: 13 tasks | Completed: 0 | In Progress: 0

## 依存グラフ（要約)
```
1.1 → {2.1, 2.2}
2.1 → 3.1
3.1 → {4.1, 4.2, 4.3, 4.4, 4.5, 4.6}   (2.1 も 4.2/4.3 に必要)
{4.4, 2.2} → 5.1
4.2 → 5.2
{5.1, 5.2, 4.3, 4.5} → 6.1 → 6.2 → 6.3
```

## クリティカルパス
`1.1 → 2.1 → 3.1 → 4.x（最重 4.3 変換) → 5.1 → 6.1 → 6.2 → 6.3`
Wave 4 の 6 タスクが最大の並列点（共同開発者と分担しやすい)。
