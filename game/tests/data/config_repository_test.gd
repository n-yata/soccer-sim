## ConfigRepository（component-design.md §4.2）のテスト。
## 値の範囲と初期値の正本は functional-overview.md「設定値として外部化する値」とエラーハンドリング「設定値が不正」。
## 壊れた .tres は、テストの中で一時ディレクトリに書いて読ませる。
extends GdUnitTestSuite

const MATCH_RULE_FILE: String = "match_rule_config.tres"
const CPU_FILE: String = "cpu_config.tres"


## turns と、τ・floor を持つ .tres を一時ディレクトリに書き、その場所を読む ConfigRepository を返す。
func _repository_with(case_name: String, turns: int, temperature: float, floor_probability: float,
		style_bonus: float = CpuConfig.new().style_bonus) -> ConfigRepository:
	var dir: String = create_temp_dir("config_repository/" + case_name)
	var rules := MatchRuleConfig.new()
	rules.turns_per_half = turns
	assert_int(ResourceSaver.save(rules, dir.path_join(MATCH_RULE_FILE))).is_equal(OK)
	var cpu := CpuConfig.new()
	cpu.temperature = temperature
	cpu.floor_probability = floor_probability
	cpu.style_bonus = style_bonus
	assert_int(ResourceSaver.save(cpu, dir.path_join(CPU_FILE))).is_equal(OK)
	return ConfigRepository.new(dir)


func test_bundled_settings_match_the_initial_values() -> void:
	# 同梱の .tres が範囲内で、functional-overview.md の初期値と一致する（不正なら開発時のこのテストで気づく）
	var repository := ConfigRepository.new()
	assert_int(repository.match_rules().turns_per_half).is_equal(12)
	assert_float(repository.cpu().temperature).is_equal(0.5)
	assert_float(repository.cpu().floor_probability).is_equal(0.05)
	assert_float(repository.cpu().style_bonus).is_equal(1.0)


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
	assert_int(repository.match_rules().turns_per_half).is_equal(12)
	assert_float(repository.cpu().temperature).is_equal(CpuConfig.new().temperature)


func test_zero_turns_falls_back_to_the_initial_value_with_an_error() -> void:
	var repository: ConfigRepository = _repository_with("zero_turns", 0, 1.0, 0.1)
	await assert_error(func() -> void: repository.match_rules()) \
			.is_push_error("ConfigRepository: match_rule_config.tres の値が範囲外（turns_per_half=0）のため、初期値を使う")
	assert_int(repository.match_rules().turns_per_half).is_equal(12)


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
			.is_push_error("ConfigRepository: cpu_config.tres の値が範囲外（temperature=0.0, floor_probability=0.1, style_bonus=%s）のため、初期値を使う"
					% CpuConfig.new().style_bonus)


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
	assert_int(repository.match_rules().turns_per_half).is_equal(12)


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


# --- 表示の調整値（PresentationConfig） ---

const PRESENTATION_FILE: String = "presentation_config.tres"


func _presentation_with(case_name: String, shift_sec: float) -> ConfigRepository:
	var dir: String = create_temp_dir("config_repository/presentation_" + case_name)
	var presentation := PresentationConfig.new()
	presentation.board_shift_sec = shift_sec
	assert_int(ResourceSaver.save(presentation, dir.path_join(PRESENTATION_FILE))).is_equal(OK)
	return ConfigRepository.new(dir)


func test_bundled_presentation_matches_the_initial_value() -> void:
	# functional-overview.md「設定値として外部化する値」の初期値 0.6 秒
	assert_float(ConfigRepository.new().presentation().board_shift_sec).is_equal(0.6)
	assert_float(PresentationConfig.new().board_shift_sec).is_equal(0.6)


func test_board_shift_inside_the_range_is_read_including_the_upper_bound() -> void:
	for shift_sec: float in [0.01, 1.2, 2.0]:
		var repository: ConfigRepository = _presentation_with("ok_%s" % shift_sec, shift_sec)
		assert_float(repository.presentation().board_shift_sec).override_failure_message(str(shift_sec)).is_equal(shift_sec)
	var cached: ConfigRepository = _presentation_with("cached", 1.0)
	assert_object(cached.presentation()).is_same(cached.presentation())


func test_out_of_range_board_shift_falls_back_to_the_initial_value() -> void:
	# 0 より大きく 2 以下の有限の値。0・負・2 超・NaN・無限大は範囲外
	for shift_sec: float in [0.0, -0.5, 2.01, NAN, INF]:
		var repository: ConfigRepository = _presentation_with("bad_%s" % shift_sec, shift_sec)
		assert_float(repository.presentation().board_shift_sec).override_failure_message(str(shift_sec)) \
				.is_equal(PresentationConfig.new().board_shift_sec)


func test_out_of_range_board_shift_reports_an_error() -> void:
	var repository: ConfigRepository = _presentation_with("error", 3.0)
	await assert_error(func() -> void: repository.presentation()) \
			.is_push_error("ConfigRepository: presentation_config.tres の値が範囲外（board_shift_sec=3.0）のため、初期値を使う")


func test_missing_presentation_falls_back_to_the_initial_value_with_an_error() -> void:
	var repository := ConfigRepository.new(create_temp_dir("config_repository/presentation_missing"))
	await assert_error(func() -> void: repository.presentation()) \
			.is_push_error("ConfigRepository: presentation_config.tres を読めないため、初期値を使う")
	assert_float(repository.presentation().board_shift_sec).is_equal(PresentationConfig.new().board_shift_sec)
