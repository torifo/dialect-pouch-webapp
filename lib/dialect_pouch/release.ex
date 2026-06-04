defmodule DialectPouch.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :dialect_pouch

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Seed the database from priv/repo/seeds.exs (regions + cited default dialect
  entries). Idempotent: the script skips if entries already exist.

  Run in production:
      bin/dialect_pouch eval "DialectPouch.Release.seed()"
  """
  def seed do
    load_app()
    seeds = Path.join([:code.priv_dir(@app), "repo", "seeds.exs"])

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn _repo -> Code.eval_file(seeds) end)
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
