## チームの配置（component-design.md §2.2）。選手ごとの状態と、各選手の現在エリアを持つ。
##
## 現在エリアは base_area・fixed_area とは別に持つ。アルゴリズム2の方式の動き（スライド・マーク・保持型の前進）で、
## 固定されていない選手の現在エリアも基本エリアからずれるため。
class_name TeamLayout
extends RefCounted

var players: Array[PlayerState]
## 選手 ID → 現在エリア（PitchArea）
var _current_areas: Dictionary


## 受け取った配列・辞書はコピーして持つ（呼び出し側が後で変えても、この配置は変わらない。component-design.md §1.1）。
func _init(p_players: Array[PlayerState], p_current_areas: Dictionary) -> void:
	players = p_players.duplicate()
	_current_areas = p_current_areas.duplicate()


## 全員の現在エリアを基本エリアにした配置（固定の有無は見ない）。
static func at_base(p_players: Array[PlayerState]) -> TeamLayout:
	var current: Dictionary = {}
	for player: PlayerState in p_players:
		current[player.player_id] = player.base_area
	return TeamLayout.new(p_players, current)


## 各選手の今いるエリア（PlayerState.current_area）を現在エリアにした配置。試合の状態からターン開始の起点を作る。
static func from_players(p_players: Array[PlayerState]) -> TeamLayout:
	var current: Dictionary = {}
	for player: PlayerState in p_players:
		current[player.player_id] = player.current_area
	return TeamLayout.new(p_players, current)


## いない選手なら null。
func current_area_of(player_id: String) -> PitchArea:
	if not _current_areas.has(player_id):
		return null
	return _current_areas[player_id] as PitchArea


## area が null なら 0。
func count_at(area: PitchArea) -> int:
	if area == null:
		return 0
	var count: int = 0
	for player: PlayerState in players:
		if area.equals(current_area_of(player.player_id)):
			count += 1
	return count


## 30エリアすべてのキー → 人数。人数が 0 のエリアも含める。
func counts() -> Dictionary:
	var result: Dictionary = {}
	for area: PitchArea in PitchArea.all():
		result[area.to_key()] = 0
	for player: PlayerState in players:
		var area: PitchArea = current_area_of(player.player_id)
		if area != null:
			result[area.to_key()] = (result[area.to_key()] as int) + 1
	return result


## player_id の選手を area に置いて固定した写し（ボールのエリアに保持者を置くとき。MatchRules）。
func with_fixed(player_id: String, area: PitchArea) -> TeamLayout:
	var copied: TeamLayout = duplicate_deep()
	for player: PlayerState in copied.players:
		if player.player_id == player_id:
			player.fixed_area = area.duplicate_deep()
			copied._current_areas[player_id] = area.duplicate_deep()
	return copied


func duplicate_deep() -> TeamLayout:
	var copied_players: Array[PlayerState] = []
	for player: PlayerState in players:
		copied_players.append(player.duplicate_deep())
	var copied_current: Dictionary = {}
	for player_id: String in _current_areas:
		copied_current[player_id] = (_current_areas[player_id] as PitchArea).duplicate_deep()
	return TeamLayout.new(copied_players, copied_current)
