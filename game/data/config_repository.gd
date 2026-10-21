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

var _config_dir: String
var _match_rules: MatchRuleConfig
var _cpu: CpuConfig


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


func _load_match_rules() -> MatchRuleConfig:
	var loaded: MatchRuleConfig = _load(MATCH_RULE_FILE) as MatchRuleConfig
	if loaded == null:
		push_error("ConfigRepository: %s を読めないため、初期値を使う" % MATCH_RULE_FILE)
		return MatchRuleConfig.new()
	if not loaded.turns_per_half >= 1:
		push_error("ConfigRepository: %s の値が範囲外（turns_per_half=%d）のため、初期値を使う"
				% [MATCH_RULE_FILE, loaded.turns_per_half])
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
	var is_bonus_valid: bool = is_finite(loaded.style_bonus) and loaded.style_bonus >= 0.0
	if not (is_temperature_valid and is_floor_valid and is_bonus_valid):
		push_error("ConfigRepository: %s の値が範囲外（temperature=%s, floor_probability=%s, style_bonus=%s）のため、初期値を使う"
				% [CPU_FILE, loaded.temperature, loaded.floor_probability, loaded.style_bonus])
		return CpuConfig.new()
	return loaded


## ファイルが無ければ null（ResourceLoader.load は無いファイルでエンジンのエラーを出すため、先に存在を確かめる）。
func _load(file_name: String) -> Resource:
	var path: String = _config_dir.path_join(file_name)
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path)
