# 設計

## 層ごとの構成

| 層 | ファイル | 役割 |
|---|---|---|
| ドメイン | `domain/simplification_def.gd`（`SimplificationDef`）・`domain/tutorial_step_def.gd`（`TutorialStepDef`） | 単純化1件・チュートリアルの段階1件 |
| ドメイン | `domain/content_catalog.gd` | `simplifications`・`tutorial_steps` を足す |
| ドメイン | `domain/match/match_rules.gd` | `create_scene(home, away, turn_kind, possession, ball_area, catalog)`（段階・場面問題の盤面） |
| ドメイン | `domain/move_options.gd` | `restricted_to(family, actions)`（段階で選べる手を絞った写し） |
| データ | `data/tutorial_content_reader.gd`（`TutorialContentReader`） | `simplifications.json`・`tutorial.json` の形と範囲を確かめて読む（`SaveDataReader` で項目を読む）。`ContentRepository` が呼ぶ |
| アプリ | `application/scripted_opponent.gd`（`ScriptedOpponent`） | 段階が決めた手を返す |
| アプリ | `MatchController.start_tutorial_step`・`App.new_tutorial_controller`・`LibraryService.tutorial_steps`／`simplifications` | — |
| UI | `ui/common/simplification_list.gd`（`SimplificationList`） | 単純化のカード（名前・ゲームでの扱い・実戦では）を2列で並べる |
| UI | `ui/screens/s08_tutorial/tutorial_screen.gd`（`TutorialScreen`） | S-08 |
| UI | `MatchBoardPanel`・`TitleScreen`・`MainShell` | 段階のための口（手の絞り込み・操作の可否・説明の置き場所・主ボタンを出さない形）、カードの位置、画面の登録 |

## 盤面の作り方（`MatchRules.create_scene`）

1. 両チームの選手を基本配置（アルゴリズム1）に置く（固定なし）
2. `turn_kind`・`possession`・`ball_area`（攻撃側＝ボールを持つ側の視点）を入れる
3. ボールを持つ側の最寄りの選手をボールの位置に立たせる（`MatchPositions.place_holder`。1ターン1マスの例外）
4. トランジションなら、その配置を起点（`transition_origin`）にする

キックオフの位置（自陣に縮めた陣形）は使わない（盤面全体の噛み合わせを見せるため）。

## チュートリアル用の MatchController

- `App.new_tutorial_controller()`: `MatchController.new(catalog, config, rng, ScriptedOpponent.new(), 何もしない画面の要求, …, store = null, user_data = null)`。
  保存の先・戦績の記録先を持たないので保存しない。画面の切り替えの要求は捨てる（チュートリアルの画面が自分で進める）
- `start_tutorial_step(step)`: `create_scene` で状態を作り、`_open` で置き換える。相手が `ScriptedOpponent` なら、その段階の相手の手を渡す
- チュートリアルの画面は `continue_after_reveal()` を呼ばない（次の段階は `start_tutorial_step` で作り直す）。
  後半の最終ターンにはならないので終了処理も起きない

## 静的データの検証

| 確かめること | どこで |
|---|---|
| 形・型・範囲（種類・文字数・手の名前・エリア・陣形の ID・最後だけが `SCOPE`・`EXPLAIN`／`OPERATE` に盤面がある・`OPERATE` に選べる手と相手の手がある） | `TutorialContentReader`（読み込み時。誤りはカタログを空にする） |
| 単純化の ID が `SIM-01` からの連番で、件数がカタログ（functional-overview.md）と同じ12件 | テスト |
| 各段階の盤面が作れ、選べる手が試合の規則で選べ、相手の手が選べる。7要素をすべて含む | テスト（`tests/content/tutorial_content_test.gd`） |

## 段階の案（`tutorial.json`）

| # | 種類 | 体験する要素 | 盤面 | 内容 |
|---|---|---|---|---|
| 1 | EXPLAIN | PITCH | 4-3-3 対 4-4-2、自分のボール `M1-C` | 5レーン×6列の30エリア、上が相手ゴール |
| 2 | EXPLAIN | MATCHUP | 同上 | エリアごとの人数と、数的優位・不利 |
| 3 | OPERATE | SIMULTANEOUS・JUDGEMENT | 同上 | ショートパスで前へ。相手も同時に守備の手を選ぶ。人数とカバーで判定 |
| 4 | OPERATE | JUDGEMENT | 4-3-3 対 4-4-2、相手のボール | 守備の手（プレス・カバー）で読む |
| 5 | EXPLAIN | STYLES | 同上（方式が違う） | ゾーン／マンツーマン、保持型／カウンター型で選手の動き方が変わる |
| 6 | OPERATE | PHASES | トランジション（自分が奪った側） | ポジティブトランジション: カウンターか保持か |
| 7 | OPERATE | PHASES | トランジション（自分が失った側） | ネガティブトランジション: 即時奪回かリトリートか |
| 8 | OPERATE | SHOT | 自分のボール、敵陣ゴール前 | ペナルティエリアからのシュート |
| 9 | SCOPE | — | — | 単純化の一覧 |

説明文は判定の結果を約束しない（選ぶ運ぶ先で結果が変わるため）。各段階の盤面と手はテストで確かめながら決める。

## 画面

- `MatchBoardPanel` に足すもの:
  - `bind(controller, show_next = true)`: 偽なら、判定理由を出したときに主ボタンを隠し、すぐ `turn_ready_to_leave` を出す
  - `set_options_filter(actions: Array[String])`: 空なら絞らない。手の名前（区分値）で絞り、ほかの手は選択不可にする
  - `set_interactive(enabled)`: 偽なら手のボタンと主ボタンを隠す（盤面だけ）
  - `side_top_slot()`・`side_bottom_slot()`: 操作の列の上端・下端に部品を置く入れ物（説明の吹き出しと「次へ」）
- `TutorialScreen`: ヘッダー（「やめる」・「チュートリアル N／M」・進み具合・局面のタグ・両者の選択の帯）、盤面（`MatchBoardPanel`）か単純化の一覧、確認ダイアログ
- タイトル: `tutorial_completed` でカードの置き場所を決める（未完了は KICK OFF の直前の大きなカード、完了後は小さなカードの最後。「はじめての方へ」とカードの説明を隠し、小さなカードを5列に）

## テスト

- `tests/domain/match/tutorial_scene_test.gd`: 盤面の作り方（基本配置・ボールの選手・トランジションの起点）・`MoveOptions.restricted_to`
- `tests/data/tutorial_content_reader_test.gd`: 形・範囲の誤り
- `tests/content/tutorial_content_test.gd`: 同梱データの検証（上の表）
- `tests/application/tutorial_controller_test.gd`: 保存しない・画面を要求しない・相手の手・段階の作り直し・本番の状態に触れない
- `tests/ui/tutorial_screen_test.gd`: 段階の進み方・絞った手・次へ・完了・やめる、タイトルのカードの位置
