## 選手の位置の持ち越し（1ターン1マス。functional-overview.md アルゴリズム2・7。2026-10-24）。
## MatchRules から呼ばれ、ターンをまたぐ選手の位置（current_area）・固定先・moved_in_turn を扱う。
## - キックオフでの、自陣に縮めた陣形への置き直しと、固定の解除
## - 判定時の配置から試合の状態への写し戻し
## - ターン開始から動いたかの印
## - 膠着したドリブルの戻し
## - ボールの保持者を置く
## どの関数も、MatchRules が作った新しい状態（next・state）を書き換える。stop_dribble の元の状態（state）は読むだけ。
class_name MatchPositions
extends RefCounted


## キックオフ: 両チームとも全員を、陣形を自陣に縮めた位置（BaseLayoutDeriver.kickoff_areas）に置き、固定を解く
## （試合の仕切り直しなので、1ターン1マスの例外。2026-10-25）。全員に moved_in_turn を立て、キックオフのターン開始では
## 誰も動かさない（縮めた陣形を盤面に見せる）。次のターン開始から、方式の動きで基本エリアへ1マスずつ上がる。
static func place_for_kickoff(state: MatchState) -> void:
	release_fixes(state)
	for players: Array[PlayerState] in [state.home_players, state.away_players]:
		var kickoff: Dictionary = BaseLayoutDeriver.kickoff_areas(players)
		for player: PlayerState in players:
			player.current_area = (kickoff[player.player_id] as PitchArea).duplicate_deep()
			player.moved_in_turn = true


## 全員の固定を解く（位置は変えない）。キックオフと、トランジションが終わって攻守ターンが始まる時に呼ぶ。
static func release_fixes(state: MatchState) -> void:
	for player: PlayerState in state.home_players + state.away_players:
		player.fixed_area = null


## 判定時の配置の選手（基本エリア・固定先・今いるエリア）を、保持側・相手の枠に写す。
## 今いるエリアは配置（TeamLayout）の現在エリアが正なので、そこから写し戻す（次のターンへ持ち越す位置）。
static func store_players(next: MatchState, pair: LayoutPair) -> void:
	var attacker_players: Array[PlayerState] = _players_at(pair.attacker)
	var defender_players: Array[PlayerState] = _players_at(pair.defender)
	if pair.attacker_side == GameEnums.TeamSide.HOME:
		next.home_players = attacker_players
		next.away_players = defender_players
	else:
		next.away_players = attacker_players
		next.home_players = defender_players


## 各選手が、ターン開始の位置（start）から動いたか（moved_in_turn）を付け直す。動いた選手は、次のターン開始の
## 方式の動きでは動かない（ターン開始から次のターン開始までを1マス以内に保つ）。
static func mark_moved(next: MatchState, start: LayoutPair) -> void:
	for side: GameEnums.TeamSide in [GameEnums.TeamSide.HOME, GameEnums.TeamSide.AWAY]:
		var started: TeamLayout = start.attacker if start.attacker_side == side else start.defender
		for player: PlayerState in next.players_of(side):
			player.moved_in_turn = not player.current_area.equals(started.current_area_of(player.player_id))


## 膠着したドリブル: 運んだ選手の固定を判定前に戻す（ボールは元のエリアに残るので、運んだ選手もそこへ戻る）。
## 判定と判定時の配置（ターン記録の pair_at_judgement）は運んだ後の位置のまま。戻る動きを返す。
## 運んだ選手の今いるエリア（current_area）も B（ターン開始の位置）に戻す。次のターン開始の方式の動きは、B から1マス。
static func stop_dribble(next: MatchState, state: MatchState, output: JudgeOutput) -> Array[Movement]:
	var result: Array[Movement] = []
	var holder: GameEnums.TeamSide = state.possession
	for movement: Movement in output.movements:
		if movement.reason != GameEnums.MovementReason.DRIBBLE:
			continue
		var before: PlayerState = _player_of(state.players_of(holder), movement.player_id)
		var carrier: PlayerState = _player_of(next.players_of(holder), movement.player_id)
		# 運んだ選手は保持側の選手なので通常は見つかる。見つからないのは状態が壊れているときで、何も戻さない
		if before == null or carrier == null:
			continue
		carrier.fixed_area = null if before.fixed_area == null else before.fixed_area.duplicate_deep()
		carrier.current_area = movement.from.duplicate_deep()
		result.append(Movement.new(holder, movement.player_id, movement.to.duplicate_deep(), movement.from.duplicate_deep(),
				GameEnums.MovementReason.DRIBBLE_STOPPED))
	return result


## 次のターンの開始時の配置で、ボールのエリアに保持側の選手がいなければ、いちばん近い選手を1人置いて固定する。
## 近さは今いるエリア（判定時の位置）からの列差＋レーン差で、同じなら配置の選手の順で先の選手
## （アルゴリズム2のマーカーの選び方と同じ）。
## start はそのターンの開始時の配置。置ける選手は、ターン開始の位置と今いるエリアのどちらからも、ボールのエリアが
## 1マス以内の選手だけ（ターン開始から次のターン開始までを1マス以内に保つ。2026-10-24）。いなければ誰も置かない
## （ボールのエリアに保持側がいないまま進む）。start が null のキックオフは、仕切り直しなので距離を問わない。
## トランジションは起点の配置も同じく変える。置いた動きを返す（置かなければ空）。
static func place_holder(next: MatchState, start: LayoutPair) -> Array[Movement]:
	var result: Array[Movement] = []
	var holders: TeamLayout = StyleLayoutCalculator.turn_start(next).pair.attacker
	if holders.count_at(next.ball_area) > 0:
		return result
	var started: TeamLayout = null
	if start != null:
		started = start.attacker if start.attacker_side == next.possession else start.defender
	var nearest: PlayerState = null
	var nearest_distance: int = 0
	for player: PlayerState in next.players_of(next.possession):
		if started != null and not (started.current_area_of(player.player_id).is_within_one(next.ball_area)
				and player.current_area.is_within_one(next.ball_area)):
			continue
		var distance: int = player.current_area.distance_to(next.ball_area)
		if nearest == null or distance < nearest_distance:
			nearest = player
			nearest_distance = distance
	if nearest == null:
		return result
	# 動きの移動元は、今いるエリア（判定時の位置）。仮に出した次のターン開始の位置は、置いた選手がいなかった場所になりうる
	var from: PitchArea = nearest.current_area.duplicate_deep()
	nearest.fixed_area = next.ball_area.duplicate_deep()
	nearest.current_area = next.ball_area.duplicate_deep()
	nearest.moved_in_turn = true
	if next.turn_kind == GameEnums.TurnKind.TRANSITION:
		next.transition_origin.attacker = next.transition_origin.attacker.with_fixed(nearest.player_id, next.ball_area)
	result.append(Movement.new(next.possession, nearest.player_id, from, next.ball_area.duplicate_deep(),
			GameEnums.MovementReason.BALL_HOLDER))
	return result


static func _player_of(players: Array[PlayerState], player_id: String) -> PlayerState:
	for player: PlayerState in players:
		if player.player_id == player_id:
			return player
	return null


static func _players_at(layout: TeamLayout) -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	for player: PlayerState in layout.players:
		var copied: PlayerState = player.duplicate_deep()
		copied.current_area = layout.current_area_of(player.player_id).duplicate_deep()
		result.append(copied)
	return result
