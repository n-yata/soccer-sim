## アルゴリズム3: 選択可能な手（functional-overview.md。component-design.md §2.4）。
##
## 局面の値（配置・ボール位置）を受け取る下位の関数を持つ。MatchState から呼ぶ入口 options_for は、
## MatchState を作る作業（試合進行）で足す。運ぶ先は PitchArea.all() の順に並べる（結果を決定的にするため）。
##
## 手の条件の距離（隣接・レーン差3以上・1〜2ゾーン前）はルールの定義そのもので、調整値ではない。そのため定数で持つ。
class_name MoveRules
extends RefCounted

## SWITCH で運べる最小のレーン差
const _SWITCH_MIN_LANE_GAP: int = 3
## LONG_BEHIND で運べる最大のレーン差
const _LONG_BEHIND_MAX_LANE_GAP: int = 1
## COUNTER で運べる、ボール位置から前のゾーン数（1〜この値）
const _COUNTER_MAX_ZONES_AHEAD: int = 2


## side が今のターンで選べる手（局面に応じて下位の関数を呼ぶ）。運ぶ先は判定時の攻撃側（トランジションは奪取側）の視点。
## 攻守ターン: 保持側は攻撃の手、相手は守備の手。トランジション: 保持側（奪取側）はカウンターの配置で奪った側の手、
## 相手は失った側の手。MatchRules.resolve_turn も手の確かめにこの関数を使う（表示と確かめをずらさないため）。
static func options_for(state: MatchState, side: GameEnums.TeamSide) -> MoveOptions:
	var is_holder: bool = side == state.possession
	if state.turn_kind == GameEnums.TurnKind.TRANSITION:
		if not is_holder:
			return neg_transition_options()
		var counter: TeamLayout = TransitionJudge.counter_layout(
				state.transition_origin.attacker, state.setup_of(side).styles)
		return pos_transition_options(counter, state.ball_area)
	var pair: LayoutPair = StyleLayoutCalculator.turn_start(state).pair
	return attack_options(pair, state.ball_area) if is_holder else defense_options(pair)


## 攻撃の手。ball と運ぶ先は攻撃側から見た座標。味方の人数は攻撃側の現在配置で数える。
static func attack_options(pair: LayoutPair, ball: PitchArea) -> MoveOptions:
	var options := MoveOptions.new()
	var family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.ATTACK
	for target: PitchArea in PitchArea.all():
		var has_teammate: bool = pair.attacker.count_at(target) >= 1
		var lane_gap: int = absi(target.lane - ball.lane)
		if has_teammate and _is_neighbor8(ball, target):
			options.add_target(family, GameEnums.PlayType.SHORT_PASS, target)
		if target.equals(ball.forward()) or (target.zone == ball.zone and lane_gap == 1):
			options.add_target(family, GameEnums.PlayType.DRIBBLE, target)
		if has_teammate and ball.zone == GameEnums.Zone.D and target.zone == GameEnums.Zone.A \
				and lane_gap <= _LONG_BEHIND_MAX_LANE_GAP:
			options.add_target(family, GameEnums.PlayType.LONG_BEHIND, target)
		if has_teammate and target.zone == ball.zone and lane_gap >= _SWITCH_MIN_LANE_GAP:
			options.add_target(family, GameEnums.PlayType.SWITCH, target)
	if ball.zone == GameEnums.Zone.A and ball.lane in [GameEnums.Lane.C, GameEnums.Lane.L1, GameEnums.Lane.R1]:
		options.allow(family, GameEnums.PlayType.SHOT)
	return options


## 守備の手。運ぶ先（制限するエリア）は攻撃側から見た座標で返す（DefenseMover.apply の target と同じ）。
## 条件を変えたら、画面に出す選べる条件の一言（MatchTexts.target_rule）の文言も直す。
## 守備側の人数は、守備側から見た座標（T_d = target.mirrored()）で数える。
static func defense_options(pair: LayoutPair) -> MoveOptions:
	var options := MoveOptions.new()
	var family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.DEFENSE
	for target: PitchArea in PitchArea.all():
		var restricted: PitchArea = target.mirrored()
		if _has_player_in(pair.defender, restricted.neighbors4()):
			options.add_target(family, GameEnums.DefenseAction.PRESS, target)
		# カバーで下がる選手は、T_d の背後まで1マスで届く選手（T_d・横・背後。前方は除く。DefenseMover.cover_neighbors）
		var can_cover: bool = pair.defender.count_at(restricted) >= 1 \
				or _has_player_in(pair.defender, DefenseMover.cover_neighbors(restricted))
		if restricted.zone != GameEnums.Zone.D and can_cover:
			options.add_target(family, GameEnums.DefenseAction.COVER, target)
	return options


## 失った側の手。COUNTER_PRESS と RETREAT は常に選べる。
static func neg_transition_options() -> MoveOptions:
	var options := MoveOptions.new()
	options.allow(GameEnums.ChoiceFamily.NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS)
	options.allow(GameEnums.ChoiceFamily.NEG_TRANS, GameEnums.NegTransAction.RETREAT)
	return options


## 奪った側の手。SECURE は常に選べる。COUNTER の運ぶ先は、ball から1〜2ゾーン前（レーン不問）で味方がいるエリア。
## winner はアルゴリズム6のカウンターの配置（呼び出し側が作る）。ball と winner は奪った側から見た座標。
static func pos_transition_options(winner: TeamLayout, ball: PitchArea) -> MoveOptions:
	var options := MoveOptions.new()
	var family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.POS_TRANS
	options.allow(family, GameEnums.PosTransAction.SECURE)
	for target: PitchArea in PitchArea.all():
		var ahead: int = target.zone - ball.zone
		if ahead >= 1 and ahead <= _COUNTER_MAX_ZONES_AHEAD and winner.count_at(target) >= 1:
			options.add_target(family, GameEnums.PosTransAction.COUNTER, target)
	return options


## 選択不可の手を拒否する（functional-overview.md エラーハンドリング「選択不可の手の指定」）。
## 運ぶ先を持つ手は一覧にある運ぶ先だけ、持たない手は運ぶ先が null のときだけ通す。
static func is_allowed(options: MoveOptions, choice: TurnChoice) -> bool:
	if not options.is_available(choice.family, choice.action):
		return false
	if not MoveOptions.needs_target(choice.family, choice.action):
		return choice.target == null
	if choice.target == null:
		return false
	for target: PitchArea in options.targets(choice.family, choice.action):
		if target.equals(choice.target):
			return true
	return false


static func _is_neighbor8(center: PitchArea, other: PitchArea) -> bool:
	for area: PitchArea in center.neighbors8():
		if area.equals(other):
			return true
	return false


static func _has_player_in(layout: TeamLayout, areas: Array[PitchArea]) -> bool:
	for area: PitchArea in areas:
		if layout.count_at(area) >= 1:
			return true
	return false
