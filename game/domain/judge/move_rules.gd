## アルゴリズム3: 選択可能な手（functional-overview.md。component-design.md §2.4）。
##
## 局面の値（配置・ボール位置）を受け取る下位の関数を持つ。MatchState から呼ぶ入口 options_for は、
## MatchState を作る作業（試合進行）で足す。運ぶ先は PitchArea.all() の順に並べる（結果を決定的にするため）。
##
## 手の条件の距離（2マス以内・レーン差3以上・1〜4列前など）はルールの定義そのもので、調整値ではない。そのため定数で持つ。
## 6列の盤面での読み替え（2026-10-25）: ショートパスは2マス、ロングボールは自陣から敵陣の奥の2列、シュートはペナルティエリアの3マス（6列目の L1・C・R1）、
## カウンターは1〜4列前、カバーは守備側の1列目では選べない。スルーパス（同日に追加）は1〜2列前・レーン差1以内で、受け手
## （OpenPlayJudge.through_pass_runner）が走り込めるエリア。
class_name MoveRules
extends RefCounted

## SHORT_PASS で届く距離（レーン差・列差がどちらもこの値以内。斜めを含む）
const _SHORT_PASS_REACH: int = 2
## SWITCH で運べる最小のレーン差
const _SWITCH_MIN_LANE_GAP: int = 3
## LONG_BEHIND で運べる最大のレーン差
const _LONG_BEHIND_MAX_LANE_GAP: int = 1
## THROUGH_PASS で運べる、ボール位置から前の列数（1〜この値）と最大のレーン差
const _THROUGH_PASS_MAX_ROWS_AHEAD: int = 2
const _THROUGH_PASS_MAX_LANE_GAP: int = 1
## LONG_BEHIND の運ぶ先の列（敵陣の奥の2列。5・6列目）の先頭
const _FINAL_ROWS_FIRST: GameEnums.Zone = GameEnums.Zone.A1
## SHOT を選べるエリア（ペナルティエリア。6列目の中央とハーフスペースの3マス。2026-10-25）
const _PENALTY_AREA_ZONE: GameEnums.Zone = GameEnums.Zone.A2
const _PENALTY_AREA_LANES: Array[GameEnums.Lane] = [GameEnums.Lane.L1, GameEnums.Lane.C, GameEnums.Lane.R1]
## COUNTER で運べる、ボール位置から前の列数（1〜この値）
const _COUNTER_MAX_ZONES_AHEAD: int = 4
## BACK_PASS で戻せる、ボール位置から後ろの列数（1〜この値。2026-11-03）
const _BACK_PASS_MAX_ROWS_BACK: int = 2


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
	return attack_options(pair, state.ball_area) if is_holder else defense_options(pair, state.ball_area)


## 攻撃の手。ball と運ぶ先は攻撃側から見た座標。味方の人数は攻撃側の現在配置で数える。
static func attack_options(pair: LayoutPair, ball: PitchArea) -> MoveOptions:
	var options := MoveOptions.new()
	var family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.ATTACK
	for target: PitchArea in PitchArea.all():
		var has_teammate: bool = pair.attacker.count_at(target) >= 1
		var lane_gap: int = absi(target.lane - ball.lane)
		var reach: int = ball.steps_to(target)
		if has_teammate and reach >= 1 and reach <= _SHORT_PASS_REACH:
			options.add_target(family, GameEnums.PlayType.SHORT_PASS, target)
		# ドリブルは周り8エリアのどこへでも（斜め・後ろも。2026-10-24）。味方の有無は問わない
		if _is_neighbor8(ball, target):
			options.add_target(family, GameEnums.PlayType.DRIBBLE, target)
		# スルーパスは1〜2列前・レーン差1以内の、味方が走り込めるエリア（空いていてもよい。2026-10-25）
		var rows_ahead: int = target.zone - ball.zone
		if rows_ahead >= 1 and rows_ahead <= _THROUGH_PASS_MAX_ROWS_AHEAD and lane_gap <= _THROUGH_PASS_MAX_LANE_GAP \
				and OpenPlayJudge.through_pass_runner(pair.attacker, ball, target) != null:
			options.add_target(family, GameEnums.PlayType.THROUGH_PASS, target)
		if has_teammate and ball.is_own_half() and target.zone >= _FINAL_ROWS_FIRST \
				and lane_gap <= _LONG_BEHIND_MAX_LANE_GAP:
			options.add_target(family, GameEnums.PlayType.LONG_BEHIND, target)
		if has_teammate and target.zone == ball.zone and lane_gap >= _SWITCH_MIN_LANE_GAP:
			options.add_target(family, GameEnums.PlayType.SWITCH, target)
		# バックパスは1〜2列後ろの、ショートパスの届くレーンの味方へ。ペナルティエリアでは出さない（4つ目の枠をシュートと分け合う。2026-11-03）
		var rows_back: int = ball.zone - target.zone
		if has_teammate and not is_penalty_area(ball) and rows_back >= 1 and rows_back <= _BACK_PASS_MAX_ROWS_BACK \
				and lane_gap <= _SHORT_PASS_REACH:
			options.add_target(family, GameEnums.PlayType.BACK_PASS, target)
	if is_penalty_area(ball):
		options.allow(family, GameEnums.PlayType.SHOT)
	return options


## シュートを打てるエリア（ペナルティエリア）か。ball は攻撃側の視点。
static func is_penalty_area(ball: PitchArea) -> bool:
	return ball.zone == _PENALTY_AREA_ZONE and ball.lane in _PENALTY_AREA_LANES


## 守備の手。運ぶ先（制限するエリア）は攻撃側から見た座標で返す（DefenseMover.apply の target と同じ）。
## 条件を変えたら、画面に出す選べる条件の一言（MatchTexts.target_rule）の文言も直す。
## 守備側の人数は、守備側から見た座標（T_d = target.mirrored()）で数える。
## ball（攻撃側の視点）を渡すと、ドリブルのコースを切る（プレスと同じエリアへ。どこを切るかは MoveMenu がドリブルの行き先から選ぶ。
## 2026-11-05）と、ペナルティエリアではシュートコースを塞ぐ（ボールのエリアへのプレス。ボールの隣に味方がいて寄せが届くときだけ。
## 2026-11-03）を足す。条件はプレスと同じ。
static func defense_options(pair: LayoutPair, ball: PitchArea = null) -> MoveOptions:
	var options := MoveOptions.new()
	var family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.DEFENSE
	for target: PitchArea in PitchArea.all():
		var restricted: PitchArea = target.mirrored()
		if _has_player_in(pair.defender, restricted.neighbors4()):
			options.add_target(family, GameEnums.DefenseAction.PRESS, target)
			if ball != null:
				options.add_target(family, GameEnums.DefenseAction.CLOSE_DOWN, target)
				if target.equals(ball) and is_penalty_area(ball):
					options.add_target(family, GameEnums.DefenseAction.BLOCK_SHOT, target)
		# カバーで下がる選手は、T_d の背後まで1マスで届く選手（T_d・横・背後。前方は除く。DefenseMover.cover_neighbors）
		var can_cover: bool = pair.defender.count_at(restricted) >= 1 \
				or _has_player_in(pair.defender, DefenseMover.cover_neighbors(restricted))
		# 守備側の1列目（ゴール前）は背後が無いので、カバーを選べない
		if restricted.zone != GameEnums.Zone.D1 and can_cover:
			options.add_target(family, GameEnums.DefenseAction.COVER, target)
	return options


## 失った側の手。COUNTER_PRESS と RETREAT は常に選べる。
static func neg_transition_options() -> MoveOptions:
	var options := MoveOptions.new()
	options.allow(GameEnums.ChoiceFamily.NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS)
	options.allow(GameEnums.ChoiceFamily.NEG_TRANS, GameEnums.NegTransAction.RETREAT)
	return options


## 奪った側の手。SECURE は常に選べる。COUNTER の運ぶ先は、ball から1〜4列前（レーン不問。2026-10-25 に1〜2ゾーン前を6列で読み替えた）で味方がいるエリア。
## そこが1つも無ければ、1列前でレーン差1以内のエリア（奪った選手が自分で運ぶ。2026-11-05）。
## winner はアルゴリズム6のカウンターの配置（呼び出し側が作る）。ball と winner は奪った側から見た座標。
static func pos_transition_options(winner: TeamLayout, ball: PitchArea) -> MoveOptions:
	var options := MoveOptions.new()
	var family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.POS_TRANS
	options.allow(family, GameEnums.PosTransAction.SECURE)
	for target: PitchArea in PitchArea.all():
		var ahead: int = target.zone - ball.zone
		if ahead >= 1 and ahead <= _COUNTER_MAX_ZONES_AHEAD and winner.count_at(target) >= 1:
			options.add_target(family, GameEnums.PosTransAction.COUNTER, target)
	# 前に味方がいなければ、奪った選手が自分で運ぶ速攻（1列前・レーン差1以内。2026-11-05。シャビの判断「カウンターが出せるようにして」）。
	# 運ぶ選手は TransitionJudge.carry_if_empty が動かす。ボールのエリアに奪った側がいない（運ぶ人がいない）ときと、前に盤が無い
	# （敵陣ゴール前で奪った）ときは、カウンターを選べない（誰もいないのにボールだけが進まないように）
	if not options.is_available(family, GameEnums.PosTransAction.COUNTER) and winner.count_at(ball) >= 1:
		for target: PitchArea in PitchArea.all():
			if target.zone - ball.zone == 1 and absi(target.lane - ball.lane) <= 1:
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
