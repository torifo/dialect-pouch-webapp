# PostgreSQL 16 + PostGIS (base image) + pg_bigm (built from source) + ltree (contrib, bundled)
# ltree / postgis are available in the base image; pg_bigm is compiled here.
FROM postgis/postgis:16-3.4

ARG PG_BIGM_VERSION=1.2-20240606

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        postgresql-server-dev-16; \
    cd /tmp; \
    # Newer pg_bigm releases ship only RPMs; use the GitHub source archive for the tag.
    # GitHub strips the leading "v" from the extracted top-level directory.
    curl -fsSL -o pg_bigm.tar.gz \
        "https://github.com/pgbigm/pg_bigm/archive/refs/tags/v${PG_BIGM_VERSION}.tar.gz"; \
    tar zxf pg_bigm.tar.gz; \
    cd "pg_bigm-${PG_BIGM_VERSION}"; \
    # with_llvm=no: skip LLVM bitcode (.bc) generation — the postgis base image enables
    # JIT, so PGXS would otherwise require clang. The extension works without bitcode.
    make USE_PGXS=1 with_llvm=no; \
    make USE_PGXS=1 with_llvm=no install; \
    cd /; rm -rf /tmp/pg_bigm*; \
    apt-get purge -y --auto-remove build-essential postgresql-server-dev-16 curl; \
    rm -rf /var/lib/apt/lists/*

# Make pg_bigm loadable (it is a normal extension; no shared_preload needed for index ops,
# but enabling here keeps full_text scans cheap by default).
# Extensions themselves are CREATEd per-database by Ecto migrations (Task 1.1).
