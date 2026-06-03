-- Enable extensions in the default dev database on first container init.
-- (Ecto migrations also CREATE EXTENSION IF NOT EXISTS for dev/test DBs — Task 1.1.)
CREATE EXTENSION IF NOT EXISTS ltree;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_bigm;
