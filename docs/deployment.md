# dialect-pouch デプロイ手順

本番（VPS / オンプレ）デプロイとバックアップ運用の手順をまとめる。
アプリ本体の概要・開発セットアップは [../README.md](../README.md) を参照。

## 本番デプロイ

アプリは `mix release`(生成済み `Dockerfile`)。最終イメージは `/app/bin/server` で起動し、
マイグレーションは `/app/bin/migrate`。DB は**必ず** `docker/postgres` の pg_bigm 入りイメージを使う
(migrations が `CREATE EXTENSION postgis / pg_bigm / ltree` を実行するため、素の postgres では失敗する)。

イメージは GitHub Actions(`.github/workflows/build-image.yml`)が **GHCR** に push する:
- `ghcr.io/torifo/dialect-pouch-webapp`(アプリ release)
- `ghcr.io/torifo/dialect-pouch-db`(pg_bigm 入り PostgreSQL)

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
# 設置先: /home/ubuntu/Web/dialect-pouch(リポを clone、または compose と .env のみ配置)
# .env: APP_HOST=dialect-pouch.example.com / POSTGRES_PASSWORD=... / SECRET_KEY_BASE=... / IMAGE_TAG=latest
docker compose -f docker-compose.prod.yml --env-file .env pull
docker compose -f docker-compose.prod.yml --env-file .env up -d
```
app は起動時に `migrate -> server` を自動実行する。デプロイ更新は push(CI が GHCR 更新)→ VPS で `pull && up -d`。

初期シード(31地域/約372エントリ、出典付き・冪等)を投入する場合:
```bash
docker exec dialect_pouch_app_prod /app/bin/dialect_pouch eval "DialectPouch.Release.seed()"
```

### オンプレ(`docker-compose.onprem.yml`・仮)
共有proxyが無い前提の暫定構成。**例外として接続先でのビルドを許可**し、同梱 NGINX(`deploy/nginx.conf`)を前段に置く。
```bash
docker compose -f docker-compose.onprem.yml --env-file .env up -d --build
```
TLS は暫定で未設定(HTTP)。実環境に合わせて `deploy/nginx.conf` と 443/証明書を調整する。

### バックアップ
`deploy/backup.sh` が DB コンテナから `pg_dump` を取り、gzip でタイムスタンプ付き保存・世代管理する(cron 想定)。復元手順はスクリプト末尾コメント参照。
