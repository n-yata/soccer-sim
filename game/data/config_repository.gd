## 調整値（game/config/*.tres）を読む（component-design.md §4.2）。値の一覧と初期値の正本は
## functional-overview.md「設定値として外部化する値」。
##
## 読めない・型が違う・範囲外のときは、初期値の Resource を返して push_error する（エラーハンドリング「設定値が不正」:
## 初期値を使い、利用者には表示しない。同梱の .tres が範囲内であることは開発時のテストで確かめる）。
## 範囲は内側にあることを肯定形で確かめる（NaN との比較は常に偽になるため、「範囲外なら拒否」の形だと NaN が通る）。
class_name ConfigRepository
extends RefCounted

const MATCH_RULE_FILE: String = "match_rule_config.tres"
const CPU_FILE: String = "cpu_config.tres"
const PRESENTATION_FILE: String = "presentation_config.tres"
## 駒を動かす時間の上限（秒）。範囲の正本は functional-overview.md「設定値として外部化する値」
const MAX_BOARD_SHIFT_SEC: float = 2.0

var _config_dir: String
var _match_rules: MatchRuleConfig
var _cpu: CpuConfig
var _presentation: PresentationConfig


## config_dir はテストで別の場所を読ませるための引数。アプリは既定値を使う。
func _init(config_dir: String = "res://config") -> void:
	_config_dir = config_dir


## 1ハーフのターン数など。1回読んだら持っておく。
func match_rules() -> MatchRuleConfig:
	if _match_rules == null:
		_match_rules = _load_match_rules()
	return _match_rules


## CPU の温度・下限確率。1回読んだら持っておく。
func cpu() -> CpuConfig:
	if _cpu == null:
		_cpu = _load_cpu()
	return _cpu


## 開示で駒を動かす時間など。1回読んだら持っておく。
func presentation() -> PresentationConfig:
	if _presentation == null:
		_presentation = _load_presentation()
	return _presentation


func _load_match_rules() -> MatchRuleConfig:
	var loaded: MatchRuleConfig = _load(MATCH_RULE_FILE) as MatchRuleConfig
	if loaded == null:
		push_error("ConfigRepository: %s を読めないため、初期値を使う" % MATCH_RULE_FILE)
		return MatchRuleConfig.new()
	# アディショナルタイムの上限は1ハーフのターン数まで（保存データの件数の上限が効くように）
	if not (loaded.turns_per_half >= 1 and loaded.max_additional_turns >= 0
			and loaded.max_additional_turns <= loaded.turns_per_half):
		push_error("ConfigRepository: %s の値が範囲外（turns_per_half=%d, max_additional_turns=%d）のため、初期値を使う"
				% [MATCH_RULE_FILE, loaded.turns_per_half, loaded.max_additional_turns])
		return MatchRuleConfig.new()
	return loaded


func _load_cpu() -> CpuConfig:
	var loaded: CpuConfig = _load(CPU_FILE) as CpuConfig
	if loaded == null:
		push_error("ConfigRepository: %s を読めないため、初期値を使う" % CPU_FILE)
		return CpuConfig.new()
	var is_temperature_valid: bool = is_finite(loaded.temperature) and loaded.temperature > 0.0
	var is_floor_valid: bool = is_finite(loaded.floor_probability) \
			and loaded.floor_probability >= 0.0 and loaded.floor_probability < 1.0
	var is_bonus_valid: bool = _is_bonus_valid(loaded.style_bonus) and _is_bonus_valid(loaded.forward_bonus) \
			and _is_bonus_valid(loaded.shot_bonus) and _is_bonus_valid(loaded.anticipation_bonus)
	if not (is_temperature_valid and is_floor_valid and is_bonus_valid):
		push_error(("ConfigRepository: %s の値が範囲外（temperature=%s, floor_probability=%s, style_bonus=%s,"
				+ " forward_bonus=%s, shot_bonus=%s, anticipation_bonus=%s）のため、初期値を使う")
				% [CPU_FILE, loaded.temperature, loaded.floor_probability, loaded.style_bonus, loaded.forward_bonus,
						loaded.shot_bonus, loaded.anticipation_bonus])
		return CpuConfig.new()
	return loaded


## 加点は 0 以上の有限の値（NaN でも偽になるよう、肯定形で確かめる）。
static func _is_bonus_valid(bonus: float) -> bool:
	return is_finite(bonus) and bonus >= 0.0


func _load_presentation() -> PresentationConfig:
	var loaded: PresentationConfig = _load(PRESENTATION_FILE) as PresentationConfig
	if loaded == null:
		push_error("ConfigRepository: %s を読めないため、初期値を使う" % PRESENTATION_FILE)
		return PresentationConfig.new()
	var shift_sec: float = loaded.board_shift_sec
	if not (is_finite(shift_sec) and shift_sec > 0.0 and shift_sec <= MAX_BOARD_SHIFT_SEC):
		push_error("ConfigRepository: %s の値が範囲外（board_shift_sec=%s）のため、初期値を使う" % [PRESENTATION_FILE, shift_sec])
		return PresentationConfig.new()
	return loaded


## ファイルが無ければ null（ResourceLoader.load は無いファイルでエンジンのエラーを出すため、先に存在を確かめる）。
func _load(file_name: String) -> Resource:
	var path: String = _config_dir.path_join(file_name)
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path)
