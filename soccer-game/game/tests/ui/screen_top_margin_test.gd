## ヘッダーを持つ画面の、上の外周の余白（screen-common.md §1.1。24px）のテスト。
## 2026-11-05 にヘッダーが画面の上端に付いていた（S-08 は自分で余白を持つので含めない）。
extends GdUnitTestSuite

const TOP_MARGIN: float = 24.0
const SCREENS: Array[AppScreens.Id] = [AppScreens.Id.S02_MATCH_SETUP, AppScreens.Id.S07_REVIEW, AppScreens.Id.S09_QUIZ,
		AppScreens.Id.S10_SCOPE, AppScreens.Id.S11_RECORDS, AppScreens.Id.S12_SETTINGS]


func test_screens_with_a_header_leave_the_outer_margin_above_it() -> void:
	for screen: AppScreens.Id in SCREENS:
		var scene: PackedScene = load(MainShell.SCREEN_SCENES[screen] as String) as PackedScene
		var instance: Node = auto_free(scene.instantiate()) as Node
		var layout: Control = instance.get_node("Layout") as Control
		assert_float(layout.offset_top).override_failure_message(
				"上の余白が無い: %s" % AppScreens.Id.find_key(screen)).is_equal(TOP_MARGIN)
		# 下まで広げたまま（本体は残りの高さ）
		assert_float(layout.anchor_bottom).is_equal(1.0)
		assert_float(layout.offset_bottom).is_equal(0.0)
