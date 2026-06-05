# 既存エントリへの「物申す」(指摘) ＋ 投稿即時公開化 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **コミット規約（厳守）:** Conventional Commits。本文は EN+JA 併記可。**Claude/Anthropic 由来の署名・帰属行（Co-Authored-By 等）は一切付けない。**

**Goal:** 既存エントリにニックネーム付きで「種別タグ＋コメント」の指摘を即時公開で残せるようにし、あわせて投稿フローを「素性あり→即公開 / 匿名→draft」に変える。

**Architecture:** 指摘は独立スキーマ `entry_remarks`（`DialectPouch.Feedback.Remark`）として保持し、`DialectPouch.Feedback` コンテキスト経由で即 `:visible` 保存。エントリ詳細 LiveView にフォームと一覧を追加。検知(C)は通報カウント＋モデレーション画面の非表示化のみ（受け皿）。Google ログインは `author_kind: :google` という enum 値の seam だけ用意し未実装。

**Tech Stack:** Elixir / Phoenix LiveView / Ecto / PostgreSQL / 既存 `DialectPouch.RateLimiter`(Hammer)

---

## File Structure

- **Create** `priv/repo/migrations/20260605xxxxxx_create_entry_remarks.exs` — `entry_remarks` テーブル
- **Create** `lib/dialect_pouch/feedback/remark.ex` — Remark スキーマ＋changeset
- **Create** `lib/dialect_pouch/feedback.ex` — Feedback コンテキスト（create/list/report/hide）
- **Modify** `lib/dialect_pouch/dictionary/entry.ex` — `has_many :remarks`
- **Modify** `lib/dialect_pouch/contributions.ex` — 素性ありで `:published`
- **Modify** `lib/dialect_pouch_web/live/entry_live.ex` — 指摘フォーム＋一覧＋イベント
- **Modify** `lib/dialect_pouch_web/live/admin_live/moderation.ex` — 通報指摘セクション
- **Create** `test/dialect_pouch/feedback_test.exs` — Feedback コンテキストのテスト
- **Modify** `test/dialect_pouch/contributions_test.exs` — B変更にあわせ期待値更新
- **Modify** `test/dialect_pouch_web/live/entry_live_test.exs` — 指摘フォーム送信/通報
- **Modify** `test/dialect_pouch_web/live/admin_live/moderation_test.exs` — 通報指摘の非表示化

実行前に `docker compose up -d db` と `mix ecto.migrate`（Task 1 後）が必要。

---

## Task 1: マイグレーション — entry_remarks テーブル

**Files:**
- Create: `priv/repo/migrations/20260605000001_create_entry_remarks.exs`

- [ ] **Step 1: マイグレーションファイルを作成**

`priv/repo/migrations/20260605000001_create_entry_remarks.exs`:

```elixir
defmodule DialectPouch.Repo.Migrations.CreateEntryRemarks do
  use Ecto.Migration

  def change do
    create table(:entry_remarks) do
      add :entry_id, references(:entries, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :body, :text, null: false
      add :author_nickname, :string
      add :author_kind, :string, null: false, default: "nickname"
      add :status, :string, null: false, default: "visible"
      add :report_count, :integer, null: false, default: 0
      timestamps(type: :utc_datetime)
    end

    create index(:entry_remarks, [:entry_id])
    create index(:entry_remarks, [:status])
  end
end
```

- [ ] **Step 2: マイグレーション実行で成功を確認**

Run: `mix ecto.migrate`
Expected: `create table entry_remarks` と index 作成が成功（エラーなし）。

- [ ] **Step 3: Commit**

```bash
git add priv/repo/migrations/20260605000001_create_entry_remarks.exs
git commit -m "feat(db): add entry_remarks table for user remarks on entries"
```

---

## Task 2: Remark スキーマ＋changeset

**Files:**
- Create: `lib/dialect_pouch/feedback/remark.ex`
- Test: `test/dialect_pouch/feedback_test.exs`（このタスクで一部作成）

- [ ] **Step 1: 失敗するテストを書く**

`test/dialect_pouch/feedback_test.exs`（新規・スキーマ changeset 部分のみ）:

```elixir
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
```

- [ ] **Step 2: テストを実行して失敗を確認**

Run: `mix test test/dialect_pouch/feedback_test.exs`
Expected: FAIL（`DialectPouch.Feedback.Remark` 未定義）。

- [ ] **Step 3: スキーマを実装**

`lib/dialect_pouch/feedback/remark.ex`:

```elixir
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
```

- [ ] **Step 4: テストを実行して成功を確認**

Run: `mix test test/dialect_pouch/feedback_test.exs`
Expected: PASS（4 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/dialect_pouch/feedback/remark.ex test/dialect_pouch/feedback_test.exs
git commit -m "feat(feedback): add Remark schema with anti-anonymous validation"
```

---

## Task 3: Feedback コンテキスト（create/list/report/hide）

**Files:**
- Create: `lib/dialect_pouch/feedback.ex`
- Test: `test/dialect_pouch/feedback_test.exs`（コンテキスト用テストを追記）

- [ ] **Step 1: 失敗するテストを追記**

`test/dialect_pouch/feedback_test.exs` の `alias` 行の下に `alias DialectPouch.{Feedback, Regions}` と `alias DialectPouch.Dictionary` を足し、ファイル末尾（最後の `end` の直前）に以下の describe を追加:

```elixir
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
      {:ok, _} = Feedback.hide_remark(a.id)

      ids = Feedback.list_remarks(entry.id) |> Enum.map(& &1.id)
      assert ids == [b.id]
    end

    test "report_remark increments report_count", %{entry: entry} do
      {:ok, r} = Feedback.create_remark(remark_attrs(entry), "rk-rep")
      {:ok, r2} = Feedback.report_remark(r.id)
      assert r2.report_count == 1
    end
  end
```

- [ ] **Step 2: テストを実行して失敗を確認**

Run: `mix test test/dialect_pouch/feedback_test.exs`
Expected: FAIL（`DialectPouch.Feedback` 未定義）。

- [ ] **Step 3: コンテキストを実装**

`lib/dialect_pouch/feedback.ex`:

```elixir
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

  @doc "Bump the report counter (detection受け皿). Returns `{:ok, remark}`."
  def report_remark(id) do
    remark = Repo.get!(Remark, id)

    remark
    |> Ecto.Changeset.change(report_count: remark.report_count + 1)
    |> Repo.update()
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
```

- [ ] **Step 4: テストを実行して成功を確認**

Run: `mix test test/dialect_pouch/feedback_test.exs`
Expected: PASS（全 9 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/dialect_pouch/feedback.ex test/dialect_pouch/feedback_test.exs
git commit -m "feat(feedback): add Feedback context (create/list/report/hide)"
```

---

## Task 4: Entry スキーマに has_many :remarks

**Files:**
- Modify: `lib/dialect_pouch/dictionary/entry.ex`

- [ ] **Step 1: 関連を追加**

`lib/dialect_pouch/dictionary/entry.ex` の `alias` 行を更新し、`has_one :provenance, Provenance` の下に `has_many :remarks` を追加。

alias 行を:

```elixir
  alias DialectPouch.Dictionary.{Sense, Example, Provenance, EntryRegion}
```

から（変更後）:

```elixir
  alias DialectPouch.Dictionary.{Sense, Example, Provenance, EntryRegion}
  alias DialectPouch.Feedback.Remark
```

`has_one :provenance, Provenance` の直後に追加:

```elixir
    has_many :remarks, Remark
```

- [ ] **Step 2: コンパイルとテストで回帰がないか確認**

Run: `mix test test/dialect_pouch/dictionary_test.exs`
Expected: PASS（既存テストが引き続き通る）。

- [ ] **Step 3: Commit**

```bash
git add lib/dialect_pouch/dictionary/entry.ex
git commit -m "feat(dictionary): associate entries with remarks"
```

---

## Task 5: 投稿フローB — 素性ありで即公開

**Files:**
- Modify: `lib/dialect_pouch/contributions.ex:55`（`status: :draft` 周辺）
- Modify: `test/dialect_pouch/contributions_test.exs`

- [ ] **Step 1: 既存テストを新仕様へ更新（失敗させる）**

`test/dialect_pouch/contributions_test.exs` の `"saves a valid submission as an unpublished :user entry"` テストを置き換え、匿名/素性ありの2ケースにする。既存の該当 `test ... do ... end` ブロックを以下2つに差し替え:

```elixir
  test "publishes immediately when a nickname (素性) is present" do
    assert {:ok, %Entry{} = entry} = Contributions.create_submission(valid(), "k-ok")
    assert entry.status == :published

    loaded = DialectPouch.Dictionary.get_by_slug_admin(entry.slug)
    assert loaded.provenance.kind == :user
    assert loaded.provenance.observed_author == "どさんこ"
    assert [%{region: %{path: "jp.hokkaido"}}] = loaded.entry_regions
    # public right away
    assert DialectPouch.Dictionary.get_published_by_slug(entry.slug)
  end

  test "saves as :draft when anonymous (no nickname)" do
    attrs = valid(%{"nickname" => ""})
    assert {:ok, %Entry{} = entry} = Contributions.create_submission(attrs, "k-anon")
    assert entry.status == :draft
    assert DialectPouch.Dictionary.get_published_by_slug(entry.slug) == nil
  end
```

- [ ] **Step 2: テストを実行して失敗を確認**

Run: `mix test test/dialect_pouch/contributions_test.exs`
Expected: FAIL（現状は常に `:draft` なので「publishes immediately」が落ちる）。

- [ ] **Step 3: `do_create` を分岐させる**

`lib/dialect_pouch/contributions.ex` の `true ->` 節内、`status: :draft,` の行を素性で分岐させる。`true ->` ブロックの map 構築を以下に変更（`status:` の値を変数 `status` にする）。

`do_create/1` の `cond do` の `true ->` 節を次に置き換え:

```elixir
      true ->
        status = if blank?(nickname), do: :draft, else: :published

        %{
          headword: headword,
          reading: reading,
          status: status,
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
```

- [ ] **Step 4: テストを実行して成功を確認**

Run: `mix test test/dialect_pouch/contributions_test.exs`
Expected: PASS（全ケース）。

- [ ] **Step 5: contribute_live の文言を実態へ更新**

`lib/dialect_pouch_web/live/contribute_live.ex` の成功・案内文を、素性ありで即時公開される旨に更新。

PC側 `@status == :ok` の note 内テキストを:

```
<.icon name="hero-check-circle" /> 投稿ありがとうございます。承認後に公開されます。
```

から:

```
<.icon name="hero-check-circle" /> 投稿ありがとうございます。ニックネーム付きの投稿はそのまま公開されます。
```

同様にモバイル側 `m-note m-note--ok` の同テキストも同じ文言に更新。

ページ冒頭の help（PC `投稿は確認のうえ公開されます（公開まで未承認の状態で保存されます）。`）を:

```
ニックネームを入れた投稿はそのまま公開されます。匿名の場合は確認のうえ公開されます。
```

に更新（モバイル側 help も同主旨に）。

- [ ] **Step 6: LiveView テストが通るか確認**

Run: `mix test test/dialect_pouch_web/live/contribute_live_test.exs`
Expected: PASS。文言アサーションが落ちる場合は、テスト側の期待文字列を Step 5 の新文言へ更新してから再実行。

- [ ] **Step 7: Commit**

```bash
git add lib/dialect_pouch/contributions.ex lib/dialect_pouch_web/live/contribute_live.ex test/dialect_pouch/contributions_test.exs test/dialect_pouch_web/live/contribute_live_test.exs
git commit -m "feat(contribute): publish submissions immediately when nickname present"
```

---

## Task 6: EntryLive — 指摘フォーム＋一覧＋イベント

**Files:**
- Modify: `lib/dialect_pouch_web/live/entry_live.ex`
- Test: `test/dialect_pouch_web/live/entry_live_test.exs`

このタスクは大きいのでステップを細かく分ける。まず mount でデータを用意し、次に PC レイアウト、最後にモバイルとイベント。

- [ ] **Step 1: 失敗するテストを書く**

`test/dialect_pouch_web/live/entry_live_test.exs` に以下のテストを追加（既存の `setup`/公開エントリ生成ヘルパに合わせる。エントリ生成方法が異なる場合は既存テストの公開エントリ生成手順を流用）。`alias DialectPouch.Feedback` を冒頭に追加し、`import Phoenix.LiveViewTest` が既にある前提:

```elixir
  test "submitting a remark shows it immediately", %{conn: conn} do
    entry = published_entry_fixture()

    {:ok, lv, _html} = live(conn, ~p"/e/#{entry.slug}")

    lv
    |> form("#remark-form", %{
      "kind" => "obsolete",
      "body" => "今はあまり使いません",
      "nickname" => "どさんこ"
    })
    |> render_submit()

    assert render(lv) =~ "今はあまり使いません"
    assert render(lv) =~ "どさんこ"
    assert [%{body: "今はあまり使いません"}] = Feedback.list_remarks(entry.id)
  end

  test "submitting a remark without a nickname shows an error", %{conn: conn} do
    entry = published_entry_fixture()
    {:ok, lv, _html} = live(conn, ~p"/e/#{entry.slug}")

    html =
      lv
      |> form("#remark-form", %{"kind" => "meaning", "body" => "違う", "nickname" => ""})
      |> render_submit()

    assert html =~ "ニックネーム"
    assert Feedback.list_remarks(entry.id) == []
  end
```

`published_entry_fixture/0` が無ければ、ファイル内に既存の公開エントリ作成パターンを関数化して追加（例）:

```elixir
  defp published_entry_fixture do
    {:ok, jp} = DialectPouch.Regions.create_region(%{name: "日本", level: :country, path: "jp"})

    {:ok, entry} =
      DialectPouch.Dictionary.create_entry(
        %{
          headword: "なまら",
          slug: "なまら",
          status: :published,
          senses: [%{gloss: "とても", standard_lemma: "とても"}],
          provenance: %{kind: :manual, reliability: :verified}
        },
        [jp.id]
      )

    entry
  end
```

- [ ] **Step 2: テストを実行して失敗を確認**

Run: `mix test test/dialect_pouch_web/live/entry_live_test.exs`
Expected: FAIL（`#remark-form` が存在しない）。

- [ ] **Step 3: mount で remarks と rate_key を読み込む**

`lib/dialect_pouch_web/live/entry_live.ex` の `mount/3` を更新。`alias DialectPouch.Dictionary` の下に `alias DialectPouch.Feedback` を追加。`mount` の返り値 socket に以下を足す（`rate_key` は contribute_live と同じ手法）:

```elixir
  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    entry = Dictionary.get_published_by_slug(slug)

    if is_nil(entry) do
      raise Ecto.NoResultsError, queryable: DialectPouch.Dictionary.Entry
    end

    rate_key =
      if connected?(socket) do
        case get_connect_info(socket, :peer_data) do
          %{address: address} -> address |> :inet.ntoa() |> to_string()
          _ -> "anon"
        end
      else
        "anon"
      end

    {:ok,
     socket
     |> assign(:entry, entry)
     |> assign(:page_title, entry.headword)
     |> assign(:rate_key, rate_key)
     |> assign(:remark_error, nil)
     |> assign(:remarks, Feedback.list_remarks(entry.id))}
  end
```

- [ ] **Step 4: handle_event を追加**

`render/1` の後（`def render` の `end` の後）に、submit と report のイベントハンドラを追加:

```elixir
  @impl true
  def handle_event("submit_remark", params, socket) do
    attrs = %{
      "entry_id" => socket.assigns.entry.id,
      "kind" => params["kind"],
      "body" => params["body"],
      "author_kind" => "nickname",
      "author_nickname" => params["nickname"]
    }

    case Feedback.create_remark(attrs, socket.assigns.rate_key) do
      {:ok, _remark} ->
        {:noreply,
         socket
         |> assign(:remark_error, nil)
         |> assign(:remarks, Feedback.list_remarks(socket.assigns.entry.id))}

      {:error, :rate_limited} ->
        {:noreply, assign(socket, :remark_error, "短時間に送信が多すぎます。少し待ってからお試しください。")}

      {:error, _changeset} ->
        {:noreply,
         assign(socket, :remark_error, "ニックネームとコメントを入力してください（匿名では送れません）。")}
    end
  end

  def handle_event("report_remark", %{"id" => id}, socket) do
    {:ok, _} = Feedback.report_remark(id)
    {:noreply, put_flash(socket, :info, "通報しました。確認します。")}
  end
```

> 注: Google ログイン実装後は `author_kind`/`author_nickname` を `current_scope` から決める（seam）。今回は常に `:nickname`。

- [ ] **Step 5: PC レイアウトに指摘セクションを追加**

`lib/dialect_pouch_web/live/entry_live.ex` の PC 側（`<div class="pc-only">` 内）、`<%!-- Examples --%>` セクションの後ろ、Regions セクションの前あたりに以下を挿入。既存の `dsec`/`card`/`badge`/`field`/`btn` クラスを踏襲:

```elixir
        <%!-- Remarks (物申す) --%>
        <section id="entry-remarks" aria-label="この言葉への声" class="dsec">
          <h2 class="dsec__label">この言葉への声</h2>

          <ul
            :if={@remarks != []}
            id="remark-list"
            style="list-style:none;margin:0 0 18px;padding:0;display:grid;gap:10px;"
          >
            <li :for={r <- @remarks} id={"remark-#{r.id}"} class="card" style="padding:12px 14px;">
              <div class="row" style="gap:8px;align-items:center;flex-wrap:wrap;">
                <span class="badge badge--user">{remark_kind_label(r.kind)}</span>
                <span class="tiny muted">— {r.author_nickname}</span>
                <button
                  type="button"
                  phx-click="report_remark"
                  phx-value-id={r.id}
                  data-confirm="この投稿を通報しますか？"
                  class="tiny muted"
                  style="margin-left:auto;background:none;border:none;cursor:pointer;"
                >
                  通報
                </button>
              </div>
              <p style="margin:6px 0 0;">{r.body}</p>
            </li>
          </ul>

          <p :if={@remarks == []} class="muted tiny" style="margin:0 0 14px;">
            まだ声はありません。違いや今の言い方があれば教えてください。
          </p>

          <div
            :if={@remark_error}
            id="remark-error"
            class="note note--err"
            style="margin-bottom:12px;"
          >
            <.icon name="hero-exclamation-circle" /> {@remark_error}
          </div>

          <form id="remark-form" phx-submit="submit_remark" class="form-card card">
            <div class="form-2col">
              <div class="fieldset">
                <label class="label" for="remark-kind">種別</label>
                <div class="select-wrap select-wrap--block">
                  <select id="remark-kind" name="kind" class="select">
                    <option :for={{label, value} <- remark_kind_options()} value={value}>
                      {label}
                    </option>
                  </select>
                </div>
              </div>
              <div class="fieldset">
                <label class="label" for="remark-nickname">
                  ニックネーム<span class="req">*</span>
                </label>
                <input
                  id="remark-nickname"
                  name="nickname"
                  class="field"
                  placeholder="匿名では送れません"
                />
              </div>
            </div>
            <div class="fieldset">
              <label class="label" for="remark-body">コメント<span class="req">*</span></label>
              <textarea
                id="remark-body"
                name="body"
                class="field"
                rows="3"
                placeholder="例: 今はあまり使いません / 意味は「すごく」に近いです"
              ></textarea>
            </div>
            <div class="form-foot">
              <p class="tiny muted">ニックネーム付きで即時に公開されます。</p>
              <button type="submit" class="btn btn--primary">
                <.icon name="hero-chat-bubble-left-right" /> 物申す
              </button>
            </div>
          </form>
        </section>
```

- [ ] **Step 6: ヘルパ関数を追加**

`lib/dialect_pouch_web/live/entry_live.ex` のモジュール末尾（最後の `end` の前、private helper 群があればその近く）に追加:

```elixir
  defp remark_kind_options do
    [
      {"意味が違う", "meaning"},
      {"読みが違う", "reading"},
      {"地域が違う", "region"},
      {"もう使わない", "obsolete"},
      {"その他", "other"}
    ]
  end

  defp remark_kind_label(:meaning), do: "意味が違う"
  defp remark_kind_label(:reading), do: "読みが違う"
  defp remark_kind_label(:region), do: "地域が違う"
  defp remark_kind_label(:obsolete), do: "もう使わない"
  defp remark_kind_label(:other), do: "その他"
```

- [ ] **Step 7: モバイルレイアウトにも指摘セクションを追加**

`lib/dialect_pouch_web/live/entry_live.ex` のモバイル側（`sp-only` の `m-app` 内）の末尾近くに、PC と同等の内容を `m-` 系クラスで追加。フォーム id は重複を避け `m-remark-form` とし、`phx-submit="submit_remark"`、`select name="kind"` / `input name="nickname"` / `textarea name="body"` を同名で配置。一覧は `@remarks` を回し、各カードに `通報`（`phx-click="report_remark" phx-value-id={r.id}`）を置く。クラスは近隣のモバイル UI（`m-fieldset`/`m-label`/`m-field`/`m-select`/`m-btn`/`m-note`）に合わせる。

```elixir
        <section id="m-entry-remarks" style="margin-top:24px;">
          <h2 class="m-h2" style="font-size:18px;">この言葉への声</h2>

          <ul
            :if={@remarks != []}
            style="list-style:none;margin:10px 0 14px;padding:0;display:grid;gap:8px;"
          >
            <li :for={r <- @remarks} id={"m-remark-#{r.id}"} class="m-note" style="display:block;">
              <div class="row" style="gap:6px;align-items:center;flex-wrap:wrap;">
                <span class="m-badge m-badge--user">{remark_kind_label(r.kind)}</span>
                <span class="tiny muted">— {r.author_nickname}</span>
                <button
                  type="button"
                  phx-click="report_remark"
                  phx-value-id={r.id}
                  data-confirm="この投稿を通報しますか？"
                  class="tiny muted"
                  style="margin-left:auto;background:none;border:none;"
                >
                  通報
                </button>
              </div>
              <p style="margin:6px 0 0;">{r.body}</p>
            </li>
          </ul>

          <div :if={@remark_error} class="m-note m-note--err">
            <.icon name="hero-exclamation-circle" class="size-4" /> {@remark_error}
          </div>

          <form id="m-remark-form" phx-submit="submit_remark">
            <div class="m-fieldset">
              <label class="m-label">種別</label>
              <div class="m-selectwrap">
                <select class="m-select" name="kind">
                  <option :for={{label, value} <- remark_kind_options()} value={value}>{label}</option>
                </select>
              </div>
            </div>
            <div class="m-fieldset">
              <label class="m-label">ニックネーム<span class="m-req">*</span></label>
              <input class="m-field" name="nickname" placeholder="匿名では送れません" />
            </div>
            <div class="m-fieldset">
              <label class="m-label">コメント<span class="m-req">*</span></label>
              <textarea class="m-field" name="body" rows="3" placeholder="例: 今はあまり使いません"></textarea>
            </div>
            <button type="submit" class="m-btn m-btn--primary">
              <.icon name="hero-chat-bubble-left-right" class="size-4" /> 物申す
            </button>
          </form>
        </section>
```

- [ ] **Step 8: テストを実行して成功を確認**

Run: `mix test test/dialect_pouch_web/live/entry_live_test.exs`
Expected: PASS（追加した2テスト＋既存テスト）。

> 注: 同名 id がPC/モバイルで重複するとLiveViewテストの `form/3` が曖昧になるため、テストの `#remark-form` はPC側を指す。曖昧エラーが出たらテストのセレクタを `#remark-form` のまま、PC側 form の id を `remark-form`、モバイルを `m-remark-form` にしてある前提で解決する。

- [ ] **Step 9: Commit**

```bash
git add lib/dialect_pouch_web/live/entry_live.ex test/dialect_pouch_web/live/entry_live_test.exs
git commit -m "feat(entry): add remark (物申す) form and list to entry page"
```

---

## Task 7: モデレーション — 通報された指摘の受け皿

**Files:**
- Modify: `lib/dialect_pouch_web/live/admin_live/moderation.ex`
- Test: `test/dialect_pouch_web/live/admin_live/moderation_test.exs`

- [ ] **Step 1: 失敗するテストを書く**

`test/dialect_pouch_web/live/admin_live/moderation_test.exs` に追加（既存のログイン済み管理者 conn セットアップを流用）。冒頭に `alias DialectPouch.Feedback` を追加:

```elixir
  test "lists reported remarks and can hide them", %{conn: conn} do
    entry = published_entry_with_remark_fixture()
    [remark] = Feedback.list_remarks(entry.id)
    {:ok, _} = Feedback.report_remark(remark.id)

    {:ok, lv, html} = live(conn, ~p"/admin/moderation")
    assert html =~ "通報された指摘"
    assert html =~ remark.body

    lv |> element("#hide-remark-#{remark.id}") |> render_click()

    assert Feedback.list_remarks(entry.id) == []
  end
```

`published_entry_with_remark_fixture/0` をファイル内に追加:

```elixir
  defp published_entry_with_remark_fixture do
    {:ok, jp} = DialectPouch.Regions.create_region(%{name: "日本", level: :country, path: "jp"})

    {:ok, entry} =
      DialectPouch.Dictionary.create_entry(
        %{
          headword: "なまら",
          slug: "なまら",
          status: :published,
          senses: [%{gloss: "とても", standard_lemma: "とても"}],
          provenance: %{kind: :manual, reliability: :verified}
        },
        [jp.id]
      )

    {:ok, _} =
      Feedback.create_remark(
        %{
          "entry_id" => entry.id,
          "kind" => "meaning",
          "body" => "違うと思います",
          "author_kind" => "nickname",
          "author_nickname" => "通報対象"
        },
        "mod-fix"
      )

    entry
  end
```

- [ ] **Step 2: テストを実行して失敗を確認**

Run: `mix test test/dialect_pouch_web/live/admin_live/moderation_test.exs`
Expected: FAIL（"通報された指摘" セクションが無い）。

- [ ] **Step 3: モデレーションに通報指摘セクションを追加**

`lib/dialect_pouch_web/live/admin_live/moderation.ex` を更新。`alias DialectPouch.Dictionary` の下に `alias DialectPouch.Feedback` を追加。`mount` で `reported` を assign:

```elixir
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "モデレーション")
     |> assign(:pending, Dictionary.list_pending())
     |> assign(:reported, Feedback.list_reported())}
  end
```

`reload/1` を更新:

```elixir
  defp reload(socket) do
    socket
    |> assign(:pending, Dictionary.list_pending())
    |> assign(:reported, Feedback.list_reported())
  end
```

イベント `hide_remark` / `unhide_remark` を追加（既存 `handle_event` 群の後）:

```elixir
  def handle_event("hide_remark", %{"id" => id}, socket) do
    {:ok, _} = Feedback.hide_remark(id)
    {:noreply, socket |> put_flash(:info, "指摘を非表示にしました") |> reload()}
  end

  def handle_event("unhide_remark", %{"id" => id}, socket) do
    {:ok, _} = Feedback.unhide_remark(id)
    {:noreply, socket |> put_flash(:info, "指摘を再表示しました") |> reload()}
  end
```

`render/1` の `</ul>`（pending リスト）の後、最後の `</div>` の前に通報指摘セクションを追加:

```elixir
        <h2 class="page-title" style="margin-top:40px;font-size:20px;">通報された指摘</h2>
        <p class="help" style="margin-top:6px">
          通報のあったユーザー指摘です。問題があれば非表示にできます（削除はしません）。
        </p>

        <p :if={@reported == []} class="empty muted" style="margin-top:16px">
          通報された指摘はありません。
        </p>

        <ul style="list-style:none;margin:16px 0 0;padding:0;display:grid;gap:10px;">
          <li :for={r <- @reported} id={"reported-#{r.id}"} class="card" style="padding:14px 16px;">
            <div class="row" style="gap:8px;align-items:center;flex-wrap:wrap;">
              <span class="badge badge--user">{r.kind}</span>
              <span class="tiny muted">— {r.author_nickname}</span>
              <span class="tiny muted">通報 {r.report_count} 件</span>
              <span class="tiny muted">/ {r.entry && r.entry.headword}</span>
            </div>
            <p style="margin:6px 0 8px;">{r.body}</p>
            <div class="row" style="gap:8px;">
              <button
                :if={r.status == :visible}
                id={"hide-remark-#{r.id}"}
                phx-click="hide_remark"
                phx-value-id={r.id}
                data-confirm="この指摘を非表示にしますか？"
                class="btn btn--ghost"
              >
                非表示にする
              </button>
              <button
                :if={r.status == :hidden}
                id={"unhide-remark-#{r.id}"}
                phx-click="unhide_remark"
                phx-value-id={r.id}
                class="btn btn--ghost"
              >
                再表示する
              </button>
            </div>
          </li>
        </ul>
```

> `list_reported` は `report_count > 0` を返すので非表示化後もこの一覧には残り、`再表示する` で戻せる。

- [ ] **Step 4: テストを実行して成功を確認**

Run: `mix test test/dialect_pouch_web/live/admin_live/moderation_test.exs`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/dialect_pouch_web/live/admin_live/moderation.ex test/dialect_pouch_web/live/admin_live/moderation_test.exs
git commit -m "feat(moderation): add reported-remarks queue with hide/restore"
```

---

## Task 8: 全体テストと仕上げ

- [ ] **Step 1: 全テストを実行**

Run: `mix test`
Expected: 全 PASS。落ちたら該当タスクへ戻る。

- [ ] **Step 2: フォーマットと警告チェック**

Run: `mix format && mix compile --warnings-as-errors`
Expected: 差分が出たら `git add -A` で取り込み、警告ゼロ。

- [ ] **Step 3: 仕上げコミット（差分があれば）**

```bash
git add -A
git commit -m "chore(remarks): format and resolve warnings"
```

---

## Self-Review メモ（計画作成者による確認）

- **スペック §4 データモデル** → Task 1（テーブル）/ Task 2（スキーマ）。enum 値・匿名禁止validation を反映。
- **スペック §5A 指摘即公開** → Task 3 `create_remark`（`:visible`）/ Task 6（UI・即時表示）。
- **スペック §5B 投稿即時公開化** → Task 5（素性ありで `:published`、匿名は `:draft`）。既存テストの期待値更新も含む。
- **スペック §5C 検知受け皿** → Task 3 `report_remark`/`hide_remark`/`list_reported` ＋ Task 7（モデレーション画面）。
- **スペック §6 UI（PC/モバイル両方）** → Task 6 Step 5/7。
- **スペック §7 テスト** → 各タスクの TDD ステップに分散。
- **Google seam** → Remark に `author_kind: :google` enum 値のみ用意（Task 2）。EntryLive は常に `:nickname`（Task 6 Step 4 の注記）。
- **型整合**: `create_remark/2`・`list_remarks/1`・`report_remark/1`・`hide_remark/1`・`unhide_remark/1`・`list_reported/0`・`remark_kind_label/1`・`remark_kind_options/0` を全タスクで同名使用。
