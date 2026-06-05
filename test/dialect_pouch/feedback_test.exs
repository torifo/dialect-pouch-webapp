defmodule DialectPouch.FeedbackTest do
  use DialectPouch.DataCase, async: true

  alias DialectPouch.Feedback.Remark
  alias DialectPouch.{Feedback, Regions, Dictionary}

  describe "Remark.changeset/2" do
    test "valid with nickname author requires a nickname" do
      cs =
        Remark.changeset(%Remark{}, %{
          entry_id: 1,
          kind: :meaning,
          body: "意味が違う気がします",
          author_kind: :nickname,
          author_nickname: "どさんこ"
        })

      assert cs.valid?
    end

    test "nickname author without nickname is invalid (匿名禁止)" do
      cs =
        Remark.changeset(%Remark{}, %{
          entry_id: 1,
          kind: :meaning,
          body: "意味が違う",
          author_kind: :nickname,
          author_nickname: ""
        })

      refute cs.valid?
      assert %{author_nickname: _} = errors_on(cs)
    end

    test "google author may omit nickname" do
      cs =
        Remark.changeset(%Remark{}, %{
          entry_id: 1,
          kind: :other,
          body: "補足です",
          author_kind: :google
        })

      assert cs.valid?
    end

    test "body and kind are required" do
      cs = Remark.changeset(%Remark{}, %{entry_id: 1, author_kind: :google})
      refute cs.valid?
      assert %{body: _, kind: _} = errors_on(cs)
    end
  end

  describe "Feedback context" do
    setup do
      {:ok, jp} = Regions.create_region(%{name: "日本", level: :country, path: "jp"})

      {:ok, entry} =
        Dictionary.create_entry(
          %{
            headword: "なまら",
            slug: "なまら",
            status: :published,
            senses: [%{gloss: "とても", standard_lemma: "とても"}],
            provenance: %{kind: :manual, reliability: :verified}
          },
          [jp.id]
        )

      %{entry: entry}
    end

    test "create_remark saves immediately as :visible", %{entry: entry} do
      assert {:ok, remark} = Feedback.create_remark(remark_attrs(entry), "rk-ok")
      assert remark.status == :visible
      assert remark.author_nickname == "どさんこ"
    end

    test "create_remark rejects a nickname author with no nickname", %{entry: entry} do
      attrs = remark_attrs(entry, %{"author_nickname" => ""})
      assert {:error, changeset} = Feedback.create_remark(attrs, "rk-anon")
      assert %{author_nickname: _} = errors_on(changeset)
    end

    test "create_remark is rate limited after the window max", %{entry: entry} do
      for _ <- 1..5, do: Feedback.create_remark(remark_attrs(entry), "rk-rl")
      assert {:error, :rate_limited} = Feedback.create_remark(remark_attrs(entry), "rk-rl")
    end

    test "list_remarks returns visible newest-first and excludes hidden", %{entry: entry} do
      {:ok, a} = Feedback.create_remark(remark_attrs(entry, %{"body" => "古い"}), "rk-a")
      {:ok, b} = Feedback.create_remark(remark_attrs(entry, %{"body" => "新しい"}), "rk-b")

      # Both visible; newest (b) should come first
      bodies_before = Feedback.list_remarks(entry.id) |> Enum.map(& &1.body)
      assert bodies_before == ["新しい", "古い"]

      # Hide the newest remark (b)
      {:ok, _} = Feedback.hide_remark(b.id)

      # Only the older remark (a) should remain visible
      remaining = Feedback.list_remarks(entry.id)
      assert length(remaining) == 1
      assert hd(remaining).id == a.id
      assert hd(remaining).body == "古い"
    end

    test "report_remark increments report_count", %{entry: entry} do
      {:ok, r} = Feedback.create_remark(remark_attrs(entry), "rk-rep")
      {:ok, r2} = Feedback.report_remark(r.id)
      assert r2.report_count == 1
    end
  end

  # module-level helper (must be OUTSIDE describe blocks)
  defp remark_attrs(entry, over \\ %{}) do
    Map.merge(
      %{
        "entry_id" => entry.id,
        "kind" => "meaning",
        "body" => "今はこう言いません",
        "author_kind" => "nickname",
        "author_nickname" => "どさんこ"
      },
      over
    )
  end
end
