defmodule DialectPouch.FeedbackTest do
  use DialectPouch.DataCase, async: true

  alias DialectPouch.Feedback.Remark

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
end
