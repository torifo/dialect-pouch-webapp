# dialect-pocket

日本各地の方言・言い回しを「気になったら気軽に調べ、眺め、変換して遊べる」consumer 向け Web アプリ。
辞書臭さを排し、検索流入(SEO)と地図ブラウズを入口に「へぇ、面白い」体験を提供する。

各データは**出典・素性(provenance)を一級市民**として保持し、「それっぽい嘘」を出さないことを最優先とする。

## コア体験
- **検索**: 見出し語・読み・意味・用例を対象に日本語 N-gram 部分一致で引く。
- **地図ブラウズ**: 国 > 都道府県 > 地域 の階層をたどって「うちの言葉」を発見する。
- **変換**: 標準語の語/言い回しを指定地域の方言へ(逆引きも)。DB ルックアップ限定で、推測生成はしない。
- **投稿**: ニックネームで方言を投稿し、キュレーター承認後に公開。
- **provenance 表示**: 各エントリの由来(open_data / manual / user / llm_assisted)・出典・検証状態を明示。未検証は「要確認」表示。

## スタック
- **言語/フレームワーク**: Elixir 1.19.5 / OTP 27.3.4 / Phoenix 1.8 (LiveView)
- **DB**: PostgreSQL 16 + PostGIS / pg_bigm(日本語 N-gram 全文検索)/ ltree(地域ツリー)
- **ジョブ**: Oban(取り込み・LLM 補完バッチ)
- **UI**: Tailwind CSS + daisyUI
- **Web サーバ**: Bandit

## 開発セットアップ

### 1. ツールチェーン(asdf)
Erlang / Elixir は asdf で管理する(`.tool-versions` に固定)。macOS 向けの一括セットアップ:

```bash
./scripts/dev-setup.sh
```

(Erlang はソースビルドのため初回は 10〜20 分かかる)

### 2. DB(Docker)
DB だけ Docker で動かす。イメージは `docker/postgres` から pg_bigm をビルドする:

```bash
docker compose up -d db
```

### 3. アプリのセットアップと起動
```bash
mix deps.get
mix ecto.setup     # ecto.create + ecto.migrate + seeds(priv/repo/seeds.exs)
mix phx.server     # http://localhost:4000
```

`mix ecto.setup` のシード投入で **31 地域・約 372 エントリ**(地域ノード 37: 国 + 29 県 + 6 エリア)が入る。
DB をやり直したいときは `mix ecto.reset`。

## 主要ルート
| パス | 内容 |
|---|---|
| `/` | ホーム |
| `/search` | 検索(LiveView) |
| `/e/:slug` | エントリ個別ページ(SSR・JSON-LD) |
| `/regions` | 地域一覧 |
| `/r/:region_path` | 地域別ページ |
| `/convert` | 変換 |
| `/contribute` | 投稿 |
| `/admin/moderation` | モデレーション(管理者認証) |
| `/sitemap.xml` | サイトマップ |

## テスト
```bash
mix test          # テスト実行(ecto.create/migrate を含む)
mix precommit     # compile --warnings-as-errors + deps.unlock --unused + format + test
```

コミット前は `mix format` と `mix precommit` を通すこと。

## 本番デプロイ

アプリは `mix release`(生成済み `Dockerfile`)。最終イメージは `/app/bin/server` で起動し、
マイグレーションは `/app/bin/migrate`。DB は**必ず** `docker/postgres` の pg_bigm 入りイメージを使う
(migrations が `CREATE EXTENSION postgis / pg_bigm / ltree` を実行するため、素の postgres では失敗する)。

イメージは GitHub Actions(`.github/workflows/build-image.yml`)が **GHCR** に push する:
- `ghcr.io/torifo/dialect-pocket-webapp`(アプリ release)
- `ghcr.io/torifo/dialect-pocket-db`(pg_bigm 入り PostgreSQL)

### 環境変数(config/runtime.exs)
| 変数 | 必須 | 内容 |
|---|---|---|
| `DATABASE_URL` | ✅ | `ecto://USER:PASS@HOST/DATABASE` |
| `SECRET_KEY_BASE` | ✅ | `mix phx.gen.secret` で生成 |
| `PHX_HOST` | ✅ | 公開ホスト名(URL 生成に使用) |
| `PORT` | — | 待受ポート(既定 4000) |
| `POOL_SIZE` | — | DB プールサイズ(既定 10) |

### VPS(`docker-compose.prod.yml`)
**VPS 上ではビルドしない**(メモリ不足)。GHCR の push 済みイメージを pull して使う。
共有リバースプロキシ(nginxproxy/nginx-proxy + acme-companion、外部ネットワーク
`global-proxy-network`)が `VIRTUAL_HOST` で自動ルーティング・自動TLSするため、個別 NGINX は不要。

```bash
# 設置先: /home/ubuntu/Web/dialect-pocket(リポを clone、または compose と .env のみ配置)
# .env: APP_HOST=dialect-pocket.example.com / POSTGRES_PASSWORD=... / SECRET_KEY_BASE=... / IMAGE_TAG=latest
docker compose -f docker-compose.prod.yml --env-file .env pull
docker compose -f docker-compose.prod.yml --env-file .env up -d
```
app は起動時に `migrate -> server` を自動実行する。デプロイ更新は push(CI が GHCR 更新)→ VPS で `pull && up -d`。

初期シード(31地域/約372エントリ、出典付き・冪等)を投入する場合:
```bash
docker exec dialect_pocket_app_prod /app/bin/dialect_pocket eval "DialectPocket.Release.seed()"
```

### オンプレ(`docker-compose.onprem.yml`・仮)
共有proxyが無い前提の暫定構成。**例外として接続先でのビルドを許可**し、同梱 NGINX(`deploy/nginx.conf`)を前段に置く。
```bash
docker compose -f docker-compose.onprem.yml --env-file .env up -d --build
```
TLS は暫定で未設定(HTTP)。実環境に合わせて `deploy/nginx.conf` と 443/証明書を調整する。

### バックアップ
`deploy/backup.sh` が DB コンテナから `pg_dump` を取り、gzip でタイムスタンプ付き保存・世代管理する(cron 想定)。復元手順はスクリプト末尾コメント参照。

## データ / provenance / ライセンス方針
- **provenance を一級市民**として保持し、「それっぽい嘘」を構造的に避ける。変換は DB ルックアップ限定で推測生成しない。
- 現行シードの背骨は **Wikipedia 各方言記事(CC BY-SA 4.0)**。出典リンク(`source.url`)を必ず保持し、本文の丸ごと転載はしない(語・意味・例の事実 + 出典リンクのみ)。
- 未確認情報は `reliability: unverified`(真偽未確認)として UI で「出典:○○(真偽未確認)」相当のバッジを付け、確定情報と区別する。
- **NINJAL(GAJ/LAJ/COJADS 等)は再配布制限**のため、再公開せず**出典・検証参照に限定**する。詳細は `docs/research/open-data-sources.md`。
- 規約が明確でないコミュニティ由来(SNS/まとめ)は `kind: community` + 出典ポインタで扱う(複製でなく「ポインタ + 事実」)。

## プロジェクト構成
- `lib/dialect_pocket/` … ドメインコンテキスト
  - `accounts` … 管理者アカウント / 認証
  - `dictionary` … エントリ・provenance・検索
  - `regions` … 地域階層(ltree / PostGIS)
  - `contributions` … ユーザー投稿・モデレーション
  - `conversion` … 変換(DB ルックアップ)
- `lib/dialect_pocket_web/` … LiveView / controllers / router / admin_auth
- `priv/seed_data/` … 初期シード(`regions_seed.json`, `dialect/*.json`)
- `priv/repo/seeds.exs` … シード投入
- `docker/postgres/` … PostGIS + pg_bigm の DB イメージ
- `deploy/` … nginx.conf / backup.sh
- `.kiro/specs/dialect-pocket-mvp/` … 要件・設計(requirements.md / design.md)
- `docs/research/` … データ調達・ライセンス調査

## ライセンス
**コードのライセンス**と**方言データのライセンスは別物**である。

- コード: リポジトリのライセンス表記に従う。
- 方言データ: シードは Wikipedia 由来(**CC BY-SA 4.0**・継承/出典表示が必要)。出典・ライセンスはエントリごとの provenance に保持される。NINJAL 等の参照専用ソースは再配布対象に含めない。
