defmodule DialectPouch.Feedback do
  @moduledoc """
  User remarks ("物申す") on existing entries.

  A remark publishes immediately (`status: :visible`); identity (nickname or a
  future account) is the safeguard, not pre-moderation. Spam/abuse detection is
  a separate, after-the-fact role: `report_remark/1` only bumps a counter and
  `hide_remark/1` takes a remark out of public view.
  """
  import Ecto.Query
  alias DialectPouch.Repo
  alias DialectPouch.Feedback.Remark
  alias DialectPouch.RateLimiter

  @max_per_window 5
  @window_ms 60_000

  @doc """
  Create a remark (saved immediately as `:visible`). `rate_key` identifies the
  client (e.g. IP) for throttling.

  Returns `{:ok, remark}` | `{:error, :rate_limited}` | `{:error, changeset}`.
  """
  def create_remark(attrs, rate_key) do
    case RateLimiter.hit("remark:" <> to_string(rate_key), @window_ms, @max_per_window) do
      {:deny, _retry_ms} ->
        {:error, :rate_limited}

      {:allow, _count} ->
        %Remark{}
        |> Remark.changeset(attrs)
        |> Repo.insert()
    end
  end

  @doc "Visible remarks for an entry, newest first."
  def list_remarks(entry_id) do
    Repo.all(
      from r in Remark,
        where: r.entry_id == ^entry_id and r.status == :visible,
        order_by: [desc: r.inserted_at, desc: r.id]
    )
  end

  @doc """
  Bump the report counter (detection受け皿). `id` may be client-supplied, so a
  missing remark is reported as `{:error, :not_found}` rather than raising.
  Returns `{:ok, remark}` | `{:error, :not_found}`.
  """
  def report_remark(id) do
    case Repo.get(Remark, id) do
      nil ->
        {:error, :not_found}

      remark ->
        remark
        |> Ecto.Changeset.change(report_count: remark.report_count + 1)
        |> Repo.update()
    end
  end

  @doc "Remarks that have been reported at least once (for curators)."
  def list_reported do
    Repo.all(
      from r in Remark,
        where: r.report_count > 0,
        order_by: [desc: r.report_count, desc: r.inserted_at],
        preload: [:entry]
    )
  end

  @doc "Hide a remark from public view."
  def hide_remark(id), do: set_status(id, :hidden)

  @doc "Restore a hidden remark."
  def unhide_remark(id), do: set_status(id, :visible)

  defp set_status(id, status) do
    Repo.get!(Remark, id)
    |> Ecto.Changeset.change(status: status)
    |> Repo.update()
  end
end
