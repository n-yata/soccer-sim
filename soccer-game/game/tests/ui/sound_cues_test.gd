## SoundCues（オートロード Sfx。.steering/20261030-sound-effects/design.md）のテスト。
## どの場面で何を鳴らしたかは cue_played で受けて確かめる。
extends GdUnitTestSuite

var _played: Array[int] = []


func before_test() -> void:
	_played.clear()
	Sfx.cue_played.connect(_on_cue_played)


func after_test() -> void:
	if Sfx.cue_played.is_connected(_on_cue_played):
		Sfx.cue_played.disconnect(_on_cue_played)


func _on_cue_played(cue: SoundCues.Cue) -> void:
	_played.append(cue)


## 4つの音すべてにファイルが読み込めていて、効果音のバス（設定の効果音音量）で鳴る
func test_every_cue_has_its_sound_on_the_se_bus() -> void:
	assert_int(SoundCues.Cue.values().size()).is_equal(4)
	for cue: int in SoundCues.Cue.values():
		var player: AudioStreamPlayer = Sfx.player_for(cue as SoundCues.Cue)
		assert_object(player.stream).override_failure_message("音が無い: %d" % cue).is_not_null()
		assert_float(player.stream.get_length()).override_failure_message("長さが0: %d" % cue).is_greater(0.0)
		assert_str(String(player.bus)).is_equal(String(AudioBuses.SE_BUS))


## 音ごとに別のファイル（同じ音を2つの場面に使っていない）
func test_each_cue_uses_its_own_file() -> void:
	var paths: Dictionary = {}
	for cue: int in SoundCues.Cue.values():
		paths[Sfx.player_for(cue as SoundCues.Cue).stream.resource_path] = true
	assert_int(paths.size()).is_equal(4)


func test_play_starts_the_sound_and_reports_the_cue() -> void:
	Sfx.play(SoundCues.Cue.WHISTLE)
	assert_bool(Sfx.player_for(SoundCues.Cue.WHISTLE).playing).is_true()
	assert_array(_played).is_equal([SoundCues.Cue.WHISTLE] as Array[int])
	Sfx.player_for(SoundCues.Cue.WHISTLE).stop()


## 画面に足したボタンは、画面ごとにつながなくても押すとクリック音を鳴らす
func test_pressing_any_button_in_the_tree_clicks() -> void:
	var button: Button = auto_free(Button.new()) as Button
	add_child(button)
	button.pressed.emit()
	var check: CheckButton = auto_free(CheckButton.new()) as CheckButton
	add_child(check)
	check.pressed.emit()
	assert_array(_played).is_equal([SoundCues.Cue.CLICK, SoundCues.Cue.CLICK] as Array[int])


## 木から外して入れ直しても、1回押して2回鳴らない
func test_a_button_that_reenters_the_tree_clicks_once() -> void:
	var button: Button = auto_free(Button.new()) as Button
	add_child(button)
	remove_child(button)
	add_child(button)
	button.pressed.emit()
	assert_array(_played).is_equal([SoundCues.Cue.CLICK] as Array[int])
