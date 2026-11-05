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
enum Zone { D1, D2, M1, M2, A1, A2 }                         # 列（自陣ゴール側から）。2026-10-25 に D・M・A の3つから6列にした
enum DefenseStyle { ZONE, MAN }
enum AttackStyle { POSSESSION, COUNTER }
enum TurnKind { OPEN_PLAY, TRANSITION }
enum PlayType { SHORT_PASS, DRIBBLE, THROUGH_PASS, LONG_BEHIND, SWITCH, SHOT, BACK_PASS }   # THROUGH_PASS は 2026-10-25、BACK_PASS は 2026-11-03（末尾に足す）
enum DefenseAction { PRESS, COVER, CLOSE_DOWN, BLOCK_SHOT }   # CLOSE_DOWN はドリブルのコースを切る（2026-11-05）、BLOCK_SHOT はボールのエリアへの寄せ（2026-11-03）
enum NegTransAction { COUNTER_PRESS, RETREAT }
enum PosTransAction { COUNTER, SECURE }
enum TurnOutcome { ADVANCE, STALL, LOSS, GOAL, SAVE, REGAIN, REGAIN_FAILED, NO_CONTEST, OFFSIDE }   # OFFSIDE は 2026-10-25
enum MatchStatus { IN_PROGRESS, FINISHED }
enum MatchStage { TURN, STYLE_CHANGE, HALFTIME }
enum PrincipleStatus { UNVERIFIED, VERIFIED, NO_SOURCE }

# 実装のための区分値
enum TeamSide { HOME, AWAY }
enum ChoiceFamily { ATTACK, DEFENSE, NEG_TRANS, POS_TRANS }   # TurnChoice.action がどの enum の値か
enum CoverKind { NONE, DEFENDER } # 同数時のカバー判定の内訳（判定理由の表示に使う。GK はカバーに数えない）
enum ReadKind { NONE, NEAR, EXACT } # 守備の読みの段階（アルゴリズム5。制限したエリアと比較エリアの近さ）
enum MovementReason { SLIDE, MARK, POSSESSION_ADVANCE, COUNTER_BREAKOUT, RETREAT_RESET, PRESS, COVER, DRIBBLE,
        DRIBBLE_STOPPED, BALL_HOLDER, RETURN, THROUGH_RUN }     # DRIBBLE_STOPPED・BALL_HOLDER は保持者の動き（アルゴリズム5・7）。
                                                               # RETURN は方式の動きが無いまま基本エリアへ1マス戻る動き（アルゴリズム2）。
                                                               # THROUGH_RUN はスルーパスの受け手の走り込み（アルゴリズム5）
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
| `FormationDef` / `PlayerSlotDef` | `formation_def.gd` / `player_slot_def.gd` | フォーメーション / 選手配置 | `PlayerSlotDef` はポジション種別を `position_type`（`"GK"` などの文字列。`type` は紛らわしいため避けた）で持ち、`is_goalkeeper()` を持つ（アルゴリズム1で GK を除くため） |
| `StyleDef` | `style_def.gd` | 方式 | `id`（区分値の名前）・`kind`（`DEFENSE`・`ATTACK`）・`name`・解説の固定文（`summary`・`strengths`・`weaknesses`）・`principle_ids`・`simplification_ids`。`defense_id(style)`・`attack_id(style)` で区分値から ID を引く |
| `TeamStyles` | `team_styles.gd` | （試合の方式） | `defense: DefenseStyle`・`attack: AttackStyle` |
| `TeamSetup` | `team_setup.gd` | （試合の陣形と方式） | `formation_id`・`styles: TeamStyles` |
| `PlayerState` | `player_state.gd` | （選手単位の配置状態） | `player_id`・`base_area`・`fixed_area`（固定されていなければ `null`）・`current_area`（今いるエリア。ターンをまたいで持ち越す）・`moved_in_turn`（前のターンの手などでターン開始の位置から動いたか）・`is_fixed()` |
| `TeamLayout` | `team_layout.gd` | （チームの配置） | `players: Array[PlayerState]` と、各選手の現在エリア（下記） |
| `LayoutPair` | `layout_pair.gd` | — | 判定中の両チームの `TeamLayout`。`attacker`・`defender`・`attacker_side: TeamSide`（`Movement.side` を埋めるため）・`defender_side()` |
| `Movement` | `movement.gd` | （ターン記録の選手の動き） | `side`・`player_id`・`from`・`to`・`reason: MovementReason` |
| `TurnChoice` | `turn_choice.gd` | （ターン記録の選択） | `family: ChoiceFamily`・`action: int`・`target: PitchArea`（シュート・即時奪回・リトリート・保持は `null`）・`is_complete_for(family)`（判定に使える形か。攻守ターン・トランジションの判定で共有） |
| `MoveOptions` | `move_options.gd` | — | 手（`family` と `action`）ごとの、選べる `target` の一覧。一覧が空の手は選択不可。運ぶ先を持たない手（シュート・即時奪回・リトリート・保持）は `allow` で選べるかだけを持つ。`add_target`・`allow`・`is_available`・`targets`・`static needs_target(family, action)` |
| `ChoiceHint` | `choice_hint.gd` | — | ヒント（FR-19）。手と運ぶ先ごとの人数差・カバーの有無。`family`・`action`・`target`・`is_compared`（リトリート・保持・スルーパスは比べない）・`own_count`・`opponent_count`（その手を選ぶ側から見た値）・`cover`・`is_offside`（今の配置のままオフサイドになる攻撃の手か。2026-10-25）・`is_marked`（相手が何もしなくても、マンツーマンの付け直しで守備の選手が運ぶ先へ入ってくるスルーパスか。どちら向きにも確定ではない。`OpenPlayJudge.defender_entered` で判定と共有。2026-10-28）・`diff()`。評価値や推奨の印は持たない |
| `JudgeDetail` | `judge_detail.gd` | （ターン記録の比較エリア・人数・カバー） | `compare_area`・`attacker_count`・`defender_count`・`cover: CoverKind`・`read: ReadKind`（守備の読みの段階） |
| `TurnRecord` | `turn_record.gd` | ターン記録 | 判定前・判定時の配置は `pair_before`・`pair_at_judgement`（`LayoutPair`。現在エリアを含む）。`ball_after` は判定直後にボールがあるエリア（`GOAL` はシュートしたエリア、`SAVE` は守備側の自陣ゴール前 `D1-C`。攻撃側の視点で `A2-C`） |
| `MatchState` | `match_state.gd` | 試合 | `transition_origin: LayoutPair`（トランジションターンの起点となる直前の配置。攻守ターンでは `null`）、`turn_records: Array[TurnRecord]`。選手は `home_players`・`away_players`（基本エリア・固定先・今いるエリア `current_area`・`moved_in_turn`。位置はターンをまたいで持ち越す）。ターン開始時の配置は `StyleLayoutCalculator.turn_start(state)` で出す（攻守ターンはアルゴリズム2、トランジションは起点） |
| `TurnResolution` | `turn_resolution.gd` | — | 1ターンを解決した結果。`next_state: MatchState`・`record: TurnRecord` |
| `MatchupNote` | `matchup_note.gd` | — | 解説の1項目。`text`・`principle_ids`・`simplification_ids`・`label`（画面で並べるときの見出し。ドメインは空のまま返し、`LibraryService` が付ける。2026-11-03）。`relabeled(label, text)` で写しを作る |
| `ReviewSummary` | `review_summary.gd` | — | 振り返りの集計結果（アルゴリズム10）。`area_tallies`（エリアのキー → `[勝ち, 負け, 膠着]`。判定の無かったエリアは入らない）・`phase_tallies`（`Phase` → 同じ形。4局面とも入る）・`goals: Array[ReviewGoal]`（`seq`・`half`・`turn_number`・`scorer`・得点後の `home_score`・`away_score`・直前のターンの通し番号 `lead_up_seqs`（古い順。得点のターンは含めない））・`segments: Array[ReviewSegment]`（`half`・`from_turn`・`to_turn`・`home_setup`・`away_setup`）・`turn_count`。数の配列の位置は `JudgeTally` の WIN・LOSE・STALL（2026-10-29） |
| `ContentCatalog` | `content_catalog.gd` | 静的データ全体 | 陣形・方式・噛み合わせルール・原則・単純化・場面問題・チュートリアルを束ねる。`formation(id)`・`style(id)`・`principle(id)`（無ければ `null`）。方式は `styles`、ルールは `matchup_rules`（配列の順が採用の順）、陣形どうしでルールが当たらない側の文は `matchup_fallback`（2026-11-03） |
| `MatchupRuleDef` / `PrincipleDef` / `SimplificationDef` / `QuizQuestionDef` / `TutorialStepDef` | 各 `*_def.gd` | 噛み合わせルール / 戦術原則 / 単純化項目 / 場面問題 / （チュートリアルの段階） | — |
| `MatchRecord` / `QuizAnswer` / `UserSettings` | `match_record.gd` / `quiz_answer.gd` / `user_settings.gd` | 戦績 / 回答結果 / 設定 | — |

`PitchArea` は盤面の位置関係を計算する関数を持つ。

```gdscript
class_name PitchArea extends RefCounted

var lane: GameEnums.Lane
var zone: GameEnums.Zone

## 相手チームから見た同じ場所（L2↔R2, L1↔R1, D1↔A2, D2↔A1, M1↔M2）
func mirrored() -> PitchArea
## 前（相手ゴール側）へ1列。盤外なら null
func forward() -> PitchArea
func backward() -> PitchArea
## 自陣（1〜3列目。OWN_HALF_ZONES）か
func is_own_half() -> bool
## 上下左右の隣接（盤内のみ）
func neighbors4() -> Array[PitchArea]
## 斜めを含む隣接8エリア（盤内のみ）
func neighbors8() -> Array[PitchArea]
func equals(other: PitchArea) -> bool
## "M2-L1" 形式（列-レーン）。保存データと判定例の表記に合わせる
func to_key() -> String
static func from_key(key: String) -> PitchArea   # 不正な文字列なら null
static func all() -> Array[PitchArea]            # 30エリア。D1→A2、各列の中は L2→R2 の順
```

`TeamLayout` は、選手ごとの現在エリアを `base_area`・`fixed_area` とは別に持つ。アルゴリズム2の方式の動き
（スライド・マーク・保持型の前進）で、固定されていない選手の現在エリアも基本エリアからずれるため。
ターンの中の計算では `TeamLayout` の現在エリアが正で、`PlayerState.current_area` は試合の状態（`MatchState`）へ
持ち越すための値（`TeamLayout.from_players` で配置を作り、`MatchRules`（実体は `MatchPositions`）が判定後の配置から写し戻す。2026-10-24）。

```gdscript
class_name TeamLayout extends RefCounted

var players: Array[PlayerState]

func _init(players: Array[PlayerState], current_areas: Dictionary)   # 選手 ID → PitchArea
## 全員の現在エリアを基本エリアにした配置（固定の有無は見ない）
static func at_base(players: Array[PlayerState]) -> TeamLayout
## 各選手の current_area を現在エリアにした配置（試合の状態からターン開始の起点を作る）
static func from_players(players: Array[PlayerState]) -> TeamLayout
func current_area_of(player_id: String) -> PitchArea   # いない選手なら null
func count_at(area: PitchArea) -> int
## 30エリアすべてのキー → 人数（0 のエリアも含める）
func counts() -> Dictionary
func duplicate_deep() -> TeamLayout
```

### 2.3 配置計算（`layout/`。アルゴリズム1・2・4）

```gdscript
class_name BaseLayoutDeriver extends RefCounted
## アルゴリズム1。座標からエリアを決める
static func area_of(x: float, y: float) -> PitchArea
## GK を除く10人の基本エリアを持つ配置（固定なし）。座標のエリアで重なる列は1マス1人に散らす（2026-10-24）
static func derive(formation: FormationDef) -> TeamLayout
## アルゴリズム7。キックオフの位置（選手 ID → エリア）。基本エリアの列を半分にした自陣の列に置き、重なれば散らす（2026-10-25）
static func kickoff_areas(players: Array[PlayerState]) -> Dictionary

class_name StyleLayoutCalculator extends RefCounted
## アルゴリズム2の手順1〜4。今いるエリアを起点に、方式の目標へ1マス近づいたターン開始時の両チームの配置を出す。
## ball は attacker 視点
static func compute(attacker: TeamLayout, attacker_styles: TeamStyles,
        defender: TeamLayout, defender_styles: TeamStyles,
        ball: PitchArea, attacker_side: GameEnums.TeamSide) -> LayoutStep
## マンツーマンのマークを付け直す（ドリブル・プレス・カバーの後に呼ぶ）。マーカーは start（ターン開始の守備側。
## 省略したら pair の守備側）から1マス近づく
static func remark(pair: LayoutPair, defender_styles: TeamStyles, start: TeamLayout = null) -> LayoutStep
## アルゴリズム6のリトリート。守備側（喪失側）の固定を解除し、基本配置＋守備方式の目標へ1マス近づける。ball は攻撃側（奪取側）の視点
static func retreat(pair: LayoutPair, defender_styles: TeamStyles, ball: PitchArea) -> LayoutStep
## 試合の状態からターン開始時の配置（攻守ターンは compute、トランジションは起点の写し）。options_for と MatchRules が使う
static func turn_start(state: MatchState) -> LayoutStep

class_name DefenseMover extends RefCounted
## アルゴリズム4。守備の手を適用し、動いた選手を固定する。target は attacker 視点
static func apply(pair: LayoutPair, action: GameEnums.DefenseAction,
        target: PitchArea) -> LayoutStep
## カバーで背後へ下がる選手を探す隣接エリア（横 → 背後。前方は除く）。MoveRules.defense_options も使う
static func cover_neighbors(restricted: PitchArea) -> Array[PitchArea]
```

`StyleLayoutCalculator` の決めごと（仕様に無い点を実装で決めたもの。2026-10-18。2026-10-24 に1ターン1マスへ改めた）:
- 方式の動きの目標は、基本エリア（固定されていれば固定先）を起点に出す。選手は今いるエリアから目標へ1マス近づく
  （`PitchArea.step_toward`。列差・レーン差をそれぞれ1ずつ詰める）。`moved_in_turn` の選手はターン開始では動かない。
  `compute` の `movements` は、今いるエリアから変わった選手だけを、攻撃側 → 守備側の順で返す
- マンツーマンでどのマーカーをどの対象につけるか: マークする対象は優先順の上からマーカーの人数分。そのうち、対象と
  同じエリアに今いるマーカーはそのまま残す（`remark` でマーカーどうしが入れ替わり、矢印が交差しないようにするため）。
  残りは優先順に、今いるエリアとの列差＋レーン差が最小のマーカーを割り当てる（基本エリアで選ぶと、遠いマーカーが
  1マスずつ追い続けて追いつかないため）。同じなら配置の選手の順
- 余ったマーカーの理由は `MARK`（カバー役も、マークの規則による動きとして扱う）
- `remark` は `ZONE` では何も動かさない（ずれる基準はターン開始時のボール位置のため）

`DefenseMover` の決めごと（仕様に無い点を実装で決めたもの。2026-10-18）:
- `COVER` の「隣接エリア」は `PRESS` と同じ上下左右から前方を除いたもの（`cover_neighbors`。前方からは背後まで2列になるため。2026-10-24）。
  同率の「横」は、中央寄りのレーンを先にし、同じなら守備側の左を先にする
- 同じエリアに動かせる選手が複数いれば、固定されていない選手のうち配置の選手の順で先の選手
- `COVER` で、隣接から選んだ選手がすでに背後にいる（`T_d` が空で、背後にだけ守備側がいる）ときは、その場で固定し、
  動き（`movements`）には含めない（位置が変わった選手だけを動きにする。`StyleLayoutCalculator` と同じ）
- 選べない手（動かせる選手がいない、`COVER` の背後が盤外）なら `null` を返す。マンツーマンのマークの付け直しは
  呼び出し側が `StyleLayoutCalculator.remark` で行う

`LayoutStep`（`layout_step.gd`）は `pair: LayoutPair` と `movements: Array[Movement]` の組で、配置の
変化とその理由（矢印の表示・開示の動き・振り返りに使う）をいっしょに返す。

### 2.4 ターン判定（`judge/`。アルゴリズム3・5・6）

```gdscript
class_name MoveRules extends RefCounted
## アルゴリズム3。side が今のターンで選べる手
## 攻守ターン: 保持側は攻撃の手、相手は守備の手。トランジション: 保持側（奪取側）は TransitionJudge.counter_layout を
## 通した配置で奪った側の手、相手は失った側の手。MatchRules.resolve_turn も手の確かめに使う
static func options_for(state: MatchState, side: GameEnums.TeamSide) -> MoveOptions
## 選択不可の手を拒否する（エラーハンドリング「選択不可の手の指定」）
static func is_allowed(options: MoveOptions, choice: TurnChoice) -> bool
## 局面の値を受け取る下位の関数（options_for が局面に応じて呼ぶ）。ball と運ぶ先は、攻撃側（トランジションは奪った側）の視点
static func attack_options(pair: LayoutPair, ball: PitchArea) -> MoveOptions
## 運ぶ先（制限するエリア）は攻撃側の視点。守備側が選べる 30 エリアのすべてが候補。ball を渡すと、ドリブルのコースを切る
## （CLOSE_DOWN。プレスと同じエリア。2026-11-05）と、ペナルティエリアではシュートコースを塞ぐ（BLOCK_SHOT。ボールのエリア）を足す
static func defense_options(pair: LayoutPair, ball: PitchArea = null) -> MoveOptions
static func neg_transition_options() -> MoveOptions
## winner はアルゴリズム6のカウンターの配置（呼び出し側が作る）。前に味方がいなければ、1列前でレーン差1以内を運ぶ先にする
## （奪った選手が自分で運ぶ。ボールのエリアに奪った側がいるときだけ。2026-11-05）
static func pos_transition_options(winner: TeamLayout, ball: PitchArea) -> MoveOptions

class_name MoveMenu extends RefCounted   # 2026-11-03。アルゴリズム3「画面に出す手」
## side に出す手。MoveRules.options_for から枠ごとに手と行き先を1つずつ選ぶ（手ごとに運ぶ先は0か1件）。利用者の手と CPU の候補
static func options_for(state: MatchState, side: GameEnums.TeamSide) -> MoveOptions
## action と同じ枠の手（チュートリアルの絞り込みを枠で効かせる）・枠の位置（ボタンの並び）
static func slot_actions(family: GameEnums.ChoiceFamily, action: int) -> Array[int]
static func slot_index(family: GameEnums.ChoiceFamily, action: int) -> int

class_name OffsideRule extends RefCounted   # 2026-10-25。判定・ヒント・盤面のラインで共有する
## 実効のオフサイドライン（攻撃側の視点の列。0 始まり）。守備側のいちばん自陣ゴールに近い選手の列か、ボールの列のうち前の方。
## 自陣の境（2）より手前なら 2、守備側が0人なら 5
static func line_row(defender: TeamLayout, ball: PitchArea) -> int
## 対象の手の受け手のエリア（スルーパスは走り込む前の位置、前へのショートパス・ロングボールは運ぶ先）。対象外の手は null
static func receiver_area(pair: LayoutPair, ball: PitchArea, attack: TurnChoice) -> PitchArea
## 受け手の列がラインより前か
static func is_offside(pair: LayoutPair, ball: PitchArea, attack: TurnChoice) -> bool

class_name OpenPlayJudge extends RefCounted
## アルゴリズム5の手順2〜6。pair はアルゴリズム2を適用済みの配置。守備の手を適用した後にオフサイドなら OFFSIDE を返し、
## 攻撃の手は適用しない（2026-10-25）
static func judge(pair: LayoutPair, attacker_styles: TeamStyles, defender_styles: TeamStyles,
        ball: PitchArea, attack: TurnChoice, defense: TurnChoice) -> JudgeOutput
## 手順5の読みの段階（ぴったり・隣・外れ。ボールのエリアへの寄せは隣に数えない）。すべて攻撃側の視点
static func read_of(restricted: PitchArea, compare: PitchArea, ball: PitchArea) -> GameEnums.ReadKind
## 手順5〜6（人数差・読み・カバー判定）。TransitionJudge のカウンターと共有する。compare は攻撃側の視点。
## 読み（detail.read）は judge が read_of で入れる（トランジションは NONE）
static func detail_at(pair: LayoutPair, compare: PitchArea, is_shot: bool) -> JudgeDetail
static func outcome_of(detail: JudgeDetail, is_shot: bool) -> GameEnums.TurnOutcome
## スルーパスの結果（ぴったり読まれたか、守備が運ぶ先へ入ってきたらロスト、それ以外は前進。defender_entered は判定の動きから出す（2026-10-28）。人数・カバーによらない。2026-10-25）
static func through_pass_outcome(detail: JudgeDetail, defender_entered: bool) -> GameEnums.TurnOutcome
## 判定の動きのうち、守備側の選手が target（攻撃側の視点）へ入ってきた動きがあるか（2026-10-28。ヒントの is_marked と共有）
static func defender_entered(movements: Array[Movement], attacker_side: GameEnums.TeamSide, target: PitchArea) -> bool
## スルーパスの受け手（target から1マス以内・ball 以外のエリアの、いちばん近い攻撃側の選手。同じなら配置の順）。
## いなければ null。MoveRules（選べるか）と apply_attack（動かす）で共有する
static func through_pass_runner(attacker: TeamLayout, ball: PitchArea, target: PitchArea) -> PlayerState
## 手順3（攻撃の手の適用。ドリブル・スルーパスの受け手の走り込みと付け直し）。判定とヒント・決定前のプレビューで共有する。
## start はターン開始の配置（省略したら pair）。付け直しのマーカーをターン開始から1マス以内に保つ
static func apply_attack(pair: LayoutPair, defender_styles: TeamStyles, ball: PitchArea, attack: TurnChoice,
        start: LayoutPair = null) -> LayoutStep
## 手順2（守備の手の適用。寄せる・下がる1人と、マンツーマンの付け直し）。適用できなければ null。判定と決定前のプレビューで共有する
static func apply_defense(pair: LayoutPair, defender_styles: TeamStyles, defense: TurnChoice) -> LayoutStep

class_name TransitionJudge extends RefCounted
## アルゴリズム6。origin は直前のターン終了時点の配置（奪取側を attacker として持つ）
## リトリートは origin の各選手の今いるエリアから、基本配置＋守備方式の目標へ1マス近づける（StyleLayoutCalculator.retreat）
static func judge(origin: LayoutPair, winner_styles: TeamStyles, loser_styles: TeamStyles,
        ball: PitchArea, winner_choice: TurnChoice, loser_choice: TurnChoice) -> JudgeOutput
## カウンターのときの奪取側の配置（カウンター型の飛び出し）。MoveRules.pos_transition_options に渡す配置にも使う
static func counter_layout(winner: TeamLayout, winner_styles: TeamStyles) -> TeamLayout
## カウンターの運ぶ先に奪取側がいなければ、ボールを持つ選手が運ぶ（OpenPlayJudge.carry_ball。判定とヒントで共有する。2026-11-05）
static func carry_if_empty(pair: LayoutPair, ball: PitchArea, target: PitchArea) -> LayoutStep
## center と上下左右の人数の合計（即時奪回の比較とヒントで共有する）
static func total_around(layout: TeamLayout, center: PitchArea) -> int

class_name MoveHints extends RefCounted
## FR-19 のヒントと、アルゴリズム8 の評価値の共通の計算。
## 「相手が何もしない」と仮定して、各手を適用した後の比較エリアの人数差とカバーの有無を出す
## 攻撃の手は攻撃の手だけを適用した後、守備の手は制限するエリアの適用前、カウンターは飛び出しの後（運ぶ先に味方がいなければ、奪った選手が運んだ後）、即時奪回は
## ボール位置と上下左右の合計で数える。リトリート・保持は比べない。陣形データを使わないため catalog 引数は持たない
static func evaluate(state: MatchState, side: GameEnums.TeamSide, options: MoveOptions) -> Array[ChoiceHint]

class_name MovePreview extends RefCounted
## 決定前のプレビュー。選んだ手を「相手が何もしない」と仮定して適用したときの、side の選手の動き（動いたチーム自身の視点）。
## 計算は判定と同じ関数（apply_attack・apply_defense・TransitionJudge.judge）を通す。トランジションの「何もしない」は、
## 奪取側の相手を即時奪回、喪失側の相手を保持とする（どちらも配置を変えない手）。選べるかは見ない。適用できなければ空
static func own_movements(state: MatchState, side: GameEnums.TeamSide, choice: TurnChoice) -> Array[Movement]
## 相手が何もしないと仮定したときの配置の並び [ターン開始時, 判定時, 次のターン開始時]（2026-11-05。プレビューで手の動きと詰め直しを
## 見せる）。結果は、攻撃は手が通る（ADVANCE）、守備はボールが動かない（STALL）、トランジションは上と同じ「何もしない」相手での判定の
## 結果。シュートは判定時まで（決まるかで置き直しが変わるため）、適用できない手・オフサイドになる手はターン開始時だけ。
## 次のターン開始時は MatchRules.preview_next（resolve_turn と同じ、判定の結果を次の状態へ反映する手順）から作る
static func team_steps(state: MatchState, side: GameEnums.TeamSide, choice: TurnChoice) -> Array[LayoutPair]
```

`JudgeOutput`（`judge_output.gd`）は `outcome: TurnOutcome`・`detail: JudgeDetail`（`NO_CONTEST` は `null`）・
`pair: LayoutPair`（判定時の配置）・`movements: Array[Movement]` を持つ。

`OpenPlayJudge` の決めごと（仕様に無い点を実装で決めたもの。2026-10-18）:
- マンツーマンの付け直し（`StyleLayoutCalculator.remark`）を行う時点は、`functional-overview.md` アルゴリズム5の手順2・3が正本
- ドリブルする選手は、ボール位置にいる攻撃側の選手のうち、固定された選手を優先し、配置の順で先の選手。
  攻撃側が固定されるのはドリブルとスルーパスの受け手だけなので、固定された選手は直前にボールを運んできたか受けた選手で、その選手に運ばせ続ける。
  誰もいなければ誰も動かさず、ボールだけが進んだものとして人数で判定する
- 動きは、守備の手 → 付け直し → ドリブル → 付け直し の順に並べる
- 選べない手（手の種類の取り違え、運ぶ先の欠け、適用できない守備の手）とボール位置の欠けでは `null` を返す。
  呼び出し側（`MatchRules`）は `MoveRules.is_allowed` で先に拒否する
- 手順7（結果の反映）は `MatchRules`（アルゴリズム7）が行う。`attacker_styles` は配置に織り込み済みのため使わない

`TransitionJudge` の決めごと（仕様に無い点を実装で決めたもの。2026-10-18）:
- カウンター型の飛び出しは、固定されていない選手だけ（方式の動きなので、アルゴリズム2の手順2に揃える）。大外かどうかは直前の配置のレーンで見る。飛び出した選手は固定しない
- リトリートの動きは1人につき1本（直前の位置 → 最終の位置、理由 `RETREAT_RESET`）。マンツーマンのマークは、飛び出した後の奪取側につく
- 即時奪回×保持の内訳は、比較エリアに `X`、人数に `X` と上下左右の隣接エリアの合計（攻撃側の人数 = 奪取側）
- 動きは、奪取側（飛び出し）→ 喪失側（リトリート）の順に並べる
- 選べない手（手の種類の取り違え、カウンターの運ぶ先の欠け）とボール位置の欠けでは `null` を返す

> ヒントと CPU の評価値を同じ関数で出すのは、利用者に見せる判断材料と CPU が使う材料を食い違わせないため。
> ヒントは判断材料を示すだけで、最善手を示さない（FR-19）。`ChoiceHint` に推奨の印は持たせない。

### 2.5 試合進行の規則（`match/`。アルゴリズム7）

1ターンの解決（アルゴリズム2〜6の組み立て）と、キックオフ・得点・ハーフ・試合終了の状態遷移を受け持つ。
アプリケーション層はこのクラスだけを呼べば1ターンを進められる。

```gdscript
class_name MatchRules extends RefCounted
## 試合を作る。kickoff_side はアプリケーション層が注入した乱数で決めて渡す
## started_at は呼び出し側が取得した時刻（ドメインでは時刻を取得しない）。陣形が無ければ null
static func create_match(match_id: String, home: TeamSetup, away: TeamSetup,
        kickoff_side: GameEnums.TeamSide, catalog: ContentCatalog, started_at: String) -> MatchState
## 盤面表示・選択肢の計算に使う、ターン開始時の両チームの配置（アルゴリズム2）
static func current_layouts(state: MatchState) -> LayoutStep
## 1ターンを解決する。どちらかの手が選択不可（範囲外の手の値を含む）、進行段階が TURN でない、試合が終わっている、
## 後半の最終ターンまで終えているなら null を返す（呼び出し側の誤り）
static func resolve_turn(state: MatchState, home_choice: TurnChoice, away_choice: TurnChoice,
        rules: MatchRuleConfig) -> TurnResolution
## 方式の選び直し（STYLE_CHANGE → TURN）。方式を差し替えるだけ（失点側のキックオフは得点の時点で済ませてある）
static func apply_style_change(state: MatchState, home: TeamStyles, away: TeamStyles) -> MatchState
## ハーフタイムの選び直し（HALFTIME → TURN）。後半のキックオフを行う
static func apply_halftime(state: MatchState, home: TeamSetup, away: TeamSetup,
        catalog: ContentCatalog) -> MatchState
## アディショナルタイムのターンか（規定の最終ターンを終えても攻撃が続いていて、まだハーフを終えていない）。
## 時計は BoardSnapshot の turn_number・turns_per_half・is_half_over から表示する（UI はドメインを呼ばない）
static func is_additional_time(state: MatchState, rules: MatchRuleConfig) -> bool
## 後半を終えたか（アディショナルタイムがあればその終わりまで。確定事項「試合終了から破棄までの順序」のやり直し判定に使う）
static func is_play_complete(state: MatchState, rules: MatchRuleConfig) -> bool
## 試合を FINISHED にした状態を返す
static func finish(state: MatchState) -> MatchState
```

`resolve_turn` が返す `next_state.stage` で、次に開く画面が決まる（`TURN` のまま／得点で `STYLE_CHANGE`／
前半終了で `HALFTIME`）。試合結果へ進むかどうかは `is_play_complete` で判断する。

`MatchRules` の決めごと（仕様に無い点を実装で決めたもの。2026-10-18）:
- `current_layouts`・`resolve_turn`・`apply_style_change`・`MoveRules.options_for` は陣形データを使わない（選手単位の
  配置状態を `MatchState` が持つ）ため、`catalog` 引数を持たない
- 得点のときは、その時点で失点側のキックオフ（キックオフ側の `M1-C`・全員をキックオフの位置へ・固定を解く。`MatchPositions.place_for_kickoff`）を済ませてから `STYLE_CHANGE` にする（選び直しの間も
  ボール位置が保持側の視点になるように）。`apply_style_change` は方式を差し替えて `TURN` に戻すだけ
- ハーフの最終ターンの判定が `LOSS`・`SAVE` でも、トランジションに入らずハーフを終える（`turn_kind` は攻守ターン、起点は `null`）
- アディショナルタイム（アルゴリズム7。2026-10-24）: ハーフを終えたかは、次のターンの番号と直前のターンの記録（`turn_records` の最後）から
  判断する（状態に印を足さない）。規定のターン数以下なら続く、規定＋最大ターン数を超えたら終える、その間は直前の結果が
  `GOAL`・`SAVE`・`LOSS`・`REGAIN` なら終える。記録が無い状態（テストで直接作った状態）は、続いている攻撃が無いので終える
- ハーフを終えた状態（`HALFTIME`・後半の終わり）の `turn_number` は 最後に行ったターン＋1（アディショナルタイムがあれば ターン数＋最大ターン数＋1 まで）。`data-definition.md` §2.1 の範囲では
  `HALFTIME` の ターン数＋1 が含まれないため、保存の作業で範囲を見直す
- （仕様の確認）攻守ターンの続き（`ADVANCE`・`STALL`）は固定を維持し、トランジションが終わって攻守ターンが始まる時だけ固定を解く（位置は戻さない。2026-10-24。アルゴリズム5の手順7と「配置区間」の定義のとおり）
- ボールの保持者（アルゴリズム7。2026-10-22）: `resolve_turn` はハーフの最終ターンの切り替えの後に、`create_match`・
  `apply_halftime` はキックオフの後に、次のターンの開始時の配置（`StyleLayoutCalculator.turn_start`）でボールのエリアに
  保持側がいなければ、いちばん近い選手を置いて固定する（トランジションは起点の配置も `TeamLayout.with_fixed` で変える）。
  置いた動き（`BALL_HOLDER`）と、膠着したドリブルの戻り（`DRIBBLE_STOPPED`）は、そのターンの記録の `movements` に足す。
  判定時の配置（`pair_at_judgement`）は変えない
- 1ターン1マス（アルゴリズム2・7。2026-10-24）:
  - `resolve_turn` は判定時の配置の現在エリアを `PlayerState.current_area` に写し戻し、各選手の `moved_in_turn` を
    「ターン開始の位置から動いたか」で付け直す（得点はキックオフで全員を基本エリアに置くので付け直さない）
  - 置ける保持者は、ターン開始の位置と今いるエリアのどちらからも、ボールのエリアが1マス以内の選手だけ。いなければ置かない。
    キックオフ（`create_match`・`apply_halftime`・得点の後）は距離を問わない
  - 膠着したドリブルの選手は、`current_area` もボールのエリア（ターン開始の位置）へ戻す。トランジションで自分で運んだ
    カウンターの膠着も同じく戻し、固定は解いたままにする（2026-11-06）
  - 選手の位置の持ち越し（キックオフのリセット・固定の解除・写し戻し・`moved_in_turn`・ドリブルの戻し・保持者を置く）は、
    `MatchRules` から呼ぶ内部のクラス `MatchPositions`（`match/`）に分けている（2026-10-24。ファイルの大きさの目安を保つため）。
    アプリケーション層は `MatchPositions` を呼ばない
- 中断データ（`data-definition.md` §2.1）は、トランジションの起点と判定時の配置を「選手単位の基本エリア・固定先」で持つ形に
  なっているが、現在エリアが無いと復元できない（ターン記録の判定前・判定時の配置も同じ）。ドメインでは `LayoutPair`（現在エリアを含む）で持つ。
  保存の作業で形式を見直す

### 2.6 CPU 思考（`cpu/`。アルゴリズム8）

```gdscript
class_name CpuPlanner extends RefCounted
## ターンの手を選ぶ。引数に相手（利用者）のそのターンの手を含めない（同時手番の公平性。FR-11）
## 選べる手が無ければ null。陣形データを使わないため catalog 引数は持たない。
## 候補 options を省くと、利用者と同じ画面に出す手（MoveMenu.options_for。2026-11-03）
static func choose_turn(state: MatchState, side: GameEnums.TeamSide,
        cpu: CpuConfig, rng: RandomNumberGenerator, options: MoveOptions = null) -> TurnChoice
## 評価値。守備の手は脅威度（攻撃側 − 守備側）、人数を比べない手（リトリート・保持・スルーパス）は 0、それ以外は 自分 − 相手
static func score(hint: ChoiceHint) -> float
## 方式の癖の加点。CPU の方式が好む手なら cpu.style_bonus、そうでなければ 0（好む手の表はアルゴリズム8）
static func style_bonus(hint: ChoiceHint, styles: TeamStyles, ball: PitchArea, cpu: CpuConfig) -> float
## 局面の加点。攻撃の手・カウンターは forward_bonus × 前へ進む列数、シュートは shot_bonus、守備の手は anticipation_bonus × ボールより前の列数、ほかは 0（アルゴリズム8）
static func situation_bonus(hint: ChoiceHint, ball: PitchArea, cpu: CpuConfig) -> float
## 選べる手（MoveHints.evaluate の並び）ごとの選択確率。score + style_bonus + situation_bonus − オフサイドの減点 − マーク注意の減点を probabilities に通す（choose_turn と同じ計算）
static func turn_probabilities(state: MatchState, side: GameEnums.TeamSide, cpu: CpuConfig) -> Array[float]
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
static func formation_profile(formation: FormationDef) -> Array[MatchupNote]
static func style_profile(style_id: String, catalog: ContentCatalog) -> Array[MatchupNote]

class_name FormationTags extends RefCounted
static func derive(formation: FormationDef) -> Array[String]   # 座標から導くタグ（移植元の deriveTags）
static func of(formation: FormationDef) -> Array[String]       # derive に extra_tags を足したもの（ルールの当てはめはこちら）
const KNOWN: Array[String]                                     # 導出するタグと extra_tags に書けるタグ（静的データの検証）
```

> 2026-11-03 に作った。`formation_matchup` は `FORMATION` ルールを配列の順に見て、viewer のタグが `viewer_tags` を、opponent のタグが
> `opponent_tags` をすべて持つものを、同じテーマは先の1件だけ採る。0件なら `catalog.matchup_fallback`。`style_matchup` は
> viewer の守備方式 × opponent の攻撃方式、viewer の攻撃方式 × opponent の守備方式の順。単独の解説は「特徴: 」「強み: 」「弱み: 」を
> 頭に付けた3件で、陣形の特徴は `description`。`style_profile` は方式1件ごと（守備・攻撃をまとめるのは `LibraryService.style_notes`）。

`MatchupNote.simplification_ids` に単純化 ID があれば、UI は単純化カタログの「実戦では」を添える（FR-23）。
ID は静的データ（`styles.json`・`matchup_rules.json` の `simplification_ids`）に、文の内容とゲームでの扱いが直接重なるものだけを書く
（2026-11-03。保持型と保持型が関わる方式ルール S01・S03・S05・S06 に SIM-02、最終ラインとの間・背後を突く R07・R12 に SIM-01、
サイドの1対1の R02・R13 に SIM-03、挟み込むプレッシングの R14 に SIM-08。ゾーン・マンツーマンは SIM-07。
守備的MF の脇・背後を突く R10 は最終ラインの調整ではないので付けない）。
S-04 は解説の欄が2つ（直前の噛み合わせ・選んだ方式）あり、同じ「実戦では」の重なりは欄ごとに除く（欄をまたいでは除かない）。

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
var library: LibraryService   # _ready で ContentRepository.load_catalog() から作る（静的データの誤りは空のカタログになり、ContentRepository が push_error する）
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

## 次の2つは UI とアプリケーション層の両方が読むので AppScreens に置く（AppScreens.SuspendedStatus・AppScreens.StartupResult。2026-10-29）
## NONE: なし／RESUMABLE: 再開できる（再開カードを出す）／FINALIZE_PENDING: 終了処理（戦績の記録）が済んでいない試合が残っている
# enum SuspendedStatus { NONE, RESUMABLE, FINALIZE_PENDING }
# enum StartupResult { NONE, RESUMABLE, FINALIZED, FINALIZE_FAILED, CORRUPTED }

signal state_changed(snapshot: BoardSnapshot)   # 盤面・スコア・相手の方式が変わった。ターンの途中（submit_turn の中）では出さず、continue_after_reveal()・方式の選び直し・ハーフタイムの確定の後に出す（試合画面は、これを受けて次のターンを始める）
signal turn_resolved(reveal: RevealView, snapshot: BoardSnapshot)  # 開示（駒とボールの動きと判定理由の表示に使う）
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
## 決定前のプレビュー（利用者の視点の手 → 利用者の選手の動き。利用者の視点）。手を選べないときは空
func user_preview(user_choice: TurnChoice) -> Array[Movement]
## 決定前のプレビューの配置の並び（MovePreview.team_steps を、利用者の選手の並び（BoardSnapshot.user_players と同じ形）にしたもの。2026-11-05）
func user_preview_frames(user_choice: TurnChoice) -> Array
func preview_style() -> Dictionary              # 決定前のプレビューの時間 {"move_sec", "hold_sec"}（PresentationConfig。2026-11-05）
## 選択不可の手なら false を返し、状態を変えない（push_error で記録する）
func submit_turn(user_choice: TurnChoice) -> bool
## 開示（駒とボールの動きと判定理由）を利用者が確認した後に呼ぶ。進行段階に応じて次の画面を App に要求する
func continue_after_reveal() -> void
func submit_style_change(user_styles: TeamStyles) -> void
func submit_halftime(user_setup: TeamSetup) -> void
func opponent_setup() -> TeamSetup               # 開示済みの相手の陣形・方式（FR-16・21）
func snapshot() -> BoardSnapshot                 # 現在の盤面・スコア（画面を開いたときの初期表示）。試合の開始前は、suspended_status() が RESUMABLE のときに中断データの状態を返す（タイトルの再開カード用）
func board_play_sec() -> float                   # 開示の1拍目（プレー。判定前 → 判定時）で駒とボールを動かす時間（PresentationConfig。2026-11-03）
func board_settle_sec() -> float                  # 開示の2拍目（詰め直し。判定時 → 次のターン開始時）で駒を動かす時間（PresentationConfig。2026-10-22 に board_shift_sec として足し、2026-11-03 に2拍目の時間にして改名した）
func board_result_sec() -> float                 # 開示の1拍目の終わりから結果の演出を出す時間（PresentationConfig。2026-11-03）
func piece_style() -> Dictionary                 # 開示の駒の動きの値 {"stagger": ずらしの幅, "hop": 弾みの高さ（駒の半径の何倍か）}（PresentationConfig。2026-11-05）
func board_beat_gap_sec() -> float               # 開示の拍と拍の間の小休止（秒。PresentationConfig。2026-11-05）
func ball_style() -> Dictionary                  # 開示の1拍目のボールの軌道の値 {"loft", "touch", "touches"}（PresentationConfig。高さはボールの半径の何倍か。2026-11-03）
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

> **2026-10-19 時点で作った範囲**: 試合の開始・選べる手とヒント・1ターンの確定と開示・方式の選び直し・ハーフタイム
> （`start_match`・`user_options`・`user_hints`・`submit_turn`・`continue_after_reveal`・`submit_style_change`・
> `submit_halftime`・`opponent_setup`・`snapshot`）。あわせて `is_match_started()`・`is_match_over()`・`last_reveal()`・
> `state()`（状態の写し）を足した。
> - `start_match` は `bool` を返す（陣形が無ければ `false`）。成功したら `state_changed` も出す。
> - `start_match`・`submit_style_change`・`submit_halftime` が成功したら、試合画面（S-03）を要求する（各画面の詳細設計のとおり、
>   試合の中の画面の切り替えはコントローラーが頼む）。`leave_result() -> bool` は、試合が終わっていればタイトル（S-01）を
>   要求して `true`、終わる前は `push_error` して `false`。終了処理（戦績・中断データの削除）は保存・戦績の作業で足す。
> - `submit_turn` の後は、`continue_after_reveal` を呼ぶまで `submit_turn`・`submit_style_change`・`submit_halftime` は
>   `false` を返す（確定の二度押しで開示を飛ばさない。得点・ハーフタイムの画面を経ずに再開しない）。確認待ちの開示が
>   無いときの `continue_after_reveal` は何もしない。
> - `BoardSnapshot.movements` は直前のターンの動き。方式の選び直し・ハーフタイムで配置を作り直した後は空。
> - 試合の開始前に `snapshot`・`user_options`・`user_hints`・`opponent_setup` を呼ぶと push_error して `null`（ヒントは空）を
>   返す。UI は `is_match_started()` で確かめてから呼ぶ。タイトルの再開カードは `snapshot()` ではなく `suspended_snapshot()`
>   （再開できる中断データの盤面。無ければ `null`）を使う（2026-10-29。試合中の盤面と中断データの盤面を1つの関数で
>   切り替えると、試合中なのか中断中なのかを呼び出し側が見分けられないため）。
> - 作り方は `_init(catalog: ContentCatalog, config: ConfigRepository, rng: RandomNumberGenerator, opponent: OpponentPolicy,
>   request_screen: Callable, assert_on_invalid_cpu: bool = OS.is_debug_build())`。画面の切り替えは `App.request_screen` を
>   注入して頼む（テストで要求を記録するため）。CPU の手が選べないときに `assert` で止めるかは引数で決める（書き出し版の
>   置き換えの経路をテストするため）。設計書の `content`・`store`・`user_data`・`is_tutorial` は、保存・戦績・チュートリアルの作業で足す
> - `submit_style_change`・`submit_halftime` は、進行段階が違えば何もせず `false` を返す
> - 終了処理・チュートリアルは、それぞれの作業で作る
>
> **2026-10-29 に足した範囲（中断・再開）**: `inspect_suspended`・`suspended_status`・`suspended_snapshot`・`resume`・
> `has_unsaved_progress`・`suspend_to_title`、保存の時点①〜④、`leave_result` での中断データの削除。
> - 保存先は `_init` の最後の引数 `store: SuspendedMatchStore = null`（`null` なら保存しない。保存を確かめないテストと
>   チュートリアル用）。設計の `content`・`is_tutorial` の引数は足さない（`user_data` は戦績の作業で足した）。チュートリアル用の
>   インスタンスは、保存先・戦績の記録先を `null` にし、画面の切り替えの要求を捨てる関数を渡して作る（`App.new_tutorial_controller()`。
>   2026-10-29。`is_tutorial` の役目は、この組み合わせで果たす）
> - 保存・読み込みの失敗は `signal storage_failed(kind)` で知らせ、`App` が `storage_error` へ中継する。通知は失敗が続く間は
>   最初の1回だけ出し、次に保存に成功したら戻す
> - 保存の失敗の扱いと再開カード用の写しは `SuspendKeeper`（`application/suspend_keeper.gd`）が持つ
> - `SuspendedStatus`・`StartupResult` は、UI（タイトル・`NewMatchGate`）とアプリケーション層の両方が読むので、`MatchController` の
>   内側ではなく `AppScreens` に置いた（`coding-gdscript.md`「enum はクラスに属させる」）。
>   値は上の設計のとおり（戦績の作業で、仮の `DISCARDED` を `FINALIZED`・`FINALIZE_FAILED` に替え、`FINALIZE_PENDING` を足した）
> - `start_match` の保存に失敗したら、前の試合の中断データを消す（上書きできないまま残ると、新しい試合を中断したときに
>   前の試合を再開してしまうため）
> - `suspend_to_title` はメモリ上の試合を閉じ、保存されている中断データを読み直して再開カード用の写しにしてから、タイトルを頼む
> - 再開した試合の `last_goal_by` は、ターン記録の最後の `GOAL` の攻撃側
>
> **2026-10-29 に足した範囲（チュートリアル）**: `start_tutorial_step(step) -> bool`。段階の盤面を `MatchRules.create_scene` で作り
> （両チームを基本配置に置き、ボールを持つ側の最寄りの選手をボールの位置に立たせる。トランジションはその配置を起点にする）、
> 相手が `ScriptedOpponent` なら台本をその段階の手に差し替える（`use_step`）。盤面の無い段階・作れない盤面は `push_error` して `false`。
> 画面の切り替えは頼まず `state_changed` も出さない（チュートリアルの画面が自分で描き直す）。開示を確認していなくても次の段階で作り直せる
>
> **2026-10-29 に足した範囲（戦績）**: 試合の終了処理とそのやり直し（`retry_pending_finalize`・`final_record`・
> `leave_result` の終了処理のやり直し・`inspect_suspended` の `FINALIZED`／`FINALIZE_FAILED`・`suspended_status` の `FINALIZE_PENDING`）。
> - 戦績の記録先は `_init` の最後の引数 `user_data: UserDataService = null`（`null` なら記録は成功した扱い）
> - 終了処理（記録 → `FINISHED` → 保存）は `MatchFinalizer`（`application/match_finalizer.gd`）が行う。最終ターンでは、保存の時点①の
>   `IN_PROGRESS` の保存の後に終了処理をする（記録に失敗しても、最終ターンまでの状態が残る）
> - 終了処理待ちの試合は `SuspendKeeper` が持つ（`pending()`・`keep_pending()`）。起動時に見つけたら、その場でやり直す
> - 戦績の終了日時は、最初に終了処理を試みた時刻。起動時・CPU 対戦の前のやり直しは、やり直した時刻（最終ターンの時刻は持っていない）
> - 試合を終えた後（最終ターンの判定理由）は `suspend_to_title` が `false` を返し、試合画面もメニューを開かない（中断で結果画面と
>   終了処理を飛ばさない）
> - `final_record()` は試合が終わる前は `push_error` して `null`。推移は `ReviewAggregator.segments`（振り返りの時間帯と同じ区切り）の始まり

**保存の時点**（正本は `functional-overview.md`「確定事項」の保存の時点）は、次のメソッドの中で
`SuspendedMatchStore.save()` を呼ぶことで実現する。チュートリアル用のインスタンスは保存しない。

| 確定事項の時点 | 呼ぶメソッド |
|---|---|
| ① ターンの確定時 | `submit_turn`（`MatchRules.resolve_turn` の直後。開示より前） |
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

基底クラスの各関数は `push_error` して `null` を返す（直接使わない）。`CpuOpponent` は `_init(catalog, cpu: CpuConfig,
rng: RandomNumberGenerator)` で作り、`CpuPlanner` を呼ぶ。

`MatchController` は相手の手をこのインターフェース経由で得る。`choose_turn` は利用者の手を受け取らないので、
利用者の手を参照できない形になっている（FR-11）。後続マイルストーンのローカル2人対戦は、ここに
「もう1人の利用者の入力」を足して対応する。

### 3.4 画面向けの参照・保存（`LibraryService`・`UserDataService`。モジュール構成図の A2）

> 2026-10-18 時点で作ったのは `LibraryService` の `formations()`・`base_counts()` だけ（試合準備の作業）。`LibraryService.new(catalog: ContentCatalog)` で作り、
> `formations()` は呼び出し側が並べ替えても影響しないよう配列をコピーして返す。ほかの関数は、それを使う画面の作業で足す。
> 2026-10-29（チュートリアルの作業）に `simplifications()`・`tutorial_steps()` を足した（配列は写し、中の値は読むだけ）。

```gdscript
class_name LibraryService extends RefCounted
func formations() -> Array[FormationDef]
func base_counts(formation_id: String) -> Dictionary        # PitchArea のキー → 人数（試合準備のミニピッチ。そのチーム自身の視点）。存在しない陣形なら push_error して空
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

> 2026-10-29 時点で作ったのは戦績（`records()`・`append_record()`・`totals()`）と設定（`settings()`・`save_settings()`・
> `mark_tutorial_completed()`）。`UserDataService.new(record_store: RecordStore, settings_store: SettingsStore)` で作り、
> `App.user_data` に置く。失敗は `signal storage_failed(kind)` で知らせ、`App` が `storage_error` へ中継する。`records()` は写しを返し、
> 終了日時の新しい順（同じ日時は後に記録したものが先）。`settings()` も写しを返す（画面が書き換えても、保存するまで持っている値は
> 変わらない）。`save_settings()` は失敗しても持っている値を更新する（画面上の値を保つ）。保存の失敗の通知は、データごとに
> 失敗が続く間は最初の1回だけ。
>
> 2026-10-31（理解度チェックの作業）に回答結果（`quiz_progress()`・`save_quiz_answer()`）を足した。
> `UserDataService.new(record_store, settings_store, quiz_store: QuizAnswerStore, questions: Array[QuizQuestionDef])` で作る
> （`questions` は正答状況の分母と、問題 ID → 学習目標。`App` が `library.quiz_questions()` を渡す）。`quiz.json` に無い問題の回答は数えない。
> `save_quiz_answer()` は保存に失敗した回答を持っておき（画面の正答状況に含める）、次の回答のときに古いものから書き直す
> （書き直さないと、次の保存が成功してファイルを読み直した時点で、失敗した回答が集計から黙って消えるため）。読み込み・保存の失敗の通知は戦績と同じ。
> `LibraryService` には `principle()`・`quiz_questions()`（写し）を足した。
>
> 2026-11-03（戦術の解説の作業）に `matchup_counts()`・`formation_notes()`・`style_notes()`・`defense_style_notes()`・`attack_style_notes()` を
> 足した。`matchup_counts` は30エリアすべてのキーを持つ（相手の基本配置は `PitchArea.mirrored()` で利用者の視点へ）。解説には見出し
> （`MatchupNote.label`）を付ける: 単独の解説は「陣形 4-4-2」「守備方式 ゾーン」「攻撃方式 保持型」、相手との噛み合わせは
> 「こちらの狙いどころ」「相手の狙いどころ」「方式の噛み合わせ」。相手の狙いどころは相手から見た文なので「相手」を「こちら」に
> 言い換える。同じ陣形どうしは両側が同じになるので、相手の狙いどころを出さない。存在しない陣形は `push_error` して空。

`bool` を返すメソッドは、保存に失敗したら `false` を返し、`App.storage_error` を出す（通知を出すのは
`UserDataService` だけ。`append_record` を呼んだ `MatchController` は、`false` を受けても通知を重ねて出さない）。読み込みに失敗した
データは初期状態として返す（エラーハンドリングの正本どおり）。

`UserDataService` は、戦績・回答結果・設定を最初に使うときに1回だけ読み込み、結果をメモリに持つ（画面を開くたび・
手の選択のたびに読み直さない）。読み込みの失敗の通知も、その1回だけ出す。保存したら、持っている値も更新する。

### 3.5 画面に渡す値（`BoardSnapshot`・`RevealView`・`ReviewView`）

どちらもアプリケーション層の値で、**利用者の視点に揃えてある**（§1.2）。UI は座標の変換もルールの計算もせず、
これを描くだけにする。変換は `ViewConverter`（`view_converter.gd`。`MatchController` だけが使う）が行う。
利用者 = `HOME` なので、`AWAY` の視点の値（CPU の選手と動き、CPU が攻撃側のときの選択の運ぶ先・比較エリア・
ボール位置）を鏡像にする。

> 2026-10-19 時点の実装の形: 選手は `{"player_id", "number", "area"}` の Dictionary の配列。`last_goal_by` はまだ得点が
> 無ければ -1。`RevealView` は判定前・判定時の配置を `user_players_before`・`opponent_players_before`・
> `user_players_at_judgement`・`opponent_players_at_judgement` の4つで持ち、内訳の有無を `has_detail`、局面を
> `turn_kind` で持つ。`simplification_ids` は単純化カタログを扱う作業まで空。振り返りの各ターンの見出し用に、
> そのターンの `half`・`turn_number` も持つ（2026-10-29）。

`BoardSnapshot`（`board_snapshot.gd`）は、試合画面・ハーフタイム・方式の選び直しが表示する現在の状態。

| フィールド | 内容 |
|---|---|
| `user_players` / `opponent_players` | 選手ごとの現在の位置（各要素は `player_id`・`number`（背番号）・`area`（利用者の視点のエリアのキー））。現在の配置（`MatchRules.current_layouts`）から `MatchController` が作る。駒の表示に使う（作戦ボードは番号を描かない。背番号は、3D 演出（2026-10-23 にやめた）の表示用に持っていたもの） |
| `user_counts` / `opponent_counts` | 30エリアの人数（`PitchArea` のキー → 人数）。`user_players` / `opponent_players` をエリアごとに数えた値と一致する |
| `ball_area` | ボール位置 |
| `user_has_ball` | 利用者がボールを持っているか |
| `last_goal_by` | 直前の得点の側（`HOME`／`AWAY`。まだ得点が無ければ空）。方式の選び直しの「〜が得点しました」に使う |
| `turn_kind` / `half` / `turn_number` / `turns_per_half` / `is_half_over` | 局面と残りターンの表示用。`is_half_over` はハーフを終えた後の盤面か（ハーフタイム・試合終了。時計は最後に行ったターンを出す。2026-10-24） |
| `score_user` / `score_opponent` | スコア |
| `user_setup` / `opponent_setup` | 陣形と方式（相手の方式の常時表示。FR-16・21） |
| `movements` | 直前の判定で動いた選手（利用者の視点に変換済み）。矢印の表示に使う |
| `offside_line_zone` | 相手のオフサイドライン（利用者の視点の列。`OffsideRule.line_row`）。利用者が保持する攻守ターンだけ、それ以外は -1（2026-10-25） |

試合の作戦ボードは優劣記号を描かず、エリアの中の駒の数で優劣を示す（2026-10-22。`functional-overview.md`「表示仕様」）。
ミニピッチの優劣記号（`▲`・`＝`・`▼`）は人数の比較だけで決まるので、UI が人数から描く。

`RevealView`（`reveal_view.gd`）は、1ターンの開示（両者の選択・開示の動き・判定理由）と振り返りの各ターンに使う値。
`MatchController` が `TurnRecord` から作る。

| フィールド | 内容 |
|---|---|
| `user_role` | 利用者の役割。`GameEnums.Phase`（攻撃側＝`ATTACK`／守備側＝`DEFENSE`／喪失側＝`NEG_TRANSITION`／奪取側＝`POS_TRANSITION`）。判定理由の文の主語を決める |
| `user_choice` / `opponent_choice` | 両者の手と、運ぶ先・寄せるエリア |
| `outcome` | ターン結果（`TurnOutcome`） |
| `compare_area` / `user_count` / `opponent_count` / `cover` / `read` | 判定の内訳（`NO_CONTEST` では空。`read` は判定理由の「読まれて」「隣を読まれて」に使う） |
| `ball_before` / `ball_after` | 判定前後のボール位置 |
| `players_before` / `players_at_judgement` | 両チームの選手単位の配置（判定前・判定時）。各要素は `BoardSnapshot.user_players` と同じ形（`player_id`・`number`・`area`。利用者の視点）。開示の動き（1拍目の判定前 → 判定時、2拍目の判定時 → 次のターン開始時）と、振り返りのミニピッチ（判定時の人数はエリアごとに数えるだけ）に使う |
| `movements` | 選手の動き（方式の動き → 守備の手 → 攻撃の手の順） |
| `simplification_ids` | 判定に関わる単純化 ID（「実戦では」の表示に使う） |

`ReviewView`（`review_view.gd`）は、振り返り画面に渡す値。ドメインの `ReviewSummary`（集計値と、得失点の流れに
含めるターンの通し番号）を `MatchController` が受け取り、各ターンを `RevealView` に変換して添える。ドメインの値は
アプリケーション層の型を持たない（`ReviewSummary` は `RevealView` を含まない）。

> 2026-10-29 時点の実装の形: 変換は `ViewConverter.review(records, catalog, lookback_turns)`（利用者 = `HOME` を viewer に
> して集計するので、エリア・局面はすでに利用者の視点）。`area_tallies`・`phase_tallies` は `ReviewSummary` の写し。
> `goals` は得点ごとの `{"is_user", "half", "turn_number", "score_user", "score_opponent", "turns": Array[RevealView]}`
> （`turns` は直前のターン → 得点のターンの順）、`segments` は `{"half", "from_turn", "to_turn", "user_setup", "opponent_setup"}`。
> ほかに `turn_count`（0 なら振り返るデータが無い）と、アディショナルタイムを「前半 15＋1」と出すための `turns_per_half` を持つ。
> `review()` は試合前なら `push_error` して `null`。

## 4. データ層（`game/data/`）

**責務**: 静的データ・調整値の読み込みと値オブジェクトへの変換、端末内保存の読み書き（`architecture-overview.md`
「データ層」）。

### 4.1 静的データ（`ContentRepository`）

```gdscript
class_name ContentRepository extends RefCounted
## content_dir はテストで別の場所を読ませるための引数。アプリは既定値を使う
func _init(content_dir: String = "res://content")
## game/content/*.json を読み、検証して ContentCatalog に変換する。誤りが1件でもあれば空の ContentCatalog を返す
## （一部だけ正しいデータで動き続けないため）。誤りは push_error でも出す
func load_catalog() -> ContentCatalog
## 検証で見つかった誤り（ID の重複、存在しない原則 ID の参照など）。空なら正常。まだ読んでいなければ読む。
## 形は "<ファイル名>: <場所（例 formations[1].players[3].number）>: <理由>"
func validation_errors() -> Array[String]
```

静的データはアプリに同梱するため、読み込みの失敗は開発時の誤りとして扱う。NFR-17 の自動テストが
`validation_errors()` が空であることを確かめる。ファイルの一覧は `repository-structure.md`「game/content/」。

> 2026-11-03 に `styles.json`・`matchup_rules.json` を足した。形・範囲（4方式・方式の種類・ルールの条件のタグと方式・原則と単純化が
> カタログにある・代わりの文）は `CommentaryContentReader`（`data/commentary_content_reader.gd`）が確かめる。陣形の強み・弱み・原則 ID と、
> `extra_tags` が既知のタグであることは `ContentRepository` が確かめる。16通りの両側に解説が出るか・移植したルールがどれも採用されうるかは、
> テスト（`tests/content/commentary_content_test.gd`）で確かめる。
>
> 2026-10-31 に `principles.json`・`quiz.json` を足した。形・範囲（各チーム10人・学習目標ごとに2問以上・プレイテストの問題がちょうど2問・
> 原則がカタログにある）は `QuizContentReader`（`data/quiz_content_reader.gd`）が確かめる。原則の ID と件数がカタログと一致するか、
> 問題の文の人数・陣形が場面の図とゲームの基本配置と食い違わないかは、テスト（`tests/content/quiz_content_test.gd`）で確かめる。
>
> 2026-10-29 時点で読むのは `formations.json`・`simplifications.json`・`tutorial.json`。単純化とチュートリアルの形・範囲は
> `TutorialContentReader`（`data/tutorial_content_reader.gd`。項目の読み出しは `SaveDataReader`）が確かめる。段階の陣形は、読み込んだ陣形ではなく
> MVP の陣形の ID（`ContentRepository.FORMATION_IDS`）で確かめる（陣形の誤り1件が、段階の数だけ誤りを増やさないため）。
> 段階の手が試合の規則で選べるか・7要素を網羅するか・単純化の ID と件数がカタログと一致するかは、テスト（`tests/content/tutorial_content_test.gd`）で確かめる
> （ルールの計算が要るため、読み込みでは確かめない）。手の名前と区分値の対応は `TurnChoice.ACTION_ENUMS`、局面の手の種類は `TurnChoice.family_for`。

### 4.2 調整値（`ConfigRepository`）

`functional-overview.md`「設定値として外部化する値」を、適用先ごとに分けた Resource で持つ（kit の
`coding-gdscript.md`「性質の違う設定を1つの Resource に混ぜない」）。Resource のクラス（スクリプト）は
ドメインが引数で受け取るため `game/domain/config/` に置き、`.tres` の読み込みだけをデータ層が行う（§7）。

| Resource（`class_name`） | ファイル（`game/config/`） | 持つ値 |
|---|---|---|
| `MatchRuleConfig` | `match_rule_config.tres` | 1ハーフのターン数・アディショナルタイムの最大ターン数 |
| `CpuConfig` | `cpu_config.tres` | 温度 τ・下限確率 floor・方式の癖の加点 style_bonus・前へ運ぶ加点 forward_bonus・シュートの加点 shot_bonus・守備の先読みの加点 anticipation_bonus・オフサイドの減点 offside_penalty（2026-10-25）・マーク注意の減点 marked_penalty（2026-10-29） |
| `PresentationConfig` | `presentation_config.tres` | 開示の1拍目・2拍目で駒を動かす時間（秒）・結果の演出を出す時間（秒）・1拍目のボールの軌道（浮き球の高さ・ドリブルの弾みの高さと回数）・駒の動き（ずらしの幅・弾みの高さ）・拍の間の小休止（秒）・決定前のプレビューの動く時間と止める時間（秒）・振り返りで遡るターン数 |
| `VerificationConfig` | `verification_config.tres` | 自己対戦検証の各組み合わせの試合数（テストだけが読む） |

```gdscript
class_name ConfigRepository extends RefCounted
func match_rules() -> MatchRuleConfig      # 値が範囲外なら初期値の Resource を返す（エラーハンドリング「設定値が不正」）
func cpu() -> CpuConfig
func presentation() -> PresentationConfig
```

値の範囲: ターン数は1以上、アディショナルタイムの最大ターン数は0以上・ターン数以下、τ は0より大きい、floor は0以上1未満、style_bonus・forward_bonus・shot_bonus・anticipation_bonus は0以上（いずれも有限の値）、駒を動かす時間（1拍目・2拍目とも）と結果の演出を出す時間は0より大きく2以下、浮き球の高さは0以上20以下・ドリブルの弾みの高さは0以上5以下（有限の値）・弾みの回数は1以上8以下、駒のずらしの幅は0以上0.8以下・駒の弾みの高さは0以上1.5以下・拍の間の小休止は0以上0.5以下（有限の値）、プレビューの動く時間は0より大きく2以下・止める時間は0以上2以下、遡るターン数は
0以上。初期値は各 Resource の `@export` の既定値として持ち、`functional-overview.md` の表と一致させる。

> 2026-10-19 時点で作ったのは `match_rules()`・`cpu()`。`ConfigRepository.new(config_dir = "res://config")` で作り
> （テストで別の場所を読ませるための引数）、1回読んだ値を持っておく。ファイルが無い・型が違う・範囲外のときは、
> 初期値の Resource を返して `push_error` する（エラーハンドリング「設定値が不正」: 利用者には表示しない）。範囲は
> 内側にあることを肯定形で確かめ、`is_finite` で NaN・無限大を拒否する。同梱の `.tres` が範囲内であることはテストで確かめる
>
> 2026-10-22 に `presentation()` を足した。`PresentationConfig` は、開示で駒を動かす時間（1拍目 `board_play_sec`・2拍目 `board_settle_sec`。
> 2026-11-03 に2拍にした）と、
> 振り返りで遡るターン数（`review_lookback_turns`。2026-10-29 に足した。0 以上）を持つ。3D 演出の上限は、3D 演出をやめたので持たない（2026-10-23）。

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

> 2026-10-31（理解度チェックの作業）: 戦績と回答結果は、破損・新しい版の扱い（下記）と書き込みの手順が同じなので、
> `VersionedJsonFile`（`data/versioned_json_file.gd`）に1つにした。`RecordStore`・`QuizAnswerStore` は、中身の形と検証（decode）と
> 追記の規則（戦績は同じ試合 ID を書かない・大きさの上限、回答結果は件数の上限 30,000）だけを持つ。`LoadState` も
> `VersionedJsonFile.LoadState` に移した（`SettingsStore` は ConfigFile でキー単位に直すので、自分の enum を持つ）。

**破損・新しい版のときに元のファイルを失わない**（戦績・回答結果・設定）:
- **破損**: 読み込みで破損と判定したら、本体を `<名前>.corrupt-<YYYYMMDD-HHMMSS>` へ名前を変えて退避してから、
  初期状態として扱う。次の保存は新しいファイルとして書く（退避したファイルは自動では消さない）
- **新しい版**（`format_version` が今の版より新しい）: 破損とは区別する。初期状態を表示するが、そのファイルへは
  書き込まない（保存は `false`。`App.storage_error(USER_DATA_NEWER)`）。古い版のアプリで開いたときに、新しい版の
  データを上書きしないため
- 中断データは対象外とする（破損・新しい版は削除する。削除の時点④）。進行中の1試合だけで、戦績と違って
  積み重ねたデータではないため

**JSON の共通の形**: 最上位に形式のバージョンを持たせる（`architecture-overview.md`「保存データの形式の
バージョン」）。キーは snake_case、区分値は enum の名前、エリアは `"M2-L1"` 形式（列-レーン）、日時は端末のローカル時刻の
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
    "ball_area": "M2-L1",
    "first_half_kickoff": "AWAY",
    "score": { "HOME": 0, "AWAY": 1 },
    "setups": {
      "HOME": { "formation_id": "4-3-3", "defense": "ZONE", "attack": "POSSESSION" },
      "AWAY": { "formation_id": "4-4-2", "defense": "MAN", "attack": "COUNTER" }
    },
    "players": {
      "HOME": [ { "player_id": "433-LB", "base_area": "D2-L2", "fixed_area": null } ],
      "AWAY": [ { "player_id": "442-ST1", "base_area": "A2-L1", "fixed_area": "M2-C" } ]
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
- 件数が上限を超える（中断データの `turn_records` が「（1ハーフのターン数＋アディショナルタイムの最大ターン数）× 2」を超える、など）

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

> **2026-10-29 時点の実装の形（中断データ）**: `SaveFileIO` は `static` の `write(path, text)`・`read(path, is_valid)`
> （`is_valid` が偽なら `.bak` を読む）・`exists`・`delete`。中断データの形は `SuspendedMatchEncoder`、読み込みと検証は
> `SuspendedMatchDecoder`（`ContentCatalog` と `MatchRuleConfig` を受け取る。誤りは `errors()` で読める。改変された保存データは
> 利用者の誤りではないので `push_error` しない）、項目の読み出しは `SaveDataReader`（型・必須・範囲を確かめ、外れた項目を
> 「場所: 理由」で積む）。`SuspendedMatchStore` は `_init(catalog, rules, dir = "user://")`、`load()` は `SuspendedLoad`
> （`status: NONE / OK / CORRUPTED`・`state`）。配置の組には `attacker_side` を書く（`data-definition.md` §2.1）。
> 保存の置き場所は `App.save_dir`（既定 `user://`。テストは一時ディレクトリを渡す）。
> `SaveMigrator` は、形式の版が 1 だけで変換する対象が無いので、まだ作っていない（形式を変える作業で作る）。
>
> **2026-10-29 時点の実装の形（設定）**: `SettingsStore` は `_init(dir = "user://")`。`load()`・`load_state()`・`save()`。
> ConfigFile の文字列（`encode_to_text`）を `SaveFileIO.write` で書く。**読み込みは `ConfigFile.parse` を使わない**
> （値の `Object(...)`・`Resource(...)` からオブジェクトを作り、リソースを読み込むため。利用者が書き換えられるファイルでそれを起こさない）。
> `SettingsStore.parse` が「[節]」「キー=値」「;・# の注釈」「空行」だけを受け付け、値は整数・小数・true・false。単純な文字列と英字だけの語は
> 型違いとしてキーごとに初期値、組み立てる書き方（`Vector2(...)` など）を含むファイルは破損。`.bak` を使うかの判断は「この書式で読めて、
> `format_version` が 1 以上の整数」（書式で読めなくても、`format_version=<整数>` の行が今の版より新しければ新しい版として扱い、書き込まない）。本体が壊れていて `.bak` が読めるときは、壊れた本体を退避してから `.bak` を使う（戦績と同じ）。
> キーの外れ（音量が有限の 0.0〜1.0 の数でない、真偽値が bool でない、無い）はそのキーだけ初期値。
> 退避（`<名前>.corrupt-<日時>`。同じ秒なら連番）は `SaveFileIO.move_aside` にまとめ、戦績と共用する。
> 音量のバス `BGM`・`SE` は `game/default_bus_layout.tres`。ライセンスの本文（`OFL.txt`）は書き出しの `include_filter` に入れる。
>
> **2026-10-29 時点の実装の形（戦績）**: `RecordStore` は `_init(rules, dir = "user://")`。`append` のたびにファイルを読み直す
> （直前に解析した・書いた文字列と結果だけを覚え、同じ中身は解析し直さない）。本体が壊れていて `.bak` が読めるときは、壊れた本体を
> 退避してから `.bak` を使う（退避しないと、次の書き込みで本体が `.bak` へ回されて消えるため）。
> 形と検証は `MatchRecordCodec`（陣形と方式の形は中断データと同じ `SuspendedMatchEncoder.setup_fields`。陣形 ID は、陣形を減らした
> 後も過去の戦績を破損にしないよう、ID の形（`ContentRepository.ID_PATTERN`）だけを確かめ、カタログにあるかは見ない）。`.bak` を使うかの判断は「読めて検証が通る、または
> 新しい版」。破損を退避できなかったときは、壊れたファイルを上書きしないよう `append` は `false`。戦績1件は `MatchRecord`、
> 推移の1区切りは `RecordPeriod`（`half`・`from_turn`・`user_setup`・`cpu_setup`）。`MatchRecord.of(state, finished_at)` で作る。

## 5. UI 層（`game/ui/`）

**責務**: 画面の表示・入力・作戦ボード（開示の動きを含む。`architecture-overview.md`「UI 層」）。`App` の
サービスを呼び、シグナルを受けて描き直す。データ層には触らない。

### 5.1 画面の切り替え（`MainShell`）

`ui/main_shell.tscn` をメインシーンにする。`App.screen_requested` を受けて、子にある画面のシーンを入れ替える。
画面どうしは直接遷移せず、遷移は必ず `App` を経由する（遷移の正本は `functional-overview.md`「画面遷移図」）。
起動時は `MatchController.inspect_suspended()` と `UserDataService.settings()` を呼んでからタイトルを開く。
タイトルを開く前に出た `App.storage_error`（中断データの破損など）は `MainShell` が保持し、タイトルを開いてから
通知（`ToastView`）で表示する。

```gdscript
class_name MainShell extends Control
## 画面 ID → シーンのパス。画面を作ったら1行足す（タイトルのカードも自動で押せるようになる）
const SCREEN_SCENES: Dictionary
## 画面のシーンがあるか（タイトルが、カードを押せるかの判断に使う）
static func has_screen(screen: AppScreens.Id) -> bool
## セーフエリアの左右の余白（基準解像度の px。x が左、y が右）。モバイルのときだけ当てる（screen-common.md §1.1）
static func side_margins(window_size: Vector2i, safe_area: Rect2i, viewport_height: float) -> Vector2

## 各画面のルートが継承する親クラス。enter / exit / handle_back の約束（screen-common.md §4）を型で表す
## （型の警告をエラーにしているため、画面を Node のまま扱うと呼べない）
class_name AppScreen extends Control
func enter(params: Dictionary) -> void
func exit() -> void
func handle_back() -> bool            # 既定は false

## 画面のシーンの入れ替えと、戻る操作の振り分け。入れる先と「画面 ID → シーン」の対応を引数で受け取る
## （本番は MainShell.SCREEN_SCENES、テストはテスト用の対応）
class_name ScreenSwitcher extends RefCounted
func _init(container: Node, scene_paths: Dictionary)
## 対応が無い・読めない・ルートが AppScreen でないときは、今の画面のまま false
func open(screen: AppScreens.Id, params: Dictionary) -> bool
func current() -> AppScreen           # 無ければ null
func current_id() -> int              # 無ければ -1
## 表示中の画面の handle_back() を1回呼んでその値を返す。画面が無ければ false
func route_back() -> bool
```

- 戻る操作（Android の戻る操作・PC の Esc）は `MainShell` が受け、`ScreenSwitcher.route_back()` が `false` なら
  `get_tree().quit()` を呼ぶ（`screen-common.md` §4.1）。デバッグビルドでは、戻る操作ごとに画面 ID と結果をログに出す

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
| `TacticsBoard` | 30エリアの盤面（5レーン×6列）。`BoardSnapshot` を受けて描く。ピッチを縦に置いて斜めから見せ（半3D）、利用者の攻撃方向を画面の上にする（2026-10-23 に横向き・右から変えた） |
| `AreaCell` | 1エリア。両チームの人数（駒）・ボール・選択可否・ヒントを表示し、タップ／クリックを受ける |
| `MoveArrowLayer` | `movements` を移動元から移動先への矢印で描く。理由（`MovementReason`）ごとに線種を変える |
| `ChoicePanel` | 局面に応じた手のボタン。画面に出す手（`MoveMenu`）のうち選べる手だけを、番号・行き先・ヒントの3行で並べる（2026-11-03） |
| `MiniPitch` | 試合準備・ハーフタイム・理解度チェックで使う小さな盤面（人数の数字と優劣記号）。作戦ボードと同じ向き（上が敵陣・左が左大外）で、遠近は付けない |
| `MatchBoardPanel` | 試合画面の盤面と手の選択の部分（左の `TacticsBoard`、右の操作の列の `ChoicePanel`・判定理由）。試合画面とチュートリアルで共用する |

> **2026-10-19 時点**: `AreaCell`・`MoveArrowLayer` は別のノードにせず、`TacticsBoard` の描画（`_draw`）と入力（`gui_input`）に
> まとめた。エリアの位置の計算（`area_rect`・`area_at`）を描画・入力・テストで共有するため。押す操作の判定（押したエリアの中で
> 離したときだけ選ぶ）は `screen-common.md` §4.1 のとおり。`MatchBoardPanel` は、開示を受けたらすぐ判定理由を出す（3D 演出は 2026-10-23 にやめた）。
> 2D 作戦ボードの部品と S-03〜S-06 の子のノードは、`.tscn` を置かずコードで組んでいる（ノード名は詳細設計に合わせる）。
> 盤面の部品が増えたときに `.tscn` へ移すかを見直す。
>
> **2026-10-22**: 盤面の情報を絞った（シンプル案）。角の優劣記号・駒の番号・方式の動きの矢印・凡例を描かない。
> ヒントの札は選べるエリアにだけ描き、±0 の札（`set_hints(hints, even_keys)` の `even_keys`）は控えめな色にする。
> 描く動きは `drawn_movements()`（ドリブル・寄せ・カバー）で、描画とテストで共有する。
>
> **2026-10-22（決定前のプレビュー）**: 手とエリアを選ぶと、`MatchController.user_preview` の動きを `TacticsBoard.show_preview` で
> 盤面に重ねる。移動先は自分の色の輪（中抜き）、動く選手の駒から輪へ点線の曲線の矢印。開示後の動き（実線）と線の種類で区別する。
> プレビューは理由で絞らない（リトリート・カウンターの飛び出し・マークの付け直しも出す）。ボールから運ぶ先への矢印は、
> ボールを運ぶ手（攻撃・カウンター）だけに出す。プレス・カバー・スルーパスでは、運ぶ先を選ぶ間に選べる条件の一言（`MatchTexts.target_rule`）を出す。
> （輪と点線の矢印は 2026-11-05 にやめた。下の注記）
>
> **2026-11-05（チーム全員のプレビュー）**: 手を選ぶと、`MatchController.user_preview_frames` の配置の並び（ターン開始時・判定時・
> 次のターン開始時）を `TacticsBoard.show_preview_motion` に渡し、どこかの配置で位置が変わる自分の選手を、半透明の駒で配置から配置へ
> 動かし、止めて最初へ戻すのをくり返す（ボードの子ノード `BoardPreviewLoop`。時間は `preview_style()`）。動く選手のもとの駒は描かない（残すと見づらい、というシャビの指摘）。動かない駒はその場に残す。
> 1人分の動きしか見えない・矢印が読みにくい、というシャビの指摘による。`show_preview`（輪と点線の曲線の矢印）は消した。
>
> **2026-11-03（手の選択の簡素化）**: 行き先はゲームが決め（`MoveMenu`）、手を押すとすぐ `READY` になる（運ぶ先を選ぶ状態をやめた）。
> 自分の手の行き先はターンの頭から `set_selectable`・`set_hints` で盤面に出し（札は手の番号。ヒントが ON なら人数差も）、
> エリアを押すとその行き先の手を選ぶ。手の一言（`target_rule`）は、スルーパス・バックパス・守備の手で、誰が動くか・何を読む手かを言う。
> `MatchController` は画面に出す手を状態ごとに1回だけ作る（`user_options`・`user_hints`・`user_preview`・`submit_turn` で共有）。
>
> **2026-11-05（詳細のポップアップ）**: 手のボタンは番号と行動の名前だけにし、2列に並べてスクロールせずに選べるようにした。
> 選んだ手の行き先・判断材料・説明は、「決定」の左の「詳細」で開く `MoveDetailView`（`ModalOverlay`）に出す（ボタンの下の説明はやめた）。
>
> **2026-10-22（開示で駒を動かす）**: 開示では、`TacticsBoard.start_shift` で、判定前の配置（`RevealView` の判定前の選手）から
> 次のターン開始時の配置（`BoardSnapshot`）へ、位置が変わった全選手の駒を `MatchController.board_shift_sec()` 秒で動かす
> （2026-11-03 に2拍に分け、この時間は2拍目の `board_settle_sec()` に改名した。下の注記）。
> 道筋（選手ごとの移動元と移動先の駒の列の位置）の計算は `BoardShift`（`board_shift.gd`）に置き、Tween はボードが持つ（描画は下の 2026-10-23 の注記のとおり `BoardPainter`）。
> 画面の状態は増やさない（テロップ・矢印はすぐ出し、「次へ」も押せる。テロップは 2026-11-03 に1拍目の後へ移した。下の注記）。次の盤面・重ね表示の消去で動きを止める。
>
> **2026-10-23**: ボールも駒と一緒に、判定前のエリア（`RevealView.ball_before`）から動かす。あわせて `TacticsBoard` を分けた。
> 描画は `BoardPainter`（`board_painter.gd`。ボードの公開の問い合わせだけを読んで描く）、開示の動きの状態（駒とボールの
> 道筋・進み具合）は `BoardShift` に置き、ボードは外から渡す値と状態・位置の計算・問い合わせ・入力・Tween を持つ。
>
> **2026-11-03（開示を2拍にする）**: 開示の動きを、1拍目（プレー。判定前 → 判定時、`board_play_sec()` 秒）と
> 2拍目（詰め直し。判定時 → 次のターン開始時、`board_settle_sec()` 秒）に分けて順に動かす。手で動いた選手と、方式で組み直る
> チーム全体を時間で分け、何が起点で全体が動いたかを見せる。`BoardShift` は拍の並びと、いまの拍・その中の進み具合を持ち、
> `TacticsBoard.start_shift` は拍の始まりの配置の並びを受け取る（screen-common.md）。動きの無い拍は飛ばす。
> それまでの `board_shift_sec`（全体の時間）は、意味が2拍目の時間に変わったので `board_settle_sec` に改名した
> （同じ型のまま意味だけが変わると、古い値が黙って使われるため）。
>
> **2026-11-03（結果の演出）**: 1拍目の終わりに、ターンの結果を盤面の動きで見せる。区分・場所・色の側は `ResultEffect`
> （`ui/board2d/result_effect.gd`。UI 層）が `RevealView` から決める（得点・セーブ・ボールを奪った・オフサイド・膠着）。
> 得点は1拍目のボールをゴールの口（`TacticsBoard.goal_mouth`。描画のゴールと同じ `goal_rect` から求める）へ向け、膠着は
> 運ぶ先の方への跳ね返り（`BallFlight.Kind.BOUNCE`）にする（`ResultEffect.shape_ball_paths`。拍に keyframe の番号を持たせ、
> 動きの無い拍を取り除いた後も1拍目を見分ける）。1拍目が終わると `TacticsBoard.play_landed` を出し、輪・ゴールの光・旗を
> `MatchController.board_result_sec()` 秒出す。`MatchBoardPanel` はテロップを着地で出す（結果が分かる前の溜めを作る）。
>
> **2026-11-03（手ごとのボールの軌道）**: 1拍目のボールを、ボールを持つ側の手の種類で動かす（グラウンダー・浮き球・ドリブル・
> 強いシュート。ほかはまっすぐ等速）。区分と形（道筋に沿った進み方と高さ）は `BallFlight`（`ui/board2d/ball_flight.gd`。
> 見せ方だけの区分なので UI 層に置き、`GameEnums` には足さない）。拍の組み立ては `BoardShift.build_beats` に移した
> （`tactics_board.gd` の行数を増やさないため）。高さ・弾みの値は `MatchController.ball_style()` から、パネルが bind で
> `TacticsBoard.set_ball_style` に入れる。影は地面の位置に描き、ボールだけを持ち上げる。
>
> **2026-11-03（作戦ボードの分割）**: `TacticsBoard` の責務を分けた。外から見た形（公開の関数・シグナル）は変えていない。
> 平面図での位置の計算（エリア・駒の列・ボール・ゴール。盤面の大きさだけから決まる）は `BoardGeometry`（`board_geometry.gd`。
> 静的関数で大きさを受け取る）、開示の進行（拍の Tween・1拍目の着地・結果の演出の状態と Tween）はボードの子ノードの
> `BoardReveal`（`board_reveal.gd`。Tween はノードが作るので状態の `BoardShift` と分けた）、結果の演出の描画は
> `ResultEffectPainter`（`result_effect_painter.gd`）。ボードには、外から渡す値と状態・入力・描画とテストが読む問い合わせ、
> 位置の計算と開示への中継を残す。拍の組み立て（いまの盤面と位置の計算が要る）はボードが行い、`BoardReveal.start` に渡す。
>
> **2026-11-05（駒の動きの質感）**: 開示で駒が等速でまっすぐ動くのをやめ、各拍の中で、その拍の始まりのボールに近い駒から順に
> 少し遅れて動き出し（ずらし。`BoardShift.build_beats` が道筋に距離の順 `order` を入れる）、加速して減速して止まり（イージング）、
> 動いている間は小さく浮く（弾み。影は足元に残す）。進み方と高さは `PieceMotion`（`piece_motion.gd`。静的関数）。ボールの動きは
> 軌道（`BallFlight`）のまま。拍と拍の間に小休止を置く（`BoardReveal`。着地は待たない）。値は `MatchController.piece_style()`・
> `board_beat_gap_sec()` から、パネルが bind で `TacticsBoard.set_piece_style`・`set_beat_gap_sec` に入れる。
>
> **2026-10-23（縦向きの盤面）**: ピッチを縦に置き、斜めから見た半3Dで描く（利用者は上へ攻める。上が敵陣、左が左大外）。
> 位置（エリア・駒・ボール・道筋）は平面図（縦向きのピッチを真上から見た図）の座標で持ち、描くときと押した点を読むときに
> `BoardProjection`（`board_projection.gd`）の写し方（平面図 ⇔ 画面。奥 = 上を狭く。6列では縦は詰めない（`NEAR_WEIGHT` 1.0。2026-10-25））を通す。
> 駒はチェスのような立体の駒（自分は丸い頭、相手はとがった頭）で、1チーム 2列×2段に並べ、奥から手前の順に描く
> （`standing_order()`。描画とテストで共有）。押せる範囲は、画面でいちばん小さい奥の行でも 48dp 以上（`MIN_CELL`）。

### 5.4 3D 演出（廃止）

> **2026-10-23 にやめた**（FR-24 の置き換え）。ターン結果は、作戦ボードの上で駒とボールを動かして見せる
> （§5.3 の `TacticsBoard.start_shift`）。`ReplayStage`・`ReplayLayoutMapper`・`replay3d/`・`MatchController.replay_max_sec()` は作らない。
> 3D 演出の決めごと（判定モジュールを呼ばない・エリアの人数と見た目を一致させる）は、開示の動きの原則として
> `architecture-overview.md`「UI 層」に引き継いだ。

### 5.5 共通部品（`common/`）

| `class_name` | 役割 |
|---|---|
| `JudgeReasonFormatter` | `RevealView` から判定理由の文（`functional-overview.md`「表示仕様」の形式）を作る。主語は `user_role` で決める（例: `NO_CONTEST` は、利用者が奪取側なら「判定なし（相手は撤退、こちらは保持）」、喪失側なら「判定なし（こちらは撤退、相手は保持）」） |
| `NotesView` | `MatchupNote` の一覧を、続く同じ見出し（`label`）を1つにまとめて表示する。単純化 ID があれば、その項目の下に「実戦では」を添える（FR-23。同じ単純化は欄の中で1回だけ） |
| `ConfirmDialog` | 確認ダイアログ（中断データが上書きされることの確認など） |
| `ToastView` | 保存エラーなどの短い通知 |
| `ScreenHeader` | 画面のヘッダー（戻る・画面名） |
| `ScoreBug` | 中継風のスコア表示（試合画面・方式の選び直し・ハーフタイム・試合結果） |
| `FormationCard` | 陣形のカード（陣形名・`MiniPitch`・選択中の印） |
| `MatchMenu` | 試合中の画面のメニュー（設定・中断してタイトルへ） |
| `SettingsPanel` | 設定の中身（設定画面と、試合中のメニューから重ねて開く設定で共用） |
| `SettingsOverlay` | 試合中のメニューから重ねて開く設定（`SettingsPanel` と閉じる。2026-10-29） |
| `LicenseView` | 同梱した素材のライセンスの表示（設定の「ライセンス」。2026-10-29） |
| `AudioBuses` | 設定の音量をオーディオバス `BGM`・`SE` へ反映する（ノードを持たない。2026-10-29） |
| `SoundCues` | 効果音（オートロード `Sfx`。2026-10-30）。音（`CLICK`・`GOAL_FOR`・`GOAL_AGAINST`・`WHISTLE`）→ ファイル（`assets/sounds/`）の対応を持ち、すべて `SE` バスで鳴らす。木に入った `BaseButton` の `pressed` に自分でつないでクリック音を鳴らす。得点・笛は `MatchScreen` が鳴らす（時点は `screen-03-match.md`）。素材の台帳は `assets/LICENSES.md`「効果音」 |
| `SimplificationList` | 単純化カタログの一覧（ゲームの表現範囲とチュートリアルの最後で共用） |
| `NewMatchGate` | 「CPU 対戦」を押したときの確認の手順（タイトルと戦績の0件の表示で共用。ノードを持たない） |
| `MatchTexts` | 試合の画面の文言（エリア名「中盤（敵陣）・左HS」・手の名前・局面のタグ・結果のラベル・ヒントの札・時計）を1か所に集める（static） |
| `QuizTexts` | 理解度チェックとタイトルのカードの文言（学習目標の名前・正答状況・正誤・根拠の原則）を1か所に集める（static）。問題の文の `{M2-L1}` を `MatchTexts.area_name` の呼び名にする（2026-10-31） |
| `StylePicker` | 守備方式・攻撃方式の2択を2組並べる部品（方式の選び直し・ハーフタイム） |
| `MatchScreenLayout` | 試合の合間の画面（方式の選び直し・ハーフタイム・試合結果）の骨組み（上部バー・本体・操作の列と主ボタン）を組む（static） |

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
>
> 2026-10-18（動く骨格の作業）: 足した `AppScreen`・`ScreenSwitcher` も、同じ4つの一覧（プロジェクト自身が登録した名前を除く）と
> 衝突しないことを確かめた。

| 区分 | 名前 |
|---|---|
| オートロード | `App`・`Sfx`（効果音。UI 層の `SoundCues`。2026-10-30） |
| enum（`GameEnums` 内） | `Lane`・`Zone`・`DefenseStyle`・`AttackStyle`・`TurnKind`・`PlayType`・`DefenseAction`・`NegTransAction`・`PosTransAction`・`TurnOutcome`・`MatchStatus`・`MatchStage`・`PrincipleStatus`・`TeamSide`・`ChoiceFamily`・`CoverKind`・`MovementReason`・`MatchResult`・`Phase`・`JudgeTally` |
| enum（その他） | `AppScreens.Id`・`AppScreens.StorageErrorKind`・`AppScreens.SuspendedStatus`・`AppScreens.StartupResult`（2026-10-29 に `MatchController` から移した）・`SuspendedLoad.Status`・`VersionedJsonFile.LoadState`（戦績・回答結果の読み込みの結果。`RecordStore`・`QuizAnswerStore` の `load_state()` が返す。2026-10-31 に `RecordStore` から移した）・`SettingsStore.LoadState`（同じ値の enum をクラス内に持つ。クラスの内側なので衝突しない） |
| ドメイン | `MatchRuleConfig`・`CpuConfig`・`PresentationConfig`・`VerificationConfig`・`GameEnums`・`PitchArea`・`FormationDef`・`PlayerSlotDef`・`StyleDef`・`TeamStyles`・`TeamSetup`・`PlayerState`・`TeamLayout`・`LayoutPair`・`LayoutStep`・`Movement`・`TurnChoice`・`MoveOptions`・`ChoiceHint`・`JudgeDetail`・`JudgeOutput`・`TurnRecord`・`MatchState`・`MatchPositions`・`TurnResolution`・`MatchupNote`・`ReviewSummary`・`ContentCatalog`・`MatchupRuleDef`・`PrincipleDef`・`SimplificationDef`・`QuizQuestionDef`・`TutorialStepDef`・`MatchRecord`・`QuizAnswer`・`UserSettings`・`BaseLayoutDeriver`・`StyleLayoutCalculator`・`DefenseMover`・`MoveRules`・`OffsideRule`・`OpenPlayJudge`・`TransitionJudge`・`MoveHints`・`MatchRules`・`CpuPlanner`・`CommentaryGenerator`・`ReviewAggregator` |
| アプリケーション | `AppScreens`・`MatchController`・`ViewConverter`・`OpponentPolicy`・`CpuOpponent`・`ScriptedOpponent`・`LibraryService`・`UserDataService`・`BoardSnapshot`・`RevealView`・`ReviewView` |
| データ | `ContentRepository`・`TutorialContentReader`・`QuizContentReader`・`ConfigRepository`・`SuspendedMatchStore`・`SuspendedLoad`・`RecordStore`・`QuizAnswerStore`・`VersionedJsonFile`・`SettingsStore`・`SaveFileIO`・`SaveMigrator` |
| UI | `MainShell`・`AppScreen`・`ScreenSwitcher`・`TitleScreen`〜`SettingsScreen`（§5.2）・`TacticsBoard`・`AreaCell`・`MoveArrowLayer`・`ChoicePanel`・`MiniPitch`・`MatchBoardPanel`・`BoardPainter`・`BoardShift`・`BoardProjection`・`JudgeReasonFormatter`・`NotesView`・`ConfirmDialog`・`ToastView`・`ScreenHeader`・`ScoreBug`・`FormationCard`・`MatchMenu`・`SettingsPanel`・`SimplificationList`・`NewMatchGate`・`MatchTexts`・`QuizTexts`・`StylePicker`・`MatchScreenLayout` |

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
