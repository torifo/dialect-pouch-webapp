# dialect-pouch MVP Requirements

## Overview
dialect-pouch は、日本各地の方言・言い回しを「気になったら気軽に調べ、眺め、変換して遊べる」consumer 向け Web アプリである。辞書臭さを排し、検索流入（SEO）と地図ブラウズを入口に「へぇ、面白い」体験を提供する。各データは出典・素性（provenance）を一級市民として保持し、「それっぽい嘘」を出さないことを最優先とする。本ドキュメントは MVP（最初に出荷する版）のスコープを定義する。

## Personas
- **探訪者（Curious）**: 出身地問わず、気になった方言を調べたり眺めて楽しむライト層。主要ターゲット。
- **望郷者（Homesick）**: 上京・移住した地方出身者。「うちの言葉」を懐かしむ。
- **投稿者（Contributor）**: 地域の言葉をニックネームで追加する協力ユーザー。
- **キュレーター（Curator）**: オープンデータ取り込み・LLM補完・投稿を検証/承認する運営（開発者本人）。

## Scope
- **In scope (MVP)**: 方言エントリの検索・閲覧、地域階層の地図ブラウズ、語/言い回しレベルの変換（主機能）と文章内マッチ置換（サブ機能）、ニックネーム投稿とモデレーション、オープンデータ取り込みパイプラインの基盤、provenance 表示。
- **Out of scope (将来)**: BYOK による文章丸ごと方言化（P2、別フィーチャー）、音声・発音録音、ネイティブアプリ、フォロー等の重厚な SNS 機能、全文機械翻訳エンジン。

---

## User Stories

### US-001: 方言を検索して意味を知る
**As a** 探訪者 **I want to** 方言・意味・地域名で検索する **So that** 気になった言葉の意味と使われる地域をすぐ理解できる

**Acceptance Criteria:**
- WHEN ユーザーが検索ボックスに方言の見出し語を入力し検索を実行する THE SYSTEM SHALL 一致するエントリを関連度順に一覧表示する
- WHEN ユーザーが意味（標準語）を入力し検索する THE SYSTEM SHALL その意味に対応する方言エントリを一覧表示する
- WHEN 検索結果が 0 件である THE SYSTEM SHALL 「該当なし」と、表記ゆれ・部分一致の候補を提示する
- IF 検索クエリが空である THEN THE SYSTEM SHALL 検索を実行せず入力を促す

### US-002: 検索エンジンから個別ページに着地する（SEO）
**As a** 探訪者 **I want to** 「○○弁 △△ 意味」で検索した時にエントリ個別ページに直接たどり着く **So that** 検索流入だけで完結して理解できる

**Acceptance Criteria:**
- WHEN クローラまたはユーザーがエントリ個別 URL にアクセスする THE SYSTEM SHALL サーバーサイドレンダリングされた HTML（見出し語・意味・用例・地域・出典）を返す
- THE SYSTEM SHALL 各エントリページに一意で永続的な URL（slug ベース）を持たせる
- THE SYSTEM SHALL 各エントリページにタイトル・メタディスクリプション・構造化データ（JSON-LD）を出力する

### US-003: 地図から地域の方言を眺める
**As a** 望郷者 **I want to** 日本地図から都道府県を選び、データのある地域はさらに掘り下げる **So that** 「うちの地域」の言葉を発見して楽しめる

**Acceptance Criteria:**
- WHEN ユーザーが地図上の都道府県を選択する THE SYSTEM SHALL その都道府県に紐づくエントリ一覧と、配下のサブ地域（データが存在するもの）を表示する
- IF 選択した地域に配下のサブ地域データが存在する THEN THE SYSTEM SHALL ドリルダウン可能であることを示し、選択でその地域に絞り込む
- IF 選択した地域に配下のサブ地域データが存在しない THEN THE SYSTEM SHALL ドリルダウンUIを提示せず、当該地域のエントリのみ表示する
- WHILE ユーザーが地図を操作している THE SYSTEM SHALL ページ全体を再読み込みせず該当領域のみ更新する

### US-004: 語・言い回しを変換する（主機能）
**As a** 探訪者 **I want to** 標準語の語/言い回しを指定地域の方言に変換し、逆も引く **So that** 遊び感覚で方言の言い方を知れる

**Acceptance Criteria:**
- WHEN ユーザーが標準語の語/言い回しと対象地域を指定して変換する THE SYSTEM SHALL DB に存在する対応エントリのみを候補として、各候補に出典を添えて提示する
- WHEN 複数の方言候補が存在する THE SYSTEM SHALL すべての候補を地域・出典つきで列挙する
- IF 指定語に対応するエントリが DB に存在しない THEN THE SYSTEM SHALL 「データなし」と明示し、推測した結果を生成しない
- THE SYSTEM SHALL 変換結果に対し、その語が確定情報か未検証（要確認）かを示す

### US-005: 文章内のマッチ語を置換する（サブ機能）
**As a** 探訪者 **I want to** 文章を入力して、DB にマッチした語だけ方言に置換・ハイライト表示する **So that** 文章全体の雰囲気を方言寄りに遊べる

**Acceptance Criteria:**
- WHEN ユーザーが文章と対象地域を入力する THE SYSTEM SHALL DB に一致した語のみを方言に置換し、置換箇所をハイライトする
- THE SYSTEM SHALL マッチしなかった部分を改変せずそのまま保持する
- WHEN 置換候補が複数ある語が含まれる THE SYSTEM SHALL 既定候補を適用しつつ他候補を選択可能にする

### US-006: 方言を投稿する
**As a** 投稿者 **I want to** ニックネームで方言エントリを追加する **So that** 自分の地域の言葉を残し共有できる

**Acceptance Criteria:**
- WHEN 投稿者が見出し語・意味・地域・任意の用例・ニックネームを入力し送信する THE SYSTEM SHALL 投稿を「未承認」状態で保存し、provenance を `user`（ニックネーム付き）として記録する
- IF 必須項目（見出し語・意味・地域）が欠けている THEN THE SYSTEM SHALL 送信を拒否し欠落項目を指摘する
- WHEN 投稿が保存される THE SYSTEM SHALL 公開一覧には承認まで表示しない
- THE SYSTEM SHALL 投稿レート制限（同一クライアントあたり単位時間あたりの上限）を適用する

### US-007: 投稿・取り込みデータを検証/承認する
**As a** キュレーター **I want to** 未承認エントリ（投稿・LLM補完）を確認して承認/却下する **So that** 公開データの正確性を担保できる

**Acceptance Criteria:**
- WHEN キュレーターがモデレーション画面を開く THE SYSTEM SHALL 未承認エントリを provenance 種別つきで一覧表示する
- WHEN キュレーターがエントリを承認する THE SYSTEM SHALL 当該エントリを公開状態にし、必要なら provenance を昇格（`llm_assisted` → 検証済み）する
- WHEN キュレーターがエントリを却下する THE SYSTEM SHALL 当該エントリを非公開のまま却下理由とともに保持する
- THE SYSTEM SHALL モデレーション操作に管理者認証を要求する

### US-008: 出典・素性を明示する
**As a** 探訪者 **I want to** 各情報がどこ由来か（オープンデータ/手動/ユーザー/LLM）を見られる **So that** 情報の信頼度を自分で判断できる

**Acceptance Criteria:**
- THE SYSTEM SHALL 各エントリに provenance 種別（`open_data` / `manual` / `user` / `llm_assisted`）を表示する
- IF provenance が `open_data` である THEN THE SYSTEM SHALL 出典名と出典 URL リンクを表示する
- IF provenance が `user` である THEN THE SYSTEM SHALL 投稿者ニックネームを表示する（匿名 `manual` は投稿者を表示しない）
- IF provenance が `llm_assisted` かつ未検証である THEN THE SYSTEM SHALL 「要確認」バッジを表示する

### US-009: オープンデータを取り込む
**As a** キュレーター **I want to** 出典つきオープンデータをバッチで取り込み、疎な領域は LLM 補完する **So that** 初期データを効率よく整える

**Acceptance Criteria:**
- WHEN 取り込みジョブを実行する THE SYSTEM SHALL 各レコードに出典（`open_data`、URL/ライセンス含む）を付与して登録する
- WHEN LLM 補完ジョブを実行する THE SYSTEM SHALL 生成エントリを provenance `llm_assisted`・未検証・非公開で登録する
- IF 取り込みレコードが既存エントリと重複する THEN THE SYSTEM SHALL 重複として既存に紐づけ、二重登録しない
- WHILE 取り込みジョブが実行中である THE SYSTEM SHALL 進捗と失敗件数を記録し、失敗レコードを後で再試行可能にする

---

## Functional Requirements

### FR-001: 階層地域モデル
**Priority:** P0 | **Persona:** 全員
THE SYSTEM SHALL 地域を階層ツリー（国 > 都道府県 > 地域/方言圏）として保持し、各エントリを任意の階層ノードに 1 つ以上紐づけられる。
**Rationale:** 「県内でも違う」を表現しつつ、データ充実度に応じて粒度を変えられるようにするため。

### FR-002: provenance 第一級管理
**Priority:** P0 | **Persona:** 探訪者/キュレーター
THE SYSTEM SHALL 各エントリに provenance 種別・出典参照・検証状態を必須メタデータとして保持する。
**Rationale:** 正確性の担保と信頼度の可視化がプロダクトの生命線であるため。

### FR-003: 日本語全文検索
**Priority:** P0 | **Persona:** 探訪者
WHEN ユーザーが検索する THE SYSTEM SHALL 見出し語・読み・意味・用例を対象に、日本語に対応した部分一致/N-gram 検索を行う。
**Rationale:** 表記ゆれの多い方言で取りこぼしを減らすため。

### FR-004: SSR とパーマリンク
**Priority:** P0 | **Persona:** 探訪者
THE SYSTEM SHALL 一覧・エントリ・地域ページをサーバーサイドレンダリングし、安定した slug URL を提供する。
**Rationale:** ロングテール SEO 流入をコア導線とするため。

### FR-005: 変換エンジン（DB ルックアップ方式）
**Priority:** P0（語/言い回し）/ P1（文章内置換）| **Persona:** 探訪者
THE SYSTEM SHALL 変換を DB エントリのルックアップに限定し、生成系による推測変換を行わない。
**Rationale:** 「それっぽい嘘」を構造的に排除するため。

### FR-006: 投稿とモデレーション
**Priority:** P1 | **Persona:** 投稿者/キュレーター
THE SYSTEM SHALL ユーザー投稿を未承認で受け付け、キュレーター承認後にのみ公開する。
**Rationale:** UGC の信頼性と荒らし耐性を保つため。

### FR-007: 管理者認証
**Priority:** P1 | **Persona:** キュレーター
THE SYSTEM SHALL モデレーション・取り込み操作に管理者認証を要求する。
**Rationale:** 公開データの改変を権限者に限定するため。

### FR-008: 取り込み/補完ジョブ基盤
**Priority:** P1 | **Persona:** キュレーター
THE SYSTEM SHALL バッチ取り込み・LLM 補完を永続ジョブとして実行し、再試行と進捗記録を可能にする。
**Rationale:** 大量オープンデータの取り込みを安定運用するため。

---

## Non-Functional Requirements
- **Performance**: エントリ個別ページの SSR 初期表示（TTFB）を通常負荷で 300ms 以内。検索 API のサーバー応答を p95 で 500ms 以内。
- **SEO**: 全公開ページが SSR・一意 slug・JSON-LD 構造化データを持つ。
- **正確性/信頼性**: 公開される全エントリが provenance を保持する。未検証 `llm_assisted` は既定で非公開、または公開時は「要確認」バッジ必須。
- **Security**: 投稿入力のサニタイズと XSS 防止。投稿レート制限。モデレーション/取り込みは管理者認証必須。
- **Scalability**: 単一 VPS（中規模）で 10 万エントリ・月間数万 PV を捌ける構成。将来のネイティブアプリ向けに JSON API を提供可能なドメイン分離を保つ。
- **Deploy**: VPS / オンプレに `mix release` + systemd もしくは Docker、NGINX 前段で配信可能であること。
- **可用性**: 単一ノードでの運用を前提とし、定期バックアップ（DB）を備える。
