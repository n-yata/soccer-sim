## ゲームバランスの計測の補助（テスト専用）。固定シードで試合を最後まで回し、点の入り方と攻守の入れ替わりを数える。
## 試合の進め方は MatchController と同じ順（ターン → 得失点後の方式の選び直し → ハーフタイム）。方式・陣形は変えずに進める
## （計測したいのは手の選択と判定の規則で、方式の選び直しではないため）。
class_name MatchBalanceProbe
extends RefCounted

var matches: int = 0
var goals: int = 0
var home_goals: int = 0
var shots: int = 0
## 保持の回数（試合の最初の保持を含む。ボールが相手に渡るたびに1つ増える）と、保持したターンの合計。
## 得点後のキックオフ・ハーフタイムで渡った分も含む
var possessions: int = 0
var possession_turns: int = 0
## プレー中の入れ替わり（判定でボールが相手に渡った回数: ロスト・シュート阻止・奪回成功・オフサイド）。キックオフで渡った分は含まない
var turnovers: int = 0
## 攻守ターンのシュート以外の手で、守備が運ぶ先を読んだか（JudgeDetail.read がぴったり・隣）ごとの回数と、そのうちロストした回数
var read_moves: int = 0
var read_losses: int = 0
var unread_moves: int = 0
var unread_losses: int = 0
## 攻守ターンの攻撃の手の数と、そのうちのスルーパスの数・ロストした数（2026-10-25。強すぎないかをシャビが判断する材料）
var attack_moves: int = 0
var through_passes: int = 0
var through_losses: int = 0
## オフサイドの回数（2026-10-25。プレー中の入れ替わりにも数える）
var offsides: int = 0


## シードごとに match_count 試合を回して合計する（1つのシードの偶然で目標の内外が決まらないよう、複数のシードで測る）。
## HOME は home_cpu、AWAY は away_cpu の設定で CpuPlanner が手を選ぶ。
static func run(match_count: int, seeds: Array[int], home_cpu: CpuConfig, away_cpu: CpuConfig,
		catalog: ContentCatalog, rules: MatchRuleConfig) -> MatchBalanceProbe:
	var probe := MatchBalanceProbe.new()
	for seed_value: int in seeds:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for _index: int in range(match_count):
			probe._play(rng, home_cpu, away_cpu, catalog, rules)
	return probe


func goals_per_match() -> float:
	return float(goals) / matches


func home_goals_per_match() -> float:
	return float(home_goals) / matches


func possessions_per_match() -> float:
	return float(possessions) / matches


func average_possession_turns() -> float:
	return float(possession_turns) / possessions


func turnovers_per_match() -> float:
	return float(turnovers) / matches


func read_loss_rate() -> float:
	return float(read_losses) / read_moves


func unread_loss_rate() -> float:
	return float(unread_losses) / unread_moves


## 攻撃の手のうちスルーパスの割合と、スルーパスのうちロストした割合（どちらも 0〜1）
## 0件なら 0（CPU がスルーパスを一度も選ばない設定でも、要約に nan を出さない）
func through_pass_rate() -> float:
	return 0.0 if attack_moves == 0 else float(through_passes) / attack_moves


func through_pass_loss_rate() -> float:
	return 0.0 if through_passes == 0 else float(through_losses) / through_passes


func summary() -> String:
	return ("goals=%.2f home=%.2f shots=%.2f possessions=%.1f avg=%.1f turnovers=%.1f read_loss=%.0f%%"
			+ " unread_loss=%.0f%% through=%.0f%% through_loss=%.0f%% offsides=%.2f") % [goals_per_match(),
			home_goals_per_match(), float(shots) / matches, possessions_per_match(), average_possession_turns(),
			turnovers_per_match(), 100.0 * read_loss_rate(), 100.0 * unread_loss_rate(), 100.0 * through_pass_rate(),
			100.0 * through_pass_loss_rate(), float(offsides) / matches]


func _play(rng: RandomNumberGenerator, home_cpu: CpuConfig, away_cpu: CpuConfig, catalog: ContentCatalog,
		rules: MatchRuleConfig) -> void:
	var kickoff: GameEnums.TeamSide = GameEnums.TeamSide.HOME if rng.randi_range(0, 1) == 0 else GameEnums.TeamSide.AWAY
	var state: MatchState = MatchRules.create_match("probe", CpuPlanner.choose_setup(catalog, rng),
			CpuPlanner.choose_setup(catalog, rng), kickoff, catalog, "")
	var holder: GameEnums.TeamSide = state.possession
	possessions += 1
	# 規則の誤りで試合が終わらないときに、テストを止めないための上限（1試合のターン数と、得失点・ハーフタイムの段階の分）
	var guard: int = rules.turns_per_half * 8
	while not MatchRules.is_play_complete(state, rules):
		guard -= 1
		if guard <= 0:
			# 数えずに抜ける（matches が増えないので、呼び出し側のテストの試合数の確認で落ちる）
			push_error("MatchBalanceProbe: 試合が終わらない")
			return
		if state.stage == GameEnums.MatchStage.STYLE_CHANGE:
			state = MatchRules.apply_style_change(state, state.home_setup.styles, state.away_setup.styles)
			continue
		if state.stage == GameEnums.MatchStage.HALFTIME:
			state = MatchRules.apply_halftime(state, state.home_setup, state.away_setup, catalog)
			continue
		if state.possession != holder:
			holder = state.possession
			possessions += 1
		possession_turns += 1
		var home_choice: TurnChoice = CpuPlanner.choose_turn(state, GameEnums.TeamSide.HOME, home_cpu, rng)
		var away_choice: TurnChoice = CpuPlanner.choose_turn(state, GameEnums.TeamSide.AWAY, away_cpu, rng)
		var resolution: TurnResolution = MatchRules.resolve_turn(state, home_choice, away_choice, rules)
		_count(resolution.record)
		state = resolution.next_state
	matches += 1
	goals += state.home_score + state.away_score
	home_goals += state.home_score


func _count(record: TurnRecord) -> void:
	if record.outcome in [GameEnums.TurnOutcome.LOSS, GameEnums.TurnOutcome.SAVE, GameEnums.TurnOutcome.REGAIN,
			GameEnums.TurnOutcome.OFFSIDE]:
		turnovers += 1
	if record.outcome == GameEnums.TurnOutcome.OFFSIDE:
		offsides += 1
		# オフサイドは読み・人数で決まらないので、読みとスルーパスの集計（ロスト率）には入れない
		return
	if record.turn_kind != GameEnums.TurnKind.OPEN_PLAY:
		return
	var attack: TurnChoice = record.home_choice if record.attacker == GameEnums.TeamSide.HOME else record.away_choice
	attack_moves += 1
	if attack.action == GameEnums.PlayType.THROUGH_PASS:
		through_passes += 1
		through_losses += 1 if record.outcome == GameEnums.TurnOutcome.LOSS else 0
	if attack.action == GameEnums.PlayType.SHOT:
		shots += 1
		return
	var lost_count: int = 1 if record.outcome == GameEnums.TurnOutcome.LOSS else 0
	if record.judge.read != GameEnums.ReadKind.NONE:
		read_moves += 1
		read_losses += lost_count
	else:
		unread_moves += 1
		unread_losses += lost_count
