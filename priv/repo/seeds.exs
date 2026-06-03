# Seeds dialect-pocket from priv/seed_data/.
#
#     mix run priv/repo/seeds.exs
#
# Loads the region tree (regions_seed.json) then the cited default dialect
# entries (dialect/*.json). Idempotent at a coarse level: regions are skipped if
# their path already exists; dialect loading is skipped entirely once any entry
# exists, so re-running does not duplicate the seed.

require Logger

alias DialectPocket.{Dictionary, Regions, Repo}
alias DialectPocket.Dictionary.Entry

seed_dir = Path.join(:code.priv_dir(:dialect_pocket), "seed_data")

read_json = fn path -> path |> File.read!() |> Jason.decode!() end

# --- Regions (parents first, idempotent by path) ---
region_file = Path.join(seed_dir, "regions_seed.json")
regions = read_json.(region_file)["regions"]

regions
|> Enum.sort_by(fn r -> r["path"] |> String.split(".") |> length() end)
|> Enum.each(fn r ->
  case Regions.get_region_by_path(r["path"]) do
    nil ->
      parent = r["parent_path"] && Regions.get_region_by_path(r["parent_path"])

      {:ok, _} =
        Regions.create_region(%{
          name: r["name"],
          level: String.to_existing_atom(r["level"]),
          path: r["path"],
          parent_id: parent && parent.id
        })

    _ ->
      :ok
  end
end)

Logger.info("Regions seeded: #{length(regions)} declared")

# --- Dialect entries (skip if already populated) ---
if Repo.aggregate(Entry, :count) > 0 do
  Logger.info("Entries already present — skipping dialect seed.")
else
  # Primary standard term for conversion lookups: first alternative of the meaning.
  primary_lemma = fn meaning ->
    meaning
    |> String.split(~r/[・、（(\s]/u, parts: 2)
    |> hd()
    |> String.trim()
    |> String.trim_leading("〜")
  end

  total =
    seed_dir
    |> Path.join("dialect")
    |> Path.join("*.json")
    |> Path.wildcard()
    |> Enum.reduce(0, fn file, acc ->
      data = read_json.(file)
      region = Regions.get_region_by_path(data["region_path"])

      unless region do
        Logger.warning("No region for #{data["region_path"]} (#{file}) — skipping file.")
      end

      src = data["source"] || %{}
      label = data["region_path"] |> String.split(".") |> List.last()

      count =
        if region do
          Enum.reduce(data["entries"], 0, fn e, n ->
            attrs = %{
              headword: e["headword"],
              reading: e["reading"],
              status: :published,
              slug: "#{e["headword"]}-#{label}",
              senses: [
                %{gloss: e["meaning"], standard_lemma: primary_lemma.(e["meaning"] || "")}
              ],
              examples:
                case e["example"] do
                  ex when is_binary(ex) and ex != "" -> [%{text: ex}]
                  _ -> []
                end,
              provenance: %{
                kind: :community,
                reliability: :unverified,
                source_platform: src["platform"],
                source_url: src["url"],
                source_license: src["license"],
                observed_at: src["observed_at"]
              }
            }

            case Dictionary.create_entry(attrs, [region.id]) do
              {:ok, _} ->
                n + 1

              {:error, reason} ->
                Logger.warning(
                  "Failed entry #{e["headword"]} (#{data["region_path"]}): #{inspect(reason)}"
                )

                n
            end
          end)
        else
          0
        end

      acc + count
    end)

  Logger.info("Dialect entries seeded: #{total}")
end
