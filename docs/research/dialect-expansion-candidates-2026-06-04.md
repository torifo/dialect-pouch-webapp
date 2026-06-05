# dialect-pouch 方言データ増強候補調査 2026-06-04

目的: seed JSON へ大量追加する前の情報収集台帳。現時点では DB/seed へは投入しない。

## 現在のローカル状況

- 対象ディレクトリ: `/Users/akito-shoji/dev/web/dialect-pouch`
- 既存 seed: `priv/seed_data/dialect/*.json`
- 2026-06-04 seed 反映後: 51 ファイル / 740 entries
- `jp.kansai` を日本直下の `area` として追加し、大阪・京都・播州などで共有される関西弁の横断カテゴリを用意済み。
- slug 生成: `headword + "-" + region_path の末尾ラベル`
- 重複回避ルール:
  - 同一 `region_path` 内の同一 `headword` は追加しない。
  - 同一語が別地域にある場合は、意味・用法が地域差として説明できるものだけ採用候補にする。
  - 既存例: `わや`, `いずい`, `あずましい`, `めんこい`, `へん` などは地域差があるため、機械的な全排除はしない。

## 優先して厚くする地域

| region_path | 既存件数 | 方針 |
|---|---:|---|
| `jp.okinawa` | 5 | あじまぁ沖縄を主ソースに 100 件単位で補完可能。利用規約は明確なオープンライセンスではないため `community/unverified` 候補。 |
| `jp.osaka` | 10 | 大阪府教材 PDF と方言一覧サイトを併用。一般語化している語も多いため、大阪固有・関西共通・全国化を要判定。 |
| `jp.aomori.tsugaru` | 20 | 五所川原市観光協会・つがる市資料・学術 PDF を優先。表記揺れが大きいため reading と headword の正規化が必要。 |
| `jp.hokkaido` | 10 | 北海道方言辞典が 1,494 語規模。地域差・世代差の注意書き付きで `community/unverified` 候補。 |
| `jp.miyagi.sendai` | 10 | 仙台弁こけしのミニ辞典・スタンプ語彙が豊富。商用キャラクター由来の例文転載は避け、語と意味だけ候補化。 |

## 確認済みソース候補

| source_name | URL | 規模/特徴 | 採用メモ |
|---|---|---|---|
| OKINAWA41 うちなーぐち一覧 | https://www.okinawa41.go.jp/dialect | 内閣府委託事業ページ。方言一覧・意味・音声あり。 | 明示オープンライセンスではないが、公共性が高く沖縄の会話表現の確認元として優先。 |
| 国立国語研究所 沖縄語辞典データ集 | 要追加確認 | サブエージェント報告では CC BY 4.0。 | 次フェーズで最優先確認。CC BY 4.0 が確認できれば沖縄語 seed の本命。 |
| 沖縄方言辞典 あじまぁ | https://hougen.ajima.jp/ | サイト表示で 3,557 語規模。五十音索引あり。 | オープンライセンスではないため、全文転載せず語・意味・出典 URL のみ。 |
| 北海道方言・北海道弁辞典 | https://hokkaido-hougen.com/ | トップ表示で 1,494 語収録。五十音・カテゴリあり。 | All Rights Reserved 表示。語・意味・リンクの候補台帳に留める。 |
| 青森県観光国際交流機構 津軽弁 | https://www.kokusai-koryu.jp/seikatujyouhou/seikatujyouhou-2371/ | 青森市提供情報の生活情報ページ。基本語彙あり。 | 公益社団法人ソース。明示 CC なしのため `community/unverified`。 |
| 黒石観光協会 津軽弁の部屋 | https://kuroishi.or.jp/about-2/welcome_jun/tugaruben/action | 動作編・感情表現編など。 | 無断転載/再利用不可。語・意味・リンクの候補台帳に留める。 |
| 五所川原市観光協会 津軽弁紹介 | https://www.go-kankou.jp/dialect/ | 観光協会の津軽弁紹介。検索結果で五十音カテゴリを確認。 | Web fetch は 502 だったが検索スニペットで存在確認。後でブラウザ/手動取得。 |
| つがる市 つがる辞典 PDF | https://www.city.tsugaru.aomori.jp/material/files/group/41/tsugaru_ziten06.pdf | 自治体 PDF。方言を使った地域 PR 資料。 | 語彙辞典というより派生企画。津軽弁表現の確認補助。 |
| 大阪府 中学校国語ワークブック 方言 | https://www.pref.osaka.lg.jp/documents/9099/jjwb-211-215.pdf | 方言教材。複数地域の例あり。 | 大阪弁専用辞典ではないが、教育資料として出典価値あり。 |
| OSAKA INFO 大阪弁 | https://osaka-info.jp/osaka/basic/osaka-dialect/ | 大阪観光局公式の大阪弁紹介。 | 観光局公式で信頼度は高め。著作権制限あり、語・意味・リンクのみ。 |
| Wikibooks 大阪弁/語彙 | https://ja.wikibooks.org/wiki/大阪弁/語彙 | 大阪弁語彙。 | CC BY-SA 系。公開編集型なので補助確認向き。 |
| 47都道府県の方言辞典 大阪府 | https://goiryoku-kitaeru.com/hougen/oosaka/ | 大阪弁の五十音一覧。 | 規約明確でない。候補抽出元として `community/unverified`。 |
| 京都民報 京のことば | https://www.kyoto-minpo.net/html/naruhodo-kyoto/kotoba/index.html | 京ことば解説。 | 無断転載禁止。語・意味・リンクのみ。 |
| 播州弁辞典 | https://www.bansyuuben.jp/ | 播州弁特化辞典。 | 明示オープンライセンスなし。地域特化の候補元。 |
| 仙台弁こけし 仙台弁ミニ辞典 | https://kokesu.com/sendaiben/ | 仙台弁の意味・用例付き一覧。 | キャラクター/スタンプ素材の文章は転載しない。語・意味・URL のみ候補化。 |

## アニメ・漫画など作品由来の扱い

- 採用可: 作品で広く知られた方言語彙・フレーズを、作品名・話数/巻数・公式配信/公式ページなどの provenance 付きで seed 候補にする。
- 注意: 引用元を示すだけでは十分とは限らないため、`example` に作中台詞を入れる場合は、方言用例の説明に必要な短い引用へ限定する。
- 避ける: 長い台詞、会話全体、歌詞、作品本文の連続転載。方言語彙だけ確認できる場合は `example` は空欄にする。
- 例: 「道産子ギャルはなまらめんこい」のような作品名由来の裏取りは、`なまら` / `めんこい` の出典補助として使い、作品台詞の大量登録にはしない。

## 追加候補: 沖縄 `jp.okinawa`

Source: 沖縄方言辞典 あじまぁ。既存 `うちなーぐち`, `たかさん`, `ちぶる`, `めんそーれ`, `めんそーれー` は除外。

| headword | reading | meaning | source_url | note |
|---|---|---|---|---|
| かなさん | かなさん | 愛おしい・愛してる・好き | https://hougen.ajima.jp/e1050 | ユーザー例「かなさん=愛してる」に対応。 |
| かなさんどー | かなさんどー | 愛しているよ | https://hougen.ajima.jp/e1050 | `かなさん` の派生表現。個別 entry 化するか alias 化を要判定。 |
| あい | あい | やあ | https://hougen.ajima.jp/gojyuon/a/ | 挨拶。短語のため同音異義に注意。 |
| あいえーなー | あいえーなー | しまった・間違えた | https://hougen.ajima.jp/gojyuon/a/ | 感嘆表現。 |
| あかさん | あかさん | 明るい | https://hougen.ajima.jp/gojyuon/a/ | 形容詞。 |
| あかちち | あかちち | 明け方 | https://hougen.ajima.jp/gojyuon/a/ | 時間語。 |
| あがた | あがた | 向こう側 | https://hougen.ajima.jp/gojyuon/a/ | 位置語。 |
| あがちゃー | あがちゃー | 働き者 | https://hougen.ajima.jp/gojyuon/a/ | 人の性質。 |
| あがちゅん | あがちゅん | 働く | https://hougen.ajima.jp/gojyuon/a/ | 動詞。 |
| あがり | あがり | 東 | https://hougen.ajima.jp/gojyuon/a/ | 方角。 |
| あきさみよー | あきさみよー | あれまあ・なんてことだ | https://hougen.ajima.jp/gojyuon/a/ | 感嘆表現。 |
| あぎじゃびよー | あぎじゃびよー | なんてこった | https://hougen.ajima.jp/gojyuon/a/ | 感嘆表現。 |
| あくた | あくた | ゴミ | https://hougen.ajima.jp/gojyuon/a/ | 名詞。 |
| あぐ | あぐ | 友人 | https://hougen.ajima.jp/gojyuon/a/ | 宮古地域注記あり。地域粒度を `jp.okinawa.miyako` に分ける候補。 |
| あさなー | あさなー | 朝寝坊 | https://hougen.ajima.jp/gojyuon/a/ | 生活語。 |
| あさばん | あさばん | 昼食 | https://hougen.ajima.jp/gojyuon/a/ | 食事語。 |
| あしがちゃー | あしがちゃー | せっかちな人 | https://hougen.ajima.jp/gojyuon/a/ | 人の性質。 |
| あしび | あしび | 歌・三線・踊りなどを楽しむこと | https://hougen.ajima.jp/gojyuon/a/ | 文化語。 |
| あしばー | あしばー | 遊び人 | https://hougen.ajima.jp/gojyuon/a/ | 人を指す語。 |
| あじくーたー | あじくーたー | 味のよいもの | https://hougen.ajima.jp/gojyuon/a/ | 食味表現。 |
| あじまー | あじまー | 交差したところ | https://hougen.ajima.jp/gojyuon/a/ | 地形/場所語。 |
| あたい | あたい | 菜園 | https://hougen.ajima.jp/gojyuon/a/ | 鹿児島 seed に同 headword あり。地域差採用可。 |
| あたいめー | あたいめー | 当たり前 | https://hougen.ajima.jp/gojyuon/a/ | 表記違い `あてーめー` もあり。 |
| あちこーこー | あちこーこー | 熱い | https://hougen.ajima.jp/gojyuon/a/ | 食べ物表現としても使われる可能性。 |
| あちゃー | あちゃー | 明日 | https://hougen.ajima.jp/gojyuon/a/ | 時間語。 |
| あっしぇ | あっしぇ | まったく | https://hougen.ajima.jp/gojyuon/a/ | 感嘆/副詞。 |
| あったに | あったに | 急に | https://hougen.ajima.jp/gojyuon/a/ | 副詞。 |
| あったぶい | あったぶい | にわか雨 | https://hougen.ajima.jp/gojyuon/a/ | 天候語。 |
| あっちゃー | あっちゃー | する者 | https://hougen.ajima.jp/gojyuon/a/ | 造語的接尾要素か要確認。 |
| あっちゅん | あっちゅん | 歩く | https://hougen.ajima.jp/gojyuon/a/ | 動詞。 |
| あなかちさん | あなかちさん | 懐かしい | https://hougen.ajima.jp/gojyuon/a/ | 形容詞。 |
| あぬひゃー | あぬひゃー | あいつ | https://hougen.ajima.jp/gojyuon/a/ | 代名詞。 |
| あびる | あびる | 話す | https://hougen.ajima.jp/gojyuon/a/ | 動詞。 |
| あびーん | あびーん | 叫ぶ | https://hougen.ajima.jp/gojyuon/a/ | 動詞。 |
| あま | あま | あそこ | https://hougen.ajima.jp/gojyuon/a/ | 指示語。 |
| あまくま | あまくま | あちこち | https://hougen.ajima.jp/gojyuon/a/ | 指示語。 |
| あまさん | あまさん | 甘い | https://hougen.ajima.jp/gojyuon/a/ | 形容詞。 |
| あみ | あみ | 雨 | https://hougen.ajima.jp/gojyuon/a/ | 天候語。 |
| あらん | あらん | 違う | https://hougen.ajima.jp/gojyuon/a/ | 否定/判定。 |
| あんくとぅ | あんくとぅ | だから | https://hougen.ajima.jp/gojyuon/a/ | 接続表現。 |
| あんせー | あんせー | それでは | https://hougen.ajima.jp/gojyuon/a/ | 接続表現。 |
| あんちゅ | あんちゅ | あの人 | https://hougen.ajima.jp/gojyuon/a/ | 人称。 |
| あんべー | あんべー | 具合 | https://hougen.ajima.jp/gojyuon/a/ | 東北にも類似語あり。 |
| あんまさん | あんまさん | 具合が悪い | https://hougen.ajima.jp/gojyuon/a/ | 体調表現。 |
| あんまー | あんまー | お母さん | https://hougen.ajima.jp/gojyuon/a/ | 家族語。 |
| いきが | いきが | 男 | https://hougen.ajima.jp/gojyuon/i/ | 人称/性別語。 |
| いきがんぐゎ | いきがんぐゎ | 男の子・息子 | https://hougen.ajima.jp/gojyuon/i/ | 同一見出しで複数義。sense 複数候補。 |
| いきらさん | いきらさん | 少ない | https://hougen.ajima.jp/gojyuon/i/ | 形容詞。 |
| いくけーん | いくけーん | 何度 | https://hougen.ajima.jp/gojyuon/i/ | 疑問語。 |
| いくたい | いくたい | 何人 | https://hougen.ajima.jp/gojyuon/i/ | 疑問語。 |

### 沖縄: OKINAWA41 追加候補

Source: OKINAWA41 うちなーぐち一覧。既存 seed と上表の重複は除外。ただし `ちむどんどん`, `あちこうこう` は「あじまぁ候補の別表記・別ソース裏取り」として残す。

| headword | reading | meaning | source_url | note |
|---|---|---|---|---|
| またやーたい | またやーたい | また会いましょう | https://www.okinawa41.go.jp/dialect | 挨拶。 |
| まかちょーけー | まかちょーけー | 任せてくださいね | https://www.okinawa41.go.jp/dialect | 依頼/応答。 |
| ちゅら | ちゅら | 美しい | https://www.okinawa41.go.jp/dialect | 形容詞。 |
| ちゃーがんじゅうねー | ちゃーがんじゅうねー | 元気にしてた？ | https://www.okinawa41.go.jp/dialect | 挨拶。 |
| ちむどんどん | ちむどんどん | 胸がどきどきする | https://www.okinawa41.go.jp/dialect | あじまぁにも類似候補あり。 |
| ちばりよー | ちばりよー | がんばれ | https://www.okinawa41.go.jp/dialect | 応援表現。 |
| うきみそーちー | うきみそーちー | おはようございます | https://www.okinawa41.go.jp/dialect | 挨拶。 |
| うーとーとー | うーとーとー | 神仏・先祖を拝む際に唱えることば | https://www.okinawa41.go.jp/dialect | 文化語。 |
| あんじー | あんじー | 相づち・そうなの？ | https://www.okinawa41.go.jp/dialect | 応答表現。 |
| まーさん | まーさん | 美味しい | https://www.okinawa41.go.jp/dialect/page/2 | 食味表現。 |
| ぬーそーがー | ぬーそーがー | 何してる？ | https://www.okinawa41.go.jp/dialect/page/2 | 会話表現。 |
| ちーちーかーかー | ちーちーかーかー | パサパサする | https://www.okinawa41.go.jp/dialect/page/2 | 食感。 |
| あちこうこう | あちこうこう | 熱い・ほかほか | https://www.okinawa41.go.jp/dialect/page/2 | あじまぁ `あちこーこー` と表記差。alias 候補。 |
| あがいたんでぃ | あがいたんでぃ | あらまあ | https://www.okinawa41.go.jp/dialect/page/2 | 感嘆。 |
| くわっちーさびら | くわっちーさびら | いただきます | https://www.okinawa41.go.jp/dialect/page/2 | 食事挨拶。 |
| なんくるないさー | なんくるないさー | なんとかなるさ | https://www.okinawa41.go.jp/dialect/page/3 | 定番表現。 |
| いちゃりばちょーでー | いちゃりばちょーでー | 一度会ったら兄弟 | https://www.okinawa41.go.jp/dialect/page/3 | ことわざ的表現。 |

### 沖縄: あじまぁ会話カテゴリ追加候補

Source: 沖縄方言辞典 あじまぁ 会話/挨拶カテゴリ。既存 seed と上表の重複は除外。

| headword | reading | meaning | source_url | note |
|---|---|---|---|---|
| あちさいびーんやー | あちさいびーんやー | 暑いですね | https://hougen.ajima.jp/category/conversation/greetings/ | 挨拶/天候。 |
| いい そーぐゎち でーびる | いい そーぐゎち でーびる | 明けましておめでとうございます | https://hougen.ajima.jp/category/conversation/greetings/ | 季節挨拶。 |
| いみそーれ | いみそーれ | お入りください | https://hougen.ajima.jp/category/conversation/greetings/ | 依頼/招待。 |
| うさがみそーれー | うさがみそーれー | お召し上がりください | https://hougen.ajima.jp/category/conversation/greetings/ | 食事表現。 |
| うにげーさびら | うにげーさびら | お願いします | https://hougen.ajima.jp/category/conversation/greetings/ | 依頼。 |
| かりーさびら | かりーさびら | 乾杯 | https://hougen.ajima.jp/category/conversation/greetings/ | 挨拶。 |
| くわっちーさびたん | くわっちーさびたん | ごちそうさま | https://hougen.ajima.jp/category/conversation/greetings/ | 食事挨拶。 |
| ぐすーよー | ぐすーよー | 皆さん | https://hougen.ajima.jp/category/conversation/greetings/ | 呼びかけ。 |
| ぐぶりーさびら | ぐぶりーさびら | 失礼します | https://hougen.ajima.jp/category/conversation/greetings/ | 挨拶。 |
| ちゃーびらさい | ちゃーびらさい | ごめんください | https://hougen.ajima.jp/category/conversation/greetings/ | 訪問挨拶。 |
| ちゅーうがまびら | ちゅーうがまびら | こんにちは | https://hougen.ajima.jp/category/conversation/greetings/ | 挨拶。 |
| にふぇーでーびる | にふぇーでーびる | ありがとうございます | https://hougen.ajima.jp/category/conversation/greetings/ | 感謝。 |
| にふぇーでーびたん | にふぇーでーびたん | ありがとうございました | https://hougen.ajima.jp/category/conversation/greetings/ | 感謝。 |
| にんじみそーれー | にんじみそーれー | おやすみなさい | https://hougen.ajima.jp/category/conversation/greetings/ | 挨拶。 |
| はいさい | はいさい | やあ | https://hougen.ajima.jp/category/conversation/greetings/ | 挨拶。 |
| はじみてぃやーさい | はじみてぃやーさい | はじめまして | https://hougen.ajima.jp/category/conversation/greetings/ | 挨拶。 |
| ひーさいびーんやー | ひーさいびーんやー | 寒いですね | https://hougen.ajima.jp/category/conversation/greetings/ | 挨拶/天候。 |
| またやーさい | またやーさい | またね | https://hougen.ajima.jp/category/conversation/greetings/ | 挨拶。 |
| まーかいめんせーが | まーかいめんせーが | どちらへおでかけですか | https://hougen.ajima.jp/category/conversation/greetings/ | 挨拶。 |
| ゆくいみそーれー | ゆくいみそーれー | ひと休みなさいませ | https://hougen.ajima.jp/category/conversation/greetings/ | 依頼/勧め。 |
| ゆたしく | ゆたしく | よろしく | https://hougen.ajima.jp/category/conversation/greetings/ | 挨拶。 |
| わっさいびーん | わっさいびーん | ごめんなさい | https://hougen.ajima.jp/category/conversation/greetings/ | 謝罪。 |
| んじちゃーびら | んじちゃーびら | さよなら | https://hougen.ajima.jp/category/conversation/greetings/ | 挨拶。 |
| んじめんそーれー | んじめんそーれー | いってらっしゃい | https://hougen.ajima.jp/category/conversation/greetings/ | 挨拶。 |
| んみゃーち | んみゃーち | いらっしゃい・ようこそ | https://hougen.ajima.jp/e190 | 宮古方言。`jp.okinawa.miyako` 分離候補。 |
| おーりとーり | おーりとーり | いらっしゃい・ようこそ | https://hougen.ajima.jp/e190 | 八重山方言。`jp.okinawa.yaeyama` 分離候補。 |

## 追加候補: 大阪 `jp.osaka`

Source: 47都道府県の方言辞典 大阪府。既存 `いきはる`, `おます`, `すもじ`, `だす`, `ねん`, `はん`, `へん`, `ぼちぼちでんな`, `もうかりまっか`, `やん` は除外。

| headword | reading | meaning | source_url | note |
|---|---|---|---|---|
| あかん | あかん | ダメ・良くない | https://goiryoku-kitaeru.com/hougen/oosaka/ | 徳島 seed に同語あり。大阪にも採用可。 |
| あかんたれ | あかんたれ | 弱虫 | https://goiryoku-kitaeru.com/hougen/oosaka/ | 人を指す語。 |
| あんじょー | あんじょー | 上手に | https://goiryoku-kitaeru.com/hougen/oosaka/ | 副詞。 |
| 行きしな | いきしな | 行く途中 | https://goiryoku-kitaeru.com/hougen/oosaka/ | 表記をかなに寄せるか要判定。 |
| いちびる | いちびる | 悪ふざけする | https://goiryoku-kitaeru.com/hougen/oosaka/ | `いちぶる` 表記も候補。 |
| いてこます | いてこます | やっつける | https://goiryoku-kitaeru.com/hougen/oosaka/ | 俗語性あり。 |
| いらう | いらう | 触る・からかう | https://goiryoku-kitaeru.com/hougen/oosaka/ | 動詞。 |
| いらち | いらち | せっかち・短気者 | https://goiryoku-kitaeru.com/hougen/oosaka/ | 岡山 seed に同語あり。大阪にも採用可。 |
| うそたれ | うそたれ | 嘘つき | https://goiryoku-kitaeru.com/hougen/oosaka/ | 人を指す語。 |
| うっとこ | うっとこ | 私の家 | https://goiryoku-kitaeru.com/hougen/oosaka/ | 生活語。 |
| ええ | ええ | 良い | https://goiryoku-kitaeru.com/hougen/oosaka/ | 広島 seed に同語あり。 |
| えげつない | えげつない | ひどい | https://goiryoku-kitaeru.com/hougen/oosaka/ | 全国化しているため要判定。 |
| えらい | えらい | 疲れた | https://goiryoku-kitaeru.com/hougen/oosaka/ | 愛知/香川/山口 seed に同語あり。 |
| おーきに | おーきに | ありがとう | https://goiryoku-kitaeru.com/hougen/oosaka/ | 京都 seed `おおきに` と表記差。alias 候補。 |
| おーじょーする | おーじょーする | 困る | https://goiryoku-kitaeru.com/hougen/oosaka/ | 動詞。 |
| おとつい | おとつい | 一昨日 | https://goiryoku-kitaeru.com/hougen/oosaka/ | 全国語との差を要確認。 |
| おもろい | おもろい | おもしろい | https://goiryoku-kitaeru.com/hougen/oosaka/ | 全国化しているが関西色が強い。 |
| かいらし | かいらし | かわいらしい | https://goiryoku-kitaeru.com/hougen/oosaka/ | 形容詞。 |
| 帰りしな | かえりしな | 帰る途中 | https://goiryoku-kitaeru.com/hougen/oosaka/ | 表記正規化要。 |
| かまへん | かまへん | かまわない | https://goiryoku-kitaeru.com/hougen/oosaka/ | 否定/許可。 |
| がめつい | がめつい | けちな | https://goiryoku-kitaeru.com/hougen/oosaka/ | 全国化注意。 |
| かんにん | かんにん | ごめん | https://goiryoku-kitaeru.com/hougen/oosaka/ | 謝罪表現。 |
| きしょくええ | きしょくええ | 気持ちがいい | https://goiryoku-kitaeru.com/hougen/oosaka/ | 感覚表現。 |
| ぐねる | ぐねる | くじく | https://goiryoku-kitaeru.com/hougen/oosaka/ | 動詞。 |
| けったいな | けったいな | 奇妙な | https://goiryoku-kitaeru.com/hougen/oosaka/ | 播州 seed `けったい` と近い。 |
| こすい | こすい | ずるい | https://goiryoku-kitaeru.com/hougen/oosaka/ | 形容詞。 |
| こそばい | こそばい | くすぐったい | https://goiryoku-kitaeru.com/hougen/oosaka/ | 原ページは後続語が連結しているため要手動確認。 |
| さぶい | さぶい | 寒い | https://goiryoku-kitaeru.com/hougen/oosaka/ | 形容詞。 |
| さぶいぼ | さぶいぼ | 鳥肌 | https://goiryoku-kitaeru.com/hougen/oosaka/ | 名詞。 |
| さら | さら | 新しい | https://goiryoku-kitaeru.com/hougen/oosaka/ | `サラピン` も候補。 |
| しゃあない | しゃあない | 仕方がない | https://goiryoku-kitaeru.com/hougen/oosaka/ | 慣用表現。 |
| しょうもなっ | しょうもなっ | くだらない | https://goiryoku-kitaeru.com/hougen/oosaka/ | `しょうもない` で登録するか要判定。 |
| すかたん | すかたん | あてはずれ・まぬけ | https://goiryoku-kitaeru.com/hougen/oosaka/ | 名詞。 |
| すきやねん | すきやねん | 好きなんだ | https://goiryoku-kitaeru.com/hougen/oosaka/ | フレーズ entry 候補。 |
| せや | せや | そうだ | https://goiryoku-kitaeru.com/hougen/oosaka/ | 判定表現。 |
| せわしない | せわしない | 忙しい | https://goiryoku-kitaeru.com/hougen/oosaka/ | 全国化注意。 |
| 炊いたん | たいたん | 煮物 | https://goiryoku-kitaeru.com/hougen/oosaka/ | 食事語。 |
| ちゃうちゃう | ちゃうちゃう | 違う違う | https://goiryoku-kitaeru.com/hougen/oosaka/ | フレーズ。 |
| ちゅうこっちゃ | ちゅうこっちゃ | そういうことだ | https://goiryoku-kitaeru.com/hougen/oosaka/ | フレーズ。 |
| でぼちん | でぼちん | おでこ | https://goiryoku-kitaeru.com/hougen/oosaka/ | 名詞。 |
| てれこ | てれこ | 入れ違い | https://goiryoku-kitaeru.com/hougen/oosaka/ | 名詞。 |
| どない | どない | どんな・どのように | https://goiryoku-kitaeru.com/hougen/oosaka/ | 疑問語。 |
| なんぎや | なんぎや | 困難だ | https://goiryoku-kitaeru.com/hougen/oosaka/ | 形容動詞。 |
| なんでやねん | なんでやねん | どうしてなんだよ | https://goiryoku-kitaeru.com/hougen/oosaka/ | 定番フレーズ。 |
| 似おてる | におてる | 似合っている | https://goiryoku-kitaeru.com/hougen/oosaka/ | 表記正規化要。 |
| ひやこい | ひやこい | 冷たい | https://goiryoku-kitaeru.com/hougen/oosaka/ | 形容詞。 |
| べっぴんさん | べっぴんさん | 美人 | https://goiryoku-kitaeru.com/hougen/oosaka/ | 名詞。 |
| ほかす | ほかす | 捨てる | https://goiryoku-kitaeru.com/hougen/oosaka/ | 愛知/徳島 seed に同語あり。 |
| ほんま | ほんま | 本当 | https://goiryoku-kitaeru.com/hougen/oosaka/ | 岡山 seed に同語あり。 |
| めっちゃ | めっちゃ | とても・非常に | https://goiryoku-kitaeru.com/hougen/oosaka/ | 全国化注意。 |
| めばちこ | めばちこ | ものもらい | https://goiryoku-kitaeru.com/hougen/oosaka/ | 原ページ表記は「もらいもの」だが一般には「ものもらい」。要再確認。 |
| ややこ | ややこ | 赤ん坊 | https://goiryoku-kitaeru.com/hougen/oosaka/ | 名詞。 |
| よーさん | よーさん | たくさん | https://goiryoku-kitaeru.com/hougen/oosaka/ | 播州 `よーけ` と近い。 |
| わい | わい | 私 | https://goiryoku-kitaeru.com/hougen/oosaka/ | 鹿児島/和歌山 seed に同語あり。 |

### 関西: サブエージェント追加候補

Source: OSAKA INFO / Wikibooks / 京都民報 / 方言ドットコム / 播州弁辞典。既存 seed と上表の重複は除外。

| region_path | headword | reading | meaning | source_url | note |
|---|---|---|---|---|---|
| `jp.osaka` | まいど | まいど | 商人・営業の挨拶 | https://osaka-info.jp/osaka/basic/osaka-dialect/ | 観光局公式。 |
| `jp.osaka` | ぬくい | ぬくい | 暖かい・温かい | https://ja.wikibooks.org/wiki/大阪弁/語彙 | CC BY-SA 系。 |
| `jp.osaka` | つぶれる | つぶれる | 壊れる | https://ja.wikibooks.org/wiki/大阪弁/語彙 | 香川 seed に同語あり。大阪候補。 |
| `jp.kyoto` | あがる | あがる | 京都市内で北へ行く | https://massan.jp/kyoto/ | 京都の道案内語。 |
| `jp.kyoto` | あじない | あじない | 食べ物がおいしくない | https://massan.jp/kyoto/ | 食味表現。 |
| `jp.kyoto` | あて | あて | 私 | https://massan.jp/kyoto/ | 高知 seed に同語あり。 |
| `jp.kyoto` | いか | いか | 凧 | https://massan.jp/kyoto/ | 名詞。 |
| `jp.kyoto` | いきし | いきし | 行きがけ | https://massan.jp/kyoto/ | 大阪 `行きしな` と関連。 |
| `jp.kyoto` | いちびる | いちびる | 調子に乗ってふざける | https://www.kyoto-minpo.net/html/naruhodo-kyoto/kotoba/index.html | 大阪候補にもあり。 |
| `jp.kyoto` | いらう | いらう | 触る・いじる | https://massan.jp/kyoto/ | 大阪候補にもあり。 |
| `jp.kyoto` | おいど | おいど | おしり | https://onodera-lifesupport.com/portal/wp/wp-content/uploads/2019/01/7%EF%BC%8E%E4%BA%AC%E9%83%BD%E5%BA%9C.pdf | 簡易一覧。 |
| `jp.kyoto` | おいでやす | おいでやす | いらっしゃい | https://onodera-lifesupport.com/portal/wp/wp-content/uploads/2019/01/7%EF%BC%8E%E4%BA%AC%E9%83%BD%E5%BA%9C.pdf | 挨拶。 |
| `jp.kyoto` | かなん | かなん | いやだ・困る | https://massan.jp/kyoto/ | 感情表現。 |
| `jp.kyoto` | きばる | きばる | がんばる・奮闘する | https://massan.jp/kyoto/ | 大分 seed に同語あり。京都候補。 |
| `jp.kyoto` | ぐつわるい | ぐつわるい | 都合が悪い | https://massan.jp/kyoto/ | 状態表現。 |
| `jp.kyoto` | けなるい | けなるい | うらやましい | https://www.kyoto-minpo.net/html/naruhodo-kyoto/kotoba/index.html | 京ことば。 |
| `jp.kyoto` | しまつする | しまつする | 節約する・倹約する | https://massan.jp/kyoto/ | 動詞。 |
| `jp.kyoto` | しんきくさい | しんきくさい | もどかしい・じれったい | https://www.kyoto-minpo.net/html/naruhodo-kyoto/kotoba/index.html | 感情表現。 |
| `jp.kyoto` | だんない | だんない | 差し支えない・大丈夫 | https://www.kyoto-minpo.net/html/naruhodo-kyoto/kotoba/index.html | 応答表現。 |
| `jp.hyogo.banshu` | あいさ | あいさ | 時々・途中・あいだ | https://www.bansyuuben.jp/50on/a.html | 長野 seed に同語あり。播州候補。 |
| `jp.hyogo.banshu` | あいまこいま | あいまこいま | あいだあいだ・要所要所 | https://www.bansyuuben.jp/50on/a.html | 副詞。 |
| `jp.hyogo.banshu` | うっとこ | うっとこ | 私の家・我が家 | https://www.bansyuuben.jp/50on/u.html | 大阪候補にもあり。 |
| `jp.hyogo.banshu` | うろがくる | うろがくる | うろたえる | https://www.bansyuuben.jp/50on/u.html | 動詞。 |
| `jp.hyogo.banshu` | おしたる | おしたる | 教える・教えてあげる | https://www.bansyuuben.jp/50on/o.html | 動詞。 |
| `jp.hyogo.banshu` | おじゃみ | おじゃみ | お手玉 | https://www.bansyuuben.jp/50on/o.html | 静岡 seed に同語あり。 |
| `jp.hyogo.banshu` | おってかー | おってかー | いらっしゃいますか・在宅ですか | https://www.bansyuuben.jp/50on/o.html | 訪問表現。 |
| `jp.hyogo.banshu` | おとろし | おとろし | 怖い・恐ろしい | https://www.bansyuuben.jp/50on/o.html | 形容詞。 |
| `jp.hyogo.banshu` | かえこと | かえこと | 交換・取り替え | https://www.bansyuuben.jp/50on/ka.html | 名詞。 |
| `jp.hyogo.banshu` | がさつい | がさつい | あつかましい・乱雑・乱暴 | https://www.bansyuuben.jp/50on/ka.html | 評価語。 |
| `jp.hyogo.banshu` | きづつない | きづつない | 気詰まり・恐縮・気が重い | https://www.bansyuuben.jp/50on/ki.html | 感情表現。 |
| `jp.hyogo.banshu` | ごーわく | ごーわく | 腹が立つ・むかつく | https://www.bansyuuben.jp/50on/ko.html | 感情表現。 |
| `jp.hyogo.banshu` | ごじゃ | ごじゃ | 無茶・無理・嘘・はったり | https://www.bansyuuben.jp/50on/ko.html | 評価語。 |
| `jp.hyogo.banshu` | さっちょこ | さっちょこ | 逆立ち | https://www.bansyuuben.jp/50on/sa.html | 名詞。 |
| `jp.hyogo.banshu` | さらっぴん | さらっぴん | 新品 | https://www.bansyuuben.jp/50on/sa.html | 大阪 `さら` と関連。 |
| `jp.hyogo.banshu` | べっちょない | べっちょない | 大丈夫・問題ない | https://www.bansyuuben.jp/50on/he.html | 応答表現。 |
| `jp.hyogo.banshu` | めげる | めげる | 壊れる・故障する | https://www.bansyuuben.jp/50on/me.html | 広島 seed に同語あり。播州候補。 |

## 追加候補: 北海道 `jp.hokkaido`

Source: 北海道方言・北海道弁辞典、北海道系まとめ。既存 `あずましい`, `いずい`, `かい`, `けっぱる`, `したっけ`, `しょ`, `だべ`, `とうきび`, `なまら`, `わや` は除外。

| headword | reading | meaning | source_url | note |
|---|---|---|---|---|
| めんこい | めんこい | かわいい | https://www.iju-hs.com/hokkaido-dialect/ | 既存は福島/宮城。北海道候補として追加可。 |
| しゃっこい | しゃっこい | 冷たい | https://hokkaidolikers.com/archives/37645 | 北海道でよく知られる候補。 |
| ばくる | ばくる | 交換する | https://www.reddit.com/r/Hokkaido/comments/1rzj7ps/i_will_answer_your_questions/ | Reddit は community。別ソース確認推奨。 |
| ちょす | ちょす | 触る・いじる | https://www.reddit.com/r/Hokkaido/comments/1rzj7ps/i_will_answer_your_questions/ | Reddit は補助。辞典確認が必要。 |
| なんも | なんも | なんてことない・大丈夫 | https://www.reddit.com/r/Hokkaido/comments/1rzj7ps/i_will_answer_your_questions/ | 補助候補。 |
| しばれる | しばれる | 凍えるほど寒い | https://www.reddit.com/r/japanlife/comments/1ocd72f | 津軽 seed に同語あり。北海道にも採用可。 |
| るいべ | るいべ | 鮭を凍らせたもの | https://hokkaido-hougen.com/ | トップカテゴリで確認。料理語。 |
| ごめ | ごめ | かもめ | https://hokkaido-hougen.com/ | 動物語。 |
| べご | べご | 牛 | https://hokkaido-hougen.com/ | 秋田 seed に同語あり。 |
| あが | あが | 赤ん坊 | https://hokkaido-hougen.com/ | 家族/人。 |
| あじゃ | あじゃ | 母 | https://hokkaido-hougen.com/ | 家族語。 |
| あっぱ | あっぱ | かあさん | https://hokkaido-hougen.com/ | 家族語。 |
| おとんぼ | おとんぼ | 末っ子 | https://hokkaido-hougen.com/ | 家族語。 |
| じゃっぱじる | じゃっぱじる | 雑魚を入れた塩汁 | https://hokkaido-hougen.com/ | 料理語。 |
| がこ | がこ | 漬物 | https://hokkaido-hougen.com/ | 料理語。 |
| あぶらこ | あぶらこ | アイナメ | https://hokkaido-hougen.com/ | 魚名。 |

### 北海道: サブエージェント追加候補

Source: HokkaidoDo / 北海道Likers。既存 seed と上表の重複は除外。

| headword | reading | meaning | source_url | note |
|---|---|---|---|---|
| あおたん | あおたん | あざ | https://hokkaidodo.jp/dialect/ | 静岡 seed に同語あり。北海道候補。 |
| あきあじ | あきあじ | 鮭 | https://hokkaidodo.jp/dialect/ | 魚名。 |
| あずる | あずる | 冬道で車がスリップして動かない・焦る | https://hokkaidodo.jp/dialect/ | 雪国語彙。 |
| うるかす | うるかす | 水に浸してふやかす | https://hokkaidolikers.com/archives/41709 | 生活語。 |
| おっちゃんこ | おっちゃんこ | 座る | https://hokkaidolikers.com/archives/41709 | 子ども向け語。 |
| がす | がす | 霧 | https://hokkaidodo.jp/dialect/ | 天候語。 |
| かまかす | かまかす | かきまぜる | https://hokkaidodo.jp/dialect/ | 動詞。 |
| ごしょいも | ごしょいも | じゃがいも | https://hokkaidodo.jp/dialect/ | 食材語。 |
| げっぱ | げっぱ | 最下位・ビリ | https://hokkaidolikers.com/archives/41709 | 名詞。 |
| じょっぴんかる | じょっぴんかる | 鍵をかける・戸締まりする | https://hokkaidolikers.com/archives/41709 | 動詞句。 |
| つっぺ | つっぺ | 栓 | https://hokkaidolikers.com/archives/41709 | 名詞。 |
| ぼっこ | ぼっこ | 棒・短めの棒 | https://hokkaidolikers.com/archives/41709 | 愛知三河 seed に同語あり。 |
| ゆきはね | ゆきはね | 除雪 | https://hokkaidodo.jp/dialect/ | 雪国語彙。 |
| リラびえ | りらびえ | リラが咲くころの寒さ | https://hokkaidodo.jp/dialect/ | 季節語。表記をかなに寄せるか要判定。 |

## 追加候補: 仙台/宮城 `jp.miyagi.sendai`

Source: 仙台弁こけし。既存 `あんべぇ`, `いずい`, `おらい`, `さ`, `だっちゃ`, `ば`, `べ`, `べこ`, `めんこい`, `わらすこ` は除外。

| headword | reading | meaning | source_url | note |
|---|---|---|---|---|
| いぎなり | いぎなり | とても・すごく | https://kokesu.com/sendaiben/ | ミニ辞典で確認。 |
| しばれる | しばれる | とても寒い | https://kokesu.com/sendaiben/ | 津軽/北海道にも候補。 |
| けさいん | けさいん | ください | https://kokesu.com/sendaiben/ | `してけさいん` など句で使う。 |
| ござりす | ござりす | ございます | https://kokesu.com/sendaiben/ | 丁寧表現。 |
| おばんでがす | おばんでがす | こんばんは | https://kokesu.com/sendaiben/ | 挨拶。 |
| んでまず | んでまず | ではまた | https://kokesu.com/sendaiben/ | 別れの挨拶。 |
| いぐすか | いぐすか | 行きますか | https://kokesu.com/sendaiben/ | フレーズ。 |
| なんだべ | なんだべ | あらまあ・なんだろう | https://kokesu.com/sendaiben/ | 感嘆/疑問。 |
| がおった | がおった | 疲れた・気が滅入った | https://kokesu.com/sendaiben/ | 状態表現。 |
| なにすや | なにすや | なんだと | https://kokesu.com/sendaiben/ | 感嘆。 |
| んだ | んだ | そうだ | https://kokesu.com/sendaiben/ | 山形 seed に同語あり。宮城にも採用可。 |
| かしぇろ | かしぇろ | 食べさせて | https://kokesu.com/sendaiben/ | 動詞形。 |
| まがしぇろ | まがしぇろ | まかせて | https://kokesu.com/sendaiben/ | 動詞形。 |
| いがった | いがった | よかった | https://kokesu.com/sendaiben/ | 形容詞過去。 |
| しょっぴぐ | しょっぴぐ | 逮捕する・引っぱる | https://kokesu.com/sendaiben/ | 俗語性あり。 |
| すかねごだ | すかねごだ | 気に入らない | https://kokesu.com/sendaiben/ | 感情表現。 |
| のむべ | のむべ | 飲もう | https://kokesu.com/sendaiben/ | 勧誘表現。 |
| いぐすぺ | いぐすぺ | 行こう | https://kokesu.com/sendaiben/ | 勧誘表現。 |
| いっちゃ | いっちゃ | いいよ | https://kokesu.com/sendaiben/ | 許可/応答。 |
| けろ | けろ | ちょうだい | https://kokesu.com/sendaiben/ | 依頼表現。 |
| んだでば | んだでば | そうだってば | https://kokesu.com/sendaiben/ | 強調。 |
| わがりすた | わがりすた | わかった | https://kokesu.com/sendaiben/ | 応答。 |
| ほどまる | ほどまる | あたたまる | https://kokesu.com/sendaiben/ | 動詞。 |
| ひまだれ | ひまだれ | 時間をもてあますこと | https://kokesu.com/sendaiben/ | 名詞。 |
| きどころ寝 | きどころね | 服を着たまま寝ること | https://kokesu.com/sendaiben/ | 名詞。 |
| あいや | あいや | あら・驚いた | https://kokesu.com/sendaiben/ | 感嘆。 |
| うろらうろら | うろらうろら | うろうろ | https://kokesu.com/sendaiben/ | 副詞。 |
| えらすぐねぇ | えらすぐねぇ | かわいげがない | https://kokesu.com/sendaiben/ | 形容。 |
| かばねやみ | かばねやみ | なまけもの・面倒くさがり | https://kokesu.com/sendaiben/ | 人を指す語。 |
| きかねごだ | きかねごだ | わがままだ | https://kokesu.com/sendaiben/ | 評価表現。 |
| ぐずらもずら | ぐずらもずら | ぐずぐずしている様子 | https://kokesu.com/sendaiben/ | 副詞。 |
| けるべ | けるべ | 帰ろう | https://kokesu.com/sendaiben/ | 勧誘表現。 |
| さっぱどする | さっぱどする | さっぱりする | https://kokesu.com/sendaiben/ | 動詞。 |
| じゃす | じゃす | ジャージ | https://kokesu.com/sendaiben/ | 名詞。 |
| せまこい | せまこい | 狭い | https://kokesu.com/sendaiben/ | 形容詞。 |
| つまかけ | つまかけ | つまずく | https://kokesu.com/sendaiben/ | 動詞。 |
| でろだらげ | でろだらげ | 泥だらけ | https://kokesu.com/sendaiben/ | 状態表現。 |
| なじょすっぺ | なじょすっぺ | どうしよう | https://kokesu.com/sendaiben/ | 困惑表現。 |
| ぬだぐる | ぬだぐる | 塗りつける・厚化粧する | https://kokesu.com/sendaiben/ | 動詞。 |
| はかはかする | はかはかする | 胸がドキドキする | https://kokesu.com/sendaiben/ | 感情/身体表現。 |
| びっくらこぐ | びっくらこぐ | びっくりする | https://kokesu.com/sendaiben/ | 動詞。 |
| ふぐすい | ふぐすい | 裕福 | https://kokesu.com/sendaiben/ | 状態表現。 |
| もじゃぐる | もじゃぐる | 紙などを揉んでくしゃくしゃにする | https://kokesu.com/sendaiben/ | 動詞。 |
| やんだ | やんだ | いやだ | https://kokesu.com/sendaiben/ | 感情表現。 |

## 追加候補: 津軽 `jp.aomori.tsugaru`

Source: 五所川原市観光協会、つがる市 PDF、関連自治体/学術資料。既存 20 語は除外。現時点は候補探索の入口。

| headword | reading | meaning | source_url | note |
|---|---|---|---|---|
| か | か | どうぞ・召し上がって | https://www.city.tsugaru.aomori.jp/material/files/group/41/tsugaru_ziten06.pdf | PDF 内に難解フレーズとして確認。短語のため同音異義注意。 |
| け | け | どうぞ・召し上がって | https://www.city.tsugaru.aomori.jp/material/files/group/41/tsugaru_ziten06.pdf | `か, け` と併記。既存宮崎/富山 `け` あり。 |
| く | く | いただきます | https://www.city.tsugaru.aomori.jp/material/files/group/41/tsugaru_ziten06.pdf | PDF 内に難解フレーズとして確認。 |
| つがる | つがる | 空返事をする | https://www.city.tsugaru.aomori.jp/material/files/group/41/tsugaru_ziten06.pdf | 地域 PR の新解釈語。通常方言としては要判定。 |
| くにざけゃぁ | くにざけゃぁ | 国境 | https://www.pref.osaka.lg.jp/documents/9099/jjwb-211-215.pdf | 大阪府教材の津軽訳例。seed 候補には弱い。 |
| なげゃ | なげゃ | 長い | https://www.pref.osaka.lg.jp/documents/9099/jjwb-211-215.pdf | 同上。 |
| 良がべ | いがべ | 良いだろう | https://www.pref.osaka.lg.jp/documents/9099/jjwb-211-215.pdf | 同上。表記要判定。 |
| 白ぱちけで | しらぱちけで | 白くなって | https://www.pref.osaka.lg.jp/documents/9099/jjwb-211-215.pdf | 同上。活用形のため entry 化には注意。 |

### 津軽: サブエージェント追加候補

Source: 青森県観光国際交流機構 / 黒石観光協会。既存 seed と上表の重複は除外。黒石観光協会は無断転載・再利用不可のため、取り込み時は語・意味・リンクの事実ポインタに留める。

| headword | reading | meaning | source_url | note |
|---|---|---|---|---|
| わ | わ | 私・僕 | https://www.kokusai-koryu.jp/seikatujyouhou/seikatujyouhou-2371/ | 短語のため同音異義注意。 |
| な | な | あなた | https://www.kokusai-koryu.jp/seikatujyouhou/seikatujyouhou-2371/ | 短語のため同音異義注意。 |
| おど | おど | お父さん | https://www.kokusai-koryu.jp/seikatujyouhou/seikatujyouhou-2371/ | 秋田 seed に同語あり。津軽候補。 |
| じっこ | じっこ | おじいさん | https://www.kokusai-koryu.jp/seikatujyouhou/seikatujyouhou-2371/ | 家族語。 |
| ばっこ | ばっこ | おばあさん | https://www.kokusai-koryu.jp/seikatujyouhou/seikatujyouhou-2371/ | 家族語。 |
| わらし | わらし | 子供 | https://www.kokusai-koryu.jp/seikatujyouhou/seikatujyouhou-2371/ | 秋田 seed に同語あり。津軽候補。 |
| けやぐ | けやぐ | 友達 | https://www.kokusai-koryu.jp/seikatujyouhou/seikatujyouhou-2371/ | 人間関係語。 |
| じゃんぼ | じゃんぼ | 髪の毛 | https://www.kokusai-koryu.jp/seikatujyouhou/seikatujyouhou-2371/ | 茨城 seed に同語あり。津軽候補。 |
| まなぐ | まなぐ | 目 | https://www.kokusai-koryu.jp/seikatujyouhou/seikatujyouhou-2371/ | 秋田 seed に同語あり。津軽候補。 |
| へっちょ | へっちょ | へそ | https://www.kokusai-koryu.jp/seikatujyouhou/seikatujyouhou-2371/ | 身体語彙。 |
| あさぐ | あさぐ | 歩く | https://kuroishi.or.jp/about-2/welcome_jun/tugaruben/action | 動詞。 |
| おたる | おたる | 疲れてしまう | https://kuroishi.or.jp/about-2/welcome_jun/tugaruben/action | 動詞。 |
| かだる | かだる | 参加する | https://kuroishi.or.jp/about-2/welcome_jun/tugaruben/action | 動詞。 |
| こちょがす | こちょがす | くすぐる | https://kuroishi.or.jp/about-2/welcome_jun/tugaruben/action | 動詞。 |
| ねっぱる | ねっぱる | くっつく | https://kuroishi.or.jp/about-2/welcome_jun/tugaruben/action | 福島 seed に同語あり。津軽候補。 |
| ふたぐ | ふたぐ | 叩く | https://kuroishi.or.jp/about-2/welcome_jun/tugaruben/action | 動詞。 |
| めぐせぇ | めぐせぇ | 恥ずかしい | https://kuroishi.or.jp/about-2/welcome_jun/tugaruben/expressions | 感情表現。 |
| かに | かに | ごめん | https://kuroishi.or.jp/about-2/welcome_jun/tugaruben/expressions | 謝罪表現。 |
| じゃわめぐ | じゃわめぐ | ぞくぞくする | https://kuroishi.or.jp/about-2/welcome_jun/tugaruben/expressions | 身体/感情表現。 |

## 統合メモ

- サブエージェント 3 本の返却分は合計 132 件規模。既存 seed と重複する同一地域語は除外済み。
- この台帳には、こちらで先に拾った候補とサブエージェント候補を統合したため、同じ headword の別ソースは note で扱う。
- 優先度は `CC BY/CC BY-SA/公共機関 > 自治体/観光協会 > 民間辞典 > SNS/Reddit`。
- アニメ・漫画由来の作品セリフは採用しない。作品名は需要確認・語の存在確認の補助に限る。

## 次にやる取り込み作業

1. 各ソースから候補を機械抽出する。
   - あじまぁ: 五十音ページ単位で `li > a` の語と意味を抽出。
   - 北海道辞典: 五十音ページとカテゴリページから抽出。
   - 仙台弁こけし: 表の `仙台弁 / 意味` を抽出し、例文は保持しない。
   - 大阪: 五十音一覧から抽出し、一般語化した語を `needs_review` にする。
2. 既存 seed と照合する。
   - 同一 `region_path + headword` は除外。
   - 同一 `headword` の別地域候補は `cross_region_duplicate: true` を付ける。
3. 追加 region が必要なものを分離する。
   - `jp.okinawa.miyako` など、原典に宮古・八重山などの地域注記がある語。
   - 未登録県: `jp.tottori`, `jp.shimane`, `jp.nara`, `jp.shiga`, `jp.mie`, `jp.gifu`, `jp.niigata`, `jp.iwate`, `jp.chiba`, `jp.saitama`, `jp.tokyo`, `jp.kanagawa`, `jp.fukui` など。
4. seed JSON 化は地域別に分ける。
   - オープンライセンスでない出典は `kind: "community"`, `reliability: "unverified"`。
   - source はファイル単位に 1 つなので、出典が混ざる場合は `jp.okinawa.ajima.json` のように source ごとにファイル分割する。
