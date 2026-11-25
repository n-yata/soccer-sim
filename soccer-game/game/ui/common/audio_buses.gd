## 設定の音量をオーディオバス（BGM・SE。default_bus_layout.tres）へ反映する（screen-12-settings.md「音量の反映」）。
## 音量は linear_to_db(値)。値が 0 ならミュートにする（linear_to_db(0) は負の無限大になるため）。
class_name AudioBuses
extends RefCounted

const BGM_BUS: StringName = &"BGM"
const SE_BUS: StringName = &"SE"


static func apply(settings: UserSettings) -> void:
	_apply_bus(BGM_BUS, settings.bgm_volume)
	_apply_bus(SE_BUS, settings.se_volume)


## バスが無い（レイアウトが読めていない）のは開発時の誤り。
static func _apply_bus(bus_name: StringName, volume: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_error("AudioBuses: バスが無い: %s" % bus_name)
		return
	AudioServer.set_bus_mute(index, volume <= 0.0)
	if volume > 0.0:
		AudioServer.set_bus_volume_db(index, linear_to_db(volume))
