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
const MAX_BOARD_BEAT_SEC: float = 2.0
## ボールの軌道の上限（浮き球の高さ・ドリブルの弾みの高さはボールの半径の何倍か、弾みは回数）。範囲の正本は同じ表
const MAX_BALL_LOFT_HEIGHT: float = 20.0
const MAX_BALL_TOUCH_HEIGHT: float = 5.0
const MAX_BALL_DRIBBLE_TOUCHES: int = 8
## 駒の動きの上限（ずらしの幅は拍の時間の割合、弾みの高さは駒の半径の何倍か、小休止は秒）。範囲の正本は同じ表
const MAX_PIECE_STAGGER: float = 0.8
const MAX_PIECE_HOP_HEIGHT: float = 1.5
const MAX_BOARD_BEAT_GAP_SEC: float = 0.5

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
			and _is_bonus_valid(loaded.shot_bonus) and _is_bonus_valid(loaded.anticipation_bonus) \
			and _is_bonus_valid(loaded.offside_penalty) and _is_bonus_valid(loaded.marked_penalty)
	if not (is_temperature_valid and is_floor_valid and is_bonus_valid):
		push_error(("ConfigRepository: %s の値が範囲外（temperature=%s, floor_probability=%s, style_bonus=%s,"
				+ " forward_bonus=%s, shot_bonus=%s, anticipation_bonus=%s, offside_penalty=%s, marked_penalty=%s）のため、初期値を使う")
				% [CPU_FILE, loaded.temperature, loaded.floor_probability, loaded.style_bonus, loaded.forward_bonus,
						loaded.shot_bonus, loaded.anticipation_bonus, loaded.offside_penalty, loaded.marked_penalty])
		return CpuConfig.new()
	return loaded


## 加点は 0 以上の有限の値（NaN でも偽になるよう、肯定形で確かめる）。
static func _is_bonus_valid(bonus: float) -> bool:
	return is_finite(bonus) and bonus >= 0.0


## 開示の拍の長さは 0 より大きく MAX_BOARD_BEAT_SEC 以下の有限の値（NaN でも偽になるよう、肯定形で確かめる）。
static func _is_board_sec_valid(sec: float) -> bool:
	return is_finite(sec) and sec > 0.0 and sec <= MAX_BOARD_BEAT_SEC


func _load_presentation() -> PresentationConfig:
	var loaded: PresentationConfig = _load(PRESENTATION_FILE) as PresentationConfig
	if loaded == null:
		push_error("ConfigRepository: %s を読めないため、初期値を使う" % PRESENTATION_FILE)
		return PresentationConfig.new()
	var settle_sec: float = loaded.board_settle_sec
	if not _is_board_sec_valid(settle_sec):
		push_error("ConfigRepository: %s の値が範囲外（board_settle_sec=%s）のため、初期値を使う" % [PRESENTATION_FILE, settle_sec])
		return PresentationConfig.new()
	var result_sec: float = loaded.board_result_sec
	if not _is_board_sec_valid(result_sec):
		push_error("ConfigRepository: %s の値が範囲外（board_result_sec=%s）のため、初期値を使う" % [PRESENTATION_FILE, result_sec])
		return PresentationConfig.new()
	var play_sec: float = loaded.board_play_sec
	if not _is_board_sec_valid(play_sec):
		push_error("ConfigRepository: %s の値が範囲外（board_play_sec=%s）のため、初期値を使う" % [PRESENTATION_FILE, play_sec])
		return PresentationConfig.new()
	if not loaded.review_lookback_turns >= 0:
		push_error("ConfigRepository: %s の値が範囲外（review_lookback_turns=%d）のため、初期値を使う" % [PRESENTATION_FILE,
				loaded.review_lookback_turns])
		return PresentationConfig.new()
	if not _is_ball_style_valid(loaded):
		push_error("ConfigRepository: %s の値が範囲外（ball_loft_height=%s, ball_touch_height=%s, ball_dribble_touches=%d）のため、初期値を使う"
				% [PRESENTATION_FILE, loaded.ball_loft_height, loaded.ball_touch_height, loaded.ball_dribble_touches])
		return PresentationConfig.new()
	if not (_is_board_sec_valid(loaded.preview_move_sec) and _is_within(loaded.preview_hold_sec, MAX_BOARD_BEAT_SEC)):
		push_error("ConfigRepository: %s の値が範囲外（preview_move_sec=%s, preview_hold_sec=%s）のため、初期値を使う"
				% [PRESENTATION_FILE, loaded.preview_move_sec, loaded.preview_hold_sec])
		return PresentationConfig.new()
	if not _is_piece_motion_valid(loaded):
		push_error("ConfigRepository: %s の値が範囲外（piece_stagger=%s, piece_hop_height=%s, board_beat_gap_sec=%s）のため、初期値を使う"
				% [PRESENTATION_FILE, loaded.piece_stagger, loaded.piece_hop_height, loaded.board_beat_gap_sec])
		return PresentationConfig.new()
	return loaded


## 駒の動きの値の範囲（ずらしの幅・弾みの高さ・拍の間の小休止。同じ表）。NaN でも偽になるよう、肯定形で確かめる。
static func _is_piece_motion_valid(config: PresentationConfig) -> bool:
	return _is_within(config.piece_stagger, MAX_PIECE_STAGGER) and _is_within(config.piece_hop_height, MAX_PIECE_HOP_HEIGHT) \
			and _is_within(config.board_beat_gap_sec, MAX_BOARD_BEAT_GAP_SEC)


## 0 以上 upper 以下の有限の値か。
static func _is_within(value: float, upper: float) -> bool:
	return is_finite(value) and value >= 0.0 and value <= upper


## ボールの軌道の値の範囲（functional-overview.md「設定値として外部化する値」）。NaN でも偽になるよう、肯定形で確かめる。
static func _is_ball_style_valid(config: PresentationConfig) -> bool:
	var loft: float = config.ball_loft_height
	var touch: float = config.ball_touch_height
	var loft_ok: bool = is_finite(loft) and loft >= 0.0 and loft <= MAX_BALL_LOFT_HEIGHT
	var touch_ok: bool = is_finite(touch) and touch >= 0.0 and touch <= MAX_BALL_TOUCH_HEIGHT
	return loft_ok and touch_ok and config.ball_dribble_touches >= 1 and config.ball_dribble_touches <= MAX_BALL_DRIBBLE_TOUCHES


## ファイルが無ければ null（ResourceLoader.load は無いファイルでエンジンのエラーを出すため、先に存在を確かめる）。
func _load(file_name: String) -> Resource:
	var path: String = _config_dir.path_join(file_name)
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path)
