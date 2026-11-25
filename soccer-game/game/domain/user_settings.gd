## 利用者の設定（data-definition.md §2.4。FR-15・FR-19）。音量は 0.0〜1.0。
## 初期値は FR-15（ヒント表示は ON）と data-definition.md の表のとおり。
class_name UserSettings
extends RefCounted

const DEFAULT_VOLUME: float = 0.7
const DEFAULT_SHOW_HINTS: bool = true
const DEFAULT_TUTORIAL_COMPLETED: bool = false

var bgm_volume: float = DEFAULT_VOLUME
var se_volume: float = DEFAULT_VOLUME
var show_hints: bool = DEFAULT_SHOW_HINTS
var tutorial_completed: bool = DEFAULT_TUTORIAL_COMPLETED


func duplicate_deep() -> UserSettings:
	var copy := UserSettings.new()
	copy.bgm_volume = bgm_volume
	copy.se_volume = se_volume
	copy.show_hints = show_hints
	copy.tutorial_completed = tutorial_completed
	return copy
