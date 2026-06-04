defmodule DialectPocket.Contributions do
  @moduledoc """
  User contributions.

  A submission is saved as a `:draft` (unmoderated) `Entry` with provenance
  `kind: :user` (nickname attribution) and becomes public only after a curator
  approves it (see moderation, Task 5.1). Submissions are rate-limited per client.
  """
  alias DialectPocket.{Dictionary, Regions, RateLimiter}

  @max_per_window 5
  @window_ms 60_000

  @doc """
  Create a user submission (saved unpublished). `rate_key` identifies the client
  (e.g. IP) for throttling.

  Returns `{:ok, entry}` | `{:error, :rate_limited}` |
  `{:error, :invalid, missing_fields}` | `{:error, changeset}`.
  """
  def create_submission(attrs, rate_key) do
    case RateLimiter.hit("contribute:" <> to_string(rate_key), @window_ms, @max_per_window) do
      {:deny, _retry_ms} -> {:error, :rate_limited}
      {:allow, _count} -> do_create(attrs)
    end
  end

  defp do_create(attrs) do
    headword = field(attrs, :headword)
    meaning = field(attrs, :meaning)
    region_path = field(attrs, :region_path)
    reading = field(attrs, :reading)
    example = field(attrs, :example)
    nickname = field(attrs, :nickname)

    missing =
      [headword: headword, meaning: meaning, region_path: region_path]
      |> Enum.filter(fn {_k, v} -> blank?(v) end)
      |> Enum.map(&elem(&1, 0))

    region = if blank?(region_path), do: nil, else: Regions.get_region_by_path(region_path)

    cond do
      missing != [] ->
        {:error, :invalid, missing}

      is_nil(region) ->
        {:error, :invalid, [:region_path]}

      true ->
        %{
          headword: headword,
          reading: reading,
          status: :draft,
          slug: headword,
          senses: [%{gloss: meaning, standard_lemma: meaning}],
          examples: if(blank?(example), do: [], else: [%{text: example}]),
          provenance: %{
            kind: :user,
            reliability: :community,
            observed_author: if(blank?(nickname), do: nil, else: nickname),
            source_platform: "user"
          }
        }
        |> Dictionary.create_entry([region.id])
    end
  end

  defp field(attrs, key) do
    (Map.get(attrs, key) || Map.get(attrs, to_string(key)))
    |> clean()
  end

  defp clean(s) when is_binary(s), do: String.trim(s)
  defp clean(other), do: other

  defp blank?(v), do: v in [nil, ""]
end
