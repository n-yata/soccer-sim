## PhaseBanner（局面が変わったときに盤面を横切る帯。2026-11-07）のテスト。
## 試合画面で、局面が変わったターンにだけ出ることは match_screens_test で確かめる。
extends GdUnitTestSuite

const SCREEN_SIZE := Vector2(1280, 720)


func _banner() -> PhaseBanner:
	var host: Control = auto_free(Control.new()) as Control
	host.theme = load("res://ui/common/theme/app_theme.tres") as Theme
	host.size = SCREEN_SIZE
	add_child(host)
	var banner := PhaseBanner.new()
	host.add_child(banner)
	return banner


## 局面ごとの見出しと一言。帯の色は、その局面でボールを持つ側のチームの色
func test_each_phase_shows_its_title_line_and_the_holder_color() -> void:
	var banner: PhaseBanner = _banner()
	var you: Color = banner.get_theme_color("you", "TacticsBoard")
	var opponent: Color = banner.get_theme_color("opponent", "TacticsBoard")
	assert_object(you).is_not_equal(opponent)
	var expected: Dictionary = {
		GameEnums.Phase.ATTACK: ["ATTACK", "攻撃 ― 自分のボールで攻める", you],
		GameEnums.Phase.NEG_TRANSITION: ["NEG. TRANSITION", "ネガティブトランジション ― ボールを失った", opponent],
		GameEnums.Phase.DEFENSE: ["DEFENSE", "守備 ― ゴールを守る", opponent],
		GameEnums.Phase.POS_TRANSITION: ["POS. TRANSITION", "ポジティブトランジション ― ボールを奪った", you],
	}
	for phase: GameEnums.Phase in expected:
		banner.show_phase(phase)
		assert_bool(banner.is_showing()).is_true()
		assert_str(banner.title_text()).is_equal(expected[phase][0])
		assert_str(banner.line_text()).is_equal(expected[phase][1])
		assert_object(banner.accent_color()).is_equal(expected[phase][2])


## follow: 最初の局面（キックオフ・チュートリアルの最初の段階）では出さず、前と変わったときだけ出す。
## 変わらなければ、前の帯が残っていても消す（チュートリアルの説明だけの段階は開示が無く、そこで消えないため）。forget で最初に戻る
func test_follow_shows_only_when_the_phase_changes() -> void:
	var banner: PhaseBanner = _banner()
	banner.follow(GameEnums.Phase.ATTACK)
	assert_bool(banner.is_showing()).is_false()
	banner.follow(GameEnums.Phase.DEFENSE)
	assert_bool(banner.is_showing()).is_true()
	assert_str(banner.title_text()).is_equal("DEFENSE")
	banner.follow(GameEnums.Phase.DEFENSE)
	assert_bool(banner.is_showing()).is_false()
	banner.follow(GameEnums.Phase.POS_TRANSITION)
	assert_bool(banner.is_showing()).is_true()
	banner.forget()
	assert_bool(banner.is_showing()).is_false()
	banner.follow(GameEnums.Phase.ATTACK)
	assert_bool(banner.is_showing()).override_failure_message("忘れた後の最初の局面で出た").is_false()


## 約1秒で勝手に消える（タップは要らない）
func test_the_banner_hides_itself_after_its_duration() -> void:
	var banner: PhaseBanner = _banner()
	banner.show_phase(GameEnums.Phase.NEG_TRANSITION)
	await get_tree().create_timer(PhaseBanner.DURATION * 0.5).timeout
	assert_bool(banner.is_showing()).is_true()
	await get_tree().create_timer(PhaseBanner.DURATION * 0.5 + 0.2).timeout
	assert_bool(banner.is_showing()).is_false()


## 出ている間も、帯の下の操作（手のボタン）を止めない
func test_the_banner_lets_taps_through() -> void:
	var banner: PhaseBanner = _banner()
	banner.show_phase(GameEnums.Phase.ATTACK)
	assert_int(banner.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	for child: Node in banner.find_children("*", "Control", true, false):
		assert_int((child as Control).mouse_filter).override_failure_message(child.name).is_equal(Control.MOUSE_FILTER_IGNORE)


## どの局面でも、見出しと一言は 24px 以上で、画面の幅（左右の余白 24px を除く）に1行で入る
func test_every_phase_fits_the_screen_width_in_one_line() -> void:
	var banner: PhaseBanner = _banner()
	await await_idle_frame()
	for phase: GameEnums.Phase in [GameEnums.Phase.ATTACK, GameEnums.Phase.NEG_TRANSITION, GameEnums.Phase.DEFENSE,
			GameEnums.Phase.POS_TRANSITION]:
		banner.show_phase(phase)
		for label: Label in [banner.title_label(), banner.line_label()]:
			var font_size: int = label.get_theme_font_size("font_size")
			assert_int(font_size).is_greater_equal(24)
			var width: float = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
					font_size).x
			assert_float(width).override_failure_message(label.text).is_less_equal(SCREEN_SIZE.x - 48.0)
		# 帯は画面の横いっぱいで、縦は真ん中
		assert_float(banner.size.x).is_equal_approx(SCREEN_SIZE.x, 0.5)
		assert_float(banner.position.y + banner.size.y / 2.0).is_equal_approx(SCREEN_SIZE.y / 2.0, 0.5)


## 利用者から見た局面: トランジションでボールを持つのは奪った側
func test_user_phase_follows_the_turn_kind_and_the_ball() -> void:
	assert_int(MatchTexts.user_phase(GameEnums.TurnKind.OPEN_PLAY, true)).is_equal(GameEnums.Phase.ATTACK)
	assert_int(MatchTexts.user_phase(GameEnums.TurnKind.OPEN_PLAY, false)).is_equal(GameEnums.Phase.DEFENSE)
	assert_int(MatchTexts.user_phase(GameEnums.TurnKind.TRANSITION, true)).is_equal(GameEnums.Phase.POS_TRANSITION)
	assert_int(MatchTexts.user_phase(GameEnums.TurnKind.TRANSITION, false)).is_equal(GameEnums.Phase.NEG_TRANSITION)
