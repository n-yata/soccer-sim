# データ定義書 — 保存データと静的データ

> 本プロダクトは RDB を持たないため、テーブル定義書の代わりに、端末内の保存データ（JSON・ConfigFile）と、アプリに
> 同梱する静的データ（JSON）の項目を定義する（`functional-overview.md`「データモデル」の方針）。
>
> | 事項 | 正本 |
> |---|---|
> | エンティティ・区分値・ER図・確定事項（日時の基準・削除・一意性） | `functional-overview.md`「データモデル」 |
> | ファイル名・保存先・JSON の共通の形・書き込み手順・破損と新しい版の扱い・形式の変換 | `component-design.md` §4.3 |
> | 静的データのファイルの一覧 | `repository-structure.md`「game/content/」 |
> | 区分値の取りうる値 | `functional-overview.md`「エンティティと区分値」（本書では型名だけを書く） |
>
> 本書は、各ファイルの**項目ごとの型・必須・値の範囲**を定める。読み込み時の検証（NFR-09・NFR-17）は本書の表を
> そのまま検査の根拠にする。

## 1. 表の書き方

| 列 | 意味 |
|---|---|
| キー | JSON のキー（snake_case）。入れ子は `.` でつなぐ。配列の要素は `[]` |
| 型 | `string`・`int`・`float`・`bool`・`object`・`array`、区分値は `enum<型名>`（値は名前の文字列）、エリアは `area`（`"M-L1"` の形）、日時は `datetime`（端末のローカル時刻の ISO 8601、タイムゾーンなし。例 `2026-10-17T19:30:12`） |
| 必須 | ○＝必須、△＝条件付き（条件は備考）、－＝任意。`null` を許すものは型に `|null` |
| 範囲・制約 | 値の範囲。これを外れたら「破損」（保存データ）または検証の誤り（静的データ） |

共通の制約:
- 知らないキーがあっても破損にしない（新しい版で増えたキーを無視できるように）。ただし `format_version` が今の版より
  新しいファイルは「新しい版」として扱う（`component-design.md` §4.3）
- 文字列の長さの上限は、特に書かない限り 2000 文字（改変されたファイルへの備え）

## 2. 端末内の保存データ（`user://`）

### 2.1 中断データ `suspended_match.json`（形式の版 1）

| キー | 型 | 必須 | 範囲・制約 | 備考（ER図の対応） |
|---|---|:--:|---|---|
| `format_version` | `int` | ○ | 1 | — |
| `match` | `object` | ○ | — | 試合 |
| `match.match_id` | `string` | ○ | `^\d{8}-\d{6}-\d{4}$` | 試合ID（`component-design.md` §4.3） |
| `match.status` | `enum<MatchStatus>` | ○ | — | 状態 |
| `match.stage` | `enum<MatchStage>` | ○ | — | 進行段階 |
| `match.half` | `int` | ○ | 1〜2 | ハーフ |
| `match.turn_number` | `int` | ○ | 1〜1ハーフのターン数（`FINISHED` と終了処理待ちでは ターン数＋1 まで） | ターン番号 |
| `match.turn_kind` | `enum<TurnKind>` | ○ | — | ターン種別 |
| `match.possession` | `enum<TeamSide>` | ○ | — | ボール保持側 |
| `match.ball_area` | `area` | ○ | — | ボール位置（保持側の視点） |
| `match.first_half_kickoff` | `enum<TeamSide>` | ○ | — | 前半キックオフ側 |
| `match.score.HOME` / `match.score.AWAY` | `int` | ○ | 0〜99 | 利用者得点／CPU得点 |
| `match.setups.HOME` / `.AWAY` | `object` | ○ | — | 両者の陣形と方式 |
| `match.setups.*.formation_id` | `string` | ○ | `formations.json` に存在する ID | — |
| `match.setups.*.defense` | `enum<DefenseStyle>` | ○ | — | — |
| `match.setups.*.attack` | `enum<AttackStyle>` | ○ | — | — |
| `match.players.HOME` / `.AWAY` | `array` | ○ | ちょうど10件。`player_id` は陣形の GK 以外の選手 ID と1対1 | 選手単位の配置状態 |
| `match.players.*[].player_id` | `string` | ○ | — | — |
| `match.players.*[].base_area` | `area` | ○ | 陣形の座標から導出したエリアと一致（アルゴリズム1） | — |
| `match.players.*[].fixed_area` | `area|null` | ○ | — | 固定されていなければ `null` |
| `match.transition_origin` | `object|null` | ○ | `turn_kind` が `TRANSITION` のときだけ `null` でない | 直前の配置（`attacker`・`defender` に、それぞれ `players` と同じ形の10件） |
| `match.started_at` | `datetime` | ○ | — | 開始日時 |
| `match.turn_records` | `array` | ○ | 0〜（1ハーフのターン数 × 2）件 | ターン記録（次表） |

**ターン記録** `match.turn_records[]`（ER図「ターン記録」）

| キー | 型 | 必須 | 範囲・制約 | 備考 |
|---|---|:--:|---|---|
| `seq` | `int` | ○ | 1 から連番 | 通し番号 |
| `half` / `turn_number` | `int` | ○ | 試合と同じ範囲 | ハーフ・ターン番号 |
| `turn_kind` | `enum<TurnKind>` | ○ | — | — |
| `attacker` | `enum<TeamSide>` | ○ | — | 攻撃側（トランジションでは奪取側） |
| `setups` | `object` | ○ | 試合の `setups` と同じ形 | その時点の両者の陣形と方式 |
| `choices.HOME` / `.AWAY` | `object` | ○ | — | 両者の選択 |
| `choices.*.family` | `enum<ChoiceFamily>` | ○ | — | — |
| `choices.*.action` | `string` | ○ | `family` に対応する区分値の名前（`SHORT_PASS` など） | — |
| `choices.*.target` | `area|null` | ○ | 運ぶ先を持つ手のときだけ `null` でない | 攻撃側の視点 |
| `ball_before` / `ball_after` | `area` | ○ | — | 判定前・判定後のボール位置（攻撃側の視点） |
| `players_before` / `players_at_judgement` | `object` | ○ | `HOME`・`AWAY` に `players` と同じ形の10件 | 判定前・判定時の両者の配置（選手単位） |
| `movements` | `array` | ○ | 0〜40件 | 選手の動き |
| `movements[].side` | `enum<TeamSide>` | ○ | — | — |
| `movements[].player_id` | `string` | ○ | その側の選手 ID | — |
| `movements[].from` / `.to` | `area` | ○ | — | 動いた選手のチーム自身の視点 |
| `movements[].reason` | `enum<MovementReason>` | ○ | — | — |
| `judge` | `object|null` | ○ | `outcome` が `NO_CONTEST` のときだけ `null` | 判定の内訳 |
| `judge.compare_area` | `area` | ○ | — | 比較エリア（攻撃側の視点。即時奪回×保持では奪ったエリア） |
| `judge.attacker_count` / `judge.defender_count` | `int` | ○ | 0〜10（即時奪回×保持は周辺の合計で 0〜10） | 攻撃側人数・守備側人数 |
| `judge.cover` | `enum<CoverKind>` | ○ | — | カバーの有無 |
| `judge.read` | `enum<ReadKind>` | ○ | — | 守備の読みの段階（ぴったり・隣・外れ。アルゴリズム5。トランジションは `NONE`）。2026-10-24 に追加 |
| `outcome` | `enum<TurnOutcome>` | ○ | — | ターン結果 |

### 2.2 戦績 `match_records.json`（形式の版 1）

| キー | 型 | 必須 | 範囲・制約 | 備考（ER図「戦績」） |
|---|---|:--:|---|---|
| `format_version` | `int` | ○ | 1 | — |
| `records` | `array` | ○ | 0〜3,000件。`match_id` は重複しない | 1件はふつう約 1KB、推移の多い試合で最大約 4KB。件数の上限か、書き込み後の大きさ 4MB を超えるなら、古いものから捨てて追記する（`RecordStore.append`）。読み込みの上限（5MB）には届かない。通算（`totals()`）は保持している戦績から数える |
| `records[].record_id` | `string` | ○ | `match_id` と同じ値 | 戦績ID（試合ごとに1件のため試合 ID を使う） |
| `records[].match_id` | `string` | ○ | 試合ID の形 | — |
| `records[].finished_at` | `datetime` | ○ | — | 終了日時 |
| `records[].score_user` / `score_cpu` | `int` | ○ | 0〜99 | 利用者得点・CPU得点 |
| `records[].result` | `enum<MatchResult>` | ○ | スコアと一致すること | 勝敗（利用者から見た値） |
| `records[].timeline` | `array` | ○ | 1〜（1ハーフのターン数 × 2 ＋ 2）件 | 陣形と方式の推移 |
| `records[].timeline[].half` / `.from_turn` | `int` | ○ | — | その陣形・方式になったハーフとターン |
| `records[].timeline[].user` / `.cpu` | `object` | ○ | 試合の `setups.*` と同じ形 | — |

### 2.3 回答結果 `quiz_answers.json`（形式の版 1）

| キー | 型 | 必須 | 範囲・制約 | 備考（ER図「回答結果」） |
|---|---|:--:|---|---|
| `format_version` | `int` | ○ | 1 | — |
| `answers` | `array` | ○ | 0〜30,000件 | 回答の順に追記する。上限に達したら古いものから捨てて追記する（正答状況は問題ごとの最新の回答で数えるため、古い回答を捨てても実用上は変わらない。ある問題の回答がすべて捨てられたときだけ、その問題は未回答に戻る） |
| `answers[].question_id` | `string` | ○ | — | 問題ID。`quiz.json` に無い ID（問題を削除した後の古い回答）は破損にせず、集計から外す |
| `answers[].correct` | `bool` | ○ | — | 正誤 |
| `answers[].answered_at` | `datetime` | ○ | — | 回答日時 |

正答状況の数え方（問題ごとの最新の回答で数える）は [`screen-09-quiz.md`](../screen/screen-09-quiz.md)「正答状況の数え方」。

### 2.4 設定 `settings.cfg`（ConfigFile。形式の版 1）

| セクション | キー | 型 | 範囲 | 初期値 | 備考（ER図の外。設定） |
|---|---|---|---|---|---|
| `meta` | `format_version` | `int` | 1 | 1 | — |
| `audio` | `bgm_volume` | `float` | 0.0〜1.0 | 0.7 | BGM 音量 |
| `audio` | `se_volume` | `float` | 0.0〜1.0 | 0.7 | 効果音音量 |
| `ui` | `show_hints` | `bool` | — | `true` | ヒント表示（FR-15 の初期値 ON） |
| `progress` | `tutorial_completed` | `bool` | — | `false` | チュートリアル完了フラグ |

- 1つのキーだけが範囲外・型違いのときは、そのキーだけを初期値にする（設定は他のデータと違い、キー単位で直せるため）。
  `format_version` が無い・読めないときは、ファイル全体を破損として扱う

## 3. 静的データ（`game/content/`。アプリに同梱）

すべてのファイルの最上位に `format_version`（`int`、1）を持たせる。ID は英数字と `-`・`_` だけ（`^[A-Za-z0-9_-]{1,40}$`）。
静的データの誤りは開発時の検証で見つける（`ContentRepository.validation_errors()`。NFR-17 の自動テスト）。

### 3.1 `formations.json`（陣形。フォーメーションラボから移植）

| キー | 型 | 必須 | 範囲・制約 | 備考 |
|---|---|:--:|---|---|
| `formations` | `array` | ○ | 4件（4-4-2・4-3-3・4-2-3-1・3-5-2） | — |
| `formations[].id` | `string` | ○ | 一意 | 例 `4-4-2` |
| `formations[].name` | `string` | ○ | 1〜20文字 | — |
| `formations[].description` | `string` | ○ | 1〜200文字 | — |
| `formations[].extra_tags` | `array<string>` | ○ | 0件以上 | 座標から導出できない特徴タグ（移植元の `extraTags`）。座標から導出するタグはアルゴリズム9 |
| `formations[].players` | `array` | ○ | 11件。GK はちょうど1件 | 選手配置 |
| `formations[].players[].id` | `string` | ○ | 全陣形で一意 | 例 `4-4-2-lb` |
| `formations[].players[].type` | `string` | ○ | `GK`・`DF`・`MF`・`FW` | ポジション種別 |
| `formations[].players[].label` | `string` | ○ | 1〜4文字 | 例 `LB` |
| `formations[].players[].number` | `int` | ○ | 1〜99。陣形の中で一意 | 背番号（作戦ボードの駒には描かない。3D 演出の表示用に持っていたが、3D 演出は 2026-10-23 にやめた。移植元には無いので本プロダクトで付ける） |
| `formations[].players[].x` / `.y` | `float` | ○ | 0〜100 | 座標（y が大きいほど相手ゴール側） |

検証: 4陣形の基本配置（アルゴリズム1）が `functional-overview.md` の表と一致すること（NFR-14 の判定例と同じテストで確かめる）。

### 3.2 `styles.json`（方式）

| キー | 型 | 必須 | 範囲・制約 | 備考 |
|---|---|:--:|---|---|
| `styles` | `array` | ○ | 4件（`ZONE`・`MAN`・`POSSESSION`・`COUNTER`） | — |
| `styles[].id` | `string` | ○ | 区分値の名前と同じ | — |
| `styles[].kind` | `string` | ○ | `DEFENSE`・`ATTACK` | — |
| `styles[].name` | `string` | ○ | 1〜20文字 | 例「ゾーン」 |
| `styles[].summary` / `.strengths` / `.weaknesses` | `string` | ○ | 1〜300文字 | 特徴・強み・弱み（FR-17） |
| `styles[].principle_ids` | `array<string>` | ○ | 1件以上。`principles.json` に存在する ID | 根拠の原則（NFR-17 ①） |
| `styles[].simplification_ids` | `array<string>` | ○ | 0件以上。`simplifications.json` に存在する ID | 「実戦では」を添える単純化 |

### 3.3 `matchup_rules.json`（噛み合わせルール）

| キー | 型 | 必須 | 範囲・制約 | 備考 |
|---|---|:--:|---|---|
| `rules` | `array` | ○ | 1件以上 | — |
| `rules[].id` | `string` | ○ | 一意 | ルールID |
| `rules[].kind` | `string` | ○ | `FORMATION`（陣形どうし）・`STYLE`（方式どうし） | — |
| `rules[].condition` | `object` | ○ | 下記 | 条件 |
| `rules[].condition.viewer_tags` / `.opponent_tags` | `array<string>` | △ | `kind` が `FORMATION` のとき。いずれかが1件以上 | 特徴タグの条件（移植元の考え方） |
| `rules[].condition.viewer_style` / `.opponent_style` | `string` | △ | `kind` が `STYLE` のとき。方式の ID | — |
| `rules[].text` | `string` | ○ | 1〜300文字 | 解説文 |
| `rules[].theme` | `string` | ○ | 1〜40文字 | テーマ（同一テーマから採用するのは1件。アルゴリズム9） |
| `rules[].principle_ids` | `array<string>` | ○ | 1件以上。`principles.json` に存在する ID | NFR-17 ① |
| `rules[].simplification_ids` | `array<string>` | ○ | 0件以上 | — |

### 3.4 `principles.json`・`simplifications.json`（カタログのアプリ内表示用）

| ファイル | キー | 型 | 必須 | 範囲・制約 |
|---|---|---|:--:|---|
| `principles.json` | `principles[].id` | `string` | ○ | `TP-NN`。`functional-overview.md`「戦術原則カタログ」と ID・件数が一致（NFR-17 ②） |
| | `principles[].name` / `.content` / `.source` | `string` | ○ | 表示用の文。`source` は「未確定」を許す |
| | `principles[].status` | `enum<PrincipleStatus>` | ○ | カタログの照合状態と一致 |
| `simplifications.json` | `simplifications[].id` | `string` | ○ | `SIM-NN`。「単純化カタログ」と ID・件数が一致（NFR-17 ②） |
| | `simplifications[].name` / `.in_game` / `.in_real` | `string` | ○ | 単純化・ゲームでの扱い・実戦では |

### 3.5 `quiz.json`（場面問題）

| キー | 型 | 必須 | 範囲・制約 | 備考 |
|---|---|:--:|---|---|
| `questions` | `array` | ○ | 各学習目標につき2件以上（FR-22） | 並び順が出題の順 |
| `questions[].id` | `string` | ○ | 一意 | 問題ID |
| `questions[].goal_id` | `string` | ○ | `LG-1`〜`LG-4` | 学習目標ID |
| `questions[].is_playtest_set` | `bool` | ○ | 各学習目標につき `true` がちょうど2件 | KPI の測定に使う8問（要件定義書 §1.5） |
| `questions[].scene` | `object` | ○ | — | 場面 |
| `questions[].scene.counts` | `object` | ○ | 15エリアのキー → `[自分, 相手]`。各チームの合計が10 | 利用者の視点 |
| `questions[].scene.ball` | `area` | ○ | — | — |
| `questions[].scene.user_styles` / `.opponent_styles` | `object` | ○ | `{defense, attack}` | — |
| `questions[].text` | `string` | ○ | 1〜200文字 | 問題文 |
| `questions[].choices` | `array` | ○ | 2〜4件 | 選択肢 |
| `questions[].choices[].id` / `.text` | `string` | ○ | `id` は問題の中で一意 | — |
| `questions[].answer` | `string` | ○ | `choices[].id` のどれか | 正解 |
| `questions[].explanation` | `string` | ○ | 1〜400文字 | 解説 |
| `questions[].principle_ids` | `array<string>` | ○ | 1件以上 | 根拠の原則 |

### 3.6 `tutorial.json`（チュートリアルの段階）

| キー | 型 | 必須 | 範囲・制約 | 備考 |
|---|---|:--:|---|---|
| `steps` | `array` | ○ | 1件以上。最後の1件だけが `SCOPE` | 並び順が段階の順 |
| `steps[].id` | `string` | ○ | 一意 | — |
| `steps[].kind` | `string` | ○ | `EXPLAIN`・`OPERATE`・`SCOPE` | 画面の動き（[`screen-08-tutorial.md`](../screen/screen-08-tutorial.md)） |
| `steps[].text` | `string` | ○ | 1〜300文字 | 説明文 |
| `steps[].setup` | `object` | △ | `kind` が `EXPLAIN`・`OPERATE` のとき | 盤面の初期状態 |
| `steps[].setup.home` / `.away` | `object` | △ | `{formation_id, defense, attack}` | 両者の陣形と方式 |
| `steps[].setup.turn_kind` / `.possession` / `.ball_area` | — | △ | 試合の同名の項目と同じ型 | — |
| `steps[].allowed_actions` | `array<string>` | △ | `kind` が `OPERATE` のとき1件以上。区分値の名前 | 利用者が選べる手（試合の規則で選べる手の部分集合） |
| `steps[].opponent_choice` | `object` | △ | `kind` が `OPERATE` のとき。ターン記録の `choices.*` と同じ形 | `ScriptedOpponent` が出す手（試合の規則で選べる手であること） |
| `steps[].covers` | `array<string>` | ○ | — | この段階で体験する要素（`PITCH`・`MATCHUP`・`PHASES`・`SIMULTANEOUS`・`STYLES`・`JUDGEMENT`・`SHOT`）。全段階を合わせて7要素すべてを含む（FR-12） |

## 4. 読み込み時の検証のまとめ

| データ | 範囲・制約に反したとき | 根拠 |
|---|---|---|
| 中断データ | 破損 → 削除（削除の時点④） | `functional-overview.md`「エラーハンドリング」 |
| 戦績・回答結果 | 破損 → 退避して初期状態 | 同上・`component-design.md` §4.3 |
| 設定 | キー単位で初期値（`format_version` が読めなければ全体を退避して初期状態） | 本書 §2.4 |
| 静的データ | 開発時の誤り（`validation_errors()` に出す。テストが失敗する） | NFR-17 |

ファイルの大きさの上限（5MB）と件数の上限は、本書の表の範囲に加えて `component-design.md` §4.3 で確かめる。
