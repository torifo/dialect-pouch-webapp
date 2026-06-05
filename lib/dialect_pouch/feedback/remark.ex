defmodule DialectPouch.Feedback.Remark do
  @moduledoc """
  A user's remark ("物申す") on an existing entry — a correction or note such as
  「意味が違う」「今はこう言う」. Identity is the safeguard: a remark must carry a
  nickname (`author_kind: :nickname`) unless backed by an account
  (`author_kind: :google`, future). Remarks are published immediately
  (`status: :visible`); detection of spam/abuse is a separate, after-the-fact
  role (see `report_count` / `:hidden`).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @kinds [:meaning, :reading, :region, :obsolete, :other]
  @author_kinds [:nickname, :google]
  @statuses [:visible, :hidden]

  schema "entry_remarks" do
    field :kind, Ecto.Enum, values: @kinds
    field :body, :string
    field :author_nickname, :string
    field :author_kind, Ecto.Enum, values: @author_kinds, default: :nickname
    field :status, Ecto.Enum, values: @statuses, default: :visible
    field :report_count, :integer, default: 0
    belongs_to :entry, DialectPouch.Dictionary.Entry
    timestamps(type: :utc_datetime)
  end

  def kinds, do: @kinds

  @doc false
  def changeset(remark, attrs) do
    remark
    |> cast(attrs, [
      :entry_id,
      :kind,
      :body,
      :author_nickname,
      :author_kind,
      :status,
      :report_count
    ])
    |> validate_required([:entry_id, :kind, :body, :author_kind, :status])
    |> validate_nickname_present()
    |> assoc_constraint(:entry)
  end

  # 匿名禁止: ニックネーム素性なら author_nickname 必須。
  defp validate_nickname_present(changeset) do
    case get_field(changeset, :author_kind) do
      :nickname -> validate_required(changeset, [:author_nickname])
      _ -> changeset
    end
  end
end
