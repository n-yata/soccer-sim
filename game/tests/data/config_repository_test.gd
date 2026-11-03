## ConfigRepository（component-design.md §4.2）のテスト。
## 値の範囲と初期値の正本は functional-overview.md「設定値として外部化する値」とエラーハンドリング「設定値が不正」。
## 壊れた .tres は、テストの中で一時ディレクトリに書いて読ませる。
extends GdUnitTestSuite

const MATCH_RULE_FILE: String = "match_rule_config.tres"
const CPU_FILE: String = "cpu_config.tres"


## turns と、τ・floor を持つ .tres を一時ディレクトリに書き、その場所を読む ConfigRepository を返す。
func _repository_with(case_name: String, turns: int, temperature: float, floor_probability: float,
		style_bonus: float = CpuConfig.new().style_bonus, forward_bonus: float = CpuConfig.new().forward_bonus,
		shot_bonus: float = CpuConfig.new().shot_bonus,
		anticipation_bonus: float = CpuConfig.new().anticipation_bonus,
		additional: int = 0, offside_penalty: float = CpuConfig.new().offside_penalty,
		marked_penalty: float = CpuConfig.new().marked_penalty) -> ConfigRepository:
	var dir: String = create_temp_dir("config_repository/" + case_name)
	var rules := MatchRuleConfig.new()
	rules.turns_per_half = turns
	rules.max_additional_turns = additional
	assert_int(ResourceSaver.save(rules, dir.path_join(MATCH_RULE_FILE))).is_equal(OK)
	var cpu := CpuConfig.new()
	cpu.temperature = temperature
	cpu.floor_probability = floor_probability
	cpu.style_bonus = style_bonus
	cpu.forward_bonus = forward_bonus
	cpu.shot_bonus = shot_bonus
	cpu.anticipation_bonus = anticipation_bonus
	cpu.offside_penalty = offside_penalty
	cpu.marked_penalty = marked_penalty
	assert_int(ResourceSaver.save(cpu, dir.path_join(CPU_FILE))).is_equal(OK)
	return ConfigRepository.new(dir)


func test_bundled_settings_match_the_initial_values() -> void:
	# 同梱の .tres が範囲内で、functional-overview.md の初期値と一致する（不正なら開発時のこのテストで気づく）
	var repository := ConfigRepository.new()
	assert_int(repository.match_rules().turns_per_half).is_equal(15)
	assert_int(repository.match_rules().max_additional_turns).is_equal(5)
	assert_float(repository.cpu().temperature).is_equal(0.5)
	assert_float(repository.cpu().floor_probability).is_equal(0.05)
	assert_float(repository.cpu().forward_bonus).is_equal(0.75)
	assert_float(repository.cpu().shot_bonus).is_equal(1.5)
	assert_float(repository.cpu().anticipation_bonus).is_equal(1.0)
	assert_float(repository.cpu().style_bonus).is_equal(1.0)
	assert_float(repository.cpu().offside_penalty).is_equal(3.0)
	assert_float(repository.cpu().marked_penalty).is_equal(3.0)


func test_valid_files_are_read_as_they_are() -> void:
	var repository: ConfigRepository = _repository_with("valid", 3, 0.5, 0.2)
	assert_int(repository.match_rules().turns_per_half).is_equal(3)
	assert_float(repository.cpu().temperature).is_equal(0.5)
	assert_float(repository.cpu().floor_probability).is_equal(0.2)


func test_values_are_read_once_and_kept() -> void:
	var repository: ConfigRepository = _repository_with("cached", 3, 0.5, 0.2)
	assert_object(repository.match_rules()).is_same(repository.match_rules())
	assert_object(repository.cpu()).is_same(repository.cpu())


func test_missing_files_fall_back_to_the_initial_values_with_an_error() -> void:
	var repository := ConfigRepository.new(create_temp_dir("config_repository/missing"))
	await assert_error(func() -> void: repository.match_rules()) \
			.is_push_error("ConfigRepository: match_rule_config.tres を読めないため、初期値を使う")
	await assert_error(func() -> void: repository.cpu()) \
			.is_push_error("ConfigRepository: cpu_config.tres を読めないため、初期値を使う")
	assert_int(repository.match_rules().turns_per_half).is_equal(15)
	assert_float(repository.cpu().temperature).is_equal(CpuConfig.new().temperature)


func test_zero_turns_falls_back_to_the_initial_value_with_an_error() -> void:
	var repository: ConfigRepository = _repository_with("zero_turns", 0, 1.0, 0.1)
	await assert_error(func() -> void: repository.match_rules()) \
			.is_push_error("ConfigRepository: match_rule_config.tres の値が範囲外（turns_per_half=0, max_additional_turns=0）のため、初期値を使う")
	assert_int(repository.match_rules().turns_per_half).is_equal(15)


func test_out_of_range_cpu_values_fall_back_to_the_initial_values() -> void:
	# 境界: τ は 0 より大きい、floor は 0 以上 1 未満。NaN・無限大も範囲外（τ = INF は「0 より大きい」を満たすので、
	# 有限であることを確かめていなければ通ってしまう）
	for case: Array in [[0.0, 0.1], [-1.0, 0.1], [1.0, 1.0], [1.0, -0.1], [INF, 0.1], [NAN, 0.1], [1.0, NAN]]:
		var repository: ConfigRepository = _repository_with("cpu_%s_%s" % [case[0], case[1]], 12, case[0] as float, case[1] as float)
		var cpu: CpuConfig = repository.cpu()
		assert_float(cpu.temperature).override_failure_message(str(case)).is_equal(CpuConfig.new().temperature)
		assert_float(cpu.floor_probability).override_failure_message(str(case)).is_equal(CpuConfig.new().floor_probability)


func test_out_of_range_cpu_values_report_an_error() -> void:
	var repository: ConfigRepository = _repository_with("cpu_error", 12, 0.0, 0.1)
	await assert_error(func() -> void: repository.cpu()) \
			.is_push_error(("ConfigRepository: cpu_config.tres の値が範囲外（temperature=0.0, floor_probability=0.1, style_bonus=%s,"
					+ " forward_bonus=%s, shot_bonus=%s, anticipation_bonus=%s, offside_penalty=%s, marked_penalty=%s）のため、初期値を使う")
					% [CpuConfig.new().style_bonus, CpuConfig.new().forward_bonus, CpuConfig.new().shot_bonus,
							CpuConfig.new().anticipation_bonus, CpuConfig.new().offside_penalty,
							CpuConfig.new().marked_penalty])


func test_negative_additional_turns_fall_back_to_the_initial_values_with_an_error() -> void:
	var repository: ConfigRepository = _repository_with("negative_additional", 3, 1.0, 0.1,
			CpuConfig.new().style_bonus, CpuConfig.new().forward_bonus, CpuConfig.new().shot_bonus,
			CpuConfig.new().anticipation_bonus, -1)
	await assert_error(func() -> void: repository.match_rules()) \
			.is_push_error("ConfigRepository: match_rule_config.tres の値が範囲外（turns_per_half=3, max_additional_turns=-1）のため、初期値を使う")
	assert_int(repository.match_rules().turns_per_half).is_equal(15)
	assert_int(repository.match_rules().max_additional_turns).is_equal(5)


func test_additional_turns_above_the_turns_per_half_fall_back_to_the_initial_values() -> void:
	# 上限は1ハーフのターン数（保存データの件数の上限が効くように。ありえない値で試合が延びないように）
	var repository: ConfigRepository = _repository_with("too_many_additional", 3, 1.0, 0.1,
			CpuConfig.new().style_bonus, CpuConfig.new().forward_bonus, CpuConfig.new().shot_bonus,
			CpuConfig.new().anticipation_bonus, 4)
	await assert_error(func() -> void: repository.match_rules()) \
			.is_push_error("ConfigRepository: match_rule_config.tres の値が範囲外（turns_per_half=3, max_additional_turns=4）のため、初期値を使う")
	assert_int(repository.match_rules().max_additional_turns).is_equal(5)
	# 境界: ターン数と同じなら受け付ける
	var equal: ConfigRepository = _repository_with("equal_additional", 3, 1.0, 0.1,
			CpuConfig.new().style_bonus, CpuConfig.new().forward_bonus, CpuConfig.new().shot_bonus,
			CpuConfig.new().anticipation_bonus, 3)
	assert_int(equal.match_rules().max_additional_turns).is_equal(3)


func test_zero_additional_turns_are_accepted() -> void:
	# 境界: アディショナルタイムの上限 0 は「アディショナルタイム無し」として受け付ける
	var repository: ConfigRepository = _repository_with("zero_additional", 3, 1.0, 0.1,
			CpuConfig.new().style_bonus, CpuConfig.new().forward_bonus, CpuConfig.new().shot_bonus,
			CpuConfig.new().anticipation_bonus, 0)
	assert_int(repository.match_rules().max_additional_turns).is_equal(0)


func test_boundary_values_inside_the_range_are_accepted() -> void:
	var repository: ConfigRepository = _repository_with("boundary", 1, 0.001, 0.0)
	assert_int(repository.match_rules().turns_per_half).is_equal(1)
	assert_float(repository.cpu().temperature).is_equal(0.001)
	assert_float(repository.cpu().floor_probability).is_equal(0.0)


func test_a_file_of_the_wrong_type_falls_back_to_the_initial_value() -> void:
	# match_rule_config.tres に CpuConfig を書いた
	var dir: String = create_temp_dir("config_repository/wrong_type")
	assert_int(ResourceSaver.save(CpuConfig.new(), dir.path_join(MATCH_RULE_FILE))).is_equal(OK)
	var repository := ConfigRepository.new(dir)
	await assert_error(func() -> void: repository.match_rules()) \
			.is_push_error("ConfigRepository: match_rule_config.tres を読めないため、初期値を使う")
	assert_int(repository.match_rules().turns_per_half).is_equal(15)


func test_style_bonus_is_read_including_zero() -> void:
	for bonus: float in [0.0, 2.5]:
		var repository: ConfigRepository = _repository_with("bonus_%s" % bonus, 12, 0.5, 0.2, bonus)
		assert_float(repository.cpu().style_bonus).override_failure_message(str(bonus)).is_equal(bonus)


func test_out_of_range_style_bonus_falls_back_to_the_initial_values() -> void:
	# 加点は 0 以上の有限の値。負・NaN・無限大は範囲外で、ほかの値と一緒に初期値へ戻す
	for bonus: float in [-0.1, NAN, INF]:
		var repository: ConfigRepository = _repository_with("bad_bonus_%s" % bonus, 12, 0.5, 0.2, bonus)
		var cpu: CpuConfig = repository.cpu()
		assert_float(cpu.style_bonus).override_failure_message(str(bonus)).is_equal(CpuConfig.new().style_bonus)
		assert_float(cpu.temperature).override_failure_message(str(bonus)).is_equal(CpuConfig.new().temperature)


func test_forward_and_shot_bonuses_are_read_including_zero() -> void:
	for bonus: float in [0.0, 2.5]:
		var repository: ConfigRepository = _repository_with("goal_bonus_%s" % bonus, 12, 0.5, 0.2, 1.0, bonus, bonus + 1.0)
		assert_float(repository.cpu().forward_bonus).override_failure_message(str(bonus)).is_equal(bonus)
		assert_float(repository.cpu().shot_bonus).override_failure_message(str(bonus)).is_equal(bonus + 1.0)


func test_out_of_range_forward_and_shot_bonuses_fall_back_to_the_initial_values() -> void:
	# 前へ運ぶ加点・シュートの加点は、それぞれ 0 以上の有限の値。片方だけ範囲外でも、全体を初期値へ戻す
	for case: Array in [[-0.1, 1.0], [NAN, 1.0], [INF, 1.0], [1.0, -0.1], [1.0, NAN], [1.0, INF]]:
		var repository: ConfigRepository = _repository_with("bad_goal_%s_%s" % [case[0], case[1]], 12, 0.5, 0.2, 2.0,
				case[0] as float, case[1] as float)
		var cpu: CpuConfig = repository.cpu()
		assert_float(cpu.forward_bonus).override_failure_message(str(case)).is_equal(CpuConfig.new().forward_bonus)
		assert_float(cpu.shot_bonus).override_failure_message(str(case)).is_equal(CpuConfig.new().shot_bonus)
		assert_float(cpu.style_bonus).override_failure_message(str(case)).is_equal(CpuConfig.new().style_bonus)


func test_anticipation_bonus_is_read_including_zero() -> void:
	for bonus: float in [0.0, 2.5]:
		var repository: ConfigRepository = _repository_with("anticipation_%s" % bonus, 12, 0.5, 0.2, 1.0, 1.0, 1.0, bonus)
		assert_float(repository.cpu().anticipation_bonus).override_failure_message(str(bonus)).is_equal(bonus)


func test_out_of_range_anticipation_bonus_falls_back_to_the_initial_values() -> void:
	# 先読みの加点も 0 以上の有限の値。範囲外なら、ほかの値と一緒に初期値へ戻す
	for bonus: float in [-0.1, NAN, INF]:
		var repository: ConfigRepository = _repository_with("bad_anticipation_%s" % bonus, 12, 0.5, 0.2, 2.0, 2.0, 2.0, bonus)
		var cpu: CpuConfig = repository.cpu()
		assert_float(cpu.anticipation_bonus).override_failure_message(str(bonus)).is_equal(CpuConfig.new().anticipation_bonus)
		assert_float(cpu.forward_bonus).override_failure_message(str(bonus)).is_equal(CpuConfig.new().forward_bonus)


func test_offside_penalty_is_read_including_zero() -> void:
	# オフサイドの減点（2026-10-25）。0 なら CPU はオフサイドを避けない
	for penalty: float in [0.0, 4.5]:
		var repository: ConfigRepository = _repository_with("offside_%s" % penalty, 12, 0.5, 0.2, 1.0, 1.0, 1.0, 1.0, 0,
				penalty)
		assert_float(repository.cpu().offside_penalty).override_failure_message(str(penalty)).is_equal(penalty)


func test_out_of_range_offside_penalty_falls_back_to_the_initial_values() -> void:
	# 減点も 0 以上の有限の値（負なら、オフサイドになる手を好むことになる）。範囲外なら、ほかの値と一緒に初期値へ戻す
	for penalty: float in [-0.1, NAN, INF]:
		var repository: ConfigRepository = _repository_with("bad_offside_%s" % penalty, 12, 0.5, 0.2, 2.0, 2.0, 2.0, 2.0, 0,
				penalty)
		var cpu: CpuConfig = repository.cpu()
		assert_float(cpu.offside_penalty).override_failure_message(str(penalty)).is_equal(CpuConfig.new().offside_penalty)
		assert_float(cpu.anticipation_bonus).override_failure_message(str(penalty)).is_equal(CpuConfig.new().anticipation_bonus)


func test_marked_penalty_is_read_including_zero() -> void:
	# マーク注意の減点（2026-10-29）。0 なら CPU はマーカーがついてくるスルーパスを避けない
	for penalty: float in [0.0, 4.5]:
		var repository: ConfigRepository = _repository_with("marked_%s" % penalty, 12, 0.5, 0.2, 1.0, 1.0, 1.0, 1.0, 0,
				CpuConfig.new().offside_penalty, penalty)
		assert_float(repository.cpu().marked_penalty).override_failure_message(str(penalty)).is_equal(penalty)


func test_out_of_range_marked_penalty_falls_back_to_the_initial_values() -> void:
	# 負なら、マーカーがついてくる手を好むことになる。範囲外なら、ほかの値と一緒に初期値へ戻す
	for penalty: float in [-0.1, NAN, INF]:
		var repository: ConfigRepository = _repository_with("bad_marked_%s" % penalty, 12, 0.5, 0.2, 2.0, 2.0, 2.0, 2.0, 0,
				CpuConfig.new().offside_penalty, penalty)
		var cpu: CpuConfig = repository.cpu()
		assert_float(cpu.marked_penalty).override_failure_message(str(penalty)).is_equal(CpuConfig.new().marked_penalty)
		assert_float(cpu.anticipation_bonus).override_failure_message(str(penalty)).is_equal(CpuConfig.new().anticipation_bonus)


# --- 表示の調整値（PresentationConfig） ---

const PRESENTATION_FILE: String = "presentation_config.tres"


func _presentation_with(case_name: String, settle_sec: float, lookback_turns: int = 3, play_sec: float = 0.6) -> ConfigRepository:
	var dir: String = create_temp_dir("config_repository/presentation_" + case_name)
	var presentation := PresentationConfig.new()
	presentation.board_settle_sec = settle_sec
	presentation.review_lookback_turns = lookback_turns
	presentation.board_play_sec = play_sec
	assert_int(ResourceSaver.save(presentation, dir.path_join(PRESENTATION_FILE))).is_equal(OK)
	return ConfigRepository.new(dir)


func test_bundled_presentation_matches_the_initial_value() -> void:
	# functional-overview.md「設定値として外部化する値」の初期値 0.6 秒
	assert_float(ConfigRepository.new().presentation().board_settle_sec).is_equal(0.6)
	assert_float(PresentationConfig.new().board_settle_sec).is_equal(0.6)


func test_bundled_presentation_file_uses_the_current_keys() -> void:
	# Godot は .tres の知らないキーを黙って無視し、その値を既定値で読む。同梱値が既定値と同じ間は、上の確認では
	# 古いキー（2026-11-03 に board_shift_sec から board_settle_sec へ改名）の取りこぼしに気づけないため、文字列で確かめる
	var text: String = FileAccess.get_file_as_string("res://config/" + PRESENTATION_FILE)
	assert_str(text).contains("board_play_sec = ")
	assert_str(text).contains("board_settle_sec = ")
	assert_str(text).not_contains("board_shift_sec")


func test_board_settle_inside_the_range_is_read_including_the_upper_bound() -> void:
	for settle_sec: float in [0.01, 1.2, 2.0]:
		var repository: ConfigRepository = _presentation_with("ok_%s" % settle_sec, settle_sec)
		assert_float(repository.presentation().board_settle_sec).override_failure_message(str(settle_sec)).is_equal(settle_sec)
	var cached: ConfigRepository = _presentation_with("cached", 1.0)
	assert_object(cached.presentation()).is_same(cached.presentation())


func test_out_of_range_board_settle_falls_back_to_the_initial_value() -> void:
	# 0 より大きく 2 以下の有限の値。0・負・2 超・NaN・無限大は範囲外
	for settle_sec: float in [0.0, -0.5, 2.01, NAN, INF]:
		var repository: ConfigRepository = _presentation_with("bad_%s" % settle_sec, settle_sec)
		assert_float(repository.presentation().board_settle_sec).override_failure_message(str(settle_sec)) \
				.is_equal(PresentationConfig.new().board_settle_sec)


func test_out_of_range_board_settle_reports_an_error() -> void:
	var repository: ConfigRepository = _presentation_with("error", 3.0)
	await assert_error(func() -> void: repository.presentation()) \
			.is_push_error("ConfigRepository: presentation_config.tres の値が範囲外（board_settle_sec=3.0）のため、初期値を使う")


func test_bundled_board_play_matches_the_initial_value() -> void:
	# functional-overview.md「設定値として外部化する値」の、開示の1拍目（プレー）の初期値 0.6 秒
	assert_float(ConfigRepository.new().presentation().board_play_sec).is_equal(0.6)
	assert_float(PresentationConfig.new().board_play_sec).is_equal(0.6)


func test_board_play_inside_the_range_is_read_including_the_upper_bound() -> void:
	for play_sec: float in [0.01, 1.2, 2.0]:
		var repository: ConfigRepository = _presentation_with("play_ok_%s" % play_sec, 0.6, 3, play_sec)
		assert_float(repository.presentation().board_play_sec).override_failure_message(str(play_sec)).is_equal(play_sec)


func test_out_of_range_board_play_falls_back_to_the_initial_value() -> void:
	# 2拍目と同じ範囲（0 より大きく 2 以下の有限の値）
	for play_sec: float in [0.0, -0.5, 2.01, NAN, INF]:
		var repository: ConfigRepository = _presentation_with("play_bad_%s" % play_sec, 1.0, 3, play_sec)
		assert_float(repository.presentation().board_play_sec).override_failure_message(str(play_sec)) \
				.is_equal(PresentationConfig.new().board_play_sec)
		# 1つでも範囲外なら、ファイル全体を初期値に戻す（ほかの値と同じ扱い）
		assert_float(repository.presentation().board_settle_sec).override_failure_message(str(play_sec)) \
				.is_equal(PresentationConfig.new().board_settle_sec)


func test_out_of_range_board_play_reports_an_error() -> void:
	var repository: ConfigRepository = _presentation_with("play_error", 0.6, 3, 3.0)
	await assert_error(func() -> void: repository.presentation()) \
			.is_push_error("ConfigRepository: presentation_config.tres の値が範囲外（board_play_sec=3.0）のため、初期値を使う")


func test_bundled_review_lookback_matches_the_initial_value() -> void:
	# functional-overview.md「設定値として外部化する値」の「振り返りで得失点の直前に遡るターン数」の初期値 3
	assert_int(ConfigRepository.new().presentation().review_lookback_turns).is_equal(3)
	assert_int(PresentationConfig.new().review_lookback_turns).is_equal(3)


func test_review_lookback_of_zero_or_more_is_read() -> void:
	for lookback: int in [0, 1, 10]:
		var repository: ConfigRepository = _presentation_with("lookback_%d" % lookback, 0.6, lookback)
		assert_int(repository.presentation().review_lookback_turns).override_failure_message(str(lookback)) \
				.is_equal(lookback)


func test_negative_review_lookback_falls_back_to_the_initial_value_with_an_error() -> void:
	var repository: ConfigRepository = _presentation_with("lookback_bad", 0.6, -1)
	await assert_error(func() -> void: repository.presentation()) \
			.is_push_error("ConfigRepository: presentation_config.tres の値が範囲外（review_lookback_turns=-1）のため、初期値を使う")
	assert_int(repository.presentation().review_lookback_turns).is_equal(PresentationConfig.new().review_lookback_turns)


func test_bundled_board_result_matches_the_initial_value() -> void:
	# functional-overview.md「設定値として外部化する値」の、結果の演出を出す時間の初期値 0.8 秒
	assert_float(ConfigRepository.new().presentation().board_result_sec).is_equal(0.8)
	assert_float(PresentationConfig.new().board_result_sec).is_equal(0.8)
	assert_str(FileAccess.get_file_as_string("res://config/" + PRESENTATION_FILE)).contains("board_result_sec = ")


func _board_result_with(case_name: String, result_sec: float) -> ConfigRepository:
	var dir: String = create_temp_dir("config_repository/board_result_" + case_name)
	var presentation := PresentationConfig.new()
	presentation.board_result_sec = result_sec
	assert_int(ResourceSaver.save(presentation, dir.path_join(PRESENTATION_FILE))).is_equal(OK)
	return ConfigRepository.new(dir)


func test_board_result_inside_the_range_is_read_including_the_upper_bound() -> void:
	for result_sec: float in [0.01, 1.2, 2.0]:
		var repository: ConfigRepository = _board_result_with("ok_%s" % result_sec, result_sec)
		assert_float(repository.presentation().board_result_sec).override_failure_message(str(result_sec)).is_equal(result_sec)


func test_out_of_range_board_result_falls_back_to_the_initial_value() -> void:
	# 拍の長さと同じ範囲（0 より大きく 2 以下の有限の値）
	for result_sec: float in [0.0, -0.5, 2.01, NAN, INF]:
		var repository: ConfigRepository = _board_result_with("bad_%s" % result_sec, result_sec)
		assert_float(repository.presentation().board_result_sec).override_failure_message(str(result_sec)) \
				.is_equal(PresentationConfig.new().board_result_sec)


func test_out_of_range_board_result_reports_an_error() -> void:
	var repository: ConfigRepository = _board_result_with("error", 3.0)
	await assert_error(func() -> void: repository.presentation()) \
			.is_push_error("ConfigRepository: presentation_config.tres の値が範囲外（board_result_sec=3.0）のため、初期値を使う")


## ボールの軌道の値（浮き球の高さ loft・ドリブルの弾みの高さ touch・弾みの回数 touches）だけを変えた設定
func _ball_style_with(case_name: String, loft: float, touch: float, touches: int) -> ConfigRepository:
	var dir: String = create_temp_dir("config_repository/ball_style_" + case_name)
	var presentation := PresentationConfig.new()
	presentation.ball_loft_height = loft
	presentation.ball_touch_height = touch
	presentation.ball_dribble_touches = touches
	assert_int(ResourceSaver.save(presentation, dir.path_join(PRESENTATION_FILE))).is_equal(OK)
	return ConfigRepository.new(dir)


func test_bundled_ball_style_matches_the_initial_value() -> void:
	# functional-overview.md「設定値として外部化する値」の初期値（浮き球 6.0・弾み 1.0・3回）
	var bundled: PresentationConfig = ConfigRepository.new().presentation()
	var initial := PresentationConfig.new()
	for config: PresentationConfig in [bundled, initial]:
		assert_float(config.ball_loft_height).is_equal(6.0)
		assert_float(config.ball_touch_height).is_equal(1.0)
		assert_int(config.ball_dribble_touches).is_equal(3)
	var text: String = FileAccess.get_file_as_string("res://config/" + PRESENTATION_FILE)
	for key: String in ["ball_loft_height = ", "ball_touch_height = ", "ball_dribble_touches = "]:
		assert_str(text).contains(key)


func test_ball_style_inside_the_range_is_read_including_the_bounds() -> void:
	# 下限（0・0・1）と上限（20・5・8）を含む
	for values: Array in [[0.0, 0.0, 1], [20.0, 5.0, 8], [3.5, 0.5, 2]]:
		var repository: ConfigRepository = _ball_style_with("ok_%s_%s_%s" % values, values[0], values[1], values[2])
		var config: PresentationConfig = repository.presentation()
		assert_float(config.ball_loft_height).override_failure_message(str(values)).is_equal(values[0] as float)
		assert_float(config.ball_touch_height).override_failure_message(str(values)).is_equal(values[1] as float)
		assert_int(config.ball_dribble_touches).override_failure_message(str(values)).is_equal(values[2] as int)


func test_out_of_range_ball_style_falls_back_to_the_initial_value() -> void:
	var initial := PresentationConfig.new()
	# どれか1つが範囲外（負・上限超え・NaN・無限大・回数 0 と 9）なら、ファイル全体を初期値に戻す
	for values: Array in [[-0.1, 1.0, 3], [20.01, 1.0, 3], [NAN, 1.0, 3], [INF, 1.0, 3],
			[6.0, -0.1, 3], [6.0, 5.01, 3], [6.0, NAN, 3], [6.0, 1.0, 0], [6.0, 1.0, 9]]:
		var repository: ConfigRepository = _ball_style_with("bad_%s_%s_%s" % values, values[0], values[1], values[2])
		var config: PresentationConfig = repository.presentation()
		assert_float(config.ball_loft_height).override_failure_message(str(values)).is_equal(initial.ball_loft_height)
		assert_float(config.ball_touch_height).override_failure_message(str(values)).is_equal(initial.ball_touch_height)
		assert_int(config.ball_dribble_touches).override_failure_message(str(values)).is_equal(initial.ball_dribble_touches)


func test_out_of_range_ball_style_reports_an_error() -> void:
	var repository: ConfigRepository = _ball_style_with("error", 6.0, 1.0, 0)
	await assert_error(func() -> void: repository.presentation()) \
			.is_push_error("ConfigRepository: presentation_config.tres の値が範囲外（ball_loft_height=6.0, ball_touch_height=1.0, ball_dribble_touches=0）のため、初期値を使う")


func test_missing_presentation_falls_back_to_the_initial_value_with_an_error() -> void:
	var repository := ConfigRepository.new(create_temp_dir("config_repository/presentation_missing"))
	await assert_error(func() -> void: repository.presentation()) \
			.is_push_error("ConfigRepository: presentation_config.tres を読めないため、初期値を使う")
	assert_float(repository.presentation().board_settle_sec).is_equal(PresentationConfig.new().board_settle_sec)
