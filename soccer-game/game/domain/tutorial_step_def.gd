## チュートリアルの段階1件（data-definition.md §3.6 の tutorial.json。FR-12）。
## 盤面（setup）は EXPLAIN・OPERATE のときだけ持つ。選べる手と相手の手は OPERATE のときだけ持つ。
## 利用者 = HOME、CPU = AWAY。ボールの位置と相手の手の運ぶ先は、試合と同じく攻撃側（ボールを持つ側）の視点。
class_name TutorialStepDef
extends RefCounted

## EXPLAIN: 説明と、操作できない盤面／OPERATE: 選べる手を絞った盤面で1手決める／SCOPE: 単純化の一覧（最後の段階）
enum Kind { EXPLAIN, OPERATE, SCOPE }

## 段階で体験する要素（FR-12 の7要素。全段階を合わせてすべてを含む）
const COVER_NAMES: Array[String] = ["PITCH", "MATCHUP", "PHASES", "SIMULTANEOUS", "STYLES", "JUDGEMENT", "SHOT"]

var id: String
var kind: Kind
var text: String
var covers: Array[String] = []
# --- 盤面（EXPLAIN・OPERATE） ---
var home_setup: TeamSetup
var away_setup: TeamSetup
var turn_kind: GameEnums.TurnKind = GameEnums.TurnKind.OPEN_PLAY
var possession: GameEnums.TeamSide = GameEnums.TeamSide.HOME
var ball_area: PitchArea
# --- 手（OPERATE） ---
## 利用者が選べる手（区分値の名前。その局面の手の種類のもの）。試合の規則で選べる手の部分集合
var allowed_actions: Array[String] = []
## ScriptedOpponent が出す手
var opponent_choice: TurnChoice


func has_board() -> bool:
	return kind != Kind.SCOPE
