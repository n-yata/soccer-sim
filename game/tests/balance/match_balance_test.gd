## ゲームバランスの計測（.steering/20261023-game-balance・20261024-in-play-turnovers）。
## 目安はシャビと決めた 1試合 3〜5.5点（2026-10-24 に前後半 15ターン＋アディショナルタイムで 2〜3点から 3〜4.5点へ、基本配置の散らしと8方向のドリブルで 3〜5.5点へ広げた。点が多すぎるかはシャビが遊んで決める）、プレー中の攻守の入れ替わり 6〜10回・保持 2〜4ターン。
## 同梱の設定（cpu_config.tres・match_rule_config.tres）で、固定した複数のシードの試合を回して数える
## （1つのシードの偶然で目標の内外が決まらないよう、平均で見る）。規則や初期値を変えて目標から外れたら、ここで気づく。
extends GdUnitTestSuite

const MATCHES_PER_SEED: int = 50
const SEEDS: Array[int] = [20261024, 7, 99]

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
	_cpu_probe = MatchBalanceProbe.run(MATCHES_PER_SEED, SEEDS, _cpu, _cpu, _catalog, _rules)


## 利用者を模した手。CPU と同じ評価で、温度を下げ下限を 0 にして最善手を選びやすくする
func _user_like() -> CpuConfig:
	var cpu: CpuConfig = _cpu.duplicate() as CpuConfig
	cpu.temperature = 0.2
	cpu.floor_probability = 0.0
	return cpu


func test_cpu_matches_score_three_to_five_and_a_half_goals_and_change_hands_six_to_ten_times_in_play() -> void:
	# 入れ替わりはプレー中の分（ロスト・シュート阻止・奪回成功）。得点後のキックオフで渡った分は数えない
	var probe: MatchBalanceProbe = _cpu_probe
	assert_int(probe.matches).is_equal(MATCHES_PER_SEED * SEEDS.size())
	assert_float(probe.goals_per_match()).override_failure_message(probe.summary()).is_between(3.0, 5.5)
	assert_float(probe.turnovers_per_match()).override_failure_message(probe.summary()).is_between(6.0, 10.0)
	assert_float(probe.average_possession_turns()).override_failure_message(probe.summary()).is_between(2.0, 4.0)


func test_a_player_choosing_the_best_moves_scores_but_not_at_will() -> void:
	# 目安は CPU 同士（1チーム約2.2点）と同じかそれより多く、1試合で大差がつくほどではないこと
	var probe: MatchBalanceProbe = MatchBalanceProbe.run(MATCHES_PER_SEED, SEEDS, _user_like(), _cpu, _catalog, _rules)
	assert_int(probe.matches).is_equal(MATCHES_PER_SEED * SEEDS.size())
	assert_float(probe.home_goals_per_match()).override_failure_message(probe.summary()).is_between(1.0, 3.5)


func test_reading_the_target_wins_the_ball_more_often_than_guessing_wrong() -> void:
	# 読み合いが効いていること（ぴったり・隣を読むと、外したときより奪いやすい。アルゴリズム5）
	var probe: MatchBalanceProbe = _cpu_probe
	assert_int(probe.read_moves).is_greater(0)
	assert_int(probe.unread_moves).is_greater(0)
	assert_float(probe.read_loss_rate()).override_failure_message(probe.summary()).is_greater(probe.unread_loss_rate())
