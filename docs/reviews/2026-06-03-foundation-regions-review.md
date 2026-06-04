# レビュー: 基盤(Task 1.1) + Regions コンテキスト(Task 2.1)

- 対象: dialect-pouch (Phoenix LiveView + PostgreSQL[ltree/PostGIS/pg_bigm] + Oban)
- レビュー日: 2026-06-03
- 形態: 静的レビューのみ（本環境では Bash/ネットワーク不可。コード実行・テスト実行・依存取得は未実施）
- レビュアー観点: 正確性/バグ・設計整合・セキュリティ/運用・テストの穴・次Waveへの申し送り

---

## 0. レビュー環境上の重大な制約（最初に読むこと）

**`priv/repo/migrations/` 配下のマイグレーションファイルを 1 件も読めていない。**

- 本環境は Bash が不可で、ディレクトリ列挙ができない。`Read` はディレクトリに対して使えず、ファイル名（Phoenix の `YYYYMMDDHHMMSS_*.exs` タイムスタンプ）が不明なため個別 Read もできなかった（候補名を複数試行したが全て `File does not exist`）。
- 一方で `priv/repo/seeds.exs` は読めており（中身はテンプレートのまま、実シードなし）、`docker/postgres/Dockerfile:31` と `docker/postgres/initdb/01-extensions.sql:2` の両方が「拡張は Ecto マイグレーション(Task 1.1)が `CREATE EXTENSION IF NOT EXISTS` する」と明記している。つまり **マイグレーションは存在する前提で書かれている**が、その実体を本レビューでは検証できていない。

→ 観点1(マイグレーションの正確性: 拡張/Oban/regions)・観点4(regions マイグレーションのインデックス)については **未検証**。下記「マイグレーション未検証チェックリスト」を人間が必ず確認すること。これは Blocker 相当の検証ギャップとして扱う。

---

## 所見一覧（重大度別）

### Blocker

**B-1. Regions マイグレーションが未検証（DB 制約とインデックスがコードの前提を満たしているか不明）**
- 根拠: `regions.ex` / `region.ex` の実装は DB 側に以下を **暗黙的に要求**している:
  - `regions.path` の `UNIQUE` 制約 — `region.ex:36` の `unique_constraint(:path)` はこれが無いと機能しない（changeset は通り、DB で衝突しても `Ecto.ConstraintError` が `unique_constraint` にマップされず例外になる）。`regions_test.exs:33-40`「enforces unique path」はこの制約が無ければ落ちる。
  - `regions.parent_id` の FK 制約 — `region.ex:37` の `foreign_key_constraint(:parent_id)` が機能する前提。
  - サブツリー検索 `subtree/1`(`regions.ex:42-50`)・`descendants/1`(`regions.ex:55-57`)・`subtree_ids/1`(`regions.ex:60-68`)は `path LIKE 'prefix.%'` を撃つ。**左端固定の前方一致**なので `regions.path` の **btree インデックス**（`text_pattern_ops` 推奨。後述 H-2）が無いと全件スキャンになる。`order_by: r.path` のソートにも効く。
- 影響: マイグレーション未確認のままでは「Task 1.1/2.1 が DoD を満たす」とは言えない。ユニーク制約欠落は機能バグ（テスト赤）に直結。
- 推奨: 後述チェックリストを人間が確認。特に `unique_index(:regions, [:path])` と `path` への適切な btree インデックス、`parent_id` の `references(... on_delete:)` を確認。

**B-2. 拡張作成マイグレーションの実行ユーザー権限が未検証（`CREATE EXTENSION` は要 superuser/相応権限）**
- 根拠: dev/test は `username: "postgres"`(`config/dev.exs:5`, `config/test.exs:9`)= スーパーユーザなので通る。しかし `config/runtime.exs:28-38` の prod は `DATABASE_URL` の任意ユーザで `mix ecto.migrate` を流す設計。マネージド PG（RDS 等）では `postgis` 拡張作成に追加権限/事前許可が要るのが普通で、`pg_bigm` に至っては **拡張自体がマネージドに存在しない**（カスタム Docker でしか入らない)。
- 影響: prod でマイグレーションが `permission denied to create extension` で停止し得る。`pg_bigm` は本番でも自前 PG が前提（design.md は VPS 前提なので整合はするが、runtime.exs の汎用 `DATABASE_URL` 設計と噛み合っていない)。
- 推奨: 拡張作成マイグレーションに「既に存在すれば skip」(`IF NOT EXISTS`)を使う（initdb と二重実行になるため必須）。prod 運用前提（自前 PG + pg_bigm 入りイメージ）を runtime/README に明記。

### High

**H-1. `subtree` 系のパス境界は安全だが、`like/2` のエスケープは「バリデーション依存」で二重防御がない**
- 根拠: `regions.ex:43,47` は `path <> ".%"` を `like/2` に渡す。境界面では **区切り `.` を必ず挟むため `jp.aomori` が `jp.aomorixxx` に誤マッチしない**（`jp.aomori.%` は `jp.aomori.` 始まりのみ）。これは正しい。`_`/`%` 混入も `region.ex:26` の `@path_format ~r/^[a-z0-9-]+(\.[a-z0-9-]+)*$/` で `path` 投入時に弾く。
- 残リスク（High）:
  1. `subtree/1`・`subtree_ids/1`・`get_region_by_path/1`(`regions.ex:24`) は **任意文字列 `path` を引数に取る公開関数**。呼び出し側がユーザー入力（例: `/r/:region_path` のルートパラメータ。design.md:36）をそのまま渡すと、`changeset` を経由しないため `@path_format` の保護が効かない。`like(r.path, ^(user_input <> ".%"))` でユーザーが `%`/`_` を注入できる。SQL インジェクションにはならない（パラメータ化されている）が、**ワイルドカード注入**で意図しないサブツリーを引ける/全件マッチ(`%`)させられる。
  2. 防御は「DB に入る path は綺麗」という前提のみ。`like/2` 自体の `ESCAPE` を使っていないので、将来ラベル規則を緩めた瞬間に壊れる。
- 推奨:
  - `subtree/1`・`subtree_ids/1`・`descendants/1`・`get_region_by_path/1` の入口で `@path_format` 同等の検証を行う（不正なら空リスト/`nil`)。`Region` に `valid_path?/1` を公開し、context 側で `if Region.valid_path?(path)` ガードする。
  - もしくは `like` 引数を作る際に `_`/`%`/`\` を明示エスケープし `like(..., ^pat, ^escape_opts)` 化（ただし現状ラベル規則なら検証のほうが素直）。
- 補足: `region.ex` docstring(`region.ex:5-8`)と `regions.ex:38-41` は「LIKE 安全」と書いているが、それは **changeset 経由で入った path に対してのみ**真。公開 API の引数経路には当てはまらない点をコメントに明記すべき。

**H-2. `path` インデックスの演算子クラスが LIKE 前方一致に最適化されているか未検証**
- 根拠: `subtree`/`descendants`/`subtree_ids` は全て `LIKE 'x.%'`（左端固定）。PostgreSQL では DB のロケールが `C` でない限り、通常の btree インデックスは `LIKE` 前方一致に使われない。`text_pattern_ops` 付き btree か、`C` コロケーション、または ltree GiST が必要。
- 影響: 10万エントリ規模(NFR Scalability)で regions は小さい（高々数千ノード）ため実害は限定的だが、`order_by: r.path` 込みのプランが全件 Seq Scan + Sort になり得る。設計が「サブツリーを 1 インデックスクエリで」(design.md:198)を謳う以上、インデックス設計の検証は必須。
- 推奨: マイグレーションで `create index(:regions, ["path text_pattern_ops"])` 相当を付与しているか確認。なければ追加。

**H-3. `regions.code` に一意制約が無い（都道府県コードの重複を許す）**
- 根拠: `region.ex:19` `field :code, :string`、changeset(`region.ex:31-38`)は `code` を `cast` するが `validate` も `unique_constraint` もしていない。design.md は「県コード対応の静的 SVG」(design.md:199)で `code` をキーに地図クリック→prefecture を引く設計。
- 影響: 同一 prefecture code を持つ region が複数作れてしまい、地図クリック→region 解決が多重ヒット/不定になる(Wave 4 の地図ドリルダウンで顕在化)。
- 推奨: 少なくとも `level=:prefecture` の範囲で `code` 一意（partial unique index `WHERE level='prefecture'`）。MVP では「`code` は prefecture のみ必須」のバリデーションも検討。

**H-4. 階層整合性がアプリ/DB のどちらでも保証されていない（path と parent_id の不一致を許す）**
- 根拠: `create_region/1`(`regions.ex:14-18`)は `path` と `parent_id` を **独立に**受け取り、整合チェックが無い。`jp.aomori.tsugaru` の `parent_id` が `jp.kagoshima` を指していても通る。`level` と `path` 深さの整合（country=深さ1, prefecture=2, area=3 等）も未チェック。
- 影響: `children/1`(parent_id ベース, `regions.ex:32-34`)と `subtree/1`(path ベース)が **別の木**を返し得る。データ不整合が静かに混入し、地図/変換(subtree_paths, design.md:61)で誤った絞り込みになる。これは provenance の正確性最優先という製品方針(requirements 全体)に反する地雷。
- 推奨: changeset で「`parent` をロードし `path == parent.path <> "." <> last_label` を検証」または「`path` から `parent_id` を導出」のいずれかに一本化。最低限、シード/取り込み時の整合テストを置く。MVP 割り切りなら「path が信頼の源泉、parent_id は表示用キャッシュ」と明記し children も path 由来に統一する手もある。

### Medium

**M-1. dev/test の `secret_key_base` がリポジトリにハードコード**
- 根拠: `config/dev.exs:26`、`config/test.exs:20` に平文。
- 評価: Phoenix 標準の挙動であり dev/test 限定。prod は `runtime.exs:49-54` で env 必須。**許容範囲だが**、この値を prod に流用しない運用ルールの明記は欲しい。署名ソルト `config/config.exs:23` も同様（dev/test 限定リスク)。
- 推奨: そのままで可。README に「dev/test 専用、prod は SECRET_KEY_BASE 必須」と一文。

**M-2. docker の postgres/postgres と initdb の冪等性・拡張二重作成**
- 根拠: `docker-compose.yml:10-12` で `postgres/postgres`、`docker/postgres/initdb/01-extensions.sql` が dev DB に拡張作成。Ecto マイグレーションも同じ拡張を作る前提(Dockerfile:31)。
- 評価: dev 限定・ポート 5432 を localhost に publish。弱パスワードは dev のみなら許容。`CREATE EXTENSION IF NOT EXISTS`(SQL:3-5)なので initdb とマイグレーションの二重実行は冪等で安全（ただしマイグレーション側も `IF NOT EXISTS` であることが条件 → 未検証, B-2参照)。
- リスク(Medium): `initdb` スクリプトは **ボリューム初回作成時のみ**実行される（`pgdata` 永続化, compose:24-25)。既存ボリュームを使い回すと拡張が入らない罠。test DB(`dialect_pouch_test`)は initdb 対象外なので、test の拡張は **マイグレーション頼み**。test でマイグレーションが拡張を作らないと test が全滅する → B-1/B-2 の検証が test 通過の生命線。
- 推奨: README に「test DB の拡張はマイグレーションが作る」明記。`5432` をホストに晒したくなければ `127.0.0.1:5432:5432` バインドに。

**M-3. Dockerfile の `with_llvm=no`・パッケージ purge・arm64 エミュレーション**
- 根拠: `docker/postgres/Dockerfile:22-27`。
- 評価:
  - `with_llvm=no`(L23): JIT bitcode を作らないだけで拡張機能は動く。コメントの説明も正確。pg_bigm の GIN インデックス利用に LLVM は不要。**妥当**。
  - `apt-get purge --auto-remove build-essential postgresql-server-dev-16 curl`(L26)+ `rm -rf /var/lib/apt/lists/*`(L27): 同一 `RUN` レイヤ内なのでイメージサイズ削減に有効。**妥当**。ただし `ca-certificates` を purge していない点は良い（後で TLS が要る場合に備える)。
  - arm64 エミュレーション(Apple Silicon): `postgis/postgis:16-3.4` は multi-arch で arm64 ネイティブ提供あり。**エミュレーションは基本不要**。ただし `pg_bigm` をソースビルドするので、ベースが arm64 なら arm64 バイナリが出来る（問題なし)。CI が amd64 の場合とローカル arm64 でビルド差異が出る点だけ注意。
- リスク(Low-Medium): `PG_BIGM_VERSION=1.2-20240606`(L5)を GitHub tag から取得(L17-18)。ネット依存ビルドなのでタグ消滅/レート制限でビルド不能になり得る。再現性のため将来はベンダリング or ミラー検討。
- 推奨: 現状維持で可。バージョン固定済みは良い。

**M-4. Oban 設定: 失敗ジョブの可視化・再試行の運用設計が薄い**
- 根拠: `config/config.exs:64-69`。`queues: [default: 10, ingestion: 5]`、`plugins: [Pruner(7日)]` のみ。`config/test.exs:24` で `testing: :inline`。
- 評価: 基盤として最小限は揃う。`testing: :inline` は test で同期実行され妥当。
- リスク(Medium): requirements FR-008/US-009 は「進捗と失敗件数の記録」「失敗レコードを後で再試行」を要求。現状 `Oban.Plugins.Pruner` のみで、**`Oban.Plugins.Lifeline`（オーファンジョブ復帰)や Cron（sitemap 定期再生成: design.md:195）が未設定**。`unique` や `max_attempts` 既定の見直しも Wave 3/5 で必要。Pruner 7日は `completed`/`discarded` を消すので、失敗の事後監査ウィンドウが 7 日に制限される点に留意。
- 推奨: Wave 3(Ingestion)着手時に `Oban.Plugins.Cron`(sitemap)・`Lifeline` を追加。`discarded` の保持/通知方針を決める。今は基盤として可。

**M-5. `roots/0`・`children/1` の `order_by: r.name` は安定ソートでない（同名で順序不定）**
- 根拠: `regions.ex:28,33`。`name` は日本語文字列で重複もあり得る（"南部"等）。タイブレークが無い。
- 影響: 同名 region があると表示順が不定 → SSR/SEO 的に毎回 DOM が揺れる可能性。
- 推奨: `order_by: [asc: r.name, asc: r.id]`。`subtree`系は `path` でユニークソートなので問題なし(`regions.ex:49,57`)。

### Low

**L-1. `geom` をスキーマ未マップにした判断**
- 根拠: `region.ex` の schema(L16-24)に `geom` フィールドが無い。design.md:89 は `field :geom, Geo.PostGIS.Geometry` を予定、design.md:200 は「MVP は描画に使わない」と明記。`mix.exs:71` で `geo_postgis` は依存に入っている。
- 評価: **妥当な割り切り**。MVP で使わないカラムを Ecto にマップしないのは健全（`Repo.all` で巨大ジオメトリを毎回引かずに済む)。DB 側にカラムだけ用意しておけば将来 `field :geom` を足すだけ。
- 留意: マイグレーションで `geom` カラム+GiST 索引を作っているか未検証(B-1)。作っていないなら「将来追加」で問題なし。`geo_postgis` を依存に入れたまま未使用なのは `mix deps.unlock --unused`(mix.exs:95 precommit)で警告対象にはならない（コードで `use` していなくても deps は残る)が、未使用依存として認識しておくこと。

**L-2. `create_region/1` にトランザクション境界が無い（単一 insert なので現状は問題なし）**
- 根拠: `regions.ex:14-18` は単発 `Repo.insert`。木構造の整合(H-4)をアプリで取るなら親ロード+検証+insert を `Repo.transaction`/`Multi` で囲む必要が出る。現状は単発なので可。
- 推奨: H-4 を実装する際にトランザクション化。

**L-3. `get_region_by_path/1` は nil を返し、`subtree/1` は空リストを返す — 「存在しない region」の表現が不統一**
- 根拠: `regions.ex:24`(`get_by` → nil)、`regions.ex:42-50`(存在しなくても `[]`)。
- 影響: `/r/:region_path`(design.md:36, 404 方針 design.md:179)で「region 自体が無い」と「region はあるが配下が空」を区別したい。`subtree/1` 単独では区別不能。
- 推奨: 呼び出し側で `get_region_by_path` → nil なら 404、ヒットすれば `subtree` という二段にする方針を context doc に明記。または `fetch_subtree/1 :: {:ok, [..]} | :error`。

**L-4. `levels/0` は公開だが `level` と階層の関係が型レベルで縛られていない**
- 根拠: `region.ex:28` `def levels`、`region.ex:18` `Ecto.Enum values: @levels`。`level` は enum 検証されるが、親子関係（country の子は prefecture 等）は未強制。H-4 と同根。

### Nit

- **N-1.** `regions.ex:8` `import Ecto.Query, warn: false` — 全関数で query を使っているので `warn: false` は不要（消すと未使用 import を検知できる)。
- **N-2.** `region.ex:14` `@type t :: %__MODULE__{}` はフィールド型を持たない緩い定義。Dialyzer 効果が薄い。Nit。
- **N-3.** `regions_test.exs:7` の `create!` ヘルパは `then(fn {:ok, r} -> r end)` で `{:error, _}` 時に `FunctionClauseError`。テスト失敗時のメッセージが不親切。`{:ok, r} = ...; r` で十分。
- **N-4.** `mix.exs:71` `geo_postgis` と未使用の現状(L-1)。`hammer`(mix.exs:72)も Wave 6 まで未使用見込み。基盤として先行追加は許容。
- **N-5.** `config/config.exs:68` Pruner `max_age` を `60*60*24*7` とベタ書き。`# 7 days` コメントはあると親切。

---

## マイグレーション未検証チェックリスト（人間が必ず確認）

本環境で読めなかったため、以下を実ファイルで確認すること:

1. **拡張**: `CREATE EXTENSION IF NOT EXISTS ltree / postgis / pg_bigm` が `IF NOT EXISTS` 付きか（initdb と二重実行されるため必須, B-2/M-2)。`execute/2` で up/down 両方向あるか。
2. **Oban**: `Oban.Migration.up(version: N)` / `down(...)` を使っているか（手書き DDL でないか)。`oban ~> 2.19`(mix.exs:70)に対応した version 指定か。
3. **regions テーブル**:
   - `path :string`(text) に **`unique_index`**（B-1 の `unique_constraint(:path)` 前提）。
   - `path` への **`text_pattern_ops` btree インデックス**（H-2, LIKE 前方一致最適化）。
   - `parent_id` の `references(:regions, on_delete: :restrict|:nilify_all)` と FK インデックス（`belongs_to` のFK index は自動生成されない)。
   - `level` カラム（enum は文字列 or pg enum か）。
   - `code` の一意性（H-3。partial unique を貼っているか)。
   - `geom geometry(...)` カラム + GiST 索引の有無（L-1。MVP 未使用なら無くて可)。
   - `timestamps(type: :utc_datetime)` と config(`config.exs:12`)の整合。
4. **マイグレーション順序**: 拡張作成 → Oban → regions の順か（regions が ltree/gist に依存するなら順序が効く)。

---

## 設計整合の評価: ltree → text materialized-path への変更

design.md:9,89,198 は **ltree + GiST** を明示指定。実装(`region.ex:19` `field :path, :string` / `regions.ex` の `LIKE 'x.%'`)は **text materialized-path + btree LIKE** に変更されている。

### 妥当性（肯定的評価）
- **正確性**: 区切り `.` を挟む前方一致(`path <> ".%"`)により境界誤マッチを構造的に回避できており(H-1 で詳述)、ltree の `<@` と同じサブツリー意味論を text で正しく再現している。ロジックは正しい。
- **依存削減**: ltree を使わなければ regions だけのために GiST/ltree 演算子を学習・保守する必要がなくなる。Ecto に ltree 型を別途定義（`Ltree` カスタム型, design.md:89）する手間も消える。
- **スケール限界の実害は小さい**: regions ノードは国+47都道府県+方言圏で高々数千。LIKE 前方一致 + btree(text_pattern_ops)で 10万エントリ規模 NFR でも regions 検索自体は瓶頸にならない。エントリ本体の絞り込みは `EntryRegion` の region_id 集合(`subtree_ids/1`)で JOIN する設計なので、ltree でなくても性能は出る。

### リスク・将来の移行コスト（辛口）
1. **`code`/`parent_id` 整合の DB 強制力が ltree より弱い**: ltree でも整合は別途必要だが、text-path では「path とノード木の不一致」(H-4)を防ぐ仕組みがゼロ。ここは ltree からの退化点であり、**最大の負債**。
2. **可変長前方一致のインデックス依存**: `text_pattern_ops` or `C` コロケーション必須(H-2)。これを忘れると ltree GiST より遅くなる。マイグレーション未検証ゆえ現状リスク中。
3. **将来 ltree へ戻す移行コスト**: `path text` → `path ltree` は `ALTER ... USING text2ltree(replace(path,'.','.'))`（ラベル規則が ltree 互換 `[a-z0-9_]` であること。**現規則 `[a-z0-9-]` のハイフンは ltree 不可**, region.ex:26）。**ここに地雷**: 現在のラベルにハイフンを許しているため、後で ltree に移すなら全 path のハイフン置換が必要。ltree 復帰可能性を残すなら **今のうちにラベル規則を `[a-z0-9_]`（ハイフン禁止)に揃えておくべき**。これは比較的安価な予防。
4. **祖先(ancestors)クエリの非対称性**: ltree なら `path @> $1` で祖先列挙が 1 クエリ。text-path では「path を `.` で分割して prefix 列を生成 → `WHERE path IN (...)`」が必要（現実装に ancestors 関数は無い)。パンくず表示(Wave 4 region ページ)で必要になる見込み。

### 結論
**MVP の割り切りとして妥当**。ただし (a) H-4 の整合保証、(b) H-2 のインデックス、(c) ハイフン→アンダースコアのラベル規則変更（ltree 復帰オプションを残すなら)、の 3 点は早期に手当て推奨。`geom` 未マップは文句なしに妥当。

---

## 追加すべきテスト（コピペ可能な ExUnit）

`test/dialect_pouch/regions_test.exs` に不足。以下を追加推奨（`async: true`, `DataCase` 前提)。

```elixir
  describe "subtree path-boundary safety" do
    setup do
      jp = create!(%{name: "日本", level: :country, path: "jp"})
      aomori = create!(%{name: "青森県", level: :prefecture, path: "jp.aomori", parent_id: jp.id})
      # 紛らわしい兄弟: プレフィックスは共有するが別ノード
      aomori2 = create!(%{name: "青森類似", level: :prefecture, path: "jp.aomori2", parent_id: jp.id})
      tsugaru = create!(%{name: "津軽", level: :area, path: "jp.aomori.tsugaru", parent_id: aomori.id})
      %{jp: jp, aomori: aomori, aomori2: aomori2, tsugaru: tsugaru}
    end

    test "subtree of jp.aomori does NOT leak jp.aomori2 (boundary match)", %{aomori: aomori} do
      paths = aomori.path |> DialectPouch.Regions.subtree() |> Enum.map(& &1.path)
      assert "jp.aomori" in paths
      assert "jp.aomori.tsugaru" in paths
      # 'jp.aomori2' は 'jp.aomori' で始まるが配下ではない → 漏れてはいけない
      refute "jp.aomori2" in paths
    end

    test "subtree_ids matches subtree and also excludes the prefix-sibling", %{aomori: aomori, aomori2: aomori2} do
      ids = DialectPouch.Regions.subtree_ids(aomori.path)
      refute aomori2.id in ids
    end
  end

  describe "subtree against untrusted / malformed input (wildcard injection)" do
    setup do
      jp = create!(%{name: "日本", level: :country, path: "jp"})
      aomori = create!(%{name: "青森県", level: :prefecture, path: "jp.aomori", parent_id: jp.id})
      %{jp: jp, aomori: aomori}
    end

    # H-1: 公開APIに生ユーザー入力が来た場合のガードを期待。
    # 現状ガードが無ければ '%' が LIKE ワイルドカードとして効き全件返る(=このテストは赤になり、
    # ガード追加の必要性を可視化する)。
    test "a path containing '%' must not match everything", %{} do
      results = DialectPouch.Regions.subtree("%")
      assert results == [], "LIKE wildcard '%' leaked through subtree/1 — add path validation"
    end

    test "a path containing '_' must not act as single-char wildcard" do
      # 'jp_aomori' は 'jp.aomori' を '_'(任意1文字)でマッチしうる
      results = DialectPouch.Regions.subtree("jp_")
      assert results == []
    end
  end

  describe "deep hierarchy" do
    test "subtree returns all levels of a 4-deep chain in path order" do
      a = create!(%{name: "A", level: :country, path: "jp"})
      b = create!(%{name: "B", level: :prefecture, path: "jp.b", parent_id: a.id})
      c = create!(%{name: "C", level: :area, path: "jp.b.c", parent_id: b.id})
      _d = create!(%{name: "D", level: :area, path: "jp.b.c.d", parent_id: c.id})

      paths = DialectPouch.Regions.subtree("jp.b") |> Enum.map(& &1.path)
      assert paths == ["jp.b", "jp.b.c", "jp.b.c.d"], "must be ordered by path and complete"
    end
  end

  describe "empty subtree vs missing region" do
    test "subtree of a leaf returns only itself" do
      jp = create!(%{name: "日本", level: :country, path: "jp"})
      leaf = create!(%{name: "葉", level: :prefecture, path: "jp.leaf", parent_id: jp.id})
      assert [r] = DialectPouch.Regions.subtree(leaf.path)
      assert r.path == "jp.leaf"
    end

    test "subtree of a non-existent path returns []" do
      assert DialectPouch.Regions.subtree("does.not.exist") == []
    end

    test "get_region_by_path returns nil for missing path (distinguishable from empty subtree)" do
      assert DialectPouch.Regions.get_region_by_path("nope") == nil
    end
  end

  describe "unicode names and ordering stability" do
    test "roots/0 has a deterministic order even with duplicate names" do
      # 同名 rootが2件 → order_by: name だけだと順序不定(M-5)。id タイブレークを期待。
      _r1 = create!(%{name: "同名", level: :country, path: "jp"})
      _r2 = create!(%{name: "同名", level: :country, path: "us"})
      ids1 = DialectPouch.Regions.roots() |> Enum.map(& &1.id)
      ids2 = DialectPouch.Regions.roots() |> Enum.map(& &1.id)
      assert ids1 == ids2, "roots/0 order must be stable; add id tiebreaker to order_by"
    end

    test "unicode region name round-trips" do
      assert {:ok, r} =
               DialectPouch.Regions.create_region(%{name: "鹿児島県（奄美）", level: :prefecture, path: "jp.kagoshima"})
      assert r.name == "鹿児島県（奄美）"
    end
  end

  describe "path format edge cases" do
    test "rejects path with trailing dot" do
      assert {:error, cs} = DialectPouch.Regions.create_region(%{name: "x", level: :area, path: "jp.aomori."})
      assert errors_on(cs)[:path]
    end

    test "rejects path with empty label (double dot)" do
      assert {:error, cs} = DialectPouch.Regions.create_region(%{name: "x", level: :area, path: "jp..aomori"})
      assert errors_on(cs)[:path]
    end

    test "rejects uppercase and wildcard chars in label" do
      for bad <- ["JP", "jp.A", "jp.a%b", "jp.a_b", "jp.a b"] do
        assert {:error, cs} = DialectPouch.Regions.create_region(%{name: "x", level: :area, path: bad})
        assert errors_on(cs)[:path], "expected #{bad} to be rejected"
      end
    end

    # H-4: path と parent_id の整合(現状は未強制 → このテストは「あるべき仕様」を示し、実装後に緑化)
    @tag :skip
    test "rejects a region whose path does not descend from its parent's path" do
      jp = create!(%{name: "日本", level: :country, path: "jp"})
      kago = create!(%{name: "鹿児島", level: :prefecture, path: "jp.kagoshima", parent_id: jp.id})
      # 親は kagoshima なのに path は aomori 配下 → 整合違反として弾きたい
      assert {:error, _cs} =
               DialectPouch.Regions.create_region(%{name: "矛盾", level: :area, path: "jp.aomori.x", parent_id: kago.id})
    end
  end

  describe "unique constraint surfaces as changeset error (not raised)" do
    test "duplicate path returns {:error, changeset}, never raises" do
      create!(%{name: "日本", level: :country, path: "jp"})
      assert {:error, cs} = DialectPouch.Regions.create_region(%{name: "dup", level: :country, path: "jp"})
      assert errors_on(cs)[:path]
    end
  end
```

> 注: 「wildcard injection」テスト群と `@tag :skip` の H-4 テストは **現状実装では落ちる/未実装**。これは意図的に「修正すべき欠陥を可視化する」ためのテストです。ガード/整合検証を実装したら緑化してください。

---

## 総合評価

**基盤(Task 1.1)**: Phoenix 1.8 / Bandit / Oban / geo_postgis / hammer の依存選定、config 三分割、Docker(pg_bigm ソースビルド)、dev-setup スクリプトは **筋が良く、コメントも正確**。Dockerfile の `with_llvm=no`・purge・バージョン固定はベストプラクティスに沿う。ただし **マイグレーション実体を本環境で検証できておらず、Task 1.1 の核心(拡張/Oban/regions DDL)が未確認**。ここが最大のブラインドスポット（Blocker B-1/B-2）。

**Regions(Task 2.1)**: サブツリー検索の **境界ロジックは正しく**(H-1 前半)、materialized-path への割り切りも妥当。一方で (1) 公開 API へのワイルドカード注入ガード欠如(H-1)、(2) path↔parent_id↔level の整合保証ゼロ(H-4)、(3) `code` 一意性欠如(H-3)、(4) インデックス未検証(H-2) が積み残し。テストは正常系中心で **境界/不正入力/深い階層/順序安定性が手薄**(観点4)。

総じて **「動く骨格はできているが、製品の生命線である正確性を担保する制約・ガード・整合検証が薄い」** 状態。MVP 基盤としては及第だが、上記 High を Wave 進行前に潰すべき。

- Blocker: 2（B-1 マイグレーション未検証=機能制約の前提不明 / B-2 prod 拡張権限・冪等性)
- High: 4（H-1 ワイルドカード注入 / H-2 インデックス / H-3 code一意性 / H-4 階層整合)
- Medium: 5、Low: 4、Nit: 5

---

## 次 Wave への申し送り

- **Wave 3.1 Dictionary / EntryRegion 結合**:
  - `subtree_ids/1`(`regions.ex:60-68`)が Dictionary の地域絞り込みの要。`entries_in_subtree(region_path)`(design.md:74)は `EntryRegion.region_id IN subtree_ids(path)` で実装する想定だが、**`subtree_ids` が全 region id をメモリに載せてから IN する**ため、サブツリーが巨大だと IN リストが膨らむ。design.md:61 の「path `<@` 対象」を素直にやるなら **regions と entry_regions を JOIN して `regions.path LIKE 'x.%'` を 1 クエリ**にするほうが N+1/巨大 IN を避けられる。Dictionary 側で `subtree_ids` を返してから別クエリ、という二段は避ける設計を推奨。
  - `EntryRegion` の `unique(entry_id, region_id)`(design.md:132)と FK インデックスを忘れずに。region 側 FK(`entry_regions.region_id`)に索引が無いと subtree JOIN が遅い。
- **検索インデックス(FR-003 / pg_bigm)**:
  - `GIN(norm gin_bigm_ops)` 等(design.md:109,118)は **pg_bigm が入った DB でしか作れない**。test DB の拡張作成(B-1/M-2)が通っていることが前提。CI でカスタム postgres イメージを使うこと。
  - `pg_bigm` の 2-gram は 1 文字クエリ("け" 等, design.md:51)で GIN が効きにくい。1〜2 文字検索の挙動は Wave 3 で要計測。
- **provenance 公開ゲート(US-008 / NFR 正確性)**:
  - `status=published` のみ公開・未検証 `llm_assisted` 非公開(design.md:190)は **Dictionary の全公開クエリに横断する不変条件**。Regions の `subtree`/`children` は status を見ないので、Dictionary 側で必ず `where status == :published` を強制するヘルパ(scope)を 1 箇所に集約し、各 LiveView/Controller が直接エントリを引かない設計に。漏れると未検証データが公開される＝製品方針の致命傷。
  - 地図ドリルダウンの「データのある地域のみ表示」(US-003, design.md:74)は **published エントリを持つ region** の判定。Regions に `children_with_data(region, scope)` を足す際、published フィルタを Dictionary 側 scope と共有すること。
- **ハイフン・ラベル規則**: ltree 復帰の可能性を少しでも残すなら、今のうちに `@path_format` を `[a-z0-9_]`(ハイフン禁止)へ。後からの全 path 置換は高コスト（上記「移行コスト」3）。
- **Oban**: Wave 3 で `Cron`(sitemap 再生成)・`Lifeline` プラグイン追加、ingestion ワーカーの `max_attempts`/`unique`(重複統合 US-009)設計。`testing: :inline`(test.exs:24)のままだと ingestion の非同期挙動・リトライをテストできないので、該当テストだけ `Oban.Testing` の `:manual` モードに切り替える方針を。
