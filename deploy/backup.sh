#!/usr/bin/env bash
# dialect-pocket DB バックアップスクリプト
#
# 本番 PostgreSQL コンテナから pg_dump を取り、gzip 圧縮してタイムスタンプ付きで保存する。
# cron 等から定期実行する想定(単一ノード運用前提の定期バックアップ)。
#
# 例: 毎日 03:30 に実行する crontab エントリ
#   30 3 * * * /path/to/dialect-pocket/deploy/backup.sh >> /var/log/dialect-pocket-backup.log 2>&1
#
# 環境変数で上書き可能:
#   DB_CONTAINER  バックアップ対象の DB コンテナ名(既定: dialect_pocket_db_prod)
#   DB_USER       接続ユーザー(既定: postgres)
#   DB_NAME       データベース名(既定: dialect_pocket_prod)
#   BACKUP_DIR    保存先ディレクトリ(既定: ./backups)
#   RETENTION     保持世代数(既定: 14。これより古いものは削除)

set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-dialect_pocket_db_prod}"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-dialect_pocket_prod}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION="${RETENTION:-14}"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
OUTFILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"

mkdir -p "${BACKUP_DIR}"

echo "==> dumping ${DB_NAME} from container ${DB_CONTAINER} -> ${OUTFILE}"
# pg_dump をコンテナ内で実行し、ホスト側で gzip 圧縮して保存する。
docker exec "${DB_CONTAINER}" pg_dump -U "${DB_USER}" "${DB_NAME}" | gzip > "${OUTFILE}"

echo "==> backup complete: $(du -h "${OUTFILE}" | cut -f1)"

# --- 世代管理: 古いバックアップを削除(新しい RETENTION 件だけ残す) ---
echo "==> pruning old backups (keeping latest ${RETENTION})"
ls -1t "${BACKUP_DIR}/${DB_NAME}_"*.sql.gz 2>/dev/null \
  | tail -n +"$((RETENTION + 1))" \
  | while read -r old; do
      echo "    removing ${old}"
      rm -f "${old}"
    done

echo "==> done"

# --- 復元手順(参考) ---
# 1. 復元先 DB が空であること(必要なら drop/create):
#      docker exec -i dialect_pocket_db_prod \
#        psql -U postgres -c "DROP DATABASE IF EXISTS dialect_pocket_prod;"
#      docker exec -i dialect_pocket_db_prod \
#        psql -U postgres -c "CREATE DATABASE dialect_pocket_prod;"
# 2. gzip を展開しながら psql に流し込む:
#      gunzip -c backups/dialect_pocket_prod_YYYYMMDD_HHMMSS.sql.gz \
#        | docker exec -i dialect_pocket_db_prod psql -U postgres dialect_pocket_prod
#    ※ 拡張(postgis/pg_bigm/ltree)はダンプ内に CREATE EXTENSION が含まれるが、
#      DB イメージは docker/postgres の pg_bigm 入りを使うこと。
