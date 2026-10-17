# コンポーネント設計 — soccer-game（仮称）

**更新日**: 2026-10-18

> 本書は、レイヤーごとの責務・インターフェース（擬似コード）・依存関係の**実装レベルの詳細**を置く。
> 次の事項は本書に書かず、正本を参照する。
>
> | 事項 | 正本 |
> |---|---|
> | レイヤー構成・各層の許可／禁止 | `architecture-overview.md`「アーキテクチャパターン」 |
> | モジュール構成図（画面 × アプリケーション × ドメイン × データ） | `functional-overview.md`「モジュール構成図」 |
> | エンティティ・区分値・ER図 | `functional-overview.md`「データモデル」 |
> | ルールの計算規則 | `functional-overview.md`「アルゴリズム設計」1〜10 |
> | ディレクトリ・ファイルの物理配置 | `repository-structure.md` |
> | GDScript の型付け・命名・Node 非継承 | kit の `coding-gdscript.md` |
>
> 擬似コードは GDScript で書く。ここに示すのは**公開するクラスとメソッドの形**で、非公開の補助関数・
> 内部の分割は実装時に決める。

## 1. 共通の約束

### 1.1 値の受け渡し

- ドメイン層の関数は**入力を書き換えず、新しい値を返す**。同じ入力から同じ出力が得られることを、判定の決定性・
  対称性のテスト（NFR-05・06）で直接確かめられるようにするため
- 値オブジェクトは `RefCounted` を継承し、`duplicate_deep() -> 自分の型` を持つ（状態を次の状態へ写すときに使う）
- 「何もない」は `null` で表す（例: シュートの運ぶ先）。型注釈は `PitchArea` のまま、ドキュメントコメントに
  `null` を取りうることを書く

### 1.2 視点（座標の向き）

座標の向きの規則は `functional-overview.md`「ドメイン上の制約」が正本。実装では次のように持つ。

| 値 | 誰から見た座標で持つか |
|---|---|
| 選手（`PlayerState`） | その選手のチーム自身 |
| ボール位置（`MatchState.ball_area`） | ボール保持側。保持が入れ替わるときに鏡像へ変換する |
| ターン記録の比較エリア・運ぶ先 | 判定時の攻撃側（トランジションでは奪取側） |
| 選手の動き（`Movement`） | 動いた選手のチーム自身 |

**アプリケーション層と UI の間でやり取りする値は、すべて利用者の視点に揃える。** 変換は `MatchController` が
行い、UI は座標を変換しない。ドメインの値（`TurnRecord` など、攻撃側の視点の値）を UI へそのまま渡さない。

| 向き | 値 | 視点 |
|---|---|---|
| アプリケーション → UI | `BoardSnapshot`・`RevealView`（§3.5）、`MoveOptions`・`ChoiceHint`（`MatchController` が返すもの）、振り返りの各ターン | 利用者 |
| UI → アプリケーション | `TurnChoice`（利用者がタップしたエリア） | 利用者。`MatchController` がドメインへ渡す前に、判定時の攻撃側の視点へ変換する |

### 1.3 チームの呼び方

ドメイン層は利用者と CPU を区別せず、`TeamSide.HOME` / `TeamSide.AWAY` で扱う。MVP では
アプリケーション層が「利用者 = `HOME`、CPU = `AWAY`」に割り当てる（後続マイルストーンのローカル2人対戦で
ドメインを変えないため。`architecture-overview.md`「機能拡張性」）。

### 1.4 名前の一意性

`class_name` と、`GameEnums` に置く enum の名前は、プロジェクト全体で重複させない（kit の `coding-gdscript.md`
「`class_name` はグローバルに一意」）。本書に出てくる名前の一覧を §6 に置き、名前を足すときはそこで重複を確かめる。

## 2. ドメイン層（`game/domain/`）

**外部依存なし**。引数で受け取った値だけで計算する。テストはシーンを起動せずに gdUnit4 で実行する
（禁止事項の正本は `architecture-overview.md`「ドメイン層」、自動チェックは NFR-13）。

### 2.1 区分値（`game_enums.gd`）

`functional-overview.md`「エンティティと区分値」の区分値をそのまま enum にする。値の名前も同書と同じにする。
加えて、実装のために次の区分値を持つ。

```gdscript
class_name GameEnums extends RefCounted

# functional-overview.md の区分値（値の一覧は同書が正本）
enum Lane { L2, L1, C, R1, R2 }
enum Zone { D, M, A }
enum DefenseStyle { ZONE, MAN }
enum AttackStyle { POSSESSION, COUNTER }
enum TurnKind { OPEN_PLAY, TRANSITION }
enum PlayType { SHORT_PASS, DRIBBLE, LONG_BEHIND, SWITCH, SHOT }
enum DefenseAction { PRESS, COVER }
enum NegTransAction { COUNTER_PRESS, RETREAT }
enum PosTransAction { COUNTER, SECURE }
enum TurnOutcome { ADVANCE, STALL, LOSS, GOAL, SAVE, REGAIN, REGAIN_FAILED, NO_CONTEST }
enum MatchStatus { IN_PROGRESS, FINISHED }
enum MatchStage { TURN, STYLE_CHANGE, HALFTIME }
enum PrincipleStatus { UNVERIFIED, VERIFIED, NO_SOURCE }

# 実装のための区分値
enum TeamSide { HOME, AWAY }
enum ChoiceFamily { ATTACK, DEFENSE, NEG_TRANS, POS_TRANS }   # TurnChoice.action がどの enum の値か
enum CoverKind { NONE, DEFENDER, GOALKEEPER, OUT_OF_GK_REACH } # 同数時のカバー判定の内訳（判定理由の表示に使う）
enum MovementReason { SLIDE, MARK, POSSESSION_ADVANCE, COUNTER_BREAKOUT, RETREAT_RESET, PRESS, COVER, DRIBBLE }
enum MatchResult { WIN, DRAW, LOSE }                           # 戦績の勝敗（利用者から見た値）
enum Phase { ATTACK, NEG_TRANSITION, DEFENSE, POS_TRANSITION } # 振り返りの局面別集計（アルゴリズム10）
enum JudgeTally { WIN, LOSE, STALL, EXCLUDED }                 # 振り返りでの1ターンの数え方（アルゴリズム10）
```

> 保存データには enum の**数値ではなく名前**（`"ZONE"` など）を書く。enum の並びを変えても保存データが
> 壊れないようにするため（§4.3）。

### 2.2 値オブジェクト

エンティティと属性の正本は `functional-overview.md`「ER図」。下表は**どのエンティティをどのクラスで持つか**の対応で、
属性は再掲しない（ER図にない、実装のために持つ値だけを備考に書く）。

| クラス | ファイル | 対応するエンティティ | 備考 |
|---|---|---|---|
| `PitchArea` | `pitch_area.gd` | （エリア） | `lane`・`zone`。視点を持たない値で、どの視点かは持ち主が決める（§1.2） |
| `FormationDef` / `PlayerSlotDef` | `formation_def.gd` / `player_slot_def.gd` | フォーメーション / 選手配置 | `PlayerSlotDef.is_goalkeeper` を持つ（アルゴリズム1で GK を除くため） |
| `StyleDef` | `style_def.gd` | 方式 | 解説の固定文 |
| `TeamStyles` | `team_styles.gd` | （試合の方式） | `defense: DefenseStyle`・`attack: AttackStyle` |
| `TeamSetup` | `team_setup.gd` | （試合の陣形と方式） | `formation_id`・`styles: TeamStyles` |
| `PlayerState` | `player_state.gd` | （選手単位の配置状態） | `player_id`・`base_area`・`fixed_area`（固定されていなければ `null`） |
| `TeamLayout` | `team_layout.gd` | （チームの配置） | `players: Array[PlayerState]` と、各選手の現在エリア |
| `LayoutPair` | `layout_pair.gd` | — | 判定中の両チームの `TeamLayout`。`attacker`・`defender` |
| `Movement` | `movement.gd` | （ターン記録の選手の動き） | `side`・`player_id`・`from`・`to`・`reason: MovementReason` |
| `TurnChoice` | `turn_choice.gd` | （ターン記録の選択） | `family: ChoiceFamily`・`action: int`・`target: PitchArea`（シュート・即時奪回・リトリート・保持は `null`） |
| `MoveOptions` | `move_options.gd` | — | 手（`family` と `action`）ごとの、選べる `target` の一覧。一覧が空の手は選択不可 |
| `ChoiceHint` | `choice_hint.gd` | — | ヒント（FR-19）。手と運ぶ先ごとの人数差・カバーの有無 |
| `JudgeDetail` | `judge_detail.gd` | （ターン記録の比較エリア・人数・カバー） | `compare_area`・`attacker_count`・`defender_count`・`cover: CoverKind` |
| `TurnRecord` | `turn_record.gd` | ターン記録 | — |
| `MatchState` | `match_state.gd` | 試合 | `transition_origin: LayoutPair`（トランジションターンの起点となる直前の配置。攻守ターンでは `null`）、`turn_records: Array[TurnRecord]` |
| `TurnResolution` | `turn_resolution.gd` | — | 1ターンを解決した結果。`next_state: MatchState`・`record: TurnRecord` |
| `MatchupNote` | `matchup_note.gd` | — | 解説の1項目。`text`・`principle_ids`・`simplification_ids` |
| `ReviewSummary` | `review_summary.gd` | — | 振り返りの集計結果（アルゴリズム10） |
| `ContentCatalog` | `content_catalog.gd` | 静的データ全体 | 陣形・方式・噛み合わせルール・原則・単純化・場面問題・チュートリアルを束ねる |
| `MatchupRuleDef` / `PrincipleDef` / `SimplificationDef` / `QuizQuestionDef` / `TutorialStepDef` | 各 `*_def.gd` | 噛み合わせルール / 戦術原則 / 単純化項目 / 場面問題 / （チュートリアルの段階） | — |
| `MatchRecord` / `QuizAnswer` / `UserSettings` | `match_record.gd` / `quiz_answer.gd` / `user_settings.gd` | 戦績 / 回答結果 / 設定 | — |

`PitchArea` は盤面の位置関係を計算する関数を持つ。

```gdscript
class_name PitchArea extends RefCounted

var lane: GameEnums.Lane
var zone: GameEnums.Zone

## 相手チームから見た同じ場所（L2↔R2, L1↔R1, D↔A）
func mirrored() -> PitchArea
## 前（相手ゴール側）へ1ゾーン。盤外なら null
func forward() -> PitchArea
func backward() -> PitchArea
## 上下左右の隣接（盤内のみ）
func neighbors4() -> Array[PitchArea]
## 斜めを含む隣接8エリア（盤内のみ）
func neighbors8() -> Array[PitchArea]
func equals(other: PitchArea) -> bool
## "M-L1" 形式。保存データと判定例の表記に合わせる
func to_key() -> String
static func from_key(key: String) -> PitchArea   # 不正な文字列なら null
static func all() -> Array[PitchArea]            # 15エリア。D→M→A、各ゾーン内は L2→R2 の順
```

### 2.3 配置計算（`layout/`。アルゴリズム1・2・4）

```gdscript
class_name BaseLayoutDeriver extends RefCounted
## アルゴリズム1。座標からエリアを決める
static func area_of(x: float, y: float) -> PitchArea
## GK を除く10人の基本エリアを持つ配置（固定なし）
static func derive(formation: FormationDef) -> TeamLayout

class_name StyleLayoutCalculator extends RefCounted
## アルゴリズム2の手順1。全選手を基本エリアに戻し、固定を解除する
static func reset_segment(layout: TeamLayout) -> TeamLayout
## アルゴリズム2の手順2〜4。ターン開始時の両チームの配置を出す。ball は attacker 視点
static func compute(attacker: TeamLayout, attacker_styles: TeamStyles,
        defender: TeamLayout, defender_styles: TeamStyles,
        ball: PitchArea) -> LayoutStep
## マンツーマンのマークを付け直す（ドリブル・プレス・カバーの後に呼ぶ）
static func remark(pair: LayoutPair, defender_styles: TeamStyles) -> LayoutStep

class_name DefenseMover extends RefCounted
## アルゴリズム4。守備の手を適用し、動いた選手を固定する。target は attacker 視点
static func apply(pair: LayoutPair, action: GameEnums.DefenseAction,
        target: PitchArea) -> LayoutStep
```

`LayoutStep`（`layout_step.gd`）は `pair: LayoutPair` と `movements: Array[Movement]` の組で、配置の
変化とその理由（矢印の表示・3D 演出・振り返りに使う）をいっしょに返す。

### 2.4 ターン判定（`judge/`。アルゴリズム3・5・6）

```gdscript
class_name MoveRules extends RefCounted
## アルゴリズム3。side が今のターンで選べる手
static func options_for(state: MatchState, side: GameEnums.TeamSide,
        catalog: ContentCatalog) -> MoveOptions
## 選択不可の手を拒否する（エラーハンドリング「選択不可の手の指定」）
static func is_allowed(options: MoveOptions, choice: TurnChoice) -> bool

class_name OpenPlayJudge extends RefCounted
## アルゴリズム5の手順2〜6。pair はアルゴリズム2を適用済みの配置
static func judge(pair: LayoutPair, attacker_styles: TeamStyles, defender_styles: TeamStyles,
        ball: PitchArea, attack: TurnChoice, defense: TurnChoice) -> JudgeOutput

class_name TransitionJudge extends RefCounted
## アルゴリズム6。origin は直前のターン終了時点の配置（奪取側を attacker として持つ）
## リトリートの基本配置は origin の各選手の base_area から作る（StyleLayoutCalculator.reset_segment）
static func judge(origin: LayoutPair, winner_styles: TeamStyles, loser_styles: TeamStyles,
        ball: PitchArea, winner_choice: TurnChoice, loser_choice: TurnChoice) -> JudgeOutput

class_name MoveHints extends RefCounted
## FR-19 のヒントと、アルゴリズム8 の評価値の共通の計算。
## 「相手が何もしない」と仮定して、各手を適用した後の比較エリアの人数差とカバーの有無を出す
static func evaluate(state: MatchState, side: GameEnums.TeamSide, options: MoveOptions,
        catalog: ContentCatalog) -> Array[ChoiceHint]
```

`JudgeOutput`（`judge_output.gd`）は `outcome: TurnOutcome`・`detail: JudgeDetail`（`NO_CONTEST` は `null`）・
`pair: LayoutPair`（判定時の配置）・`movements: Array[Movement]` を持つ。

> ヒントと CPU の評価値を同じ関数で出すのは、利用者に見せる判断材料と CPU が使う材料を食い違わせないため。
> ヒントは判断材料を示すだけで、最善手を示さない（FR-19）。`ChoiceHint` に推奨の印は持たせない。

### 2.5 試合進行の規則（`match/`。アルゴリズム7）

1ターンの解決（アルゴリズム2〜6の組み立て）と、キックオフ・得点・ハーフ・試合終了の状態遷移を受け持つ。
アプリケーション層はこのクラスだけを呼べば1ターンを進められる。

```gdscript
class_name MatchRules extends RefCounted
## 試合を作る。kickoff_side はアプリケーション層が注入した乱数で決めて渡す
static func create_match(match_id: String, home: TeamSetup, away: TeamSetup,
        kickoff_side: GameEnums.TeamSide, catalog: ContentCatalog) -> MatchState
## 盤面表示・選択肢の計算に使う、ターン開始時の両チームの配置（アルゴリズム2）
static func current_layouts(state: MatchState, catalog: ContentCatalog) -> LayoutStep
## 1ターンを解決する。どちらかの手が選択不可なら null を返す（呼び出し側の誤り）
static func resolve_turn(state: MatchState, home_choice: TurnChoice, away_choice: TurnChoice,
        catalog: ContentCatalog, rules: MatchRuleConfig) -> TurnResolution
## 方式の選び直し（STYLE_CHANGE → TURN）。キックオフを行う
static func apply_style_change(state: MatchState, home: TeamStyles, away: TeamStyles,
        catalog: ContentCatalog) -> MatchState
## ハーフタイムの選び直し（HALFTIME → TURN）。後半のキックオフを行う
static func apply_halftime(state: MatchState, home: TeamSetup, away: TeamSetup,
        catalog: ContentCatalog) -> MatchState
## 後半の最終ターンまで終えたか（確定事項「試合終了から破棄までの順序」のやり直し判定に使う）
static func is_play_complete(state: MatchState, rules: MatchRuleConfig) -> bool
## 試合を FINISHED にした状態を返す
static func finish(state: MatchState) -> MatchState
```

`resolve_turn` が返す `next_state.stage` で、次に開く画面が決まる（`TURN` のまま／得点で `STYLE_CHANGE`／
前半終了で `HALFTIME`）。試合結果へ進むかどうかは `is_play_complete` で判断する。

### 2.6 CPU 思考（`cpu/`。アルゴリズム8）

```gdscript
class_name CpuPlanner extends RefCounted
## ターンの手を選ぶ。引数に相手（利用者）のそのターンの手を含めない（同時手番の公平性。FR-11）
static func choose_turn(state: MatchState, side: GameEnums.TeamSide, catalog: ContentCatalog,
        cpu: CpuConfig, rng: RandomNumberGenerator) -> TurnChoice
## 試合開始時・ハーフタイムの陣形と方式（一様ランダム）
static func choose_setup(catalog: ContentCatalog, rng: RandomNumberGenerator) -> TeamSetup
## 得失点後の方式（一様ランダム）
static func choose_styles(rng: RandomNumberGenerator) -> TeamStyles
## 選択確率（テスト用に公開する。floor / N 以上が残ることの検証に使う）
static func probabilities(scores: Array[float], cpu: CpuConfig) -> Array[float]
```

`RandomNumberGenerator` は `RefCounted` を継承する Godot 標準のクラスで、シードを指定して結果を再現できる。
ドメイン層では生成せず、引数で受け取ったものだけを使う（`architecture-overview.md`「ドメイン層」）。

### 2.7 解説生成（`commentary/`。アルゴリズム9）

```gdscript
class_name CommentaryGenerator extends RefCounted
## 陣形どうしの解説（特徴タグ × 噛み合わせルール）。viewer から見た文にする
static func formation_matchup(viewer: FormationDef, opponent: FormationDef,
        catalog: ContentCatalog) -> Array[MatchupNote]
## 方式どうしの解説（守備方式 × 相手の攻撃方式、攻撃方式 × 相手の守備方式）
static func style_matchup(viewer: TeamStyles, opponent: TeamStyles,
        catalog: ContentCatalog) -> Array[MatchupNote]
## 単独の陣形・方式の特徴・強み・弱み（FR-17。試合準備で相手が未定のときに使う）
static func formation_profile(formation: FormationDef, catalog: ContentCatalog) -> Array[MatchupNote]
static func style_profile(styles: TeamStyles, catalog: ContentCatalog) -> Array[MatchupNote]
```

`MatchupNote.simplification_ids` に単純化 ID があれば、UI は単純化カタログの「実戦では」を添える（FR-23）。

### 2.8 振り返り集計（`review/`。アルゴリズム10）

```gdscript
class_name ReviewAggregator extends RefCounted
## viewer から見たエリア別・局面別の集計と、得失点の直前ターン（lookback ターン）を返す
static func aggregate(records: Array[TurnRecord], viewer: GameEnums.TeamSide,
        lookback_turns: int) -> ReviewSummary
```

## 3. アプリケーション層（`game/application/`）

**責務**: 試合の状態遷移・保存の時点の制御・乱数の生成と注入・画面遷移の要求（`architecture-overview.md`
「アプリケーション層」）。UI のノードは触らず、シグナルで通知する。

### 3.1 入口（オートロード `App`）

`application/app.gd` を `App` という名前でオートロードに登録する（`Node` を継承する。アプリケーション層の
唯一のノード）。各サービスを生成して保持し、UI からの入口になる。オートロード名と衝突しないよう、このスクリプトには
`class_name` を付けない。

```gdscript
extends Node   # オートロード名: App

## UI に開いてほしい画面を知らせる。UI のルート（MainShell）が受けて画面を切り替える
signal screen_requested(screen: AppScreens.Id, params: Dictionary)
## UI が画面の切り替えを頼む入口（タイトル・戻る操作など、MatchController を経由しない遷移）。screen_requested を出す
func request_screen(screen: AppScreens.Id, params: Dictionary = {}) -> void
## 保存に失敗したことを知らせる。UI が表示する文言の正本は functional-overview.md「エラーハンドリング」
signal storage_error(kind: AppScreens.StorageErrorKind)

var match_controller: MatchController   # 本番の試合用。チュートリアルには使わない
var library: LibraryService
var user_data: UserDataService

## チュートリアル用に、本番とは別の MatchController を作る（保存しない・画面遷移を要求しない・相手は ScriptedOpponent）。
## チュートリアルを抜けたら捨てる。本番の match_controller の状態には触れない
func new_tutorial_controller() -> MatchController
```

`AppScreens`（`app_screens.gd`）は画面 ID（`S01_TITLE`〜`S12_SETTINGS`。画面一覧の画面 ID に1対1で対応）と、
保存エラーの種類（`SUSPEND_SAVE`・`USER_DATA_SAVE`・`SUSPEND_LOAD`・`USER_DATA_LOAD`・`USER_DATA_NEWER`）の enum を持つ。
文言の対応は `functional-overview.md`「エラーハンドリング」。

### 3.2 試合進行の管理（`MatchController`。モジュール構成図の A1）

```gdscript
class_name MatchController extends RefCounted

## NONE: なし／RESUMABLE: 再開できる（再開カードを出す）／FINALIZE_PENDING: 終了処理（戦績の記録）が済んでいない試合が残っている
enum SuspendedStatus { NONE, RESUMABLE, FINALIZE_PENDING }
enum StartupResult { NONE, RESUMABLE, FINALIZED, FINALIZE_FAILED, CORRUPTED }

signal state_changed(snapshot: BoardSnapshot)   # 盤面・スコア・相手の方式が変わった。ターンの途中（submit_turn の中）では出さず、continue_after_reveal()・方式の選び直し・ハーフタイムの確定の後に出す（試合画面は、これを受けて次のターンを始める）
signal turn_resolved(reveal: RevealView, snapshot: BoardSnapshot)  # 開示（演出と判定理由の表示に使う）
signal stage_changed(stage: GameEnums.MatchStage)

## is_tutorial が真のときは store・user_data に null を渡し、保存・画面遷移の要求・終了処理を行わない
## 戦績の記録は UserDataService.append_record() を通す（戦績のキャッシュを1か所で更新するため。RecordStore を直接持たない）
func _init(content: ContentRepository, config: ConfigRepository, store: SuspendedMatchStore,
        user_data: UserDataService, rng: RandomNumberGenerator, opponent: OpponentPolicy, is_tutorial: bool) -> void

# --- 起動時（UC-05。確定事項「起動時の扱い」） ---
## 起動時に1回だけ呼ぶ後始末。FINISHED・破損なら削除し、最終ターンまで終えた IN_PROGRESS なら終了処理をやり直す
func inspect_suspended() -> StartupResult
## タイトルを開くたびに呼ぶ。start_match・suspend_to_title・leave_result・終了処理の結果で更新される
func suspended_status() -> SuspendedStatus
## 再開する。毎回 SuspendedMatchStore.load() から読み直し、進行段階（確定事項「再開先」）が示す画面（S-03／S-04／S-05）を
## App に要求して true を返す。読めなかった（消えていた・破損していた）ときは中断データを削除し、App.storage_error(SUSPEND_LOAD) を出して
## S-01 を要求し直し、false を返す
func resume() -> bool
## FINALIZE_PENDING のときに、終了処理（戦績の記録 → FINISHED で保存 → 中断データの削除）をやり直す。成功なら true
func retry_pending_finalize() -> bool

# --- 試合（UC-01〜03） ---
## 試合を作って保存する（保存の時点②）。既存の中断データは、利用者の確認を経たうえでこの保存で上書きされる（削除の時点①）
func start_match(user_setup: TeamSetup) -> void
func user_options() -> MoveOptions               # 利用者の視点
func user_hints() -> Array[ChoiceHint]           # 利用者の視点。設定でヒントが OFF なら UI は呼ばない
## 選択不可の手なら false を返し、状態を変えない（push_error で記録する）
func submit_turn(user_choice: TurnChoice) -> bool
## 開示（演出と判定理由）を利用者が確認した後に呼ぶ。進行段階に応じて次の画面を App に要求する
func continue_after_reveal() -> void
func submit_style_change(user_styles: TeamStyles) -> void
func submit_halftime(user_setup: TeamSetup) -> void
func opponent_setup() -> TeamSetup               # 開示済みの相手の陣形・方式（FR-16・21）
func snapshot() -> BoardSnapshot                 # 現在の盤面・スコア（画面を開いたときの初期表示）。試合の開始前は、suspended_status() が RESUMABLE のときに中断データの状態を返す（タイトルの再開カード用）
func replay_max_sec() -> float                   # 3D 演出の上限（PresentationConfig）
## 直前の保存に失敗していて、中断データが最新の状態でないか（中断の確認ダイアログで警告する）
func has_unsaved_progress() -> bool
## 試合中のメニューから中断してタイトルへ。直前の保存に失敗していれば保存をやり直す（保存の時点④）
func suspend_to_title() -> bool

# --- 結果・振り返り（UC-04） ---
func final_record() -> MatchRecord               # 結果画面が開くたびに呼ぶ（勝敗・スコア・陣形と方式の推移）
func review() -> ReviewView                      # ReviewSummary の集計値と、得失点の流れの各ターンの RevealView（利用者の視点）
## 結果画面からタイトルへ戻る。終了処理が済んでいなければやり直し、なお失敗したら中断データを消さずに残す
func leave_result() -> void

# --- チュートリアル（UC-06。App.new_tutorial_controller() で作った別インスタンスだけが使う） ---
## 段階の盤面で試合の状態を作り直し、ScriptedOpponent の台本をその段階の手に差し替える
func start_tutorial_step(step: TutorialStepDef) -> void
```

**保存の時点**（正本は `functional-overview.md`「確定事項」の保存の時点）は、次のメソッドの中で
`SuspendedMatchStore.save()` を呼ぶことで実現する。チュートリアル用のインスタンスは保存しない。

| 確定事項の時点 | 呼ぶメソッド |
|---|---|
| ① ターンの確定時 | `submit_turn`（`MatchRules.resolve_turn` の直後。演出の再生より前） |
| ② 試合の作成時 | `start_match` |
| ③ 進行段階が変わる時 | `submit_turn`（`STYLE_CHANGE`・`HALFTIME` に入る場合は①と同じ1回の保存で兼ねる）、`submit_style_change`、`submit_halftime` |
| ④ メニューから中断する時（直前の保存に失敗していた場合だけ） | `suspend_to_title` |

保存に失敗しても試合は続け、`App.storage_error` を出し、`has_unsaved_progress()` を真にする（エラーハンドリング
「中断データの保存失敗」）。次に保存に成功したら偽に戻す。

**試合の終了処理**（確定事項「試合終了から破棄までの順序」）は `submit_turn` の中で
`MatchRules.is_play_complete` が真になったときに行う: ① `UserDataService.append_record`（同じ試合 ID があれば記録しない）
→ 成功したら ② `MatchRules.finish` → ③ `SuspendedMatchStore.save`。どちらかが失敗したら中断データは
`IN_PROGRESS` のまま残り、`leave_result`（同じ起動の中）か `inspect_suspended`（次の起動時）がやり直す。
`leave_result` は終了処理が済んでいる場合に限って中断データを削除する（削除の時点②）。
やり直しにも失敗して残った試合は `suspended_status()` が `FINALIZE_PENDING` を返す。タイトルで CPU 対戦を選んだら、
先に `retry_pending_finalize()` でやり直し、なお失敗したら「前の試合の戦績を記録できていません。新しい試合を始めると、
その戦績は記録されません」と確認してから試合準備へ進む（上書きは試合の作成時）。

**選択不可の手**: `submit_turn` は `MoveRules.is_allowed` で利用者の手を確かめ、選択不可なら `false` を返す。
CPU（`OpponentPolicy`）が返した手が選択不可なのは開発時の誤りなので、`assert` で止める（テストで検出する）。
書き出し版で起きた場合は `push_error` で記録し、CPU の手を選べる手の先頭に置き換えてターンを解決する
（CPU 側の誤りで利用者に選び直しを求めないため）。

**乱数**: `App` が起動時に `RandomNumberGenerator` を1つ作って `randomize()` し、`MatchController` に渡す。
前半のキックオフ側の決定と CPU の選択はこの生成器だけを使う。再開しても作り直さない（CPU の手を中断前と同じに
する必要はない）。テストではシードを固定した生成器を渡す。

### 3.3 相手の手の出どころ（`OpponentPolicy`）

```gdscript
class_name OpponentPolicy extends RefCounted
func choose_turn(state: MatchState, side: GameEnums.TeamSide) -> TurnChoice
func choose_setup() -> TeamSetup
func choose_styles() -> TeamStyles

class_name CpuOpponent extends OpponentPolicy        # CpuPlanner を呼ぶ（MVP の対戦相手）
class_name ScriptedOpponent extends OpponentPolicy   # チュートリアルの段階が決めた手を返す
```

`MatchController` は相手の手をこのインターフェース経由で得る。`choose_turn` は利用者の手を受け取らないので、
利用者の手を参照できない形になっている（FR-11）。後続マイルストーンのローカル2人対戦は、ここに
「もう1人の利用者の入力」を足して対応する。

### 3.4 画面向けの参照・保存（`LibraryService`・`UserDataService`。モジュール構成図の A2）

```gdscript
class_name LibraryService extends RefCounted
func formations() -> Array[FormationDef]
func base_counts(formation_id: String) -> Dictionary        # PitchArea のキー → 人数（試合準備のミニピッチ。そのチーム自身の視点）
## 両チームの基本配置の人数を、利用者の視点に揃えて返す（相手は鏡像に変換済み）。PitchArea のキー → [利用者, 相手]
func matchup_counts(user_formation_id: String, opponent_formation_id: String) -> Dictionary
func formation_notes(viewer_id: String, opponent_id: String) -> Array[MatchupNote]  # opponent_id が空なら単独の解説
func style_notes(viewer: TeamStyles, opponent: TeamStyles) -> Array[MatchupNote]    # opponent が null なら単独の解説
## 守備方式だけ・攻撃方式だけの単独の解説（試合準備で片方だけを選んだとき、方式の選び直しで変えた方式を示すとき）
func defense_style_notes(style: GameEnums.DefenseStyle) -> Array[MatchupNote]
func attack_style_notes(style: GameEnums.AttackStyle) -> Array[MatchupNote]
func simplifications() -> Array[SimplificationDef]
func principle(principle_id: String) -> PrincipleDef
func quiz_questions() -> Array[QuizQuestionDef]
func tutorial_steps() -> Array[TutorialStepDef]

class_name UserDataService extends RefCounted
func records() -> Array[MatchRecord]                        # 新しい順
func append_record(record: MatchRecord) -> bool             # 戦績の追加はここだけを通す（MatchController の終了処理が呼ぶ）。キャッシュも更新する
func totals() -> Dictionary                                 # {"win": int, "draw": int, "lose": int}。保持している戦績（上限までの直近の試合）から数える
func quiz_progress() -> Dictionary                          # 学習目標 ID → {"answered": int, "correct": int, "total": int}。answered・correct は問題ごとの最新の回答で数える。total はその学習目標の問題数
func save_quiz_answer(answer: QuizAnswer) -> bool
func settings() -> UserSettings
func save_settings(settings: UserSettings) -> bool
func mark_tutorial_completed() -> bool
```

`bool` を返すメソッドは、保存に失敗したら `false` を返し、`App.storage_error` を出す（通知を出すのは
`UserDataService` だけ。`append_record` を呼んだ `MatchController` は、`false` を受けても通知を重ねて出さない）。読み込みに失敗した
データは初期状態として返す（エラーハンドリングの正本どおり）。

`UserDataService` は、戦績・回答結果・設定を最初に使うときに1回だけ読み込み、結果をメモリに持つ（画面を開くたび・
手の選択のたびに読み直さない）。読み込みの失敗の通知も、その1回だけ出す。保存したら、持っている値も更新する。

### 3.5 画面に渡す値（`BoardSnapshot`・`RevealView`・`ReviewView`）

どちらもアプリケーション層の値で、**利用者の視点に揃えてある**（§1.2）。UI は座標の変換もルールの計算もせず、
これを描くだけにする。

`BoardSnapshot`（`board_snapshot.gd`）は、試合画面・ハーフタイム・方式の選び直しが表示する現在の状態。

| フィールド | 内容 |
|---|---|
| `user_players` / `opponent_players` | 選手ごとの現在の位置（各要素は `player_id`・`number`（背番号）・`area`（利用者の視点のエリアのキー））。現在の配置（`MatchRules.current_layouts`）から `MatchController` が作る。背番号つきの駒の表示に使う |
| `user_counts` / `opponent_counts` | 15エリアの人数（`PitchArea` のキー → 人数）。`user_players` / `opponent_players` をエリアごとに数えた値と一致する |
| `ball_area` | ボール位置 |
| `user_has_ball` | 利用者がボールを持っているか |
| `last_goal_by` | 直前の得点の側（`HOME`／`AWAY`。まだ得点が無ければ空）。方式の選び直しの「〜が得点しました」に使う |
| `turn_kind` / `half` / `turn_number` / `turns_per_half` | 局面と残りターンの表示用 |
| `score_user` / `score_opponent` | スコア |
| `user_setup` / `opponent_setup` | 陣形と方式（相手の方式の常時表示。FR-16・21） |
| `movements` | 直前の判定で動いた選手（利用者の視点に変換済み）。矢印の表示に使う |

優劣記号（`▲`・`＝`・`▼`）は人数の比較だけで決まるので、UI が `user_counts` と `opponent_counts` から描く。

`RevealView`（`reveal_view.gd`）は、1ターンの開示（両者の選択・3D 演出・判定理由）と振り返りの各ターンに使う値。
`MatchController` が `TurnRecord` から作る。

| フィールド | 内容 |
|---|---|
| `user_role` | 利用者の役割。`GameEnums.Phase`（攻撃側＝`ATTACK`／守備側＝`DEFENSE`／喪失側＝`NEG_TRANSITION`／奪取側＝`POS_TRANSITION`）。判定理由の文の主語を決める |
| `user_choice` / `opponent_choice` | 両者の手と、運ぶ先・寄せるエリア |
| `outcome` | ターン結果（`TurnOutcome`） |
| `compare_area` / `user_count` / `opponent_count` / `cover` | 判定の内訳（`NO_CONTEST` では空） |
| `ball_before` / `ball_after` | 判定前後のボール位置 |
| `players_before` / `players_at_judgement` | 両チームの選手単位の配置（判定前・判定時）。各要素は `BoardSnapshot.user_players` と同じ形（`player_id`・`number`・`area`。利用者の視点）。3D 演出の並び方と、振り返りのミニピッチ（判定時の人数はエリアごとに数えるだけ）に使う |
| `movements` | 選手の動き（方式の動き → 守備の手 → 攻撃の手の順） |
| `simplification_ids` | 判定に関わる単純化 ID（「実戦では」の表示に使う） |

`ReviewView`（`review_view.gd`）は、振り返り画面に渡す値。ドメインの `ReviewSummary`（集計値と、得失点の流れに
含めるターンの通し番号）を `MatchController` が受け取り、各ターンを `RevealView` に変換して添える。ドメインの値は
アプリケーション層の型を持たない（`ReviewSummary` は `RevealView` を含まない）。

## 4. データ層（`game/data/`）

**責務**: 静的データ・調整値の読み込みと値オブジェクトへの変換、端末内保存の読み書き（`architecture-overview.md`
「データ層」）。

### 4.1 静的データ（`ContentRepository`）

```gdscript
class_name ContentRepository extends RefCounted
## game/content/*.json を読み、検証して ContentCatalog に変換する
func load_catalog() -> ContentCatalog
## 検証で見つかった誤り（ID の重複、存在しない原則 ID の参照など）。空なら正常
func validation_errors() -> Array[String]
```

静的データはアプリに同梱するため、読み込みの失敗は開発時の誤りとして扱う。NFR-17 の自動テストが
`validation_errors()` が空であることを確かめる。ファイルの一覧は `repository-structure.md`「game/content/」。

### 4.2 調整値（`ConfigRepository`）

`functional-overview.md`「設定値として外部化する値」を、適用先ごとに分けた Resource で持つ（kit の
`coding-gdscript.md`「性質の違う設定を1つの Resource に混ぜない」）。Resource のクラス（スクリプト）は
ドメインが引数で受け取るため `game/domain/config/` に置き、`.tres` の読み込みだけをデータ層が行う（§7）。

| Resource（`class_name`） | ファイル（`game/config/`） | 持つ値 |
|---|---|---|
| `MatchRuleConfig` | `match_rule_config.tres` | 1ハーフのターン数 |
| `CpuConfig` | `cpu_config.tres` | 温度 τ・下限確率 floor |
| `PresentationConfig` | `presentation_config.tres` | 3D 演出の長さの上限（秒）・振り返りで遡るターン数 |
| `VerificationConfig` | `verification_config.tres` | 自己対戦検証の各組み合わせの試合数（テストだけが読む） |

```gdscript
class_name ConfigRepository extends RefCounted
func match_rules() -> MatchRuleConfig      # 値が範囲外なら初期値の Resource を返す（エラーハンドリング「設定値が不正」）
func cpu() -> CpuConfig
func presentation() -> PresentationConfig
```

値の範囲: ターン数は1以上、τ は0より大きい、floor は0以上1未満、演出の上限は0より大きく5以下、遡るターン数は
0以上。初期値は各 Resource の `@export` の既定値として持ち、`functional-overview.md` の表と一致させる。

### 4.3 端末内保存

| データ | ファイル（`user://`） | 形式 | クラス |
|---|---|---|---|
| 中断データ（試合・ターン記録） | `suspended_match.json` | JSON | `SuspendedMatchStore` |
| 戦績 | `match_records.json` | JSON | `RecordStore` |
| 回答結果 | `quiz_answers.json` | JSON | `QuizAnswerStore` |
| 設定 | `settings.cfg` | ConfigFile | `SettingsStore` |

```gdscript
class_name SuspendedMatchStore extends RefCounted
func load() -> SuspendedLoad          # status: NONE / OK / CORRUPTED、state: MatchState（新しい版の形式も CORRUPTED として扱う）
func save(state: MatchState) -> bool
func delete() -> bool                 # 本体・.bak・.tmp をすべて消す（.bak から削除済みの試合が復活しないように）

class_name RecordStore extends RefCounted
enum LoadState { OK, EMPTY, CORRUPTED, NEWER_VERSION }
func load_all() -> Array[MatchRecord] # 破損・新しい版なら空配列（初期状態）を返す
func load_state() -> LoadState
func append(record: MatchRecord) -> bool   # 同じ match_id があれば書かずに true を返す（冪等）。NEWER_VERSION のときは書かずに false。件数の上限か、書き込み後のファイルの大きさの上限（4MB。読み込みの上限 5MB より小さくする）を超えるなら、超えなくなるまで古いものから捨ててから追記する
```

`QuizAnswerStore`・`SettingsStore` も `RecordStore` と同じ形（`load_all`／`load`、`append`／`save`、
`load_state`）にする。

**破損・新しい版のときに元のファイルを失わない**（戦績・回答結果・設定）:
- **破損**: 読み込みで破損と判定したら、本体を `<名前>.corrupt-<YYYYMMDD-HHMMSS>` へ名前を変えて退避してから、
  初期状態として扱う。次の保存は新しいファイルとして書く（退避したファイルは自動では消さない）
- **新しい版**（`format_version` が今の版より新しい）: 破損とは区別する。初期状態を表示するが、そのファイルへは
  書き込まない（保存は `false`。`App.storage_error(USER_DATA_NEWER)`）。古い版のアプリで開いたときに、新しい版の
  データを上書きしないため
- 中断データは対象外とする（破損・新しい版は削除する。削除の時点④）。進行中の1試合だけで、戦績と違って
  積み重ねたデータではないため

**JSON の共通の形**: 最上位に形式のバージョンを持たせる（`architecture-overview.md`「保存データの形式の
バージョン」）。キーは snake_case、区分値は enum の名前、エリアは `"M-L1"` 形式、日時は端末のローカル時刻の
ISO 8601（タイムゾーンなし）で書く。

```json
{
  "format_version": 1,
  "match": {
    "match_id": "20261017-193012-4821",
    "status": "IN_PROGRESS",
    "stage": "TURN",
    "half": 1,
    "turn_number": 5,
    "turn_kind": "OPEN_PLAY",
    "possession": "HOME",
    "ball_area": "M-L1",
    "first_half_kickoff": "AWAY",
    "score": { "HOME": 0, "AWAY": 1 },
    "setups": {
      "HOME": { "formation_id": "4-3-3", "defense": "ZONE", "attack": "POSSESSION" },
      "AWAY": { "formation_id": "4-4-2", "defense": "MAN", "attack": "COUNTER" }
    },
    "players": {
      "HOME": [ { "player_id": "433-LB", "base_area": "D-L2", "fixed_area": null } ],
      "AWAY": [ { "player_id": "442-ST1", "base_area": "A-C", "fixed_area": "M-C" } ]
    },
    "transition_origin": null,
    "started_at": "2026-10-17T19:30:12",
    "turn_records": [ ]
  }
}
```

> 上の例は形を示すためのもので、`players` は各チーム10人のうち1人ずつだけを書いている。

- **試合 ID**: `作成日時（YYYYMMDD-HHMMSS）-乱数4桁`。端末内で一意であればよい（サーバーと突き合わせない）
- **ターン記録**: ER図「ターン記録」の項目を、上と同じ規則でキーにする
- **戦績**: `{"format_version": 1, "records": [ ... ]}`。1件は ER図「戦績」の項目
- **回答結果**: `{"format_version": 1, "answers": [ ... ]}`。1件は ER図「回答結果」の項目
- **設定**: `[meta] format_version`、`[audio] bgm_volume`・`se_volume`（0.0〜1.0。初期値 0.7）、`[ui] show_hints`（初期値 `true`）、
  `[progress] tutorial_completed`

**読み込み時の検証**（NFR-09）: 次のいずれかなら「破損」として扱う。破損時の処理は `functional-overview.md`
「エラーハンドリング」と上の退避の規則に従う（`format_version` が今の版より新しい場合は「新しい版」）。
- ファイルが大きすぎる（5MB を超える。戦績を数千件ためても 2MB に届かない大きさ。改変されたファイルを全量読み込まない）
- JSON として読めない、`format_version` が無い
- 必須のキーが無い、型・範囲が違う（存在しないエリア名・区分値、10人でない配置など）
- 件数が上限を超える（中断データの `turn_records` が「1ハーフのターン数 × 2」を超える、など）

**形式の変換**（NFR-26）: `SaveMigrator`（`save_migrator.gd`）が、読み込んだ `format_version` から今の版まで、
1版ずつ変換する関数を順に適用する。形式を変えるたびに変換関数を1つ足し、変更前の形式のテスト用データを
`tests/fixtures/` に残す。

**書き込み手順**（NFR-08。強制終了でも直前に確定した状態を残す）: `SaveFileIO`（`save_file_io.gd`）が
全ファイルで共通に行う。

1. `<名前>.tmp` に全体を書いて閉じる
2. 既存の本体があれば `<名前>.bak` へ名前を変える
3. `<名前>.tmp` を本体の名前に変える
4. `<名前>.bak` を消す

読み込み時、本体が無いか壊れていて `.bak` が読めるなら `.bak` を使う（手順2と3の間で止まった場合）。
`.tmp` は読まずに消す（書き込みの途中で止まった可能性があるため）。削除（`delete()`）は本体・`.bak`・`.tmp` を
すべて消す。

## 5. UI 層（`game/ui/`）

**責務**: 画面の表示・入力・2D 作戦ボード・3D 演出（`architecture-overview.md`「UI 層」）。`App` の
サービスを呼び、シグナルを受けて描き直す。データ層には触らない。

### 5.1 画面の切り替え（`MainShell`）

`ui/main_shell.tscn` をメインシーンにする。`App.screen_requested` を受けて、子にある画面のシーンを入れ替える。
画面どうしは直接遷移せず、遷移は必ず `App` を経由する（遷移の正本は `functional-overview.md`「画面遷移図」）。
起動時は `MatchController.inspect_suspended()` と `UserDataService.settings()` を呼んでからタイトルを開く。
タイトルを開く前に出た `App.storage_error`（中断データの破損など）は `MainShell` が保持し、タイトルを開いてから
通知（`ToastView`）で表示する。

### 5.2 画面

ディレクトリと `class_name` の対応。各画面のレイアウト・項目・イベントは `screen-design.md` に書く。

| 画面ID | ディレクトリ（`ui/screens/`） | ルートの `class_name` |
|---|---|---|
| S-01 | `s01_title/` | `TitleScreen` |
| S-02 | `s02_match_setup/` | `MatchSetupScreen` |
| S-03 | `s03_match/` | `MatchScreen` |
| S-04 | `s04_style_change/` | `StyleChangeScreen` |
| S-05 | `s05_halftime/` | `HalftimeScreen` |
| S-06 | `s06_result/` | `ResultScreen` |
| S-07 | `s07_review/` | `ReviewScreen` |
| S-08 | `s08_tutorial/` | `TutorialScreen` |
| S-09 | `s09_quiz/` | `QuizScreen` |
| S-10 | `s10_scope/` | `ScopeScreen` |
| S-11 | `s11_records/` | `RecordsScreen` |
| S-12 | `s12_settings/` | `SettingsScreen` |

### 5.3 2D 作戦ボード（`board2d/`）

| `class_name` | 役割 |
|---|---|
| `TacticsBoard` | 15エリアの盤面。`BoardSnapshot` を受けて描く。ピッチを横に置き、利用者の攻撃方向を画面の右にする |
| `AreaCell` | 1エリア。両チームの人数（`自分−相手`）・優劣記号・ボール・選択可否・ヒントを表示し、タップ／クリックを受ける |
| `MoveArrowLayer` | `movements` を移動元から移動先への矢印で描く。理由（`MovementReason`）ごとに線種を変える |
| `ChoicePanel` | 局面に応じた手のボタン。`MoveOptions` で選べない手を選択不可にする |
| `MiniPitch` | 試合準備・ハーフタイム・理解度チェックで使う小さな盤面（人数の数字と優劣記号） |
| `MatchBoardPanel` | 試合画面の盤面と手の選択の部分（左の `TacticsBoard`、右の操作の列の `ChoicePanel`・判定理由、両方を覆う 3D 演出の表示場所）。試合画面とチュートリアルで共用する |

### 5.4 3D 演出（`replay3d/`）

```gdscript
class_name ReplayStage extends Node3D
signal finished(was_cut: bool)   # was_cut: 上限に達して打ち切ったか（NFR-02 の記録に使う）
## 開示の値から演出を組み立てて再生する。max_sec は MatchController.replay_max_sec()
func play(reveal: RevealView, max_sec: float) -> void
func skip() -> void

class_name ReplayLayoutMapper extends RefCounted
## エリアの人数から、エリア内の立ち位置（3D 座標）を決める。人数ごとに決まった並べ方を使う
static func slot_positions(area: PitchArea, count: int) -> Array[Vector3]
```

- 演出の入力は `RevealView`（ターン記録を利用者の視点に変換したもの）だけにする。`ReplayStage` はドメインの
  判定モジュールを呼ばない（`architecture-overview.md`「3D 演出の原則」）
- カメラはメインスタンドから見下ろす位置に置き、利用者の攻撃方向が画面の右になるようにする（2D 作戦ボードと同じ向き）
- 選手は簡易形状（カプセル＋チーム色＋背番号）で、移動は `Tween` で補間する。骨格のアニメーションは使わない
  （3D 素材の方針の正本は `architecture-overview.md`「テクノロジースタック」）
- 演出の流れ: ①判定前の配置（`players_before`）で並ぶ → ②`movements` の順（方式の動き → 守備の手 → 攻撃の手）で選手が動く →
  ③ボールが比較エリアへ動き、結果（前進・ロスト・得点など）を見せる。各段の長さは、合計が上限の8割に収まるように
  組み立てる（暫定値を上限に張り付けない。kit の `coding-gdscript.md`）
- 上限に達したら打ち切って `finished(true)` を出す。`skip()` でも即座に `finished(false)` を出す

### 5.5 共通部品（`common/`）

| `class_name` | 役割 |
|---|---|
| `JudgeReasonFormatter` | `RevealView` から判定理由の文（`functional-overview.md`「表示仕様」の形式）を作る。主語は `user_role` で決める（例: `NO_CONTEST` は、利用者が奪取側なら「判定なし（相手は撤退、こちらは保持）」、喪失側なら「判定なし（こちらは撤退、相手は保持）」） |
| `NotesView` | `MatchupNote` の一覧を表示し、単純化 ID があれば「実戦では」を添える |
| `ConfirmDialog` | 確認ダイアログ（中断データが上書きされることの確認など） |
| `ToastView` | 保存エラーなどの短い通知 |
| `ScreenHeader` | 画面のヘッダー（戻る・画面名） |
| `ScoreBug` | 中継風のスコア表示（試合画面・方式の選び直し・ハーフタイム・試合結果） |
| `FormationCard` | 陣形のカード（陣形名・`MiniPitch`・選択中の印） |
| `MatchMenu` | 試合中の画面のメニュー（設定・中断してタイトルへ） |
| `SettingsPanel` | 設定の中身（設定画面と、試合中のメニューから重ねて開く設定で共用） |
| `SimplificationList` | 単純化カタログの一覧（ゲームの表現範囲とチュートリアルの最後で共用） |
| `NewMatchGate` | 「CPU 対戦」を押したときの確認の手順（タイトルと戦績の0件の表示で共用。ノードを持たない） |

各部品の外から見た形（メソッド・シグナル）は `docs/specs/3_detail-design/screen/screen-common.md` §5。

## 6. 名前の一覧（重複の確認用）

§1.4 のための一覧。名前を足すときは、ここと Godot の組み込みクラス名の両方と重ならないことを確かめる。

> **確認の結果（2026-10-18、Godot 4.7.2）**: 下の表の全124個の名前（クラス名・enum 名・画面12個のクラス名）を、次の1,294個の名前と
> 突き合わせ、衝突は 0 件だった（大文字・小文字の違いも衝突とみなして比べた）。
> - `ClassDB.get_class_list()` の組み込みクラス
> - Variant の型名（`Vector2`・`Array` など）
> - `Engine.get_singleton_list()` のシングルトン
> - `ProjectSettings.get_global_class_list()` のグローバルなクラス名（同梱の gdUnit4 が登録する `GdUnitError`・`ErrorLogEntry` など）
>
> 突き合わせは、画面なしで実行する使い捨てのスクリプトで行った。名前を足すとき、または Godot・gdUnit4 の版を上げるときは、
> 同じ4つの一覧と突き合わせる。

| 区分 | 名前 |
|---|---|
| オートロード | `App` |
| enum（`GameEnums` 内） | `Lane`・`Zone`・`DefenseStyle`・`AttackStyle`・`TurnKind`・`PlayType`・`DefenseAction`・`NegTransAction`・`PosTransAction`・`TurnOutcome`・`MatchStatus`・`MatchStage`・`PrincipleStatus`・`TeamSide`・`ChoiceFamily`・`CoverKind`・`MovementReason`・`MatchResult`・`Phase`・`JudgeTally` |
| enum（その他） | `AppScreens.Id`・`AppScreens.StorageErrorKind`・`MatchController.SuspendedStatus`・`MatchController.StartupResult`・`SuspendedLoad.Status`・`RecordStore.LoadState`（`QuizAnswerStore`・`SettingsStore` も同名の enum を各クラス内に持つ。クラスの内側なので衝突しない） |
| ドメイン | `MatchRuleConfig`・`CpuConfig`・`PresentationConfig`・`VerificationConfig`・`GameEnums`・`PitchArea`・`FormationDef`・`PlayerSlotDef`・`StyleDef`・`TeamStyles`・`TeamSetup`・`PlayerState`・`TeamLayout`・`LayoutPair`・`LayoutStep`・`Movement`・`TurnChoice`・`MoveOptions`・`ChoiceHint`・`JudgeDetail`・`JudgeOutput`・`TurnRecord`・`MatchState`・`TurnResolution`・`MatchupNote`・`ReviewSummary`・`ContentCatalog`・`MatchupRuleDef`・`PrincipleDef`・`SimplificationDef`・`QuizQuestionDef`・`TutorialStepDef`・`MatchRecord`・`QuizAnswer`・`UserSettings`・`BaseLayoutDeriver`・`StyleLayoutCalculator`・`DefenseMover`・`MoveRules`・`OpenPlayJudge`・`TransitionJudge`・`MoveHints`・`MatchRules`・`CpuPlanner`・`CommentaryGenerator`・`ReviewAggregator` |
| アプリケーション | `AppScreens`・`MatchController`・`OpponentPolicy`・`CpuOpponent`・`ScriptedOpponent`・`LibraryService`・`UserDataService`・`BoardSnapshot`・`RevealView`・`ReviewView` |
| データ | `ContentRepository`・`ConfigRepository`・`SuspendedMatchStore`・`SuspendedLoad`・`RecordStore`・`QuizAnswerStore`・`SettingsStore`・`SaveFileIO`・`SaveMigrator` |
| UI | `MainShell`・`TitleScreen`〜`SettingsScreen`（§5.2）・`TacticsBoard`・`AreaCell`・`MoveArrowLayer`・`ChoicePanel`・`MiniPitch`・`MatchBoardPanel`・`ReplayStage`・`ReplayLayoutMapper`・`JudgeReasonFormatter`・`NotesView`・`ConfirmDialog`・`ToastView`・`ScreenHeader`・`ScoreBug`・`FormationCard`・`MatchMenu`・`SettingsPanel`・`SimplificationList`・`NewMatchGate` |

> `MatchStatus`（enum）と `MatchState`（クラス）、`TurnOutcome.LOSS` と `MatchResult.LOSE` のように
> 似た名前があるが、いずれも別の名前で衝突しない。`MatchResult` は勝敗の区分値で、戦績のクラスは `MatchRecord`。

## 7. 依存関係のまとめ

レイヤー間の許可／禁止の正本は `architecture-overview.md`。本書の範囲で補足するのは次の3点。

- **ドメイン層の中**: `match/` は `layout/`・`judge/` を、`cpu/` は `judge/`（`MoveHints`・`MoveRules`）を呼ぶ。
  `layout/`・`judge/` は `match/`・`cpu/` を呼ばない（下位から上位への呼び出しを作らない）
- **ドメインが受け取る Resource**: `MatchRuleConfig`・`CpuConfig` などの調整値は `Resource` を継承するが、
  ドメインは引数で受け取った値を読むだけで、読み込みはしない。ドメインがデータ層に依存しないよう、これらの
  クラスは `game/domain/config/` に置き、`.tres` の読み込みだけをデータ層（`ConfigRepository`）が行う
- **UI が読む値**: アプリケーション層の `BoardSnapshot`・`RevealView`・`ReviewView` と、ドメインの値（`MoveOptions`・
  `ChoiceHint`・`MatchupNote` など。座標を含むものは `MatchController` が利用者の視点に変換済み）を
  表示のために読む（ドメインへは点線の依存）。ドメインの関数は呼ばない
