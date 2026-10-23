## ゲームバランスの計測（.steering/20261023-game-balance。目標はシャビと決めた 1試合 2〜3点、攻守の入れ替わり 6〜10回）。
## 同梱の設定（cpu_config.tres・match_rule_config.tres）で、固定シードの試合を回して数える。
## 規則や初期値を変えてバランスが目標から外れたら、ここで気づく。
extends GdUnitTestSuite

const MATCHES: int = 100
const SEED: int = 20261024

var _catalog: ContentCatalog
var _rules: MatchRuleConfig
var _cpu: CpuConfig
## CPU 同士の計測（2つのテストで共有する。試合を回すのに時間がかかるため1回だけ）
var _cpu_probe: MatchBalanceProbe


func before() -> void:
	_catalog = ContentRepository.new().load_catalog()
	var repository := ConfigRepository.new()
	_rules = repository.match_rules()
	_cpu = repository.cpu()
	_cpu_probe = MatchBalanceProbe.run(MATCHES, SEED, _cpu, _cpu, _catalog, _rules)


## 利用者を模した手。CPU と同じ評価で、温度を下げ下限を 0 にして最善手を選びやすくする
func _user_like() -> CpuConfig:
	var cpu: CpuConfig = _cpu.duplicate() as CpuConfig
	cpu.temperature = 0.2
	cpu.floor_probability = 0.0
	return cpu


func test_cpu_matches_score_two_to_three_goals_over_six_to_ten_possessions() -> void:
	# 保持の回数は、得点後のキックオフで渡った分を含む（プレー中の入れ替わりは turnovers。summary に出す）
	var probe: MatchBalanceProbe = _cpu_probe
	assert_int(probe.matches).is_equal(MATCHES)
	assert_float(probe.goals_per_match()).override_failure_message(probe.summary()).is_between(2.0, 3.0)
	assert_float(probe.possessions_per_match()).override_failure_message(probe.summary()).is_between(6.0, 10.0)
	assert_float(probe.average_possession_turns()).override_failure_message(probe.summary()).is_between(2.0, 4.0)


func test_a_player_choosing_the_best_moves_scores_but_not_at_will() -> void:
	# 目安は CPU 同士（1チーム約1.4点）より多く、1試合で大差がつくほどではないこと
	var probe: MatchBalanceProbe = MatchBalanceProbe.run(MATCHES, SEED, _user_like(), _cpu, _catalog, _rules)
	assert_int(probe.matches).is_equal(MATCHES)
	assert_float(probe.home_goals_per_match()).override_failure_message(probe.summary()).is_between(1.0, 2.5)


func test_reading_the_target_wins_the_ball_more_often_than_guessing_wrong() -> void:
	# 読み合いが効いていること（読みを当てると、外したときより奪いやすい。アルゴリズム5）
	var probe: MatchBalanceProbe = _cpu_probe
	assert_int(probe.read_moves).is_greater(0)
	assert_int(probe.unread_moves).is_greater(0)
	assert_float(probe.read_loss_rate()).override_failure_message(probe.summary()).is_greater(probe.unread_loss_rate())
