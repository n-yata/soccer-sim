## アルゴリズム8: CPU の選択（functional-overview.md。component-design.md §2.6）。
## 読み合いが成立するよう、状況に応じつつ偏りすぎない手を選ぶ（FR-11）。
##
## 乱数生成器はドメインで作らず、引数で受け取ったものだけを使う（固定シードで選択を再現できるようにするため）。
## 引数に相手のそのターンの手を含めない（同時手番の公平性）。
class_name CpuPlanner
extends RefCounted


## ターンの手を選ぶ。候補（options。省略したら画面に出す手 MoveMenu.options_for。利用者と同じ手。2026-11-03）の手から、
## 評価値（score）から選択確率（probabilities）を出し、rng で1つ選ぶ。選べる手が1つも無ければ null を返す（呼び出し側の誤り。通常は起きない）。
static func choose_turn(state: MatchState, side: GameEnums.TeamSide, cpu: CpuConfig,
		rng: RandomNumberGenerator, options: MoveOptions = null) -> TurnChoice:
	var hints: Array[ChoiceHint] = MoveHints.evaluate(state, side, _candidates(state, side, options))
	if hints.is_empty():
		return null
	var picked: ChoiceHint = hints[_draw(_probabilities_of(hints, state, side, cpu), rng)]
	var target: PitchArea = null if picked.target == null else picked.target.duplicate_deep()
	return TurnChoice.new(picked.family, picked.action, target)


## 候補の手（MoveHints.evaluate の並び）ごとの選択確率。評価値に方式の癖の加点と局面の加点を足し、
## オフサイドの減点とマーク注意の減点を引いて（両方当てはまれば両方引く）probabilities を通す。options は choose_turn と同じ。
static func turn_probabilities(state: MatchState, side: GameEnums.TeamSide, cpu: CpuConfig,
		options: MoveOptions = null) -> Array[float]:
	return _probabilities_of(MoveHints.evaluate(state, side, _candidates(state, side, options)), state, side, cpu)


static func _candidates(state: MatchState, side: GameEnums.TeamSide, options: MoveOptions) -> MoveOptions:
	return MoveMenu.options_for(state, side) if options == null else options


static func _probabilities_of(hints: Array[ChoiceHint], state: MatchState, side: GameEnums.TeamSide,
		cpu: CpuConfig) -> Array[float]:
	var styles: TeamStyles = state.setup_of(side).styles
	var scores: Array[float] = []
	for hint: ChoiceHint in hints:
		# 今の配置のままオフサイドになる手は、ボールを失う手として減点する（2026-10-25）
		var offside: float = cpu.offside_penalty if hint.is_offside else 0.0
		# 相手が何もしなくても守備がついて入ってくるスルーパス（マーク注意）も、ボールを失う手として減点する（2026-10-29）
		var marked: float = cpu.marked_penalty if hint.is_marked else 0.0
		scores.append(score(hint) + style_bonus(hint, styles, state.ball_area, cpu)
				+ situation_bonus(hint, state.ball_area, cpu) - offside - marked)
	return probabilities(scores, cpu)


## 局面の加点（functional-overview.md アルゴリズム8）。人数差だけの評価では、CPU が前へ運ばずシュートも打たず、
## 守備も運ぶ先をほとんど読めなかったため。ball は保持側（攻撃側）の視点のボール位置。
## - 攻撃の手・奪取側の手で運ぶ先があれば forward_bonus × (運ぶ先の列 − ボールの列)（後ろへ運ぶ手は負）
## - シュートなら shot_bonus
## - 守備の手は anticipation_bonus × (制限するエリアの列 − ボールの列)。制限するエリアも攻撃側の視点なので、
##   攻撃が前へ運びたがるのを見越して、ボールより前のエリアを守りに行く
## - ほかは 0
static func situation_bonus(hint: ChoiceHint, ball: PitchArea, cpu: CpuConfig) -> float:
	if hint.family == GameEnums.ChoiceFamily.DEFENSE:
		if hint.target == null:
			return 0.0
		return cpu.anticipation_bonus * (hint.target.zone - ball.zone)
	var is_carrier: bool = hint.family == GameEnums.ChoiceFamily.ATTACK \
			or hint.family == GameEnums.ChoiceFamily.POS_TRANS
	if not is_carrier:
		return 0.0
	if hint.family == GameEnums.ChoiceFamily.ATTACK and hint.action == GameEnums.PlayType.SHOT:
		return cpu.shot_bonus
	if hint.target == null:
		return 0.0
	return cpu.forward_bonus * (hint.target.zone - ball.zone)


## 方式の癖の加点。CPU の方式が好む手なら cpu.style_bonus、そうでなければ 0（好む手の表は functional-overview.md
## アルゴリズム8。ルールの定義なので定数で持つ）。ball は保持側の視点のボール位置で、前へのドリブルの判定に使う。
static func style_bonus(hint: ChoiceHint, styles: TeamStyles, ball: PitchArea, cpu: CpuConfig) -> float:
	return cpu.style_bonus if _is_preferred(hint, styles, ball) else 0.0


static func _is_preferred(hint: ChoiceHint, styles: TeamStyles, ball: PitchArea) -> bool:
	var is_counter: bool = styles.attack == GameEnums.AttackStyle.COUNTER
	var is_man: bool = styles.defense == GameEnums.DefenseStyle.MAN
	match hint.family:
		GameEnums.ChoiceFamily.ATTACK:
			match hint.action:
				GameEnums.PlayType.LONG_BEHIND, GameEnums.PlayType.THROUGH_PASS:
					return is_counter
				GameEnums.PlayType.DRIBBLE:
					return is_counter and hint.target != null and hint.target.zone > ball.zone
				GameEnums.PlayType.SHORT_PASS, GameEnums.PlayType.SWITCH:
					return not is_counter
		GameEnums.ChoiceFamily.POS_TRANS:
			return is_counter == (hint.action == GameEnums.PosTransAction.COUNTER)
		GameEnums.ChoiceFamily.DEFENSE:
			# ボールに寄せる・シュートコースを塞ぐもプレス（2026-11-03）
			return is_man == (hint.action != GameEnums.DefenseAction.COVER)
		GameEnums.ChoiceFamily.NEG_TRANS:
			return is_man == (hint.action == GameEnums.NegTransAction.COUNTER_PRESS)
	return false


## 手の評価値（相手が何もしないと仮定した、手を適用した後の比較エリアでの人数差。CPU から見た値）。
## 守備の手は制限するエリアの脅威度（攻撃側 − 守備側。脅威が大きいエリアほど守りに行く）、
## 人数を比べない手（リトリート・保持・スルーパス）は 0、それ以外は 自分 − 相手。
static func score(hint: ChoiceHint) -> float:
	if not hint.is_compared:
		return 0.0
	if hint.family == GameEnums.ChoiceFamily.DEFENSE:
		return float(hint.opponent_count - hint.own_count)
	return float(hint.own_count - hint.opponent_count)


## 選択確率 p_i = floor / N + (1 − floor) × softmax(s_i / τ)。どの手にも floor / N 以上の確率が残る。
## softmax は最大値を引いてから指数を取り、評価値が大きくても桁あふれしないようにする。
## τ・floor が範囲外（τ が 0 以下・NaN・無限大、floor が [0, 1) の外）か、評価値に NaN・無限大があれば一様な確率にする。範囲の検査はデータ層
## （ConfigRepository）が行うが、壊れた値が届いたときに NaN で抽選が最後の手へ黙って偏らないよう、安全な側へ倒す。
static func probabilities(scores: Array[float], cpu: CpuConfig) -> Array[float]:
	var result: Array[float] = []
	if scores.is_empty():
		return result
	var count: int = scores.size()
	if not _is_usable(cpu) or not _are_finite(scores):
		for _index: int in range(count):
			result.append(1.0 / count)
		return result
	var highest: float = scores.max()
	var weights: Array[float] = []
	var total: float = 0.0
	for s: float in scores:
		var weight: float = exp((s - highest) / cpu.temperature)
		weights.append(weight)
		total += weight
	for weight: float in weights:
		result.append(cpu.floor_probability / count + (1.0 - cpu.floor_probability) * weight / total)
	return result


## 評価値がすべて有限か（INF − INF や NaN の比較で、確率が NaN になるのを防ぐ）。
static func _are_finite(scores: Array[float]) -> bool:
	for s: float in scores:
		if not is_finite(s):
			return false
	return true


## NaN でも偽になるよう、範囲の内側にあることを肯定形で確かめる（not (τ > 0) の形）。
static func _is_usable(cpu: CpuConfig) -> bool:
	var is_temperature_usable: bool = is_finite(cpu.temperature) and cpu.temperature > 0.0
	var is_floor_usable: bool = is_finite(cpu.floor_probability) \
			and cpu.floor_probability >= 0.0 and cpu.floor_probability < 1.0
	return is_temperature_usable and is_floor_usable


## 試合開始時・ハーフタイムの陣形と方式。選べる組み合わせ（陣形 × 守備方式 × 攻撃方式）から一様ランダムに選ぶ。
## 陣形が無ければ null を返す。
static func choose_setup(catalog: ContentCatalog, rng: RandomNumberGenerator) -> TeamSetup:
	if catalog.formations.is_empty():
		return null
	var formation: FormationDef = catalog.formations[rng.randi_range(0, catalog.formations.size() - 1)]
	return TeamSetup.new(formation.id, choose_styles(rng))


## 得失点後の方式。守備方式 × 攻撃方式から一様ランダムに選ぶ（陣形はハーフタイム以外で変えない）。
## enum の値が 0 から連続していること（GameEnums の定義）を前提に、添字をそのまま値にする。
static func choose_styles(rng: RandomNumberGenerator) -> TeamStyles:
	var defense: GameEnums.DefenseStyle = rng.randi_range(0, GameEnums.DefenseStyle.size() - 1) as GameEnums.DefenseStyle
	var attack: GameEnums.AttackStyle = rng.randi_range(0, GameEnums.AttackStyle.size() - 1) as GameEnums.AttackStyle
	return TeamStyles.new(defense, attack)


## 確率に従って添字を1つ選ぶ。浮動小数の誤差で累積が 1 に届かないときは最後の手にする。
static func _draw(probabilities_list: Array[float], rng: RandomNumberGenerator) -> int:
	var r: float = rng.randf()
	var cumulative: float = 0.0
	for index: int in range(probabilities_list.size()):
		cumulative += probabilities_list[index]
		if r < cumulative:
			return index
	return probabilities_list.size() - 1
